#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CONFIGURATION UI MODULE
##############################################################################
#
# Interactive prompts, wizard flows, and init helpers.
# Extracted from config.sh to keep the non-interactive core testable.
#
# DEPENDENCIES: config.sh must be sourced first (provides yaml_set, yaml_get,
#   validate_*, load_config, CONFIG_* state, CONFIG_USER, CONFIG_PROJECT).
#
##############################################################################

#=============================================================================
# INTERACTIVE INPUT HELPERS
#=============================================================================

# Trap handler for clean exit
_interactive_cleanup() {
    echo ""
    echo ""
    log_warn "Configuration cancelled by user"
    echo "Partial configuration may have been saved."
    echo "Run 'zzcollab config init --interactive' to continue setup."
    return 0
}

# Prompt for input with default value and exit handling
# Usage: prompt_input "Prompt text" "default_value" result_var
prompt_input() {
    local prompt="$1"
    local default="$2"
    local result_var="$3"
    local input

    if has_gum; then
        input=$(gum_input "${default:-(enter value)}" "$prompt" "$default") || {
            return 1
        }
        printf -v "$result_var" '%s' "${input:-$default}"
        return 0
    fi

    if [[ -n "$default" ]]; then
        printf "%s [%s]: " "$prompt" "$default"
    else
        printf "%s: " "$prompt"
    fi

    zzc_read -r input || {
        return 1
    }

    if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
        return 1
    fi

    printf -v "$result_var" '%s' "${input:-$default}"
    return 0
}

# Prompt for validated input with retry
# Usage: prompt_validated "Prompt" "default" result_var validator_func "error_message"
prompt_validated() {
    local prompt="$1"
    local default="$2"
    local result_var="$3"
    local validator="$4"
    local error_msg="${5:-Invalid input}"
    local input

    if has_gum; then
        while true; do
            input=$(gum_input "${default:-(enter value)}" "$prompt" "$default") || {
                return 1
            }
            input="${input:-$default}"
            if $validator "$input"; then
                printf -v "$result_var" '%s' "$input"
                return 0
            else
                log_warn "$error_msg"
            fi
        done
    fi

    while true; do
        if [[ -n "$default" ]]; then
            printf "%s [%s]: " "$prompt" "$default"
        else
            printf "%s: " "$prompt"
        fi

        zzc_read -r input || {
            return 1
        }

        if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
            return 1
        fi

        input="${input:-$default}"

        if $validator "$input"; then
            printf -v "$result_var" '%s' "$input"
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
    local result_var="$3"
    local input

    if has_gum; then
        while true; do
            input=$(gum_input "${default:-github-username}" "$prompt" "$default") || {
                return 1
            }
            input="${input:-$default}"
            if [[ -z "$input" ]]; then
                printf -v "$result_var" '%s' ""
                return 0
            fi
            log_info "Checking GitHub account..."
            local rc=0
            forge_account_exists github "$input" || rc=$?
            case $rc in
                0)  log_success "Account found: $input"
                    printf -v "$result_var" '%s' "$input"; return 0 ;;
                2)  printf -v "$result_var" '%s' "$input"; return 0 ;;
                *)  log_warn "Account '$input' not found on GitHub. Please check the username." ;;
            esac
        done
    fi

    while true; do
        if [[ -n "$default" ]]; then
            printf "%s [%s]: " "$prompt" "$default"
        else
            printf "%s: " "$prompt"
        fi

        zzc_read -r input || {
            return 1
        }

        if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
            return 1
        fi

        input="${input:-$default}"

        if [[ -z "$input" ]]; then
            printf -v "$result_var" '%s' ""
            return 0
        fi

        printf "  Checking GitHub account..."
        local rc=0
        forge_account_exists github "$input" || rc=$?
        case $rc in
            0)  echo " OK"
                printf -v "$result_var" '%s' "$input"; return 0 ;;
            2)  echo ""
                printf -v "$result_var" '%s' "$input"; return 0 ;;
            *)  echo " not found"
                echo "  Account '$input' not found on GitHub. Please check the username." ;;
        esac
    done
}

