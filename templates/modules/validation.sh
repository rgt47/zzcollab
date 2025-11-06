#!/usr/bin/env bash
# modules/validation.sh - Package dependency validation (pure shell, no R required)
#
# This module validates that all R packages used in code are properly declared
# in DESCRIPTION and locked in renv.lock for reproducibility.
#
# Key Innovation: Runs on host without requiring R installation
# - Package extraction: pure shell (grep, sed, awk)
# - DESCRIPTION parsing: pure shell (awk)
# - renv.lock parsing: jq (standard JSON tool)

set -euo pipefail

#==============================================================================
# LOGGING FUNCTIONS (standalone, no dependencies)
#==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

#==============================================================================
# CONFIGURATION
#==============================================================================

# Base R packages that don't need declaration
BASE_PACKAGES=(
    "base" "utils" "stats" "graphics" "grDevices"
    "methods" "datasets" "tools" "grid" "parallel"
)

# Directories to scan for R code
STANDARD_DIRS=("R" "scripts" "analysis")
STRICT_DIRS=("R" "scripts" "analysis" "tests" "vignettes" "inst")

# File extensions to search
FILE_EXTENSIONS=("R" "Rmd" "qmd" "Rnw")

#==============================================================================
# PACKAGE EXTRACTION (PURE SHELL)
#==============================================================================

# Extract package names from R code using grep/sed
# Handles: library(), require(), package::function(), @importFrom
extract_code_packages() {
    local dirs=("$@")
    local packages=()

    # Build find command for file extensions
    local find_pattern=""
    for ext in "${FILE_EXTENSIONS[@]}"; do
        if [[ -n "$find_pattern" ]]; then
            find_pattern="$find_pattern -o"
        fi
        find_pattern="$find_pattern -name \"*.$ext\""
    done

    # Find all R files and extract package references
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            # Extract library() and require() calls
            grep -oP '(?:library|require)\s*\(\s*["\x27]?([a-zA-Z][a-zA-Z0-9._]{2,})["\x27]?' "$file" 2>/dev/null | \
                sed -E 's/.*[(]["'\''"]?([a-zA-Z0-9._]+).*/\1/' || true

            # Extract namespace calls (package::function)
            grep -oP '([a-zA-Z][a-zA-Z0-9._]{2,})::' "$file" 2>/dev/null | \
                sed 's/:://' || true

            # Extract roxygen imports
            grep -oP '#\x27\s*@importFrom\s+([a-zA-Z][a-zA-Z0-9._]{2,})' "$file" 2>/dev/null | \
                sed -E 's/.*@importFrom\s+([a-zA-Z0-9._]+).*/\1/' || true

            grep -oP '#\x27\s*@import\s+([a-zA-Z][a-zA-Z0-9._]{2,})' "$file" 2>/dev/null | \
                sed -E 's/.*@import\s+([a-zA-Z0-9._]+).*/\1/' || true
        fi
    done < <(eval "find ${dirs[*]} -type f \( $find_pattern \) 2>/dev/null")
}

