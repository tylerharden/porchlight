# Xcode Cloud Setup Guide

## Overview

Xcode Cloud automatically builds and tests Porchlight on every git tag matching `v*`. This document describes the manual configuration required in Xcode Cloud UI.

**Note:** This configuration lives in Xcode Cloud's web UI and App Store Connect, not in code. It must be set up manually once.

## Prerequisites

- Apple Developer Program membership
- Xcode 15.0 or later
- Access to [App Store Connect](https://appstoreconnect.apple.com)
- GitHub repository connected to Xcode Cloud

## Active Configuration

The "GitHub Deploy" workflow has been configured with the following settings:

### General
- **Name:** GitHub Deploy
- **Description:** This workflow needs to exist for our GitHub workflow to be able to trigger a deploy with the API.

### Environment
- **Xcode Version:** Latest Release
- **macOS Version:** Latest Release
- **Environment Variables:** None

### Start Conditions
- **None.** Apple's native GitHub webhook trigger never reliably fired for this repo (confirmed via the App Store Connect API: Apple's own git reference index never picked up any pushed tags for this repo). Builds are instead started explicitly via `POST /v1/ciBuildRuns` from `.github/workflows/release-macos.yml` — see `.github/scripts/trigger_xcode_cloud_build.py`.
- Manual builds from the App Store Connect UI can still target any branch (`manualBranchStartCondition` allows all).

### Build Actions
- **Platform:** macOS
- **Scheme:** Porchlight
- **Build For:** Any Mac
- **Action Type:** Archive (`buildDistributionAudience: APP_STORE_ELIGIBLE`) — produces a signed, distributable `.xcarchive` using automatic signing (`DEVELOPMENT_TEAM = TLFCRD5283`), not just a compile check

## Backup & Recovery

Xcode Cloud config lives entirely in App Store Connect, not in git, so there's nothing to restore from source control if a workflow or product connection is deleted (this has already happened once — see git log around "ci: trigger CLI/macOS releases..."). A snapshot of the current workflow config is kept at `apps/macos/docs/xcode-cloud-workflow.json` and can be recreated via the API with:

```bash
ASC_ISSUER_ID=... ASC_KEY_ID=... ASC_PRIVATE_KEY="$(cat AuthKey.p8)" \
  python3 .github/scripts/recreate_xcode_cloud_workflow.py
```

Re-run the snapshot (fetch the workflow via `GET /v1/ciWorkflows/{id}` and update the JSON) after any manual change in App Store Connect so it stays accurate. Note the relationship IDs in the snapshot (product, repository, xcodeVersion, macOsVersion) are only valid for the current product/repo connection — if that's also gone, reconnect the repository first and look up fresh IDs.

## Automatic Version Management

Xcode Cloud automatically extracts the version from the git tag and updates the app version before building.

**How it works:**
1. When you push tag `v0.2.0`, Xcode Cloud reads `CI_TAG=v0.2.0`
2. Pre-xcodebuild script (`ci_scripts/ci_pre_xcodebuild.sh`) runs before compilation
3. Script extracts version: `v0.2.0` → `0.2.0`
4. Uses `agvtool` to update Xcode project version
5. Build proceeds with correct version in `CFBundleShortVersionString`
6. App Store receives correct version automatically

**Script location:** `apps/macos/ci_scripts/ci_pre_xcodebuild.sh`

This means you **don't need to manually update the version** before creating a tag — Xcode Cloud handles it!

## Post-Build Actions (Optional Setup)

If you want to add notifications or distribution after builds complete:

### Email Notifications
1. Go to **Post-Build Actions > Email**
2. Check **Notify on:**
   - ✅ Build Succeeds
   - ✅ Build Fails
3. Add recipients (your email, team emails)

### Slack Notifications (via GitHub Actions)
- Slack notifications are handled by the GitHub Actions workflow
- Sent when release is published
- Webhook configured via `SLACK_WEBHOOK` secret

