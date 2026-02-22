#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB DOCTOR MODULE
##############################################################################
#
# PURPOSE: Comprehensive workspace health checks
#          - Version stamps: Check Makefile, .Rprofile, Dockerfile versions
#          - Required files: Verify core files exist
#          - Directory structure: Check standard layout
#          - Supports batch scanning with --scan
#
# USAGE:
#   bash doctor.sh [DIR ...]
#   bash doctor.sh --scan <parent-dir>
#
# EXIT CODES:
#   0 - All checks passed
#   1 - One or more issues found
#
# REFERENCE: docs/workspace-structure.md
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
readonly COL_DIM='\033[2m'

#=============================================================================
# REQUIRED FILES AND DIRECTORIES
# Reference: docs/workspace-structure.md
#=============================================================================

# Required files (must exist for a valid workspace)
REQUIRED_FILES=(
    "DESCRIPTION"
    "renv.lock"
    ".Rprofile"
    "Makefile"
    "Dockerfile"
    ".gitignore"
)

# Required directories (must exist for a valid workspace)
REQUIRED_DIRS=(
    "R"
    "analysis"
)

# Optional but expected directories
OPTIONAL_DIRS=(
    "tests/testthat"
    "man"
    ".zzcollab"
)

# Required .gitignore entries
REQUIRED_GITIGNORE=(
    ".Rproj.user"
    ".Rhistory"
    ".RData"
    "renv/library/"
    "renv/staging/"
)

# Required .Rbuildignore entries (regex patterns)
REQUIRED_RBUILDIGNORE=(
    "^analysis"
    "^docs"
    "^\\.github"
    "^renv"
    "^Makefile"
    "^Dockerfile"
)

#=============================================================================
# VERSION EXTRACTION
#=============================================================================

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

# Extract zzcollab version stamp from markdown files (HTML comment format)
# Matches: <!-- zzcollab FILENAME.md vX.Y.Z -->
extract_md_version() {
    local file="$1"
    local label="$2"
    if [[ -f "$file" ]]; then
        sed -n "s/^<!-- zzcollab ${label} v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p" "$file" | head -1
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

#=============================================================================
# CHECK FUNCTIONS
#=============================================================================

# Check required files exist
# Returns number of missing files
check_required_files() {
    local dir="$1"
    local missing=0

    echo "  Required files:"
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ -f "$dir/$file" ]]; then
            printf "    %-20s ${COL_GREEN}✓${COL_RESET}\n" "$file"
        else
            printf "    %-20s ${COL_RED}✗ missing${COL_RESET}\n" "$file"
            missing=$((missing + 1))
        fi
    done

    return $missing
}

# Check required directories exist
# Returns number of missing directories
check_required_dirs() {
    local dir="$1"
    local missing=0

    echo "  Required directories:"
    for d in "${REQUIRED_DIRS[@]}"; do
        if [[ -d "$dir/$d" ]]; then
            printf "    %-20s ${COL_GREEN}✓${COL_RESET}\n" "$d/"
        else
            printf "    %-20s ${COL_RED}✗ missing${COL_RESET}\n" "$d/"
            missing=$((missing + 1))
        fi
    done

    # Optional directories (warnings only, don't affect exit code)
    local has_optional=false
    for d in "${OPTIONAL_DIRS[@]}"; do
        if [[ ! -d "$dir/$d" ]]; then
            if [[ "$has_optional" == false ]]; then
                echo "  Optional directories:"
                has_optional=true
            fi
            printf "    %-20s ${COL_YELLOW}○ not found${COL_RESET}\n" "$d/"
        fi
    done

    return $missing
}

