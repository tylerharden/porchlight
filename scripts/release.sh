#!/bin/bash
# Cut a release: bump both version numbers, commit, tag, push, and create
# the GitHub release -- in that order, so the tag always points at the
# exact commit that gets built and shipped.
#
# Run locally (not in CI) so the release is created with your own GitHub
# auth, not the Actions GITHUB_TOKEN -- GitHub suppresses workflow triggers
# for events caused by GITHUB_TOKEN, so a CI-created release would never
# actually kick off CLI Release / macOS Release.
#
# Usage: scripts/release.sh 0.2.0

set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh <version, e.g. 0.2.0>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Must be on main to cut a release" >&2
  exit 1
fi

git fetch origin --quiet
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "Local main is not up to date with origin/main -- pull first" >&2
  exit 1
fi

sed -i.bak "s/^version = .*/version = \"$VERSION\"/" cli/Cargo.toml
rm -f cli/Cargo.toml.bak
sed -i.bak "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" apps/macos/Porchlight.xcodeproj/project.pbxproj
rm -f apps/macos/Porchlight.xcodeproj/project.pbxproj.bak

# Keep Cargo.lock's self-referential package version in sync so it doesn't
# drift out of date until someone happens to build locally.
cargo check --manifest-path cli/Cargo.toml --quiet

echo "cli/Cargo.toml:"
grep "^version" cli/Cargo.toml
echo "project.pbxproj:"
grep "MARKETING_VERSION" apps/macos/Porchlight.xcodeproj/project.pbxproj | head -2

git add cli/Cargo.toml cli/Cargo.lock apps/macos/Porchlight.xcodeproj/project.pbxproj
git commit -m "chore: bump version to $VERSION"
git tag "v$VERSION"
git push origin main
git push origin "v$VERSION"

gh release create "v$VERSION" --title "v$VERSION" --generate-notes

echo "Released v$VERSION -- CLI Release and macOS Release should start shortly."
