# Release Workflow

## Overview

Porchlight uses a single version number across the CLI and macOS app. Releases are cut with `scripts/release.sh`, run **locally**, not via a GitHub Actions workflow — the version is bumped and committed *before* the tag is created, so the tag always points at the exact commit that gets built and shipped, and the release is created with your own GitHub auth rather than the Actions `GITHUB_TOKEN`.

### Why locally, not via GitHub Actions?

A release created by a workflow running with the default `GITHUB_TOKEN` does not trigger other workflows' `release: published` listeners — GitHub deliberately suppresses this to prevent infinite recursive workflow chains. A workflow that bumped, tagged, and created the release itself would silently never kick off the actual build workflows. Running it locally with your own token sidesteps this entirely.

## Creating a Release

```bash
scripts/release.sh 0.2.0
```

This bumps `cli/Cargo.toml` and the Xcode project's `MARKETING_VERSION`, commits, tags `v0.2.0`, pushes both, and creates the GitHub Release (`--generate-notes`). Must be run from an up-to-date `main`.

Publishing the release triggers two independent workflows:

1. **`release-cli.yml`** — builds a universal (arm64 + x86_64) CLI binary, uploads it with a sha256 checksum to the release.
2. **`release-macos.yml`** — archives the macOS app, code-signs it with a Developer ID Application certificate, notarizes via `notarytool`, staples the ticket, packages as a `.dmg`, and uploads it (with a checksum) to the release.

Both run independently — a failure in one doesn't block or affect the other. Each has its own status badge in the README.

## Distribution

Porchlight is distributed as a notarized `.dmg` for direct download — not through the Mac App Store. That path was tried (Xcode Cloud, `ENABLE_APP_SANDBOX`, the works) and ruled out: the Mac App Store requires App Sandbox for every submission, and Porchlight's core function — scanning the whole system for listening ports and inspecting other processes to find local dev servers — is exactly the class of behavior App Sandbox exists to prevent. Confirmed empirically: sandboxed, the CLI helper that does all the actual scanning crashes immediately on every launch attempt (`AppSandbox` abort in `libsystem_secinit.dylib`) before it can do anything. There's no entitlement that grants a general sandboxed app that kind of system-wide visibility. Making Porchlight App Store-eligible would mean abandoning system-wide discovery entirely — a different product, not a config change.

## Version Numbers by Component

| Component | File | Version Format |
|-----------|------|-----------------|
| Rust CLI | `cli/Cargo.toml` | `version = "0.2.0"` |
| macOS App | `apps/macos/Porchlight.xcodeproj/project.pbxproj` | `MARKETING_VERSION = 0.2.0;` |

Both are bumped together by `scripts/release.sh`.

## Manual Testing

`release-cli.yml` and `release-macos.yml` both support `workflow_dispatch` independently of a real release — useful for retrying one side without re-bumping versions or re-running the other.

## Monitoring

- **GitHub Actions**: Actions tab, or the `CI` / `CLI Release` / `macOS Release` badges in the README
- **Releases page**: CLI binary, checksum, notarized `.dmg`, and its checksum are attached as release assets once their respective workflows finish

## Troubleshooting

### `scripts/release.sh` fails on `git tag`
The tag already exists — you're likely re-running with a version that was already released. Pick a new version.

### Release didn't trigger anything
Make sure you ran `scripts/release.sh` (or created the release yourself via `gh release create` / the web UI) rather than having a workflow create it — see "Why locally" above.

### macOS Release fails on notarization
Check the `notarytool submit --wait` output in the job log — it prints Apple's actual rejection reason (common ones: hardened runtime not enabled, missing entitlements, unsigned nested binaries/frameworks). For a rejection with no detail in the log, fetch it directly:

```bash
xcrun notarytool log <submission-id> --key <path-to-AuthKey.p8> --key-id <ASC_KEY_ID> --issuer <ASC_ISSUER_ID>
```

## Related Documentation

- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) — Apple's official docs