# Prompt for yes/no with default
# Usage: prompt_yesno "Question" "y" result_var
prompt_yesno() {
    local prompt="$1"
    local default="$2"
    local result_var="$3"
    local input

    if has_gum; then
        if gum_confirm "$prompt"; then
            printf -v "$result_var" '%s' "true"
        else
            printf -v "$result_var" '%s' "false"
        fi
        return 0
    fi

    local hint="y/n"
    [[ "$default" == "y" ]] && hint="Y/n"
    [[ "$default" == "n" ]] && hint="y/N"

    printf "%s (%s): " "$prompt" "$hint"

    zzc_read -r input || {
        return 1
    }

    if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
        return 1
    fi

    input="${input:-$default}"
    if [[ "$input" =~ ^[Yy] ]]; then
        printf -v "$result_var" '%s' "true"
    else
        printf -v "$result_var" '%s' "false"
    fi
    return 0
}

# Prompt for selection from list
# Usage: prompt_select "Prompt" "opt1,opt2,opt3" "default" result_var
prompt_select() {
    local prompt="$1"
    local options="$2"
    local default="$3"
    local result_var="$4"
    local input

    if has_gum; then
        local item items_csv
        items_csv="$options"
        local gum_args=()
        local IFS_SAVED="$IFS"
        IFS=',' read -ra gum_args <<< "$items_csv"
        IFS="$IFS_SAVED"
        local trimmed_args=()
        for item in "${gum_args[@]}"; do
            trimmed_args+=("${item#"${item%%[! ]*}"}")
        done
        input=$(gum_choose "$prompt" "${trimmed_args[@]}") || {
            return 1
        }
        printf -v "$result_var" '%s' "${input:-$default}"
        return 0
    fi

    while true; do
        printf "%s (%s) [%s]: " "$prompt" "$options" "$default"

        zzc_read -r input || {
            return 1
        }

        if [[ "$input" == "q" || "$input" == "Q" || "$input" == ":q" ]]; then
            return 1
        fi

        input="${input:-$default}"

        if [[ ",$options," == *",$input,"* ]]; then
            printf -v "$result_var" '%s' "$input"
            return 0
        else
            echo "  Invalid choice. Please select from: $options"
        fi
    done
}

