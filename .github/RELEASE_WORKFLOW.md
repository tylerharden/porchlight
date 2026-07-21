# Release Workflow

## Overview

Porchlight uses a single version number across the CLI and macOS app. Releases are cut via a `workflow_dispatch` action, not by pushing a tag directly — the version is bumped and committed *before* the tag is created, so the tag always points at the exact commit that gets built and shipped.

Three workflows are involved:

1. **`prepare-release.yml`** — the entry point. Bumps `cli/Cargo.toml` and the Xcode project version, commits to `main`, tags that commit, and creates the GitHub Release.
2. **`release-cli.yml`** — triggered by the release being published. Builds a universal (arm64 + x86_64) CLI binary and uploads it, with a sha256 checksum, to the release.
3. **`release-macos.yml`** — also triggered by the release. Starts an Xcode Cloud build via the App Store Connect API and waits for it to finish, failing loudly (with the real compiler/archive error) if it fails.

The last two run independently — a CLI build failure doesn't block or affect the macOS build, and vice versa. Each has its own status badge in the README.

## Creating a Release

```bash
gh workflow run prepare-release.yml --repo tylerharden/porchlight -f version=0.2.0
```

Or via the Actions tab: **Prepare Release → Run workflow**, enter the version (no `v` prefix, e.g. `0.2.0`).

That's it — this single action bumps both version numbers, commits, tags `v0.2.0`, pushes, and creates the GitHub Release, which then kicks off both `release-cli.yml` and `release-macos.yml` automatically.

## Why not just push a tag?

The original design tagged first and bumped the version afterward, in a commit pushed *after* the tag already existed. That meant Xcode Cloud, if pointed at the tag, would build stale, unbumped source — confirmed live on the real `v0.1.0` release (the build's `sourceCommit` was the tag's original target, not the version-bump commit). Bumping and committing *before* tagging removes that whole class of bug: the tag and `main`'s HEAD are always the same commit at release time.

## Why the App Store Connect API, not Xcode Cloud's native triggers

Xcode Cloud's built-in GitHub tag/branch triggers never reliably fired for this repo — confirmed via the App Store Connect API that Apple's own git reference index frequently lags or never catches up. `release-macos.yml` instead calls `POST /v1/ciBuildRuns` directly via `.github/scripts/trigger_xcode_cloud_build.py`, using the App Store Connect API key stored in the `ASC_ISSUER_ID` / `ASC_KEY_ID` / `ASC_PRIVATE_KEY` repo secrets. See `apps/macos/docs/XCODE_CLOUD_SETUP.md` for the Xcode Cloud workflow configuration itself (which lives in App Store Connect, not in this repo).

## Version Numbers by Component

| Component | File | Version Format |
|-----------|------|-----------------|
| Rust CLI | `cli/Cargo.toml` | `version = "0.2.0"` |
| macOS App | `apps/macos/Porchlight.xcodeproj/project.pbxproj` | `MARKETING_VERSION = 0.2.0;` |

Both are bumped together by `prepare-release.yml`. Note `MARKETING_VERSION` must be clean dotted-numeric (no pre-release suffixes like `-beta`) — Xcode Cloud's Archive action validates this as part of App Store Connect submission prep and will reject anything else.

## Manual Testing

To test without a real version bump, use `workflow_dispatch` directly on `release-cli.yml` or `release-macos.yml` — both support it independently of a real release, useful for retrying just one side (e.g. after an Xcode Cloud failure) without re-bumping versions or re-running the CLI build.

## Monitoring

- **GitHub Actions**: Actions tab, or the `CI` / `CLI Release` / `macOS App Release` badges in the README
- **Xcode Cloud**: `release-macos.yml`'s job log includes the real build error directly (fetched via the App Store Connect API) if the Xcode Cloud build fails — no need to check App Store Connect separately unless you want more detail
- **Releases page**: CLI binary + checksum are attached as release assets once `release-cli.yml` finishes

## Troubleshooting

### `prepare-release.yml` fails on `git tag`
The tag already exists — you're likely re-running with a version that was already released. Pick a new version.

### macOS build fails with a real Xcode Cloud error
`release-macos.yml` prints the actual failure (fetched via `ciBuildActions/{id}/issues`) directly in its job log. Common ones seen so far:
- Missing Rust toolchain (fixed via `apps/macos/ci_scripts/ci_post_clone.sh`, installs it via Homebrew)
- Invalid `MARKETING_VERSION` format (must be dotted-numeric only)
- Missing App Store Connect metadata (e.g. `LSApplicationCategoryType`) once the workflow targets `APP_STORE_ELIGIBLE` distribution

### CLI or macOS release didn't trigger automatically
Both require the GitHub release to actually be published (not draft). If it was published but nothing ran, check `Settings > Actions > General > Workflow permissions` allows "Read and write permissions".

## Related Documentation

- [Xcode Cloud Setup](../apps/macos/docs/XCODE_CLOUD_SETUP.md) — Xcode Cloud workflow configuration, backup/recovery
- [Xcode Cloud Documentation](https://developer.apple.com/xcode-cloud/) — Apple's official docs
- [App Store Connect](https://appstoreconnect.apple.com) — Web UI for managing builds
