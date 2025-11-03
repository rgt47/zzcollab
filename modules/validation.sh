#!/usr/bin/env bash
set -euo pipefail
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

#-----------------------------------------------------------------------------
# FUNCTION: extract_code_packages
# PURPOSE:  Extract R package names from source code using pure shell tools
# DESCRIPTION:
#   Scans R source files for package references and extracts package names
#   using grep/sed. Handles library(), require(), namespace calls (pkg::fn),
#   and roxygen2 imports (@import, @importFrom).
# ARGS:
#   $@ - Directory paths to scan for R files
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   Package names to stdout, one per line (may contain duplicates)
# GLOBALS READ:
#   FILE_EXTENSIONS - Array of file extensions to search (.R, .Rmd, etc.)
# NOTES:
#   - Pure shell implementation (no R required on host)
#   - Extracts from: library(), require(), pkg::fn, @importFrom, @import
#   - Returns raw list with possible duplicates (use clean_packages() after)
#   - Requires closing parenthesis to avoid incomplete calls
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: clean_packages
# PURPOSE:  Clean, validate, and deduplicate extracted package names
# DESCRIPTION:
#   Takes a raw list of package names (possibly with duplicates, invalid names)
#   and returns a cleaned, deduplicated, sorted list of valid R package names.
#   Filters out base R packages that don't need declaration, validates package
#   name format according to R package naming rules, and removes duplicates.
# ARGS:
#   $@ - Raw package names (one per argument, may include duplicates/invalid)
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   Cleaned package names to stdout, one per line, sorted alphabetically
# GLOBALS READ:
#   BASE_PACKAGES - Array of base R packages to exclude
# VALIDATION RULES:
#   - Minimum 2 characters (R package requirement)
#   - Must start with a letter (a-zA-Z)
#   - Can contain letters, numbers, and dots only
#   - Cannot start or end with a dot
#   - CRAN doesn't allow underscores, but BioConductor does (we allow them)
# FILTERS APPLIED:
#   1. Remove empty strings and names < 2 characters
#   2. Remove base R packages (base, utils, stats, etc.)
#   3. Validate format: ^[a-zA-Z][a-zA-Z0-9.]*$
#   4. Remove names starting or ending with dots
#   5. Sort and deduplicate
# EXAMPLE:
#   packages=(dplyr ggplot2 dplyr base "" "a" ".invalid" "valid.pkg")
#   clean_packages "${packages[@]}"
#   # Output: ggplot2, valid.pkg, dplyr (sorted, base and invalid removed)
#-----------------------------------------------------------------------------
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
        # Use literal string matching instead of regex to avoid SC2076
        local base_packages_str=" ${BASE_PACKAGES[*]} "
        if [[ "$base_packages_str" == *" ${pkg} "* ]]; then
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

#-----------------------------------------------------------------------------
# FUNCTION: parse_description_imports
# PURPOSE:  Extract package names from DESCRIPTION Imports field
# DESCRIPTION:
#   Parses the Imports field from an R package DESCRIPTION file using pure
#   awk, extracting package names while removing version constraints and
#   handling multi-line continuation. Returns clean package names suitable
#   for validation against code usage.
# ARGS:
#   None (operates on ./DESCRIPTION in current directory)
# RETURNS:
#   0 - Success (even if DESCRIPTION doesn't exist or has no Imports)
# OUTPUTS:
#   Package names to stdout, one per line, sorted and deduplicated
# FILES READ:
#   ./DESCRIPTION - R package metadata file
# AWK PROCESSING:
#   1. Identifies "Imports:" field start
#   2. Collects continuation lines (start with whitespace)
#   3. Stops at next field (line starting with capital letter)
#   4. Removes "Imports:" prefix
#   5. Removes version constraints: (>= x.y.z) or any (...)
#   6. Normalizes whitespace
#   7. Splits on commas
# VERSION CONSTRAINT HANDLING:
#   Removes all parenthetical expressions:
#   - "pkg (>= 1.0.0)" → "pkg"
#   - "pkg (>= 1.0.0),\n    pkg2 (< 2.0)" → "pkg", "pkg2"
# MULTI-LINE HANDLING:
#   DCF (Debian Control File) format allows continuation:
#   Imports: pkg1,
#       pkg2,
#       pkg3
#   All collected and processed together.
# EXAMPLE:
#   DESCRIPTION contains:
#     Imports:
#         dplyr (>= 1.0.0),
#         ggplot2
#   Output:
#     dplyr
#     ggplot2
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: parse_description_suggests
# PURPOSE:  Extract package names from DESCRIPTION Suggests field
# DESCRIPTION:
#   Parses the Suggests field from an R package DESCRIPTION file using pure
#   awk. Similar to parse_description_imports() but targets Suggests field.
#   Suggests packages are optional dependencies (testing, vignettes, examples).
# ARGS:
#   None (operates on ./DESCRIPTION in current directory)
# RETURNS:
#   0 - Success (even if DESCRIPTION doesn't exist or has no Suggests)
# OUTPUTS:
#   Package names to stdout, one per line, sorted and deduplicated
# FILES READ:
#   ./DESCRIPTION - R package metadata file
# SUGGESTS VS IMPORTS:
#   - Imports: Required dependencies, always installed
#   - Suggests: Optional dependencies, used for testing/vignettes/examples
#   - This function extracts Suggests to allow optional validation
# AWK PROCESSING:
#   Same as parse_description_imports() but for "Suggests:" field
# EXAMPLE:
#   DESCRIPTION contains:
#     Suggests:
#         testthat (>= 3.0.0),
#         knitr,
#         rmarkdown
#   Output:
#     knitr
#     rmarkdown
#     testthat
#-----------------------------------------------------------------------------
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
# DESCRIPTION CLEANUP
#==============================================================================

