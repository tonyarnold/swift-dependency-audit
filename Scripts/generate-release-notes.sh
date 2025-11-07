#!/bin/bash

# SwiftDependencyAudit Release Notes Generator
# Extracts release notes from CHANGELOG.md for a specific version
# Can optionally update the CHANGELOG.md to convert "Unreleased" to a versioned release
# Usage: ./generate-release-notes.sh <version> [--update-changelog]

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"

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

# Function to update changelog
update_changelog() {
    local version="$1"
    local clean_version="${version#v}"
    local current_date
    current_date="$(date +%Y-%m-%d)"

    log_info "Updating CHANGELOG.md to release version $version"

    # Create backup
    cp "$CHANGELOG_FILE" "${CHANGELOG_FILE}.backup"
    log_info "Created backup: ${CHANGELOG_FILE}.backup"

    # Create temporary file
    local temp_file
    temp_file="$(mktemp)"

    # Process the changelog
    awk -v version="$clean_version" -v date="$current_date" '
    BEGIN {
        updated_unreleased = 0
        in_unreleased = 0
        unreleased_content = ""
    }

    # When we hit [Unreleased], start capturing content
    /^## \[Unreleased\]$/ && !updated_unreleased {
        in_unreleased = 1
        updated_unreleased = 1
        next
    }

    # When we hit the next section header while in unreleased, output everything
    /^## / && in_unreleased {
        # Output the new structure
        print "## [Unreleased]"
        print ""
        print "## [" version "] - " date

        # Output captured content (now under the versioned section)
        if (unreleased_content != "") {
            print unreleased_content
        }

        # Now print the current line (next version header) and stop capturing
        print $0
        in_unreleased = 0
        next
    }

    # Capture content while in unreleased section
    in_unreleased {
        if (unreleased_content == "") {
            unreleased_content = $0
        } else {
            unreleased_content = unreleased_content "\n" $0
        }
        next
    }

    # Update the link at the bottom for the new version
    /^\[Unreleased\]:/ {
        # Extract the repository URL pattern
        gsub(/compare\/.*\.\.\.HEAD/, "compare/v" version "...HEAD")
        print
        print "[" version "]: https://github.com/yourusername/SwiftDependencyAudit/releases/tag/v" version
        next
    }

    # Print all other lines unchanged
    { print }
    ' "$CHANGELOG_FILE" > "$temp_file"

    # Replace original with updated content
    mv "$temp_file" "$CHANGELOG_FILE"

    log_success "Successfully updated CHANGELOG.md"
    log_info "- Converted [Unreleased] to [$clean_version] - $current_date"
    log_info "- Added new empty [Unreleased] section"
    log_info "- Updated version links"
}

# Main function
main() {
    # Parse arguments
    local version=""
    local update_changelog=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --update-changelog)
                update_changelog=true
                shift
                ;;
            --help|-h)
                echo "Usage: $SCRIPT_NAME <version> [--update-changelog]"
                echo ""
                echo "Arguments:"
                echo "  <version>            Version to extract/create (e.g., v1.0.0, 1.0.0, unreleased)"
                echo ""
                echo "Options:"
                echo "  --update-changelog   Update CHANGELOG.md to convert [Unreleased] to versioned release"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "Examples:"
                echo "  $SCRIPT_NAME v1.0.0                    # Extract release notes for v1.0.0"
                echo "  $SCRIPT_NAME unreleased                # Extract unreleased changes"
                echo "  $SCRIPT_NAME v1.1.0 --update-changelog # Extract notes and update changelog"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                log_error "Use --help for usage information"
                exit 1
                ;;
            *)
                if [[ -z "$version" ]]; then
                    version="$1"
                else
                    log_error "Multiple versions specified: $version and $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Check required arguments
    if [[ -z "$version" ]]; then
        log_error "Usage: $SCRIPT_NAME <version> [--update-changelog]"
        log_error "Example: $SCRIPT_NAME v1.0.0 --update-changelog"
        log_error "Use --help for more information"
        exit 1
    fi

    # Remove 'v' prefix if present for matching
    local clean_version="${version#v}"

    # Check if CHANGELOG.md exists
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        log_error "CHANGELOG.md not found in current directory"
        exit 1
    fi

    # Update changelog if requested
    if [[ "$update_changelog" == true ]]; then
        if [[ "$clean_version" == "unreleased" ]] || [[ "$version" == "unreleased" ]]; then
            log_error "Cannot update changelog for 'unreleased' version"
            log_error "Please specify a specific version (e.g., v1.0.0)"
            exit 1
        fi

        # Check if unreleased section exists
        if ! grep -q "^## \[Unreleased\]" "$CHANGELOG_FILE"; then
            log_error "No [Unreleased] section found in $CHANGELOG_FILE"
            log_error "Cannot update changelog without unreleased content"
            exit 1
        fi

        # Update the changelog
        update_changelog "$version"
        log_info ""
    fi

    log_info "Extracting release notes for version $version from $CHANGELOG_FILE"

    # Extract the unreleased section if no specific version is provided or version is "unreleased"
    if [[ "$clean_version" == "unreleased" ]] || [[ "$version" == "unreleased" ]]; then
        log_info "Extracting unreleased changes..."

        # Extract content between "## [Unreleased]" and the next "## [" line
        awk '
        /^## \[Unreleased\]/ { found=1; next }
        /^## \[/ && found { exit }
        found { print }
        ' "$CHANGELOG_FILE"

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
