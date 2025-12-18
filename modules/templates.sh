#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB TEMPLATES MODULE
##############################################################################
# 
# PURPOSE: Template processing engine and file creation utilities
#          - Template copying with variable substitution
#          - Safe file creation functions
#          - Variable substitution system
#
# DEPENDENCIES: core.sh (for logging functions)
##############################################################################

# Validate core module is loaded
# Validate required modules are loaded
require_module "core"

#=============================================================================
# TEMPLATE FILE PROCESSING FUNCTIONS (extracted from lines 250-334)
#=============================================================================

# Function: copy_template_file
# Purpose: Copy a template file and substitute variables within it
# USAGE:    copy_template_file "Dockerfile" "Dockerfile" ["Docker config"] [templates_dir]
# ARGS:
#   $1 - template: Template filename (relative to templates directory)
#   $2 - dest: Destination path for the copied file
#   $3 - description: Optional description for logging (defaults to destination path)
#   $4 - templates_dir: Optional templates directory (defaults to TEMPLATES_DIR global)
# RETURNS:
#   0 - File copied and variables substituted successfully
#   1 - Failed (template not found, copy failed, substitution failed)
# GLOBALS:
#   READ: TEMPLATES_DIR (if $4 not provided - fallback for backward compatibility)
#   WRITE: None
# Example:
#   copy_template_file "Dockerfile" "Dockerfile" "Docker configuration"
#   copy_template_file "Makefile" "Makefile" "Makefile" "/custom/templates"
copy_template_file() {
    # Declare local variables to avoid affecting global scope
    local template="$1"
    local dest="$2"
    local description="${3:-$dest}"  # Use $dest as default if $3 not provided
    local templates_dir="${4:-$TEMPLATES_DIR}"  # Use parameter or fall back to global

    # Input validation: ensure minimum required arguments are provided
    [[ $# -ge 2 ]] || { log_error "copy_template_file: need template and destination"; return 1; }

    # Validate templates_dir is set
    if [[ -z "$templates_dir" ]]; then
        log_error "copy_template_file: templates directory not specified and TEMPLATES_DIR global not set"
        return 1
    fi

    # Check if the source template file exists
    if [[ ! -f "$templates_dir/$template" ]]; then
        log_error "Template not found: $templates_dir/$template"
        return 1
    fi
    
    # Skip copying if destination file already exists (don't overwrite existing work)
    if [[ -f "$dest" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    local dest_dir
    dest_dir=$(dirname "$dest")  # Extract directory part of destination path
    # Check if we need to create a directory (not current dir) and it doesn't exist
    if [[ "$dest_dir" != "." ]] && [[ ! -d "$dest_dir" ]]; then
        # mkdir -p creates parent directories as needed
        if ! mkdir -p "$dest_dir"; then
            log_error "Failed to create directory: $dest_dir"
            return 1
        fi
    fi
    
    # Copy the template file to the destination
    if ! cp "$templates_dir/$template" "$dest"; then
        log_error "Failed to copy template: $template"
        return 1
    fi
    
    # Replace placeholder variables in the copied file with actual values
    if ! substitute_variables "$dest"; then
        log_error "Failed to substitute variables in: $dest"
        return 1
    fi

    # Success - no logging here, let calling function handle user messages
    return 0
}

# Function: substitute_variables
# Purpose: Replace template placeholders (${VAR_NAME}) with actual variable values
# USAGE:    substitute_variables "path/to/file" [pkg_name] [author_name] ...
# ARGS:
#   $1 - file: Path to file containing template variables to substitute
#   $2 - pkg_name: Optional package name (overrides PKG_NAME global)
#   $3 - author_name: Optional author name (overrides AUTHOR_NAME global)
#   Additional optional parameters for other template variables (can extend as needed)
# RETURNS:
#   0 - Variables substituted successfully
#   1 - File not found or substitution failed
# GLOBALS:
#   READ: PKG_NAME, AUTHOR_NAME, AUTHOR_EMAIL, AUTHOR_INSTITUTE, AUTHOR_INSTITUTE_FULL,
#         BASE_IMAGE, R_VERSION, USERNAME, AUTHOR_LAST, AUTHOR_ORCID, MANUSCRIPT_TITLE,
#         GITHUB_ACCOUNT, TEAM_NAME, PROJECT_NAME, DOCKERHUB_ACCOUNT,
#         R_PACKAGES_INSTALL_CMD, SYSTEM_DEPS_INSTALL_CMD, LIBS_BUNDLE, PKGS_BUNDLE
#   WRITE: None (exports to environment for envsubst)
# NOTE: Optional parameters override corresponding globals. Falls back to globals if not provided.
# Uses envsubst (environment variable substitution) tool for safe replacement
substitute_variables() {
    local file="$1"
    local pkg_name_override="${2:-}"
    local author_name_override="${3:-}"

    # Verify the file exists before attempting to process it
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    
    # Export all variables that templates might reference
    # envsubst only substitutes variables that are in the environment
    # Use parameter overrides if provided, otherwise use globals
    # Note: PKG_NAME may be readonly from main script - only set if override provided
    if [[ -n "$pkg_name_override" ]]; then
        PKG_NAME="$pkg_name_override" 2>/dev/null || true
    fi
    export PKG_NAME
    if [[ -n "$author_name_override" ]]; then
        AUTHOR_NAME="$author_name_override" 2>/dev/null || true
    fi
    export AUTHOR_NAME
    export AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE
    export R_VERSION="${R_VERSION:-latest}"  # Provide default value if not set
    export USERNAME="${USERNAME:-analyst}"   # Default Docker user

    # Additional variables for manuscript paradigm
    export PACKAGE_NAME="$PKG_NAME"  # Alias for consistency
    export AUTHOR_LAST="${AUTHOR_LAST:-}"  # Author last name
    export AUTHOR_ORCID="${AUTHOR_ORCID:-}"  # ORCID identifier
    export MANUSCRIPT_TITLE="${MANUSCRIPT_TITLE:-Research Compendium Analysis}"  # Default manuscript title
    export DATE="$(date +%Y-%m-%d)"  # Current date
    export GITHUB_ACCOUNT="${GITHUB_ACCOUNT:-}"  # GitHub account name

    # Team collaboration variables - for Makefile docker-push-team target
    export TEAM_NAME="${TEAM_NAME:-}"  # Team name for Docker Hub organization
    export PROJECT_NAME="${PROJECT_NAME:-}"  # Project name for Docker image
    export DOCKERHUB_ACCOUNT="${DOCKERHUB_ACCOUNT:-}"  # Docker Hub account name

    # Profile system variables - generated from bundles.yaml
    export R_PACKAGES_INSTALL_CMD="${R_PACKAGES_INSTALL_CMD:-# No R packages specified}"
    export SYSTEM_DEPS_INSTALL_CMD="${SYSTEM_DEPS_INSTALL_CMD:-# No system dependencies specified}"
    export LIBS_BUNDLE="${LIBS_BUNDLE:-minimal}"
    export PKGS_BUNDLE="${PKGS_BUNDLE:-minimal}"
    
    # Process the file: read it, substitute variables, write to temp file, then replace original
    # envsubst with explicit variable list - only substitutes specified template variables
    # This ensures we substitute template vars but preserve any other ${VAR} syntax
    # > "$file.tmp" - writes output to temporary file
    # && mv "$file.tmp" "$file" - if substitution succeeds, replace original with processed version
    if ! (envsubst '$PKG_NAME $AUTHOR_NAME $AUTHOR_EMAIL $AUTHOR_INSTITUTE $AUTHOR_INSTITUTE_FULL $BASE_IMAGE $R_VERSION $USERNAME $PACKAGE_NAME $AUTHOR_LAST $AUTHOR_ORCID $MANUSCRIPT_TITLE $DATE $GITHUB_ACCOUNT $TEAM_NAME $PROJECT_NAME $DOCKERHUB_ACCOUNT $R_PACKAGES_INSTALL_CMD $SYSTEM_DEPS_INSTALL_CMD $LIBS_BUNDLE $PKGS_BUNDLE' < "$file" > "$file.tmp" && mv "$file.tmp" "$file"); then
        log_error "Failed to substitute variables in file: $file"
        rm -f "$file.tmp"  # Clean up temporary file on failure
        return 1
    fi
}

#=============================================================================
# FILE CREATION UTILITIES (extracted from lines 336-384)
#=============================================================================

# Function: create_file_if_missing
# Purpose: Create a file with specified content only if it doesn't already exist
# Arguments:
#   $1 - file_path: where to create the file
#   $2 - content: what content to put in the file
#   $3 - description: optional description for logging (defaults to file_path)
# Behavior: Preserves existing files to avoid overwriting user modifications
create_file_if_missing() {
    local file_path="$1"
    local content="$2"
    local description="${3:-$file_path}"
    
    # Input validation
    [[ $# -ge 2 ]] || { log_error "create_file_if_missing: need file_path and content"; return 1; }
    
    # Skip if file already exists (preserve user work)
    if [[ -f "$file_path" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$file_path")
    if [[ "$parent_dir" != "." ]] && [[ ! -d "$parent_dir" ]]; then
        if ! mkdir -p "$parent_dir"; then
            log_error "Failed to create directory: $parent_dir"
            return 1
        fi
    fi
    
    # Create the file with the specified content
    # printf is safer than echo for handling content with special characters
    if ! printf '%s\n' "$content" > "$file_path"; then
        log_error "Failed to create file: $file_path"
        return 1
    fi
    
    log_info "Created $description"
}

# Function: install_template
# Purpose: Consolidated template installation with tracking and error handling
# Arguments: $1 - template file, $2 - destination, $3 - description, $4 - success message (optional)
# Returns: 0 on success, 1 on failure
install_template() {
    local template="$1"
    local dest="$2" 
    local description="$3"
    local success_msg="${4:-"Created $description"}"
    
    if copy_template_file "$template" "$dest" "$description"; then
        track_template_file "$template" "$dest"
        log_info "$success_msg"
        return 0
    else
        log_error "Failed to create $description"
        return 1
    fi
}

#=============================================================================
# TEMPLATES MODULE VALIDATION
#=============================================================================

# Set templates module loaded flag
readonly ZZCOLLAB_TEMPLATES_LOADED=true