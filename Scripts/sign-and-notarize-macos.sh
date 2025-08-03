#!/usr/bin/env bash

set -euo pipefail

# Sign and notarize macOS binary using Apple Developer certificates
# Requires the following environment variables:
# - APPLE_CERTIFICATE_P12_BASE64: Base64 encoded Developer ID certificate
# - APPLE_CERTIFICATE_PASSWORD: Password for the certificate
# - APPLE_API_KEY_BASE64: Base64 encoded App Store Connect API key
# - APPLE_API_KEY_ID: App Store Connect API key ID
# - APPLE_API_ISSUER_ID: App Store Connect issuer ID

BINARY_PATH="${1:-".build/apple/Products/Release/swift-dependency-audit"}"

echo "=== Signing and Notarizing macOS Binary ==="
echo "Binary path: $BINARY_PATH"

# Validate required environment variables
if [[ -z "${APPLE_CERTIFICATE_P12_BASE64:-}" ]]; then
  echo "❌ Error: APPLE_CERTIFICATE_P12_BASE64 environment variable is required"
  exit 1
fi

if [[ -z "${APPLE_CERTIFICATE_PASSWORD:-}" ]]; then
  echo "❌ Error: APPLE_CERTIFICATE_PASSWORD environment variable is required"
  exit 1
fi

if [[ -z "${APPLE_API_KEY_BASE64:-}" ]]; then
  echo "❌ Error: APPLE_API_KEY_BASE64 environment variable is required"
  exit 1
fi

if [[ -z "${APPLE_API_KEY_ID:-}" ]]; then
  echo "❌ Error: APPLE_API_KEY_ID environment variable is required"
  exit 1
fi

if [[ -z "${APPLE_API_ISSUER_ID:-}" ]]; then
  echo "❌ Error: APPLE_API_ISSUER_ID environment variable is required"
  exit 1
fi

# Validate binary exists
if [[ ! -f "$BINARY_PATH" ]]; then
  echo "❌ Error: Binary not found at $BINARY_PATH"
  exit 1
fi

# Create variables (RUNNER_TEMP is provided by GitHub Actions)
TEMP_DIR="${RUNNER_TEMP:-/tmp}"
CERTIFICATE_PATH="${TEMP_DIR}/build_certificate.p12"
EPHEMERAL_KEYCHAIN_PASSWORD="$(openssl rand -base64 100)"
EPHEMERAL_KEYCHAIN_PATH="${TEMP_DIR}/app-signing.keychain-db"

echo "📄 Setting up certificate and keychain..."

# Import certificate from secret
echo -n "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode -o "${CERTIFICATE_PATH}"

# Create temporary keychain
security create-keychain -p "$EPHEMERAL_KEYCHAIN_PASSWORD" "${EPHEMERAL_KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${EPHEMERAL_KEYCHAIN_PATH}"
security unlock-keychain -p "$EPHEMERAL_KEYCHAIN_PASSWORD" "${EPHEMERAL_KEYCHAIN_PATH}"

# Import certificate to keychain
security import "${CERTIFICATE_PATH}" -P "$APPLE_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "${EPHEMERAL_KEYCHAIN_PATH}"
security set-key-partition-list -S "apple-tool:,apple:" -s -k "${EPHEMERAL_KEYCHAIN_PASSWORD}" "${EPHEMERAL_KEYCHAIN_PATH}"
security list-keychain -d user -s "${EPHEMERAL_KEYCHAIN_PATH}" login.keychain

# Clean up certificate file
rm "${CERTIFICATE_PATH}"

echo "🔐 Signing binary..."

# Find the exact certificate identity
CERT_IDENTITY=$(security find-identity -v "${EPHEMERAL_KEYCHAIN_PATH}" | grep "Developer ID Application" | head -1 | cut -d '"' -f 2)
echo "Using certificate identity: $CERT_IDENTITY"

# Sign binary
codesign --force --options runtime --timestamp --sign "$CERT_IDENTITY" "$BINARY_PATH"

# Verify signature
codesign --verify --verbose "$BINARY_PATH"

echo "📝 Preparing for notarization..."

# Create API key
echo "$APPLE_API_KEY_BASE64" | base64 --decode -o "${TEMP_DIR}/AuthKey.p8"

# Zip for notarization
ditto -c -k --keepParent "$BINARY_PATH" swift-dependency-audit.zip

echo "📡 Submitting for notarization..."

# Submit for notarization
xcrun notarytool submit swift-dependency-audit.zip \
  --key "${TEMP_DIR}/AuthKey.p8" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --wait

echo "🧹 Cleaning up..."

# Clean up
rm -f "${TEMP_DIR}/AuthKey.p8" swift-dependency-audit.zip
security delete-keychain "${EPHEMERAL_KEYCHAIN_PATH}"

echo "✅ macOS binary successfully signed and notarized"
