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

# Load centralized constants if available, otherwise use local constants
if [[ "${ZZCOLLAB_CONSTANTS_LOADED:-}" == "true" ]]; then
    # Use centralized constants
    readonly AUTHOR_NAME="$ZZCOLLAB_AUTHOR_NAME"
    readonly AUTHOR_EMAIL="$ZZCOLLAB_AUTHOR_EMAIL"
    readonly AUTHOR_INSTITUTE="$ZZCOLLAB_AUTHOR_INSTITUTE"
    readonly AUTHOR_INSTITUTE_FULL="$ZZCOLLAB_AUTHOR_INSTITUTE_FULL"
    readonly JQ_AVAILABLE="$ZZCOLLAB_JQ_AVAILABLE"
else
    # Fallback to local constants
    readonly AUTHOR_NAME="${ZZCOLLAB_AUTHOR_NAME:-Ronald G. Thomas}"
    readonly AUTHOR_EMAIL="${ZZCOLLAB_AUTHOR_EMAIL:-rgthomas@ucsd.edu}"
    readonly AUTHOR_INSTITUTE="${ZZCOLLAB_INSTITUTE:-UCSD}"
    readonly AUTHOR_INSTITUTE_FULL="${ZZCOLLAB_INSTITUTE_FULL:-University of California, San Diego}"
    readonly JQ_AVAILABLE=$(command -v jq >/dev/null 2>&1 && echo "true" || echo "false")
fi

#=============================================================================
# LOGGING AND OUTPUT FUNCTIONS (extracted from lines 219-248)
#=============================================================================

##############################################################################
# FUNCTION: log_info
# PURPOSE:  Display informational messages with an icon
# USAGE:    log_info "message text"
# ARGS:     
#   $* - Message text to display
# RETURNS:  
#   0 - Always succeeds
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs to stderr)
# EXAMPLE:
#   log_info "Starting process..."
#   log_info "Found $count files"
##############################################################################
log_info() {
    printf "ℹ️  %s\n" "$*" >&2
}

##############################################################################
# FUNCTION: log_warn
# PURPOSE:  Display warning messages that don't stop execution
# USAGE:    log_warn "warning message"
# ARGS:     
#   $* - Warning message text to display
# RETURNS:  
#   0 - Always succeeds
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs to stderr)
# EXAMPLE:
#   log_warn "Configuration file not found, using defaults"
#   log_warn "Deprecated option used: $option"
##############################################################################
log_warn() {
    printf "⚠️  %s\n" "$*" >&2
}

##############################################################################
# FUNCTION: log_error
# PURPOSE:  Display error messages (typically before exiting)
# USAGE:    log_error "error message"
# ARGS:     
#   $* - Error message text to display
# RETURNS:  
#   0 - Always succeeds
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs to stderr)
# EXAMPLE:
#   log_error "Failed to create directory: $dir"
#   log_error "Invalid argument: $arg"
##############################################################################
log_error() {
    printf "❌ %s\n" "$*" >&2
}

##############################################################################
# FUNCTION: log_success
# PURPOSE:  Display success messages for completed operations
# USAGE:    log_success "success message"
# ARGS:     
#   $* - Success message text to display
# RETURNS:  
#   0 - Always succeeds
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs to stderr)
# EXAMPLE:
#   log_success "Package installed successfully"
#   log_success "Created $count files"
##############################################################################
log_success() {
    printf "✅ %s\n" "$*" >&2
}

#=============================================================================
# PACKAGE NAME VALIDATION FUNCTIONS (extracted from lines 51-97)
#=============================================================================

