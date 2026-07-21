#!/usr/bin/env python3
"""Start an Xcode Cloud build via the App Store Connect API.

Xcode Cloud's native GitHub push/tag triggers are unreliable for this repo
(Apple's own git reference index never picked up any tags), so releases
trigger the build directly via API instead of waiting on Apple's webhook.

Required environment variables:
  ASC_ISSUER_ID     App Store Connect API issuer ID
  ASC_KEY_ID        App Store Connect API key ID
  ASC_PRIVATE_KEY   App Store Connect API private key (.p8 contents, PEM)
  ASC_WORKFLOW_ID   Xcode Cloud ciWorkflows id to build
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
    workflow_id = os.environ["ASC_WORKFLOW_ID"]

    token = make_jwt(issuer_id, key_id, private_key_pem)
    body = json.dumps(
        {
            "data": {
                "type": "ciBuildRuns",
                "relationships": {"workflow": {"data": {"type": "ciWorkflows", "id": workflow_id}}},
            }
        }
    ).encode()

    req = urllib.request.Request(
        f"{BASE}/ciBuildRuns",
        data=body,
        method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"Failed to start Xcode Cloud build: HTTP {e.code}", file=sys.stderr)
        print(e.read().decode(), file=sys.stderr)
        sys.exit(1)

    run = data["data"]
    print(f"Started Xcode Cloud build #{run['attributes'].get('number')} (id={run['id']})")


if __name__ == "__main__":
    main()
