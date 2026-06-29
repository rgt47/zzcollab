#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CONSTANTS LIBRARY
##############################################################################
#
# PURPOSE: Centralized global constants and environment variables
#          - Path constants for script directories
#          - Configuration file names
#          - Default values
#
# DEPENDENCIES: None (this is a foundation library)
##############################################################################

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
[[ -z "${ZZCOLLAB_LIB_DIR:-}" ]] && ZZCOLLAB_LIB_DIR="$ZZCOLLAB_HOME/lib"
[[ -z "${ZZCOLLAB_MODULES_DIR:-}" ]] && ZZCOLLAB_MODULES_DIR="$ZZCOLLAB_HOME/modules"
[[ -z "${ZZCOLLAB_TEMPLATES_DIR:-}" ]] && ZZCOLLAB_TEMPLATES_DIR="$ZZCOLLAB_HOME/templates"
readonly ZZCOLLAB_LIB_DIR ZZCOLLAB_MODULES_DIR ZZCOLLAB_TEMPLATES_DIR

#=============================================================================
# CONFIGURATION FILES (user settings)
#=============================================================================

# Configuration file hierarchy (loaded in priority order)
# Use :- so callers can override paths via environment variables (e.g. tests).
readonly ZZCOLLAB_CONFIG_PROJECT="${ZZCOLLAB_CONFIG_PROJECT:-./zzcollab.yaml}"
readonly ZZCOLLAB_CONFIG_USER_DIR="${ZZCOLLAB_CONFIG_USER_DIR:-$HOME/.zzcollab}"
readonly ZZCOLLAB_CONFIG_USER="${ZZCOLLAB_CONFIG_USER:-$ZZCOLLAB_CONFIG_USER_DIR/config.yaml}"
readonly ZZCOLLAB_CONFIG_SYSTEM="${ZZCOLLAB_CONFIG_SYSTEM:-/etc/zzcollab/config.yaml}"

#=============================================================================
# DEFAULT VALUES
#=============================================================================

# Single source of truth for the zzcollab version. The CLI --version, the
# template stamp, and the R package DESCRIPTION all track this number.
# install.sh rewrites ZZCOLLAB_VERSION in the installed copy.
readonly ZZCOLLAB_VERSION="0.1.0"
readonly ZZCOLLAB_TEMPLATE_VERSION="$ZZCOLLAB_VERSION"
readonly ZZCOLLAB_DEFAULT_BASE_IMAGE="rocker/r-ver"
readonly ZZCOLLAB_DEFAULT_R_VERSION="4.6.0"
# Package versions for the minimal starter renv.lock. Bumped per release to
# track current CRAN/PPM versions, so a generated lockfile pins versions that
# still have precompiled binaries. An older pin (e.g. an archived renv) is
# source-only on PPM and compiles from scratch.
readonly ZZCOLLAB_DEFAULT_RENV_VERSION="1.2.3"
readonly ZZCOLLAB_DEFAULT_TINYTEST_VERSION="1.4.3"
# Pinned tag for the zzrenvcheck validation tool installed into the image.
# Bump this constant when upgrading zzrenvcheck.
readonly ZZRENVCHECK_TAG="${ZZRENVCHECK_TAG:-v0.3.1}"

# Author information (should be set via environment variables or config file)
readonly ZZCOLLAB_AUTHOR_NAME="${ZZCOLLAB_AUTHOR_NAME:-Your Name}"
readonly ZZCOLLAB_AUTHOR_EMAIL="${ZZCOLLAB_AUTHOR_EMAIL:-your.email@example.com}"
readonly ZZCOLLAB_AUTHOR_INSTITUTE="${ZZCOLLAB_INSTITUTE:-Your Institution}"
readonly ZZCOLLAB_AUTHOR_INSTITUTE_FULL="${ZZCOLLAB_INSTITUTE_FULL:-Your Institution Full Name}"

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
