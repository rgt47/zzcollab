#!/bin/bash
##############################################################################
# READONLY CONSTANTS CHECKER
##############################################################################
# 
# PURPOSE: Check for constants that should be marked as readonly
# USAGE:   ./scripts/check-readonly.sh
# 
# DESCRIPTION:
#   Scans all shell scripts for uppercase variable assignments that
#   could be marked as readonly constants for better code safety.
#
##############################################################################

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

##############################################################################
# HELPER FUNCTIONS
##############################################################################

log_info() {
    echo "ℹ️  $*" >&2
}

log_success() {
    echo "✅ $*" >&2
}

log_warn() {
    echo "⚠️  $*" >&2
}

##############################################################################
# MAIN ANALYSIS
##############################################################################

main() {
    cd "$PROJECT_ROOT"
    
    log_info "Scanning for constants that should be readonly..."
    
    # Find uppercase variable assignments that are not already readonly
    local found_issues=false
    
    # Check all shell scripts
    while IFS= read -r -d '' file; do
        local relative_path="${file#$PROJECT_ROOT/}"
        
        # Skip this script itself
        if [[ "$relative_path" == "scripts/check-readonly.sh" ]]; then
            continue
        fi
        
        # Look for uppercase variable assignments
        if grep -n "^[A-Z_][A-Z0-9_]*=" "$file" | grep -v "^readonly " | grep -v "export " | grep -v "local "; then
            if [[ "$found_issues" == "false" ]]; then
                echo ""
                log_warn "Found constants that could be marked readonly:"
                echo ""
                found_issues=true
            fi
            echo "📄 $relative_path:"
            grep -n "^[A-Z_][A-Z0-9_]*=" "$file" | grep -v "^readonly " | grep -v "export " | grep -v "local " | \
                sed 's/^/    /'
            echo ""
        fi
    done < <(find . -name "*.sh" -type f -print0)
    
    if [[ "$found_issues" == "false" ]]; then
        log_success "All constants are properly marked as readonly!"
    else
        echo ""
        log_info "Consider marking these constants as readonly for better code safety:"
        echo "  readonly CONSTANT_NAME=\"value\""
        echo ""
        log_info "Note: Variables that change during execution should not be readonly"
    fi
}

main "$@"