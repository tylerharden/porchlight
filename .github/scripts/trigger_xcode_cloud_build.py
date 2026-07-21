#!/usr/bin/env python3
"""Start an Xcode Cloud build via the App Store Connect API and wait for it.

Xcode Cloud's native GitHub push/tag triggers are unreliable for this repo
(Apple's own webhook delivery is badly delayed -- sometimes hours), so
releases trigger the build directly via API instead of waiting on it.

If ASC_TAG is set, this looks up the matching git reference in Apple's
index and builds that specific tag (so the build shows up under the tag
in App Store Connect, not lumped under "main"). Apple's tag indexing also
lags sometimes, so if the tag isn't indexed yet this falls back to
building main's current HEAD with a warning, rather than failing the
release outright.

This also polls the build until it finishes and fails the job (with the
actual compiler/script error printed) if the Xcode Cloud build itself
failed, so a real build failure is visible in the GitHub Actions run
instead of only showing "successfully started a build".

Required environment variables:
  ASC_ISSUER_ID     App Store Connect API issuer ID
  ASC_KEY_ID        App Store Connect API key ID
  ASC_PRIVATE_KEY   App Store Connect API private key (.p8 contents, PEM)
  ASC_WORKFLOW_ID   Xcode Cloud ciWorkflows id to build

Optional:
  ASC_TAG           git tag name to build (e.g. v0.2.0); omit to build main
"""
import base64
import json
import os
import sys
import time
import urllib.request
import urllib.error

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

BASE = "https://api.appstoreconnect.apple.com/v1"
POLL_INTERVAL_SECONDS = 30
TIMEOUT_SECONDS = 25 * 60


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_jwt(issuer_id: str, key_id: str, private_key_pem: str) -> str:
    private_key = serialization.load_pem_private_key(private_key_pem.encode(), password=None)

    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"

    der_sig = private_key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = utils.decode_dss_signature(der_sig)
    raw_sig = r.to_bytes(32, "big") + s.to_bytes(32, "big")

    return f"{signing_input}.{b64url(raw_sig)}"


class Client:
    def __init__(self, issuer_id: str, key_id: str, private_key_pem: str):
        self.issuer_id = issuer_id
        self.key_id = key_id
        self.private_key_pem = private_key_pem

    def call(self, path: str, method: str = "GET", body: dict | None = None) -> dict:
        token = make_jwt(self.issuer_id, self.key_id, self.private_key_pem)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            f"{BASE}{path}",
            data=data,
            method=method,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            print(f"App Store Connect API error: HTTP {e.code} for {method} {path}", file=sys.stderr)
            print(e.read().decode(), file=sys.stderr)
            sys.exit(1)


def find_tag_reference(client: Client, workflow_id: str, tag: str) -> str | None:
    repository = client.call(f"/ciWorkflows/{workflow_id}/repository")
    repo_id = repository["data"]["id"]

    refs = client.call(f"/scmRepositories/{repo_id}/gitReferences?limit=200").get("data", [])
    for ref in refs:
        if ref["attributes"].get("kind") == "TAG" and ref["attributes"].get("name") == tag:
            return ref["id"]
    return None


def start_build(client: Client, workflow_id: str, tag: str | None) -> str:
    relationships = {"workflow": {"data": {"type": "ciWorkflows", "id": workflow_id}}}

    if tag:
        ref_id = find_tag_reference(client, workflow_id, tag)
        if ref_id:
            relationships["sourceBranchOrTag"] = {"data": {"type": "scmGitReferences", "id": ref_id}}
            print(f"Building tag {tag!r} (git reference {ref_id})")
        else:
            print(f"Tag {tag!r} not yet indexed by Apple, building main's current HEAD instead")

    data = client.call(
        "/ciBuildRuns",
        method="POST",
        body={"data": {"type": "ciBuildRuns", "relationships": relationships}},
    )
    run = data["data"]
    print(f"Started Xcode Cloud build #{run['attributes'].get('number')} (id={run['id']})")
    return run["id"]


def print_failure_details(client: Client, build_run_id: str) -> None:
    actions = client.call(f"/ciBuildRuns/{build_run_id}/actions").get("data", [])
    for action in actions:
        name = action["attributes"].get("name")
        status = action["attributes"].get("completionStatus")
        print(f"  action: {name} -> {status}")
        if status not in ("SUCCEEDED", None):
            issues = client.call(f"/ciBuildActions/{action['id']}/issues?limit=20").get("data", [])
            for issue in issues:
                a = issue["attributes"]
                print(f"    [{a.get('issueType')}] {a.get('message')}")


def wait_for_build(client: Client, build_run_id: str) -> None:
    deadline = time.time() + TIMEOUT_SECONDS
    while True:
        data = client.call(f"/ciBuildRuns/{build_run_id}")
        attrs = data["data"]["attributes"]
        progress = attrs.get("executionProgress")
        print(f"  status: {progress}")

        if progress == "COMPLETE":
            result = attrs.get("completionStatus")
            if result == "SUCCEEDED":
                print(f"Xcode Cloud build succeeded: {attrs.get('sourceCommit', {}).get('webUrl', '')}")
                return
            print(f"Xcode Cloud build finished with result: {result}", file=sys.stderr)
            print_failure_details(client, build_run_id)
            sys.exit(1)

        if time.time() > deadline:
            print(f"Timed out after {TIMEOUT_SECONDS}s waiting for Xcode Cloud build to finish", file=sys.stderr)
            sys.exit(1)

        time.sleep(POLL_INTERVAL_SECONDS)


def main():
    client = Client(
        issuer_id=os.environ["ASC_ISSUER_ID"],
        key_id=os.environ["ASC_KEY_ID"],
        private_key_pem=os.environ["ASC_PRIVATE_KEY"],
    )
    workflow_id = os.environ["ASC_WORKFLOW_ID"]
    tag = os.environ.get("ASC_TAG") or None

    build_run_id = start_build(client, workflow_id, tag)
    wait_for_build(client, build_run_id)


if __name__ == "__main__":
    main()
