#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CLI MODULE
##############################################################################
#
# PURPOSE: CLI variable defaults and workflow-template helper.
#          - Initializes the flag/interface variables that downstream
#            modules read (defaults; live values are set by the command
#            dispatchers in zzcollab.sh, e.g. cmd_docker).
#          - Provides get_workflow_template() for the GitHub module.
#
# NOTE: Argument parsing lives in main()/cmd_* in zzcollab.sh. The former
#       parse_cli_arguments/export_cli_variables/process_cli apparatus and
#       its validators were removed: they were unreachable (cmd_init invoked
#       process_cli with no arguments) and their flag set contradicted the
#       live parser. See CHANGELOG for details.
#
# DEPENDENCIES: lib/core.sh (logging), lib/constants.sh (defaults)
##############################################################################

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

# Track whether user explicitly provided these flags (read by config.sh and
# zzcollab.sh for team-member validation and config precedence)
USER_PROVIDED_BASE_IMAGE=false
USER_PROVIDED_LIBS=false
USER_PROVIDED_PKGS=false
USER_PROVIDED_PROFILE=false
USER_PROVIDED_R_VERSION=false
USE_TEAM_IMAGE=false    # Deprecated: retained for backward compatibility

#=============================================================================
# WORKFLOW TEMPLATE HELPER
#=============================================================================

get_workflow_template() {
    # Unified paradigm uses single workflow template from unified/ directory
    echo "unified/.github/workflows/render-report.yml"
}

#=============================================================================
# MODULE LOADED
#=============================================================================
