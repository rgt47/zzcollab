#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CONFIGURATION MODULE (core)
##############################################################################
#
# Non-interactive core: YAML I/O, config loading, validators, CLI commands.
# Interactive prompts and wizard flows live in config-ui.sh (sourced after
# this module in zzcollab.sh).
#
# Manages YAML configuration files with priority: project > user > defaults
# Requires: yq (YAML processor, mikefarah v4+)
#
# Files:
#   ./zzcollab.yaml          - Project-specific config
#   ~/.zzcollab/config.yaml  - User global config
#
##############################################################################


#=============================================================================
# CONFIGURATION PATHS AND STATE
#=============================================================================

readonly CONFIG_PROJECT="${ZZCOLLAB_CONFIG_PROJECT:-./zzcollab.yaml}"
readonly CONFIG_USER_DIR="${ZZCOLLAB_CONFIG_USER_DIR:-$HOME/.zzcollab}"
readonly CONFIG_USER="${ZZCOLLAB_CONFIG_USER:-$CONFIG_USER_DIR/config.yaml}"

# Interactive mode state

# Original configuration state (backward compatibility)
CONFIG_TEAM_NAME=""
CONFIG_GITHUB_ACCOUNT=""
CONFIG_DOCKERHUB_ACCOUNT=""
CONFIG_PROFILE_NAME=""
CONFIG_R_VERSION=""
CONFIG_AUTO_GITHUB="false"
CONFIG_SKIP_CONFIRMATION="false"
CONFIG_WITH_EXAMPLES="false"
# Research archetype (init-time scaffolding axis): manuscript | analysis |
# package | simulation | blog. Empty -> analysis.
CONFIG_ARCHETYPE=""
# Dependency-validation (zzrenvcheck) defaults read by 'zzc validate'. strict
# also scans tests/ and vignettes/; fix auto-repairs DESCRIPTION. Empty ->
# strict on, fix off.
CONFIG_VALIDATE_STRICT=""
CONFIG_VALIDATE_FIX=""

# Feature defaults for new projects (set by 'zzc toggle --global', read by the
# init feature wizard). Empty means "use the built-in recommendation".
CONFIG_FEAT_BACKEND=""
CONFIG_FEAT_DOCKER=""
CONFIG_FEAT_CI=""
CONFIG_FEAT_DATA=""
CONFIG_FEAT_CODE_QUALITY=""
CONFIG_FEAT_TESTS=""
CONFIG_FEAT_CLOUD=""

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
CONFIG_RPACKAGE_ENCODING=""
CONFIG_RPACKAGE_VIGNETTE_BUILDER=""

# Extended configuration state - Code Style
CONFIG_STYLE_LINE_LENGTH=""
CONFIG_STYLE_USE_NATIVE_PIPE=""
CONFIG_STYLE_ASSIGNMENT=""

# Extended configuration state - Docker
# (The Docker Hub account is stored canonically in CONFIG_DOCKERHUB_ACCOUNT;
# the former docker.account key is kept as a read alias for back-compat.)
CONFIG_DOCKER_DEFAULT_PROFILE=""
CONFIG_DOCKER_REGISTRY=""
CONFIG_DOCKER_RUNTIME=""

# Extended configuration state - GitHub
CONFIG_GITHUB_DEFAULT_VISIBILITY=""
CONFIG_GITHUB_DEFAULT_BRANCH=""

# Extended configuration state - forge / GitLab
# Source forge for CI, remote creation, and cloud launch. Empty -> github
# (back-compatible). Consumers apply the default at the use site, e.g.
# "${CONFIG_FORGE:-github}", as with the feature defaults above.
CONFIG_FORGE=""
CONFIG_GITLAB_ACCOUNT=""
# GitLab host for self-hosted instances; empty -> gitlab.com at the use site.
CONFIG_GITLAB_HOST=""
CONFIG_GITLAB_DEFAULT_VISIBILITY=""
CONFIG_GITLAB_DEFAULT_BRANCH=""

#=============================================================================
# YAML OPERATIONS
#=============================================================================

