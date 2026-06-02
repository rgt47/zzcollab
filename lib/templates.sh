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

#=============================================================================
# TEMPLATE FILE PROCESSING FUNCTIONS
#=============================================================================

# Function: _render_template (private)
# Purpose: Copy a template into place and substitute its variables. Shared core
#          of copy_template_file (overwrite=false) and regenerate_template_file
#          (overwrite=true).
# ARGS: $1 template  $2 dest  $3 description  $4 templates_dir  $5 overwrite
# RETURNS: 0 on success (or skip), 1 on failure.
_render_template() {
    local template="$1" dest="$2" description="$3" templates_dir="$4" overwrite="$5"

    if [[ -z "$templates_dir" ]]; then
        log_error "render_template: templates directory not specified"
        return 1
    fi
    if [[ ! -f "$templates_dir/$template" ]]; then
        log_error "Template not found: $templates_dir/$template"
        return 1
    fi
    if [[ "$overwrite" != "true" && -f "$dest" ]]; then
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
    if ! safe_cp "$templates_dir/$template" "$dest"; then
        log_error "Failed to copy template: $template"
        return 1
    fi
    if ! substitute_variables "$dest"; then
        log_error "Failed to substitute variables in: $dest"
        return 1
    fi
    return 0
}

# Copy a template and substitute variables, skipping if the destination exists.
# USAGE: copy_template_file TEMPLATE DEST [DESCRIPTION] [TEMPLATES_DIR]
copy_template_file() {
    [[ $# -ge 2 ]] || { log_error "copy_template_file: need template and destination"; return 1; }
    _render_template "$1" "$2" "${3:-$2}" \
        "${4:-${TEMPLATES_DIR:-$ZZCOLLAB_TEMPLATES_DIR}}" "false"
}

# Copy a template and substitute variables, overwriting the destination.
# USAGE: regenerate_template_file TEMPLATE DEST [DESCRIPTION] [TEMPLATES_DIR]
regenerate_template_file() {
    [[ $# -ge 2 ]] || { log_error "regenerate_template_file: need template and destination"; return 1; }
    local description="${3:-$2}"
    _render_template "$1" "$2" "$description" \
        "${4:-${TEMPLATES_DIR:-$ZZCOLLAB_TEMPLATES_DIR}}" "true" \
        && log_success "Regenerated $description"
}

# Function: render_authors_r
# Purpose: Build a DESCRIPTION Authors@R person() call from the resolved
#          config. Splits AUTHOR_NAME into given/family (last token = family),
#          parses the comma-separated roles (default aut,cre), and appends an
#          ORCID comment only when CONFIG_AUTHOR_ORCID is set.
# OUTPUT:  A single-line person(...) expression on stdout.
render_authors_r() {
    local name="${CONFIG_AUTHOR_NAME:-${AUTHOR_NAME:-Your Name}}"
    local email="${CONFIG_AUTHOR_EMAIL:-${AUTHOR_EMAIL:-your.email@example.com}}"
    local orcid="${CONFIG_AUTHOR_ORCID:-${AUTHOR_ORCID:-}}"
    local roles="${CONFIG_AUTHOR_ROLES:-aut,cre}"

    local given family
    if [[ "$name" == *" "* ]]; then
        family="${name##* }"
        given="${name% *}"
    else
        given="$name"
        family=""
    fi

    # Build the role vector, e.g. "aut", "cre"
    local role_vec="" r
    local oldifs="$IFS"
    IFS=','
    for r in $roles; do
        r="${r//[[:space:]]/}"
        [[ -z "$r" ]] && continue
        role_vec+="\"$r\", "
    done
    IFS="$oldifs"
    role_vec="${role_vec%, }"
    [[ -z "$role_vec" ]] && role_vec="\"aut\", \"cre\""

    local out="person(given = \"$given\""
    [[ -n "$family" ]] && out+=", family = \"$family\""
    out+=", email = \"$email\", role = c($role_vec)"
    [[ -n "$orcid" ]] && out+=", comment = c(ORCID = \"$orcid\")"
    out+=")"
    printf '%s' "$out"
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
    export PKG_NAME="${PKG_NAME:-$(basename "$(pwd)" | tr '-' '.' | tr '[:upper:]' '[:lower:]')}"
    if [[ -n "$author_name_override" ]]; then
        AUTHOR_NAME="$author_name_override" 2>/dev/null || true
    fi
    # Resolved config (CONFIG_*, populated by load_config) wins over the
    # core.sh placeholder defaults so scaffolded metadata reflects the user.
    AUTHOR_NAME="${CONFIG_AUTHOR_NAME:-${AUTHOR_NAME:-Your Name}}"
    AUTHOR_EMAIL="${CONFIG_AUTHOR_EMAIL:-${AUTHOR_EMAIL:-your.email@example.com}}"
    export AUTHOR_NAME 2>/dev/null || true
    export AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE
    # Don't default R_VERSION to 'latest' - let generate_dockerfile read from renv.lock
    [[ -n "${R_VERSION:-}" ]] && export R_VERSION

    export PACKAGE_NAME="${PKG_NAME:-$(basename "$(pwd)" | tr '-' '.' | tr '[:upper:]' '[:lower:]')}"

    # DESCRIPTION metadata sourced from the resolved config (with R-package
    # defaults). AUTHORS_R is pre-rendered because envsubst cannot express the
    # conditional ORCID/role structure of the person() call.
    export LICENSE_TYPE="${CONFIG_LICENSE_TYPE:-GPL-3}"
    export ROXYGEN_VERSION="${CONFIG_RPACKAGE_ROXYGEN_VERSION:-7.3.2}"
    export PKG_ENCODING="${CONFIG_RPACKAGE_ENCODING:-UTF-8}"
    AUTHORS_R="$(render_authors_r)"
    export AUTHORS_R

    # Split AUTHOR_NAME into given/family for CFF and other structured formats.
    # Convention: last whitespace-delimited token is the family name.
    # "Ronald G. Thomas" -> given="Ronald G.", family="Thomas"
    local _cff_name="${AUTHOR_NAME:-Your Name}"
    if [[ "$_cff_name" == *' '* ]]; then
        export AUTHOR_FAMILY_NAME="${_cff_name##* }"
        export AUTHOR_GIVEN_NAME="${_cff_name% *}"
    else
        export AUTHOR_GIVEN_NAME="$_cff_name"
        export AUTHOR_FAMILY_NAME=""
    fi

    export DATE="$(date +%Y-%m-%d)"
    export GITHUB_ACCOUNT="${GITHUB_ACCOUNT:-}"
    export PROJECT_NAME="${PROJECT_NAME:-}"
    if [[ -z "${ZZCOLLAB_TEMPLATE_VERSION:-}" ]]; then
        ZZCOLLAB_TEMPLATE_VERSION="0.0.0"
    fi
    export ZZCOLLAB_TEMPLATE_VERSION

    # PPM snapshot date and Ubuntu codename for pinned repository URLs.
    # get_ubuntu_codename is defined in modules/docker.sh; we guard in case
    # templates.sh is ever sourced without docker.sh.
    export PPM_SNAPSHOT="${PPM_SNAPSHOT:-$(date +%Y-%m-%d)}"
    if declare -f get_ubuntu_codename > /dev/null 2>&1; then
        export UBUNTU_CODENAME="${UBUNTU_CODENAME:-$(get_ubuntu_codename "${R_VERSION:-4.4.0}")}"
    else
        export UBUNTU_CODENAME="${UBUNTU_CODENAME:-noble}"
    fi

    # Note: $BASE_IMAGE is intentionally excluded - it is a runtime shell
    # variable in Makefile ($$BASE_IMAGE), not a template placeholder.
    if ! (envsubst '$PKG_NAME $AUTHOR_NAME $AUTHOR_GIVEN_NAME $AUTHOR_FAMILY_NAME $AUTHOR_EMAIL $AUTHOR_INSTITUTE $AUTHOR_INSTITUTE_FULL $R_VERSION $PACKAGE_NAME $AUTHORS_R $LICENSE_TYPE $ROXYGEN_VERSION $PKG_ENCODING $DATE $GITHUB_ACCOUNT $PROJECT_NAME $ZZCOLLAB_TEMPLATE_VERSION $UBUNTU_CODENAME $PPM_SNAPSHOT' < "$file" > "$file.tmp" && mv "$file.tmp" "$file"); then
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

    log_info "Created $description"
}

# Function: install_template
# Purpose: Consolidated template installation with error handling
install_template() {
    local template="$1"
    local dest="$2"
    local description="$3"
    local success_msg="${4:-"Created $description"}"

    if copy_template_file "$template" "$dest" "$description"; then
        log_info "$success_msg"
        return 0
    else
        log_error "Failed to create $description"
        return 1
    fi
}
