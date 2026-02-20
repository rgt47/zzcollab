#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB CHECK-UPDATES MODULE
##############################################################################
#
# PURPOSE: Detect outdated zzcollab template files in workspaces
#          - Reads version stamps from Makefile, .Rprofile, Dockerfile
#          - Compares against current ZZCOLLAB_TEMPLATE_VERSION
#          - Reports outdated, current, or unstamped files
#          - Supports batch scanning with --scan
#
# USAGE:
#   bash check-updates.sh [DIR ...]
#   bash check-updates.sh --scan <parent-dir>
#
# EXIT CODES:
#   0 - All checked files are current
#   1 - One or more files are outdated or unstamped
##############################################################################

# Source constants if not already loaded
if [[ -z "${ZZCOLLAB_CONSTANTS_LOADED:-}" ]]; then
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_script_dir}/../lib/constants.sh"
    unset _script_dir
fi

CURRENT_VERSION="${ZZCOLLAB_TEMPLATE_VERSION}"

readonly COL_RESET='\033[0m'
readonly COL_GREEN='\033[0;32m'
readonly COL_YELLOW='\033[1;33m'
readonly COL_RED='\033[0;31m'
readonly COL_CYAN='\033[0;36m'

# Extract zzcollab version stamp from a file
# Usage: extract_version <file> <label>
#   where label is "Makefile", ".Rprofile", or "Dockerfile"
# Returns the version string (e.g., "2.1.0") or empty string
extract_version() {
    local file="$1"
    local label="$2"
    if [[ -f "$file" ]]; then
        sed -n "s/^# zzcollab ${label} v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p" "$file" | head -1
    fi
}

# Extract zzvim-R version stamp from .Rprofile.local
# Matches: # zzvim-R .Rprofile.local vX.Y.Z
extract_zzvimr_version() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sed -n 's/^# zzvim-R \.Rprofile\.local v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$file" | head -1
    fi
}

# Check a single workspace directory
# Returns 0 if all current, 1 if any outdated/unstamped
check_workspace() {
    local dir="$1"
    local any_outdated=0

    # Collapse home directory for display
    local display_dir="${dir/#$HOME/~}"
    printf "${COL_CYAN}Checking: %s${COL_RESET}\n" "$display_dir"

    # Makefile
    local makefile_ver
    makefile_ver=$(extract_version "$dir/Makefile" "Makefile")
    print_file_status "Makefile" "$makefile_ver" || any_outdated=1

    # .Rprofile
    local rprofile_ver
    rprofile_ver=$(extract_version "$dir/.Rprofile" ".Rprofile")
    print_file_status ".Rprofile" "$rprofile_ver" || any_outdated=1

    # Dockerfile
    local dockerfile_ver
    dockerfile_ver=$(extract_version "$dir/Dockerfile" "Dockerfile")
    print_file_status "Dockerfile" "$dockerfile_ver" || any_outdated=1

    # .Rprofile.local (owned by zzvim-R, informational only)
    if [[ -f "$dir/.Rprofile.local" ]]; then
        local rprofile_local_ver
        rprofile_local_ver=$(extract_zzvimr_version "$dir/.Rprofile.local")
        print_info_status ".Rprofile.local" "$rprofile_local_ver" "zzvim-R"
    fi

    echo ""
    return $any_outdated
}

# Print status line for a single file
# Returns 0 if current, 1 if outdated or no stamp
print_file_status() {
    local filename="$1"
    local found_ver="$2"

    if [[ -z "$found_ver" ]]; then
        printf "  %-14s %-30s ${COL_YELLOW}(no stamp)${COL_RESET}\n" \
            "$filename" ""
        return 1
    elif [[ "$found_ver" == "$CURRENT_VERSION" ]]; then
        printf "  %-14s v%-29s ${COL_GREEN}(current)${COL_RESET}\n" \
            "$filename" "$found_ver"
        return 0
    else
        printf "  %-14s ${COL_RED}v%-7s -> v%-19s${COL_RESET} ${COL_RED}(outdated)${COL_RESET}\n" \
            "$filename" "$found_ver" "$CURRENT_VERSION"
        return 1
    fi
}

# Print informational status for files owned by other tools
# Does not affect exit code (zzcollab cannot judge currency)
print_info_status() {
    local filename="$1"
    local found_ver="$2"
    local owner="$3"

    if [[ -z "$found_ver" ]]; then
        printf "  %-14s %-30s ${COL_YELLOW}(no stamp)${COL_RESET} [%s]\n" \
            "$filename" "" "$owner"
    else
        printf "  %-14s v%-29s ${COL_CYAN}(%s)${COL_RESET}\n" \
            "$filename" "$found_ver" "$owner"
    fi
}

# Scan a parent directory for zzcollab workspaces
scan_directory() {
    local parent="$1"
    local found=0
    local any_outdated=0

    if [[ ! -d "$parent" ]]; then
        echo "Error: directory not found: $parent" >&2
        return 1
    fi

    # Find directories containing a Makefile with a zzcollab stamp,
    # OR any Makefile alongside a Dockerfile (likely zzcollab workspace)
    while IFS= read -r makefile; do
        local workspace_dir
        workspace_dir="$(dirname "$makefile")"
        # Only check if it looks like a zzcollab workspace
        if grep -q "zzcollab" "$makefile" 2>/dev/null; then
            found=$((found + 1))
            check_workspace "$workspace_dir" || any_outdated=1
        fi
    done < <(find "$parent" -maxdepth 3 -name "Makefile" -type f 2>/dev/null)

    if [[ $found -eq 0 ]]; then
        echo "No zzcollab workspaces found under: $parent"
        return 0
    fi

    echo "---"
    echo "Scanned $found workspace(s), current template version: v${CURRENT_VERSION}"
    return $any_outdated
}

# Main entry point
main() {
    local scan_mode=false
    local dirs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scan)
                scan_mode=true
                shift
                if [[ $# -eq 0 ]]; then
                    echo "Error: --scan requires a directory argument" >&2
                    exit 1
                fi
                dirs+=("$1")
                shift
                ;;
            --help|-h)
                echo "Usage: zzc check-updates [DIR ...]"
                echo "       zzc check-updates --scan <parent-dir>"
                echo ""
                echo "Check zzcollab template files for version freshness."
                echo ""
                echo "Options:"
                echo "  DIR            One or more workspace directories (default: .)"
                echo "  --scan DIR     Recursively find and check all zzcollab workspaces"
                echo "  --help         Show this help"
                exit 0
                ;;
            *)
                dirs+=("$1")
                shift
                ;;
        esac
    done

    # Default to current directory
    if [[ ${#dirs[@]} -eq 0 ]]; then
        dirs=(".")
    fi

    echo "zzcollab template version: v${CURRENT_VERSION}"
    echo ""

    local exit_code=0

    if [[ "$scan_mode" == true ]]; then
        for dir in "${dirs[@]}"; do
            scan_directory "$(cd "$dir" && pwd)" || exit_code=1
        done
    else
        for dir in "${dirs[@]}"; do
            local abs_dir
            abs_dir="$(cd "$dir" && pwd)"
            check_workspace "$abs_dir" || exit_code=1
        done
    fi

    return $exit_code
}

main "$@"