_YQ_AVAILABLE=""
_require_yq() {
    [[ "$_YQ_AVAILABLE" == "true" ]] && return 0
    if command -v yq >/dev/null 2>&1; then
        # C-4: assert mikefarah yq v4+. kislyuk's Python yq and v3 both produce
        # subtly wrong output that config parsing silently swallows.
        local ver_line
        ver_line=$(yq --version 2>&1 | head -1)
        if echo "$ver_line" | grep -qE '(mikefarah|version v?4\.[0-9])'; then
            _YQ_AVAILABLE="true"
            return 0
        else
            log_error "yq found but not mikefarah v4 (got: $ver_line)"
            log_info "Install: brew install yq (macOS) or snap install yq (Ubuntu)"
            return 1
        fi
    fi
    log_error "yq required but not found"
    log_info "Install: brew install yq (macOS) or snap install yq (Ubuntu)"
    return 1
}

# Reject any path that is not a plain dotted key, so a user-supplied key
# cannot inject expressions into the yq program string.
_validate_yaml_path() {
    local path="$1"
    [[ "$path" =~ ^[A-Za-z0-9_.]+$ ]] || {
        log_error "Invalid config key: $path"
        return 1
    }
}

yaml_get() {
    local file="$1" path="$2"
    [[ -f "$file" ]] || return 1
    _validate_yaml_path "$path" || return 1
    _require_yq || return 1
    yq eval ".$path // \"\"" "$file" 2>/dev/null
}

yaml_set() {
    local file="$1" path="$2" value="$3"
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    _validate_yaml_path "$path" || return 1
    _require_yq || return 1
    _YQ_VAL="$value" yq eval ".$path = strenv(_YQ_VAL)" "$file" -i
}

# Persist the GitHub account to both the canonical github.account key and the
# legacy defaults.github_account, so older config readers still resolve it.
# Centralized so the dual write cannot drift across its call sites.
_set_github_account_yaml() {
    yaml_set "$1" "github.account" "$2"
    yaml_set "$1" "defaults.github_account" "$2"
}

# C-2: Persist profile to both docker.default_profile (canonical, what
# 'config get profile_name' reads) and defaults.profile_name (what the default
# template writes and what the loader uses for CONFIG_PROFILE_NAME).
# Centralised so both interactive and non-interactive set paths stay in sync.
_set_profile_name_yaml() {
    yaml_set "$1" "docker.default_profile" "$2"
    yaml_set "$1" "defaults.profile_name" "$2"
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

# validate_r_version() is defined in lib/core.sh.
# Config module uses lenient mode (X.Y or X.Y.Z).
validate_r_version_lenient() {
    validate_r_version --lenient "$@"
}

# Validate positive integer
validate_positive_int() {
    local num="$1"
    [[ -z "$num" ]] && return 0  # Empty is OK
    [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -gt 0 ]]
}

# Interactive input helpers (prompt_*, print_section, _interactive_cleanup)
# and wizard flows (config_identity_gate, config_project_prompt, config_init,
# config_interactive_setup, _setup_*) live in modules/config-ui.sh.



#=============================================================================
# CONFIGURATION LOADING
#=============================================================================

# Memo so load_config parses the YAML at most once per process. config_set /
# config_init reset it after writing so the next read reflects the change.
_CONFIG_LOADED=""

load_config() {
    [[ "$_CONFIG_LOADED" == "true" ]] && return 0

    # Reset to defaults - original fields
    CONFIG_TEAM_NAME=""
    CONFIG_GITHUB_ACCOUNT=""
    CONFIG_DOCKERHUB_ACCOUNT=""
    CONFIG_PROFILE_NAME=""
    CONFIG_R_VERSION=""
    CONFIG_AUTO_GITHUB="false"
    CONFIG_SKIP_CONFIRMATION="false"
    CONFIG_WITH_EXAMPLES="false"
    CONFIG_ARCHETYPE=""
    CONFIG_VALIDATE_STRICT=""
    CONFIG_VALIDATE_FIX=""

    # Reset feature defaults (empty -> built-in recommendation)
    CONFIG_FEAT_BACKEND=""
    CONFIG_FEAT_DOCKER=""
    CONFIG_FEAT_CI=""
    CONFIG_FEAT_DATA=""
    CONFIG_FEAT_CODE_QUALITY=""
    CONFIG_FEAT_TESTS=""
    CONFIG_FEAT_CLOUD=""

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
    CONFIG_RPACKAGE_ENCODING=""
    CONFIG_RPACKAGE_VIGNETTE_BUILDER=""
    CONFIG_STYLE_LINE_LENGTH=""
    CONFIG_STYLE_USE_NATIVE_PIPE=""
    CONFIG_STYLE_ASSIGNMENT=""
    CONFIG_DOCKER_DEFAULT_PROFILE=""
    CONFIG_DOCKER_REGISTRY=""
    CONFIG_DOCKER_RUNTIME=""
    CONFIG_GITHUB_DEFAULT_VISIBILITY=""
    CONFIG_GITHUB_DEFAULT_BRANCH=""
    CONFIG_FORGE=""
    CONFIG_GITLAB_ACCOUNT=""
    CONFIG_GITLAB_HOST=""
    CONFIG_GITLAB_DEFAULT_VISIBILITY=""
    CONFIG_GITLAB_DEFAULT_BRANCH=""

    # Load in reverse priority (later overrides earlier)
    _load_file "$CONFIG_USER"
    _load_file "$CONFIG_PROJECT"

    _CONFIG_LOADED="true"
}

