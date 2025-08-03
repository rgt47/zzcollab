#!/bin/bash
##############################################################################
# ZZCOLLAB UTILITIES MODULE
##############################################################################
# 
# PURPOSE: Common utility functions used across multiple modules
#          - File and directory operations
#          - String manipulation utilities
#          - Common validation patterns
#          - Date/time utilities
#
# DEPENDENCIES: core.sh (logging)
#
# TRACKING: No file creation - pure utility functions
##############################################################################

# Validate required modules are loaded
if [[ "${ZZCOLLAB_CORE_LOADED:-}" != "true" ]]; then
    echo "❌ Error: utils.sh requires core.sh to be loaded first" >&2
    exit 1
fi

#=============================================================================
# FILE AND DIRECTORY UTILITIES
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

#=============================================================================
# STRING MANIPULATION UTILITIES
#=============================================================================

# Function: trim_whitespace
# Purpose: Remove leading and trailing whitespace
# Arguments: $1 - string to trim
trim_whitespace() {
    local var="$1"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Function: to_lowercase
# Purpose: Convert string to lowercase
# Arguments: $1 - string to convert
to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Function: to_uppercase
# Purpose: Convert string to uppercase
# Arguments: $1 - string to convert
to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Function: sanitize_filename
# Purpose: Sanitize string for use as filename
# Arguments: $1 - string to sanitize
sanitize_filename() {
    local filename="$1"
    # Replace problematic characters with underscores
    filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
    # Remove multiple consecutive underscores
    filename=$(echo "$filename" | sed 's/__*/_/g')
    # Remove leading/trailing underscores
    filename=$(echo "$filename" | sed 's/^_*//;s/_*$//')
    echo "$filename"
}

#=============================================================================
# DATE/TIME UTILITIES
#=============================================================================

# Function: get_timestamp
# Purpose: Get current timestamp in ISO format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Function: get_date
# Purpose: Get current date in YYYY-MM-DD format
get_date() {
    date +"%Y-%m-%d"
}

# Function: get_year
# Purpose: Get current year
get_year() {
    date +"%Y"
}

#=============================================================================
# VALIDATION UTILITIES
#=============================================================================

# Function: is_valid_identifier
# Purpose: Check if string is a valid identifier (package name, variable name, etc.)
# Arguments: $1 - string to validate
is_valid_identifier() {
    local identifier="$1"
    [[ "$identifier" =~ ^[a-zA-Z][a-zA-Z0-9._]*$ ]]
}

# Function: is_valid_email
# Purpose: Basic email validation
# Arguments: $1 - email to validate
is_valid_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Function: is_valid_url
# Purpose: Basic URL validation
# Arguments: $1 - URL to validate
is_valid_url() {
    local url="$1"
    [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$ ]]
}

#=============================================================================
# SYSTEM UTILITIES
#=============================================================================

# Function: get_os_type
# Purpose: Get OS type (linux, darwin, etc.)
get_os_type() {
    uname -s | to_lowercase
}

# Function: get_shell_type
# Purpose: Get current shell type
get_shell_type() {
    basename "$SHELL"
}

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
# ARRAY UTILITIES
#=============================================================================

# Function: array_contains
# Purpose: Check if array contains a value
# Arguments: $1 - value to find, $2+ - array elements
array_contains() {
    local value="$1"
    shift
    local element
    for element in "$@"; do
        [[ "$element" == "$value" ]] && return 0
    done
    return 1
}

# Function: array_unique
# Purpose: Remove duplicate elements from array (via stdout)
# Arguments: $@ - array elements
array_unique() {
    printf '%s\n' "$@" | sort -u
}

# Function: array_join
# Purpose: Join array elements with separator
# Arguments: $1 - separator, $2+ - array elements
array_join() {
    local separator="$1"
    shift
    local IFS="$separator"
    echo "$*"
}

#=============================================================================
# ERROR HANDLING UTILITIES
#=============================================================================

# Function: handle_error
# Purpose: Standard error handling with logging and exit
# Arguments: $1 - error message, $2 - exit code (optional, defaults to 1)
handle_error() {
    local error_message="$1"
    local exit_code="${2:-1}"
    
    log_error "$error_message"
    exit "$exit_code"
}

# Function: handle_warning
# Purpose: Standard warning handling with logging
# Arguments: $1 - warning message
handle_warning() {
    local warning_message="$1"
    log_warning "$warning_message"
}

# Function: fail_function
# Purpose: Standard function failure handling (log error and return 1)
# Arguments: $1 - error message
fail_function() {
    local error_message="$1"
    log_error "$error_message"
    return 1
}

# Function: require_success
# Purpose: Ensure previous command succeeded, exit if not
# Arguments: $1 - error message for failure
require_success() {
    local last_exit_code=$?
    if [[ $last_exit_code -ne 0 ]]; then
        handle_error "${1:-Command failed with exit code $last_exit_code}"
    fi
}

# Function: try_or_fail
# Purpose: Execute command, exit on failure
# Arguments: $1 - command to execute, $2 - error message (optional)
try_or_fail() {
    local cmd="$1"
    local error_msg="${2:-Command failed: $cmd}"
    
    if ! eval "$cmd"; then
        handle_error "$error_msg"
    fi
}

# Function: try_or_return
# Purpose: Execute command, return 1 on failure
# Arguments: $1 - command to execute, $2 - error message (optional)
try_or_return() {
    local cmd="$1"
    local error_msg="${2:-Command failed: $cmd}"
    
    if ! eval "$cmd"; then
        fail_function "$error_msg"
    fi
}

#=============================================================================
# PERFORMANCE UTILITIES
#=============================================================================

# Function: benchmark
# Purpose: Simple benchmarking for functions
# Arguments: $1 - function name, $2+ - function arguments
benchmark() {
    local func_name="$1"
    shift
    local start_time
    local end_time
    local duration
    
    start_time=$(date +%s.%N)
    "$func_name" "$@"
    local result=$?
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    log_info "Benchmark: $func_name completed in ${duration}s"
    
    return $result
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


log_info "Utilities module loaded successfully"