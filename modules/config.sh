#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CONFIGURATION MODULE
##############################################################################
#
# Manages YAML configuration files with priority: project > user > defaults
# Requires: yq (YAML processor)
#
# Files:
#   ./zzcollab.yaml          - Project-specific config
#   ~/.zzcollab/config.yaml  - User global config
#
##############################################################################

require_module "core"

#=============================================================================
# CONFIGURATION PATHS AND STATE
#=============================================================================

readonly CONFIG_PROJECT="${ZZCOLLAB_CONFIG_PROJECT:-./zzcollab.yaml}"
readonly CONFIG_USER_DIR="${ZZCOLLAB_CONFIG_USER_DIR:-$HOME/.zzcollab}"
readonly CONFIG_USER="${ZZCOLLAB_CONFIG_USER:-$CONFIG_USER_DIR/config.yaml}"

# Interactive mode state
INTERACTIVE_CANCELLED=false

# Original configuration state (backward compatibility)
CONFIG_TEAM_NAME=""
CONFIG_GITHUB_ACCOUNT=""
CONFIG_DOCKERHUB_ACCOUNT=""
CONFIG_PROFILE_NAME=""
CONFIG_LIBS_BUNDLE=""
CONFIG_PKGS_BUNDLE=""
CONFIG_R_VERSION=""
CONFIG_AUTO_GITHUB="false"
CONFIG_SKIP_CONFIRMATION="false"
CONFIG_WITH_EXAMPLES="false"

# Extended configuration state - Author
CONFIG_AUTHOR_NAME=""
CONFIG_AUTHOR_EMAIL=""
CONFIG_AUTHOR_ORCID=""
CONFIG_AUTHOR_AFFILIATION=""
CONFIG_AUTHOR_AFFILIATION_FULL=""
CONFIG_AUTHOR_ROLES=""

# Extended configuration state - License
CONFIG_LICENSE_TYPE=""
CONFIG_LICENSE_YEAR=""
CONFIG_LICENSE_HOLDER=""
CONFIG_LICENSE_INCLUDE_FILE="true"

# Extended configuration state - R Package
CONFIG_RPACKAGE_MIN_R_VERSION=""
CONFIG_RPACKAGE_ROXYGEN_VERSION=""
CONFIG_RPACKAGE_TESTTHAT_EDITION=""
CONFIG_RPACKAGE_ENCODING=""
CONFIG_RPACKAGE_LANGUAGE=""
CONFIG_RPACKAGE_VIGNETTE_BUILDER=""

# Extended configuration state - Code Style
CONFIG_STYLE_LINE_LENGTH=""
CONFIG_STYLE_INDENT_SIZE=""
CONFIG_STYLE_USE_NATIVE_PIPE=""
CONFIG_STYLE_ASSIGNMENT=""
CONFIG_STYLE_NAMING_CONVENTION=""

# Extended configuration state - Docker
CONFIG_DOCKER_DEFAULT_PROFILE=""
CONFIG_DOCKER_DEFAULT_BASE_IMAGE=""
CONFIG_DOCKER_REGISTRY=""
CONFIG_DOCKER_PLATFORM=""

# Extended configuration state - GitHub
CONFIG_GITHUB_DEFAULT_VISIBILITY=""
CONFIG_GITHUB_DEFAULT_BRANCH=""
CONFIG_GITHUB_CREATE_ISSUES=""
CONFIG_GITHUB_CREATE_WIKI=""

# Extended configuration state - CI/CD
CONFIG_CICD_ENABLE_GITHUB_ACTIONS=""
CONFIG_CICD_R_VERSIONS=""
CONFIG_CICD_OS_MATRIX=""
CONFIG_CICD_RUN_COVERAGE=""
CONFIG_CICD_COVERAGE_THRESHOLD=""

# Extended configuration state - Documentation
CONFIG_DOCS_USE_PKGDOWN=""
CONFIG_DOCS_USE_README=""
CONFIG_DOCS_USE_NEWS=""
CONFIG_DOCS_CITATION_STYLE=""

#=============================================================================
# YAML OPERATIONS
#=============================================================================

_require_yq() {
    command -v yq >/dev/null 2>&1 || {
        log_error "yq required but not found"
        log_info "Install: brew install yq (macOS) or snap install yq (Ubuntu)"
        return 1
    }
}

yaml_get() {
    local file="$1" path="$2"
    [[ -f "$file" ]] || return 1
    _require_yq || return 1
    yq eval ".$path // \"\"" "$file" 2>/dev/null
}

yaml_set() {
    local file="$1" path="$2" value="$3"
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    _require_yq || return 1
    yq eval ".$path = \"$value\"" "$file" -i
}

yaml_set_bool() {
    local file="$1" path="$2" value="$3"
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    _require_yq || return 1
    yq eval ".$path = $value" "$file" -i
}

yaml_set_array() {
    local file="$1" path="$2" value="$3"
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    _require_yq || return 1
    yq eval ".$path = [$value]" "$file" -i
}

#=============================================================================
# INPUT VALIDATION HELPERS
#=============================================================================

