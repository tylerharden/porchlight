# Release Workflow

## Overview

Porchlight uses a semantic versioning system with a single version number across all platforms (CLI, macOS, and future Windows/Linux builds).

When you create a release with a `v*` tag:

1. GitHub Actions workflow automatically extracts the version
2. Updates version numbers in all platform-specific files (Cargo.toml, Xcode project)
3. Commits the version updates back to main
4. Xcode Cloud automatically triggers builds (via git tag)
5. Sends Slack notification when release is published

## Creating a Release

### Step 1: Create a Git Tag

```bash
git tag v0.2.0
git push origin v0.2.0
```

**Tag format:** `v` followed by semantic version (`vX.Y.Z`)

**Note:** You don't need to manually update version numbers. Xcode Cloud will automatically extract the version from the tag and update the app version before building.

### Step 2: Create GitHub Release

Go to [Releases](https://github.com/tylerharden/porchlight/releases) and create a new release:

- **Tag:** `v0.2.0` (the tag you just pushed)
- **Title:** `v0.2.0`
- **Description:** Release notes with changes, improvements, and bug fixes
- **Publish release:** Check the "Publish this release" checkbox

When the release is published:
- GitHub Actions extracts version from tag and updates CLI version
- Xcode Cloud detects the tag and automatically starts building
- Xcode Cloud post-clone script updates macOS app version to match tag
- Build proceeds with correct version in all components

### Workflow Automation

When the release is published:

1. **Version Update Stage**
   - GitHub Actions extracts version from tag (`v0.2.0` → `0.2.0`)
   - Updates `cli/Cargo.toml`
   - Updates `apps/macos/Porchlight.xcodeproj/project.pbxproj`
   - Commits changes back to main branch

2. **Build Stage**
   - Xcode Cloud detects the `v*` tag
   - Automatically starts release builds for macOS

3. **Notification Stage**
   - Sends Slack message with release details
   - Includes version, repository link, and release link

## Setup Requirements

### GitHub Secrets

Add these secrets to your GitHub repository settings (`Settings > Secrets and variables > Actions`):

- **`SLACK_WEBHOOK`** - Slack webhook URL for notifications
  - Get this from your Slack workspace: Incoming Webhooks integration
  - Optional if you don't want Slack notifications

### Xcode Cloud Configuration

Xcode Cloud watches your GitHub repository for tags matching `v*` and automatically starts builds. The manifest is stored at:

```
apps/macos/Porchlight.xcodeproj/xcshareddata/xcodecloud/manifest.json
```

Configure your Xcode Cloud build workflow in Xcode:
1. Open the project in Xcode
2. Go to **Product → Xcode Cloud → Manage Workflows**
3. Create a workflow that builds on tag pattern `v*`
4. Configure signing and distribution settings

## Version Numbers by Component

| Component | File | Version Format |
|-----------|------|-----------------|
| Rust CLI | `cli/Cargo.toml` | `version = "0.2.0"` |
| macOS App | `apps/macos/Porchlight.xcodeproj/project.pbxproj` | `MARKETING_VERSION = 0.2.0;` |

All versions are synchronized automatically by the GitHub Actions workflow.

## Examples

### Creating a Minor Release

```bash
# Current version is 0.1.0, bumping to 0.2.0
git tag v0.2.0
git push origin v0.2.0

# Go to GitHub Releases, create release from v0.2.0 tag
# Add release notes and publish

# Workflow automatically:
# - Updates Cargo.toml to 0.2.0
# - Updates Xcode project to 0.2.0
# - Commits back to main
# - Xcode Cloud starts building
# - Slack notification sent
```

### Creating a Patch Release

```bash
# Current version is 0.2.0, bumping to 0.2.1
git tag v0.2.1
git push origin v0.2.1

# GitHub → Releases → Create from tag
# Workflow handles the rest
```

## Manual Testing

To test the workflow without creating a real release:

```bash
# Create a test tag
git tag v0.1.0-test
git push origin v0.1.0-test

# Go to GitHub and create a release from this tag
# Workflow runs, commits version updates, sends notification

# Clean up test tag
git tag -d v0.1.0-test
git push --delete origin v0.1.0-test
```

## Monitoring

- **GitHub Actions**: Watch the **Actions** tab for workflow progress
- **Slack**: Receive notifications in your configured Slack channel
- **Xcode Cloud**: View detailed build logs in the Xcode Cloud dashboard
- **Main Branch**: Version updates are automatically committed to `main`

## Troubleshooting

### Workflow doesn't trigger
- Ensure tag follows `v*` format (e.g., `v0.2.0`, not `macos-0.2.0`)
- Ensure release is marked as "Published" (not draft)
- Check GitHub Actions permissions: `Settings > Actions > General > Workflow permissions` should allow "Read and write permissions"

### Slack notification fails
- Verify `SLACK_WEBHOOK` secret is set in repository settings
- Test webhook URL is valid: `curl -X POST -H 'Content-type: application/json' --data '{"text":"Test"}' YOUR_WEBHOOK_URL`

### Xcode Cloud build fails
- Verify Xcode Cloud workflow is configured to trigger on `v*` tags
- Check build logs in Xcode Cloud dashboard
- Ensure macOS app builds successfully locally: `xcodebuild -project apps/macos/Porchlight.xcodeproj -scheme Porchlight -configuration Release build`

### Version numbers not updating
- Check GitHub Actions workflow logs for sed command errors
- Verify file paths in workflow match your repo structure
- Ensure GitHub token has write permissions to repository

## Related Documentation

- [Xcode Cloud Setup](../apps/macos/docs/XCODE_CLOUD_SETUP.md) — Manual configuration in Xcode Cloud UI
- [Xcode Cloud Documentation](https://developer.apple.com/xcode-cloud/) — Apple's official docs
- [App Store Connect](https://appstoreconnect.apple.com) — Web UI for managing builds
