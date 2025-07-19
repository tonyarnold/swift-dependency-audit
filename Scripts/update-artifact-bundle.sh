#!/bin/bash

# SwiftDependencyAudit artifact bundle updater
# Updates Package.swift with new version and checksum for binary targets
# Usage: ./update-artifact-bundle.sh <version>

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly ARTIFACT_BUNDLE="swift-dependency-audit.artifactbundle.zip"
readonly PACKAGE_FILE="Package.swift"
readonly BACKUP_FILE="Package.swift.bak"

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

    # Check if version starts with 'v'
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]]; then
        log_error "Invalid version format: $version"
        log_error "Expected format: v1.0.0 or v1.0.0-beta.1"
        return 1
    fi

    return 0
}

validate_checksum() {
    local checksum="$1"

    # SHA256 checksums are 64 characters long
    if [[ ${#checksum} -ne 64 ]]; then
        log_error "Invalid checksum length: ${#checksum} (expected 64)"
        return 1
    fi

    # Check if checksum contains only hexadecimal characters
    if [[ ! "$checksum" =~ ^[a-f0-9]+$ ]]; then
        log_error "Invalid checksum format: contains non-hexadecimal characters"
        return 1
    fi

    return 0
}

# Main script
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        log_error "Usage: $SCRIPT_NAME <version>"
        log_error "Example: $SCRIPT_NAME v1.0.0"
        exit 1
    fi

    local readonly version="$1"

    log_info "Starting $SCRIPT_NAME for version $version"

    # Validate version format
    if ! validate_version "$version"; then
        exit 1
    fi

    # Check if artifact bundle exists
    if [[ ! -f "$ARTIFACT_BUNDLE" ]]; then
        log_error "Artifact bundle '$ARTIFACT_BUNDLE' not found in current directory"
        log_error "Current directory: $(pwd)"
        log_error "Available files: $(ls -la | grep -E '\.zip$' || echo 'No zip files found')"
        exit 1
    fi

    # Check if Package.swift exists
    if [[ ! -f "$PACKAGE_FILE" ]]; then
        log_error "Package.swift not found in current directory"
        exit 1
    fi

    # Calculate and validate checksum
    log_info "Calculating SHA256 checksum for $ARTIFACT_BUNDLE..."
    local readonly checksum="$(calculate_checksum "$ARTIFACT_BUNDLE")"

    if ! validate_checksum "$checksum"; then
        exit 1
    fi

    # Display bundle information
    local readonly bundle_size="$(du -h "$ARTIFACT_BUNDLE" | cut -f1)"
    log_info "Artifact bundle information:"
    log_info "  File: $ARTIFACT_BUNDLE"
    log_info "  Size: $bundle_size"
    log_info "  Checksum: $checksum"

    # Create backup of Package.swift
    log_info "Creating backup: $BACKUP_FILE"
    cp "$PACKAGE_FILE" "$BACKUP_FILE"

    # Update Package.swift
    log_info "Updating Package.swift with:"
    log_info "  Version: $version"
    log_info "  Checksum: $checksum"

    # Check if the binary target section exists
    if ! grep -q "SwiftDependencyAuditBinary" "$PACKAGE_FILE"; then
        log_error "SwiftDependencyAuditBinary target not found in Package.swift"
        log_error "Please ensure you're using the production Package.swift template"
        rm -f "$BACKUP_FILE"
        exit 1
    fi

    # Update the download URL with proper error handling
    # Use a simpler approach that works across different sed implementations
    local temp_file="$(mktemp)"
    if ! sed "s|VERSION_PLACEHOLDER|$version|g" \
        "$PACKAGE_FILE" > "$temp_file"; then
        log_error "Failed to update version placeholder in Package.swift"
        log_warning "Restoring backup..."
        mv "$BACKUP_FILE" "$PACKAGE_FILE"
        rm -f "$temp_file"
        exit 1
    fi
    mv "$temp_file" "$PACKAGE_FILE"

    # Update the checksum with proper error handling
    local temp_file2="$(mktemp)"
    if ! sed "s|CHECKSUM_PLACEHOLDER|$checksum|g" \
        "$PACKAGE_FILE" > "$temp_file2"; then
        log_error "Failed to update checksum placeholder in Package.swift"
        log_warning "Restoring backup..."
        mv "$BACKUP_FILE" "$PACKAGE_FILE"
        rm -f "$temp_file2"
        exit 1
    fi
    mv "$temp_file2" "$PACKAGE_FILE"

    # Verify the changes were applied correctly
    log_info "Verifying changes..."

    if ! grep -q "$version" "$PACKAGE_FILE"; then
        log_error "Version update verification failed: $version not found in Package.swift"
        log_warning "Restoring backup..."
        mv "$BACKUP_FILE" "$PACKAGE_FILE"
        exit 1
    fi

    if ! grep -q "$checksum" "$PACKAGE_FILE"; then
        log_error "Checksum update verification failed: $checksum not found in Package.swift"
        log_warning "Restoring backup..."
        mv "$BACKUP_FILE" "$PACKAGE_FILE"
        exit 1
    fi

    # Display the updated configuration
    log_success "Package.swift updated successfully"
    echo ""
    log_info "Updated binary target configuration:"
    echo "----------------------------------------"
    grep -A 4 -B 1 "SwiftDependencyAuditBinary" "$PACKAGE_FILE" | sed 's/^/  /'
    echo "----------------------------------------"

    # Clean up backup file
    rm -f "$BACKUP_FILE"

    # Generate a checksum file for external verification
    echo "$checksum" > "$ARTIFACT_BUNDLE.checksum"
    log_success "Checksum file created: $ARTIFACT_BUNDLE.checksum"

    log_success "All updates completed successfully"
    log_info "Ready for release: $version"
}

# Run main function with all arguments
main "$@"