##############################################################################
# FUNCTION: validate_package_name
# PURPOSE:  Converts current directory name into a valid R package name
# USAGE:    validate_package_name
# ARGS:     
#   None - Uses current working directory
# RETURNS:  
#   0 - Success, outputs valid package name to stdout
#   1 - Error, cannot create valid package name
# GLOBALS:  
#   READ:  PWD (current working directory)
#   WRITE: None
# EXAMPLE:
#   pkg_name=$(validate_package_name)
#   if validate_package_name >/dev/null; then
#       echo "Valid directory name"
#   fi
##############################################################################
validate_package_name() {
    local dir_name
    dir_name=$(basename "$(pwd)")
    
    local pkg_name
    # Clean directory name: keep only alphanumeric and periods, limit to 50 chars
    pkg_name=$(printf '%s' "$dir_name" | tr -cd '[:alnum:].' | head -c 50)
    
    # Check if cleaning resulted in empty string
    if [[ -z "$pkg_name" ]]; then
        echo "❌ Error: Cannot determine valid package name from directory '$dir_name'" >&2
        return 1
    fi
    
    # R packages must start with a letter
    if [[ ! "$pkg_name" =~ ^[[:alpha:]] ]]; then
        echo "❌ Error: Package name must start with a letter: '$pkg_name'" >&2
        return 1
    fi
    
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
# UNIFIED TRACKING SYSTEM
#=============================================================================

# Function: track_item
# Purpose: Universal tracking function for all manifest items
# Arguments: $1 - type (directory, file, template, symlink, dotfile, docker_image)
#           $2 - primary data (path, file, template, etc.)
#           $3 - secondary data (for symlinks: target, templates: dest)
track_item() {
    local type="$1"
    local data1="$2"
    local data2="${3:-}"
    
    case "$type" in
        directory)
            if [[ "$JQ_AVAILABLE" == "true" ]] && [[ -f "$MANIFEST_FILE" ]]; then
                local tmp
                tmp=$(mktemp)
                jq --arg dir "$data1" '.directories += [$dir]' "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
            elif [[ -f "$MANIFEST_TXT" ]]; then
                echo "directory:$data1" >> "$MANIFEST_TXT"
            fi
            ;;
        file)
            if [[ "$JQ_AVAILABLE" == "true" ]] && [[ -f "$MANIFEST_FILE" ]]; then
                local tmp
                tmp=$(mktemp)
                jq --arg file "$data1" '.files += [$file]' "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
            elif [[ -f "$MANIFEST_TXT" ]]; then
                echo "file:$data1" >> "$MANIFEST_TXT"
            fi
            ;;
        template)
            if [[ "$JQ_AVAILABLE" == "true" ]] && [[ -f "$MANIFEST_FILE" ]]; then
                local tmp
                tmp=$(mktemp)
                jq --arg template "$data1" --arg dest "$data2" '.template_files += [{"template": $template, "destination": $dest}]' "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
            elif [[ -f "$MANIFEST_TXT" ]]; then
                echo "template:$data1:$data2" >> "$MANIFEST_TXT"
            fi
            ;;
        symlink)
            if [[ "$JQ_AVAILABLE" == "true" ]] && [[ -f "$MANIFEST_FILE" ]]; then
                local tmp
                tmp=$(mktemp)
                jq --arg link "$data1" --arg target "$data2" '.symlinks += [{"link": $link, "target": $target}]' "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
            elif [[ -f "$MANIFEST_TXT" ]]; then
                echo "symlink:$data1:$data2" >> "$MANIFEST_TXT"
            fi
            ;;
        dotfile)
            if [[ "$JQ_AVAILABLE" == "true" ]] && [[ -f "$MANIFEST_FILE" ]]; then
                local tmp
                tmp=$(mktemp)
                jq --arg dotfile "$data1" '.dotfiles += [$dotfile]' "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
            elif [[ -f "$MANIFEST_TXT" ]]; then
                echo "dotfile:$data1" >> "$MANIFEST_TXT"
            fi
            ;;
        docker_image)
            if [[ "$JQ_AVAILABLE" == "true" ]] && [[ -f "$MANIFEST_FILE" ]]; then
                local tmp
                tmp=$(mktemp)
                jq --arg image "$data1" '.docker_image = $image' "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
            elif [[ -f "$MANIFEST_TXT" ]]; then
                echo "docker_image:$data1" >> "$MANIFEST_TXT"
            fi
            ;;
        *)
            log_error "Unknown tracking type: $type"
            return 1
            ;;
    esac
}

