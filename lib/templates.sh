#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB TEMPLATES LIBRARY
##############################################################################
#
# PURPOSE: Template processing engine and file creation utilities
#          - Template copying with variable substitution
#          - Safe file creation functions
#          - Variable substitution system
#
# DEPENDENCIES: lib/core.sh (for logging functions)
##############################################################################

# Validate core library is loaded
require_module "core"

#=============================================================================
# TEMPLATE FILE PROCESSING FUNCTIONS
#=============================================================================

# Function: copy_template_file
# Purpose: Copy a template file and substitute variables within it
# USAGE:    copy_template_file "Dockerfile" "Dockerfile" ["Docker config"] [templates_dir]
# ARGS:
#   $1 - template: Template filename (relative to templates directory)
#   $2 - dest: Destination path for the copied file
#   $3 - description: Optional description for logging (defaults to destination path)
#   $4 - templates_dir: Optional templates directory (defaults to ZZCOLLAB_TEMPLATES_DIR)
# RETURNS:
#   0 - File copied and variables substituted successfully
#   1 - Failed (template not found, copy failed, substitution failed)
copy_template_file() {
    local template="$1"
    local dest="$2"
    local description="${3:-$dest}"
    local templates_dir="${4:-${TEMPLATES_DIR:-$ZZCOLLAB_TEMPLATES_DIR}}"

    [[ $# -ge 2 ]] || { log_error "copy_template_file: need template and destination"; return 1; }

    if [[ -z "$templates_dir" ]]; then
        log_error "copy_template_file: templates directory not specified"
        return 1
    fi

    if [[ ! -f "$templates_dir/$template" ]]; then
        log_error "Template not found: $templates_dir/$template"
        return 1
    fi

    if [[ -f "$dest" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi

    local dest_dir
    dest_dir=$(dirname "$dest")
    if [[ "$dest_dir" != "." ]] && [[ ! -d "$dest_dir" ]]; then
        if ! mkdir -p "$dest_dir"; then
            log_error "Failed to create directory: $dest_dir"
            return 1
        fi
    fi

    if ! cp "$templates_dir/$template" "$dest"; then
        log_error "Failed to copy template: $template"
        return 1
    fi

    if ! substitute_variables "$dest"; then
        log_error "Failed to substitute variables in: $dest"
        return 1
    fi

    return 0
}

# Function: regenerate_template_file
# Purpose: Copy a template file and substitute variables, overwriting if exists
# USAGE:    regenerate_template_file "Makefile" "Makefile" ["Makefile"] [templates_dir]
# ARGS:
#   $1 - template: Template filename (relative to templates directory)
#   $2 - dest: Destination path for the copied file
#   $3 - description: Optional description for logging (defaults to destination path)
#   $4 - templates_dir: Optional templates directory (defaults to ZZCOLLAB_TEMPLATES_DIR)
# RETURNS:
#   0 - File regenerated and variables substituted successfully
#   1 - Failed (template not found, copy failed, substitution failed)
regenerate_template_file() {
    local template="$1"
    local dest="$2"
    local description="${3:-$dest}"
    local templates_dir="${4:-${TEMPLATES_DIR:-$ZZCOLLAB_TEMPLATES_DIR}}"

    [[ $# -ge 2 ]] || { log_error "regenerate_template_file: need template and destination"; return 1; }

    if [[ -z "$templates_dir" ]]; then
        log_error "regenerate_template_file: templates directory not specified"
        return 1
    fi

    if [[ ! -f "$templates_dir/$template" ]]; then
        log_error "Template not found: $templates_dir/$template"
        return 1
    fi

    if ! cp "$templates_dir/$template" "$dest"; then
        log_error "Failed to copy template: $template"
        return 1
    fi

    if ! substitute_variables "$dest"; then
        log_error "Failed to substitute variables in: $dest"
        return 1
    fi

    log_success "Regenerated $description"
    return 0
}

# Function: substitute_variables
# Purpose: Replace template placeholders (${VAR_NAME}) with actual variable values
# USAGE:    substitute_variables "path/to/file" [pkg_name] [author_name]
substitute_variables() {
    local file="$1"
    local pkg_name_override="${2:-}"
    local author_name_override="${3:-}"

    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }

    if [[ -n "$pkg_name_override" ]]; then
        PKG_NAME="$pkg_name_override" 2>/dev/null || true
    fi
    export PKG_NAME
    if [[ -n "$author_name_override" ]]; then
        AUTHOR_NAME="$author_name_override" 2>/dev/null || true
    fi
    export AUTHOR_NAME
    export AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE
    # Don't default R_VERSION to 'latest' - let generate_dockerfile read from renv.lock
    [[ -n "${R_VERSION:-}" ]] && export R_VERSION
    export USERNAME="${USERNAME:-analyst}"

    export PACKAGE_NAME="$PKG_NAME"
    export AUTHOR_LAST="${AUTHOR_LAST:-}"
    export AUTHOR_ORCID="${AUTHOR_ORCID:-}"
    export MANUSCRIPT_TITLE="${MANUSCRIPT_TITLE:-Research Compendium Analysis}"
    export DATE="$(date +%Y-%m-%d)"
    export GITHUB_ACCOUNT="${GITHUB_ACCOUNT:-}"

    export TEAM_NAME="${TEAM_NAME:-}"
    export PROJECT_NAME="${PROJECT_NAME:-}"
    export DOCKERHUB_ACCOUNT="${DOCKERHUB_ACCOUNT:-}"

    export R_PACKAGES_INSTALL_CMD="${R_PACKAGES_INSTALL_CMD:-# No R packages specified}"
    export SYSTEM_DEPS_INSTALL_CMD="${SYSTEM_DEPS_INSTALL_CMD:-# No system dependencies specified}"
    export LIBS_BUNDLE="${LIBS_BUNDLE:-minimal}"
    export PKGS_BUNDLE="${PKGS_BUNDLE:-minimal}"
    if [[ -z "${ZZCOLLAB_TEMPLATE_VERSION:-}" ]]; then
        ZZCOLLAB_TEMPLATE_VERSION="0.0.0"
    fi
    export ZZCOLLAB_TEMPLATE_VERSION

    # Note: $USERNAME and $BASE_IMAGE are intentionally excluded - they are runtime
    # shell variables in Makefile ($$USERNAME, $$BASE_IMAGE), not template placeholders
    if ! (envsubst '$PKG_NAME $AUTHOR_NAME $AUTHOR_EMAIL $AUTHOR_INSTITUTE $AUTHOR_INSTITUTE_FULL $R_VERSION $PACKAGE_NAME $AUTHOR_LAST $AUTHOR_ORCID $MANUSCRIPT_TITLE $DATE $GITHUB_ACCOUNT $TEAM_NAME $PROJECT_NAME $DOCKERHUB_ACCOUNT $R_PACKAGES_INSTALL_CMD $SYSTEM_DEPS_INSTALL_CMD $LIBS_BUNDLE $PKGS_BUNDLE $ZZCOLLAB_TEMPLATE_VERSION' < "$file" > "$file.tmp" && mv "$file.tmp" "$file"); then
        log_error "Failed to substitute variables in file: $file"
        rm -f "$file.tmp"
        return 1
    fi
}

#=============================================================================
# FILE CREATION UTILITIES
#=============================================================================

# Function: create_file_if_missing
# Purpose: Create a file with specified content only if it doesn't already exist
create_file_if_missing() {
    local file_path="$1"
    local content="$2"
    local description="${3:-$file_path}"

    [[ $# -ge 2 ]] || { log_error "create_file_if_missing: need file_path and content"; return 1; }

    if [[ -f "$file_path" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi

    local parent_dir
    parent_dir=$(dirname "$file_path")
    if [[ "$parent_dir" != "." ]] && [[ ! -d "$parent_dir" ]]; then
        if ! mkdir -p "$parent_dir"; then
            log_error "Failed to create directory: $parent_dir"
            return 1
        fi
    fi

    if ! printf '%s\n' "$content" > "$file_path"; then
        log_error "Failed to create file: $file_path"
        return 1
    fi

    track_file "$file_path"
    log_info "Created $description"
}

# Function: install_template
# Purpose: Consolidated template installation with tracking and error handling
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
# TEMPLATES LIBRARY VALIDATION
#=============================================================================

# Set templates module loaded flag
readonly ZZCOLLAB_TEMPLATES_LOADED=true