# Table mapping YAML paths to CONFIG_* variable names.
# Format: "yaml.path CONFIG_VAR_NAME" (space-separated, one per line).
# To add a new config field: add one line here and declare the variable above.
_CONFIG_MAP="
defaults.team_name              CONFIG_TEAM_NAME
defaults.github_account         CONFIG_GITHUB_ACCOUNT
defaults.dockerhub_account      CONFIG_DOCKERHUB_ACCOUNT
defaults.profile_name           CONFIG_PROFILE_NAME
defaults.r_version              CONFIG_R_VERSION
defaults.auto_github            CONFIG_AUTO_GITHUB
defaults.skip_confirmation      CONFIG_SKIP_CONFIRMATION
defaults.with_examples          CONFIG_WITH_EXAMPLES
defaults.archetype              CONFIG_ARCHETYPE
validate.strict                 CONFIG_VALIDATE_STRICT
validate.fix                    CONFIG_VALIDATE_FIX
author.name                     CONFIG_AUTHOR_NAME
author.email                    CONFIG_AUTHOR_EMAIL
author.orcid                    CONFIG_AUTHOR_ORCID
author.affiliation              CONFIG_AUTHOR_AFFILIATION
author.affiliation_full         CONFIG_AUTHOR_AFFILIATION_FULL
author.roles                    CONFIG_AUTHOR_ROLES
license.type                    CONFIG_LICENSE_TYPE
license.year                    CONFIG_LICENSE_YEAR
license.holder                  CONFIG_LICENSE_HOLDER
license.include_file            CONFIG_LICENSE_INCLUDE_FILE
r_package.min_r_version         CONFIG_RPACKAGE_MIN_R_VERSION
r_package.roxygen_version       CONFIG_RPACKAGE_ROXYGEN_VERSION
r_package.encoding              CONFIG_RPACKAGE_ENCODING
r_package.vignette_builder      CONFIG_RPACKAGE_VIGNETTE_BUILDER
style.line_length               CONFIG_STYLE_LINE_LENGTH
style.use_native_pipe           CONFIG_STYLE_USE_NATIVE_PIPE
style.assignment                CONFIG_STYLE_ASSIGNMENT
docker.default_profile          CONFIG_DOCKER_DEFAULT_PROFILE
docker.registry                 CONFIG_DOCKER_REGISTRY
docker.runtime                  CONFIG_DOCKER_RUNTIME
features.backend                CONFIG_FEAT_BACKEND
features.docker                 CONFIG_FEAT_DOCKER
features.ci                     CONFIG_FEAT_CI
features.data                   CONFIG_FEAT_DATA
features.code_quality           CONFIG_FEAT_CODE_QUALITY
features.tests                  CONFIG_FEAT_TESTS
features.cloud                  CONFIG_FEAT_CLOUD
github.account                  CONFIG_GITHUB_ACCOUNT
github.default_visibility       CONFIG_GITHUB_DEFAULT_VISIBILITY
github.default_branch           CONFIG_GITHUB_DEFAULT_BRANCH
forge                           CONFIG_FORGE
gitlab.account                  CONFIG_GITLAB_ACCOUNT
gitlab.host                     CONFIG_GITLAB_HOST
gitlab.default_visibility       CONFIG_GITLAB_DEFAULT_VISIBILITY
gitlab.default_branch           CONFIG_GITLAB_DEFAULT_BRANCH
"