### TestFlight Distribution (Optional)
1. Go to **Post-Build Actions > TestFlight**
2. Check **Distribute to TestFlight**
3. Select beta groups to notify

## Testing the Workflow

To verify the "Deploy Tag" workflow is working correctly:

1. Create a test tag locally:
   ```bash
   git tag v0.1.0-test
   git push origin v0.1.0-test
   ```

2. Go to [App Store Connect > Xcode Cloud > Builds](https://appstoreconnect.apple.com/access/builds/)
3. Verify build starts automatically (should trigger within a few seconds)
4. Watch the build progress in real-time
5. Once complete, check notification preferences

6. Clean up test tag:
   ```bash
   git tag -d v0.1.0-test
   git push --delete origin v0.1.0-test
   ```

**What to expect:**
- Build starts automatically when `v*` tag is pushed
- Auto-cancel is enabled, so older builds are cancelled
- If `apps/macos/` files haven't changed, build won't trigger
- Build completes on "Any Mac" (takes ~5-10 minutes typically)

## Workflow Overview

```
Release Created (v0.2.0 tag)
        ↓
GitHub Actions Workflow Runs
├─ Extract version from tag
├─ Update Cargo.toml
├─ Update Xcode project version
└─ Commit back to main
        ↓
Xcode Cloud Detects Tag
├─ Pull latest code
├─ Build app (Release configuration)
├─ Run tests
└─ Archive for distribution
        ↓
Post-Build Actions
├─ Email notification
├─ Slack notification
└─ (Optional) TestFlight distribution
```

## Configuration Summary

| Setting | Value | Purpose |
|---------|-------|---------|
| **Workflow Name** | Deploy Tag | Identifies the release workflow |
| **Trigger Type** | Tag changes | Only build on git tag pushes |
| **Tag Pattern** | `v*` | Matches semantic version tags (v0.1.0, v1.0.0, etc.) |
| **File Changes** | `apps/macos/**` | Only trigger if macOS app files changed |
| **Auto-cancel** | On | Cancel previous builds when new tag arrives |
| **Xcode Version** | Latest | Always use latest Xcode release |
| **macOS Version** | Latest | Always use latest macOS for building |
| **Scheme** | Porchlight | App target to build |
| **Build For** | Any Mac | Universal build for all Mac architectures |

## Troubleshooting

### Workflow doesn't trigger on tag

**Possible causes:**
- Tag pattern doesn't match (e.g., `macos-0.2.0` vs `v0.2.0`)
- Workflow is disabled or archived
- Repository isn't connected to Xcode Cloud

**Solution:**
1. Go to App Store Connect > Xcode Cloud > Workflows
2. Verify workflow status is "Active" (not Archived)
3. Check trigger pattern matches your tag format
4. Manually trigger a build from the App Store Connect UI to test

### Build fails in Xcode Cloud but succeeds locally

**Possible causes:**
- Different signing certificates
- Environment variables not set
- Dependencies not available in cloud
- macOS version mismatch

**Solution:**
1. Review build logs in App Store Connect
2. Check signing & provisioning profiles
3. Verify environment secrets are set
4. Run local build with Release configuration to match cloud

### Notifications not sent

**For Email:**
- Check email addresses in post-build actions
- Verify notification conditions are set

**For Slack:**
- Test webhook URL independently: 
  ```bash
  curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"Test"}' \
    YOUR_SLACK_WEBHOOK_URL
  ```
- Verify webhook URL is current (webhooks can expire)

## Related Documentation

- [Release Workflow](./RELEASE_WORKFLOW.md) — How to create releases and version bumping
- [Xcode Cloud Documentation](https://developer.apple.com/xcode-cloud/) — Apple's official docs
- [App Store Connect](https://appstoreconnect.apple.com) — Web UI for managing builds

## When to Update This Doc

- ✅ If you change the trigger pattern (e.g., from `v*` to something else)
- ✅ If you add/remove post-build actions
- ✅ If you change signing or distribution settings
- ✅ If you change the scheme or configuration used for releases

Update this file and commit to git so the team knows what's configured.
