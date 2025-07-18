#!/bin/bash

# SwiftDependencyAudit SPM Artifact Bundle Generator
# Creates Swift Package Manager compatible artifact bundles with multi-platform binaries
# Usage: ./spm-artifact-bundle.sh <version>

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly TOOL_NAME="swift-dependency-audit"
readonly BUNDLE_NAME="swift-dependency-audit.artifactbundle"
readonly TEMPLATE_FILE="Templates/spm-artifact-bundle-info.template"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

# Utility functions
calculate_checksum() {
    local file="$1"
    
    if command -v shasum >/dev/null 2>&1; then
        # macOS/BSD systems
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        # Linux/GNU systems
        sha256sum "$file" | cut -d' ' -f1
    else
        log_error "No checksum tool available (shasum or sha256sum)"
        return 1
    fi
}

# Validation functions
validate_version() {
    local version="$1"

    # Remove 'v' prefix if present for internal processing
    version="${version#v}"

    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]]; then
        log_error "Invalid version format: $version"
        log_error "Expected format: 1.0.0 or 1.0.0-beta.1"
        return 1
    fi

    return 0
}

validate_binary() {
    local binary_path="$1"
    local platform="$2"

    if [[ ! -f "$binary_path" ]]; then
        log_error "$platform binary not found: $binary_path"
        return 1
    fi

    if [[ ! -x "$binary_path" ]]; then
        log_error "$platform binary is not executable: $binary_path"
        return 1
    fi

    # Get binary size for reporting
    local size
    if size=$(du -h "$binary_path" 2>/dev/null | cut -f1); then
        log_info "$platform binary found: $binary_path ($size)"
    else
        log_info "$platform binary found: $binary_path"
    fi

    return 0
}

# Function to create platform-specific directory and copy binary
create_platform_binary() {
    local platform="$1"
    local binary_path="$2"
    local target_name="$3"
    local version="$4"

    local platform_dir="$BUNDLE_NAME/$TOOL_NAME-$platform"

    log_info "Creating $platform binary entry..."

    # Validate binary exists and is executable
    if ! validate_binary "$binary_path" "$platform"; then
        log_error "Validation failed for $platform binary: $binary_path"
        return 1
    fi

    # Create directory structure
    if ! mkdir -p "$platform_dir"; then
        log_error "Failed to create directory: $platform_dir"
        return 1
    fi

    # Copy binary
    if ! cp "$binary_path" "$platform_dir/$target_name"; then
        log_error "Failed to copy binary from $binary_path to $platform_dir/$target_name"
        return 1
    fi

    if ! chmod +x "$platform_dir/$target_name"; then
        log_error "Failed to make binary executable: $platform_dir/$target_name"
        return 1
    fi

    # Verify the copy
    if [[ ! -f "$platform_dir/$target_name" ]]; then
        log_error "Failed to copy $platform binary to $platform_dir/$target_name"
        return 1
    fi

    local copied_size=$(du -h "$platform_dir/$target_name" | cut -f1)
    log_success "$platform binary created: $platform_dir/$target_name ($copied_size)"

    return 0
}