# Friendly user-key aliases that do NOT follow the derivation rule (user key =
# YAML path with 'defaults.' stripped and dots->underscores). snake_case form
# on the left, canonical YAML write path on the right. Checked before the
# derivation, so e.g. 'github_account' writes to github.account (the canonical
# path) rather than the legacy load-only defaults.github_account.
_CONFIG_ALIASES="
profile_name      docker.default_profile
profile           docker.default_profile
docker_account    defaults.dockerhub_account
github_account    github.account
"

# Map a YAML path to its CONFIG_* variable name via _CONFIG_MAP (the same table
# the loader uses), so config get is symmetric with config set. Prints the var
# name and returns 0, or returns 1 if the path is unknown.
_yaml_path_to_var() {
    local target="$1" yp vn
    while read -r yp vn; do
        [[ -z "$yp" ]] && continue
        [[ "$yp" == "$target" ]] && { echo "$vn"; return 0; }
    done <<< "$_CONFIG_MAP"
    return 1
}

_load_file() {
    local file="$1"
    # Absent file is normal (user may not have a project config yet).
    [[ -f "$file" ]] || return 0
    _require_yq || return 0

    # C-3: distinguish "file absent" (handled above) from "file present but
    # unparseable". A malformed zzcollab.yaml must be an error, not a silent
    # fallback to defaults that silently selects a different Docker image.
    local dump yq_rc
    dump=$(yq eval \
        '.. | select(tag != "!!map" and tag != "!!seq") | (path | join(".")) + "=" + (. | tostring)' \
        "$file" 2>&1)
    yq_rc=$?
    if [[ "$yq_rc" -ne 0 ]]; then
        log_error "Failed to parse config file: $file"
        log_error "  $(echo "$dump" | head -3)"
        return 1
    fi

    # Parse the dump once into parallel path/value arrays. Splitting on the
    # first '=' is safe because yq paths never contain '='.
    local _paths=() _vals=() line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        _paths+=("${line%%=*}")
        _vals+=("${line#*=}")
    done <<< "$dump"

    # Assign in _CONFIG_MAP order so map precedence is preserved (e.g.
    # github.account overrides defaults.github_account). Empty values are
    # skipped, matching the previous behaviour.
    local yaml_path var_name i
    while read -r yaml_path var_name; do
        [[ -z "$yaml_path" ]] && continue
        for ((i = 0; i < ${#_paths[@]}; i++)); do
            if [[ "${_paths[$i]}" == "$yaml_path" ]]; then
                [[ -n "${_vals[$i]}" ]] && printf -v "$var_name" '%s' "${_vals[$i]}"
                break
            fi
        done
    done <<< "$_CONFIG_MAP"

    # docker.default_profile also overrides CONFIG_PROFILE_NAME (legacy compat)
    for ((i = 0; i < ${#_paths[@]}; i++)); do
        if [[ "${_paths[$i]}" == "docker.default_profile" && -n "${_vals[$i]}" ]]; then
            CONFIG_PROFILE_NAME="${_vals[$i]}"
            break
        fi
    done

    # C-1: mirror defaults.profile_name → CONFIG_DOCKER_DEFAULT_PROFILE so that
    # 'config get profile_name' (which reads CONFIG_DOCKER_DEFAULT_PROFILE via the
    # alias table) is symmetric with what the default template writes
    # (defaults.profile_name). Matches the github.account dual-load pattern.
    if [[ -n "$CONFIG_PROFILE_NAME" && -z "$CONFIG_DOCKER_DEFAULT_PROFILE" ]]; then
        CONFIG_DOCKER_DEFAULT_PROFILE="$CONFIG_PROFILE_NAME"
    fi

    # Legacy docker.account folds into the canonical dockerhub_account
    if [[ -z "$CONFIG_DOCKERHUB_ACCOUNT" ]]; then
        for ((i = 0; i < ${#_paths[@]}; i++)); do
            if [[ "${_paths[$i]}" == "docker.account" && -n "${_vals[$i]}" ]]; then
                CONFIG_DOCKERHUB_ACCOUNT="${_vals[$i]}"
                break
            fi
        done
    fi

    return 0
}

apply_config_defaults() {
    [[ -z "${TEAM_NAME:-}" && -n "$CONFIG_TEAM_NAME" ]] && TEAM_NAME="$CONFIG_TEAM_NAME"
    [[ -z "${GITHUB_ACCOUNT:-}" && -n "$CONFIG_GITHUB_ACCOUNT" ]] && GITHUB_ACCOUNT="$CONFIG_GITHUB_ACCOUNT"
    [[ -z "${DOCKERHUB_ACCOUNT:-}" && -n "$CONFIG_DOCKERHUB_ACCOUNT" ]] && DOCKERHUB_ACCOUNT="$CONFIG_DOCKERHUB_ACCOUNT"
    [[ -z "${PROFILE_NAME:-}" && -n "$CONFIG_PROFILE_NAME" ]] && PROFILE_NAME="$CONFIG_PROFILE_NAME"

    if [[ -z "${R_VERSION:-}" ]]; then
        R_VERSION="${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}"
    fi

    [[ "$CONFIG_AUTO_GITHUB" == "true" ]] && CREATE_GITHUB_REPO=true
    [[ "$CONFIG_SKIP_CONFIRMATION" == "true" ]] && SKIP_CONFIRMATION=true
    [[ "${WITH_EXAMPLES:-false}" == "false" && "$CONFIG_WITH_EXAMPLES" == "true" ]] && WITH_EXAMPLES=true
    return 0
}

# _get_config_value was removed: config get now reads the merged value via
# _key_to_yaml_path + _yaml_path_to_var (the same _CONFIG_MAP the loader uses),
# so get is symmetric with set and there is a single source of truth.

# config_identity_gate, config_project_prompt, config_init,
# config_interactive_setup, _setup_* → moved to config-ui.sh


#=============================================================================
# CONFIG SET/GET/LIST COMMANDS
#=============================================================================

# Translate a snake_case config key alias to its dotted YAML path. Shared by
# config_get and config_set so the read and write paths cannot drift.
# Resolve a user-facing key (snake_case) to its canonical YAML write path,
# driven entirely by _CONFIG_ALIASES + _CONFIG_MAP. Prints the path and returns
# 0; prints nothing and returns 1 if the key is unknown (so callers can reject
# typos instead of silently writing an unreadable defaults.<typo> entry).
_key_to_yaml_path() {
    local key="$1" yp vn k akey apath
    # 1. Explicit friendly aliases (e.g. profile_name -> docker.default_profile).
    while read -r akey apath; do
        [[ -z "$akey" ]] && continue
        [[ "$key" == "$akey" ]] && { echo "$apath"; return 0; }
    done <<< "$_CONFIG_ALIASES"
    # 2. Derive from _CONFIG_MAP: user key = path with 'defaults.' stripped and
    #    remaining dots turned into underscores (team_name, docker_registry,
    #    style_line_length, author_name, github_default_visibility, ...).
    while read -r yp vn; do
        [[ -z "$yp" ]] && continue
        k="${yp#defaults.}"
        k="${k//./_}"
        [[ "$key" == "$k" ]] && { echo "$yp"; return 0; }
    done <<< "$_CONFIG_MAP"
    # 3. A fully-dotted key that names a known path passes through.
    if [[ "$key" == *.* ]]; then
        while read -r yp vn; do
            [[ "$yp" == "$key" ]] && { echo "$yp"; return 0; }
        done <<< "$_CONFIG_MAP"
    fi
    return 1
}

config_set() {
    local key="$1" value="$2" local_only="${3:-false}"
    local file="$CONFIG_USER"

    [[ "$local_only" == "true" ]] && file="$CONFIG_PROJECT"

    if [[ ! -f "$file" ]]; then
        if [[ "$file" == "$CONFIG_PROJECT" ]]; then
            # Create minimal project config. Only the header; the actual key
            # is written below, so no placeholder stub (an empty
            # docker.default_profile here would persist as a meaningless
            # override). Matches config_project_prompt's creation site.
            cat > "$file" << 'EOF'
# Project-specific zzcollab configuration
# Overrides user config (~/.zzcollab/config.yaml)
# Commit this file to version control.
EOF
            log_debug "Created project config: $file"
        else
            config_init
        fi
    fi

    # Normalize key: convert kebab-case to snake_case (user-facing uses kebab-case)
    key="${key//-/_}"

    # C-5: Dispatch validators so non-interactive config set rejects bad values
    # with the same checks the interactive path applies.
    if [[ -n "$value" ]]; then
        case "$key" in
            team_name|dockerhub_account|docker_account)
                validate_team_name "$value" || return 1 ;;
            author_email)
                validate_email "$value" || {
                    log_error "Invalid email: $value"
                    return 1
                } ;;
            author_orcid)
                validate_orcid "$value" || {
                    log_error "Invalid ORCID (expected 0000-0000-0000-000X): $value"
                    return 1
                } ;;
            r_version|rpackage_min_r_version)
                validate_r_version_lenient "$value" || {
                    log_error "Invalid R version (expected X.Y or X.Y.Z): $value"
                    return 1
                } ;;
            style_line_length|rpackage_roxygen_version)
                validate_positive_int "$value" || {
                    log_error "Invalid value (expected positive integer): $value"
                    return 1
                } ;;
            profile_name|profile)
                case "$value" in
                    minimal|analysis|rstudio) ;;
                    *) log_error "Unknown profile: $value (valid: minimal, analysis, rstudio)"
                       return 1 ;;
                esac ;;
            archetype)
                case "$value" in
                    manuscript|analysis|package|simulation|blog) ;;
                    *) log_error "Unknown archetype: $value (valid: manuscript, analysis, package, simulation, blog)"
                       return 1 ;;
                esac ;;
            docker_runtime)
                case "$value" in
                    docker|podman|apptainer) ;;
                    *) log_error "Unknown runtime: $value (valid: docker, podman, apptainer)"
                       return 1 ;;
                esac ;;
            validate_strict|validate_fix)
                case "$value" in
                    true|false) ;;
                    *) log_error "Expected true or false for $key (got: $value)"
                       return 1 ;;
                esac ;;
            forge)
                case "$value" in
                    github|gitlab|none) ;;
                    *) log_error "Unknown forge: $value (valid: github, gitlab, none)"
                       return 1 ;;
                esac ;;
        esac
    fi

    # Resolve the key to its canonical YAML path; reject unknown keys so a typo
    # is not silently written to an unreadable defaults.<typo> entry.
    local yaml_path
    yaml_path=$(_key_to_yaml_path "$key") || {
        log_error "Unknown config key: $1"
        log_info "See available settings: zzcollab config list"
        return 1
    }

    # Invalidate the load_config memo so the next read sees the new value.
    _CONFIG_LOADED=""

    # C-2: profile_name must write to both YAML paths to keep the loader and
    # the alias table in sync.
    if [[ "$yaml_path" == "docker.default_profile" ]]; then
        _set_profile_name_yaml "$file" "$value" && log_success "Set profile_name = $value"
    else
        yaml_set "$file" "$yaml_path" "$value" && log_success "Set $yaml_path = $value"
    fi
}

