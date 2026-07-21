#!/usr/bin/env python3
"""Recreate the Xcode Cloud workflow from apps/macos/docs/xcode-cloud-workflow.json.

Xcode Cloud config lives entirely in App Store Connect, not in the repo, so
there's nothing to restore from git if a workflow is deleted or a product
connection is reset (as happened once already this project -- see git log
around "ci: trigger CLI/macOS releases..."). This is a manual disaster-recovery
tool, not something any CI workflow runs automatically.

Usage:
  ASC_ISSUER_ID=... ASC_KEY_ID=... ASC_PRIVATE_KEY="$(cat AuthKey.p8)" \
    python3 .github/scripts/recreate_xcode_cloud_workflow.py

Note: the relationship IDs (product, repository, xcodeVersion, macOsVersion)
in xcode-cloud-workflow.json are only valid for the CURRENT product/repo
connection. If that connection was also deleted, first reconnect the
repository in App Store Connect (Xcode Cloud > your app > Manage Workflows),
then look up the new IDs via GET /v1/ciProducts before running this.
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
SNAPSHOT_PATH = os.path.join(
    os.path.dirname(__file__), "..", "..", "apps", "macos", "docs", "xcode-cloud-workflow.json"
)


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


def main():
    issuer_id = os.environ["ASC_ISSUER_ID"]
    key_id = os.environ["ASC_KEY_ID"]
    private_key_pem = os.environ["ASC_PRIVATE_KEY"]

    with open(SNAPSHOT_PATH) as f:
        snapshot = json.load(f)

    rel = snapshot["relationships"]
    body = {
        "data": {
            "type": "ciWorkflows",
            "attributes": {
                "name": snapshot["name"],
                "description": snapshot["description"],
                "containerFilePath": snapshot["containerFilePath"],
                "clean": snapshot["clean"],
                "isEnabled": snapshot["isEnabled"],
                "actions": snapshot["actions"],
                "tagStartCondition": snapshot["tagStartCondition"],
                "branchStartCondition": snapshot["branchStartCondition"],
                "pullRequestStartCondition": snapshot["pullRequestStartCondition"],
                "scheduledStartCondition": snapshot["scheduledStartCondition"],
                "manualBranchStartCondition": snapshot["manualBranchStartCondition"],
                "manualTagStartCondition": snapshot["manualTagStartCondition"],
            },
            "relationships": {
                "product": {"data": {"type": "ciProducts", "id": rel["product"]["id"]}},
                "repository": {"data": {"type": "scmRepositories", "id": rel["repository"]["id"]}},
                "xcodeVersion": {"data": {"type": "ciXcodeVersions", "id": rel["xcodeVersion"]["id"]}},
                "macOsVersion": {"data": {"type": "ciMacOsVersions", "id": rel["macOsVersion"]["id"]}},
            },
        }
    }

    token = make_jwt(issuer_id, key_id, private_key_pem)
    req = urllib.request.Request(
        f"{BASE}/ciWorkflows",
        data=json.dumps(body).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"Failed to create workflow: HTTP {e.code}", file=sys.stderr)
        print(e.read().decode(), file=sys.stderr)
        sys.exit(1)

    workflow = data["data"]
    print(f"Created workflow {workflow['id']!r} ({workflow['attributes']['name']!r})")
    print("Update ASC_WORKFLOW_ID in .github/workflows/release-macos.yml to this new id.")


if __name__ == "__main__":
    main()
