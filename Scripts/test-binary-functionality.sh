#!/usr/bin/env bash

set -euo pipefail

# Test binary functionality with basic and comprehensive validation
# Usage: test-binary-functionality.sh <platform> <arch> [triple] [test_level]
#
# Parameters:
#   platform: "macOS" or "Linux"
#   arch: "universal", "x86_64", "aarch64", etc.
#   triple: Target triple for Linux builds (optional)
#   test_level: "basic" or "comprehensive" (default: basic)

PLATFORM="${1:-}"
ARCH="${2:-}"
TRIPLE="${3:-}"
TEST_LEVEL="${4:-basic}"

if [[ -z "$PLATFORM" || -z "$ARCH" ]]; then
  echo "Usage: $0 <platform> <arch> [triple] [test_level]"
  echo "Example: $0 macOS universal \"\" comprehensive"
  echo "Example: $0 Linux x86_64 x86_64-unknown-linux-gnu basic"
  exit 1
fi

echo "=== Testing Binary Functionality ==="
echo "Platform: $PLATFORM"
echo "Architecture: $ARCH"
echo "Test level: $TEST_LEVEL"

# Determine binary path based on platform
if [[ "$PLATFORM" = "macOS" ]]; then
  BINARY_PATH=".build/apple/Products/Release/swift-dependency-audit"
else
  if [[ -z "$TRIPLE" ]]; then
    echo "❌ Error: Triple is required for Linux builds"
    exit 1
  fi
  BINARY_PATH=".build/$TRIPLE/release/swift-dependency-audit"
fi

echo "Binary path: $BINARY_PATH"

# Validate binary exists
if [[ ! -f "$BINARY_PATH" ]]; then
  echo "❌ Error: Binary not found at $BINARY_PATH"
  exit 1
fi

# Make sure binary is executable
chmod +x "$BINARY_PATH"

echo "🔍 Running basic functionality tests..."

# Basic functionality test
echo "Testing basic functionality..."
"$BINARY_PATH" --version
"$BINARY_PATH" --help > /dev/null
"$BINARY_PATH" . --exclude-tests --quiet

echo "✅ Basic functionality tests passed"

# Run comprehensive tests if requested
if [[ "$TEST_LEVEL" = "comprehensive" ]]; then
  echo "🔬 Running comprehensive validation..."

  echo "=== Comprehensive CLI Validation ==="
  "$BINARY_PATH" --help
  "$BINARY_PATH" --version

  echo "=== Testing Self-Analysis ==="
  "$BINARY_PATH" . --verbose --exclude-tests

  echo "=== Testing JSON Output ==="
  "$BINARY_PATH" . --output-format json --no-color --exclude-tests > output.json
  if command -v jq >/dev/null 2>&1; then
    jq . output.json > /dev/null || (echo "❌ Invalid JSON output" && exit 1)
    echo "✅ JSON output is valid"
  else
    echo "⚠️  jq not available, skipping JSON validation"
  fi

  echo "=== Testing Output Formats ==="
  "$BINARY_PATH" . --output-format xcode --quiet --exclude-tests
  "$BINARY_PATH" . --output-format github-actions --quiet --exclude-tests

  echo "=== Testing Custom Whitelist ==="
  "$BINARY_PATH" . --whitelist "Foundation,SwiftUI,ArgumentParser" --verbose --exclude-tests

  echo "✅ Comprehensive validation tests passed"
fi

echo "🎉 All tests completed successfully"