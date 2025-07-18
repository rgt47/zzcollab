#!/bin/bash
##############################################################################
# LOCAL SHELLCHECK RUNNER
##############################################################################
# 
# PURPOSE: Run ShellCheck analysis locally for development
# USAGE:   ./scripts/shellcheck-local.sh [--fix] [--verbose]
# 
# OPTIONS:
#   --fix      Apply automatic fixes where possible
#   --verbose  Show detailed output
#   --help     Show this help message
#
##############################################################################

set -euo pipefail

# Script directory and project root
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
readonly SHELLCHECK_CONFIG="$PROJECT_ROOT/.shellcheckrc"
VERBOSE=false
APPLY_FIXES=false

##############################################################################
# HELPER FUNCTIONS
##############################################################################

# Function: show_help
# Purpose: Display usage information
show_help() {
    cat << 'EOF'
ShellCheck Local Runner

USAGE:
    ./scripts/shellcheck-local.sh [OPTIONS]

OPTIONS:
    --fix      Apply automatic fixes where possible
    --verbose  Show detailed output and progress
    --help     Show this help message

DESCRIPTION:
    Runs ShellCheck analysis on all shell scripts in the project.
    Uses the project's .shellcheckrc configuration file.

EXAMPLES:
    ./scripts/shellcheck-local.sh                 # Basic check
    ./scripts/shellcheck-local.sh --verbose       # Detailed output
    ./scripts/shellcheck-local.sh --fix           # Apply fixes

EOF
}

# Function: log_info
# Purpose: Log informational messages
log_info() {
    echo "ℹ️  $*" >&2
}

# Function: log_success
# Purpose: Log success messages
log_success() {
    echo "✅ $*" >&2
}

# Function: log_error
# Purpose: Log error messages
log_error() {
    echo "❌ $*" >&2
}

# Function: check_shellcheck
# Purpose: Verify ShellCheck is installed
check_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_error "ShellCheck is not installed"
        echo ""
        echo "Installation instructions:"
        echo "  macOS: brew install shellcheck"
        echo "  Ubuntu/Debian: sudo apt-get install shellcheck"
        echo "  Arch Linux: sudo pacman -S shellcheck"
        echo "  Manual: https://github.com/koalaman/shellcheck#installing"
        exit 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "ShellCheck version: $(shellcheck --version | head -n2 | tail -n1)"
    fi
}

# Function: check_file
# Purpose: Run ShellCheck on a single file
check_file() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Checking $relative_path..."
    fi
    
    if shellcheck "$file"; then
        if [[ "$VERBOSE" == "true" ]]; then
            log_success "$relative_path passed"
        fi
        return 0
    else
        log_error "$relative_path failed ShellCheck"
        return 1
    fi
}

# Function: run_shellcheck
# Purpose: Run ShellCheck on all shell scripts
run_shellcheck() {
    local total_files=0
    local passed_files=0
    local failed_files=0
    
    cd "$PROJECT_ROOT"
    
    # Check main script
    if [[ -f "zzcollab.sh" ]]; then
        ((total_files++))
        if check_file "zzcollab.sh"; then
            ((passed_files++))
        else
            ((failed_files++))
        fi
    fi
    
    # Check modules
    if [[ -d "modules" ]]; then
        while IFS= read -r -d '' file; do
            ((total_files++))
            if check_file "$file"; then
                ((passed_files++))
            else
                ((failed_files++))
            fi
        done < <(find modules -name "*.sh" -type f -print0)
    fi
    
    # Check utility scripts
    for script in install.sh navigation_scripts.sh; do
        if [[ -f "$script" ]]; then
            ((total_files++))
            if check_file "$script"; then
                ((passed_files++))
            else
                ((failed_files++))
            fi
        fi
    done
    
    # Check template scripts
    if [[ -d "templates" ]]; then
        while IFS= read -r -d '' file; do
            ((total_files++))
            if check_file "$file"; then
                ((passed_files++))
            else
                ((failed_files++))
            fi
        done < <(find templates -name "*.sh" -type f -print0)
    fi
    
    # Check scripts directory
    if [[ -d "scripts" ]]; then
        while IFS= read -r -d '' file; do
            ((total_files++))
            if check_file "$file"; then
                ((passed_files++))
            else
                ((failed_files++))
            fi
        done < <(find scripts -name "*.sh" -type f -print0)
    fi
    
    # Summary
    echo ""
    echo "📊 ShellCheck Analysis Summary:"
    echo "   Total files: $total_files"
    echo "   Passed: $passed_files"
    echo "   Failed: $failed_files"
    
    if [[ $failed_files -eq 0 ]]; then
        log_success "All shell scripts passed ShellCheck analysis!"
        return 0
    else
        log_error "$failed_files file(s) failed ShellCheck analysis"
        return 1
    fi
}

##############################################################################
# MAIN EXECUTION
##############################################################################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            APPLY_FIXES=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Starting ShellCheck analysis..."
        log_info "Project root: $PROJECT_ROOT"
        log_info "Config file: $SHELLCHECK_CONFIG"
    fi
    
    # Check prerequisites
    check_shellcheck
    
    # Verify config file exists
    if [[ ! -f "$SHELLCHECK_CONFIG" ]]; then
        log_error "ShellCheck config file not found: $SHELLCHECK_CONFIG"
        exit 1
    fi
    
    # Run analysis
    if run_shellcheck; then
        if [[ "$VERBOSE" == "true" ]]; then
            log_success "ShellCheck analysis completed successfully"
        fi
        exit 0
    else
        log_error "ShellCheck analysis failed"
        exit 1
    fi
}

# Run main function
main