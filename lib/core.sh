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
    gum style --foreground 212 --border rounded --padding '0 1' --margin '0 0' "$1"
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
# CORE LIBRARY VALIDATION
#=============================================================================

# Validate that this library is being sourced correctly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ Error: core.sh should be sourced, not executed directly" >&2
    exit 1
fi
