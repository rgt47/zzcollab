#!/bin/bash
##############################################################################
# ZZCOLLAB - DOCKER-BASED RESEARCH COLLABORATION FRAMEWORK
##############################################################################
# 
# PURPOSE: Creates reproducible research compendia with containerized workflows
#          - Modular architecture with 15 specialized shell modules
#          - Docker-first development with team collaboration support
#          - R package structure with automated testing and CI/CD
#          - Configuration system for user defaults and team settings
#          - Enterprise-grade dependency validation and environment management
#
# ARCHITECTURE:
#          Main Script (zzcollab.sh) 
#          ├── Module Loading (constants → core → cli → config → others)
#          ├── Command Processing (CLI argument parsing and validation)
#          ├── Workflow Execution (team init, individual setup, help system)
#          └── Cleanup and Exit (manifest tracking, error handling)
#
# USAGE:   ./zzcollab.sh [OPTIONS]
#          Examples:
#          ./zzcollab.sh -t myteam -p study -d ~/dotfiles       # Team lead setup
#          ./zzcollab.sh -t myteam -p study --use-team-image    # Team member join (pulls from Docker Hub)
#          ./zzcollab.sh --help                                 # Show all options
#          ./zzcollab.sh --config list                          # Configuration management
#
# DEPENDENCIES: Docker, Git, optional: GitHub CLI (gh), yq for config files
##############################################################################

# Bash strict mode: exit on errors, undefined variables, pipe failures
# -e: exit immediately if any command fails
# -u: exit if undefined variable is used  
# -o pipefail: exit if any command in pipeline fails
set -euo pipefail

#=============================================================================
# SCRIPT CONSTANTS AND DIRECTORY SETUP
#=============================================================================

# Determine script location using portable method
# ${BASH_SOURCE[0]} = full path to this script file
# dirname = extract directory path only
# cd + pwd = resolve to absolute path (handles symlinks)
# NOTE: These may be pre-set by wrapper script for installed version
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "${MODULES_DIR:-}" ]]; then
    readonly MODULES_DIR="$SCRIPT_DIR/modules"
fi

# Load centralized constants module first (provides global configuration)
# This module contains all color codes, paths, defaults, and system constants
if [[ -f "$MODULES_DIR/constants.sh" ]]; then
    # shellcheck source=modules/constants.sh
    source "$MODULES_DIR/constants.sh"
    
    # Use centralized constants from constants.sh module
    # These are defined in modules/constants.sh and provide consistent paths
    readonly TEMPLATES_DIR="$ZZCOLLAB_TEMPLATES_DIR"    # templates/ directory
    readonly MANIFEST_FILE="$ZZCOLLAB_MANIFEST_JSON"    # .zzcollab_manifest.json
    readonly MANIFEST_TXT="$ZZCOLLAB_MANIFEST_TXT"      # .zzcollab_manifest.txt
else
    # Fallback constants if constants module not available (backwards compatibility)
    # This should rarely happen in normal operation
    readonly TEMPLATES_DIR="$SCRIPT_DIR/templates"
    readonly MANIFEST_FILE=".zzcollab_manifest.json"
    readonly MANIFEST_TXT=".zzcollab_manifest.txt"
fi

#=============================================================================
# CLI MODULE LOADING AND ARGUMENT PROCESSING
#=============================================================================

# Load CLI module first (handles all command-line argument parsing)
# The CLI module must be loaded before other modules because it sets global variables
# that other modules depend on (like TEAM_NAME, PROJECT_NAME, PROFILE_NAME, etc.)
if [[ -f "$MODULES_DIR/cli.sh" ]]; then
    # shellcheck source=modules/cli.sh
    source "$MODULES_DIR/cli.sh"
else
    # If CLI module missing, we can't continue as we need argument parsing
    echo "❌ Error: CLI module not found: $MODULES_DIR/cli.sh" >&2
    exit 1
fi

# Process all command-line arguments passed to this script
# This function (from cli.sh) parses flags like -t, -p, --help, etc.
# and sets global variables that control script behavior
# "$@" passes all script arguments to the function
process_cli "$@"

#=============================================================================
# EARLY EXIT FOR HELP AND NEXT STEPS (before loading heavy modules)
#=============================================================================

