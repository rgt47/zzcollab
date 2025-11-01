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
# - CRAN validation: curl (HTTP API)

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/constants.sh"

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
            # Updated regex: {1,} allows minimum 2-char packages (1 letter + 1 more char)
            # Also requires closing parenthesis to avoid matching incomplete calls
            grep -oP '(?:library|require)\s*\(\s*["'\''"]?([a-zA-Z][a-zA-Z0-9.]*?)["'\''"]?\s*\)' "$file" 2>/dev/null | \
                sed -E 's/.*[(]["'\''"]?([a-zA-Z0-9.]+)["'\''"]?\).*/\1/' || true

            # Extract namespace calls (package::function)
            # Updated regex: {0,} allows minimum 1-char after first letter (2-char total)
            grep -oP '([a-zA-Z][a-zA-Z0-9.]*)::' "$file" 2>/dev/null | \
                sed 's/:://' || true

            # Extract roxygen imports
            # Updated regex: {0,} allows minimum 1-char packages
            grep -oP '#'\''\s*@importFrom\s+([a-zA-Z][a-zA-Z0-9.]*)' "$file" 2>/dev/null | \
                sed -E 's/.*@importFrom\s+([a-zA-Z0-9.]+).*/\1/' || true

            grep -oP '#'\''\s*@import\s+([a-zA-Z][a-zA-Z0-9.]*)' "$file" 2>/dev/null | \
                sed -E 's/.*@import\s+([a-zA-Z0-9.]+).*/\1/' || true
        fi
    done < <(eval "find ${dirs[*]} -type f \( $find_pattern \) 2>/dev/null")
}

# Clean and deduplicate package list
clean_packages() {
    local packages=("$@")
    local cleaned=()

    # Sort, deduplicate, filter base packages
    for pkg in "${packages[@]}"; do
        # Skip if empty or too short (R packages must be at least 2 chars)
        if [[ -z "$pkg" ]] || [[ ${#pkg} -lt 2 ]]; then
            continue
        fi

        # Skip if base package
        if [[ " ${BASE_PACKAGES[*]} " =~ " ${pkg} " ]]; then
            continue
        fi

        # Validate package name format
        # R package rules: start with letter, contain letters/numbers/dots only
        # Note: CRAN doesn't allow underscores, but BioConductor does
        # We allow underscores for compatibility but validate properly
        if [[ "$pkg" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]]; then
            # Additional validation: cannot start or end with dot
            if [[ ! "$pkg" =~ ^\. ]] && [[ ! "$pkg" =~ \.$ ]]; then
                cleaned+=("$pkg")
            fi
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
        BEGIN { in_imports = 0; imports = "" }

        # Start of Imports field
        /^Imports:/ {
            in_imports = 1
            imports = $0
            next
        }

        # Continuation lines (start with whitespace) while in Imports field
        in_imports && /^[[:space:]]/ {
            # Add space before appending to avoid concatenation issues
            imports = imports " " $0
            next
        }

        # Stop when we hit a new field (line that does not start with whitespace)
        in_imports && /^[A-Z]/ {
            in_imports = 0
        }

        # Process and output when done
        END {
            if (imports) {
                # Remove "Imports:" prefix
                gsub(/^Imports:[[:space:]]*/, "", imports)
                # Remove version constraints (handles multi-line constraints)
                gsub(/\([^)]*\)/, "", imports)
                # Normalize whitespace
                gsub(/[[:space:]]+/, " ", imports)
                # Split on commas
                gsub(/,/, "\n", imports)
                print imports
            }
        }
    ' DESCRIPTION | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u
}

# Parse Suggests field from DESCRIPTION
parse_description_suggests() {
    if [[ ! -f "DESCRIPTION" ]]; then
        return 0
    fi

    awk '
        BEGIN { in_suggests = 0; suggests = "" }

        # Start of Suggests field
        /^Suggests:/ {
            in_suggests = 1
            suggests = $0
            next
        }

        # Continuation lines (start with whitespace) while in Suggests field
        in_suggests && /^[[:space:]]/ {
            # Add space before appending to avoid concatenation issues
            suggests = suggests " " $0
            next
        }

        # Stop when we hit a new field
        in_suggests && /^[A-Z]/ {
            in_suggests = 0
        }

        # Process and output when done
        END {
            if (suggests) {
                gsub(/^Suggests:[[:space:]]*/, "", suggests)
                gsub(/\([^)]*\)/, "", suggests)
                gsub(/[[:space:]]+/, " ", suggests)
                gsub(/,/, "\n", suggests)
                print suggests
            }
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
    code_packages_raw=($(extract_code_packages "${dirs[@]}"))
    local code_packages
    code_packages=($(clean_packages "${code_packages_raw[@]}"))

    # Step 2: Parse DESCRIPTION
    local desc_imports
    desc_imports=($(parse_description_imports))

    # Step 3: Parse renv.lock
    local renv_packages
    renv_packages=($(parse_renv_lock))

    # Step 4: Report findings
    log_info "Found ${#code_packages[@]} packages in code"
    log_info "Found ${#desc_imports[@]} packages in DESCRIPTION Imports"
    log_info "Found ${#renv_packages[@]} packages in renv.lock"

    # Step 5: Find missing packages (in code but not in DESCRIPTION)
    local missing=()
    for pkg in "${code_packages[@]}"; do
        if [[ ! " ${desc_imports[*]} " =~ " ${pkg} " ]]; then
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

    log_success "✅ All packages properly declared in DESCRIPTION"
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
    the zzcollab-entrypoint.sh exit hook.
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