# Validate email format
validate_email() {
    local email="$1"
    [[ -z "$email" ]] && return 0  # Empty is OK (optional)
    [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Validate ORCID format (0000-0000-0000-0000)
validate_orcid() {
    local orcid="$1"
    [[ -z "$orcid" ]] && return 0  # Empty is OK (optional)
    [[ "$orcid" =~ ^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$ ]]
}

# Validate R version format (X.Y.Z)
validate_r_version() {
    local version="$1"
    [[ -z "$version" ]] && return 0  # Empty is OK
    [[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
}

# Validate positive integer
validate_positive_int() {
    local num="$1"
    [[ -z "$num" ]] && return 0  # Empty is OK
    [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -gt 0 ]]
}

# Validate percentage (0-100)
validate_percentage() {
    local num="$1"
    [[ -z "$num" ]] && return 0  # Empty is OK
    [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 0 ]] && [[ "$num" -le 100 ]]
}

# Validate GitHub account exists (requires gh CLI)
validate_github_account() {
    local account="$1"
    [[ -z "$account" ]] && return 0  # Empty is OK (optional)
    if command -v gh &>/dev/null; then
        gh api "users/$account" &>/dev/null
        return $?
    fi
    return 0  # Skip validation if gh not available
}

#=============================================================================
# INTERACTIVE INPUT HELPERS
#=============================================================================

# Trap handler for clean exit
_interactive_cleanup() {
    INTERACTIVE_CANCELLED=true
    echo ""
    echo ""
    log_warn "Configuration cancelled by user"
    echo "Partial configuration may have been saved."
    echo "Run 'zzcollab -c init --interactive' to continue setup."
    return 0
}

# Prompt for input with default value and exit handling
# Usage: prompt_input "Prompt text" "default_value" result_var
prompt_input() {
    local prompt="$1"
    local default="$2"
    local -n result_ref="$3"
    local input

    if [[ -n "$default" ]]; then
        printf "%s [%s]: " "$prompt" "$default"
    else
        printf "%s: " "$prompt"
    fi

    read -r input || {
        INTERACTIVE_CANCELLED=true
        return 1
    }

    if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
        INTERACTIVE_CANCELLED=true
        return 1
    fi

    result_ref="${input:-$default}"
    return 0
}

# Prompt for validated input with retry
# Usage: prompt_validated "Prompt" "default" result_var validator_func "error_message"
prompt_validated() {
    local prompt="$1"
    local default="$2"
    local -n result_ref="$3"
    local validator="$4"
    local error_msg="${5:-Invalid input}"
    local input

    while true; do
        if [[ -n "$default" ]]; then
            printf "%s [%s]: " "$prompt" "$default"
        else
            printf "%s: " "$prompt"
        fi

        read -r input || {
            INTERACTIVE_CANCELLED=true
            return 1
        }

        if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
            INTERACTIVE_CANCELLED=true
            return 1
        fi

        input="${input:-$default}"

        # Run validator function
        if $validator "$input"; then
            result_ref="$input"
            return 0
        else
            echo "  $error_msg"
        fi
    done
}

# Prompt for GitHub account with existence check
prompt_github_account() {
    local prompt="$1"
    local default="$2"
    local -n result_ref="$3"
    local input

    while true; do
        if [[ -n "$default" ]]; then
            printf "%s [%s]: " "$prompt" "$default"
        else
            printf "%s: " "$prompt"
        fi

        read -r input || {
            INTERACTIVE_CANCELLED=true
            return 1
        }

        if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
            INTERACTIVE_CANCELLED=true
            return 1
        fi

        input="${input:-$default}"

        # Empty is OK
        if [[ -z "$input" ]]; then
            result_ref=""
            return 0
        fi

        # Check if account exists
        if command -v gh &>/dev/null; then
            printf "  Checking GitHub account..."
            if gh api "users/$input" &>/dev/null; then
                echo " OK"
                result_ref="$input"
                return 0
            else
                echo " not found"
                echo "  Account '$input' not found on GitHub. Please check the username."
            fi
        else
            # gh not available, accept without validation
            result_ref="$input"
            return 0
        fi
    done
}

# Prompt for yes/no with default
# Usage: prompt_yesno "Question" "y" result_var
prompt_yesno() {
    local prompt="$1"
    local default="$2"
    local -n result_ref="$3"
    local input
    local hint="y/n"

    [[ "$default" == "y" ]] && hint="Y/n"
    [[ "$default" == "n" ]] && hint="y/N"

    printf "%s (%s): " "$prompt" "$hint"

    read -r input || {
        INTERACTIVE_CANCELLED=true
        return 1
    }

    if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
        INTERACTIVE_CANCELLED=true
        return 1
    fi

    input="${input:-$default}"
    [[ "$input" =~ ^[Yy] ]] && result_ref="true" || result_ref="false"
    return 0
}

# Prompt for selection from list
# Usage: prompt_select "Prompt" "opt1,opt2,opt3" "default" result_var
prompt_select() {
    local prompt="$1"
    local options="$2"
    local default="$3"
    local -n result_ref="$4"
    local input

    while true; do
        printf "%s (%s) [%s]: " "$prompt" "$options" "$default"

        read -r input || {
            INTERACTIVE_CANCELLED=true
            return 1
        }

        if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
            INTERACTIVE_CANCELLED=true
            return 1
        fi

        input="${input:-$default}"

        # Validate input is one of the options
        if [[ ",$options," == *",$input,"* ]]; then
            result_ref="$input"
            return 0
        else
            echo "  Invalid choice. Please select from: $options"
        fi
    done
}

# Print section header
print_section() {
    local title="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

#=============================================================================
# CONFIGURATION LOADING
#=============================================================================

load_config() {
    # Reset to defaults - original fields
    CONFIG_TEAM_NAME=""
    CONFIG_GITHUB_ACCOUNT=""
    CONFIG_DOCKERHUB_ACCOUNT=""
    CONFIG_PROFILE_NAME=""
    CONFIG_LIBS_BUNDLE=""
    CONFIG_PKGS_BUNDLE=""
    CONFIG_R_VERSION=""
    CONFIG_AUTO_GITHUB="false"
    CONFIG_SKIP_CONFIRMATION="false"
    CONFIG_WITH_EXAMPLES="false"

    # Reset extended fields
    CONFIG_AUTHOR_NAME=""
    CONFIG_AUTHOR_EMAIL=""
    CONFIG_AUTHOR_ORCID=""
    CONFIG_AUTHOR_AFFILIATION=""
    CONFIG_AUTHOR_AFFILIATION_FULL=""
    CONFIG_AUTHOR_ROLES=""
    CONFIG_LICENSE_TYPE=""
    CONFIG_LICENSE_YEAR=""
    CONFIG_LICENSE_HOLDER=""
    CONFIG_LICENSE_INCLUDE_FILE="true"
    CONFIG_RPACKAGE_MIN_R_VERSION=""
    CONFIG_RPACKAGE_ROXYGEN_VERSION=""
    CONFIG_RPACKAGE_TESTTHAT_EDITION=""
    CONFIG_RPACKAGE_ENCODING=""
    CONFIG_RPACKAGE_LANGUAGE=""
    CONFIG_RPACKAGE_VIGNETTE_BUILDER=""
    CONFIG_STYLE_LINE_LENGTH=""
    CONFIG_STYLE_INDENT_SIZE=""
    CONFIG_STYLE_USE_NATIVE_PIPE=""
    CONFIG_STYLE_ASSIGNMENT=""
    CONFIG_STYLE_NAMING_CONVENTION=""
    CONFIG_DOCKER_DEFAULT_PROFILE=""
    CONFIG_DOCKER_DEFAULT_BASE_IMAGE=""
    CONFIG_DOCKER_REGISTRY=""
    CONFIG_DOCKER_PLATFORM=""
    CONFIG_GITHUB_DEFAULT_VISIBILITY=""
    CONFIG_GITHUB_DEFAULT_BRANCH=""
    CONFIG_GITHUB_CREATE_ISSUES=""
    CONFIG_GITHUB_CREATE_WIKI=""
    CONFIG_CICD_ENABLE_GITHUB_ACTIONS=""
    CONFIG_CICD_R_VERSIONS=""
    CONFIG_CICD_OS_MATRIX=""
    CONFIG_CICD_RUN_COVERAGE=""
    CONFIG_CICD_COVERAGE_THRESHOLD=""
    CONFIG_DOCS_USE_PKGDOWN=""
    CONFIG_DOCS_USE_README=""
    CONFIG_DOCS_USE_NEWS=""
    CONFIG_DOCS_CITATION_STYLE=""

    # Load in reverse priority (later overrides earlier)
    _load_file "$CONFIG_USER"
    _load_file "$CONFIG_PROJECT"
}

_load_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local val

    # Original defaults section
    val=$(yaml_get "$file" "defaults.team_name") && [[ -n "$val" ]] && CONFIG_TEAM_NAME="$val"
    val=$(yaml_get "$file" "defaults.github_account") && [[ -n "$val" ]] && CONFIG_GITHUB_ACCOUNT="$val"
    val=$(yaml_get "$file" "defaults.dockerhub_account") && [[ -n "$val" ]] && CONFIG_DOCKERHUB_ACCOUNT="$val"
    val=$(yaml_get "$file" "defaults.profile_name") && [[ -n "$val" ]] && CONFIG_PROFILE_NAME="$val"
    val=$(yaml_get "$file" "defaults.libs_bundle") && [[ -n "$val" ]] && CONFIG_LIBS_BUNDLE="$val"
    val=$(yaml_get "$file" "defaults.pkgs_bundle") && [[ -n "$val" ]] && CONFIG_PKGS_BUNDLE="$val"
    val=$(yaml_get "$file" "defaults.r_version") && [[ -n "$val" ]] && CONFIG_R_VERSION="$val"
    val=$(yaml_get "$file" "defaults.auto_github") && [[ -n "$val" ]] && CONFIG_AUTO_GITHUB="$val"
    val=$(yaml_get "$file" "defaults.skip_confirmation") && [[ -n "$val" ]] && CONFIG_SKIP_CONFIRMATION="$val"
    val=$(yaml_get "$file" "defaults.with_examples") && [[ -n "$val" ]] && CONFIG_WITH_EXAMPLES="$val"

    # Author section
    val=$(yaml_get "$file" "author.name") && [[ -n "$val" ]] && CONFIG_AUTHOR_NAME="$val"
    val=$(yaml_get "$file" "author.email") && [[ -n "$val" ]] && CONFIG_AUTHOR_EMAIL="$val"
    val=$(yaml_get "$file" "author.orcid") && [[ -n "$val" ]] && CONFIG_AUTHOR_ORCID="$val"
    val=$(yaml_get "$file" "author.affiliation") && [[ -n "$val" ]] && CONFIG_AUTHOR_AFFILIATION="$val"
    val=$(yaml_get "$file" "author.affiliation_full") && [[ -n "$val" ]] && CONFIG_AUTHOR_AFFILIATION_FULL="$val"
    val=$(yaml_get "$file" "author.roles") && [[ -n "$val" ]] && CONFIG_AUTHOR_ROLES="$val"

    # License section
    val=$(yaml_get "$file" "license.type") && [[ -n "$val" ]] && CONFIG_LICENSE_TYPE="$val"
    val=$(yaml_get "$file" "license.year") && [[ -n "$val" ]] && CONFIG_LICENSE_YEAR="$val"
    val=$(yaml_get "$file" "license.holder") && [[ -n "$val" ]] && CONFIG_LICENSE_HOLDER="$val"
    val=$(yaml_get "$file" "license.include_file") && [[ -n "$val" ]] && CONFIG_LICENSE_INCLUDE_FILE="$val"

    # R Package section
    val=$(yaml_get "$file" "r_package.min_r_version") && [[ -n "$val" ]] && CONFIG_RPACKAGE_MIN_R_VERSION="$val"
    val=$(yaml_get "$file" "r_package.roxygen_version") && [[ -n "$val" ]] && CONFIG_RPACKAGE_ROXYGEN_VERSION="$val"
    val=$(yaml_get "$file" "r_package.testthat_edition") && [[ -n "$val" ]] && CONFIG_RPACKAGE_TESTTHAT_EDITION="$val"
    val=$(yaml_get "$file" "r_package.encoding") && [[ -n "$val" ]] && CONFIG_RPACKAGE_ENCODING="$val"
    val=$(yaml_get "$file" "r_package.language") && [[ -n "$val" ]] && CONFIG_RPACKAGE_LANGUAGE="$val"
    val=$(yaml_get "$file" "r_package.vignette_builder") && [[ -n "$val" ]] && CONFIG_RPACKAGE_VIGNETTE_BUILDER="$val"

    # Style section
    val=$(yaml_get "$file" "style.line_length") && [[ -n "$val" ]] && CONFIG_STYLE_LINE_LENGTH="$val"
    val=$(yaml_get "$file" "style.indent_size") && [[ -n "$val" ]] && CONFIG_STYLE_INDENT_SIZE="$val"
    val=$(yaml_get "$file" "style.use_native_pipe") && [[ -n "$val" ]] && CONFIG_STYLE_USE_NATIVE_PIPE="$val"
    val=$(yaml_get "$file" "style.assignment") && [[ -n "$val" ]] && CONFIG_STYLE_ASSIGNMENT="$val"
    val=$(yaml_get "$file" "style.naming_convention") && [[ -n "$val" ]] && CONFIG_STYLE_NAMING_CONVENTION="$val"

    # Docker section
    val=$(yaml_get "$file" "docker.default_profile") && [[ -n "$val" ]] && CONFIG_DOCKER_DEFAULT_PROFILE="$val"
    val=$(yaml_get "$file" "docker.default_base_image") && [[ -n "$val" ]] && CONFIG_DOCKER_DEFAULT_BASE_IMAGE="$val"
    val=$(yaml_get "$file" "docker.registry") && [[ -n "$val" ]] && CONFIG_DOCKER_REGISTRY="$val"
    val=$(yaml_get "$file" "docker.platform") && [[ -n "$val" ]] && CONFIG_DOCKER_PLATFORM="$val"

    # GitHub section
    val=$(yaml_get "$file" "github.default_visibility") && [[ -n "$val" ]] && CONFIG_GITHUB_DEFAULT_VISIBILITY="$val"
    val=$(yaml_get "$file" "github.default_branch") && [[ -n "$val" ]] && CONFIG_GITHUB_DEFAULT_BRANCH="$val"
    val=$(yaml_get "$file" "github.create_issues") && [[ -n "$val" ]] && CONFIG_GITHUB_CREATE_ISSUES="$val"
    val=$(yaml_get "$file" "github.create_wiki") && [[ -n "$val" ]] && CONFIG_GITHUB_CREATE_WIKI="$val"

    # CI/CD section
    val=$(yaml_get "$file" "cicd.enable_github_actions") && [[ -n "$val" ]] && CONFIG_CICD_ENABLE_GITHUB_ACTIONS="$val"
    val=$(yaml_get "$file" "cicd.r_versions") && [[ -n "$val" ]] && CONFIG_CICD_R_VERSIONS="$val"
    val=$(yaml_get "$file" "cicd.os_matrix") && [[ -n "$val" ]] && CONFIG_CICD_OS_MATRIX="$val"
    val=$(yaml_get "$file" "cicd.run_coverage") && [[ -n "$val" ]] && CONFIG_CICD_RUN_COVERAGE="$val"
    val=$(yaml_get "$file" "cicd.coverage_threshold") && [[ -n "$val" ]] && CONFIG_CICD_COVERAGE_THRESHOLD="$val"

    # Documentation section
    val=$(yaml_get "$file" "documentation.use_pkgdown") && [[ -n "$val" ]] && CONFIG_DOCS_USE_PKGDOWN="$val"
    val=$(yaml_get "$file" "documentation.use_readme") && [[ -n "$val" ]] && CONFIG_DOCS_USE_README="$val"
    val=$(yaml_get "$file" "documentation.use_news") && [[ -n "$val" ]] && CONFIG_DOCS_USE_NEWS="$val"
    val=$(yaml_get "$file" "documentation.citation_style") && [[ -n "$val" ]] && CONFIG_DOCS_CITATION_STYLE="$val"

    return 0
}

apply_config_defaults() {
    [[ -z "${TEAM_NAME:-}" && -n "$CONFIG_TEAM_NAME" ]] && TEAM_NAME="$CONFIG_TEAM_NAME"
    [[ -z "${GITHUB_ACCOUNT:-}" && -n "$CONFIG_GITHUB_ACCOUNT" ]] && GITHUB_ACCOUNT="$CONFIG_GITHUB_ACCOUNT"
    [[ -z "${DOCKERHUB_ACCOUNT:-}" && -n "$CONFIG_DOCKERHUB_ACCOUNT" ]] && DOCKERHUB_ACCOUNT="$CONFIG_DOCKERHUB_ACCOUNT"
    [[ -z "${PROFILE_NAME:-}" && -n "$CONFIG_PROFILE_NAME" ]] && PROFILE_NAME="$CONFIG_PROFILE_NAME"
    [[ -z "${LIBS_BUNDLE:-}" && -n "$CONFIG_LIBS_BUNDLE" ]] && LIBS_BUNDLE="$CONFIG_LIBS_BUNDLE"
    [[ -z "${PKGS_BUNDLE:-}" && -n "$CONFIG_PKGS_BUNDLE" ]] && PKGS_BUNDLE="$CONFIG_PKGS_BUNDLE"

    if [[ -z "${R_VERSION:-}" ]]; then
        R_VERSION="${CONFIG_R_VERSION:-4.5.1}"
        USER_PROVIDED_R_VERSION="false"
    fi

    [[ "$CONFIG_AUTO_GITHUB" == "true" ]] && CREATE_GITHUB_REPO=true
    [[ "$CONFIG_SKIP_CONFIRMATION" == "true" ]] && SKIP_CONFIRMATION=true
    [[ "${WITH_EXAMPLES:-false}" == "false" && "$CONFIG_WITH_EXAMPLES" == "true" ]] && WITH_EXAMPLES=true
    return 0
}

_get_config_value() {
    local key="$1"
    case "$key" in
        # Original fields
        team_name) echo "$CONFIG_TEAM_NAME" ;;
        github_account) echo "$CONFIG_GITHUB_ACCOUNT" ;;
        dockerhub_account) echo "$CONFIG_DOCKERHUB_ACCOUNT" ;;
        profile_name) echo "$CONFIG_PROFILE_NAME" ;;
        libs_bundle) echo "$CONFIG_LIBS_BUNDLE" ;;
        pkgs_bundle) echo "$CONFIG_PKGS_BUNDLE" ;;
        r_version) echo "$CONFIG_R_VERSION" ;;
        auto_github) echo "$CONFIG_AUTO_GITHUB" ;;
        skip_confirmation) echo "$CONFIG_SKIP_CONFIRMATION" ;;
        with_examples) echo "$CONFIG_WITH_EXAMPLES" ;;
        # Author fields
        author.name|author_name) echo "$CONFIG_AUTHOR_NAME" ;;
        author.email|author_email) echo "$CONFIG_AUTHOR_EMAIL" ;;
        author.orcid|author_orcid) echo "$CONFIG_AUTHOR_ORCID" ;;
        author.affiliation|author_affiliation) echo "$CONFIG_AUTHOR_AFFILIATION" ;;
        author.affiliation_full|author_affiliation_full) echo "$CONFIG_AUTHOR_AFFILIATION_FULL" ;;
        author.roles|author_roles) echo "$CONFIG_AUTHOR_ROLES" ;;
        # License fields
        license.type|license_type) echo "$CONFIG_LICENSE_TYPE" ;;
        license.year|license_year) echo "$CONFIG_LICENSE_YEAR" ;;
        license.holder|license_holder) echo "$CONFIG_LICENSE_HOLDER" ;;
        # R Package fields
        r_package.min_r_version) echo "$CONFIG_RPACKAGE_MIN_R_VERSION" ;;
        r_package.testthat_edition) echo "$CONFIG_RPACKAGE_TESTTHAT_EDITION" ;;
        # Docker fields
        docker.default_profile) echo "$CONFIG_DOCKER_DEFAULT_PROFILE" ;;
        docker.registry) echo "$CONFIG_DOCKER_REGISTRY" ;;
        # GitHub fields
        github.default_visibility) echo "$CONFIG_GITHUB_DEFAULT_VISIBILITY" ;;
        github.default_branch) echo "$CONFIG_GITHUB_DEFAULT_BRANCH" ;;
        *) echo "" ;;
    esac
}

