#!/bin/bash

# Xcode Cloud post-clone script
# Runs immediately after Xcode Cloud clones the repo, before the Xcode build starts.
# The "Bundle porchlight CLI" run script build phase needs `cargo` on PATH,
# but Xcode Cloud's macOS image doesn't include the Rust toolchain by default.

set -e

echo "Installing Rust toolchain via Homebrew..."
brew install rust

echo "Rust installed: $(cargo --version)"
