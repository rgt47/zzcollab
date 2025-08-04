#!/bin/bash
##############################################################################
# ZZCOLLAB CONSTANTS MODULE
##############################################################################
# 
# PURPOSE: Centralized global constants and environment variables
#          - Color constants for output formatting
#          - Path constants for script directories
#          - Manifest and configuration file names
#          - Default values and system constants
#
# DEPENDENCIES: None (this is a foundation module)
##############################################################################

#=============================================================================
# COLOR CONSTANTS (used across multiple scripts)
#=============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#=============================================================================
# PATH CONSTANTS
#=============================================================================

# Core script directories (computed once)
readonly ZZCOLLAB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
readonly ZZCOLLAB_TEMPLATES_DIR="$ZZCOLLAB_SCRIPT_DIR/templates"
readonly ZZCOLLAB_MODULES_DIR="$ZZCOLLAB_SCRIPT_DIR/modules"

#=============================================================================
# MANIFEST AND CONFIGURATION FILES
#=============================================================================

# Manifest files for tracking created items
readonly ZZCOLLAB_MANIFEST_JSON=".zzcollab_manifest.json"
readonly ZZCOLLAB_MANIFEST_TXT=".zzcollab_manifest.txt"

# Configuration file paths
readonly ZZCOLLAB_CONFIG_PROJECT="./zzcollab.yaml"
readonly ZZCOLLAB_CONFIG_USER_DIR="$HOME/.zzcollab"
readonly ZZCOLLAB_CONFIG_USER="$ZZCOLLAB_CONFIG_USER_DIR/config.yaml"
readonly ZZCOLLAB_CONFIG_SYSTEM="/etc/zzcollab/config.yaml"

#=============================================================================
# DEFAULT VALUES
#=============================================================================

# Docker and build defaults
readonly ZZCOLLAB_DEFAULT_BASE_IMAGE="rocker/r-ver"
readonly ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE="all"
readonly ZZCOLLAB_DEFAULT_BUILD_MODE="standard"

# Author information (can be overridden via environment variables)
readonly ZZCOLLAB_AUTHOR_NAME="${ZZCOLLAB_AUTHOR_NAME:-Ronald G. Thomas}"
readonly ZZCOLLAB_AUTHOR_EMAIL="${ZZCOLLAB_AUTHOR_EMAIL:-rgthomas@ucsd.edu}"
readonly ZZCOLLAB_AUTHOR_INSTITUTE="${ZZCOLLAB_INSTITUTE:-UCSD}"
readonly ZZCOLLAB_AUTHOR_INSTITUTE_FULL="${ZZCOLLAB_INSTITUTE_FULL:-University of California, San Diego}"

#=============================================================================
# SYSTEM CONSTANTS
#=============================================================================

# Command availability checks (cached for performance)
readonly ZZCOLLAB_JQ_AVAILABLE=$(command -v jq >/dev/null 2>&1 && echo "true" || echo "false")

# Script metadata
readonly ZZCOLLAB_SCRIPT_NAME="$(basename "${BASH_SOURCE[1]}")"
readonly ZZCOLLAB_TODAY="$(date '+%B %d, %Y')"

#=============================================================================
# MODULE LOADING FLAGS
#=============================================================================

# Module loading status flags (set by each module when loaded)
# These are set by individual modules, declared here for reference
# readonly ZZCOLLAB_CORE_LOADED=true          # Set by core.sh
# readonly ZZCOLLAB_TEMPLATES_LOADED=true     # Set by templates.sh
# readonly ZZCOLLAB_CLI_LOADED=true           # Set by cli.sh
# readonly ZZCOLLAB_CONFIG_LOADED=true        # Set by config.sh
# readonly ZZCOLLAB_ANALYSIS_LOADED=true      # Set by analysis.sh
# readonly ZZCOLLAB_GITHUB_LOADED=true        # Set by github.sh

#=============================================================================
# CONSTANTS MODULE VALIDATION
#=============================================================================

# Validate that this module is being sourced correctly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ constants.sh should be sourced, not executed directly" >&2
    exit 1
fi

# Set constants module loaded flag
readonly ZZCOLLAB_CONSTANTS_LOADED=true