# Handle discovery commands (--list-*) early to avoid loading all modules
if [[ "${LIST_PROFILES:-false}" == "true" ]] || [[ "${LIST_LIBS:-false}" == "true" ]] || [[ "${LIST_PKGS:-false}" == "true" ]]; then
    if [[ ! -f "${TEMPLATES_DIR}/bundles.yaml" ]]; then
        echo "❌ Error: Bundles file not found: ${TEMPLATES_DIR}/bundles.yaml" >&2
        exit 1
    fi

    if [[ "${LIST_PROFILES:-false}" == "true" ]]; then
        echo "Available Profiles:"
        echo ""
        yq eval '.profiles | to_entries | .[] | "  " + .key + " - " + .value.description + " (" + .value.size + ")"' \
            "${TEMPLATES_DIR}/bundles.yaml" 2>/dev/null
        echo ""
        echo "Usage: zzcollab --profile-name PROFILE"
        echo "Example: zzcollab --profile-name bioinformatics"
        exit 0
    fi

    if [[ "${LIST_LIBS:-false}" == "true" ]]; then
        echo "Available Library Bundles (System Dependencies):"
        echo ""
        yq eval '.library_bundles | to_entries | .[] |
            "  " + .key + " - " + .value.description + "\n    Packages: " + (.value.deps | join(", "))' \
            "${TEMPLATES_DIR}/bundles.yaml" 2>/dev/null
        echo ""
        echo "Usage: zzcollab --libs BUNDLE"
        echo "Example: zzcollab -b rocker/r-ver --libs geospatial"
        exit 0
    fi

    if [[ "${LIST_PKGS:-false}" == "true" ]]; then
        echo "Available Package Bundles (R Packages):"
        echo ""
        yq eval '.package_bundles | to_entries | .[] |
            "  " + .key + " - " + .value.description + "\n    Packages: " + (.value.packages | join(", "))' \
            "${TEMPLATES_DIR}/bundles.yaml" 2>/dev/null
        echo ""
        echo "Usage: zzcollab --pkgs BUNDLE"
        echo "Example: zzcollab -b rocker/r-ver --pkgs modeling"
        exit 0
    fi
fi

