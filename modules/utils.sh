#!/bin/bash
##############################################################################
# ZZCOLLAB UTILITIES MODULE (SIMPLIFIED)
##############################################################################
# 
# PURPOSE: Essential utility functions used across multiple modules
#          - Core file and directory operations with error handling
#          - Essential validation patterns
#          - System checks
#
# DEPENDENCIES: core.sh (logging, tracking)
#
# TRACKING: No file creation - pure utility functions
##############################################################################

# Validate required modules are loaded
require_module "core"

#=============================================================================
# CORE FILE AND DIRECTORY OPERATIONS
#=============================================================================

# Function: safe_mkdir
# Purpose: Create directory with error handling and logging
# Arguments: $1 - directory path, $2 - description (optional)
safe_mkdir() {
    local dir="$1"
    local description="${2:-directory}"
    
    if mkdir -p "$dir" 2>/dev/null; then
        log_info "Created $description: $dir"
        track_directory "$dir"
        return 0
    else
        log_error "Failed to create $description: $dir"
        return 1
    fi
}

# Function: safe_copy
# Purpose: Copy file with error handling and logging
# Arguments: $1 - source, $2 - destination, $3 - description (optional)
safe_copy() {
    local src="$1"
    local dest="$2"
    local description="${3:-file}"
    
    if cp "$src" "$dest" 2>/dev/null; then
        log_info "Copied $description: $src → $dest"
        track_file "$dest"
        return 0
    else
        log_error "Failed to copy $description: $src → $dest"
        return 1
    fi
}

# Function: safe_symlink
# Purpose: Create symbolic link with error handling and logging
# Arguments: $1 - target, $2 - link name, $3 - description (optional)
safe_symlink() {
    local target="$1"
    local link="$2"
    local description="${3:-symlink}"
    
    if ln -sf "$target" "$link" 2>/dev/null; then
        log_info "Created $description: $link → $target"
        track_symlink "$link" "$target"
        return 0
    else
        log_error "Failed to create $description: $link → $target"
        return 1
    fi
}

#=============================================================================
# ESSENTIAL VALIDATION FUNCTIONS
#=============================================================================

# Function: file_exists_and_readable
# Purpose: Check if file exists and is readable
# Arguments: $1 - file path
file_exists_and_readable() {
    [[ -f "$1" && -r "$1" ]]
}

# Function: dir_exists_and_writable
# Purpose: Check if directory exists and is writable
# Arguments: $1 - directory path
dir_exists_and_writable() {
    [[ -d "$1" && -w "$1" ]]
}

# Function: is_valid_identifier
# Purpose: Check if string is a valid identifier (package name, variable name, etc.)
# Arguments: $1 - string to validate
is_valid_identifier() {
    local identifier="$1"
    [[ "$identifier" =~ ^[a-zA-Z][a-zA-Z0-9._]*$ ]]
}

#=============================================================================
# ESSENTIAL SYSTEM UTILITIES
#=============================================================================

# Function: is_docker_available
# Purpose: Check if Docker is available and running
is_docker_available() {
    command_exists docker && docker info >/dev/null 2>&1
}

# Function: is_git_repo
# Purpose: Check if current directory is a git repository
is_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

#=============================================================================
# MODULE VALIDATION
#=============================================================================

log_info "Utilities module (simplified) loaded successfully"