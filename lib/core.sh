#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CORE LIBRARY - FOUNDATION INFRASTRUCTURE
##############################################################################
#
# PURPOSE: Provides core infrastructure functions required by all other modules
#          This is the foundation library that must be loaded before others
#
# FEATURES:
#          - Unified logging system (log_info, log_error, log_success, log_warn)
#          - Package name validation and sanitization
#          - File safety utilities (safe_mkdir)
#          - Command availability caching
#          - Cross-platform compatibility helpers
#
# ARCHITECTURE: This library provides the basic building blocks that other
#               modules depend on. It establishes consistent patterns for
#               error handling, logging, and validation across the codebase.
#
# DEPENDENCIES: lib/constants.sh (optional, has fallbacks)
#
# NOTE: This file consolidates the former modules/core.sh and modules/utils.sh
##############################################################################

#=============================================================================
# CORE CONSTANTS (from original zzcollab.sh)
#=============================================================================

# Load centralized constants if available, otherwise use local constants
if [[ "${ZZCOLLAB_CONSTANTS_LOADED:-}" == "true" ]]; then
    AUTHOR_NAME="$ZZCOLLAB_AUTHOR_NAME"
    AUTHOR_EMAIL="$ZZCOLLAB_AUTHOR_EMAIL"
    readonly AUTHOR_INSTITUTE="$ZZCOLLAB_AUTHOR_INSTITUTE"
    readonly AUTHOR_INSTITUTE_FULL="$ZZCOLLAB_AUTHOR_INSTITUTE_FULL"
else
    AUTHOR_NAME="${ZZCOLLAB_AUTHOR_NAME:-Your Name}"
    AUTHOR_EMAIL="${ZZCOLLAB_AUTHOR_EMAIL:-your.email@example.com}"
    readonly AUTHOR_INSTITUTE="${ZZCOLLAB_INSTITUTE:-Your Institution}"
    readonly AUTHOR_INSTITUTE_FULL="${ZZCOLLAB_INSTITUTE_FULL:-Your Institution Full Name}"
fi

#=============================================================================
# LOGGING AND OUTPUT FUNCTIONS
#=============================================================================

# Verbosity levels:
#   0 = quiet (errors only)
#   1 = default (successes and errors) ~8 lines
#   2 = verbose (includes info messages) ~25 lines
#   3 = debug (everything) ~400 lines
export VERBOSITY_LEVEL="${VERBOSITY_LEVEL:-1}"

# Optional: Write all messages to log file regardless of verbosity
export LOG_FILE="${LOG_FILE:-.zzcollab.log}"
export ENABLE_LOG_FILE="${ENABLE_LOG_FILE:-false}"

##############################################################################
# FUNCTION: _write_to_log_file
# PURPOSE:  Write message to log file if enabled
# USAGE:    _write_to_log_file "level" "message"
##############################################################################
_write_to_log_file() {
    if [[ "$ENABLE_LOG_FILE" == "true" && -n "$LOG_FILE" ]]; then
        printf "[%s] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$LOG_FILE"
    fi
}

##############################################################################
# FUNCTION: log_debug
# PURPOSE:  Display detailed debug messages (only with -vv/--debug)
##############################################################################
log_debug() {
    _write_to_log_file "DEBUG" "$*"
    if [[ $VERBOSITY_LEVEL -ge 3 ]]; then
        printf "🔍 %s\n" "$*" >&2
    fi
}

##############################################################################
# FUNCTION: log_info
# PURPOSE:  Display informational messages (shown with -v or higher)
##############################################################################
log_info() {
    _write_to_log_file "INFO" "$*"
    if [[ $VERBOSITY_LEVEL -ge 2 ]]; then
        printf "ℹ️  %s\n" "$*" >&2
    fi
}

##############################################################################
# FUNCTION: log_warn
# PURPOSE:  Display warning messages (shown at default level and higher)
##############################################################################
log_warn() {
    _write_to_log_file "WARN" "$*"
    if [[ $VERBOSITY_LEVEL -ge 1 ]]; then
        printf "⚠️  %s\n" "$*" >&2
    fi
}

##############################################################################
# FUNCTION: log_error
# PURPOSE:  Display error messages (always shown, even in quiet mode)
##############################################################################
log_error() {
    _write_to_log_file "ERROR" "$*"
    printf "❌ %s\n" "$*" >&2
}