# Main script
main() {
    # Parse arguments
    local version
    if [[ $# -eq 1 ]]; then
        version="$1"
    else
        # Try to get version from git if no argument provided
        if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
            version="$(git describe --tags --always)"
            log_info "Using git version: $version"
        else
            log_error "Usage: $SCRIPT_NAME <version>"
            log_error "Example: $SCRIPT_NAME 1.0.0"
            exit 1
        fi
    fi

    # Clean VERSION to remove any 'v' prefix for internal processing
    local clean_version="${version#v}"

    # Validate version format
    if ! validate_version "$clean_version"; then
        exit 1
    fi

    log_info "Creating artifact bundle for $TOOL_NAME version $clean_version"

    # Clean up any existing bundle
    if [[ -d "$BUNDLE_NAME" ]]; then
        log_info "Removing existing bundle directory..."
        rm -rf "$BUNDLE_NAME"
    fi

    if [[ -f "$BUNDLE_NAME.zip" ]]; then
        log_info "Removing existing bundle archive..."
        rm -f "$BUNDLE_NAME.zip"
    fi

    # Create artifact bundle directory
    mkdir -p "$BUNDLE_NAME"

    # Track successful binary creations
    local binaries_created=0

    # Create macOS universal binary
    local macos_path=".build/apple/Products/Release/swift-dependency-audit"
    if [[ -f "$macos_path" ]]; then
        if create_platform_binary "macos" "$macos_path" "swift-dependency-audit" "$clean_version"; then
            binaries_created=$((binaries_created + 1))
        else
            log_warning "Failed to create macOS binary bundle"
        fi
    else
        log_warning "macOS binary not found: $macos_path"
    fi

    # Create Linux x86_64 binary
    local linux_x86_path=".build/x86_64-unknown-linux-gnu/release/swift-dependency-audit"
    if [[ -f "$linux_x86_path" ]]; then
        if create_platform_binary "x86_64-unknown-linux-gnu" "$linux_x86_path" "swift-dependency-audit" "$clean_version"; then
            binaries_created=$((binaries_created + 1))
        else
            log_warning "Failed to create Linux x86_64 binary bundle"
        fi
    else
        log_warning "Linux x86_64 binary not found: $linux_x86_path"
    fi

    # Create Linux ARM64 binary
    local linux_arm_path=".build/aarch64-unknown-linux-gnu/release/swift-dependency-audit"
    if [[ -f "$linux_arm_path" ]]; then
        if create_platform_binary "aarch64-unknown-linux-gnu" "$linux_arm_path" "swift-dependency-audit" "$clean_version"; then
            binaries_created=$((binaries_created + 1))
        else
            log_warning "Failed to create Linux aarch64 binary bundle"
        fi
    else
        log_warning "Linux ARM64 binary not found: $linux_arm_path"
    fi

    # Verify we have at least one binary
    if [[ $binaries_created -eq 0 ]]; then
        log_error "No binaries were successfully created"
        exit 1
    fi

    log_info "Successfully created $binaries_created platform binary/binaries"

    # Generate info.json from template
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi

    log_info "Generating info.json manifest..."
    sed "s/__VERSION__/$clean_version/g" "$TEMPLATE_FILE" > "$BUNDLE_NAME/info.json"

    if [[ ! -f "$BUNDLE_NAME/info.json" ]]; then
        log_error "Failed to generate info.json"
        exit 1
    fi

    log_success "Generated info.json for version $clean_version"

    # Copy license if available
    if [[ -f "LICENSE" ]]; then
        cp LICENSE "$BUNDLE_NAME/"
        log_success "Added LICENSE to bundle"
    else
        log_warning "LICENSE file not found, skipping"
    fi

    # Create ZIP archive
    local zip_name="$BUNDLE_NAME.zip"
    log_info "Creating ZIP archive: $zip_name"

    if command -v 7z >/dev/null 2>&1; then
        # Use 7z if available (better compression)
        log_info "Using 7zip for compression..."
        7z a -tzip -mx=9 "$zip_name" "$BUNDLE_NAME/" >/dev/null
    else
        # Fallback to system zip
        log_info "Using system zip for compression..."
        zip -r -9 "$zip_name" "$BUNDLE_NAME/" >/dev/null
    fi

    # Verify ZIP was created
    if [[ ! -f "$zip_name" ]]; then
        log_error "Failed to create ZIP archive"
        exit 1
    fi

    # Calculate checksum
    local checksum=$(calculate_checksum "$zip_name")
    local zip_size=$(du -h "$zip_name" | cut -f1)

    # Save checksum to file for CI
    echo "$checksum" > "$zip_name.checksum"

    # Display results
    echo ""
    log_success "🎉 Artifact bundle created successfully!"
    log_info "📦 Bundle: $zip_name ($zip_size)"
    log_info "🔐 SHA256: $checksum"
    log_info "📋 Checksum file: $zip_name.checksum"
    echo ""
    log_info "Add this to your Package.swift:"
    echo "----------------------------------------"
    echo ".binaryTarget("
    echo "    name: \"SwiftDependencyAuditBinary\","
    echo "    url: \"https://github.com/tonyarnold/swift-dependency-audit/releases/download/v$clean_version/$zip_name\","
    echo "    checksum: \"$checksum\""
    echo ")"
    echo "----------------------------------------"
    echo ""

    # Clean up bundle directory
    rm -rf "$BUNDLE_NAME"
    log_info "Cleaned up temporary bundle directory"

    log_success "Artifact bundle generation completed"
}

# Run main function with all arguments
main "$@"