# Check for misplaced files and directories
# Returns number of misplaced items
check_misplaced_files() {
    local dir="$1"
    local issues=0
    local has_header=false

    print_misplaced_header() {
        if [[ "$has_header" == false ]]; then
            echo "  Misplaced items:"
            has_header=true
        fi
    }

    # ZZCOLLAB_USER_GUIDE.md in root instead of docs/
    if [[ -f "$dir/ZZCOLLAB_USER_GUIDE.md" ]] && [[ ! -f "$dir/docs/ZZCOLLAB_USER_GUIDE.md" ]]; then
        print_misplaced_header
        printf "    %-20s ${COL_YELLOW}should be in docs/${COL_RESET}\n" "USER_GUIDE.md"
        issues=$((issues + 1))

        # Offer to move if interactive
        if [[ -t 0 ]]; then
            local move_choice
            read -r -p "    Move to docs/ZZCOLLAB_USER_GUIDE.md? [Y/n]: " move_choice
            if [[ ! "$move_choice" =~ ^[Nn]$ ]]; then
                mkdir -p "$dir/docs"
                if mv "$dir/ZZCOLLAB_USER_GUIDE.md" "$dir/docs/ZZCOLLAB_USER_GUIDE.md"; then
                    printf "    ${COL_GREEN}✓ Moved to docs/${COL_RESET}\n"
                    issues=$((issues - 1))
                else
                    printf "    ${COL_RED}✗ Failed to move${COL_RESET}\n"
                fi
            fi
        fi
    fi

    # archive/ should be one level up, not inside workspace
    if [[ -d "$dir/archive" ]]; then
        print_misplaced_header
        printf "    %-20s ${COL_YELLOW}should be at ../archive/${COL_RESET}\n" "archive/"
        issues=$((issues + 1))

        # Offer to move if interactive
        if [[ -t 0 ]]; then
            local parent_dir
            parent_dir="$(dirname "$dir")"
            local move_choice
            read -r -p "    Move to $parent_dir/archive/? [Y/n]: " move_choice
            if [[ ! "$move_choice" =~ ^[Nn]$ ]]; then
                if [[ -d "$parent_dir/archive" ]]; then
                    printf "    ${COL_RED}✗ ../archive/ already exists${COL_RESET}\n"
                elif mv "$dir/archive" "$parent_dir/archive"; then
                    printf "    ${COL_GREEN}✓ Moved to ../archive/${COL_RESET}\n"
                    issues=$((issues - 1))
                else
                    printf "    ${COL_RED}✗ Failed to move${COL_RESET}\n"
                fi
            fi
        fi
    fi

    if [[ "$has_header" == true ]]; then
        echo ""
    fi

    return $issues
}