#-----------------------------------------------------------------------------
# FUNCTION: remove_unused_packages_from_description
# PURPOSE:  Remove packages from DESCRIPTION that are not used in code
# DESCRIPTION:
#   Compares packages declared in DESCRIPTION Imports against packages
#   actually used in code. Removes unused packages from DESCRIPTION file
#   (except protected packages like renv). This helps keep DESCRIPTION
#   aligned with actual code dependencies.
# ARGS:
#   $1 - packages_in_code: Array of package names used in code
#   $2 - strict_mode: "true" or "false" for scanning scope
# RETURNS:
#   0 - Success (packages removed if any)
#   1 - Error (DESCRIPTION not found or not writable)
# OUTPUTS:
#   Informational messages about removed packages
# SIDE EFFECTS:
#   Modifies DESCRIPTION file in-place
# PROTECTED PACKAGES:
#   - renv: Always kept (infrastructure package)
# STRATEGY:
#   1. Parse current DESCRIPTION Imports
#   2. Find packages in DESCRIPTION but NOT in code
#   3. Remove unused packages (except protected ones)
#   4. Rewrite DESCRIPTION with awk
# EXAMPLE:
#   DESCRIPTION has: renv, dplyr, ggplot2
#   Code uses: dplyr
#   Result: Remove ggplot2, keep renv (protected) and dplyr (used)
#-----------------------------------------------------------------------------
remove_unused_packages_from_description() {
    local strict_mode="${1:-false}"

    if [[ ! -f "DESCRIPTION" ]]; then
        log_warn "DESCRIPTION file not found, skipping cleanup"
        return 1
    fi

    if [[ ! -w "DESCRIPTION" ]]; then
        log_warn "DESCRIPTION file not writable, skipping cleanup"
        return 1
    fi

    # Get packages used in code
    local code_packages=()
    while IFS= read -r pkg; do
        code_packages+=("$pkg")
    done < <(extract_packages_from_code "$strict_mode")

    # Get packages in DESCRIPTION
    local desc_packages=()
    while IFS= read -r pkg; do
        desc_packages+=("$pkg")
    done < <(parse_description_imports)

    # Find unused packages (in DESCRIPTION but NOT in code)
    local unused_packages=()
    for pkg in "${desc_packages[@]}"; do
        # Protected package check
        if [[ "$pkg" == "renv" ]]; then
            continue
        fi

        # Check if package is used in code
        local found=false
        for code_pkg in "${code_packages[@]}"; do
            if [[ "$pkg" == "$code_pkg" ]]; then
                found=true
                break
            fi
        done

        if [[ "$found" == false ]]; then
            unused_packages+=("$pkg")
        fi
    done

    # No unused packages? Done
    if [[ ${#unused_packages[@]} -eq 0 ]]; then
        log_debug "No unused packages to remove from DESCRIPTION"
        return 0
    fi

    # Report what we're removing
    log_info "Removing ${#unused_packages[@]} unused package(s) from DESCRIPTION:"
    for pkg in "${unused_packages[@]}"; do
        log_info "  - $pkg"
    done

    # Create temporary file for new DESCRIPTION
    local tmp_desc=$(mktemp)

    # Build regex pattern for packages to remove
    local remove_pattern=""
    for pkg in "${unused_packages[@]}"; do
        if [[ -z "$remove_pattern" ]]; then
            remove_pattern="$pkg"
        else
            remove_pattern="$remove_pattern|$pkg"
        fi
    done

    # Remove unused packages from Imports section using awk
    awk -v pattern="^[[:space:]]*(${remove_pattern})[[:space:],]*\$" '
    /^Imports:/ { in_imports=1; print; next }
    in_imports {
        if (/^[A-Z]/) {
            # New section started, exit Imports
            in_imports=0
            print
            next
        }
        # Skip lines matching removal pattern
        if ($0 ~ pattern) {
            next
        }
        # Keep other lines
        print
    }
    !in_imports { print }
    ' DESCRIPTION > "$tmp_desc"

    # Replace DESCRIPTION with cleaned version
    mv "$tmp_desc" DESCRIPTION

    log_success "✅ Removed unused packages from DESCRIPTION"
    log_info "   Next renv::snapshot() will update renv.lock accordingly"
    return 0
}

#==============================================================================
# RENV.LOCK PARSING (USING JQ)
#==============================================================================

#-----------------------------------------------------------------------------
# FUNCTION: parse_renv_lock
# PURPOSE:  Extract package names from renv.lock file using jq
# DESCRIPTION:
#   Parses the renv.lock JSON file to extract all installed package names.
#   This provides the source of truth for what packages are actually locked
#   in the reproducible environment. Requires jq for JSON parsing.
# ARGS:
#   None (operates on ./renv.lock in current directory)
# RETURNS:
#   0 - Success (even if renv.lock doesn't exist or jq not available)
# OUTPUTS:
#   Package names to stdout, one per line, sorted and deduplicated
# FILES READ:
#   ./renv.lock - renv package lockfile (JSON format)
# DEPENDENCIES:
#   jq - Command-line JSON processor
#   - macOS: brew install jq
#   - Linux: apt-get install jq
#   - If jq not found, logs warning and returns gracefully
# RENV.LOCK STRUCTURE:
#   {
#     "R": {...},
#     "Packages": {
#       "packageA": {...},
#       "packageB": {...}
#     }
#   }
#   This function extracts keys from the "Packages" object.
# ERROR HANDLING:
#   - Missing renv.lock: Returns success (empty output)
#   - Missing jq: Logs warning with installation instructions, returns success
#   - Invalid JSON: jq error silently caught (returns empty)
# WHY JQ INSTEAD OF SHELL:
#   - renv.lock is complex nested JSON
#   - Shell JSON parsing is fragile and error-prone
#   - jq is standard tool (available on all major platforms)
# EXAMPLE:
#   renv.lock contains:
#     {"Packages": {"dplyr": {...}, "ggplot2": {...}}}
#   Output:
#     dplyr
#     ggplot2
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: validate_package_environment
# PURPOSE:  Main validation logic for R package environment consistency
# DESCRIPTION:
#   Validates that all R packages used in source code are properly declared
#   in DESCRIPTION Imports field and locked in renv.lock for reproducibility.
#   This is the core validation function that orchestrates package extraction,
#   parsing, and comparison. Runs entirely on host without requiring R.
# ARGS:
#   $1 - strict_mode: "true" to scan all directories (tests/, vignettes/),
#                     "false" (default) to scan only standard dirs (R/, scripts/)
#   $2 - auto_fix: "true" to attempt automatic fixes (NOT YET IMPLEMENTED),
#                  "false" (default) to only report issues
# RETURNS:
#   0 - All packages properly declared (validation passed)
#   1 - Missing packages found (validation failed)
# OUTPUTS:
#   Progress messages and validation results to stdout
#   Error messages for missing packages
# GLOBALS READ:
#   STANDARD_DIRS - Array of standard directories to scan (R/, scripts/, analysis/)
#   STRICT_DIRS - Array of all directories in strict mode (adds tests/, vignettes/, inst/)
# VALIDATION WORKFLOW:
#   1. Extract packages from source code (library, require, ::, @import)
#   2. Clean and validate extracted package names
#   3. Parse DESCRIPTION Imports field
#   4. Parse renv.lock (optional, for informational purposes)
#   5. Compare code packages vs DESCRIPTION
#   6. Report any packages used in code but not declared in DESCRIPTION
# STRICT MODE:
#   Standard mode: Scans R/, scripts/, analysis/ only
#   Strict mode: Also scans tests/, vignettes/, inst/
#   Rationale: Tests and vignettes can use Suggests packages, which may not
#              be in Imports. Strict mode helps catch undeclared Suggests.
# AUTO-FIX (NOT YET IMPLEMENTED):
#   Would add missing packages to DESCRIPTION automatically
#   Currently logs message directing user to manual fix or R script
# REPRODUCIBILITY SIGNIFICANCE:
#   This validation ensures that anyone cloning the project can:
#   1. Install dependencies from DESCRIPTION
#   2. Restore exact versions from renv.lock
#   3. Run all code without "package not found" errors
# EXAMPLE USAGE:
#   validate_package_environment "false" "false"  # Standard validation
#   validate_package_environment "true" "false"   # Strict validation
#-----------------------------------------------------------------------------
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

    log_success "✅ All packages properly declared in DESCRIPTION"
    return 0
}

#-----------------------------------------------------------------------------
# FUNCTION: validate_and_report
# PURPOSE:  User-friendly wrapper around validate_package_environment
# DESCRIPTION:
#   Convenience function that calls validate_package_environment() and
#   provides actionable feedback on how to fix issues. Formats output
#   for end-user consumption with clear success/failure messages and
#   instructions for resolving validation failures.
# ARGS:
#   $1 - strict_mode: "true" or "false" (default), passed to validation
# RETURNS:
#   0 - Validation passed
#   1 - Validation failed (packages missing from DESCRIPTION)
# OUTPUTS:
#   Success message if validation passes
#   Error message plus fix instructions if validation fails
# FIX INSTRUCTIONS PROVIDED:
#   1. Manual addition to DESCRIPTION Imports field
#   2. Run R validation script with --fix flag
#   3. Install packages inside container (auto-snapshot on exit)
# USER EXPERIENCE FOCUS:
#   This function prioritizes clear, actionable guidance over technical details
#   Goal: Make it easy for researchers to fix validation issues themselves
# EXAMPLE OUTPUT ON FAILURE:
#   Package environment validation failed
#
#   To fix missing packages, you can:
#     1. Add them manually to DESCRIPTION Imports field
#     2. Run: Rscript validate_package_environment.R --fix
#     3. Inside container: renv::install() then exit (auto-snapshot)
#-----------------------------------------------------------------------------
validate_and_report() {
    local strict_mode="${1:-false}"

    if validate_package_environment "$strict_mode" "false"; then
        log_success "Package environment validation passed"

        # Clean up unused packages from DESCRIPTION
        # This runs after validation to ensure all used packages are declared
        log_debug "Checking for unused packages in DESCRIPTION..."
        remove_unused_packages_from_description "$strict_mode"

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

#-----------------------------------------------------------------------------
# FUNCTION: main
# PURPOSE:  Command-line entry point for validation module
# DESCRIPTION:
#   Provides CLI interface to the validation system. Parses command-line
#   arguments, displays help, and invokes validate_and_report() with
#   appropriate settings. Only runs when module is executed directly
#   (not when sourced by other scripts).
# ARGS:
#   --strict : Enable strict mode (scan tests/, vignettes/, inst/)
#   --help|-h : Display usage information and exit
# RETURNS:
#   0 - Validation passed
#   1 - Validation failed or invalid arguments
#   (exits script, does not return to caller)
# USAGE:
#   ./modules/validation.sh              # Standard validation
#   ./modules/validation.sh --strict     # Strict validation
#   ./modules/validation.sh --help       # Show help
# EXECUTION GUARD:
#   Only runs if ${BASH_SOURCE[0]} == ${0}
#   This allows module to be:
#   - Executed directly: Runs main()
#   - Sourced by other scripts: Provides functions only
# CLI DESIGN:
#   - Simple, focused interface (validation-specific)
#   - Clear help text with examples
#   - Minimal dependencies (just bash, grep, sed, awk, jq)
# HOST REQUIREMENTS:
#   - Standard Unix tools: bash, grep, sed, awk, find
#   - jq: For renv.lock parsing (optional, warns if missing)
#   - No R installation required on host!
# INTEGRATION:
#   This script is called by:
#   - Makefile targets (make check-renv, make check-renv-strict)
#   - Docker exit hooks (auto-validation after container exit)
#   - Manual validation by developers
# WHY HOST-BASED VALIDATION:
#   Running on host (not in Docker) enables:
#   - Fast validation without container startup
#   - Pre-commit hooks and CI/CD integration
#   - Validation before Docker build (catch issues early)
#-----------------------------------------------------------------------------
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