# Legacy wrapper functions for backward compatibility
track_directory() { track_item "directory" "$1"; }
track_file() { track_item "file" "$1"; }
track_template_file() { track_item "template" "$1" "$2"; }
track_symlink() { track_item "symlink" "$1" "$2"; }
track_dotfile() { track_item "dotfile" "$1"; }
track_docker_image() { track_item "docker_image" "$1"; }

#=============================================================================
# UNIFIED VALIDATION SYSTEM
#=============================================================================

# Function: validate_files_exist
# Purpose: Check that required files exist
# Arguments: $1 - description, $2+ - file paths
validate_files_exist() {
    local description="$1"
    shift
    local files=("$@")
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_success "$description: all files exist"
        return 0
    else
        log_error "$description: missing files: ${missing_files[*]}"
        return 1
    fi
}

# Function: validate_directories_exist
# Purpose: Check that required directories exist
# Arguments: $1 - description, $2+ - directory paths
validate_directories_exist() {
    local description="$1"
    shift
    local directories=("$@")
    local missing_dirs=()
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -eq 0 ]]; then
        log_success "$description: all directories exist"
        return 0
    else
        log_error "$description: missing directories: ${missing_dirs[*]}"
        return 1
    fi
}

# Function: validate_commands_exist
# Purpose: Check that required commands are available
# Arguments: $1 - description, $2+ - command names
validate_commands_exist() {
    local description="$1"
    shift
    local commands=("$@")
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -eq 0 ]]; then
        log_success "$description: all commands available"
        return 0
    else
        log_error "$description: missing commands: ${missing_commands[*]}"
        return 1
    fi
}

# Function: validate_with_callback
# Purpose: Generic validation with custom validation function
# Arguments: $1 - description, $2 - validation function, $3+ - arguments to validation function
validate_with_callback() {
    local description="$1"
    local validation_func="$2"
    shift 2
    
    log_info "Validating $description..."
    
    if "$validation_func" "$@"; then
        log_success "$description validation passed"
        return 0
    else
        log_error "$description validation failed"
        return 1
    fi
}

#=============================================================================
# LEGACY COMPATIBILITY FUNCTIONS (for team_init.sh)
#=============================================================================

# Function: require_module
# Purpose: Validate that required modules are loaded, with standardized error handling
# Arguments: $1+ - module names to check (e.g., "core", "templates")
# Usage: require_module "core" "templates"
# Note: This replaces the repeated validation patterns across all modules
require_module() {
    local current_module="${BASH_SOURCE[2]##*/}"  # Get calling module name
    current_module="${current_module%.sh}"
    
    for module in "$@"; do
        local module_var="ZZCOLLAB_${module^^}_LOADED"
        if [[ "${!module_var:-}" != "true" ]]; then
            echo "❌ Error: ${current_module}.sh requires ${module}.sh to be loaded first" >&2
            exit 1
        fi
    done
}

# Function: print_error
# Purpose: Legacy alias for log_error (used by team_init.sh)
print_error() {
    log_error "$@"
}

# Function: print_warning
# Purpose: Legacy alias for log_warning (used by team_init.sh)
print_warning() {
    log_warning "$@"
}

# Function: print_success
# Purpose: Legacy alias for log_success (used by team_init.sh)
print_success() {
    log_success "$@"
}

# Function: print_status
# Purpose: Legacy alias for log_info (used by team_init.sh)
print_status() {
    log_info "$@"
}

# Function: confirm
# Purpose: Interactive confirmation prompt
# Arguments: $1 - prompt message (optional)
# Returns: 0 if user confirms (y/Y), 1 otherwise
confirm() {
    local prompt="${1:-Continue?}"
    read -p "$prompt [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
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