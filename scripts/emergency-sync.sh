#!/bin/bash
set -euo pipefail

# Emergency Release Sync Script
# Use this when automation fails - provides reliable manual backup procedure
# Usage: ./emergency-sync.sh [TAG] [PRIVATE_REPO] [PUBLIC_REPO]

# Default values
DEFAULT_PRIVATE_REPO="klp2/the-librarian"
DEFAULT_PUBLIC_REPO="klp2/the-librarian-game"

# Configuration
PRIVATE_REPO="${2:-$DEFAULT_PRIVATE_REPO}"
PUBLIC_REPO="${3:-$DEFAULT_PUBLIC_REPO}"
TAG="${1:-}"
TEMP_DIR="emergency-sync-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Help function
show_help() {
    cat << EOF
Emergency Release Sync Script

USAGE:
    $0 [TAG] [PRIVATE_REPO] [PUBLIC_REPO]

ARGUMENTS:
    TAG           Release tag to sync (e.g., v1.0.0). If omitted, syncs latest release.
    PRIVATE_REPO  Private repository name (default: $DEFAULT_PRIVATE_REPO)
    PUBLIC_REPO   Public repository name (default: $DEFAULT_PUBLIC_REPO)

EXAMPLES:
    # Sync latest release between default repositories
    $0

    # Sync specific tag
    $0 v1.0.0

    # Sync between custom repositories
    $0 v1.0.0 myorg/private-repo myorg/public-repo

PREREQUISITES:
    - GitHub CLI (gh) installed and authenticated
    - GITHUB_TOKEN environment variable (optional, for enhanced rate limits)
    - Write access to public repository

ENVIRONMENT VARIABLES:
    GITHUB_TOKEN  Personal access token (recommended for rate limiting)
    DRY_RUN       Set to 'true' to preview actions without making changes

EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed. Please install it first."
        log_info "Install: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
        exit 1
    fi
    
    # Check if we can access both repositories
    if ! gh api repos/$PRIVATE_REPO &> /dev/null; then
        log_error "Cannot access private repository: $PRIVATE_REPO"
        log_info "Please check repository name and permissions."
        exit 1
    fi
    
    if ! gh api repos/$PUBLIC_REPO &> /dev/null; then
        log_error "Cannot access public repository: $PUBLIC_REPO"
        log_info "Please check repository name and write permissions."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get release information
get_release_info() {
    log_info "Getting release information from $PRIVATE_REPO..."
    
    if [ -n "$TAG" ]; then
        # Get specific tag
        if ! RELEASE_INFO=$(gh api repos/$PRIVATE_REPO/releases/tags/$TAG 2>/dev/null); then
            log_error "Release tag '$TAG' not found in $PRIVATE_REPO"
            exit 1
        fi
        log_info "Found specific release: $TAG"
    else
        # Get latest release
        if ! RELEASE_INFO=$(gh api repos/$PRIVATE_REPO/releases/latest 2>/dev/null); then
            log_error "No releases found in $PRIVATE_REPO"
            exit 1
        fi
        TAG=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
        log_info "Found latest release: $TAG"
    fi
    
    # Extract release details
    RELEASE_NAME=$(echo "$RELEASE_INFO" | jq -r '.name // .tag_name')
    RELEASE_BODY=$(echo "$RELEASE_INFO" | jq -r '.body // ""')
    IS_PRERELEASE=$(echo "$RELEASE_INFO" | jq -r '.prerelease')
    IS_DRAFT=$(echo "$RELEASE_INFO" | jq -r '.draft')
    ASSET_COUNT=$(echo "$RELEASE_INFO" | jq -r '.assets | length')
    
    log_success "Release info: '$RELEASE_NAME' with $ASSET_COUNT assets"
    
    if [ "$IS_PRERELEASE" = "true" ]; then
        log_warning "This is a prerelease"
    fi
    
    if [ "$IS_DRAFT" = "true" ]; then
        log_warning "This is a draft release"
    fi
}

# Check if release exists in public repo
check_existing_release() {
    log_info "Checking if release $TAG exists in $PUBLIC_REPO..."
    
    if gh api repos/$PUBLIC_REPO/releases/tags/$TAG &> /dev/null; then
        log_warning "Release $TAG already exists in $PUBLIC_REPO"
        
        if [ "${FORCE:-}" != "true" ]; then
            echo
            read -p "Do you want to overwrite the existing release? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Sync cancelled by user"
                exit 0
            fi
            FORCE="true"
        fi
        
        log_info "Will overwrite existing release"
    else
        log_success "Release $TAG does not exist in $PUBLIC_REPO"
    fi
}

# Download assets from private repository
download_assets() {
    log_info "Creating temporary directory: $TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    if [ "$ASSET_COUNT" -eq 0 ]; then
        log_info "No assets to download"
        return
    fi
    
    log_info "Downloading $ASSET_COUNT assets from $PRIVATE_REPO..."
    
    if [ "${DRY_RUN:-}" = "true" ]; then
        log_info "DRY RUN: Would download assets to $TEMP_DIR"
        return
    fi
    
    if ! gh release download "$TAG" --repo "$PRIVATE_REPO" --dir "$TEMP_DIR"; then
        log_error "Failed to download assets from $PRIVATE_REPO"
        cleanup
        exit 1
    fi
    
    # List downloaded files
    log_success "Downloaded assets:"
    ls -la "$TEMP_DIR/" | tail -n +2 | while read -r line; do
        echo "  $line"
    done
    
    # Generate checksums
    log_info "Generating checksums..."
    cd "$TEMP_DIR"
    if ls *.tar.gz *.zip *.exe *.dmg 2>/dev/null | head -1 &> /dev/null; then
        find . -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.exe" -o -name "*.dmg" \) \
            -exec sha256sum {} + > checksums.txt
        log_success "Checksums generated"
    else
        log_info "No binary files found for checksum generation"
    fi
    cd - > /dev/null
}

# Delete existing release if needed
delete_existing_release() {
    if [ "${FORCE:-}" = "true" ]; then
        log_info "Deleting existing release $TAG from $PUBLIC_REPO..."
        
        if [ "${DRY_RUN:-}" = "true" ]; then
            log_info "DRY RUN: Would delete existing release"
            return
        fi
        
        if gh release delete "$TAG" --repo "$PUBLIC_REPO" --yes; then
            log_success "Existing release deleted"
        else
            log_warning "Failed to delete existing release (it may not exist)"
        fi
    fi
}

# Create release in public repository
create_public_release() {
    log_info "Creating release $TAG in $PUBLIC_REPO..."
    
    # Prepare release command
    RELEASE_CMD="gh release create \"$TAG\" --repo \"$PUBLIC_REPO\" --title \"$RELEASE_NAME\""
    
    # Add release notes
    if [ -n "$RELEASE_BODY" ]; then
        echo "$RELEASE_BODY" > "$TEMP_DIR/RELEASE_NOTES.md"
        RELEASE_CMD="$RELEASE_CMD --notes-file \"$TEMP_DIR/RELEASE_NOTES.md\""
    else
        RELEASE_CMD="$RELEASE_CMD --notes \"Release $TAG\""
    fi
    
    # Add flags
    if [ "$IS_PRERELEASE" = "true" ]; then
        RELEASE_CMD="$RELEASE_CMD --prerelease"
    fi
    
    if [ "$IS_DRAFT" = "true" ]; then
        RELEASE_CMD="$RELEASE_CMD --draft"
    fi
    
    # Add assets if any
    if [ "$ASSET_COUNT" -gt 0 ] && [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR" 2>/dev/null | grep -v RELEASE_NOTES.md | wc -l)" -gt 0 ]; then
        ASSETS=$(find "$TEMP_DIR" -type f ! -name "RELEASE_NOTES.md" | tr '\n' ' ')
        RELEASE_CMD="$RELEASE_CMD $ASSETS"
    fi
    
    if [ "${DRY_RUN:-}" = "true" ]; then
        log_info "DRY RUN: Would execute:"
        echo "  $RELEASE_CMD"
        return
    fi
    
    # Execute release creation
    if eval "$RELEASE_CMD"; then
        log_success "Release created successfully!"
        RELEASE_URL="https://github.com/$PUBLIC_REPO/releases/tag/$TAG"
        log_success "Release URL: $RELEASE_URL"
    else
        log_error "Failed to create release in $PUBLIC_REPO"
        cleanup
        exit 1
    fi
}

# Verify sync success
verify_sync() {
    if [ "${DRY_RUN:-}" = "true" ]; then
        log_info "DRY RUN: Would verify sync success"
        return
    fi
    
    log_info "Verifying sync success..."
    
    if PUBLIC_RELEASE_INFO=$(gh api repos/$PUBLIC_REPO/releases/tags/$TAG 2>/dev/null); then
        PUBLIC_ASSET_COUNT=$(echo "$PUBLIC_RELEASE_INFO" | jq -r '.assets | length')
        
        log_success "Verification results:"
        echo "  - Tag: $TAG"
        echo "  - Private repo assets: $ASSET_COUNT"
        echo "  - Public repo assets: $PUBLIC_ASSET_COUNT"
        
        if [ "$ASSET_COUNT" -gt 0 ] && [ "$PUBLIC_ASSET_COUNT" -lt "$ASSET_COUNT" ]; then
            log_warning "Public repository has fewer assets than private repository"
            log_warning "This might indicate an upload failure"
        else
            log_success "Asset counts match (allowing for additional files like checksums)"
        fi
    else
        log_error "Failed to verify public release"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        log_info "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Main execution
main() {
    # Handle help flag
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        show_help
        exit 0
    fi
    
    # Print header
    echo
    log_info "Emergency Release Sync Script"
    log_info "Private repo: $PRIVATE_REPO"
    log_info "Public repo:  $PUBLIC_REPO"
    
    if [ "${DRY_RUN:-}" = "true" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    
    echo
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Execute sync steps
    check_prerequisites
    get_release_info
    check_existing_release
    download_assets
    delete_existing_release
    create_public_release
    verify_sync
    
    echo
    log_success "🎉 Release sync completed successfully!"
    
    if [ "${DRY_RUN:-}" != "true" ]; then
        echo
        log_info "Release URL: https://github.com/$PUBLIC_REPO/releases/tag/$TAG"
        log_info "Next steps:"
        echo "  1. Verify the release in the public repository"
        echo "  2. Test download links and checksums"
        echo "  3. Update any documentation that references the release"
    fi
}

# Execute main function with all arguments
main "$@"