# Check .gitignore and .Rbuildignore contain required entries
# Returns number of missing entries
check_ignore_files() {
    local dir="$1"
    local issues=0
    local missing_gitignore=()
    local missing_rbuildignore=()

    # Check .gitignore
    if [[ -f "$dir/.gitignore" ]]; then
        for entry in "${REQUIRED_GITIGNORE[@]}"; do
            if ! grep -qF "$entry" "$dir/.gitignore" 2>/dev/null; then
                missing_gitignore+=("$entry")
            fi
        done
    fi

    # Check .Rbuildignore
    if [[ -f "$dir/.Rbuildignore" ]]; then
        for entry in "${REQUIRED_RBUILDIGNORE[@]}"; do
            if ! grep -qF "$entry" "$dir/.Rbuildignore" 2>/dev/null; then
                missing_rbuildignore+=("$entry")
            fi
        done
    fi

    # Report missing entries
    if [[ ${#missing_gitignore[@]} -gt 0 ]] || [[ ${#missing_rbuildignore[@]} -gt 0 ]]; then
        echo "  Ignore file entries:"

        if [[ ${#missing_gitignore[@]} -gt 0 ]]; then
            printf "    .gitignore missing:\n"
            for entry in "${missing_gitignore[@]}"; do
                printf "      ${COL_YELLOW}- %s${COL_RESET}\n" "$entry"
                issues=$((issues + 1))
            done
        fi

        if [[ ${#missing_rbuildignore[@]} -gt 0 ]]; then
            printf "    .Rbuildignore missing:\n"
            for entry in "${missing_rbuildignore[@]}"; do
                printf "      ${COL_YELLOW}- %s${COL_RESET}\n" "$entry"
                issues=$((issues + 1))
            done
        fi

        # Offer to fix if interactive
        if [[ -t 0 ]] && [[ $issues -gt 0 ]]; then
            local fix_choice
            read -r -p "    Add missing entries? [Y/n]: " fix_choice
            if [[ ! "$fix_choice" =~ ^[Nn]$ ]]; then
                local fixed=0
                for entry in "${missing_gitignore[@]}"; do
                    echo "$entry" >> "$dir/.gitignore"
                    fixed=$((fixed + 1))
                done
                for entry in "${missing_rbuildignore[@]}"; do
                    echo "$entry" >> "$dir/.Rbuildignore"
                    fixed=$((fixed + 1))
                done
                printf "    ${COL_GREEN}✓ Added %d entries${COL_RESET}\n" "$fixed"
                issues=0
            fi
        fi
        echo ""
    fi

    return $issues
}

# Check version stamps in template files
# Returns number of outdated/unstamped files
check_version_stamps() {
    local dir="$1"
    local issues=0

    echo "  Version stamps:"

    # Makefile
    local makefile_ver
    makefile_ver=$(extract_version "$dir/Makefile" "Makefile")
    print_version_status "Makefile" "$makefile_ver" || issues=$((issues + 1))

    # .Rprofile
    local rprofile_ver
    rprofile_ver=$(extract_version "$dir/.Rprofile" ".Rprofile")
    print_version_status ".Rprofile" "$rprofile_ver" || issues=$((issues + 1))

    # Dockerfile
    local dockerfile_ver
    dockerfile_ver=$(extract_version "$dir/Dockerfile" "Dockerfile")
    print_version_status "Dockerfile" "$dockerfile_ver" || issues=$((issues + 1))

    # docs/ZZCOLLAB_USER_GUIDE.md
    if [[ -f "$dir/docs/ZZCOLLAB_USER_GUIDE.md" ]]; then
        local guide_ver
        guide_ver=$(extract_md_version "$dir/docs/ZZCOLLAB_USER_GUIDE.md" "ZZCOLLAB_USER_GUIDE.md")
        print_version_status "docs/USER_GUIDE.md" "$guide_ver" || issues=$((issues + 1))
    elif [[ -d "$dir/docs" ]]; then
        printf "    %-18s ${COL_YELLOW}missing${COL_RESET}\n" "docs/USER_GUIDE.md"
        issues=$((issues + 1))

        local template_guide="${ZZCOLLAB_TEMPLATES_DIR}/ZZCOLLAB_USER_GUIDE.md"
        if [[ -t 0 ]] && [[ -f "$template_guide" ]]; then
            local copy_choice
            read -r -p "    Copy from template? [Y/n]: " copy_choice
            if [[ ! "$copy_choice" =~ ^[Nn]$ ]]; then
                if cp "$template_guide" "$dir/docs/ZZCOLLAB_USER_GUIDE.md" && \
                   sed -i.bak "s/\\\$ZZCOLLAB_TEMPLATE_VERSION/${CURRENT_VERSION}/g" \
                       "$dir/docs/ZZCOLLAB_USER_GUIDE.md" && \
                   rm -f "$dir/docs/ZZCOLLAB_USER_GUIDE.md.bak"; then
                    printf "    ${COL_GREEN}✓ Copied user guide to docs/ (v%s)${COL_RESET}\n" \
                        "$CURRENT_VERSION"
                    issues=$((issues - 1))
                else
                    printf "    ${COL_RED}✗ Failed to copy${COL_RESET}\n"
                fi
            fi
        fi
    fi

    # .github/workflows/r-package.yml
    local workflow_file="$dir/.github/workflows/r-package.yml"
    if [[ -f "$workflow_file" ]]; then
        local workflow_ver
        workflow_ver=$(extract_version "$workflow_file" "r-package.yml")
        print_version_status "r-package.yml" "$workflow_ver" || issues=$((issues + 1))
    elif [[ -d "$dir/.github/workflows" ]]; then
        printf "    %-18s ${COL_YELLOW}missing${COL_RESET}\n" "r-package.yml"
        issues=$((issues + 1))

        local template_workflow="${ZZCOLLAB_TEMPLATES_DIR}/workflows/r-package.yml"
        if [[ -t 0 ]] && [[ -f "$template_workflow" ]]; then
            local copy_choice
            read -r -p "    Copy from template? [Y/n]: " copy_choice
            if [[ ! "$copy_choice" =~ ^[Nn]$ ]]; then
                if cp "$template_workflow" "$workflow_file" && \
                   sed -i.bak "s/\\\$ZZCOLLAB_TEMPLATE_VERSION/${CURRENT_VERSION}/g" \
                       "$workflow_file" && \
                   rm -f "$workflow_file.bak"; then
                    printf "    ${COL_GREEN}✓ Copied r-package.yml (v%s)${COL_RESET}\n" \
                        "$CURRENT_VERSION"
                    issues=$((issues - 1))
                else
                    printf "    ${COL_RED}✗ Failed to copy${COL_RESET}\n"
                fi
            fi
        fi
    fi

    # .Rprofile.local (owned by zzvim-R, informational only)
    if [[ -f "$dir/.Rprofile.local" ]]; then
        local rprofile_local_ver
        rprofile_local_ver=$(extract_zzvimr_version "$dir/.Rprofile.local")
        print_info_status ".Rprofile.local" "$rprofile_local_ver" "zzvim-R"
    fi

    return $issues
}

# Check CI workflow status via GitHub CLI
# Returns number of issues (0 = passing or not applicable, 1 = failing)
check_ci_status() {
    local dir="$1"
    local issues=0

    # Skip if no git repo or no gh CLI
    if ! command -v gh &>/dev/null; then
        return 0
    fi
    if [[ ! -d "$dir/.git" ]]; then
        return 0
    fi

    # Get repo from git remote
    local remote_url
    remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 0
    local repo
    repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
    [[ -n "$repo" ]] || return 0

    echo "  CI status:"

    # Query latest run on default branch
    local run_info
    run_info=$(gh run list --repo "$repo" --limit 1 --json status,conclusion,name,headBranch 2>/dev/null) || {
        printf "    %-18s ${COL_YELLOW}(gh auth required)${COL_RESET}\n" "GitHub Actions"
        return 0
    }

    # No runs at all
    if [[ "$run_info" == "[]" ]]; then
        printf "    %-18s ${COL_DIM}(no runs)${COL_RESET}\n" "GitHub Actions"
        return 0
    fi

    local conclusion status name branch
    conclusion=$(echo "$run_info" | sed -n 's/.*"conclusion":"\([^"]*\)".*/\1/p' | head -1)
    status=$(echo "$run_info" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -1)
    name=$(echo "$run_info" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)
    branch=$(echo "$run_info" | sed -n 's/.*"headBranch":"\([^"]*\)".*/\1/p' | head -1)

    local display_name="${name:-workflow}"
    [[ ${#display_name} -gt 18 ]] && display_name="${display_name:0:16}.."

    if [[ "$status" == "in_progress" || "$status" == "queued" ]]; then
        printf "    %-18s ${COL_YELLOW}(running)${COL_RESET} %s\n" "$display_name" "$branch"
    elif [[ "$conclusion" == "success" ]]; then
        printf "    %-18s ${COL_GREEN}passing${COL_RESET}  %s\n" "$display_name" "$branch"
    elif [[ "$conclusion" == "failure" ]]; then
        printf "    %-18s ${COL_RED}failing${COL_RESET}  %s\n" "$display_name" "$branch"
        issues=1
    elif [[ "$conclusion" == "cancelled" ]]; then
        printf "    %-18s ${COL_YELLOW}cancelled${COL_RESET} %s\n" "$display_name" "$branch"
    else
        printf "    %-18s ${COL_DIM}%s${COL_RESET}\n" "$display_name" "${conclusion:-unknown}"
    fi
    echo ""

    return $issues
}

# Check a single workspace directory
# Returns 0 if all checks pass, 1 if any issues found
check_workspace() {
    local dir="$1"
    local total_issues=0

    # Collapse home directory for display
    local display_dir="${dir/#$HOME/~}"
    printf "${COL_CYAN}Checking: %s${COL_RESET}\n\n" "$display_dir"

    # Check required files
    check_required_files "$dir"
    total_issues=$((total_issues + $?))
    echo ""

    # Check required directories
    check_required_dirs "$dir"
    total_issues=$((total_issues + $?))
    echo ""

    # Check for misplaced files
    check_misplaced_files "$dir"
    total_issues=$((total_issues + $?))

    # Check ignore file contents
    check_ignore_files "$dir"
    total_issues=$((total_issues + $?))

    # Check version stamps
    check_version_stamps "$dir"
    total_issues=$((total_issues + $?))
    echo ""

    # Check CI status
    check_ci_status "$dir"
    total_issues=$((total_issues + $?))

    # Summary
    if [[ $total_issues -eq 0 ]]; then
        printf "  ${COL_GREEN}All checks passed${COL_RESET}\n"
    else
        printf "  ${COL_RED}%d issue(s) found${COL_RESET}\n" "$total_issues"
    fi
    echo ""

    [[ $total_issues -eq 0 ]]
}

# Print version status line for a single file
# Returns 0 if current, 1 if outdated or no stamp
print_version_status() {
    local filename="$1"
    local found_ver="$2"

    if [[ -z "$found_ver" ]]; then
        printf "    %-18s ${COL_YELLOW}(no stamp)${COL_RESET}\n" "$filename"
        return 1
    elif [[ "$found_ver" == "$CURRENT_VERSION" ]]; then
        printf "    %-18s v%-10s ${COL_GREEN}(current)${COL_RESET}\n" "$filename" "$found_ver"
        return 0
    else
        printf "    %-18s ${COL_RED}v%-6s -> v%-6s (outdated)${COL_RESET}\n" \
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
        printf "    %-18s ${COL_YELLOW}(no stamp)${COL_RESET} ${COL_DIM}[%s]${COL_RESET}\n" \
            "$filename" "$owner"
    else
        printf "    %-18s v%-10s ${COL_DIM}(%s)${COL_RESET}\n" \
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
            help|--help|-h)
                echo "Usage: zzc doctor [DIR ...]"
                echo "       zzc doctor --scan <parent-dir>"
                echo ""
                echo "Workspace health checks:"
                echo "  - Required files    DESCRIPTION, renv.lock, Makefile, etc."
                echo "  - Directory layout  R/, analysis/"
                echo "  - Version stamps    Makefile, .Rprofile, Dockerfile"
                echo ""
                echo "Options:"
                echo "  DIR            One or more workspace directories (default: .)"
                echo "  --scan DIR     Recursively find all zzcollab workspaces"
                echo "  help           Show this help"
                echo ""
                echo "Reference: docs/workspace-structure.md"
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