# Print section header
print_section() {
    local title="$1"
    if has_gum; then
        gum_header "$title"
        return 0
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

#=============================================================================
# INIT FLOW HELPERS
#=============================================================================

##############################################################################
# FUNCTION: config_identity_gate
# PURPOSE:  Ensure required identity fields (name, email) are present in the
#           user config before project creation. When either is missing, runs
#           a short interactive prompt and writes to CONFIG_USER.
#           GitHub account is also captured here as the personal default.
# RETURNS:  0 on success, 1 if required fields cannot be captured.
##############################################################################
config_identity_gate() {
    local needs_name=false needs_email=false

    [[ -z "${CONFIG_AUTHOR_NAME:-}" ]] && needs_name=true
    [[ -z "${CONFIG_AUTHOR_EMAIL:-}" ]] && needs_email=true

    if [[ "$needs_name" == "false" && "$needs_email" == "false" ]]; then
        return 0
    fi

    if [[ ! -t 0 ]] || [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
        log_error "Required identity fields missing in user config"
        log_error "Run: zzcollab config init --interactive"
        return 1
    fi

    # Ensure the file exists and carries the full current schema, so the
    # writes below land in a structured, complete config.
    config_backfill_schema "$CONFIG_USER"

    echo ""
    print_section "One-time Identity Setup"
    echo "  These fields go into DESCRIPTION and are saved to ~/.zzcollab/config.yaml."
    echo "  You will not be asked again once they are set."
    echo ""

    local val
    if [[ "$needs_name" == "true" ]]; then
        prompt_input "Full name" "${CONFIG_AUTHOR_NAME:-}" val || return 1
        if [[ -z "$val" ]]; then
            log_error "Name is required"
            return 1
        fi
        yaml_set "$CONFIG_USER" "author.name" "$val"
        CONFIG_AUTHOR_NAME="$val"
    fi

    if [[ "$needs_email" == "true" ]]; then
        prompt_validated "Email address" "${CONFIG_AUTHOR_EMAIL:-}" val \
            validate_email "Invalid email format. Example: user@example.com" || return 1
        if [[ -z "$val" ]]; then
            log_error "Email is required"
            return 1
        fi
        yaml_set "$CONFIG_USER" "author.email" "$val"
        CONFIG_AUTHOR_EMAIL="$val"
    fi

    if [[ -z "${CONFIG_GITHUB_ACCOUNT:-}" ]]; then
        echo ""
        echo "  Your personal GitHub username (can be overridden per-project in the next step)."
        prompt_github_account "Personal GitHub username (optional)" "${CONFIG_GITHUB_ACCOUNT:-}" val || return 1
        if [[ -n "$val" ]]; then
            _set_github_account_yaml "$CONFIG_USER" "$val"
            CONFIG_GITHUB_ACCOUNT="$val"
        fi
    fi

    echo ""
    log_success "Identity saved to: $CONFIG_USER"
    return 0
}

##############################################################################
# FUNCTION: config_identity_review
# PURPOSE:  Single entry point for the identity step of `zzc init`. Handles
#           two cases:
#             1. Required fields (name/email) missing -> delegate to
#                config_identity_gate, which prompts for them (required).
#             2. Both present -> show the saved identity and offer an optional
#                update, pre-filling each prompt with the existing value so a
#                bare Enter keeps it. Because users run `zzc init` for every
#                new repo, the default is to keep existing values (no prompt
#                churn); only an explicit yes walks the fields.
# RETURNS:  0 on success or skip, 1 if required fields cannot be captured.
##############################################################################
config_identity_review() {
    local needs_name=false needs_email=false
    [[ -z "${CONFIG_AUTHOR_NAME:-}" ]] && needs_name=true
    [[ -z "${CONFIG_AUTHOR_EMAIL:-}" ]] && needs_email=true

    # Case 1: required fields absent -> must capture them.
    if [[ "$needs_name" == "true" || "$needs_email" == "true" ]]; then
        config_identity_gate || return 1
        return 0
    fi

    # Case 2: identity already complete. Non-interactive runs keep it silently.
    if [[ ! -t 0 ]] || [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
        return 0
    fi

    echo ""
    print_section "Author Identity"
    echo "  Saved in ~/.zzcollab/config.yaml (used for DESCRIPTION and reports)."
    printf "    Name:   %s\n" "${CONFIG_AUTHOR_NAME}"
    printf "    Email:  %s\n" "${CONFIG_AUTHOR_EMAIL}"
    [[ -n "${CONFIG_GITHUB_ACCOUNT:-}" ]] && printf "    GitHub: %s\n" "${CONFIG_GITHUB_ACCOUNT}"
    echo ""

    local ans
    prompt_yesno "Change these values?" "n" ans || return 0
    [[ "$ans" != "true" ]] && return 0

    # Make sure the file carries the full schema before writing into it.
    config_backfill_schema "$CONFIG_USER"

    local val
    prompt_input "Full name" "${CONFIG_AUTHOR_NAME}" val || return 0
    if [[ -n "$val" ]]; then
        yaml_set "$CONFIG_USER" "author.name" "$val"
        CONFIG_AUTHOR_NAME="$val"
    fi

    prompt_validated "Email address" "${CONFIG_AUTHOR_EMAIL}" val \
        validate_email "Invalid email format. Example: user@example.com" || return 0
    if [[ -n "$val" ]]; then
        yaml_set "$CONFIG_USER" "author.email" "$val"
        CONFIG_AUTHOR_EMAIL="$val"
    fi

    prompt_github_account "Personal GitHub username (optional)" \
        "${CONFIG_GITHUB_ACCOUNT:-}" val || return 0
    if [[ -n "$val" ]]; then
        _set_github_account_yaml "$CONFIG_USER" "$val"
        CONFIG_GITHUB_ACCOUNT="$val"
    fi

    echo ""
    log_success "Identity updated: $CONFIG_USER"
    return 0
}

##############################################################################
# FUNCTION: config_project_prompt
# PURPOSE:  Capture project-specific overrides during zzc init.
#           Pre-fills each prompt with the current user-level default.
#           Writes ONLY changed values to ./zzcollab.yaml so the file
#           stays minimal and contains only true overrides.
# USAGE:    config_project_prompt "PackageName"
# RETURNS:  0 on success, 1 on cancel
##############################################################################
config_project_prompt() {
    local pkg_name="${1:-$(basename "$(pwd)")}"

    local default_profile="${CONFIG_PROFILE_NAME:-analysis}"
    local default_r_version="${CONFIG_R_VERSION:-}"
    local default_github="${CONFIG_GITHUB_ACCOUNT:-}"
    local default_team="${CONFIG_TEAM_NAME:-}"

    if [[ -z "$default_r_version" ]]; then
        default_r_version="${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}"
    fi

    print_section "Project Setup: $pkg_name"
    echo "  Pre-filled from your user config. Edit to override for this project only."
    echo "  Changes are written to ./zzcollab.yaml (not your global config)."
    echo ""

    local val new_profile new_r_version new_github new_team

    prompt_select "Docker profile" \
        "minimal,analysis,rstudio" \
        "$default_profile" val || return 1
    new_profile="$val"

    prompt_validated "R version" "$default_r_version" val \
        validate_r_version "Expected format: X.Y.Z (e.g., 4.4.2)" || return 1
    new_r_version="$val"

    prompt_github_account \
        "GitHub account for this project (personal or org)" \
        "$default_github" val || return 1
    new_github="$val"

    prompt_input "Team name (optional)" "$default_team" val || return 1
    new_team="$val"

    local -a override_paths=()
    local -a override_values=()

    [[ "$new_profile" != "$default_profile" ]] && {
        override_paths+=("docker.default_profile")
        override_values+=("$new_profile")
    }
    [[ -n "$new_r_version" && "$new_r_version" != "$default_r_version" ]] && {
        override_paths+=("defaults.r_version")
        override_values+=("$new_r_version")
    }
    [[ -n "$new_github" && "$new_github" != "$default_github" ]] && {
        override_paths+=("github.account")
        override_values+=("$new_github")
    }
    [[ -n "$new_team" && "$new_team" != "$default_team" ]] && {
        override_paths+=("defaults.team_name")
        override_values+=("$new_team")
    }

    if [[ ${#override_paths[@]} -eq 0 ]]; then
        log_info "No project-level overrides (using user defaults)"
        return 0
    fi

    if [[ ! -f "$CONFIG_PROJECT" ]]; then
        cat > "$CONFIG_PROJECT" << 'EOF'
# Project-specific zzcollab configuration
# Overrides user config (~/.zzcollab/config.yaml)
# Commit this file to version control.
EOF
        log_debug "Created project config: $CONFIG_PROJECT"
    fi

    local i
    for i in "${!override_paths[@]}"; do
        yaml_set "$CONFIG_PROJECT" "${override_paths[$i]}" "${override_values[$i]}"
    done

    log_success "Project overrides written to: $CONFIG_PROJECT"
    return 0
}

#=============================================================================
# CONFIG INIT
#=============================================================================

config_init() {
    local interactive="${1:-false}"

    mkdir -p "$CONFIG_USER_DIR"

    if [[ -f "$CONFIG_USER" ]]; then
        if [[ "$interactive" == "true" ]]; then
            log_info "Editing existing configuration: $CONFIG_USER"
            load_config
            config_interactive_setup
            return 0
        else
            log_warn "Config exists: $CONFIG_USER"
            zzc_read -p "Overwrite? [y/N] " -n 1 -r; echo
            [[ $REPLY =~ ^[Yy]$ ]] || return 0
        fi
    fi

    _create_default_config
    _CONFIG_LOADED=""

    if [[ "$interactive" == "true" ]]; then
        config_interactive_setup
    else
        log_success "Created: $CONFIG_USER"
        log_info "Run 'zzcollab config init --interactive' for guided setup"
    fi
}

_write_config_skeleton() {
    local target="${1:-$CONFIG_USER}"
    local current_year
    current_year=$(date +%Y)

    cat > "$target" << EOF
# ZZCOLLAB Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
#
# This file stores your personal defaults for R package development.
# Values here are used unless overridden by CLI flags or project config.
#
# Run 'zzcollab config init --interactive' for guided setup.

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
  min_r_version: "4.1.0"      # Minimum R version (for native pipe)
  roxygen_version: "7.3.0"
  encoding: "UTF-8"
  vignette_builder: "knitr"

#=============================================================================
# CODE STYLE PREFERENCES
#=============================================================================
# Enforced by lintr and styler

style:
  line_length: 78
  use_native_pipe: true        # |> instead of %>%
  assignment: "arrow"          # <- instead of =

#=============================================================================
# DOCKER PREFERENCES
#=============================================================================

docker:
  default_profile: "analysis"
  registry: "docker.io"        # docker.io, ghcr.io

#=============================================================================
# GITHUB PREFERENCES
#=============================================================================

github:
  account: ""
  default_visibility: "private"
  default_branch: "main"

#=============================================================================
# LEGACY DEFAULTS (backward compatibility)
#=============================================================================

defaults:
  team_name: ""
  github_account: ""
  dockerhub_account: ""
  profile_name: "analysis"
  r_version: ""
  auto_github: false
  skip_confirmation: false
  with_examples: false
EOF
}

##############################################################################
# FUNCTION: _create_default_config
# PURPOSE:  Write a complete, commented config skeleton to the user config
#           path. Used when no config exists yet.
##############################################################################
_create_default_config() {
    _write_config_skeleton "$CONFIG_USER"
    log_success "Created default config: $CONFIG_USER"
}

##############################################################################
# FUNCTION: config_backfill_schema
# PURPOSE:  Bring an existing config file up to the current schema without
#           losing any values the user has already set. Older configs (and
#           hand-trimmed ones) may lack whole sections (author, license,
#           r_package, style, github). This deep-merges the current default
#           skeleton UNDER the existing file: missing keys gain their default
#           values and comments, while every value already present is kept.
# INPUTS:   $1 - config file (default: $CONFIG_USER)
# OUTPUTS:  Rewrites the file in place when a merge is needed; invalidates the
#           load_config memo so the next read reflects the new structure.
# RETURNS:  0 on success or when nothing to do; non-zero only on hard failure.
##############################################################################
config_backfill_schema() {
    local file="${1:-$CONFIG_USER}"

    # Absent file: nothing to back-fill, create a fresh one instead.
    if [[ ! -f "$file" ]]; then
        mkdir -p "$(dirname "$file")"
        _create_default_config
        _CONFIG_LOADED=""
        return 0
    fi

    _require_yq || return 0

    local tmp_skel tmp_merged
    tmp_skel=$(mktemp) || return 1
    tmp_merged=$(mktemp) || { rm -f "$tmp_skel"; return 1; }

    _write_config_skeleton "$tmp_skel"

    # Only merge when the file is genuinely missing one or more schema keys.
    # This keeps the operation idempotent: yq re-attaches the skeleton's head
    # comments on every merge, so an unconditional merge would accumulate
    # duplicate comment blocks across repeated `zzc init` runs.
    local leaf_query='.. | select(tag != "!!map" and tag != "!!seq") | path | join(".")'
    local file_set need_merge=false p
    file_set=" $(yq eval "$leaf_query" "$file" 2>/dev/null | tr '\n' ' ') "
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if [[ "$file_set" != *" $p "* ]]; then
            need_merge=true
            break
        fi
    done < <(yq eval "$leaf_query" "$tmp_skel" 2>/dev/null)

    if [[ "$need_merge" == "false" ]]; then
        rm -f "$tmp_skel" "$tmp_merged"
        return 0
    fi

    # Skeleton is fileIndex 0 (provides structure, comments, defaults); the
    # existing file is fileIndex 1 and wins on every conflict, so user values
    # are preserved and only missing keys are filled.
    if yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        "$tmp_skel" "$file" > "$tmp_merged" 2>/dev/null && [[ -s "$tmp_merged" ]]; then
        mv "$tmp_merged" "$file"
        _CONFIG_LOADED=""
    else
        rm -f "$tmp_merged"
    fi

    rm -f "$tmp_skel"
    return 0
}

#=============================================================================
# INTERACTIVE SETUP WIZARD
#=============================================================================

config_interactive_setup() {

    trap '_interactive_cleanup; return 0' INT

    local val
    local current_year
    local choice
    current_year=$(date +%Y)

    load_config

    clear

    if has_gum; then
        gum_header "ZZCOLLAB Configuration Setup"
        local gum_choice
        gum_choice=$(gum_choose "What would you like to do?" \
            "Review basic configuration values interactively" \
            "Change existing values" \
            "Edit advanced settings (R Package, Code Style, CI/CD)" \
            "Full setup (all sections)" \
            "Exit") || { _save_and_exit; return 0; }
        case "$gum_choice" in
            "Review basic"*)   _setup_missing_values ;;
            "Change existing"*) _setup_change_existing ;;
            "Edit advanced"*)  _setup_advanced ;;
            "Full setup"*)     _setup_full ;;
            "Exit")            return 0 ;;
            *)                 return 0 ;;
        esac
    else
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════════════╗"
        echo "║                    ZZCOLLAB Configuration Setup                          ║"
        echo "╠══════════════════════════════════════════════════════════════════════════╣"
        echo "║  Press Enter to accept defaults shown in [brackets].                     ║"
        echo "║  Type 'q' or press Ctrl-D at any time to exit and save progress.        ║"
        echo "╚══════════════════════════════════════════════════════════════════════════╝"
        echo ""

        echo "  What would you like to do?"
        echo ""
        echo "    1) Review basic configuration values interactively"
        echo "    2) Change existing values"
        echo "    3) Edit advanced settings (R Package, Code Style, CI/CD)"
        echo "    4) Full setup (all sections)"
        echo "    q) Exit"
        echo ""
        printf "  Choice [1]: "
        zzc_read -r choice || { _save_and_exit; return 0; }
        choice="${choice:-1}"

        case "$choice" in
            1) _setup_missing_values ;;
            2) _setup_change_existing ;;
            3) _setup_advanced ;;
            4) _setup_full ;;
            q|Q) return 0 ;;
            *) echo "Invalid choice"; return 1 ;;
        esac
    fi

    trap - INT

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                       Configuration Complete                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    log_success "Configuration saved to: $CONFIG_USER"
    echo ""
    echo "Quick commands:"
    echo "  zzcollab config list              # View all settings"
    echo "  zzcollab config set KEY VALUE     # Change a setting"
    echo "  zzcollab config get KEY           # Get a setting value"
    echo ""
}

