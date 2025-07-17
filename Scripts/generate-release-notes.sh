#!/bin/bash

# SwiftDependencyAudit Release Notes Generator
# Extracts release notes from CHANGELOG.md for a specific version
# Usage: ./generate-release-notes.sh <version>

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly CHANGELOG_FILE="CHANGELOG.md"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        log_error "Usage: $SCRIPT_NAME <version>"
        log_error "Example: $SCRIPT_NAME v1.0.0"
        exit 1
    fi
    
    local version="$1"
    
    # Remove 'v' prefix if present for matching
    local clean_version="${version#v}"
    
    # Check if CHANGELOG.md exists
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        log_error "CHANGELOG.md not found in current directory"
        exit 1
    fi
    
    log_info "Extracting release notes for version $version from $CHANGELOG_FILE"
    
    # Extract the unreleased section if no specific version is provided or version is "unreleased"
    if [[ "$clean_version" == "unreleased" ]] || [[ "$version" == "unreleased" ]]; then
        log_info "Extracting unreleased changes..."
        
        # Extract content between "## [Unreleased]" and the next "## [" line
        awk '
        /^## \[Unreleased\]/ { found=1; next }
        /^## \[/ && found { exit }
        found && /^$/ { print; next }
        found && !/^$/ { print }
        ' "$CHANGELOG_FILE" | sed '/^$/d' | head -n -1
        
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            log_error "Failed to extract unreleased section from CHANGELOG.md"
            exit 1
        fi
        
        log_success "Successfully extracted unreleased changes"
        return 0
    fi
    
    # Try to find the version in different formats
    local version_patterns=(
        "^## \\[$clean_version\\]"
        "^## \\[v$clean_version\\]"
        "^## $clean_version"
        "^## v$clean_version"
    )
    
    local found_version=""
    for pattern in "${version_patterns[@]}"; do
        if grep -q "$pattern" "$CHANGELOG_FILE"; then
            found_version="$pattern"
            break
        fi
    done
    
    if [[ -z "$found_version" ]]; then
        log_error "Version $version not found in $CHANGELOG_FILE"
        log_info "Available versions:"
        grep "^## \[" "$CHANGELOG_FILE" | head -5 | sed 's/^/  /'
        exit 1
    fi
    
    log_info "Found version using pattern: $found_version"
    
    # Extract content between the version header and the next version header
    awk -v pattern="$found_version" '
    $0 ~ pattern { found=1; next }
    /^## \[/ && found { exit }
    /^## [0-9]/ && found { exit }
    found && /^$/ { print; next }
    found && !/^$/ { print }
    ' "$CHANGELOG_FILE" | sed '/^$/d'
    
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "Failed to extract release notes for version $version"
        exit 1
    fi
    
    log_success "Successfully extracted release notes for version $version"
}

# Run main function with all arguments
main "$@"