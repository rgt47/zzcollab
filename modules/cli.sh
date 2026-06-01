#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CLI MODULE
##############################################################################
#
# PURPOSE: CLI validation utilities, variable defaults, and workflow helper.
#          - Validation functions (validate_*) that vet user-supplied values;
#            covered by tests/shell/test-cli.sh.
#          - Initializes the flag/interface variables that downstream modules
#            read (defaults; live values are set by the command dispatchers in
#            zzcollab.sh, e.g. cmd_docker).
#          - Provides get_workflow_template() for the GitHub module.
#
# NOTE: Argument parsing lives in main()/cmd_* in zzcollab.sh. The former
#       parse_cli_arguments/export_cli_variables/process_cli apparatus was
#       removed: it was unreachable (cmd_init invoked process_cli with no
#       arguments) and its flag set contradicted the live parser. See
#       CHANGELOG for details.
#
# DEPENDENCIES: lib/core.sh (logging), lib/constants.sh (defaults)
##############################################################################

#=============================================================================
# CLI ARGUMENT VALIDATION FUNCTIONS
#=============================================================================

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

# validate_r_version() is defined in lib/core.sh (shared, supports
# --strict and --lenient modes). CLI uses strict mode (X.Y.Z required).

#=============================================================================
# CLI VARIABLE INITIALIZATION
#=============================================================================

# Initialize variables for command line options
# Use centralized constants if available
readonly DEFAULT_BASE_IMAGE="${ZZCOLLAB_DEFAULT_BASE_IMAGE:-rocker/r-ver}"
BASE_IMAGE="${DEFAULT_BASE_IMAGE}"

# User-friendly interface variables
TEAM_NAME=""
PROJECT_NAME=""
GITHUB_ACCOUNT=""
R_VERSION=""  # R version for Docker build (extracted from renv.lock or specified via --r-version)

# Initialization mode variables
SKIP_CONFIRMATION=false
CREATE_GITHUB_REPO=false
FORCE_DIRECTORY=false    # Skip directory validation (advanced users)
WITH_EXAMPLES=false      # Include example files and templates in workspace

# Track whether the user explicitly chose a profile (read by init_export_config_vars
# in zzcollab.sh so a CLI --profile flag wins over the configured default).
USER_PROVIDED_PROFILE=false

#=============================================================================
# WORKFLOW TEMPLATE HELPER
#=============================================================================

get_workflow_template() {
    # The report-rendering workflow installed into generated projects.
    echo "workflows/render-report.yml"
}

#=============================================================================
# MODULE LOADED
#=============================================================================

