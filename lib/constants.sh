#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CONSTANTS LIBRARY
##############################################################################
#
# PURPOSE: Centralized global constants and environment variables
#          - Color constants for output formatting
#          - Path constants for script directories
#          - Manifest and configuration file names
#          - Default values and system constants
#
# DEPENDENCIES: None (this is a foundation library)
##############################################################################

#=============================================================================
# COLOR CONSTANTS (ANSI escape codes for terminal output formatting)
#=============================================================================

readonly RED='\033[0;31m'      # Red text - used for errors and failures
readonly GREEN='\033[0;32m'    # Green text - used for success messages
readonly YELLOW='\033[1;33m'   # Bold yellow text - used for warnings
readonly BLUE='\033[0;34m'     # Blue text - used for information messages
readonly NC='\033[0m'          # No Color - resets terminal to default

#=============================================================================
# PATH CONSTANTS (computed dynamically)
#=============================================================================

# Determine ZZCOLLAB_HOME dynamically
# Priority: 1. ZZCOLLAB_HOME env var, 2. ~/.zzcollab, 3. derive from script location
if [[ -z "${ZZCOLLAB_HOME:-}" ]]; then
    # Try to derive from this script's location
    # This script is at $ZZCOLLAB_HOME/lib/constants.sh
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$_script_dir" == */lib ]]; then
        ZZCOLLAB_HOME="${_script_dir%/lib}"
    elif [[ -d "$HOME/.zzcollab" ]]; then
        ZZCOLLAB_HOME="$HOME/.zzcollab"
    else
        ZZCOLLAB_HOME="$HOME/bin/zzcollab-support"
    fi
    unset _script_dir
fi
readonly ZZCOLLAB_HOME

# Derived directories - built from ZZCOLLAB_HOME
# Only set if not already defined (allows zzcollab.sh to pre-set paths)
[[ -z "${ZZCOLLAB_BIN_DIR:-}" ]] && ZZCOLLAB_BIN_DIR="$ZZCOLLAB_HOME/bin"
[[ -z "${ZZCOLLAB_LIB_DIR:-}" ]] && ZZCOLLAB_LIB_DIR="$ZZCOLLAB_HOME/lib"
[[ -z "${ZZCOLLAB_MODULES_DIR:-}" ]] && ZZCOLLAB_MODULES_DIR="$ZZCOLLAB_HOME/modules"
[[ -z "${ZZCOLLAB_TEMPLATES_DIR:-}" ]] && ZZCOLLAB_TEMPLATES_DIR="$ZZCOLLAB_HOME/templates"
readonly ZZCOLLAB_BIN_DIR ZZCOLLAB_LIB_DIR ZZCOLLAB_MODULES_DIR ZZCOLLAB_TEMPLATES_DIR

# Legacy compatibility aliases
readonly ZZCOLLAB_SCRIPT_DIR="$ZZCOLLAB_HOME"

#=============================================================================
# MANIFEST AND CONFIGURATION FILES (for project tracking and user settings)
#=============================================================================

readonly ZZCOLLAB_MANIFEST_JSON=".zzcollab/manifest.json"
readonly ZZCOLLAB_MANIFEST_TXT=".zzcollab/manifest.txt"

# Configuration file hierarchy (loaded in priority order)
readonly ZZCOLLAB_CONFIG_PROJECT="./zzcollab.yaml"
readonly ZZCOLLAB_CONFIG_USER_DIR="$HOME/.zzcollab"
readonly ZZCOLLAB_CONFIG_USER="$ZZCOLLAB_CONFIG_USER_DIR/config.yaml"
readonly ZZCOLLAB_CONFIG_SYSTEM="/etc/zzcollab/config.yaml"

#=============================================================================
# DEFAULT VALUES
#=============================================================================

readonly ZZCOLLAB_DEFAULT_BASE_IMAGE="rocker/r-ver"
readonly ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE="r-ver"
readonly ZZCOLLAB_DEFAULT_PROFILE_NAME="ubuntu_standard_analysis_vim"
readonly ZZCOLLAB_DEFAULT_R_VERSION="4.5.2"

# Author information (should be set via environment variables or config file)
readonly ZZCOLLAB_AUTHOR_NAME="${ZZCOLLAB_AUTHOR_NAME:-Your Name}"
readonly ZZCOLLAB_AUTHOR_EMAIL="${ZZCOLLAB_AUTHOR_EMAIL:-your.email@example.com}"
readonly ZZCOLLAB_AUTHOR_INSTITUTE="${ZZCOLLAB_INSTITUTE:-Your Institution}"
readonly ZZCOLLAB_AUTHOR_INSTITUTE_FULL="${ZZCOLLAB_INSTITUTE_FULL:-Your Institution Full Name}"

#=============================================================================
# SYSTEM CONSTANTS
#=============================================================================

readonly ZZCOLLAB_JQ_AVAILABLE=$(command -v jq >/dev/null 2>&1 && echo "true" || echo "false")

# Script metadata
readonly ZZCOLLAB_SCRIPT_NAME="$(basename "${BASH_SOURCE[1]:-zzcollab}")"
readonly ZZCOLLAB_TODAY="$(date '+%B %d, %Y')"

#=============================================================================
# EXIT CODE CONSTANTS
#=============================================================================

readonly EXIT_SUCCESS=0        # Successful execution
readonly EXIT_ERROR=1          # General error
readonly EXIT_USAGE=2          # Usage error (invalid arguments)
readonly EXIT_CONFIG=3         # Configuration error
readonly EXIT_NOTFOUND=4       # Required file or resource not found
readonly EXIT_PERMISSION=5     # Permission denied
readonly EXIT_VALIDATION=6     # Validation failed
readonly EXIT_DOCKER=7         # Docker-related error
readonly EXIT_NETWORK=8        # Network error
readonly EXIT_INTERRUPT=130    # User interrupted (Ctrl+C)

#=============================================================================
# CONSTANTS LIBRARY VALIDATION
#=============================================================================

# Validate that this library is being sourced correctly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ Error: constants.sh should be sourced, not executed directly" >&2
    exit 1
fi

# Set constants module loaded flag
readonly ZZCOLLAB_CONSTANTS_LOADED=true
