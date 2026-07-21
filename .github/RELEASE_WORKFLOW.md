# Release Workflow

## Overview

Porchlight uses a single version number across the CLI and macOS app. Releases are cut with `scripts/release.sh`, run **locally**, not via a GitHub Actions workflow — the version is bumped and committed *before* the tag is created, so the tag always points at the exact commit that gets built and shipped, and the release is created with your own GitHub auth rather than the Actions `GITHUB_TOKEN`.

### Why locally, not via GitHub Actions?

Two hard-learned reasons:

1. **`GITHUB_TOKEN` doesn't cascade.** A release created by a workflow running with the default `GITHUB_TOKEN` does not trigger other workflows' `release: published` listeners — GitHub deliberately suppresses this to prevent infinite recursive workflow chains. A `prepare-release.yml` workflow that bumped, tagged, and created the release itself would silently never kick off the actual build workflows. Running it locally with your own token sidesteps this entirely.
2. **Tag-then-bump was a real bug, not just cosmetic.** The original design tagged first and bumped the version in a commit pushed *after* the tag existed. Xcode Cloud, pointed at that tag, would build the stale, unbumped source — confirmed live on the real `v0.1.0` release (the build's `sourceCommit` was the tag's original target, not the version-bump commit). Bumping and committing *before* tagging removes that whole class of bug.

## Creating a Release

```bash
scripts/release.sh 0.2.0
```

This bumps `cli/Cargo.toml` and the Xcode project's `MARKETING_VERSION`, commits, tags `v0.2.0`, pushes both, and creates the GitHub Release (`--generate-notes`). Must be run from an up-to-date `main`.

Publishing the release triggers three independent workflows:

1. **`release-cli.yml`** — builds a universal (arm64 + x86_64) CLI binary, uploads it with a sha256 checksum to the release.
2. **`release-macos.yml`** — starts an Xcode Cloud build via the App Store Connect API (for eventual Mac App Store / TestFlight distribution) and waits for it to finish, failing loudly with the real archive error if it fails.
3. **`release-macos-direct.yml`** — archives, code-signs with a Developer ID Application certificate, notarizes via `notarytool`, staples, packages as a `.dmg`, and uploads it to the release (for direct/outside-the-App-Store distribution).

All three run independently — a failure in one doesn't block or affect the others. Each has its own status badge in the README.

## Why the App Store Connect API, not Xcode Cloud's native triggers

Xcode Cloud's built-in GitHub tag/branch triggers never reliably fired for this repo — confirmed via the App Store Connect API that Apple's own git reference index frequently lags or never catches up. `release-macos.yml` instead calls `POST /v1/ciBuildRuns` directly via `.github/scripts/trigger_xcode_cloud_build.py`, using the App Store Connect API key stored in the `ASC_ISSUER_ID` / `ASC_KEY_ID` / `ASC_PRIVATE_KEY` repo secrets. See `apps/macos/docs/XCODE_CLOUD_SETUP.md` for the Xcode Cloud workflow configuration itself (which lives in App Store Connect, not in this repo).

## Two Distribution Paths

| | Mac App Store / TestFlight | Direct download |
|---|---|---|
| Workflow | `release-macos.yml` | `release-macos-direct.yml` |
| Signing | Automatic, App Store Connect-managed | Developer ID Application cert (`DEVELOPER_ID_CERTIFICATE_P12` / `_PASSWORD` secrets) |
| Build system | Xcode Cloud (triggered via API) | GitHub Actions `macos-latest` runner directly |
| Output | Submitted to App Store Connect | Notarized, stapled `.dmg` attached to the GitHub Release |

## Version Numbers by Component

| Component | File | Version Format |
|-----------|------|-----------------|
| Rust CLI | `cli/Cargo.toml` | `version = "0.2.0"` |
| macOS App | `apps/macos/Porchlight.xcodeproj/project.pbxproj` | `MARKETING_VERSION = 0.2.0;` |

Both are bumped together by `scripts/release.sh`. Note `MARKETING_VERSION` must be clean dotted-numeric (no pre-release suffixes like `-beta`) — Xcode Cloud's Archive action validates this as part of App Store Connect submission prep and will reject anything else.

## Manual Testing

`release-cli.yml`, `release-macos.yml`, and `release-macos-direct.yml` all support `workflow_dispatch` independently of a real release — useful for retrying just one side (e.g. after an Xcode Cloud failure) without re-bumping versions or re-running the others.

## Monitoring

- **GitHub Actions**: Actions tab, or the `CI` / `CLI Release` / `macOS App Release` / `macOS Direct Release` badges in the README
- **Xcode Cloud**: `release-macos.yml`'s job log includes the real build error directly (fetched via the App Store Connect API) if the Xcode Cloud build fails — no need to check App Store Connect separately unless you want more detail
- **Releases page**: CLI binary, checksum, and the notarized `.dmg` + checksum are attached as release assets once their respective workflows finish

## Troubleshooting

### `scripts/release.sh` fails on `git tag`
The tag already exists — you're likely re-running with a version that was already released. Pick a new version.

### Release didn't trigger anything
Make sure you ran `scripts/release.sh` (or created the release yourself via `gh release create` / the web UI) rather than having a workflow create it — see "Why locally" above.

### macOS App Store build fails with a real Xcode Cloud error
`release-macos.yml` prints the actual failure (fetched via `ciBuildActions/{id}/issues`) directly in its job log. Common ones seen so far:
- Missing Rust toolchain (fixed via `apps/macos/ci_scripts/ci_post_clone.sh`, installs it via Homebrew)
- Invalid `MARKETING_VERSION` format (must be dotted-numeric only)
- Missing App Store Connect metadata (e.g. `LSApplicationCategoryType`) once the workflow targets `APP_STORE_ELIGIBLE` distribution
- Generic `Preparing build for App Store Connect failed` with no further detail via the API — this needs local investigation via Xcode's **Product → Archive → Validate App**, which surfaces a specific, actionable message the API doesn't expose

### macOS Direct Release fails on notarization
Check the `notarytool submit --wait` output in the job log — it prints Apple's actual rejection reason (common ones: hardened runtime not enabled, missing entitlements, unsigned nested binaries/frameworks).

## Related Documentation

- [Xcode Cloud Setup](../apps/macos/docs/XCODE_CLOUD_SETUP.md) — Xcode Cloud workflow configuration, backup/recovery
- [Xcode Cloud Documentation](https://developer.apple.com/xcode-cloud/) — Apple's official docs
- [App Store Connect](https://appstoreconnect.apple.com) — Web UI for managing builds
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) — Apple's official docs
