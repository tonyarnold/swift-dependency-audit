#!/bin/bash

# SwiftDependencyAudit SPM Artifact Bundle Generator
# Based on SwiftFormat's proven workflow

set -e

# Configuration
TOOL_NAME="swift-dependency-audit"
BUNDLE_NAME="swift-dependency-audit.artifactbundle"
VERSION=${1:-$(git describe --tags --always)}

# Clean VERSION to remove any 'v' prefix
VERSION=${VERSION#v}

echo "Creating artifact bundle for $TOOL_NAME version $VERSION"

# Create artifact bundle directory
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME"

# Function to create platform-specific directory and copy binary
create_platform_binary() {
    local platform=$1
    local binary_path=$2
    local target_name=$3
    
    local platform_dir="$BUNDLE_NAME/$TOOL_NAME-$VERSION-$platform"
    local bin_dir="$platform_dir/bin"
    
    echo "Creating $platform binary..."
    mkdir -p "$bin_dir"
    
    if [ -f "$binary_path" ]; then
        cp "$binary_path" "$bin_dir/$target_name"
        chmod +x "$bin_dir/$target_name"
        echo "✅ $platform binary created: $bin_dir/$target_name"
    else
        echo "❌ Binary not found: $binary_path"
        return 1
    fi
}

# Create macOS universal binary
if [ -f ".build/apple/Products/Release/swift-dependency-audit" ]; then
    create_platform_binary "macos" ".build/apple/Products/Release/swift-dependency-audit" "swift-dependency-audit"
elif [ -f ".build/release/swift-dependency-audit" ]; then
    create_platform_binary "macos" ".build/release/swift-dependency-audit" "swift-dependency-audit"
else
    echo "❌ macOS binary not found. Please build first with:"
    echo "   swift build -c release --arch arm64 --arch x86_64"
    exit 1
fi

# Create Linux x86_64 binary
if [ -f ".build/x86_64-unknown-linux-gnu/release/swift-dependency-audit" ]; then
    create_platform_binary "linux-gnu" ".build/x86_64-unknown-linux-gnu/release/swift-dependency-audit" "swift-dependency-audit_linux"
fi

# Create Linux ARM64 binary
if [ -f ".build/aarch64-unknown-linux-gnu/release/swift-dependency-audit" ]; then
    # Create the linux-gnu directory if it doesn't exist
    local linux_dir="$BUNDLE_NAME/$TOOL_NAME-$VERSION-linux-gnu/bin"
    mkdir -p "$linux_dir"
    cp ".build/aarch64-unknown-linux-gnu/release/swift-dependency-audit" "$linux_dir/swift-dependency-audit_linux_aarch64"
    chmod +x "$linux_dir/swift-dependency-audit_linux_aarch64"
    echo "✅ Linux ARM64 binary created: $linux_dir/swift-dependency-audit_linux_aarch64"
fi

# Generate info.json from template
if [ -f "Scripts/spm-artifact-bundle-info.template" ]; then
    echo "Generating info.json manifest..."
    sed "s/__VERSION__/$VERSION/g" Scripts/spm-artifact-bundle-info.template > "$BUNDLE_NAME/info.json"
    echo "✅ Generated info.json for version $VERSION"
else
    echo "❌ Template file not found: Scripts/spm-artifact-bundle-info.template"
    exit 1
fi

# Copy license
if [ -f "LICENSE" ]; then
    cp LICENSE "$BUNDLE_NAME/"
    echo "✅ Added LICENSE to bundle"
fi

# Create ZIP archive
ZIP_NAME="$BUNDLE_NAME.zip"
echo "Creating ZIP archive: $ZIP_NAME"

if command -v 7z >/dev/null 2>&1; then
    # Use 7z if available (better compression)
    7z a -tzip -mx=9 "$ZIP_NAME" "$BUNDLE_NAME/"
else
    # Fallback to system zip
    zip -r -9 "$ZIP_NAME" "$BUNDLE_NAME/"
fi

# Calculate checksum
CHECKSUM=$(shasum -a 256 "$ZIP_NAME" | cut -d' ' -f1)

echo ""
echo "🎉 Artifact bundle created successfully!"
echo "📦 Bundle: $ZIP_NAME"
echo "🔐 SHA256: $CHECKSUM"
echo ""
echo "Add this to your Package.swift:"
echo ".binaryTarget("
echo "    name: \"SwiftDependencyAuditBinary\","
echo "    url: \"https://github.com/tonyarnold/swift-dependency-audit/releases/download/v$VERSION/$ZIP_NAME\","
echo "    checksum: \"$CHECKSUM\""
echo ")"
echo ""

# Save checksum to file for CI
echo "$CHECKSUM" > "$ZIP_NAME.checksum"