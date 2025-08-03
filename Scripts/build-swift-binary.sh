#!/usr/bin/env bash

set -euo pipefail

# Build optimized Swift binary for the specified platform
# Usage: build-swift-binary.sh <platform> <arch> [triple] [version_source]
# 
# Parameters:
#   platform: "macOS" or "Linux"
#   arch: "universal", "x86_64", "aarch64", etc.
#   triple: Target triple for Linux builds (optional)
#   version_source: "git" for CI builds, "tag" for release builds, or explicit version

PLATFORM="${1:-}"
ARCH="${2:-}"
TRIPLE="${3:-}"
VERSION_SOURCE="${4:-git}"

if [[ -z "$PLATFORM" || -z "$ARCH" ]]; then
  echo "Usage: $0 <platform> <arch> [triple] [version_source]"
  echo "Example: $0 macOS universal"
  echo "Example: $0 Linux x86_64 x86_64-unknown-linux-gnu git"
  exit 1
fi

echo "=== Building Swift Binary ==="
echo "Platform: $PLATFORM"
echo "Architecture: $ARCH"
echo "Triple: ${TRIPLE:-N/A}"
echo "Version source: $VERSION_SOURCE"

# Determine version based on source
case "$VERSION_SOURCE" in
  "git")
    VERSION=$(git describe --tags --always 2>/dev/null | sed 's/^v//' || echo "dev")
    echo "Version will be detected as: $VERSION"
    ;;
  "tag")
    # For release workflows - get from GitHub environment
    if [[ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ]]; then
      VERSION="${GITHUB_EVENT_INPUTS_TAG_NAME:-}"
    else
      VERSION="${GITHUB_REF#refs/tags/}"
    fi
    VERSION="${VERSION#v}"  # Remove 'v' prefix if present
    echo "Building release binary (version will be detected as: $VERSION)..."
    ;;
  *)
    # Explicit version provided
    VERSION="$VERSION_SOURCE"
    echo "Using explicit version: $VERSION"
    ;;
esac

if [[ "$PLATFORM" = "macOS" ]]; then
  echo "🍎 Building universal macOS binary..."

  # Build ARM64 binary
  echo "Building ARM64 binary..."
  swift build --configuration release --arch arm64 -Xswiftc -Osize

  # Build x86_64 binary
  echo "Building x86_64 binary..."
  swift build --configuration release --arch x86_64 -Xswiftc -Osize

  # Create output directory
  mkdir -p .build/apple/Products/Release

  # Combine architectures with lipo
  echo "Combining architectures with lipo..."
  lipo -create \
    .build/arm64-apple-macosx/release/swift-dependency-audit \
    .build/x86_64-apple-macosx/release/swift-dependency-audit \
    -output .build/apple/Products/Release/swift-dependency-audit

  # Verify the universal binary
  echo "Verifying universal binary..."
  lipo -info .build/apple/Products/Release/swift-dependency-audit

  # Strip the final binary
  strip -rSTx .build/apple/Products/Release/swift-dependency-audit

  echo "✅ Universal macOS binary built successfully"

elif [[ "$PLATFORM" = "Linux" ]]; then
  if [[ -z "$TRIPLE" ]]; then
    echo "❌ Error: Triple is required for Linux builds"
    exit 1
  fi

  echo "🐧 Building static Linux binary for $ARCH..."
  swift build --configuration release --triple "$TRIPLE" -Xswiftc -Osize --static-swift-stdlib
  strip ".build/$TRIPLE/release/swift-dependency-audit"

  echo "✅ Linux $ARCH binary built successfully"

else
  echo "❌ Error: Unsupported platform '$PLATFORM'. Use 'macOS' or 'Linux'"
  exit 1
fi