#=============================================================================
# CONFIG COMMANDS
#=============================================================================

config_init() {
    local interactive="${1:-false}"

    mkdir -p "$CONFIG_USER_DIR"

    if [[ -f "$CONFIG_USER" ]]; then
        log_warn "Config exists: $CONFIG_USER"
        read -p "Overwrite? [y/N] " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] || {
            if [[ "$interactive" == "true" ]]; then
                log_info "Loading existing configuration for review..."
                load_config
            else
                return 0
            fi
        }
    fi

    _create_default_config

    if [[ "$interactive" == "true" ]]; then
        config_interactive_setup
    else
        log_success "Created: $CONFIG_USER"
        log_info "Run 'zzcollab -c init --interactive' for guided setup"
    fi
}

_create_default_config() {
    local current_year
    current_year=$(date +%Y)

    cat > "$CONFIG_USER" << EOF
# ZZCOLLAB Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
#
# This file stores your personal defaults for R package development.
# Values here are used unless overridden by CLI flags or project config.
#
# Run 'zzcollab -c init --interactive' for guided setup.

#=============================================================================
# AUTHOR INFORMATION
#=============================================================================
# Used in DESCRIPTION Authors@R field, reports, and git commits

author:
  name: ""
  email: ""
  orcid: ""                    # e.g., "0000-0002-1234-5678"
  affiliation: ""              # Short name, e.g., "Stanford"
  affiliation_full: ""         # Full name for papers
  roles: "aut, cre"            # aut=author, cre=maintainer, ctb=contributor

#=============================================================================
# LICENSE PREFERENCES
#=============================================================================
# Default license for new R packages

license:
  type: "GPL-3"                # GPL-3, MIT, Apache-2.0, CC-BY-4.0
  year: "${current_year}"
  holder: ""                   # Defaults to author.name if empty
  include_file: true           # Create LICENSE.md file

#=============================================================================
# R PACKAGE DEFAULTS
#=============================================================================
# Technical defaults for R package DESCRIPTION

r_package:
  min_r_version: "4.1.0"       # Minimum R version (for native pipe)
  roxygen_version: "7.3.0"
  testthat_edition: 3
  encoding: "UTF-8"
  language: "en-US"
  vignette_builder: "knitr"

#=============================================================================
# CODE STYLE PREFERENCES
#=============================================================================
# Enforced by lintr and styler

style:
  line_length: 78
  indent_size: 2
  use_native_pipe: true        # |> instead of %>%
  assignment: "arrow"          # <- instead of =
  naming_convention: "snake_case"

#=============================================================================
# DOCKER PREFERENCES
#=============================================================================

docker:
  default_profile: "analysis"
  default_base_image: "rocker/tidyverse"
  registry: "docker.io"        # docker.io, ghcr.io
  platform: "linux/amd64"

#=============================================================================
# GITHUB PREFERENCES
#=============================================================================

github:
  account: ""
  default_visibility: "private"
  default_branch: "main"
  create_issues: true
  create_wiki: false

#=============================================================================
# CI/CD PREFERENCES
#=============================================================================

cicd:
  enable_github_actions: true
  r_versions: "4.3, 4.4"
  os_matrix: "ubuntu-latest"
  run_coverage: true
  coverage_threshold: 80

#=============================================================================
# DOCUMENTATION PREFERENCES
#=============================================================================

documentation:
  use_pkgdown: false
  use_readme: true
  use_news: true
  citation_style: "apa"

#=============================================================================
# LEGACY DEFAULTS (backward compatibility)
#=============================================================================

defaults:
  team_name: ""
  github_account: ""
  dockerhub_account: ""
  profile_name: "ubuntu_standard_minimal"
  libs_bundle: "minimal"
  pkgs_bundle: "minimal"
  r_version: ""
  auto_github: false
  skip_confirmation: false
  with_examples: false
EOF

    log_success "Created: $CONFIG_USER"
}

