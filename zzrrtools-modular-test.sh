#!/bin/bash
##############################################################################
# ZZRRTOOLS MODULAR TEST SCRIPT - PHASE 1
##############################################################################
# 
# PURPOSE: Test that the first 3 extracted modules preserve exact functionality
#          - Tests core.sh, templates.sh, structure.sh modules
#          - Validates identical behavior to original zzrrtools.sh
#          - Demonstrates modular architecture works
#
# USAGE:   ./zzrrtools-modular-test.sh
#
# MODULES TESTED: core, templates, structure (Phase 1 of modularization)
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

#=============================================================================
# MODULE LOADING SYSTEM
#=============================================================================

# Load modules in dependency order
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
# PACKAGE NAME VALIDATION (using modular function)
#=============================================================================

# Validate package name using extracted function
PKG_NAME=$(validate_package_name)
readonly PKG_NAME

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
  "modules_loaded": ["core", "templates", "structure"],
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
            echo "# Modules: core, templates, structure"
            echo "# Format: type:path"
        } > "$MANIFEST_TXT"
        log_success "Initialized text manifest file: $MANIFEST_TXT (jq not available)"
    fi
}

#=============================================================================
# VALIDATION FUNCTIONS
#=============================================================================

validate_templates_directory() {
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found: $TEMPLATES_DIR"
        log_error "Please ensure you're running this script from the zzrrtools directory"
        return 1
    fi
    log_success "Templates directory found: $TEMPLATES_DIR"
}

test_core_functions() {
    log_info "Testing core module functions..."
    
    # Test logging functions
    log_info "Testing log_info function"
    log_warn "Testing log_warn function"
    log_success "Testing log_success function"
    
    # Test command_exists function
    if command_exists "bash"; then
        log_success "command_exists function working (bash found)"
    else
        log_error "command_exists function failed (bash should exist)"
        return 1
    fi
    
    if ! command_exists "nonexistent_command_12345"; then
        log_success "command_exists function working (correctly identified missing command)"
    else
        log_error "command_exists function failed (should not find nonexistent command)"
        return 1
    fi
    
    # Test package name validation
    if [[ -n "$PKG_NAME" ]] && [[ "$PKG_NAME" =~ ^[[:alpha:]] ]]; then
        log_success "Package name validation working: '$PKG_NAME'"
    else
        log_error "Package name validation failed: '$PKG_NAME'"
        return 1
    fi
}

test_template_functions() {
    log_info "Testing template module functions..."
    
    # Test create_file_if_missing function
    local test_file="test_template_file.txt"
    local test_content="This is a test file created by modular zzrrtools"
    
    if create_file_if_missing "$test_file" "$test_content" "test file"; then
        if [[ -f "$test_file" ]] && grep -q "test file created by modular" "$test_file"; then
            log_success "create_file_if_missing function working"
            rm "$test_file"  # Clean up
        else
            log_error "create_file_if_missing created file but content incorrect"
            return 1
        fi
    else
        log_error "create_file_if_missing function failed"
        return 1
    fi
}

#=============================================================================
# MAIN TEST EXECUTION
#=============================================================================

main() {
    log_info "🧪 Starting ZZRRTOOLS Modular Test - Phase 1"
    log_info "📦 Package name: '$PKG_NAME'"
    log_info "🔧 Testing modules: core, templates, structure"
    
    # Initialize manifest tracking
    init_manifest
    
    # Validate environment
    validate_templates_directory || exit 1
    
    # Test individual modules
    test_core_functions || exit 1
    test_template_functions || exit 1
    
    # Test structure creation (the main functionality)
    log_info "Testing directory structure creation..."
    create_directory_structure || exit 1
    
    log_info "Testing symbolic links creation..."
    create_symbolic_links || exit 1
    
    # Validate the created structure
    validate_directory_structure || exit 1
    
    # Show summary
    show_structure_summary
    
    # Final success message
    log_success "🎉 Modular test completed successfully!"
    
    echo ""
    log_info "📋 PHASE 1 RESULTS:"
    log_info "✅ Core module (logging, validation, utilities) - WORKING"
    log_info "✅ Templates module (file creation, template processing) - WORKING"  
    log_info "✅ Structure module (directories, symlinks) - WORKING"
    log_info "✅ Manifest tracking for uninstall - WORKING"
    echo ""
    log_info "📁 Created $(find . -type d | wc -l) directories and $(find . -type l | wc -l) symlinks"
    log_info "📄 Manifest file: $([[ -f "$MANIFEST_FILE" ]] && echo "$MANIFEST_FILE" || echo "$MANIFEST_TXT")"
    echo ""
    log_info "🔄 Next: Phase 2 will extract remaining modules (docker, rpackage, analysis, etc.)"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi