#!/bin/bash
#=============================================================================
# ZZCOLLAB Workflow Installer
# Automatically installs appropriate GitHub Actions workflow based on profile
#
# Usage: ./scripts/install-workflows.sh [--dry-run] [--verbose]
#
# Reads:
#   - config.yaml (enabled profiles)
#   - profiles.yaml (workflow_type for each profile)
#
# Installs:
#   - .github/workflows/r-package-{type}.yml → .github/workflows/r-package.yml
#   - Removes render-paper.yml if present
#=============================================================================

set -euo pipefail

# Configuration
CONFIG_FILE="${1:-.}/config.yaml"
PROFILES_FILE="${1:-.}/templates/profiles.yaml"
WORKFLOW_TEMPLATES_DIR="${1:-.}/templates/workflows"
WORKFLOW_OUTPUT_DIR="${1:-.}/.github/workflows"
DRY_RUN=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#=============================================================================
# FUNCTIONS
#=============================================================================

usage() {
    cat << EOF
Usage: ./scripts/install-workflows.sh [OPTIONS]

OPTIONS:
  --dry-run       Show what would be done without making changes
  --verbose       Print detailed output
  --help          Show this help message

EXAMPLE:
  ./scripts/install-workflows.sh
  ./scripts/install-workflows.sh --dry-run --verbose

EOF
}

log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

log_error() {
    echo -e "${RED}❌ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}  → ${NC}$1"
    fi
}

#=============================================================================
# ARGUMENT PARSING
#=============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

#=============================================================================
# VALIDATION
#=============================================================================

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "config.yaml not found at: $CONFIG_FILE"
    exit 1
fi

if [ ! -f "$PROFILES_FILE" ]; then
    log_error "profiles.yaml not found at: $PROFILES_FILE"
    exit 1
fi

#=============================================================================
# MAIN WORKFLOW
#=============================================================================

echo ""
echo "=========================================="
echo "ZZCOLLAB Workflow Installer"
echo "=========================================="
echo ""

log_info "Reading configuration from: $CONFIG_FILE"
log_verbose "Profiles database: $PROFILES_FILE"

# Find all enabled profiles
enabled_profiles=$(grep -A 1 "enabled: true" "$CONFIG_FILE" | grep -B 1 "enabled: true" | grep "^  [a-z]" | sed 's/:.*//' | tr -d ' ')

if [ -z "$enabled_profiles" ]; then
    log_warning "No enabled profiles found in config.yaml"
    exit 0
fi

log_info "Found enabled profiles:"
echo "$enabled_profiles" | while read profile; do
    log_verbose "$profile"
done

# Get workflow type from first enabled profile
# (Most projects use one profile; if multiple, use first)
primary_profile=$(echo "$enabled_profiles" | head -1)

log_info "Using primary profile: $primary_profile"

# Extract workflow_type from profiles.yaml
workflow_type=$(grep -A 20 "^${primary_profile}:" "$PROFILES_FILE" | grep "workflow_type:" | awk '{print $2}' | tr -d '"')

if [ -z "$workflow_type" ]; then
    log_error "No workflow_type found for profile: $primary_profile"
    log_error "Ensure profiles.yaml includes 'workflow_type:' field"
    exit 1
fi

log_success "Profile '$primary_profile' uses workflow type: $workflow_type"

# Validate workflow template exists
workflow_template="$WORKFLOW_TEMPLATES_DIR/r-package-${workflow_type}.yml"

if [ ! -f "$workflow_template" ]; then
    log_error "Workflow template not found: $workflow_template"
    log_error "Available workflow types: package-dev, analysis, blog, shiny"
    exit 1
fi

# Create .github/workflows directory if needed
if [ ! -d "$WORKFLOW_OUTPUT_DIR" ]; then
    if [ "$DRY_RUN" = true ]; then
        log_verbose "[DRY RUN] Would create: $WORKFLOW_OUTPUT_DIR"
    else
        mkdir -p "$WORKFLOW_OUTPUT_DIR"
        log_verbose "Created directory: $WORKFLOW_OUTPUT_DIR"
    fi
fi

# Install workflow
workflow_output="$WORKFLOW_OUTPUT_DIR/r-package.yml"

if [ "$DRY_RUN" = true ]; then
    log_verbose "[DRY RUN] Would copy: $workflow_template → $workflow_output"
    log_success "[DRY RUN] Would install workflow: r-package-${workflow_type}.yml"
else
    cp "$workflow_template" "$workflow_output"
    log_success "Installed workflow: $workflow_output"
    log_verbose "Size: $(du -h "$workflow_output" | cut -f1)"
fi

# Remove legacy render-paper.yml if present
render_paper="$WORKFLOW_OUTPUT_DIR/render-paper.yml"
if [ -f "$render_paper" ]; then
    if [ "$DRY_RUN" = true ]; then
        log_verbose "[DRY RUN] Would delete: $render_paper"
    else
        rm "$render_paper"
        log_success "Removed legacy: render-paper.yml"
    fi
fi

# Summary
echo ""
echo "=========================================="
if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN - No changes made"
else
    log_success "Workflow installation complete"
fi
echo "=========================================="
echo ""
log_info "Workflow type: $workflow_type"
log_info "Profile: $primary_profile"
log_info "Output: .github/workflows/r-package.yml"
echo ""

if [ "$DRY_RUN" = false ]; then
    log_info "Next steps:"
    log_verbose "1. Review .github/workflows/r-package.yml"
    log_verbose "2. Commit to git: git add .github/workflows/"
    log_verbose "3. Push to GitHub: git push origin main"
    echo ""
fi

exit 0