#=============================================================================
# INTERACTIVE SETUP
#=============================================================================

config_interactive_setup() {
    INTERACTIVE_CANCELLED=false

    # Set up trap for Ctrl+C
    trap '_interactive_cleanup; return 0' INT

    clear
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                    ZZCOLLAB Configuration Setup                          ║"
    echo "╠══════════════════════════════════════════════════════════════════════════╣"
    echo "║  This wizard will configure your R package development environment.     ║"
    echo "║                                                                          ║"
    echo "║  Press Enter to accept defaults shown in [brackets].                     ║"
    echo "║  Type 'q' or press Ctrl+C at any time to exit and save progress.        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""

    local val
    local current_year
    current_year=$(date +%Y)

    # Load existing values for defaults
    load_config

    #-------------------------------------------------------------------------
    # SECTION 1: Author Information
    #-------------------------------------------------------------------------
    print_section "1/8  Author Information"
    echo "This information appears in DESCRIPTION, reports, and git commits."
    echo ""

    prompt_input "Full name" "${CONFIG_AUTHOR_NAME:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.name" "$val"

    prompt_validated "Email address" "${CONFIG_AUTHOR_EMAIL:-}" val validate_email \
        "Invalid email format. Example: user@example.com" || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.email" "$val"

    prompt_validated "ORCID (optional, e.g., 0000-0002-1234-5678)" "${CONFIG_AUTHOR_ORCID:-}" val validate_orcid \
        "Invalid ORCID format. Expected: 0000-0000-0000-0000" || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.orcid" "$val"

    prompt_input "Affiliation (short)" "${CONFIG_AUTHOR_AFFILIATION:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.affiliation" "$val"

    prompt_input "Affiliation (full, for papers)" "${CONFIG_AUTHOR_AFFILIATION_FULL:-$val}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.affiliation_full" "$val"

    #-------------------------------------------------------------------------
    # SECTION 2: License
    #-------------------------------------------------------------------------
    print_section "2/8  License Preferences"
    echo "Choose a default license for new R packages."
    echo ""
    echo "  GPL-3      - Copyleft, derivatives must be open source"
    echo "  MIT        - Permissive, minimal restrictions"
    echo "  Apache-2.0 - Permissive with patent protection"
    echo "  CC-BY-4.0  - For data and documentation"
    echo ""

    prompt_select "Default license" "GPL-3,MIT,Apache-2.0,CC-BY-4.0" "${CONFIG_LICENSE_TYPE:-GPL-3}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "license.type" "$val"

    prompt_input "Copyright year" "${CONFIG_LICENSE_YEAR:-$current_year}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "license.year" "$val"

    #-------------------------------------------------------------------------
    # SECTION 3: R Package Defaults
    #-------------------------------------------------------------------------
    print_section "3/8  R Package Defaults"
    echo "Technical defaults for the DESCRIPTION file."
    echo ""

    prompt_validated "Minimum R version required" "${CONFIG_RPACKAGE_MIN_R_VERSION:-4.1.0}" val validate_r_version \
        "Invalid R version format. Expected: X.Y or X.Y.Z (e.g., 4.1 or 4.1.0)" || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "r_package.min_r_version" "$val"

    prompt_select "testthat edition" "2,3" "${CONFIG_RPACKAGE_TESTTHAT_EDITION:-3}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "r_package.testthat_edition" "$val"

    prompt_select "Vignette builder" "knitr,quarto" "${CONFIG_RPACKAGE_VIGNETTE_BUILDER:-knitr}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "r_package.vignette_builder" "$val"

    #-------------------------------------------------------------------------
    # SECTION 4: Code Style
    #-------------------------------------------------------------------------
    print_section "4/8  Code Style Preferences"
    echo "These preferences guide code generation and linting."
    echo ""

    prompt_validated "Line length for wrapping" "${CONFIG_STYLE_LINE_LENGTH:-78}" val validate_positive_int \
        "Invalid value. Must be a positive integer (e.g., 78, 80, 120)" || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "style.line_length" "$val"

    prompt_yesno "Use native pipe |> (requires R >= 4.1)" "${CONFIG_STYLE_USE_NATIVE_PIPE:-true}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "style.use_native_pipe" "$val"

    prompt_select "Assignment operator" "arrow,equals" "${CONFIG_STYLE_ASSIGNMENT:-arrow}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "style.assignment" "$val"

    #-------------------------------------------------------------------------
    # SECTION 5: Docker
    #-------------------------------------------------------------------------
    print_section "5/8  Docker Preferences"
    echo "Default Docker configuration for reproducible environments."
    echo ""
    echo "Available profiles:"
    echo "  minimal      - Essential R development (~650MB)"
    echo "  rstudio      - RStudio Server IDE (~980MB)"
    echo "  analysis     - Data analysis with tidyverse (~1.2GB) [RECOMMENDED]"
    echo "  modeling     - Machine learning with tidymodels (~1.5GB)"
    echo "  publishing   - LaTeX/Quarto for manuscripts (~3GB)"
    echo "  shiny        - Shiny web applications (~1.8GB)"
    echo ""

    prompt_select "Default profile" "minimal,rstudio,analysis,modeling,publishing,shiny" "${CONFIG_DOCKER_DEFAULT_PROFILE:-analysis}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "docker.default_profile" "$val"

    prompt_select "Docker registry" "docker.io,ghcr.io" "${CONFIG_DOCKER_REGISTRY:-docker.io}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "docker.registry" "$val"

    #-------------------------------------------------------------------------
    # SECTION 6: GitHub
    #-------------------------------------------------------------------------
    print_section "6/8  GitHub Preferences"
    echo "Settings for GitHub repository creation."
    echo ""

    prompt_github_account "GitHub username" "${CONFIG_GITHUB_ACCOUNT:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && {
        yaml_set "$CONFIG_USER" "github.account" "$val"
        yaml_set "$CONFIG_USER" "defaults.github_account" "$val"
    }

    prompt_select "Default repository visibility" "private,public" "${CONFIG_GITHUB_DEFAULT_VISIBILITY:-private}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "github.default_visibility" "$val"

    prompt_select "Default branch name" "main,master" "${CONFIG_GITHUB_DEFAULT_BRANCH:-main}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "github.default_branch" "$val"

    #-------------------------------------------------------------------------
    # SECTION 7: CI/CD
    #-------------------------------------------------------------------------
    print_section "7/8  CI/CD Preferences"
    echo "Continuous integration settings for GitHub Actions."
    echo ""

    prompt_yesno "Enable GitHub Actions" "${CONFIG_CICD_ENABLE_GITHUB_ACTIONS:-true}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "cicd.enable_github_actions" "$val"

    if [[ "$val" == "true" ]]; then
        prompt_input "R versions to test (comma-separated)" "${CONFIG_CICD_R_VERSIONS:-4.3, 4.4}" val || { _save_and_exit; return 0; }
        yaml_set "$CONFIG_USER" "cicd.r_versions" "$val"

        prompt_yesno "Run code coverage" "${CONFIG_CICD_RUN_COVERAGE:-true}" val || { _save_and_exit; return 0; }
        yaml_set "$CONFIG_USER" "cicd.run_coverage" "$val"

        if [[ "$val" == "true" ]]; then
            prompt_validated "Coverage threshold (%)" "${CONFIG_CICD_COVERAGE_THRESHOLD:-80}" val validate_percentage \
                "Invalid value. Must be 0-100" || { _save_and_exit; return 0; }
            yaml_set "$CONFIG_USER" "cicd.coverage_threshold" "$val"
        fi
    fi

    #-------------------------------------------------------------------------
    # SECTION 8: Team Defaults
    #-------------------------------------------------------------------------
    print_section "8/8  Team Defaults"
    echo "Settings for team collaboration."
    echo ""

    prompt_input "Default team name" "${CONFIG_TEAM_NAME:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "defaults.team_name" "$val"

    # Reset trap
    trap - INT

    #-------------------------------------------------------------------------
    # COMPLETION
    #-------------------------------------------------------------------------
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                       Configuration Complete                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    log_success "Configuration saved to: $CONFIG_USER"
    echo ""
    echo "Quick commands:"
    echo "  zzcollab -c list              # View all settings"
    echo "  zzcollab -c set KEY VALUE     # Change a setting"
    echo "  zzcollab -c get KEY           # Get a setting value"
    echo ""
}

