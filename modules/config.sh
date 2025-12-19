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

# Configuration state (populated by load_config)
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

#=============================================================================
# CONFIGURATION LOADING
#=============================================================================

load_config() {
    # Reset to defaults
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

    # Load in reverse priority (later overrides earlier)
    _load_file "$CONFIG_USER"
    _load_file "$CONFIG_PROJECT"
}

_load_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local val
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
        *) echo "" ;;
    esac
}

#=============================================================================
# CONFIG COMMANDS
#=============================================================================

config_init() {
    mkdir -p "$CONFIG_USER_DIR"

    if [[ -f "$CONFIG_USER" ]]; then
        log_warn "Config exists: $CONFIG_USER"
        read -p "Overwrite? [y/N] " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] || return 0
    fi

    cat > "$CONFIG_USER" << 'EOF'
# ZZCOLLAB Configuration
# Values here are defaults unless overridden by CLI flags

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

config_set() {
    local key="$1" value="$2" local_only="${3:-false}"
    local file="$CONFIG_USER"

    [[ "$local_only" == "true" ]] && file="$CONFIG_PROJECT"
    key="${key//-/_}"

    if [[ ! -f "$file" ]]; then
        if [[ "$file" == "$CONFIG_PROJECT" ]]; then
            [[ -f "$CONFIG_USER" ]] && cp "$CONFIG_USER" "$file" || config_init
        else
            config_init
        fi
    fi

    yaml_set "$file" "defaults.$key" "$value" && log_success "Set $key = $value"
}

config_get() {
    local key="$1" local_only="${2:-false}"
    key="${key//-/_}"

    if [[ "$local_only" == "true" ]]; then
        yaml_get "$CONFIG_PROJECT" "defaults.$key"
    else
        load_config
        _get_config_value "$key"
    fi
}

config_list() {
    local local_only="${1:-false}"
    local label="Configuration"

    if [[ "$local_only" == "true" ]]; then
        [[ -f "$CONFIG_PROJECT" ]] || { echo "No project config: $CONFIG_PROJECT"; return 0; }
        label="Project configuration"
    fi

    load_config
    echo "$label:"
    echo ""
    printf "  %-20s %s\n" "team_name:" "${CONFIG_TEAM_NAME:-<not set>}"
    printf "  %-20s %s\n" "github_account:" "${CONFIG_GITHUB_ACCOUNT:-<not set>}"
    printf "  %-20s %s\n" "dockerhub_account:" "${CONFIG_DOCKERHUB_ACCOUNT:-<not set>}"
    printf "  %-20s %s\n" "profile_name:" "${CONFIG_PROFILE_NAME:-<not set>}"
    printf "  %-20s %s\n" "libs_bundle:" "${CONFIG_LIBS_BUNDLE:-<not set>}"
    printf "  %-20s %s\n" "pkgs_bundle:" "${CONFIG_PKGS_BUNDLE:-<not set>}"
    printf "  %-20s %s\n" "r_version:" "${CONFIG_R_VERSION:-<not set>}"
    printf "  %-20s %s\n" "auto_github:" "$CONFIG_AUTO_GITHUB"
    printf "  %-20s %s\n" "skip_confirmation:" "$CONFIG_SKIP_CONFIRMATION"
    printf "  %-20s %s\n" "with_examples:" "$CONFIG_WITH_EXAMPLES"
    echo ""
    echo "Files:"
    [[ -f "$CONFIG_PROJECT" ]] && echo "  [x] $CONFIG_PROJECT" || echo "  [ ] $CONFIG_PROJECT"
    [[ -f "$CONFIG_USER" ]] && echo "  [x] $CONFIG_USER" || echo "  [ ] $CONFIG_USER"
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
        init)       config_init ;;
        set)        [[ $# -ge 2 ]] || { echo "Usage: config set KEY VALUE"; return 1; }
                    config_set "$1" "$2" ;;
        get)        [[ $# -ge 1 ]] || { echo "Usage: config get KEY"; return 1; }
                    config_get "$1" ;;
        list)       config_list ;;
        set-local)  [[ $# -ge 2 ]] || { echo "Usage: config set-local KEY VALUE"; return 1; }
                    config_set "$1" "$2" true ;;
        get-local)  [[ $# -ge 1 ]] || { echo "Usage: config get-local KEY"; return 1; }
                    config_get "$1" true ;;
        list-local) config_list true ;;
        validate)   config_validate ;;
        path)       echo "User:    $CONFIG_USER"
                    echo "Project: $CONFIG_PROJECT" ;;
        *)          echo "Unknown: $cmd"
                    echo "Commands: init, set, get, list, set-local, get-local, list-local, validate, path"
                    return 1 ;;
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
