#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CLI MODULE
##############################################################################
# 
# PURPOSE: Command line interface parsing and validation
#          - Command line argument parsing
#          - Flag variable initialization
#          - User-friendly interface processing
#          - Argument validation
#
# DEPENDENCIES: None (loaded before other modules)
#
# EXPORTS: All CLI variables and functions for use by main script
##############################################################################

#=============================================================================
# CLI ARGUMENT VALIDATION FUNCTIONS
#=============================================================================

##############################################################################
# FUNCTION: require_arg
# PURPOSE:  Validate that a command line flag has a required argument
# USAGE:    require_arg "--flag-name" "$argument_value"
# ARGS:     
#   $1 - flag_name: Name of the command line flag for error reporting
#   $2 - argument_value: The argument value to validate (may be empty)
# RETURNS:  
#   0 - Argument is present and non-empty
#   1 - Argument is missing or empty (exits with error message)
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs error to stderr, then exits)
# DESCRIPTION:
#   This function provides standardized validation for command line arguments
#   that are required for specific flags. It prevents silent failures when
#   users provide flags without their required arguments.
# ERROR BEHAVIOR:
#   - Exits immediately with code 1 if argument is missing
#   - Provides clear error message identifying the problematic flag
#   - Uses stderr for error output to avoid interfering with normal output
# EXAMPLE:
#   require_arg "--team-name" "$team_name_value"
##############################################################################
require_arg() {
    if [[ -z "${2:-}" ]]; then
        echo "❌ Error: $1 requires an argument" >&2
        return 1  # Recoverable: caller can handle error
    fi
    return 0
}