_save_and_exit() {
    trap - INT
    echo ""
    echo ""
    log_warn "Configuration cancelled"
    log_info "Progress saved to: $CONFIG_USER"
    log_info "Run 'zzcollab -c init --interactive' to continue"
}

#=============================================================================
# CONFIG SET/GET/LIST COMMANDS
#=============================================================================

config_set() {
    local key="$1" value="$2" local_only="${3:-false}"
    local file="$CONFIG_USER"

    [[ "$local_only" == "true" ]] && file="$CONFIG_PROJECT"

    if [[ ! -f "$file" ]]; then
        if [[ "$file" == "$CONFIG_PROJECT" ]]; then
            [[ -f "$CONFIG_USER" ]] && cp "$CONFIG_USER" "$file" || config_init
        else
            config_init
        fi
    fi

    # Normalize key: convert kebab-case to snake_case (user-facing uses kebab-case)
    key="${key//-/_}"

    # Handle dotted keys (e.g., author.name) vs simple keys (e.g., profile_name)
    if [[ "$key" == *"."* ]]; then
        yaml_set "$file" "$key" "$value" && log_success "Set $key = $value"
    else
        # Simple keys go in defaults section
        yaml_set "$file" "defaults.$key" "$value" && log_success "Set defaults.$key = $value"
    fi
}