_setup_missing_values() {
    local val
    local current_year
    current_year=$(date +%Y)
    local has_missing=false

    print_section "Complete Missing Values"
    echo "Only prompting for essential fields that are not yet set."
    echo ""

    if [[ -z "${CONFIG_AUTHOR_NAME:-}" ]]; then
        has_missing=true
        prompt_input "Full name" "" val || { _save_and_exit; return 0; }
        [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.name" "$val"
    fi

    if [[ -z "${CONFIG_AUTHOR_EMAIL:-}" ]]; then
        has_missing=true
        prompt_validated "Email address" "" val validate_email \
            "Invalid email format. Example: user@example.com" || { _save_and_exit; return 0; }
        [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.email" "$val"
    fi

    if [[ -z "${CONFIG_AUTHOR_AFFILIATION:-}" ]]; then
        has_missing=true
        prompt_input "Affiliation (short)" "" val || { _save_and_exit; return 0; }
        [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.affiliation" "$val"
    fi

    if [[ -z "${CONFIG_GITHUB_ACCOUNT:-}" ]]; then
        has_missing=true
        prompt_github_account "GitHub username" "" val || { _save_and_exit; return 0; }
        [[ -n "$val" ]] && {
            _set_github_account_yaml "$CONFIG_USER" "$val"
        }
    fi

    if [[ "$has_missing" == "false" ]]; then
        echo "  All essential fields are already set!"
        echo ""
        echo "  Use option 2 to change existing values, or"
        echo "  option 3 to edit advanced settings."
    fi
}

_setup_change_existing() {
    local val
    local current_year
    current_year=$(date +%Y)

    print_section "Author Information"
    echo "This information appears in DESCRIPTION, reports, and git commits."
    echo ""

    prompt_input "Full name" "${CONFIG_AUTHOR_NAME:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.name" "$val"

    prompt_validated "Email address" "${CONFIG_AUTHOR_EMAIL:-}" val validate_email \
        "Invalid email format. Example: user@example.com" || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.email" "$val"

    prompt_validated "ORCID (optional)" "${CONFIG_AUTHOR_ORCID:-}" val validate_orcid \
        "Invalid ORCID format. Expected: 0000-0000-0000-0000" || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.orcid" "$val"

    prompt_input "Affiliation (short)" "${CONFIG_AUTHOR_AFFILIATION:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.affiliation" "$val"

    prompt_input "Affiliation (full, for papers)" \
        "${CONFIG_AUTHOR_AFFILIATION_FULL:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "author.affiliation_full" "$val"

    print_section "License Preferences"
    echo "  GPL-3      - Copyleft, derivatives must be open source"
    echo "  MIT        - Permissive, minimal restrictions"
    echo "  Apache-2.0 - Permissive with patent protection"
    echo "  CC-BY-4.0  - For data and documentation"
    echo ""

    prompt_select "Default license" "GPL-3,MIT,Apache-2.0,CC-BY-4.0" \
        "${CONFIG_LICENSE_TYPE:-GPL-3}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "license.type" "$val"

    prompt_input "Copyright year" "${CONFIG_LICENSE_YEAR:-$current_year}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "license.year" "$val"

    print_section "Docker Preferences"
    echo "  minimal      - Essential R development (~650MB)"
    echo "  analysis     - Data analysis with tidyverse (~1.2GB) [RECOMMENDED]"
    echo "  rstudio      - RStudio Server IDE (~980MB)"
    echo ""

    prompt_select "Default profile" \
        "minimal,analysis,rstudio" \
        "${CONFIG_PROFILE_NAME:-analysis}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "defaults.profile_name" "$val"
    yaml_set "$CONFIG_USER" "docker.default_profile" "$val"

    prompt_select "Docker registry" "docker.io,ghcr.io,registry.gitlab.com" \
        "${CONFIG_DOCKER_REGISTRY:-docker.io}" val || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "docker.registry" "$val"

    print_section "GitHub Preferences"

    prompt_github_account "GitHub username" "${CONFIG_GITHUB_ACCOUNT:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && {
        _set_github_account_yaml "$CONFIG_USER" "$val"
    }

    prompt_select "Default repository visibility" "private,public" \
        "${CONFIG_GITHUB_DEFAULT_VISIBILITY:-private}" val || \
        { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "github.default_visibility" "$val"

    prompt_select "Default branch name" "main,master" \
        "${CONFIG_GITHUB_DEFAULT_BRANCH:-main}" val || \
        { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "github.default_branch" "$val"

    print_section "Team Defaults"

    prompt_input "Default team name" "${CONFIG_TEAM_NAME:-}" val || { _save_and_exit; return 0; }
    [[ -n "$val" ]] && yaml_set "$CONFIG_USER" "defaults.team_name" "$val"
}

_setup_advanced() {
    local val

    print_section "R Package Defaults (Advanced)"
    echo "Technical defaults for the DESCRIPTION file."
    echo ""

    prompt_validated "Minimum R version required" \
        "${CONFIG_RPACKAGE_MIN_R_VERSION:-4.1.0}" val \
        validate_r_version_lenient \
        "Invalid R version format. Expected: X.Y or X.Y.Z (e.g., 4.1 or 4.1.0)" \
        || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "r_package.min_r_version" "$val"

    prompt_select "Vignette builder" "knitr,quarto" \
        "${CONFIG_RPACKAGE_VIGNETTE_BUILDER:-knitr}" val || \
        { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "r_package.vignette_builder" "$val"

    print_section "Code Style Preferences (Advanced)"
    echo "These preferences guide code generation and linting."
    echo ""

    prompt_validated "Line length for wrapping" "${CONFIG_STYLE_LINE_LENGTH:-78}" val validate_positive_int \
        "Invalid value. Must be a positive integer (e.g., 78, 80, 120)" || { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "style.line_length" "$val"

    prompt_yesno "Use native pipe |> (requires R >= 4.1)" \
        "${CONFIG_STYLE_USE_NATIVE_PIPE:-true}" val || \
        { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "style.use_native_pipe" "$val"

    prompt_select "Assignment operator" "arrow,equals" \
        "${CONFIG_STYLE_ASSIGNMENT:-arrow}" val || \
        { _save_and_exit; return 0; }
    yaml_set "$CONFIG_USER" "style.assignment" "$val"
}

_setup_full() {
    _setup_change_existing
    _setup_advanced
}

_save_and_exit() {
    trap - INT
    echo ""
    echo ""
    log_warn "Configuration cancelled"
    log_info "Progress saved to: $CONFIG_USER"
    log_info "Run 'zzcollab config init --interactive' to continue"
}