##############################################################################
# FUNCTION: validate_team_name
# PURPOSE:  Validate team name format and constraints
# ARGS:     $1 - team name to validate
# RETURNS:  0 if valid, 1 if invalid
# DESCRIPTION:
#   Validates team name:
#   - Alphanumeric + hyphens only
#   - 2-50 characters
#   - Not reserved (zzcollab, docker, github, etc.)
##############################################################################
validate_team_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Team name cannot be empty"
        return 1
    fi

    # Check format: alphanumeric + hyphens, 2-50 chars
    if ! [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] || [[ ${#name} -lt 2 ]]; then
        log_error "Invalid team name: '$name'"
        log_error "Team names must be 2-50 characters: alphanumeric and hyphens only"
        log_error "Examples: 'my-team', 'lab-123', 'research'"
        return 1
    fi

    # Check length
    if [[ ${#name} -gt 50 ]]; then
        log_error "Team name too long: ${#name} characters (max: 50)"
        return 1
    fi

    # Check not reserved
    local reserved=("zzcollab" "docker" "github" "root" "system" "admin" "test")
    for reserved_name in "${reserved[@]}"; do
        if [[ "$name" == "$reserved_name" ]]; then
            log_error "Team name '$name' is reserved and cannot be used"
            return 1
        fi
    done

    return 0
}

##############################################################################
# FUNCTION: validate_project_name
# PURPOSE:  Validate project name format
# ARGS:     $1 - project name to validate
# RETURNS:  0 if valid, 1 if invalid
##############################################################################
validate_project_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Project name cannot be empty"
        return 1
    fi

    # Check format: alphanumeric + hyphens + underscores, 1-50 chars
    if ! [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        log_error "Invalid project name: '$name'"
        log_error "Project names must start with letter/digit, use alphanumeric, hyphens, underscores"
        return 1
    fi

    if [[ ${#name} -gt 50 ]]; then
        log_error "Project name too long: ${#name} characters (max: 50)"
        return 1
    fi

    return 0
}

##############################################################################
# FUNCTION: validate_base_image
# PURPOSE:  Validate Docker base image reference format
# ARGS:     $1 - base image reference to validate
# RETURNS:  0 if valid, 1 if invalid
# DESCRIPTION:
#   Validates Docker image format: [registry/]image[:tag]
#   Examples: rocker/rstudio, rocker/rstudio:4.3.1, ghcr.io/org/image
##############################################################################
validate_base_image() {
    local image="$1"

    if [[ -z "$image" ]]; then
        log_error "Base image cannot be empty"
        return 1
    fi

    # Basic docker image format validation
    # Format: [registry[:port]/][org/]image[:tag]
    # Allow: alphanumeric, dots, colons (port/tag), hyphens, underscores, slashes
    # Must start with alphanumeric and not contain consecutive special chars
    if ! [[ "$image" =~ ^[a-zA-Z0-9][a-zA-Z0-9.:/_-]*$ ]] || [[ "$image" =~ [/:]{2,} ]]; then
        log_error "Invalid base image reference: '$image'"
        log_error "Valid formats:"
        log_error "  - 'rocker/rstudio' (Docker Hub)"
        log_error "  - 'rocker/rstudio:4.3.1' (with tag)"
        log_error "  - 'ghcr.io/org/image' (other registry)"
        return 1
    fi

    return 0
}

##############################################################################
# FUNCTION: validate_r_version
# PURPOSE:  Validate R version format (X.Y.Z)
# ARGS:     $1 - R version to validate
# RETURNS:  0 if valid, 1 if invalid
##############################################################################
validate_r_version() {
    local version="$1"

    if [[ -z "$version" ]]; then
        log_error "R version cannot be empty"
        return 1
    fi

    # Format: X.Y.Z (e.g., 4.3.1)
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid R version: '$version'"
        log_error "Expected format: X.Y.Z (e.g., '4.3.1')"
        return 1
    fi

    return 0
}

##############################################################################
# FUNCTION: validate_bundle_name
# PURPOSE:  Validate bundle name exists in bundles.yaml
# ARGS:     $1 - bundle type (package_bundles or library_bundles)
#           $2 - bundle name to validate
# RETURNS:  0 if valid, 1 if invalid
##############################################################################
validate_bundle_name() {
    local bundle_type="$1"
    local bundle_name="$2"

    if [[ -z "$bundle_name" ]]; then
        return 0  # Empty is OK (optional)
    fi

    if [[ ! -f "${TEMPLATES_DIR}/bundles.yaml" ]]; then
        log_warn "Bundles file not found, skipping bundle validation"
        return 0
    fi

    # Check bundle exists using yq
    if ! yq eval ".${bundle_type}.${bundle_name}" "${TEMPLATES_DIR}/bundles.yaml" &>/dev/null; then
        log_error "Bundle not found: $bundle_name"
        log_error "Available ${bundle_type}:"
        yq eval ".${bundle_type} | keys" "${TEMPLATES_DIR}/bundles.yaml" 2>/dev/null | sed 's/^/  - /' || true
        return 1
    fi

    return 0
}

#=============================================================================
# CLI VARIABLE INITIALIZATION
#=============================================================================

# Initialize variables for command line options
# Note: BUILD_DOCKER=false by default - users run 'make docker-build' manually
BUILD_DOCKER=false
# Use centralized constants if available
readonly DEFAULT_BASE_IMAGE="${ZZCOLLAB_DEFAULT_BASE_IMAGE:-rocker/r-ver}"
BASE_IMAGE="$DEFAULT_BASE_IMAGE"

# User-friendly interface variables
TEAM_NAME=""
PROJECT_NAME=""
GITHUB_ACCOUNT=""
DOCKERFILE_PATH=""
IMAGE_TAG=""
R_VERSION=""  # R version for Docker build (extracted from renv.lock or specified via --r-version)

# Initialization mode variables
PREPARE_DOCKERFILE=false
SKIP_CONFIRMATION=false
CREATE_GITHUB_REPO=false
FORCE_DIRECTORY=false    # Skip directory validation (advanced users)
WITH_EXAMPLES=false      # Include example files and templates in workspace
ADD_EXAMPLES=false       # Add examples to existing project

# Profile bundle variables (system libraries and R packages)
LIBS_BUNDLE=""    # System library bundle (e.g., minimal, modeling, publishing, gui)
PKGS_BUNDLE=""    # R package bundle (e.g., tidyverse, shiny, modeling)

# Track whether user explicitly provided these flags (for team member validation)
USER_PROVIDED_BASE_IMAGE=false
USER_PROVIDED_LIBS=false
USER_PROVIDED_PKGS=false
USER_PROVIDED_PROFILE=false
USER_PROVIDED_R_VERSION=false
USE_TEAM_IMAGE=false    # Team member flag to pull and use team image

# Show flags (processed after modules are loaded)
SHOW_HELP=false
SHOW_HELP_TOPIC=""
SHOW_NEXT_STEPS=false

# Config command flags
CONFIG_COMMAND=false
CONFIG_SUBCOMMAND=""
CONFIG_ARGS=()

#=============================================================================
# CLI ARGUMENT PARSING FUNCTION
#=============================================================================

# Function: parse_cli_arguments
# Purpose: Parse all command line arguments and set global variables
# Arguments: All command line arguments passed to script
parse_cli_arguments() {
    # Git-like help subcommand: zzcollab help <topic>
    if [[ "${1:-}" == "help" ]]; then
        SHOW_HELP=true
        if [[ -n "${2:-}" ]] && [[ ! "$2" =~ ^- ]]; then
            SHOW_HELP_TOPIC="$2"
        fi
        return 0
    fi

    # Process all command line arguments (identical to original zzcollab.sh)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-docker)
                BUILD_DOCKER=true
                shift
                ;;
            --no-docker|-n)
                BUILD_DOCKER=false
                shift
                ;;
            --quiet|-q)
                export VERBOSITY_LEVEL=0
                shift
                ;;
            -v|--verbose)
                export VERBOSITY_LEVEL=2
                shift
                ;;
            -vv|--debug)
                export VERBOSITY_LEVEL=3
                export ENABLE_LOG_FILE=true
                shift
                ;;
            --log-file|-w)
                export ENABLE_LOG_FILE=true
                shift
                ;;
            --base-image|-b)
                require_arg "$1" "$2" || return 1
                BASE_IMAGE="$2"
                USER_PROVIDED_BASE_IMAGE=true
                shift 2
                ;;
            --team|-t)
                require_arg "$1" "$2" || return 1
                TEAM_NAME="$2"
                shift 2
                ;;
            --project-name|-p)
                require_arg "$1" "$2" || return 1
                PROJECT_NAME="$2"
                shift 2
                ;;
            --github-account|-g)
                require_arg "$1" "$2" || return 1
                GITHUB_ACCOUNT="$2"
                shift 2
                ;;
            --dockerfile|-f)
                require_arg "$1" "$2" || return 1
                DOCKERFILE_PATH="$2"
                shift 2
                ;;
            --prepare-dockerfile|-P)
                PREPARE_DOCKERFILE=true
                shift
                ;;
            --config|-c)
                # Config command with subcommand
                # Will be processed after modules are loaded
                CONFIG_COMMAND=true
                if [[ -n "${2:-}" ]] && [[ ! "$2" =~ ^- ]]; then
                    CONFIG_SUBCOMMAND="$2"
                    shift 2
                    # Collect remaining args for config command
                    CONFIG_ARGS=("$@")
                    # Break out of argument parsing loop
                    break
                else
                    echo "❌ Error: --config requires a subcommand (init, set, get, list, validate)" >&2
                    return 1
                fi
                ;;
            --next-steps)
                # Will be processed after modules are loaded
                SHOW_NEXT_STEPS=true
                shift
                ;;
            --help|-h)
                # Will be processed after modules are loaded
                SHOW_HELP=true
                # Check for optional topic argument
                if [[ -n "${2:-}" ]] && [[ ! "$2" =~ ^- ]]; then
                    SHOW_HELP_TOPIC="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --profile-name|-r)
                require_arg "$1" "$2" || return 1
                PROFILE_NAME="$2"
                USER_PROVIDED_PROFILE=true
                shift 2
                ;;
            --libs|-l)
                require_arg "$1" "$2" || return 1
                LIBS_BUNDLE="$2"
                USER_PROVIDED_LIBS=true
                shift 2
                ;;
            --pkgs|-k)
                require_arg "$1" "$2" || return 1
                PKGS_BUNDLE="$2"
                USER_PROVIDED_PKGS=true
                shift 2
                ;;
            --tag|-a)
                require_arg "$1" "$2" || return 1
                IMAGE_TAG="$2"
                shift 2
                ;;
            --r-version)
                require_arg "$1" "$2" || return 1
                R_VERSION="$2"
                USER_PROVIDED_R_VERSION=true
                shift 2
                ;;
            --yes|-y)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --use-team-image|-u)
                USE_TEAM_IMAGE=true
                shift
                ;;
            --github|-G)
                CREATE_GITHUB_REPO=true
                shift
                ;;
            --force)
                FORCE_DIRECTORY=true
                shift
                ;;
            --with-examples|-x)
                WITH_EXAMPLES=true
                shift
                ;;
            --add-examples)
                ADD_EXAMPLES=true
                shift
                ;;
            *)
                echo "❌ Error: Unknown option '$1'" >&2
                echo "Use --help for usage information" >&2
                return 1
                ;;
        esac
    done

    return 0
}

