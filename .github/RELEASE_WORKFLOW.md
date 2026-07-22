# Release Workflow

## Overview

The CLI and macOS app release **independently**, each with its own version number and its own platform-prefixed tag (`cli-vX.Y.Z`, `macos-vX.Y.Z`). A CLI-only fix doesn't force a no-op macOS release, and vice versa.

Both are cut entirely from GitHub Actions — no local script, no terminal required. Each workflow bumps its version, commits, tags, pushes, builds, and creates the GitHub Release with the built artifact attached, all in one `workflow_dispatch` run.

### Why one workflow does everything, not a release event fanning out

The obvious alternative — a workflow creates a release, and *that* triggers separate build workflows via `release: published` — runs into a real GitHub Actions limitation: events caused by the default `GITHUB_TOKEN` don't trigger other workflows' event listeners (this prevents infinite recursive workflow chains). A release created by a workflow using `GITHUB_TOKEN` would silently never kick off anything listening for it. The usual fix is a personal access token or GitHub App token dedicated to this, but that's real infrastructure to maintain for a single-maintainer project.

Since each platform's entire pipeline (bump → tag → build → release) runs inside **one** workflow rather than being split across a release event and separate listeners, there's no cross-workflow triggering happening at all — so `GITHUB_TOKEN` works fine.

### Why independent versions, not one shared number

The macOS app doesn't consume a pre-built CLI release artifact — it compiles `cli/` from source at build time (the "Bundle porchlight CLI" script phase). So there's nothing to coordinate by sharing a version number; the two components were never really versioned as one thing, just labeled that way. Independent versions mean a platform only gets a new release (and a changelog entry) when something in it actually changed.

## Creating a Release

**GitHub Actions tab** → **CLI Release** or **macOS Release** → **Run workflow** → enter the version (no prefix, e.g. `0.3.1`) → **Run workflow**.

Or from the terminal:

```bash
gh workflow run release-cli.yml -f version=0.3.1
gh workflow run release-macos.yml -f version=1.2.0
```

**`release-cli.yml`**: bumps `cli/Cargo.toml`, commits, tags `cli-v0.3.1`, pushes, builds a universal (arm64 + x86_64) CLI binary, creates the GitHub Release with the binary + sha256 checksum attached.

**`release-macos.yml`**: bumps the Xcode project's `MARKETING_VERSION`, commits, tags `macos-v1.2.0`, pushes, archives the app, code-signs with a Developer ID Application certificate, notarizes via `notarytool`, staples the ticket, packages as a `.dmg`, creates the GitHub Release with the `.dmg` + checksum attached.

Both run under the repo's own `GITHUB_TOKEN` — nobody needs their personal GitHub credentials on hand to cut a release.

## The CLI Version Pin

Since the macOS app builds the CLI from source rather than consuming a release, "which CLI version does this macOS build embed" needed an explicit answer instead of "whatever happened to be on `main`." `PORCHLIGHT_CLI_VERSION` (an Xcode build setting in `project.pbxproj`) is that pin — analogous to a pinned dependency version. The "Validate & Generate Build Info" script phase fails the Release build if `cli/Cargo.toml`'s actual version doesn't match the pin, and bakes the confirmed value into a compiled Swift constant (`Generated/BuildInfo.swift`) that the About tab reads directly.

Cutting a CLI release does **not** move this pin automatically — that's deliberate, so a macOS release always embeds a CLI version you've explicitly chosen, not just whatever CLI work happened to land most recently. To pick up a new CLI release in the next macOS build, update `PORCHLIGHT_CLI_VERSION` in the Xcode project first (commit that change to `main` before running the macOS Release workflow). If the pin and `cli/Cargo.toml` disagree, the Archive step fails loudly with the exact mismatch.

## Distribution

Porchlight is distributed as a notarized `.dmg` for direct download — not through the Mac App Store. That path was tried (Xcode Cloud, `ENABLE_APP_SANDBOX`, the works) and ruled out: the Mac App Store requires App Sandbox for every submission, and Porchlight's core function — scanning the whole system for listening ports and inspecting other processes to find local dev servers — is exactly the class of behavior App Sandbox exists to prevent. Confirmed empirically: sandboxed, the CLI helper that does all the actual scanning crashes immediately on every launch attempt (`AppSandbox` abort in `libsystem_secinit.dylib`) before it can do anything. There's no entitlement that grants a general sandboxed app that kind of system-wide visibility. Making Porchlight App Store-eligible would mean abandoning system-wide discovery entirely — a different product, not a config change.

## Version Numbers by Component

| Component | File | Tag prefix | Version Format |
|-----------|------|------------|-----------------|
| Rust CLI | `cli/Cargo.toml` | `cli-v` | `version = "0.3.1"` |
| macOS App | `apps/macos/Porchlight.xcodeproj/project.pbxproj` | `macos-v` | `MARKETING_VERSION = 1.2.0;` |
| CLI pin (macOS build) | `apps/macos/Porchlight.xcodeproj/project.pbxproj` | — | `PORCHLIGHT_CLI_VERSION = 0.3.1;` |

## Monitoring

- **GitHub Actions**: Actions tab, or the `CI` / `CLI Release` / `macOS Release` badges in the README
- **Releases page**: CLI binary + checksum, or the notarized `.dmg` + checksum, attached once the workflow finishes

## Troubleshooting

### Workflow fails on `git tag` or `gh release create`
The tag/release already exists — you're likely re-running with a version that was already released for that platform. Pick a new version.

### macOS Release fails on notarization
Check the `notarytool submit --wait` output in the job log — it prints Apple's actual rejection reason (common ones: hardened runtime not enabled, missing entitlements, unsigned nested binaries/frameworks). For a rejection with no detail in the log, fetch it directly:

```bash
xcrun notarytool log <submission-id> --key <path-to-AuthKey.p8> --key-id <ASC_KEY_ID> --issuer <ASC_ISSUER_ID>
```

### macOS Release build fails with "CLI version mismatch"
`PORCHLIGHT_CLI_VERSION` in the Xcode project doesn't match `cli/Cargo.toml`. Update the pin (project build settings), commit to `main`, then re-run the workflow.

## Related Documentation

- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) — Apple's official docs