config_get() {
    local key="$1" local_only="${2:-false}"

    # Normalize key: convert kebab-case to snake_case (user-facing uses kebab-case)
    key="${key//-/_}"

    # Resolve the key to its canonical YAML path (same mapping as config_set).
    local yaml_path
    yaml_path=$(_key_to_yaml_path "$key") || {
        log_error "Unknown config key: $1"
        return 1
    }

    if [[ "$local_only" == "true" ]]; then
        yaml_get "$CONFIG_PROJECT" "$yaml_path"
    else
        load_config
        # Read the merged value by mapping the YAML path to its CONFIG_ var, so
        # get is symmetric with set (both route through _key_to_yaml_path).
        local var
        var=$(_yaml_path_to_var "$yaml_path") && printf '%s\n' "${!var}"
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
        printf "  %-25s %s\n" "account:" "${CONFIG_DOCKERHUB_ACCOUNT:-<not set>}"
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

    if [[ "$show_section" == "all" || "$show_section" == "defaults" ]]; then
        echo ""
        echo "Team Defaults:"
        printf "  %-25s %s\n" "team_name:" "${CONFIG_TEAM_NAME:-<not set>}"
        printf "  %-25s %s\n" "with_examples:" "$CONFIG_WITH_EXAMPLES"
    fi

    echo ""
    echo "Config Files:"
    [[ -f "$CONFIG_PROJECT" ]] && echo "  [x] $CONFIG_PROJECT" || echo "  [ ] $CONFIG_PROJECT"
    [[ -f "$CONFIG_USER" ]] && echo "  [x] $CONFIG_USER" || echo "  [ ] $CONFIG_USER"
    echo ""
}

#=============================================================================
# INITIALIZATION
#=============================================================================

init_config_system() {
    load_config
    apply_config_defaults
}