# For regular help and next-steps, we can show immediately
if [[ "${SHOW_HELP:-false}" == "true" ]] || [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
    # Load core module first (required by help module)
    if [[ -f "$MODULES_DIR/core.sh" ]]; then
        source "$MODULES_DIR/core.sh" >/dev/null 2>&1
    fi

    # Load help module
    if [[ -f "$MODULES_DIR/help.sh" ]]; then
        source "$MODULES_DIR/help.sh" >/dev/null 2>&1

        if [[ "${SHOW_HELP:-false}" == "true" ]]; then
            show_help
            exit 0
        fi

        if [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
            show_next_steps
            exit 0
        fi
    fi
fi

# Handle config commands
if [[ "${CONFIG_COMMAND:-false}" == "true" ]]; then
    # Load core module first
    if [[ -f "$MODULES_DIR/core.sh" ]]; then
        source "$MODULES_DIR/core.sh" >/dev/null 2>&1
    fi

    # Load config module
    if [[ -f "$MODULES_DIR/config.sh" ]]; then
        source "$MODULES_DIR/config.sh" >/dev/null 2>&1

        # Initialize config system to load configuration files
        init_config_system

        # Call handle_config_command with subcommand and args
        if [[ ${#CONFIG_ARGS[@]} -gt 0 ]]; then
            handle_config_command "${CONFIG_SUBCOMMAND}" "${CONFIG_ARGS[@]}"
        else
            handle_config_command "${CONFIG_SUBCOMMAND}"
        fi
        exit $?
    else
        echo "❌ Error: Config module not found" >&2
        exit 1
    fi
fi

#=============================================================================
# MODULE LOADING SYSTEM
#=============================================================================

# Temporary bootstrap logging functions (BEFORE core.sh loads)
# These will be REDEFINED by core.sh with full functionality after it loads
# This allows logging during the module loading phase before core.sh is available
# Note: This is intentional duplication - not a bug
log_info() { printf "ℹ️  %s\n" "$*" >&2; }
log_error() { printf "❌ %s\n" "$*" >&2; }
log_debug() { : ; }  # No-op during bootstrap (will be redefined by core.sh)

# Validate modules directory exists
if [[ ! -d "$MODULES_DIR" ]]; then
    log_error "Modules directory not found: $MODULES_DIR"
    log_error "Please ensure you're running this script from the zzcollab directory"
    exit 1
fi

# Function: load_module
# Purpose: Unified module loading with consistent error handling
# Arguments: $1 - module name, $2 - required (true/false), $3 - post-load function (optional)
load_module() {
    local module="$1"
    local required="${2:-true}"
    local post_load_func="${3:-}"
    
    if [[ -f "$MODULES_DIR/${module}.sh" ]]; then
        log_debug "Loading ${module} module..."
        # shellcheck source=/dev/null
        source "$MODULES_DIR/${module}.sh"
        
        # Run post-load function if specified
        if [[ -n "$post_load_func" && "$(type -t "$post_load_func")" == "function" ]]; then
            "$post_load_func"
        fi
    else
        if [[ "$required" == "true" ]]; then
            log_error "${module^} module not found: $MODULES_DIR/${module}.sh"
            exit 1
        else
            log_info "${module^} module not found - using defaults"
        fi
    fi
}

# Load modules in dependency order
log_debug "Loading all zzcollab modules..."

# Load core module first (required by all others)
load_module "core" "true"

# Load config module (depends on core, provides defaults for CLI)
load_module "config" "false" "init_config_system"

# Load essential modules (depends on core)
load_module "templates" "true"
load_module "utils" "true"
load_module "structure" "true"

#=============================================================================
# PACKAGE NAME VALIDATION (must be done before rpackage module)
#=============================================================================

# Validate package name using extracted function
PKG_NAME=$(validate_package_name)
readonly PKG_NAME

# Check if user specified redundant project name
if [[ -n "${PROJECT_NAME:-}" ]] && [[ "$PROJECT_NAME" == "$PKG_NAME" ]]; then
    log_info "💡 Project name '$PROJECT_NAME' matches directory name - you can omit -p flag"
fi

# Export variables for template substitution
USERNAME="${USERNAME:-analyst}"  # Default Docker user
export PKG_NAME AUTHOR_NAME AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE USERNAME

log_info "Package name determined: $PKG_NAME"

# Load remaining modules that depend on PKG_NAME being set
modules_to_load=("rpackage" "docker" "analysis" "cicd" "devtools" "help" "help_guides" "github" "profile_validation")

for module in "${modules_to_load[@]}"; do
    load_module "$module" "true"
done

#=============================================================================
# HELP AND NEXT STEPS (extracted to modules/help.sh)
#=============================================================================

# Help functions now loaded from modules/help.sh:
# - show_help()
# - show_init_help() 
# - show_next_steps()

# GitHub functions now in modules/github.sh

#=============================================================================
# MANIFEST INITIALIZATION
#=============================================================================

init_manifest() {
    if [[ "$JQ_AVAILABLE" == "true" ]]; then
        cat > "$MANIFEST_FILE" <<EOF
{
  "version": "1.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_name": "$PKG_NAME",
  "modules_loaded": ["core", "templates", "structure", "rpackage", "docker", "analysis", "cicd", "devtools"],
  "command_line_options": {
    "build_docker": $BUILD_DOCKER,
    "dotfiles_dir": "${DOTFILES_DIR}",
    "dotfiles_nodot": $DOTFILES_NODOT,
    "base_image": "$BASE_IMAGE"
  },
  "directories": [],
  "files": [],
  "template_files": [],
  "symlinks": [],
  "dotfiles": [],
  "docker_image": null
}
EOF
        log_success "Initialized JSON manifest file: $MANIFEST_FILE"
    else
        {
            echo "# ZZCOLLAB MANIFEST - Created $(date)"
            echo "# Package: $PKG_NAME"
            echo "# Modules: core, templates, structure, rpackage, docker, analysis, cicd, devtools"
            echo "# Build Docker: $BUILD_DOCKER"
            echo "# Dotfiles: $DOTFILES_DIR"
            echo "# Base Image: $BASE_IMAGE"
            echo "# Format: type:path"
        } > "$MANIFEST_TXT"
        log_success "Initialized text manifest file: $MANIFEST_TXT (jq not available)"
    fi
}

install_uninstall_script() {
    local uninstall_script="zzcollab-uninstall.sh"
    if [[ -f "$TEMPLATES_DIR/$uninstall_script" ]]; then
        cp "$TEMPLATES_DIR/$uninstall_script" "./$uninstall_script"
        chmod +x "./$uninstall_script"
        track_file "$uninstall_script"
        log_success "Uninstall script installed: ./$uninstall_script"
    else
        log_warning "Uninstall script template not found"
    fi
}

#=============================================================================
# DIRECTORY VALIDATION FUNCTIONS
#=============================================================================

# Function: get_zzcollab_files
# Purpose: Get list of files and directories that zzcollab creates
get_zzcollab_files() {
    local files=(
        # Core project files
        "DESCRIPTION" "NAMESPACE" "Makefile" ".gitignore" ".Rprofile" 
        "renv.lock" "setup_renv.R" "LICENSE"
        
        # Docker files
        "Dockerfile" "docker-compose.yml" "Dockerfile.teamcore" "Dockerfile.personal"
        ".zshrc_docker"
        
        # Documentation and guides
        "ZZCOLLAB_USER_GUIDE.md" "check_renv_for_commit.R"
        
        # Configuration files
        "zzcollab.yaml" "config.yaml" "dev.sh"
        
        # R project file (dynamic based on package name)
        "${PKG_NAME}.Rproj"
    )
    
    local directories=(
        # R package structure
        "R" "tests" "tests/testthat" "tests/integration" "data" "data/raw_data"
        "inst" "man" "vignettes"
        
        # Analysis structure  
        "analysis" "analysis/report" "analysis/templates" "scripts"
        "figures" "output"
        
        # Development and CI
        ".github" ".github/workflows" ".github/ISSUE_TEMPLATE"
        
        # renv
        "renv"
    )
    
    printf '%s\n' "${files[@]}" "${directories[@]}"
}

# Function: detect_file_conflicts
# Purpose: Check for actual file conflicts between existing files and zzcollab files
detect_file_conflicts() {
    local conflicts=()
    local zzcollab_files

    # Check if this is a team setup directory awaiting full project setup
    local is_team_setup_dir=false
    if [[ -f ".zzcollab_team_setup" ]]; then
        if grep -q "full_project_setup_needed=true" .zzcollab_team_setup 2>/dev/null; then
            is_team_setup_dir=true
        fi
    fi

    # Get list of files that zzcollab would create
    # Using while read loop for broader shell compatibility instead of mapfile
    local file
    zzcollab_files=()
    while IFS= read -r file; do
        zzcollab_files+=("$file")
    done < <(get_zzcollab_files)

    # Check for existing files that would conflict
    for item in "${zzcollab_files[@]}"; do
        if [[ -f "$item" ]]; then
            # Skip expected files from team setup
            if [[ "$is_team_setup_dir" == "true" ]]; then
                case "$item" in
                    DESCRIPTION|Dockerfile.teamcore|.zshrc_docker|config.yaml|profiles.yaml)
                        # These are expected from team initialization - not conflicts
                        continue
                        ;;
                esac
            fi
            # Files are always conflicts (zzcollab would skip them)
            conflicts+=("$item")
        elif [[ -d "$item" ]]; then
            # For directories, only report as conflict if they contain files
            # that would interfere with zzcollab's expected structure
            if [[ "$item" == ".github" ]] || [[ "$item" == ".github/workflows" ]] || [[ "$item" == ".github/ISSUE_TEMPLATE" ]]; then
                # These are standard zzcollab directories - not conflicts if empty
                # Only conflict if they contain files zzcollab would create
                local has_conflict=false
                case "$item" in
                    ".github/workflows")
                        # Check for specific workflow files zzcollab creates
                        if [[ -f ".github/workflows/r-package.yml" ]] || [[ -f ".github/workflows/render-report.yml" ]]; then
                            has_conflict=true
                        fi
                        ;;
                    ".github")
                        # Check for PR template or other GitHub files zzcollab creates
                        if [[ -f ".github/pull_request_template.md" ]]; then
                            has_conflict=true
                        fi
                        ;;
                esac
                if [[ "$has_conflict" == "true" ]]; then
                    conflicts+=("$item")
                fi
            else
                # For other directories, consider them conflicts if they exist
                conflicts+=("$item")
            fi
        fi
    done
    
    # Return conflicts (safe handling of empty array)
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        printf '%s\n' "${conflicts[@]}"
    fi
}

# Function: confirm_overwrite_conflicts
# Purpose: Ask user about overwriting conflicting files
confirm_overwrite_conflicts() {
    local conflicts
    # Using while read loop for broader shell compatibility instead of mapfile
    conflicts=()
    local conflict
    while IFS= read -r conflict; do
        [[ -n "$conflict" ]] && conflicts+=("$conflict")
    done < <(detect_file_conflicts)
    
    if [[ ${#conflicts[@]} -eq 0 ]]; then
        log_debug "✅ No file conflicts detected - safe to proceed"
        return 0
    fi
    
    echo ""
    log_warning "⚠️  FILE CONFLICT DETECTION:"
    log_warning "Found ${#conflicts[@]} existing files/directories that zzcollab would modify:"
    echo ""
    
    for conflict in "${conflicts[@]}"; do
        if [[ -f "$conflict" ]]; then
            echo "  📄 $conflict (file)"
        elif [[ -d "$conflict" ]]; then
            echo "  📁 $conflict (directory)"
        fi
    done
    
    echo ""
    log_info "ℹ️  What happens with conflicts:"
    log_info "  • Files: zzcollab skips existing files (won't overwrite your work)"
    log_info "  • Directories: zzcollab adds to existing directories (safe)"
    log_info "  • Only new zzcollab files will be created"
    echo ""
    
    read -p "Continue with setup? Existing files will be preserved [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Setup cancelled by user"
        exit 0
    fi
    
    log_debug "✅ Proceeding with setup - existing files will be preserved"
    return 0
}

# Function: validate_directory_for_setup
# Purpose: Prevent accidental zzcollab runs while allowing parameter updates in existing projects
# 
# Safety Features:
# 1. Detects existing zzcollab projects (allows parameter changes)
# 2. Warns about directories with many files (prevents accidents)
# 3. Provides --force flag for advanced users
# 4. Shows helpful guidance for safe usage
#
# Project Detection:
# - Looks for .zzcollab_manifest.json or .zzcollab_manifest.txt
# - Checks for R package structure (DESCRIPTION + R/ + analysis/)
# - Allows updates like changing base images, build modes, etc.
validate_directory_for_setup() {
    local current_dir
    current_dir=$(basename "$PWD")
    
    # Skip all directory validation if --force is used (advanced users)
    if [[ "${FORCE_DIRECTORY:-false}" == "true" ]]; then
        log_warning "⚠️  Directory validation skipped due to --force flag"
        log_info "Proceeding with setup in current directory: $PWD"
        return 0
    fi
    
    # Check if this is an existing zzcollab project (allow parameter updates)
    if [[ -f ".zzcollab_manifest.json" ]] || [[ -f ".zzcollab_manifest.txt" ]] || [[ -f "DESCRIPTION" && -d "R" && -d "analysis" ]]; then
        log_debug "✅ Detected existing zzcollab project - allowing parameter updates"
        log_info "You can safely run zzcollab here to modify build settings, base images, etc."
        return 0
    fi
    
    # Check if this is a directory where team initialization was completed (common workflow)
    if [[ -f ".zzcollab_team_setup" ]]; then
        log_info "✅ Detected directory with completed team initialization"
        log_info "Proceeding with full project setup (this is the intended workflow after -i)"
        return 0
    fi
    
    # Critical protection: Never allow installation in home directory
    if [[ "$PWD" == "$HOME" ]]; then
        log_error "🚫 CRITICAL SAFETY CHECK FAILED:"
        log_error "Cannot run zzcollab in your home directory ($HOME)"
        log_error "This would clutter your home directory with project files"
        echo ""
        log_info "💡 RECOMMENDED ACTIONS:"
        log_info "  1. Create a projects directory: mkdir ~/projects && cd ~/projects"
        log_info "  2. Create a specific project directory: mkdir ~/my-analysis && cd ~/my-analysis"
        log_info "  3. Use a dedicated workspace: cd /path/to/your/workspace"
        echo ""
        log_info "Then run zzcollab in the appropriate project directory"
        exit 1
    fi
    
    # Critical protection: Common problematic directories
    local problematic_dirs=("/Users" "/home" "/root" "/tmp" "/var" "/usr" "/opt" "/etc")
    for dir in "${problematic_dirs[@]}"; do
        if [[ "$PWD" == "$dir" ]]; then
            log_error "🚫 CRITICAL SAFETY CHECK FAILED:"
            log_error "Cannot run zzcollab in system directory: $PWD"
            log_error "This could damage your system or create security issues"
            exit 1
        fi
    done
    
    # Skip validation for certain directories that are expected to be non-empty
    if [[ "$current_dir" == "zzcollab" ]]; then
        log_warning "Running zzcollab setup in the zzcollab source directory"
        log_warning "This will create project files alongside the zzcollab source code"
        read -p "Are you sure you want to continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
        return 0
    fi
    
    # Use intelligent conflict detection instead of generic file count
    confirm_overwrite_conflicts
    return 0
}

# Function: validate_directory_for_setup_no_conflicts
# Purpose: Same as validate_directory_for_setup but without conflict detection
# Used when conflict detection has already been performed separately
validate_directory_for_setup_no_conflicts() {
    local current_dir
    current_dir=$(basename "$PWD")

    # Skip all directory validation if --force is used (advanced users)
    if [[ "${FORCE_DIRECTORY:-false}" == "true" ]]; then
        log_warning "⚠️  Directory validation skipped due to --force flag"
        log_info "Proceeding with setup in current directory: $PWD"
        return 0
    fi

    # Check if this is an existing zzcollab project (allow parameter updates)
    if [[ -f ".zzcollab_manifest.json" ]] || [[ -f ".zzcollab_manifest.txt" ]] || [[ -f "DESCRIPTION" && -d "R" && -d "analysis" ]]; then
        log_debug "✅ Detected existing zzcollab project - allowing parameter updates"
        log_info "You can safely run zzcollab here to modify build settings, base images, etc."
        return 0
    fi

    # Check if this is a directory where team initialization was completed (common workflow)
    if [[ -f ".zzcollab_team_setup" ]]; then
        log_info "✅ Detected directory with completed team initialization"
        log_info "Proceeding with full project setup (this is the intended workflow after -i)"
        return 0
    fi

    # Critical protection: Never allow installation in home directory
    if [[ "$PWD" == "$HOME" ]]; then
        log_error "🚫 CRITICAL SAFETY CHECK FAILED:"
        log_error "Cannot run zzcollab in your home directory ($HOME)"
        log_error "This would clutter your home directory with project files"
        echo ""
        log_info "💡 RECOMMENDED ACTIONS:"
        log_info "  1. Create a projects directory: mkdir ~/projects && cd ~/projects"
        log_info "  2. Create a specific project directory: mkdir ~/my-analysis && cd ~/my-analysis"
        log_info "  3. Use a dedicated workspace: cd /path/to/your/workspace"
        echo ""
        log_info "Then run zzcollab in the appropriate project directory"
        exit 1
    fi

    # Critical protection: Common problematic directories
    local problematic_dirs=("/Users" "/home" "/root" "/tmp" "/var" "/usr" "/opt" "/etc")
    for dir in "${problematic_dirs[@]}"; do
        if [[ "$PWD" == "$dir" ]]; then
            log_error "🚫 CRITICAL SAFETY CHECK FAILED:"
            log_error "Cannot run zzcollab in system directory: $PWD"
            log_error "This could damage your system or create security issues"
            exit 1
        fi
    done

    # Skip validation for certain directories that are expected to be non-empty
    if [[ "$current_dir" == "zzcollab" ]]; then
        log_warning "Running zzcollab setup in the zzcollab source directory"
        log_warning "This will create project files alongside the zzcollab source code"
        read -p "Are you sure you want to continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
        return 0
    fi

    # Note: conflict detection removed - assumed to have been performed separately
    log_debug "✅ Directory validation passed"
    return 0
}

#=============================================================================
# MAIN EXECUTION HELPER FUNCTIONS
#=============================================================================

# Function: handle_special_modes
# Purpose: Handle init, build profile, help modes that exit early
# Note: --list-* flags are handled earlier (lines 98-138) before modules are loaded
handle_special_modes() {
    # Handle help and next-steps options for normal mode
    if [[ "${SHOW_HELP:-false}" == "true" ]]; then
        # Check if a specific topic was requested
        case "${SHOW_HELP_TOPIC}" in
            init)
                show_init_help
                ;;
            github)
                show_github_help
                ;;
            quickstart)
                show_quickstart_help
                ;;
            workflow)
                show_workflow_help
                ;;
            troubleshooting)
                show_troubleshooting_help
                ;;
            config)
                show_config_help
                ;;
            dotfiles)
                show_dotfiles_help
                ;;
            renv)
                show_renv_help
                ;;
            docker)
                show_docker_help
                ;;
            cicd)
                show_cicd_help
                ;;
            "")
                # No topic specified, show general help
                show_help
                ;;
            *)
                echo "❌ Error: Unknown help topic '$SHOW_HELP_TOPIC'" >&2
                echo "Valid topics: init, github, quickstart, workflow, troubleshooting," >&2
                echo "              config, dotfiles, renv, docker, cicd" >&2
                exit 1
                ;;
        esac
        exit 0
    fi

    if [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
        show_next_steps
        exit 0
    fi
}