config_get() {
    local key="$1" local_only="${2:-false}"

    # Normalize key: convert kebab-case to snake_case (user-facing uses kebab-case)
    key="${key//-/_}"

    if [[ "$local_only" == "true" ]]; then
        if [[ "$key" == *"."* ]]; then
            yaml_get "$CONFIG_PROJECT" "$key"
        else
            yaml_get "$CONFIG_PROJECT" "defaults.$key"
        fi
    else
        load_config
        _get_config_value "$key"
    fi
}

config_list() {
    local local_only="${1:-false}"
    local show_section="${2:-all}"
    local label="Configuration"

    if [[ "$local_only" == "true" ]]; then
        [[ -f "$CONFIG_PROJECT" ]] || { echo "No project config: $CONFIG_PROJECT"; return 0; }
        label="Project configuration"
    fi

    load_config

    echo ""
    echo "$label"
    echo "$(printf '=%.0s' {1..60})"

    if [[ "$show_section" == "all" || "$show_section" == "author" ]]; then
        echo ""
        echo "Author:"
        printf "  %-25s %s\n" "name:" "${CONFIG_AUTHOR_NAME:-<not set>}"
        printf "  %-25s %s\n" "email:" "${CONFIG_AUTHOR_EMAIL:-<not set>}"
        printf "  %-25s %s\n" "orcid:" "${CONFIG_AUTHOR_ORCID:-<not set>}"
        printf "  %-25s %s\n" "affiliation:" "${CONFIG_AUTHOR_AFFILIATION:-<not set>}"
    fi

    if [[ "$show_section" == "all" || "$show_section" == "license" ]]; then
        echo ""
        echo "License:"
        printf "  %-25s %s\n" "type:" "${CONFIG_LICENSE_TYPE:-<not set>}"
        printf "  %-25s %s\n" "year:" "${CONFIG_LICENSE_YEAR:-<not set>}"
        printf "  %-25s %s\n" "holder:" "${CONFIG_LICENSE_HOLDER:-<not set>}"
    fi

    if [[ "$show_section" == "all" || "$show_section" == "r_package" ]]; then
        echo ""
        echo "R Package:"
        printf "  %-25s %s\n" "min_r_version:" "${CONFIG_RPACKAGE_MIN_R_VERSION:-<not set>}"
        printf "  %-25s %s\n" "testthat_edition:" "${CONFIG_RPACKAGE_TESTTHAT_EDITION:-<not set>}"
        printf "  %-25s %s\n" "vignette_builder:" "${CONFIG_RPACKAGE_VIGNETTE_BUILDER:-<not set>}"
    fi

    if [[ "$show_section" == "all" || "$show_section" == "style" ]]; then
        echo ""
        echo "Code Style:"
        printf "  %-25s %s\n" "line_length:" "${CONFIG_STYLE_LINE_LENGTH:-<not set>}"
        printf "  %-25s %s\n" "use_native_pipe:" "${CONFIG_STYLE_USE_NATIVE_PIPE:-<not set>}"
        printf "  %-25s %s\n" "assignment:" "${CONFIG_STYLE_ASSIGNMENT:-<not set>}"
    fi

    if [[ "$show_section" == "all" || "$show_section" == "docker" ]]; then
        echo ""
        echo "Docker:"
        printf "  %-25s %s\n" "default_profile:" "${CONFIG_DOCKER_DEFAULT_PROFILE:-<not set>}"
        printf "  %-25s %s\n" "registry:" "${CONFIG_DOCKER_REGISTRY:-<not set>}"
    fi

    if [[ "$show_section" == "all" || "$show_section" == "github" ]]; then
        echo ""
        echo "GitHub:"
        printf "  %-25s %s\n" "account:" "${CONFIG_GITHUB_ACCOUNT:-<not set>}"
        printf "  %-25s %s\n" "default_visibility:" "${CONFIG_GITHUB_DEFAULT_VISIBILITY:-<not set>}"
        printf "  %-25s %s\n" "default_branch:" "${CONFIG_GITHUB_DEFAULT_BRANCH:-<not set>}"
    fi

    if [[ "$show_section" == "all" || "$show_section" == "cicd" ]]; then
        echo ""
        echo "CI/CD:"
        printf "  %-25s %s\n" "enable_github_actions:" "${CONFIG_CICD_ENABLE_GITHUB_ACTIONS:-<not set>}"
        printf "  %-25s %s\n" "r_versions:" "${CONFIG_CICD_R_VERSIONS:-<not set>}"
        printf "  %-25s %s\n" "run_coverage:" "${CONFIG_CICD_RUN_COVERAGE:-<not set>}"
        printf "  %-25s %s\n" "coverage_threshold:" "${CONFIG_CICD_COVERAGE_THRESHOLD:-<not set>}"
    fi

    if [[ "$show_section" == "all" || "$show_section" == "defaults" ]]; then
        echo ""
        echo "Team Defaults:"
        printf "  %-25s %s\n" "team_name:" "${CONFIG_TEAM_NAME:-<not set>}"
        printf "  %-25s %s\n" "profile_name:" "${CONFIG_PROFILE_NAME:-<not set>}"
        printf "  %-25s %s\n" "with_examples:" "$CONFIG_WITH_EXAMPLES"
    fi

    echo ""
    echo "Config Files:"
    [[ -f "$CONFIG_PROJECT" ]] && echo "  [x] $CONFIG_PROJECT" || echo "  [ ] $CONFIG_PROJECT"
    [[ -f "$CONFIG_USER" ]] && echo "  [x] $CONFIG_USER" || echo "  [ ] $CONFIG_USER"
    echo ""
}

