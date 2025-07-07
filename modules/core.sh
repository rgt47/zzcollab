#!/bin/bash
##############################################################################
# ZZCOLLAB CORE MODULE
##############################################################################
# 
# PURPOSE: Core infrastructure functions required by all other modules
#          - Logging system
#          - Package name validation
#          - Utility functions
#          - Constants and environment setup
#
# DEPENDENCIES: None (this is the foundation module)
##############################################################################

#=============================================================================
# CORE CONSTANTS (from original zzcollab.sh)
#=============================================================================

# Author information can be customized via environment variables
readonly AUTHOR_NAME="${ZZCOLLAB_AUTHOR_NAME:-Ronald G. Thomas}"
readonly AUTHOR_EMAIL="${ZZCOLLAB_AUTHOR_EMAIL:-rgthomas@ucsd.edu}"
readonly AUTHOR_INSTITUTE="${ZZCOLLAB_INSTITUTE:-UCSD}"
readonly AUTHOR_INSTITUTE_FULL="${ZZCOLLAB_INSTITUTE_FULL:-University of California, San Diego}"

#=============================================================================
# LOGGING AND OUTPUT FUNCTIONS (extracted from lines 219-248)
#=============================================================================

# Function: log_info
# Purpose: Display informational messages with an icon
# All log functions send output to stderr (&2) so they don't interfere with script output
log_info() {
    # $* expands to all function arguments as a single string
    # printf is safer than echo for consistent formatting across different shells
    printf "ℹ️  %s\n" "$*" >&2
}

# Function: log_warn  
# Purpose: Display warning messages that don't stop execution
log_warn() {
    printf "⚠️  %s\n" "$*" >&2
}

# Function: log_error
# Purpose: Display error messages (typically before exiting)
log_error() {
    printf "❌ %s\n" "$*" >&2
}

# Function: log_success
# Purpose: Display success messages for completed operations
log_success() {
    printf "✅ %s\n" "$*" >&2
}

#=============================================================================
# PACKAGE NAME VALIDATION FUNCTIONS (extracted from lines 51-97)
#=============================================================================

# Function: validate_package_name
# Purpose: Converts current directory name into a valid R package name
# R package naming rules: Only letters, numbers, and periods; must start with a letter
# Returns: A valid package name string or exits with error
validate_package_name() {
    # Declare local variables to avoid affecting global scope
    local dir_name
    # basename extracts the final directory name from the current working directory path
    # $(pwd) returns the current working directory as an absolute path
    dir_name=$(basename "$(pwd)")
    
    local pkg_name
    # Clean the directory name to create a valid R package name:
    # printf '%s' "$dir_name" - outputs the directory name without adding newlines
    # tr -cd '[:alnum:].' - removes all characters EXCEPT alphanumeric and periods
    # head -c 50 - limits to first 50 characters to avoid overly long names
    pkg_name=$(printf '%s' "$dir_name" | tr -cd '[:alnum:].' | head -c 50)
    
    # Check if the cleaning process resulted in an empty string
    if [[ -z "$pkg_name" ]]; then
        # >&2 redirects output to stderr (standard error stream)
        echo "❌ Error: Cannot determine valid package name from directory '$dir_name'" >&2
        return 1  # Exit function with error status
    fi
    
    # R packages must start with a letter (not a number or special character)
    # =~ operator performs regex pattern matching
    # ^[[:alpha:]] means "starts with any alphabetic character"
    # The ! negates the condition, so this checks if it does NOT start with a letter
    if [[ ! "$pkg_name" =~ ^[[:alpha:]] ]]; then
        echo "❌ Error: Package name must start with a letter: '$pkg_name'" >&2
        return 1
    fi
    
    # Output the valid package name (this becomes the return value when called with $())
    printf '%s' "$pkg_name"
}

#=============================================================================
# UTILITY FUNCTIONS (extracted from lines 335-384)
#=============================================================================

# Function: command_exists
# Purpose: Check if a command is available in the current PATH
# Usage: if command_exists docker; then ... fi
# Returns: 0 if command exists, 1 if not
command_exists() {
    # command -v is the POSIX-compliant way to check for command availability
    # It's more portable than 'which' and 'type'
    # Redirect both stdout and stderr to /dev/null to suppress output
    command -v "$1" >/dev/null 2>&1
}

#=============================================================================
# CORE MODULE VALIDATION
#=============================================================================

# Validate that this module is being sourced correctly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "core.sh should be sourced, not executed directly"
    exit 1
fi

# Set core module loaded flag
readonly ZZCOLLAB_CORE_LOADED=true