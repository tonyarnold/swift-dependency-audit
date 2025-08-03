#!/usr/bin/env bash

set -euo pipefail

# Setup Swift on Linux using Swiftly
# This script handles Swift installation for Linux CI/build environments

echo "=== Setting up Swift for Linux ==="

# Check if Swift is already available
if command -v swift >/dev/null 2>&1; then
  echo "Swift is already available:"
  swift --version
else
  echo "Installing Swift using Swiftly..."

  # Install Swiftly
  curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash

  # Add Swiftly to PATH for current session
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> $GITHUB_PATH

  # Install latest Swift toolchain
  swiftly install latest
  swiftly use latest

  echo "Swift installation completed:"
  swift --version
fi