config_validate() {
    local errors=0
    for file in "$CONFIG_PROJECT" "$CONFIG_USER"; do
        [[ -f "$file" ]] || continue
        printf "Checking %s... " "$file"
        if yq eval '.' "$file" >/dev/null 2>&1; then
            echo "OK"
        else
            echo "INVALID"
            errors=$((errors + 1))
        fi
    done
    [[ $errors -eq 0 ]]
}

#=============================================================================
# COMMAND DISPATCHER
#=============================================================================

handle_config_command() {
    local cmd="${1:-list}"
    shift 2>/dev/null || true

    case "$cmd" in
        init)
            if [[ "${1:-}" == "--interactive" || "${1:-}" == "-i" ]]; then
                config_init true
            else
                config_init false
            fi
            ;;
        set)
            [[ $# -ge 2 ]] || { echo "Usage: config set KEY VALUE"; return 1; }
            config_set "$1" "$2"
            ;;
        get)
            [[ $# -ge 1 ]] || { echo "Usage: config get KEY"; return 1; }
            config_get "$1"
            ;;
        list)
            config_list false "${1:-all}"
            ;;
        set-local)
            [[ $# -ge 2 ]] || { echo "Usage: config set-local KEY VALUE"; return 1; }
            config_set "$1" "$2" true
            ;;
        get-local)
            [[ $# -ge 1 ]] || { echo "Usage: config get-local KEY"; return 1; }
            config_get "$1" true
            ;;
        list-local)
            config_list true
            ;;
        validate)
            config_validate
            ;;
        path)
            echo "User:    $CONFIG_USER"
            echo "Project: $CONFIG_PROJECT"
            ;;
        *)
            echo "Unknown: $cmd"
            echo ""
            echo "Commands:"
            echo "  init                    Create default config file"
            echo "  init --interactive      Guided configuration wizard"
            echo "  set KEY VALUE           Set a configuration value"
            echo "  get KEY                 Get a configuration value"
            echo "  list [section]          List all or section config"
            echo "  set-local KEY VALUE     Set project-local value"
            echo "  get-local KEY           Get project-local value"
            echo "  list-local              List project config"
            echo "  validate                Validate YAML syntax"
            echo "  path                    Show config file paths"
            echo ""
            echo "Sections: author, license, r_package, style, docker, github, cicd, defaults"
            return 1
            ;;
    esac
}

#=============================================================================
# INITIALIZATION
#=============================================================================

init_config_system() {
    load_config
    apply_config_defaults
}

readonly ZZCOLLAB_CONFIG_LOADED=true
