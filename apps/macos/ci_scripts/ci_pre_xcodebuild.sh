#!/bin/bash

# Xcode Cloud pre-xcodebuild script to set version from git tag
# This script runs before xcodebuild executes
# It extracts the version from the git tag and updates the Xcode project

set -e  # Exit on error

# Check if we're building from a tag
if [ -z "$CI_TAG" ]; then
    echo "No git tag detected, skipping version update"
    exit 0
fi

echo "Git tag detected: $CI_TAG"

# Extract version from tag (remove 'v' prefix)
# Examples: v0.2.0 -> 0.2.0, v1.0.0 -> 1.0.0
VERSION=${CI_TAG#v}

echo "Setting version to: $VERSION"

# Use agvtool to update the marketing version in Xcode project
# This updates both CFBundleShortVersionString and other version info
cd "$(dirname "$0")/../"
agvtool new-marketing-version "$VERSION"

echo "Version updated successfully"