##############################################################################
# FUNCTION: log_success
# PURPOSE:  Display success messages (shown at default level and higher)
##############################################################################
log_success() {
    _write_to_log_file "SUCCESS" "$*"
    if [[ $VERBOSITY_LEVEL -ge 1 ]]; then
        printf "✅ %s\n" "$*" >&2
    fi
}

#=============================================================================
# SEMANTIC VERSION COMPARISON
#=============================================================================

##############################################################################
# FUNCTION: semver_cmp
# PURPOSE:  Compare two semver strings (X.Y.Z).
# USAGE:    semver_cmp <a> <b>
# RETURNS:  Echoes 0 if a == b, -1 if a < b, 1 if a > b.
##############################################################################
semver_cmp() {
    local a="$1" b="$2"
    [[ "$a" == "$b" ]] && { echo 0; return; }
    local smaller
    smaller=$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -1)
    [[ "$smaller" == "$a" ]] && echo -1 || echo 1
}

#=============================================================================
# PACKAGE NAME VALIDATION FUNCTIONS
#=============================================================================

##############################################################################
# FUNCTION: validate_package_name
# PURPOSE:  Converts name into a valid R package name
# USAGE:    validate_package_name [name]
#           If name not provided, uses current directory name
# RETURNS:  0 - Success, outputs valid package name to stdout
#           1 - Error, cannot create valid package name
##############################################################################
validate_package_name() {
    local dir_name
    if [[ $# -gt 0 ]]; then
        dir_name="$1"
    else
        dir_name=$(basename "$(pwd)")
    fi

    local pkg_name
    pkg_name=$(printf '%s' "$dir_name" | tr -cd '[:alnum:].' | head -c 50)

    if [[ -z "$pkg_name" ]]; then
        echo "❌ Error: Cannot determine valid package name from '$dir_name'" >&2
        return 1
    fi

    if [[ ! "$pkg_name" =~ ^[[:alpha:]] ]]; then
        echo "❌ Error: Package name must start with a letter: '$pkg_name'" >&2
        return 1
    fi

    printf '%s' "$pkg_name"
}

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Function: command_exists
# Purpose: Check if a command is available in the current PATH
# Usage: if command_exists docker; then ... fi
# Returns: 0 if command exists, 1 if not
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#=============================================================================
# FILE AND DIRECTORY OPERATIONS (from utils.sh)
#=============================================================================

# Function: safe_mkdir
# Purpose: Create directory with error handling and logging
# Arguments: $1 - directory path, $2 - description (optional)
safe_mkdir() {
    local dir="$1"
    local description="${2:-directory}"

    if mkdir -p "$dir" 2>/dev/null; then
        log_info "Created $description: $dir"
        return 0
    else
        log_error "Failed to create $description: $dir"
        return 1
    fi
}

# Function: safe_cp
# Purpose: Copy file avoiding macOS EDEADLK on cloud-synced filesystems
#          (Dropbox, iCloud). Dropbox locks existing file inodes, so we
#          remove the target first, then write a new file.
# Arguments: $1 - source path, $2 - destination path
safe_cp() {
    local src="$1" dest="$2"
    # Verify the source exists before removing the destination, so a missing
    # source cannot leave the destination deleted (and abort under set -e).
    if [[ ! -f "$src" ]]; then
        log_error "safe_cp: source not found: $src"
        return 1
    fi
    rm -f "$dest"
    cat "$src" > "$dest"
}


#=============================================================================
# DIRECTORY SAFETY GUARD
#=============================================================================

# Function: assert_safe_init_directory
# Purpose:  Prevent accidental zzc init in occupied directories (e.g. ~/prj).
#           Hard-stops when unexpected subdirectories exist; prompts when
#           many files are present. Bypassed with --force on cmd_init.
# Returns:  0 if safe to proceed, 1 if user cancels or directory is occupied.
assert_safe_init_directory() {
    local subdirs items
    subdirs=$(find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' | wc -l | tr -d ' ')
    items=$(find . -maxdepth 1 -mindepth 1 ! -name '.*' | wc -l | tr -d ' ')

    if [[ "$subdirs" -gt 1 ]]; then
        log_error "This directory has $subdirs existing subdirectories."
        log_error "zzc init is intended for new, empty project directories."
        log_error "Create a project subdirectory:  mkdir myproject && cd myproject"
        log_error "Override with:                  zzc init --force"
        return 1
    fi

    if [[ "$items" -gt 3 ]]; then
        # The soft prompt is a courtesy check, not the hard >1-subdir stop.
        # Under --yes/accept-defaults, proceed non-interactively; the hard stop
        # above still requires an explicit 'zzc init --force'.
        if [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
            log_warn "This directory has $items existing items; proceeding (--yes)."
        else
            log_warn "This directory has $items existing items."
            confirm "Run zzc init here?" || return 1
        fi
    fi

    return 0
}

# Function: zzc_read
# Purpose: Wrapper around `read` that skips the prompt when
#          ZZCOLLAB_ACCEPT_DEFAULTS=true, leaving variables empty
#          so that existing default-handling logic takes effect.
# Usage:   zzc_read -r -p "Prompt: " variable
zzc_read() {
    if [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
        REPLY=""
        local _args=("$@") _i=0 _prompt="" _newline=true
        while (( _i < ${#_args[@]} )); do
            case "${_args[_i]}" in
                -p)         _prompt="${_args[_i+1]:-}"
                            ((_i+=2)) ;;
                -n)         _newline=false
                            ((_i+=2)) ;;
                -[dtaiu])   ((_i+=2)) ;;
                -*)         ((_i+=1)) ;;
                *)          printf -v "${_args[_i]}" '%s' ""
                            ((_i+=1)) ;;
            esac
        done
        if [[ -n "$_prompt" ]]; then
            printf '%s(default)' "$_prompt" >&2
        else
            printf '(default)' >&2
        fi
        [[ "$_newline" == "true" ]] && printf '\n' >&2
        return 0
    fi
    read "$@"
}

# Function: confirm
# Purpose: Interactive confirmation prompt
# Arguments: $1 - prompt message (optional)
# Returns: 0 if user confirms (y/Y), 1 otherwise
confirm() {
    local prompt="${1:-Continue?}"
    zzc_read -p "$prompt [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

#=============================================================================
# SHARED VALIDATION FUNCTIONS
#=============================================================================

# Validate R version format.
#   --strict (default): requires X.Y.Z (e.g., 4.4.2)
#   --lenient: allows X.Y or X.Y.Z (e.g., 4.1 or 4.1.0)
# Empty input returns 1 in strict mode, 0 in lenient mode.
validate_r_version() {
    local strict=true
    if [[ "${1:-}" == "--lenient" ]]; then
        strict=false
        shift
    fi

    local version="$1"

    if [[ -z "$version" ]]; then
        if [[ "$strict" == "true" ]]; then
            log_error "R version cannot be empty"
            return 1
        fi
        return 0
    fi

    if [[ "$strict" == "true" ]]; then
        if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_error "Invalid R version: '$version'"
            log_error "Expected format: X.Y.Z (e.g., '4.3.1')"
            return 1
        fi
    else
        if ! [[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            log_error "Invalid R version: '$version'"
            log_error "Expected format: X.Y or X.Y.Z (e.g., '4.1' or '4.3.1')"
            return 1
        fi
    fi
    return 0
}

#=============================================================================
# GUM TUI WRAPPERS
#=============================================================================
# Thin wrappers around charmbracelet/gum for styled interactive prompts.
# Install: brew install gum
# All callers should guard with has_gum() and provide zzc_read fallbacks.

has_gum() { command -v gum >/dev/null 2>&1; }

# gum_header TEXT
# Renders a rounded-border styled section banner.
gum_header() {
    # Foreground 13 is the terminal palette's bright magenta (the 16-color
    # index, not a fixed 256-index), matching fzf's named 'bright-magenta' in
    # ZZCOLLAB_FZF_COLORS so both TUIs track the user's theme and read as one
    # UI. lipgloss takes the numeric index; fzf takes the name - same color.
    gum style --foreground 13 --border rounded --padding '0 1' --margin '0 0' "$1"
}

# Hint appended to every gum prompt header so the cancel key is discoverable.
# All gum wrappers return non-zero when the user presses Esc.
readonly ZZCOLLAB_GUM_ESC_HINT="(esc to exit)"

# _gum_header_with_hint HEADER
# Appends the esc-to-exit hint to a header, or returns the hint alone when the
# header is empty.
_gum_header_with_hint() {
    if [[ -n "$1" ]]; then
        printf '%s  %s' "$1" "$ZZCOLLAB_GUM_ESC_HINT"
    else
        printf '%s' "$ZZCOLLAB_GUM_ESC_HINT"
    fi
}

# gum_input PLACEHOLDER HEADER [DEFAULT]
# Prompts for freeform text. Writes result to stdout.
# Returns 1 if the user cancels (Ctrl-C / Esc).
gum_input() {
    local placeholder="$1" header="$2" default="${3:-}"
    local args=(gum input --placeholder "$placeholder" \
        --header "$(_gum_header_with_hint "$header")")
    [[ -n "$default" ]] && args+=(--value "$default")
    "${args[@]}"
}

# gum_choose HEADER ITEM...
# Presents a single-select list. Writes chosen item to stdout.
# Returns 1 if the user cancels.
gum_choose() {
    local header="$1"; shift
    gum choose --header "$(_gum_header_with_hint "$header")" "$@"
}

# gum_multichoose HEADER PRESELECTED_CSV OPTION...
# Multi-select checklist, pre-ticked to PRESELECTED_CSV (comma-separated subset
# of OPTION). Echoes the chosen options, one per line.
gum_multichoose() {
    local header="$1" selected="$2"; shift 2
    gum choose --no-limit --header "$(_gum_header_with_hint "$header")" \
        --selected="$selected" "$@"
}

# gum_confirm PROMPT
# Returns 0 for Yes, 1 for No or cancel.
gum_confirm() {
    gum confirm "$(_gum_header_with_hint "$1")"
}

#=============================================================================
# FZF TUI WRAPPERS
#=============================================================================
# fzf-driven single-select with a live preview pane: an "info box" to the right
# of the list that re-renders as the cursor moves between options. Used where
# per-option guidance helps the choice (e.g. the package backend). Callers must
# guard with has_fzf() and keep a gum/zzc_read fallback, exactly as the gum
# wrappers do. Install: brew install fzf

has_fzf() { command -v fzf >/dev/null 2>&1; }

# Pinned fzf theme, set explicitly on every invocation rather than inheriting
# the user's FZF_DEFAULT_OPTS, so the UI is consistent regardless of the
# caller's personal fzf configuration. Named ANSI colors (not 256-indexed) so
# the menu tracks the terminal's own 16-color palette: bright-magenta for the
# active accents (matching gum's accent), bright-black for chrome, bright-white
# for the current line.
readonly ZZCOLLAB_FZF_COLORS='pointer:bright-magenta,marker:bright-magenta,hl:bright-magenta,hl+:bright-magenta,fg+:bright-white,prompt:bright-magenta,header:bright-black,border:bright-black,preview-border:bright-black,gutter:-1'

# fzf_choose_preview HEADER INFO_DIR ITEM...
# Presents ITEMs as a single-select list with an info box on the right. For the
# highlighted ITEM the box shows the contents of "$INFO_DIR/<item>" - one file
# per item, named exactly as the item - which the caller writes before calling.
# Writes the chosen item to stdout; returns 1 if the user cancels (Esc). The
# first ITEM is highlighted initially, so callers list the default first.
fzf_choose_preview() {
    local header="$1" info_dir="$2"; shift 2
    printf '%s\n' "$@" | fzf \
        --height=14 --reverse --no-multi --no-info --cycle \
        --color="$ZZCOLLAB_FZF_COLORS" \
        --pointer='>' --prompt='> ' \
        --header="$header  (esc to cancel)" \
        --preview="cat -- '$info_dir'/{}" \
        --preview-window='right:62%:wrap:border-rounded'
}

# fzf_checklist_preview HEADER INFO_DIR STATE_FILE
# A multi-toggle checklist with a live info box. Unlike fzf's native
# multi-select (whose accept falls back to the cursor line when nothing is
# ticked - wrong for a checklist where "all off" is valid), checkbox state is
# kept in STATE_FILE, which the CALLER pre-populates and reads back. Each line
# of STATE_FILE is "<name> on|off"; tab/space toggles the highlighted item and
# Enter commits. INFO_DIR holds one info file per name (see fzf_choose_preview).
# Returns 0 when committed (read STATE_FILE for the result) or non-zero on Esc.
# The caller owns STATE_FILE and INFO_DIR; this function only edits STATE_FILE.
fzf_checklist_preview() {
    local header="$1" info_dir="$2" state="$3"
    local helper
    helper=$(mktemp -d "${TMPDIR:-/tmp}/zzc-fzfck.XXXXXX") || return 1
    # render: STATE_FILE -> tab-separated "[x]<TAB>name" lines for fzf input.
    cat > "$helper/render" <<'RENDER'
#!/usr/bin/env bash
while read -r name st; do
    if [[ "$st" == on ]]; then printf '[x]\t%s\n' "$name"
    else printf '[ ]\t%s\n' "$name"; fi
done < "$1"
RENDER
    # toggle: flip one name's state in place (atomic rename).
    cat > "$helper/toggle" <<'TOGGLE'
#!/usr/bin/env bash
sf="$1"; name="$2"; tmp="$sf.tmp"
while read -r n st; do
    [[ "$n" == "$name" ]] && { [[ "$st" == on ]] && st=off || st=on; }
    printf '%s %s\n' "$n" "$st"
done < "$sf" > "$tmp"
mv "$tmp" "$sf"
TOGGLE
    chmod +x "$helper/render" "$helper/toggle"
    local toggle_act="execute-silent(bash '$helper/toggle' '$state' {2})+reload(bash '$helper/render' '$state')"
    local rc=0
    # --track --id-nth=2 keeps the cursor on the same item across reloads even
    # though the checkbox field changes; {2} is the name field (tab-delimited).
    bash "$helper/render" "$state" | fzf \
        --height=16 --reverse --no-info --no-multi --cycle --track \
        --color="$ZZCOLLAB_FZF_COLORS" \
        --delimiter='\t' --with-nth='1,2' --id-nth='2' \
        --pointer='>' --prompt='> ' \
        --header="$header  (tab toggles, enter applies, esc cancels)" \
        --bind "tab:$toggle_act" \
        --bind "space:$toggle_act" \
        --preview="cat -- '$info_dir'/{2}" \
        --preview-window='right:58%:wrap:border-rounded' \
        >/dev/null || rc=$?
    rm -rf "$helper"
    return $rc
}

#=============================================================================
# CI FORGE DETECTION
#=============================================================================

# zzc_ci_forge [DIR]
# Which CI forge a project carries, by artifact presence:
#   .github/workflows/r-package.yml -> github
#   .gitlab-ci.yml                  -> gitlab
#   neither                         -> none
# A project uses a single forge; if both somehow exist, github wins. Shared by
# status, the toggle wizard, and doctor so the notion of "CI present" stays
# consistent across GitHub and GitLab.
zzc_ci_forge() {
    local d="${1:-.}"
    if [[ -f "$d/.github/workflows/r-package.yml" ]]; then
        echo github
    elif [[ -f "$d/.gitlab-ci.yml" ]]; then
        echo gitlab
    else
        echo none
    fi
}

#=============================================================================
# FORGE ACCOUNT HELPERS
#=============================================================================
# Forge-aware wrappers over the gh / glab CLIs, so account detection and
# existence checks have one implementation each. All degrade gracefully when
# the relevant CLI is absent. HOST applies to GitLab self-hosted instances
# (default gitlab.com); it is ignored for GitHub.

# forge_user FORGE [HOST]
# Echo the authenticated user's login/username for the forge, or nothing.
# Returns non-zero when the CLI is absent or the lookup fails.
forge_user() {
    local forge="$1" host="${2:-gitlab.com}" out
    case "$forge" in
        gitlab)
            command -v glab >/dev/null 2>&1 || return 1
            # glab api targets gitlab.com unless --hostname is given (it does
            # not read GITLAB_HOST), so pass the host explicitly for self-hosted.
            out=$(glab api user --hostname "$host" 2>/dev/null) || return 1
            [[ -n "$out" ]] || return 1
            if command -v jq >/dev/null 2>&1; then
                printf '%s' "$out" | jq -r '.username // empty' 2>/dev/null
            else
                printf '%s' "$out" | sed -n 's/.*"username"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
            fi
            ;;
        *)
            command -v gh >/dev/null 2>&1 || return 1
            gh api user --jq '.login' 2>/dev/null
            ;;
    esac
}

# forge_account_exists FORGE ACCOUNT [HOST]
# 0 = account exists, 1 = not found, 2 = cannot check (CLI absent or error).
# Callers typically accept the input on 2 (the historical gh behaviour).
forge_account_exists() {
    local forge="$1" account="$2" host="${3:-gitlab.com}" out
    case "$forge" in
        gitlab)
            command -v glab >/dev/null 2>&1 || return 2
            out=$(glab api "users?username=${account}" --hostname "$host" 2>/dev/null) || return 2
            [[ -n "$out" && "$out" != "[]" ]] && return 0 || return 1
            ;;
        *)
            command -v gh >/dev/null 2>&1 || return 2
            gh api "users/${account}" >/dev/null 2>&1 && return 0 || return 1
            ;;
    esac
}

#=============================================================================
# CORE LIBRARY VALIDATION
#=============================================================================

# Validate that this library is being sourced correctly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ Error: core.sh should be sourced, not executed directly" >&2
    exit 1
fi