# Function: validate_and_setup_environment
# Purpose: Validate prerequisites and setup environment
validate_and_setup_environment() {
    # Concise startup message at default verbosity
    if [[ $VERBOSITY_LEVEL -eq 1 ]]; then
        echo "Creating project '$PKG_NAME'..." >&2
    fi

    # Detailed messages only in verbose/debug mode
    log_info "🚀 Starting modular rrtools project setup..."
    log_info "📦 Package name: '$PKG_NAME'"
    log_debug "🔧 All modules loaded successfully"
    echo ""

    # Foundation detection: Dockerfile presence determines mode
    # If Dockerfile exists → Team member mode (or lead working on analysis)
    # If Dockerfile absent → Team lead mode (creating foundation)
    if [[ -f "Dockerfile" ]]; then
        # Team member mode (or lead working on analysis)
        log_debug "✅ Detected existing Dockerfile - using existing foundation"

        # Block foundation-changing flags (foundation is locked)
        if [[ "${USER_PROVIDED_PROFILE:-false}" == "true" ]]; then
            log_error "❌ Cannot use --profile-name: Dockerfile already defines foundation"
            log_error "   To change foundation: rm Dockerfile && zzcollab --profile-name NEW_PROFILE"
            exit 1
        fi

        if [[ "${USER_PROVIDED_BASE_IMAGE:-false}" == "true" ]]; then
            log_error "❌ Cannot use -b/--base-image: Dockerfile already defines foundation"
            log_error "   To change foundation: rm Dockerfile && zzcollab -b NEW_IMAGE"
            exit 1
        fi

        if [[ "${USER_PROVIDED_LIBS:-false}" == "true" ]]; then
            log_error "❌ Cannot use --libs: Dockerfile already defines foundation"
            log_error "   To change foundation: rm Dockerfile && zzcollab --libs NEW_BUNDLE"
            exit 1
        fi

        if [[ "${USER_PROVIDED_PKGS:-false}" == "true" ]]; then
            log_error "❌ Cannot use --pkgs: Dockerfile already defines foundation"
            log_error "   To change foundation: rm Dockerfile && zzcollab --pkgs NEW_BUNDLE"
            exit 1
        fi

        # If --use-team-image, we'll configure Makefile for team image pulling
        if [[ "${USE_TEAM_IMAGE:-false}" == "true" ]]; then
            log_info "🐳 Will configure Makefile to pull and use team image from Docker Hub"
        fi
    else
        # Team lead mode (creating foundation)
        log_info "📝 No Dockerfile found - will create new foundation"
    fi

    # Profile system validation (new)
    # Expand profile if --profile-name was specified
    # OR use default profile (minimal) if only --pkgs was provided
    # OR use default profile (minimal) if no arguments provided
    if [[ -n "${PROFILE_NAME:-}" ]]; then
        expand_profile_name "$PROFILE_NAME"
    elif [[ "${USER_PROVIDED_PKGS:-false}" == "true" ]]; then
        # Scenario 3: --pkgs without --profile-name → use default profile (minimal)
        log_info "Using default profile 'minimal' with custom packages"
        expand_profile_name "minimal"
    else
        # Scenario 4: No profile specified → use default minimal profile
        # This ensures LIBS_BUNDLE and PKGS_BUNDLE are always set
        log_info "Using default profile 'minimal'"
        expand_profile_name "minimal"
    fi

    # Apply smart defaults based on base image if needed (may override profile defaults)
    if [[ -n "${BASE_IMAGE:-}" ]] && [[ "${USER_PROVIDED_BASE_IMAGE:-false}" == "true" ]]; then
        apply_smart_defaults "$BASE_IMAGE"
    fi

    # Validate profile combination compatibility
    if [[ -n "${BASE_IMAGE:-}" ]] || [[ -n "${LIBS_BUNDLE:-}" ]] || [[ -n "${PKGS_BUNDLE:-}" ]]; then
        validate_profile_combination "${BASE_IMAGE:-}" "${LIBS_BUNDLE:-}" "${PKGS_BUNDLE:-}" || exit 1
    fi

    # Generate actual install commands from bundles.yaml (single source of truth)
    # These will be injected into the Dockerfile template
    generate_r_package_install_commands "${PKGS_BUNDLE}"
    generate_system_deps_install_commands "${LIBS_BUNDLE}"

    # Validate team member restrictions
    # Team member = has TEAM_NAME AND Dockerfile already exists
    # Team lead = has TEAM_NAME but NO Dockerfile (initializing)
    if [[ -n "${TEAM_NAME:-}" ]] && [[ -f "Dockerfile" ]]; then
        validate_team_member_flags "true"
    fi

    # Validate templates directory
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found: $TEMPLATES_DIR"
        log_error "Please ensure you're running this script from the zzcollab directory"
        exit 1
    fi

    # Run conflict detection FIRST, before any directory creation
    confirm_overwrite_conflicts

    # Validate directory is safe for setup (but skip conflict detection since we already did it)
    validate_directory_for_setup_no_conflicts

    # Initialize manifest tracking
    init_manifest
}