#=============================================================================
# TEAM IMAGE AVAILABILITY CHECKING
#=============================================================================

#=============================================================================
# CLI VARIABLE EXPORT FUNCTION
#=============================================================================

# Function: export_cli_variables
# Purpose: Export all CLI variables for use by other modules
export_cli_variables() {
    # Core build options
    export BUILD_DOCKER BASE_IMAGE

    # Team interface variables
    export TEAM_NAME PROJECT_NAME GITHUB_ACCOUNT DOCKERFILE_PATH IMAGE_TAG

    # Mode and behavior flags
    export PREPARE_DOCKERFILE USE_TEAM_IMAGE WITH_EXAMPLES ADD_EXAMPLES

    # GitHub integration flags
    export CREATE_GITHUB_REPO SKIP_CONFIRMATION

    # Show/display flags
    export SHOW_HELP SHOW_NEXT_STEPS
}

#=============================================================================
# MAIN CLI PROCESSING FUNCTION
#=============================================================================

# Function: process_cli
# Purpose: Main function to process all CLI arguments and setup
# Arguments: All command line arguments
process_cli() {
    # Parse command line arguments
    if ! parse_cli_arguments "$@"; then
        log_error "Failed to parse command line arguments"
        return 1
    fi

    # Export variables for other modules
    export_cli_variables

    return 0
}

# Helper functions for template selection
get_template() {
    local template_type="$1"
    case "$template_type" in
        Dockerfile)
            # Use personal Dockerfile when building from team base images
            if [[ "$BASE_IMAGE" == *"core-"* ]]; then
                echo "Dockerfile.personal"
            else
                # Use unified Dockerfile for standard rocker base images
                echo "Dockerfile.unified"
            fi
            ;;
        *)
            # Always use base template (dynamic package management)
            echo "$template_type"
            ;;
    esac
}

#=============================================================================
# DYNAMIC DESCRIPTION GENERATION
#=============================================================================

# Generate DESCRIPTION file content based on Docker profile
# Reads profiles.yaml to extract packages for the specified profile
# Arguments:
#   $1 - Profile name (minimal, analysis, publishing, etc.)
# Returns:
#   DESCRIPTION file content with appropriate dependencies
# Dependencies:
#   - yq (YAML parser)
#   - profiles.yaml in TEMPLATES_DIR
generate_description_from_profile() {
    local profile="$1"
    local pkg_name="${PKG_NAME:-myproject}"
    local author_name="${AUTHOR_NAME:-Author Name}"
    local author_email="${AUTHOR_EMAIL:-author@example.com}"

    # Locate profiles.yaml
    local profiles_file="${TEMPLATES_DIR}/profiles.yaml"

    if [[ ! -f "$profiles_file" ]]; then
        log_error "profiles.yaml not found at: $profiles_file"
        return 1
    fi

    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        log_error "yq is required for dynamic DESCRIPTION generation"
        log_error "Install with: brew install yq (macOS) or snap install yq (Ubuntu)"
        return 1
    fi

    # Extract packages from profile
    local packages
    packages=$(yq eval ".${profile}.packages[]" "$profiles_file" 2>/dev/null)

    if [[ -z "$packages" ]]; then
        log_warn "No packages found for profile '$profile', using minimal defaults"
        packages="renv"
    fi

    # Base DESCRIPTION header (common to all profiles)
    cat <<EOF
Package: ${pkg_name}
Title: Research Compendium for ${pkg_name}
Version: 0.0.0.9000
Authors@R:
    person("${author_name}", email = "${author_email}", role = c("aut", "cre"))
Description: This is a research compendium for the ${pkg_name} project.
License: GPL-3
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.2.0
EOF

    # Determine which packages go in Imports vs Suggests
    # Core workflow packages (renv, here, devtools, usethis) → Imports
    # Analysis packages (dplyr, ggplot2, tidyr, etc.) → Imports if present
    # Testing/documentation packages → Suggests

    local imports=()
    local suggests=()

    # Always add core packages to Imports if present in profile
    while IFS= read -r pkg; do
        case "$pkg" in
            renv)
                imports+=("$pkg")
                ;;
            dplyr|ggplot2|tidyr|readr|stringr|lubridate|forcats|purrr)
                # Core tidyverse packages → Imports
                imports+=("$pkg")
                ;;
            sf|terra|leaflet|mapview)
                # Geospatial core → Imports
                imports+=("$pkg")
                ;;
            shiny|shinydashboard)
                # Shiny core → Imports
                imports+=("$pkg")
                ;;
            quarto|bookdown|rmarkdown|knitr)
                # Publishing → could be Imports or Suggests
                imports+=("$pkg")
                ;;
            tidymodels|caret|xgboost)
                # ML frameworks → Imports
                imports+=("$pkg")
                ;;
            BiocManager|DESeq2|edgeR)
                # Bioconductor → Imports
                imports+=("$pkg")
                ;;
            parallel|foreach|doParallel|future|furrr|data.table)
                # HPC packages → Imports
                imports+=("$pkg")
                ;;
            testthat|roxygen2|pkgdown|rcmdcheck|covr)
                # Dev/test packages → Suggests
                suggests+=("$pkg")
                ;;
            *)
                # Default: everything else → Suggests
                suggests+=("$pkg")
                ;;
        esac
    done <<< "$packages"

    # No standard suggests - users add packages as needed via install.packages()

    # Output Imports section
    if [[ ${#imports[@]} -gt 0 ]]; then
        echo "Imports:"
        for i in "${!imports[@]}"; do
            if [[ $i -eq $((${#imports[@]} - 1)) ]]; then
                echo "    ${imports[$i]}"
            else
                echo "    ${imports[$i]},"
            fi
        done
    fi

    # Output Suggests section
    if [[ ${#suggests[@]} -gt 0 ]]; then
        echo "Suggests:"
        for i in "${!suggests[@]}"; do
            if [[ $i -eq $((${#suggests[@]} - 1)) ]]; then
                echo "    ${suggests[$i]}"
            else
                echo "    ${suggests[$i]},"
            fi
        done
    fi

    # Common footer
    cat <<'EOF'
Config/testthat/edition: 3
VignetteBuilder: knitr
EOF
}

# Legacy wrapper functions for backward compatibility
# Note: get_dockerfile_template() removed - use docker.sh version instead
get_description_template() {
    # Select DESCRIPTION template based on profile name
    # Matches profile-specific templates if they exist
    if [[ -n "${PROFILE_NAME:-}" ]]; then
        local profile_desc="${TEMPLATES_DIR}/DESCRIPTION.${PROFILE_NAME}"
        if [[ -f "$profile_desc" ]]; then
            log_debug "Using profile-specific DESCRIPTION: DESCRIPTION.${PROFILE_NAME}"
            echo "DESCRIPTION.${PROFILE_NAME}"
            return 0
        fi
    fi

    # Fallback to generic DESCRIPTION template
    log_debug "Using generic DESCRIPTION template"
    get_template "DESCRIPTION"
}
get_workflow_template() {
    # Unified paradigm uses single workflow template from unified/ directory
    echo "unified/.github/workflows/render-report.yml"
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


# Note: No logging here since core.sh may not be loaded yet