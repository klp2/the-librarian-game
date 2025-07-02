#!/bin/bash
set -euo pipefail

# Release Automation Setup Script
# This script helps configure the cross-repository release synchronization

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
PRIVATE_REPO=""
PUBLIC_REPO=""
GITHUB_USERNAME=""
TOKEN_SCOPES="contents:write,metadata:read,actions:read"

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

log_step() {
    echo -e "${BOLD}${BLUE}📋 $1${NC}"
}

# Help function
show_help() {
    cat << EOF
Release Automation Setup Script

This script helps you configure cross-repository release synchronization
between your private and public repositories.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -p, --private-repo    Private repository name (e.g., owner/private-repo)
    -u, --public-repo     Public repository name (e.g., owner/public-repo)  
    -h, --help           Show this help message

EXAMPLES:
    # Interactive setup
    $0

    # Setup with specified repositories
    $0 --private-repo myorg/private --public-repo myorg/public

WHAT THIS SCRIPT DOES:
    1. Validates GitHub CLI setup
    2. Creates fine-grained Personal Access Token (PAT)
    3. Configures repository secrets
    4. Tests permissions and access
    5. Validates workflow configuration

PREREQUISITES:
    - GitHub CLI (gh) installed and authenticated
    - Repository admin access to both private and public repositories
    - Internet connection for GitHub API access

EOF
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking Prerequisites"
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install from: https://cli.github.com/"
        exit 1
    fi
    
    # Check authentication
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated"
        log_info "Run 'gh auth login' to authenticate"
        exit 1
    fi
    
    # Get authenticated username
    GITHUB_USERNAME=$(gh api user --jq '.login')
    log_success "GitHub CLI authenticated as: $GITHUB_USERNAME"
    
    # Check jq availability
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed (required for JSON processing)"
        log_info "Install jq from: https://stedolan.github.io/jq/"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get repository information
get_repository_info() {
    log_step "Repository Configuration"
    
    if [ -z "$PRIVATE_REPO" ]; then
        echo
        read -p "Enter private repository name (e.g., owner/repo): " PRIVATE_REPO
    fi
    
    if [ -z "$PUBLIC_REPO" ]; then
        echo
        read -p "Enter public repository name (e.g., owner/repo): " PUBLIC_REPO
    fi
    
    # Validate repository format
    if [[ ! "$PRIVATE_REPO" =~ ^[^/]+/[^/]+$ ]]; then
        log_error "Invalid private repository format: $PRIVATE_REPO"
        log_info "Use format: owner/repository"
        exit 1
    fi
    
    if [[ ! "$PUBLIC_REPO" =~ ^[^/]+/[^/]+$ ]]; then
        log_error "Invalid public repository format: $PUBLIC_REPO"
        log_info "Use format: owner/repository"
        exit 1
    fi
    
    log_success "Repository configuration:"
    echo "  Private: $PRIVATE_REPO"
    echo "  Public:  $PUBLIC_REPO"
}

# Verify repository access
verify_repository_access() {
    log_step "Verifying Repository Access"
    
    # Check private repository access
    log_info "Checking access to private repository: $PRIVATE_REPO"
    if ! gh api repos/$PRIVATE_REPO &> /dev/null; then
        log_error "Cannot access private repository: $PRIVATE_REPO"
        log_info "Please verify:"
        log_info "  1. Repository name is correct"
        log_info "  2. You have admin access to the repository"
        log_info "  3. Repository exists and is accessible"
        exit 1
    fi
    log_success "Private repository access verified"
    
    # Check public repository access
    log_info "Checking access to public repository: $PUBLIC_REPO"
    if ! gh api repos/$PUBLIC_REPO &> /dev/null; then
        log_error "Cannot access public repository: $PUBLIC_REPO"
        log_info "Please verify:"
        log_info "  1. Repository name is correct"
        log_info "  2. You have admin access to the repository"
        log_info "  3. Repository exists and is accessible"
        exit 1
    fi
    log_success "Public repository access verified"
    
    # Check admin permissions on both repos
    log_info "Verifying admin permissions..."
    
    PRIVATE_PERMS=$(gh api repos/$PRIVATE_REPO --jq '.permissions.admin // false')
    PUBLIC_PERMS=$(gh api repos/$PUBLIC_REPO --jq '.permissions.admin // false')
    
    if [ "$PRIVATE_PERMS" != "true" ]; then
        log_error "Admin access required for private repository: $PRIVATE_REPO"
        exit 1
    fi
    
    if [ "$PUBLIC_PERMS" != "true" ]; then
        log_error "Admin access required for public repository: $PUBLIC_REPO"
        exit 1
    fi
    
    log_success "Admin permissions verified for both repositories"
}

# Create Personal Access Token
create_personal_access_token() {
    log_step "Personal Access Token Setup"
    
    log_info "Creating fine-grained Personal Access Token..."
    log_warning "You will need to authorize this token manually in your browser"
    
    echo
    log_info "The token will need the following permissions:"
    echo "  - Repository access: Both $PRIVATE_REPO and $PUBLIC_REPO"
    echo "  - Permissions: contents:write, metadata:read, actions:read"
    echo
    
    read -p "Continue with token creation? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Token creation cancelled"
        exit 0
    fi
    
    # Generate token name with timestamp
    TOKEN_NAME="release-sync-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Creating token with name: $TOKEN_NAME"
    log_info "Opening browser for token authorization..."
    
    # Create the token (this will open browser for authorization)
    if TOKEN_RESPONSE=$(gh auth token --hostname github.com --scope "$TOKEN_SCOPES" 2>/dev/null); then
        log_success "Token created successfully"
        GITHUB_TOKEN="$TOKEN_RESPONSE"
    else
        log_error "Failed to create token automatically"
        log_info "Please create a fine-grained PAT manually:"
        log_info "  1. Go to https://github.com/settings/personal-access-tokens/fine-grained"
        log_info "  2. Click 'Generate new token'"
        log_info "  3. Select both repositories: $PRIVATE_REPO and $PUBLIC_REPO"
        log_info "  4. Grant permissions: contents:write, metadata:read, actions:read"
        echo
        read -p "Enter your Personal Access Token: " -s GITHUB_TOKEN
        echo
    fi
    
    # Validate token
    log_info "Validating token..."
    if gh auth status --hostname github.com --token "$GITHUB_TOKEN" &> /dev/null; then
        log_success "Token validation successful"
    else
        log_error "Token validation failed"
        exit 1
    fi
}

# Configure repository secrets
configure_repository_secrets() {
    log_step "Configuring Repository Secrets"
    
    # Configure secrets in private repository (where the sync workflow runs)
    log_info "Setting up secrets in private repository: $PRIVATE_REPO"
    
    # Set CROSS_REPO_TOKEN
    echo "$GITHUB_TOKEN" | gh secret set CROSS_REPO_TOKEN --repo "$PRIVATE_REPO"
    log_success "CROSS_REPO_TOKEN secret configured"
    
    # Set PUBLIC_REPO_OWNER and PUBLIC_REPO_NAME
    PUBLIC_OWNER=$(echo "$PUBLIC_REPO" | cut -d'/' -f1)
    PUBLIC_NAME=$(echo "$PUBLIC_REPO" | cut -d'/' -f2)
    
    echo "$PUBLIC_OWNER" | gh secret set PUBLIC_REPO_OWNER --repo "$PRIVATE_REPO"
    echo "$PUBLIC_NAME" | gh secret set PUBLIC_REPO_NAME --repo "$PRIVATE_REPO"
    
    log_success "PUBLIC_REPO_OWNER secret configured"
    log_success "PUBLIC_REPO_NAME secret configured"
    
    # Verify secrets were set
    log_info "Verifying secrets configuration..."
    SECRETS=$(gh secret list --repo "$PRIVATE_REPO" --json name --jq '.[].name')
    
    for secret in "CROSS_REPO_TOKEN" "PUBLIC_REPO_OWNER" "PUBLIC_REPO_NAME"; do
        if echo "$SECRETS" | grep -q "$secret"; then
            log_success "Secret $secret is configured"
        else
            log_error "Secret $secret was not configured properly"
            exit 1
        fi
    done
}

# Test the configuration
test_configuration() {
    log_step "Testing Configuration"
    
    log_info "Testing cross-repository access with configured token..."
    
    # Test private repo access
    if gh api repos/$PRIVATE_REPO --token "$GITHUB_TOKEN" &> /dev/null; then
        log_success "Private repository access with token: OK"
    else
        log_error "Cannot access private repository with token"
        exit 1
    fi
    
    # Test public repo access
    if gh api repos/$PUBLIC_REPO --token "$GITHUB_TOKEN" &> /dev/null; then
        log_success "Public repository access with token: OK"
    else
        log_error "Cannot access public repository with token"
        exit 1
    fi
    
    # Test release access
    log_info "Testing release API access..."
    if gh api repos/$PRIVATE_REPO/releases --token "$GITHUB_TOKEN" &> /dev/null; then
        log_success "Private repository releases access: OK"
    else
        log_warning "Cannot access private repository releases (may be empty)"
    fi
    
    if gh api repos/$PUBLIC_REPO/releases --token "$GITHUB_TOKEN" &> /dev/null; then
        log_success "Public repository releases access: OK"
    else
        log_warning "Cannot access public repository releases (may be empty)"
    fi
}

# Check workflow files
check_workflow_files() {
    log_step "Workflow Configuration Check"
    
    SYNC_WORKFLOW="$PRIVATE_REPO/.github/workflows/sync-release.yml"
    VALIDATE_WORKFLOW="$PUBLIC_REPO/.github/workflows/validate-sync.yml"
    
    log_info "Checking for required workflow files..."
    
    # Check sync workflow in private repo
    if gh api repos/$PRIVATE_REPO/contents/.github/workflows/sync-release.yml &> /dev/null; then
        log_success "Sync workflow found in private repository"
    else
        log_warning "Sync workflow not found in private repository"
        log_info "Copy the sync-release.yml workflow to: $PRIVATE_REPO/.github/workflows/"
    fi
    
    # Check validation workflow in public repo
    if gh api repos/$PUBLIC_REPO/contents/.github/workflows/validate-sync.yml &> /dev/null; then
        log_success "Validation workflow found in public repository"
    else
        log_warning "Validation workflow not found in public repository"
        log_info "The validate-sync.yml workflow should be in: $PUBLIC_REPO/.github/workflows/"
    fi
}

# Generate summary report
generate_summary() {
    log_step "Setup Summary"
    
    cat << EOF

🎉 Release Automation Setup Complete!

CONFIGURATION:
  Private Repository: $PRIVATE_REPO
  Public Repository:  $PUBLIC_REPO
  GitHub User:        $GITHUB_USERNAME

CONFIGURED SECRETS (in $PRIVATE_REPO):
  ✅ CROSS_REPO_TOKEN     - Personal Access Token for cross-repo access
  ✅ PUBLIC_REPO_OWNER    - Public repository owner ($PUBLIC_OWNER)
  ✅ PUBLIC_REPO_NAME     - Public repository name ($PUBLIC_NAME)

NEXT STEPS:
  1. Copy the sync-release.yml workflow to $PRIVATE_REPO/.github/workflows/
  2. Ensure validate-sync.yml workflow is in $PUBLIC_REPO/.github/workflows/
  3. Test the automation by creating a release in the private repository
  4. Monitor the workflow execution and check for any issues

TESTING:
  # Test manual sync
  cd $PUBLIC_REPO
  ./scripts/emergency-sync.sh v1.0.0

  # Test with dry run
  DRY_RUN=true ./scripts/emergency-sync.sh v1.0.0

TROUBLESHOOTING:
  - Check workflow logs in GitHub Actions tab
  - Verify token permissions if sync fails
  - Use emergency sync script as backup
  - Review RELEASE_AUTOMATION_GUIDE.md for detailed instructions

For support, see the Release Automation Guide or check the repository issues.

EOF
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--private-repo)
                PRIVATE_REPO="$2"
                shift 2
                ;;
            -u|--public-repo)
                PUBLIC_REPO="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Print header
    echo
    log_info "🚀 Release Automation Setup Script"
    log_info "This script will configure cross-repository release synchronization"
    echo
    
    # Execute setup steps
    check_prerequisites
    get_repository_info
    verify_repository_access
    create_personal_access_token
    configure_repository_secrets
    test_configuration
    check_workflow_files
    generate_summary
}

# Execute main function with all arguments
main "$@"