# Function: execute_project_creation_workflow
# Purpose: Execute the main project creation steps
execute_project_creation_workflow() {
    # Execute setup in same order as original zzcollab.sh
    log_info "📁 Creating project structure..."
    # Unified paradigm - single structure for all research workflows
    create_directory_structure || exit 1
    create_data_templates || exit 1
    
    log_info "📦 Creating R package files..."
    create_core_files || exit 1
    create_renv_setup || exit 1
    
    log_info "⚙️ Creating configuration files..."
    create_config_files || exit 1
    
    log_info "🐳 Creating Docker files..."
    create_docker_files || exit 1
    
    log_info "📝 Creating analysis files..."
    create_analysis_files || exit 1
    
    log_info "📜 Creating research scripts..."
    create_scripts_directory || exit 1
    
    log_info "🚀 Creating GitHub workflows..."
    create_github_workflows || exit 1
    
    log_info "🛠️ Creating development tools..."
    create_makefile || exit 1
    
    log_info "🔗 Creating navigation scripts..."
    create_navigation_scripts || exit 1
}

# Function: finalize_and_report_results  
# Purpose: Complete setup with Docker build, renv, GitHub, and reporting
finalize_and_report_results() {
    # Determine R version for Docker build
    # Priority: 1) User-provided --r-version, 2) renv.lock
    if [[ "${USER_PROVIDED_R_VERSION:-false}" != "true" ]]; then
        log_info "🔍 Detecting R version from renv.lock..."
        R_VERSION=$(extract_r_version_from_lockfile)
        export R_VERSION
        log_info "Using R version: $R_VERSION"
    else
        log_info "Using user-specified R version: $R_VERSION"
    fi

    # Install uninstall script
    install_uninstall_script
    
    # Conditional Docker build (same logic as original)
    if [[ "$BUILD_DOCKER" == "true" ]]; then
        log_info "🐳 Building Docker image..."
        if build_docker_image; then
            log_success "Docker image built successfully"
            
            # Clean up dotfiles from working directory after successful Docker build
            if command -v cleanup_dotfiles_from_workdir >/dev/null 2>&1; then
                cleanup_dotfiles_from_workdir
            fi
        else
            log_warning "Docker build failed - you can build manually later with 'make docker-build'"
            log_info "💡 Dotfiles kept in working directory for manual Docker build"
        fi
    else
        log_info "⏭️ Skipping Docker image build (use 'make docker-build' to build)"
        log_info "💡 Run 'make docker-build' after initialization completes"
    fi
    
    # Initialize renv with snapshot of current environment
    log_info "📦 Creating renv.lock file..."
    if command -v R >/dev/null 2>&1; then
        if R --slave -e "renv::init(bare = TRUE, restart = FALSE); renv::snapshot(prompt = FALSE)" 2>/dev/null; then
            log_success "Created renv.lock with current package environment"
        else
            log_warning "Failed to create renv.lock - run 'renv::init(); renv::snapshot()' manually"
        fi
    else
        log_warning "R not found - run 'renv::init(); renv::snapshot()' after installing R"
    fi
    
    # Create GitHub repository if requested
    if [[ "$CREATE_GITHUB_REPO" == "true" ]]; then
        log_info "🐙 Creating GitHub repository..."
        create_github_repository_workflow
    fi
    
    # Clean up team setup marker if it exists (workflow completed)
    if [[ -f ".zzcollab_team_setup" ]]; then
        rm ".zzcollab_team_setup"
        log_info "🧹 Cleaned up team initialization marker (full setup now complete)"
    fi
    
    # Final success message and concise summary
    echo ""
    log_success "Done! Next: make docker-build"

    # Show created items count (only in verbose mode)
    if [[ $VERBOSITY_LEVEL -ge 2 ]]; then
        echo ""
        local dir_count file_count symlink_count
        dir_count=$(find . -type d | wc -l)
        file_count=$(find . -type f \( ! -path "./.git/*" \) | wc -l)
        symlink_count=$(find . -type l | wc -l)

        log_info "📊 Created: $dir_count directories, $file_count files, $symlink_count symlinks"
        log_info "📄 Manifest: $([[ -f "$MANIFEST_FILE" ]] && echo "$MANIFEST_FILE" || echo "$MANIFEST_TXT")"

        # Show module summaries (only in verbose mode)
        echo ""
        show_structure_summary
        echo ""
        show_rpackage_summary
        echo ""
        show_docker_summary
        echo ""
        show_analysis_summary
        echo ""
        show_cicd_summary
        echo ""
        show_devtools_summary

        echo ""
        log_info "📚 Run '$0 --next-steps' for development workflow guidance"
        log_info "🆘 Run './zzcollab-uninstall.sh' if you need to remove created files"
        log_info "📖 See ZZCOLLAB_USER_GUIDE.md for comprehensive documentation"
        echo ""
    fi
}

#=============================================================================
# MAIN EXECUTION FUNCTION (refactored for clarity)
#=============================================================================

main() {
    handle_special_modes
    validate_and_setup_environment
    execute_project_creation_workflow
    finalize_and_report_results
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi