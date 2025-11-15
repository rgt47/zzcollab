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
    [[ -n "${2:-}" ]] || { echo "❌ Error: $1 requires an argument" >&2; exit 1; }
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

# Multi-architecture support configuration
MULTIARCH_VERSE_IMAGE="${MULTIARCH_VERSE_IMAGE:-rocker/verse}"
FORCE_PLATFORM="${FORCE_PLATFORM:-auto}"
export MULTIARCH_VERSE_IMAGE FORCE_PLATFORM

# New user-friendly interface variables
TEAM_NAME=""
PROJECT_NAME=""
GITHUB_ACCOUNT=""
DOCKERHUB_ACCOUNT=""
DOCKERFILE_PATH=""
IMAGE_TAG=""
R_VERSION=""  # R version for Docker build (extracted from renv.lock or specified via --r-version)

# Base image selection for team initialization
readonly DEFAULT_INIT_BASE_IMAGE="${ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE:-r-ver}"
INIT_BASE_IMAGE="$DEFAULT_INIT_BASE_IMAGE"    # Options: r-ver, rstudio, verse, all

# Initialization mode variables
PREPARE_DOCKERFILE=false
SKIP_CONFIRMATION=false
CREATE_GITHUB_REPO=false
FORCE_DIRECTORY=false    # Skip directory validation (advanced users)
WITH_EXAMPLES=false      # Include example files and templates in workspace
ADD_EXAMPLES=false       # Add examples to existing project

# Profile bundle variables (system libraries and R packages)
LIBS_BUNDLE=""    # System library bundle (e.g., alpine, bioinfo, geospatial)
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
                require_arg "$1" "$2"
                BASE_IMAGE="$2"
                USER_PROVIDED_BASE_IMAGE=true
                shift 2
                ;;
            --team|-t)
                require_arg "$1" "$2"
                TEAM_NAME="$2"
                shift 2
                ;;
            --project-name|-p)
                require_arg "$1" "$2"
                PROJECT_NAME="$2"
                shift 2
                ;;
            --github-account|-g)
                require_arg "$1" "$2"
                GITHUB_ACCOUNT="$2"
                shift 2
                ;;
            --dockerfile|-f)
                require_arg "$1" "$2"
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
                    exit 1
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
                require_arg "$1" "$2"
                PROFILE_NAME="$2"
                USER_PROVIDED_PROFILE=true
                shift 2
                ;;
            --libs|-l)
                require_arg "$1" "$2"
                LIBS_BUNDLE="$2"
                USER_PROVIDED_LIBS=true
                shift 2
                ;;
            --pkgs|-k)
                require_arg "$1" "$2"
                PKGS_BUNDLE="$2"
                USER_PROVIDED_PKGS=true
                shift 2
                ;;
            --tag|-a)
                require_arg "$1" "$2"
                IMAGE_TAG="$2"
                shift 2
                ;;
            --r-version)
                require_arg "$1" "$2"
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
                exit 1
                ;;
        esac
    done
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
    export TEAM_NAME PROJECT_NAME GITHUB_ACCOUNT DOCKERHUB_ACCOUNT DOCKERFILE_PATH IMAGE_TAG

    # Mode and behavior flags
    export PREPARE_DOCKERFILE USE_TEAM_IMAGE WITH_EXAMPLES ADD_EXAMPLES

    # GitHub integration flags
    export CREATE_GITHUB_REPO SKIP_CONFIRMATION

    # Show/display flags
    export SHOW_HELP SHOW_NEXT_STEPS
}

#=============================================================================
# CLI VALIDATION FUNCTIONS
#=============================================================================

# Function: validate_cli_arguments
# Purpose: Validate CLI argument combinations and required values
validate_cli_arguments() {
    # No validation needed currently
    :
}

#=============================================================================
# MAIN CLI PROCESSING FUNCTION
#=============================================================================

# Function: process_cli
# Purpose: Main function to process all CLI arguments and setup
# Arguments: All command line arguments
process_cli() {
    # Parse command line arguments
    parse_cli_arguments "$@"

    # Validate argument combinations
    validate_cli_arguments

    # Export variables for other modules
    export_cli_variables
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
#   $1 - Profile name (minimal, analysis, alpine_minimal, etc.)
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
    echo "unified/.github/workflows/render-paper.yml"
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


# Note: No logging here since core.sh may not be loaded yet