# Clean and deduplicate package list
clean_packages() {
    local packages=("$@")
    local cleaned=()

    # Sort, deduplicate, filter base packages
    for pkg in "${packages[@]}"; do
        # Skip if empty or too short
        if [[ -z "$pkg" ]] || [[ ${#pkg} -lt 3 ]]; then
            continue
        fi

        # Skip if base package
        # Use literal string matching instead of regex to avoid SC2076
        local base_packages_str=" ${BASE_PACKAGES[*]} "
        if [[ "$base_packages_str" == *" ${pkg} "* ]]; then
            continue
        fi

        # Validate package name format (letters, numbers, dots, underscores)
        if [[ "$pkg" =~ ^[a-zA-Z][a-zA-Z0-9._]+$ ]]; then
            cleaned+=("$pkg")
        fi
    done

    # Sort and deduplicate
    printf '%s\n' "${cleaned[@]}" | sort -u
}

#==============================================================================
# DESCRIPTION FILE PARSING (PURE SHELL)
#==============================================================================

# Parse Imports field from DESCRIPTION using awk
parse_description_imports() {
    if [[ ! -f "DESCRIPTION" ]]; then
        return 0
    fi

    awk '
        /^Imports:/ {
            imports = $0
            # Continue reading continuation lines (start with whitespace)
            while (getline > 0 && /^[[:space:]]/) {
                imports = imports $0
            }
            # Clean up the imports field
            gsub(/Imports:[[:space:]]*/, "", imports)
            gsub(/\([^)]*\)/, "", imports)  # Remove version constraints
            gsub(/,/, "\n", imports)
            print imports
            exit
        }
    ' DESCRIPTION | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u
}

# Parse Suggests field from DESCRIPTION
parse_description_suggests() {
    if [[ ! -f "DESCRIPTION" ]]; then
        return 0
    fi

    awk '
        /^Suggests:/ {
            suggests = $0
            while (getline > 0 && /^[[:space:]]/) {
                suggests = suggests $0
            }
            gsub(/Suggests:[[:space:]]*/, "", suggests)
            gsub(/\([^)]*\)/, "", suggests)
            gsub(/,/, "\n", suggests)
            print suggests
            exit
        }
    ' DESCRIPTION | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u
}

#==============================================================================
# RENV.LOCK PARSING (USING JQ)
#==============================================================================

# Parse package names from renv.lock using jq
parse_renv_lock() {
    if [[ ! -f "renv.lock" ]]; then
        return 0
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        log_warn "jq not found, skipping renv.lock parsing"
        log_warn "Install jq: brew install jq (macOS) or apt-get install jq (Linux)"
        return 0
    fi

    # Extract package names from Packages section
    jq -r '.Packages | keys[]' renv.lock 2>/dev/null | \
        grep -v '^$' | \
        sort -u || true
}

#==============================================================================
# VALIDATION LOGIC
#==============================================================================

# Main validation function
validate_package_environment() {
    local strict_mode="${1:-false}"
    local auto_fix="${2:-false}"

    log_info "Validating package dependencies..."

    # Step 1: Extract packages from code
    local dirs=("${STANDARD_DIRS[@]}")
    if [[ "$strict_mode" == "true" ]]; then
        dirs=("${STRICT_DIRS[@]}")
        log_info "Running in strict mode (scanning all directories)"
    fi

    log_info "Scanning for R files in: ${dirs[*]}"
    local code_packages_raw
    mapfile -t code_packages_raw < <(extract_code_packages "${dirs[@]}")
    local code_packages
    mapfile -t code_packages < <(clean_packages "${code_packages_raw[@]}")

    # Step 2: Parse DESCRIPTION
    local desc_imports
    mapfile -t desc_imports < <(parse_description_imports)

    # Step 3: Parse renv.lock
    local renv_packages
    mapfile -t renv_packages < <(parse_renv_lock)

    # Step 4: Report findings
    log_info "Found ${#code_packages[@]} packages in code"
    log_info "Found ${#desc_imports[@]} packages in DESCRIPTION Imports"
    log_info "Found ${#renv_packages[@]} packages in renv.lock"

    # Step 5: Find missing packages (in code but not in DESCRIPTION)
    local missing=()
    for pkg in "${code_packages[@]}"; do
        # Use literal string matching instead of regex to avoid SC2076
        local desc_imports_str=" ${desc_imports[*]} "
        if [[ "$desc_imports_str" != *" ${pkg} "* ]]; then
            missing+=("$pkg")
        fi
    done

    # Step 6: Report issues
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing from DESCRIPTION Imports:"
        for pkg in "${missing[@]}"; do
            echo "  - $pkg"
        done

        if [[ "$auto_fix" == "true" ]]; then
            log_info "Auto-fix not yet implemented in shell version"
            log_info "Please run: Rscript validate_package_environment.R --fix"
        fi

        return 1
    fi

    log_success "All packages properly declared in DESCRIPTION"
    return 0
}

# Validate and provide actionable feedback
validate_and_report() {
    local strict_mode="${1:-false}"

    if validate_package_environment "$strict_mode" "false"; then
        log_success "Package environment validation passed"
        return 0
    else
        log_error "Package environment validation failed"
        echo ""
        echo "To fix missing packages, you can:"
        echo "  1. Add them manually to DESCRIPTION Imports field"
        echo "  2. Run: Rscript validate_package_environment.R --fix"
        echo "  3. Inside container: renv::install() then exit (auto-snapshot)"
        echo ""
        return 1
    fi
}

#==============================================================================
# COMMAND LINE INTERFACE
#==============================================================================

# Main entry point when run as script
main() {
    local strict_mode=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --strict)
                strict_mode=true
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: validation.sh [OPTIONS]

Validate R package dependencies without requiring R on host.

OPTIONS:
    --strict        Scan all directories (including tests/, vignettes/)
    --help, -h      Show this help message

EXAMPLES:
    validation.sh              # Standard validation
    validation.sh --strict     # Strict mode (all directories)

REQUIREMENTS:
    - jq (for renv.lock parsing): brew install jq
    - Standard Unix tools: grep, sed, awk, find

NOTE:
    This script runs on the host without R. Package installation and
    renv::snapshot() happen automatically inside Docker containers via
    the .Last() function in .Rprofile.
EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Run validation
    validate_and_report "$strict_mode"
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
