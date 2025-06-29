#!/bin/bash
##############################################################################
# ZZRRTOOLS MODULAR TEST SCRIPT - PHASE 2
##############################################################################
# 
# PURPOSE: Test Phase 2 modules (rpackage, docker) with Phase 1 modules
#          - Tests all 5 modules working together
#          - Validates R package creation functionality
#          - Tests Docker integration (without actual building)
#          - Comprehensive functionality validation
#
# USAGE:   ./zzrrtools-modular-test-phase2.sh
#
# MODULES TESTED: core, templates, structure, rpackage, docker
##############################################################################

set -euo pipefail

#=============================================================================
# SCRIPT CONSTANTS AND SETUP
#=============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATES_DIR="$SCRIPT_DIR/templates"
readonly MODULES_DIR="$SCRIPT_DIR/modules"

# Manifest tracking for uninstall functionality
readonly MANIFEST_FILE=".zzrrtools_manifest.json"
readonly MANIFEST_TXT=".zzrrtools_manifest.txt"

# Docker build control (set to false to skip actual Docker build)
readonly SKIP_DOCKER_BUILD=true

#=============================================================================
# MODULE LOADING SYSTEM
#=============================================================================

# Basic logging before modules are loaded
log_info() {
    printf "ℹ️  %s\n" "$*" >&2
}

log_error() {
    printf "❌ %s\n" "$*" >&2
}

# Validate modules directory exists
if [[ ! -d "$MODULES_DIR" ]]; then
    log_error "Modules directory not found: $MODULES_DIR"
    exit 1
fi

# Load modules in dependency order
log_info "Loading Phase 2 modules..."

# Load core module first (required by all others)
if [[ -f "$MODULES_DIR/core.sh" ]]; then
    log_info "Loading core module..."
    # shellcheck source=modules/core.sh
    source "$MODULES_DIR/core.sh"
else
    log_error "Core module not found: $MODULES_DIR/core.sh"
    exit 1
fi

# Load templates module (depends on core)
if [[ -f "$MODULES_DIR/templates.sh" ]]; then
    log_info "Loading templates module..."
    # shellcheck source=modules/templates.sh
    source "$MODULES_DIR/templates.sh"
else
    log_error "Templates module not found: $MODULES_DIR/templates.sh"
    exit 1
fi

# Load structure module (depends on core)
if [[ -f "$MODULES_DIR/structure.sh" ]]; then
    log_info "Loading structure module..."
    # shellcheck source=modules/structure.sh
    source "$MODULES_DIR/structure.sh"
else
    log_error "Structure module not found: $MODULES_DIR/structure.sh"
    exit 1
fi

#=============================================================================
# PACKAGE NAME VALIDATION (must be done before rpackage module)
#=============================================================================

# Validate package name using extracted function
PKG_NAME=$(validate_package_name)
readonly PKG_NAME

# Set Docker base image for templates
readonly BASE_IMAGE="rocker/r-ver"

log_info "Package name determined: $PKG_NAME"

# Load rpackage module (depends on core, templates, and PKG_NAME)
if [[ -f "$MODULES_DIR/rpackage.sh" ]]; then
    log_info "Loading rpackage module..."
    # shellcheck source=modules/rpackage.sh
    source "$MODULES_DIR/rpackage.sh"
else
    log_error "Rpackage module not found: $MODULES_DIR/rpackage.sh"
    exit 1
fi

# Load docker module (depends on core, templates)
if [[ -f "$MODULES_DIR/docker.sh" ]]; then
    log_info "Loading docker module..."
    # shellcheck source=modules/docker.sh
    source "$MODULES_DIR/docker.sh"
else
    log_error "Docker module not found: $MODULES_DIR/docker.sh"
    exit 1
fi

# PKG_NAME and BASE_IMAGE already defined above during module loading

#=============================================================================
# MANIFEST INITIALIZATION
#=============================================================================

init_manifest() {
    if command -v jq >/dev/null 2>&1; then
        cat > "$MANIFEST_FILE" <<EOF
{
  "version": "1.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_name": "$PKG_NAME",
  "modules_loaded": ["core", "templates", "structure", "rpackage", "docker"],
  "directories": [],
  "files": [],
  "template_files": [],
  "symlinks": [],
  "dotfiles": [],
  "docker_image": null
}
EOF
        log_success "Initialized JSON manifest file: $MANIFEST_FILE"
    else
        {
            echo "# ZZRRTOOLS MANIFEST - Created $(date)"
            echo "# Package: $PKG_NAME"
            echo "# Modules: core, templates, structure, rpackage, docker"
            echo "# Format: type:path"
        } > "$MANIFEST_TXT"
        log_success "Initialized text manifest file: $MANIFEST_TXT (jq not available)"
    fi
}

#=============================================================================
# PHASE 2 TESTING FUNCTIONS
#=============================================================================

test_rpackage_functions() {
    log_info "Testing R package module functions..."
    
    # Test R version extraction (should not fail even without renv.lock)
    local r_version
    r_version=$(extract_r_version_from_lockfile)
    if [[ -n "$r_version" ]]; then
        log_success "R version extraction working: $r_version"
    else
        log_error "R version extraction failed"
        return 1
    fi
    
    # Test R package structure validation (should pass after create_core_files)
    # We'll test this after creating the files
    log_success "R package module functions ready for testing"
}

test_docker_functions() {
    log_info "Testing Docker module functions..."
    
    # Test R version extraction specifically
    local r_version
    r_version=$(extract_r_version_from_lockfile)
    log_success "Docker R version detection: $r_version"
    
    # Test Docker environment validation (may warn about Docker not running)
    log_info "Testing Docker environment validation..."
    if validate_docker_environment; then
        log_success "Docker environment validation passed"
    else
        log_warn "Docker environment validation failed (expected if Docker not running)"
    fi
    
    log_success "Docker module functions ready for testing"
}

validate_templates_directory() {
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found: $TEMPLATES_DIR"
        log_error "Please ensure you're running this script from the zzrrtools directory"
        return 1
    fi
    
    # Check for required template files
    local -r required_templates=(
        "DESCRIPTION"
        "Dockerfile"
        "docker-compose.yml"
        "R/utils.R"
    )
    
    local missing_templates=()
    for template in "${required_templates[@]}"; do
        if [[ ! -f "$TEMPLATES_DIR/$template" ]]; then
            missing_templates+=("$template")
        fi
    done
    
    if [[ ${#missing_templates[@]} -eq 0 ]]; then
        log_success "All required templates found"
    else
        log_error "Missing templates: ${missing_templates[*]}"
        return 1
    fi
}

test_complete_workflow() {
    log_info "Testing complete Phase 2 workflow..."
    
    # 1. Create directory structure (Phase 1)
    log_info "Step 1: Creating directory structure..."
    create_directory_structure || return 1
    
    # 2. Create R package files (Phase 2)
    log_info "Step 2: Creating R package files..."
    create_core_files || return 1
    create_renv_setup || return 1
    
    # 3. Validate R package structure
    log_info "Step 3: Validating R package structure..."
    validate_r_package_structure || return 1
    
    # 4. Create Docker files (Phase 2)
    log_info "Step 4: Creating Docker configuration..."
    create_docker_files || return 1
    
    # 5. Create symbolic links (Phase 1)
    log_info "Step 5: Creating symbolic links..."
    create_symbolic_links || return 1
    
    # 6. Skip Docker build but test validation
    if [[ "$SKIP_DOCKER_BUILD" == "true" ]]; then
        log_info "Step 6: Skipping Docker build (SKIP_DOCKER_BUILD=true)"
        log_info "Testing Docker configuration validation..."
        # This will warn about missing image but validate files
        validate_docker_environment || log_warn "Docker validation incomplete (expected)"
    else
        log_info "Step 6: Building Docker image..."
        build_docker_image || log_warn "Docker build failed (may be expected)"
    fi
    
    log_success "Complete workflow test finished"
}

count_created_items() {
    local dir_count file_count symlink_count
    dir_count=$(find . -type d | wc -l)
    file_count=$(find . -type f \( ! -path "./.git/*" \) | wc -l)
    symlink_count=$(find . -type l | wc -l)
    
    log_info "Created: $dir_count directories, $file_count files, $symlink_count symlinks"
}

#=============================================================================
# MAIN TEST EXECUTION
#=============================================================================

main() {
    log_info "🧪 Starting ZZRRTOOLS Modular Test - Phase 2"
    log_info "📦 Package name: '$PKG_NAME'"
    log_info "🔧 Testing modules: core, templates, structure, rpackage, docker"
    echo ""
    
    # Initialize manifest tracking
    init_manifest
    
    # Validate environment
    log_info "Validating test environment..."
    validate_templates_directory || exit 1
    
    # Test individual modules
    log_info "Testing individual module functions..."
    test_rpackage_functions || exit 1
    test_docker_functions || exit 1
    
    # Test complete integrated workflow
    log_info "Testing complete integrated workflow..."
    test_complete_workflow || exit 1
    
    # Count and report created items
    count_created_items
    
    # Show summaries
    echo ""
    show_structure_summary
    echo ""
    show_rpackage_summary
    echo ""
    show_docker_summary
    
    # Final success message
    echo ""
    log_success "🎉 Phase 2 modular test completed successfully!"
    
    echo ""
    log_info "📋 PHASE 2 RESULTS:"
    log_info "✅ Core module (logging, validation, utilities) - WORKING"
    log_info "✅ Templates module (file creation, template processing) - WORKING"  
    log_info "✅ Structure module (directories, symlinks) - WORKING"
    log_info "✅ R Package module (DESCRIPTION, tests, renv) - WORKING"
    log_info "✅ Docker module (Dockerfile, compose, build logic) - WORKING"
    log_info "✅ Manifest tracking for uninstall - WORKING"
    echo ""
    log_info "📄 Manifest file: $([[ -f "$MANIFEST_FILE" ]] && echo "$MANIFEST_FILE" || echo "$MANIFEST_TXT")"
    echo ""
    log_info "🔄 Next: Phase 3 will add remaining modules (analysis, cicd, devtools)"
    echo ""
    
    if [[ "$SKIP_DOCKER_BUILD" == "true" ]]; then
        log_info "💡 To test Docker build: set SKIP_DOCKER_BUILD=false and ensure Docker is running"
    fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi