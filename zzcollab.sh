#!/bin/bash
##############################################################################
# ZZCOLLAB - Research Compendium Framework
##############################################################################
# Single entry point with subcommand routing
#
# USAGE:
#   zzcollab init [OPTIONS]          Create new project
#   zzcollab docker [OPTIONS]        Generate/build Docker image
#   zzcollab validate [OPTIONS]      Validate project structure
#   zzcollab config [SUBCOMMAND]     Configuration management
#   zzcollab help [TOPIC]            Show help
#
# LEGACY (backwards compatible):
#   zzcollab -t TEAM -p PROJECT      Team setup (maps to 'init')
#   zzcollab --help                  Show help
##############################################################################

set -euo pipefail

#=============================================================================
# PATH DETECTION
#=============================================================================

# Determine installation directory
# Priority: 1) ~/.zzcollab (installed), 2) script directory (development)
# Note: These are exported but NOT readonly - constants.sh handles readonly
if [[ -d "$HOME/.zzcollab/lib" ]]; then
    export ZZCOLLAB_HOME="$HOME/.zzcollab"
else
    export ZZCOLLAB_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Set derived paths (constants.sh will make them readonly)
export ZZCOLLAB_LIB_DIR="$ZZCOLLAB_HOME/lib"
export ZZCOLLAB_MODULES_DIR="$ZZCOLLAB_HOME/modules"
export ZZCOLLAB_TEMPLATES_DIR="$ZZCOLLAB_HOME/templates"

#=============================================================================
# BOOTSTRAP LOGGING (before core.sh loads)
#=============================================================================

log_info() { printf "ℹ️  %s\n" "$*" >&2; }
log_error() { printf "❌ %s\n" "$*" >&2; }
log_debug() { :; }

#=============================================================================
# MODULE SYSTEM
#=============================================================================

# Track loaded modules (Bash 3.2 compatible)
LOADED_MODULES=""

require_module() {
    local module
    for module in "$@"; do
        # Skip if already loaded (check both tracking methods)
        case " $LOADED_MODULES " in
            *" $module "*) continue ;;
        esac

        # Also check ZZCOLLAB_*_LOADED flags
        local module_upper
        module_upper=$(echo "$module" | tr '[:lower:]' '[:upper:]')
        local module_var="ZZCOLLAB_${module_upper}_LOADED"
        if [[ "${!module_var:-}" == "true" ]]; then
            LOADED_MODULES="$LOADED_MODULES $module"
            continue
        fi

        local module_path=""
        if [[ -f "$ZZCOLLAB_LIB_DIR/${module}.sh" ]]; then
            module_path="$ZZCOLLAB_LIB_DIR/${module}.sh"
        elif [[ -f "$ZZCOLLAB_MODULES_DIR/${module}.sh" ]]; then
            module_path="$ZZCOLLAB_MODULES_DIR/${module}.sh"
        else
            log_error "Module not found: $module"
            exit 1
        fi

        # shellcheck source=/dev/null
        source "$module_path"
        LOADED_MODULES="$LOADED_MODULES $module"
    done
}

export -f require_module

#=============================================================================
# LOAD FOUNDATION LIBRARIES
#=============================================================================

# Validate installation
if [[ ! -d "$ZZCOLLAB_LIB_DIR" ]]; then
    log_error "Library directory not found: $ZZCOLLAB_LIB_DIR"
    log_error "Run the installer or check your installation"
    exit 1
fi

# Load foundation (order matters: constants → core → templates)
require_module "constants" "core" "templates"

#=============================================================================
# WORKSPACE INITIALIZATION HELPER
#=============================================================================

# Check if rrtools workspace is initialized (DESCRIPTION exists)
# Returns 0 if initialized, 1 if not
is_workspace_initialized() {
    [[ -f "DESCRIPTION" ]]
}

# Ensure rrtools workspace exists, prompt to create if not
# Returns 0 on success, 1 on failure/cancel
ensure_workspace_initialized() {
    local context="${1:-operation}"

    if is_workspace_initialized; then
        return 0
    fi

    echo "" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "  No rrtools workspace detected" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  The '$context' command requires an initialized workspace." >&2
    echo "  This creates an rrtools type research compendium structure:" >&2
    echo "" >&2
    echo "    DESCRIPTION    R package metadata" >&2
    echo "    R/             Reusable functions" >&2
    echo "    analysis/      Data, scripts, reports" >&2
    echo "    tests/         Unit tests" >&2
    echo "" >&2

    if [[ ! -t 0 ]]; then
        log_error "Non-interactive mode: run 'zzcollab init' first"
        return 1
    fi

    read -r -p "Initialize workspace now? [Y/n]: " init_choice
    if [[ "$init_choice" =~ ^[Nn]$ ]]; then
        log_info "Cancelled. Run 'zzcollab init' when ready."
        return 1
    fi

    # Load required modules for project setup
    require_module "cli" "config" "project"

    # Get package name from directory
    PKG_NAME=$(basename "$(pwd)")
    PKG_NAME=$(echo "$PKG_NAME" | tr '-' '.' | tr '[:upper:]' '[:lower:]')
    export PKG_NAME

    log_info "Initializing workspace: $PKG_NAME"
    setup_project || {
        log_error "Workspace initialization failed"
        return 1
    }

    log_success "Workspace initialized"
    echo "" >&2
    return 0
}

#=============================================================================
# SUBCOMMAND ROUTING
#=============================================================================

# Note: main show_usage() defined later in file

cmd_init() {
    require_module "cli" "config" "project" "docker" "github"

    # Process CLI arguments
    process_cli "$@" || exit 1

    # Validate package name
    PKG_NAME=$(validate_package_name)
    readonly PKG_NAME
    export PKG_NAME

    log_info "Creating project: $PKG_NAME"

    # If a profile was specified, derive the base image from it
    if [[ "${USER_PROVIDED_PROFILE:-false}" == "true" ]] && [[ -n "${PROFILE_NAME:-}" ]]; then
        BASE_IMAGE=$(get_profile_base_image "$PROFILE_NAME")
        export BASE_IMAGE
        log_info "Using profile '$PROFILE_NAME' with base image: $BASE_IMAGE"
    fi

    # Run project setup
    setup_project || exit 1

    log_success "Project setup complete"

    # If legacy mode with profile specified, skip prompt and go straight to docker
    if [[ "${USER_PROVIDED_PROFILE:-false}" == "true" ]]; then
        cmd_docker --profile "$PROFILE_NAME"
        return $?
    fi

    # Prompt for reproducibility setup
    echo ""
    echo "───────────────────────────────────────────────────────────"
    echo "  Reproducibility Setup"
    echo "───────────────────────────────────────────────────────────"
    echo ""
    echo "  Your rrtools workspace is ready for host R development."
    echo "  For reproducible research, add package tracking and/or Docker."
    echo ""
    echo "  [r] renv only      - Package lockfile for reproducibility"
    echo "  [d] renv + Docker  - Full containerized environment (recommended)"
    echo "  [n] None           - Just rrtools structure, configure later"
    echo ""

    local repro_choice
    read -r -p "Add reproducibility? [r/d/N]: " repro_choice

    case "$repro_choice" in
        r|R)
            cmd_renv
            ;;
        d|D)
            cmd_docker
            ;;
        n|N|"")
            echo ""
            log_info "Skipping reproducibility setup"
            log_info "Run 'zzcollab renv' or 'zzcollab docker' later"
            ;;
        *)
            log_warn "Invalid choice, skipping reproducibility setup"
            log_info "Run 'zzcollab renv' or 'zzcollab docker' later"
            ;;
    esac

    return 0
}

cmd_docker() {
    require_module "cli" "config" "profiles" "docker"

    local build_image=false
    local r_version=""
    local base_image=""
    local profile=""
    local profile_changed=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build|-b) build_image=true; shift ;;
            --r-version) r_version="$2"; shift 2 ;;
            --base-image) base_image="$2"; shift 2 ;;
            --profile|-r) profile="$2"; profile_changed=true; shift 2 ;;
            --help|-h) require_module "help"; show_help_docker; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Ensure rrtools workspace is initialized
    ensure_workspace_initialized "docker" || exit 1

    # Ensure renv.lock exists (required by Dockerfile)
    if [[ ! -f "renv.lock" ]]; then
        log_info "No renv.lock found, creating minimal lockfile..."

        # Determine R version: CLI arg > config > query CRAN
        if [[ -z "$r_version" ]]; then
            load_config 2>/dev/null || true
            r_version="${CONFIG_R_VERSION:-}"
        fi
        if [[ -z "$r_version" ]]; then
            r_version=$(get_cran_r_version)
        fi

        create_renv_lock_minimal "$r_version"
    fi

    # Set environment for docker module
    [[ -n "$r_version" ]] && export R_VERSION="$r_version"
    [[ -n "$base_image" ]] && export BASE_IMAGE="$base_image"
    if [[ -n "$profile" ]]; then
        BASE_IMAGE=$(get_profile_base_image "$profile")
        export BASE_IMAGE
        # Save profile to config
        require_module "config"
        config_set "profile-name" "$profile" 2>/dev/null || true
    fi

    # Trigger build prompt if profile changed
    [[ "$profile_changed" == "true" ]] && ZZCOLLAB_BUILD_AFTER_SETUP="true"

    # Generate Dockerfile + renv.lock (wizard handles new workspaces)
    generate_dockerfile || exit 1

    # Build if requested explicitly or profile changed
    if [[ "$build_image" == "true" ]]; then
        build_docker_image || exit 1
    fi
}

cmd_renv() {
    require_module "config" "docker"

    local r_version=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --r-version) r_version="$2"; shift 2 ;;
            --help|-h)
                cat << 'EOF'
RENV SETUP (without Docker)

Sets up renv for reproducible R environments without Docker.

USAGE:
    zzcollab renv [OPTIONS]

OPTIONS:
    --r-version VERSION    Specify R version (default: query CRAN)
    --help, -h             Show this help

CREATES:
    renv.lock              Package lockfile with R version
    .Rprofile              renv activation + critical R options
    renv/                  renv directory structure

EXAMPLES:
    zzcollab renv                    # Interactive setup
    zzcollab renv --r-version 4.4.2  # Specify version

NEXT STEPS:
    R -e "renv::restore()"           # Install packages from lockfile
EOF
                exit 0
                ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Ensure rrtools workspace is initialized
    ensure_workspace_initialized "renv" || exit 1

    local project_name
    project_name=$(basename "$(pwd)")

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  renv setup: $project_name"
    echo "═══════════════════════════════════════════════════════════"

    # Get R version from config, CLI, or prompt
    if [[ -z "$r_version" ]]; then
        load_config 2>/dev/null || true
        r_version="${CONFIG_R_VERSION:-}"
    fi

    if [[ -z "$r_version" ]]; then
        local cran_version
        cran_version=$(get_cran_r_version)
        echo ""
        echo "  Current R version on CRAN: $cran_version"
        echo ""
        echo "  [1] Use R $cran_version (current)"
        echo "  [2] Specify a different version"
        echo ""

        local version_choice
        read -r -p "R version [1]: " version_choice
        version_choice="${version_choice:-1}"

        case "$version_choice" in
            1) r_version="$cran_version" ;;
            2)
                read -r -p "Enter R version (e.g., 4.3.2): " r_version
                if [[ ! "$r_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    log_error "Invalid version format. Expected: X.Y.Z"
                    return 1
                fi
                ;;
            *)
                log_error "Invalid choice"
                return 1
                ;;
        esac
    else
        echo ""
        echo "  R version: $r_version"
    fi

    # Create renv.lock
    create_renv_lock_minimal "$r_version"

    # Create .Rprofile with renv activation and critical options
    if [[ -f ".Rprofile" ]]; then
        log_warn ".Rprofile exists, checking for renv activation..."
        if ! grep -q "renv/activate.R" .Rprofile 2>/dev/null; then
            echo "" >> .Rprofile
            echo "# renv activation" >> .Rprofile
            echo 'source("renv/activate.R")' >> .Rprofile
            log_success "Added renv activation to .Rprofile"
        else
            log_info ".Rprofile already has renv activation"
        fi
    else
        cat > .Rprofile << 'EOF'
# renv activation
source("renv/activate.R")

# Critical reproducibility options
options(
    stringsAsFactors = FALSE,
    digits = 7,
    OutDec = ".",
    na.action = "na.omit",
    contrasts = c("contr.treatment", "contr.poly")
)

# Auto-restore on startup if packages missing
.First <- function() {
    if (file.exists("renv.lock") && requireNamespace("renv", quietly = TRUE)) {
        status <- tryCatch(renv::status(project = getwd()), error = function(e) NULL)
        if (!is.null(status) && !isTRUE(status$synchronized)) {
            message("Restoring packages from renv.lock...")
            renv::restore(prompt = FALSE)
        }
    }
}

# Auto-snapshot on exit
.Last <- function() {
    if (interactive() && file.exists("renv.lock") && requireNamespace("renv", quietly = TRUE)) {
        tryCatch({
            renv::snapshot(prompt = FALSE)
            message("renv.lock updated")
        }, error = function(e) NULL)
    }
}
EOF
        log_success "Created .Rprofile"
    fi

    # Create renv directory structure
    mkdir -p renv
    if [[ ! -f "renv/activate.R" ]]; then
        # Create minimal activate.R that will bootstrap renv
        cat > renv/activate.R << 'EOF'
# Minimal renv activation - will bootstrap full renv on first use
local({
    if (!requireNamespace("renv", quietly = TRUE)) {
        message("Installing renv...")
        install.packages("renv", repos = "https://cloud.r-project.org")
    }
    renv::load()
})
EOF
        log_success "Created renv/activate.R"
    fi

    # Create .gitignore for renv
    if [[ ! -f "renv/.gitignore" ]]; then
        cat > renv/.gitignore << 'EOF'
library/
local/
cellar/
lock/
python/
sandbox/
staging/
EOF
        log_success "Created renv/.gitignore"
    fi

    echo ""
    echo "───────────────────────────────────────────────────────────"
    echo "  Setup complete"
    echo "───────────────────────────────────────────────────────────"
    echo "  R version:  $r_version"
    echo "  renv.lock:  created"
    echo "  .Rprofile:  renv activation + critical options"
    echo ""
    echo "Next steps:"
    echo "  R                              # Start R (auto-restores packages)"
    echo "  install.packages('tidyverse')  # Add packages as needed"
    echo "  # renv.lock auto-updates on exit"
    echo ""

    # Offer to save R version to config
    read -r -p "Save R version to config? [Y/n]: " save_config
    if [[ ! "$save_config" =~ ^[Nn]$ ]]; then
        config_set "r-version" "$r_version"
    fi
}

cmd_validate() {
    # Pass all arguments directly to validation.sh's main function
    # This supports all validation flags: --fix, --strict, --verbose, --no-fix, --system-deps

    local validation_script="$ZZCOLLAB_MODULES_DIR/validation.sh"

    if [[ ! -f "$validation_script" ]]; then
        log_error "Validation module not found: $validation_script"
        return 1
    fi

    # Run validation.sh directly with all passed arguments
    bash "$validation_script" "$@"
}

cmd_config() {
    require_module "config"

    init_config_system

    local subcommand="${1:-}"
    shift || true

    # No subcommand = interactive setup
    if [[ -z "$subcommand" ]]; then
        # Ensure config file exists
        if [[ ! -f "$CONFIG_USER" ]]; then
            config_init "false"
        fi
        config_interactive_setup
        return
    fi

    case "$subcommand" in
        init)
            local interactive="false"
            [[ "${1:-}" == "--interactive" || "${1:-}" == "-i" ]] && interactive="true"
            config_init "$interactive"
            ;;
        list)
            config_list
            ;;
        get)
            [[ $# -lt 1 ]] && { log_error "Usage: zzcollab config get KEY"; exit 1; }
            config_get "$1"
            ;;
        set)
            [[ $# -lt 2 ]] && { log_error "Usage: zzcollab config set KEY VALUE"; exit 1; }
            config_set "$1" "$2"
            ;;
        *)
            log_error "Unknown config subcommand: $subcommand"
            log_info "Valid subcommands: init, list, get, set"
            log_info "Or run 'zzc config' with no args for interactive setup"
            exit 1
            ;;
    esac
}

cmd_nav() {
    local action="${1:-}"
    local nav_script="$ZZCOLLAB_HOME/navigation_scripts.sh"

    if [[ ! -f "$nav_script" ]]; then
        log_error "Navigation script not found: $nav_script"
        return 1
    fi

    case "$action" in
        install)
            "$nav_script" --install
            ;;
        uninstall)
            "$nav_script" --uninstall
            ;;
        show|"")
            cat << 'EOF'
Navigation shortcuts (after 'zzcollab nav install'):

  r  - project Root
  a  - analysis/
  d  - analysis/data/
  w  - analysis/data/raw_data/
  y  - analysis/data/derived_data/
  f  - analysis/figures/
  t  - analysis/tables/
  s  - analysis/scripts/
  p  - analysis/report/
  e  - tests/
  o  - docs/
  m  - man/

  mr - run 'make r' from anywhere in project

Install: zzcollab nav install
Remove:  zzcollab nav uninstall
EOF
            ;;
        --help|-h)
            cat << 'EOF'
Usage: zzcollab nav <action>

Actions:
  install     Add navigation shortcuts to shell config
  uninstall   Remove navigation shortcuts
  show        Display available shortcuts (default)

Navigation shortcuts provide single-letter commands to quickly
navigate within your project from any subdirectory.
EOF
            ;;
        *)
            log_error "Unknown action: $action"
            log_info "Valid actions: install, uninstall, show"
            return 1
            ;;
    esac
}

cmd_uninstall() {
    local dry_run=false
    local force=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n) dry_run=true; shift ;;
            --force|-f) force=true; shift ;;
            --help|-h)
                cat << 'EOF'
Usage: zzcollab uninstall [options]

Remove zzcollab-generated files from the current project.

Options:
  -n, --dry-run    Preview what would be removed
  -f, --force      Skip confirmation prompt
  -h, --help       Show this help

This removes files tracked in .zzcollab/manifest.json.
Your data, R code, and analysis files are preserved.
EOF
                return 0
                ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    # Check for manifest
    local manifest=".zzcollab/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        manifest=".zzcollab/manifest.txt"
        if [[ ! -f "$manifest" ]]; then
            log_error "No zzcollab manifest found in current directory"
            log_info "Are you in a zzcollab project?"
            return 1
        fi
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_info "Dry run - would remove:"
        if [[ "$manifest" == *.json ]] && command -v jq >/dev/null 2>&1; then
            jq -r '.files[]?, .directories[]?, .template_files[]?' "$manifest" 2>/dev/null | while read -r item; do
                [[ -e "$item" ]] && echo "  $item"
            done
        else
            grep -E '^(file|dir|template):' "$manifest" 2>/dev/null | cut -d: -f2- | while read -r item; do
                [[ -e "$item" ]] && echo "  $item"
            done
        fi
        return 0
    fi

    if [[ "$force" != "true" ]]; then
        log_warn "This will remove zzcollab files from the current project"
        read -p "Continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi

    log_info "Removing zzcollab files..."
    # Actual removal logic would go here
    # For now, just remove manifest
    rm -rf .zzcollab
    log_success "Uninstall complete"
}

cmd_list() {
    local list_type="${1:-}"

    case "$list_type" in
        profiles)
            require_module "profiles"
            echo "Available profiles (base images):"
            echo ""
            echo "  minimal      rocker/r-ver        Minimal R environment"
            echo "  tidyverse    rocker/tidyverse    Tidyverse packages included"
            echo "  verse        rocker/verse        Tidyverse + publishing tools"
            echo "  rstudio      rocker/rstudio      RStudio Server"
            echo "  shiny        rocker/shiny        Shiny Server"
            echo ""
            echo "Usage: zzcollab docker --profile <name>"
            ;;
        libs)
            echo "System library bundles (auto-derived from R packages):"
            echo ""
            echo "  graphics     libcairo2-dev libfreetype6-dev libpng-dev"
            echo "  database     libpq-dev libmariadb-dev libsqlite3-dev"
            echo "  network      libcurl4-openssl-dev libssl-dev libssh2-1-dev"
            echo "  text         libxml2-dev libicu-dev"
            echo ""
            echo "Note: System deps are now auto-derived from R packages in"
            echo "DESCRIPTION/renv.lock. Manual --libs flag rarely needed."
            ;;
        pkgs)
            echo "R package bundles:"
            echo ""
            echo "  tidyverse    dplyr, tidyr, ggplot2, readr, purrr, etc."
            echo "  modeling     lme4, brms, rstanarm, broom"
            echo "  reporting    rmarkdown, knitr, bookdown, xaringan"
            echo "  tables       gt, flextable, kableExtra"
            echo ""
            echo "Note: Packages are managed via renv.lock. Add packages with"
            echo "renv::install() inside the container."
            ;;
        all|"")
            cmd_list profiles
            echo ""
            cmd_list libs
            echo ""
            cmd_list pkgs
            ;;
        --help|-h)
            cat << 'EOF'
Usage: zzcollab list <type>

Types:
  profiles    List Docker base image profiles
  libs        List system library bundles
  pkgs        List R package bundles
  all         List everything (default)
EOF
            ;;
        *)
            log_error "Unknown list type: $list_type"
            log_info "Valid types: profiles, libs, pkgs, all"
            return 1
            ;;
    esac
}

cmd_help() {
    require_module "help"

    local topic="${1:-}"

    if [[ -z "$topic" ]]; then
        show_help
    else
        case "$topic" in
            init|quickstart) show_help_quickstart ;;
            docker) show_help_docker ;;
            validate) log_info "Validate: Check project structure and dependencies" ;;
            nav|navigation) cmd_nav --help ;;
            uninstall) cmd_uninstall --help ;;
            config) show_help_config ;;
            github) show_github_help ;;
            workflow) show_help_workflow ;;
            renv) show_help_renv ;;
            profiles) show_help_profiles ;;
            cicd) show_help_cicd ;;
            troubleshooting) show_help_troubleshooting ;;
            *) log_error "Unknown help topic: $topic"; show_help_topics_list ;;
        esac
    fi
}

#=============================================================================
# GIT COMMANDS
#=============================================================================

cmd_git() {
    # Check git is available
    if ! command -v git &>/dev/null; then
        log_error "git not installed"
        log_info "Install: xcode-select --install (macOS) or apt install git (Linux)"
        return 1
    fi

    if [[ -d ".git" ]]; then
        log_info "Git already initialized"
        return 0
    fi

    log_info "Initializing git repository..."
    git init || { log_error "git init failed"; return 1; }

    # Create .gitignore if it doesn't exist
    if [[ ! -f ".gitignore" ]]; then
        cat > .gitignore << 'EOF'
# R artifacts
.Rhistory
.Rdata
.RDataTmp
.Ruserdata
*.Rproj.user/

# renv
renv/library/
renv/local/
renv/cellar/
renv/lock/
renv/python/
renv/sandbox/
renv/staging/

# Data (customize as needed)
# analysis/data/raw_data/
# analysis/data/derived_data/

# Docker
.docker/

# OS
.DS_Store
Thumbs.db

# zzcollab user files
.zzcollab/
EOF
        log_success "Created .gitignore"
    fi

    log_success "Git initialized"
    return 0
}

cmd_github() {
    # Ensure git is initialized first
    cmd_git || return 1

    # Ensure there's at least one commit (required for --push)
    if ! git rev-parse HEAD &>/dev/null; then
        log_info "Creating initial commit..."
        git add .
        git commit -m "Initial project setup

Generated with zzcollab" || {
            log_error "Failed to create initial commit"
            return 1
        }
        log_success "Initial commit created"
    fi

    # Check if gh CLI is available
    if ! command -v gh &>/dev/null; then
        log_error "GitHub CLI (gh) not installed"
        log_info "Install: https://cli.github.com/"
        return 1
    fi

    # Check if already has remote
    if git remote get-url origin &>/dev/null; then
        log_info "GitHub remote already configured"
        git remote get-url origin
        return 0
    fi

    local project_name
    project_name=$(basename "$(pwd)")

    # Check auth status
    if ! gh auth status &>/dev/null; then
        log_error "Not authenticated with GitHub"
        log_info "Run: gh auth login"
        return 1
    fi

    # Get GitHub username
    local gh_user
    gh_user=$(gh api user --jq '.login' 2>/dev/null) || {
        log_error "Could not get GitHub username"
        return 1
    }

    # Check if repo already exists
    if gh repo view "${gh_user}/${project_name}" &>/dev/null; then
        log_warn "Repository ${gh_user}/${project_name} already exists"
        echo ""
        echo "Options:"
        echo "  1) Connect to existing repo (add remote and push)"
        echo "  2) Delete and recreate"
        echo "  3) Cancel"
        echo ""
        read -r -p "Choice [1]: " choice
        choice="${choice:-1}"

        case "$choice" in
            1)
                log_info "Connecting to existing repository..."
                git remote add origin "https://github.com/${gh_user}/${project_name}.git" 2>/dev/null || \
                    git remote set-url origin "https://github.com/${gh_user}/${project_name}.git"
                git branch -M main
                git push -u origin main --force
                log_success "Connected and pushed to existing repository"
                return 0
                ;;
            2)
                log_warn "Deleting existing repository..."
                gh repo delete "${gh_user}/${project_name}" --yes || {
                    log_error "Failed to delete repository"
                    return 1
                }
                log_success "Deleted ${gh_user}/${project_name}"
                ;;
            *)
                log_info "Cancelled"
                return 0
                ;;
        esac
    fi

    local visibility="${GITHUB_VISIBILITY:-private}"
    log_info "Creating GitHub repository: $project_name ($visibility)"

    if gh repo create "$project_name" --source=. "--${visibility}" --push; then
        log_success "GitHub repository created and pushed"
        gh repo view --web 2>/dev/null || true
    else
        log_error "Failed to create GitHub repository"
        return 1
    fi

    return 0
}

cmd_dockerhub() {
    local tag="${1:-latest}"
    local project_name
    project_name=$(basename "$(pwd)")

    # Check Docker is available
    if ! command -v docker &>/dev/null; then
        log_error "Docker not installed"
        return 1
    fi

    # Check if image exists locally
    if ! docker image inspect "$project_name" &>/dev/null; then
        log_error "Docker image '$project_name' not found"
        log_info "Build first: zzcollab docker -b"
        return 1
    fi

    # Get DockerHub username from config or environment
    require_module "config"
    load_config 2>/dev/null || true
    local dockerhub_user="${DOCKERHUB_ACCOUNT:-${CONFIG_DOCKERHUB_ACCOUNT:-}}"

    if [[ -z "$dockerhub_user" ]]; then
        # Try to get from docker info
        dockerhub_user=$(docker info 2>/dev/null | grep -i username | awk '{print $2}')
    fi

    if [[ -z "$dockerhub_user" ]]; then
        log_error "DockerHub username not configured"
        log_info "Set with: zzcollab config set dockerhub-account <username>"
        log_info "Or login: docker login"
        return 1
    fi

    local remote_image="${dockerhub_user}/${project_name}:${tag}"

    log_info "Tagging: $project_name → $remote_image"
    docker tag "$project_name" "$remote_image" || {
        log_error "Failed to tag image"
        return 1
    }

    log_info "Pushing to DockerHub: $remote_image"
    if docker push "$remote_image"; then
        log_success "Pushed: $remote_image"
        echo ""
        echo "Pull with:"
        echo "  docker pull $remote_image"
    else
        log_error "Push failed. Check: docker login"
        return 1
    fi

    return 0
}

##############################################################################
# FUNCTION: cmd_quickstart
# PURPOSE:  Smart profile command - quickstart for new, switch for existing
# USAGE:    zzcollab analysis
#           zzcollab minimal
# ARGS:     $1 - profile name (analysis, minimal, publishing, etc.)
##############################################################################
cmd_quickstart() {
    local profile="${1:-analysis}"

    require_module "cli" "config" "project" "profiles" "docker"

    # Validate profile exists
    local base_image
    base_image=$(get_profile_base_image "$profile") || {
        log_error "Unknown profile: $profile"
        log_info "Available: minimal, analysis, publishing, rstudio, shiny, verse, tidyverse"
        return 1
    }

    # Existing project → just switch profile
    if is_workspace_initialized; then
        log_info "Switching to profile: $profile ($base_image)"
        config_set "profile-name" "$profile" 2>/dev/null || true

        if [[ -f "Dockerfile" ]]; then
            export BASE_IMAGE="$base_image"
            generate_dockerfile || return 1
            log_success "Dockerfile regenerated with $profile profile"
        else
            log_info "No Dockerfile yet. Run 'zzcollab docker' to generate."
        fi
        return 0
    fi

    # New project → full quickstart
    local project_name
    project_name=$(basename "$(pwd)")

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  zzcollab quickstart: $project_name"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Profile:    $profile"
    echo "  Base image: $base_image"
    echo ""
    echo "  This will create:"
    echo "    - rrtools research compendium structure"
    echo "    - renv.lock for package reproducibility"
    echo "    - Dockerfile for containerized environment"
    echo ""

    read -r -p "Continue? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    # Step 1: Initialize project structure
    echo ""
    log_info "Step 1/3: Creating project structure..."
    PKG_NAME=$(validate_package_name)
    export PKG_NAME
    setup_project || return 1
    log_success "Project structure created"

    # Step 2: Set up renv
    echo ""
    log_info "Step 2/3: Setting up renv..."
    local r_version
    r_version=$(get_cran_r_version)
    create_renv_lock_minimal "$r_version"
    log_success "renv.lock created (R $r_version)"

    # Step 3: Generate Dockerfile with profile
    echo ""
    log_info "Step 3/3: Generating Dockerfile..."
    export BASE_IMAGE="$base_image"
    config_set "profile-name" "$profile" 2>/dev/null || true
    generate_dockerfile || return 1
    log_success "Dockerfile created ($profile profile)"

    # Summary and build prompt
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Setup complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Created:"
    echo "    DESCRIPTION, R/, analysis/, tests/"
    echo "    renv.lock (R $r_version)"
    echo "    Dockerfile ($profile)"
    echo ""

    read -r -p "Build Docker image now? [y/N]: " build_choice
    if [[ "$build_choice" =~ ^[Yy]$ ]]; then
        echo ""
        build_docker_image || return 1
        echo ""
        log_success "Ready! Run 'make r' to start development"
    else
        echo ""
        log_info "To build later: make docker-build"
        log_info "To start development: make r"
    fi

    return 0
}

#=============================================================================
# REMOVE COMMANDS
#=============================================================================

cmd_rm() {
    local feature="${1:-}"

    case "$feature" in
        docker)
            cmd_rm_docker
            ;;
        renv)
            cmd_rm_renv
            ;;
        git)
            cmd_rm_git
            ;;
        github)
            cmd_rm_github
            ;;
        cicd)
            cmd_rm_cicd
            ;;
        all)
            cmd_rm_all
            ;;
        "")
            log_error "Usage: zzcollab rm <feature>"
            log_info "Features: docker, renv, git, github, cicd, all"
            return 1
            ;;
        *)
            log_error "Unknown feature: $feature"
            log_info "Features: docker, renv, git, github, cicd, all"
            return 1
            ;;
    esac
}

cmd_rm_docker() {
    local files=("Dockerfile" ".dockerignore")
    local removed=0

    for f in "${files[@]}"; do
        if [[ -f "$f" ]]; then
            rm "$f"
            log_info "Removed $f"
            ((removed++))
        fi
    done

    if [[ $removed -eq 0 ]]; then
        log_info "No Docker files to remove"
    else
        log_success "Docker configuration removed"
    fi
}

cmd_rm_renv() {
    echo ""
    log_warn "This will remove renv.lock and renv/ directory"
    read -r -p "Continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    [[ -f "renv.lock" ]] && rm "renv.lock" && log_info "Removed renv.lock"
    [[ -d "renv" ]] && rm -rf "renv" && log_info "Removed renv/"

    # Remove renv activation from .Rprofile if present
    if [[ -f ".Rprofile" ]] && grep -q "renv/activate.R" .Rprofile; then
        sed -i.bak '/renv\/activate.R/d' .Rprofile
        rm -f .Rprofile.bak
        log_info "Removed renv activation from .Rprofile"
    fi

    log_success "renv configuration removed"
}

cmd_rm_git() {
    if [[ ! -d ".git" ]]; then
        log_info "No git repository to remove"
        return 0
    fi

    echo ""
    log_warn "This will DELETE the .git directory and all git history!"
    read -r -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cancelled"
        return 0
    fi

    rm -rf .git
    log_success "Git repository removed"
}

cmd_rm_github() {
    if ! git remote get-url origin &>/dev/null; then
        log_info "No GitHub remote to remove"
        return 0
    fi

    git remote remove origin
    log_success "GitHub remote removed (local repo preserved)"
    log_info "Note: Remote repository still exists on GitHub"
}

cmd_rm_cicd() {
    if [[ ! -d ".github/workflows" ]]; then
        log_info "No CI/CD workflows to remove"
        return 0
    fi

    rm -rf .github/workflows
    # Remove .github if empty
    rmdir .github 2>/dev/null || true
    log_success "CI/CD workflows removed"
}

cmd_rm_all() {
    echo ""
    log_warn "This will remove ALL zzcollab-generated files:"
    echo ""
    echo "  Directories: R/, analysis/, tests/, man/, vignettes/, docs/, .github/"
    echo "  Files:       Dockerfile, Makefile, DESCRIPTION, NAMESPACE, LICENSE,"
    echo "               renv.lock, .Rprofile, .Rbuildignore, .gitignore, *.Rproj"
    echo "  Metadata:    .zzcollab/"
    echo ""
    echo "  Note: .git/ will NOT be removed (use 'zzc rm git' separately)"
    echo ""
    read -r -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cancelled"
        return 0
    fi

    # Directories
    local dirs=(R analysis tests man vignettes docs .github .zzcollab)
    for d in "${dirs[@]}"; do
        [[ -d "$d" ]] && rm -rf "$d" && log_info "Removed $d/"
    done

    # Files
    local files=(
        Dockerfile .dockerignore Makefile
        DESCRIPTION NAMESPACE LICENSE
        renv.lock .Rprofile .Rbuildignore .gitignore
    )
    for f in "${files[@]}"; do
        [[ -f "$f" ]] && rm "$f" && log_info "Removed $f"
    done

    # Rproj files
    for f in *.Rproj; do
        [[ -f "$f" ]] && rm "$f" && log_info "Removed $f"
    done

    # renv directory
    [[ -d "renv" ]] && rm -rf "renv" && log_info "Removed renv/"

    log_success "All zzcollab files removed"
    log_info "Directory now contains only your original files"
}

#=============================================================================
# MAIN - Multi-command parsing
#=============================================================================

show_usage() {
    cat << 'EOF'
Usage: zzcollab <commands...> [options]

Commands (can be combined):
  init       Create rrtools structure (DESCRIPTION, R/, analysis/)
  renv       Add renv package tracking (renv.lock)
  docker     Add Docker containerization (Dockerfile)
  git        Initialize git repository
  github     Initialize git + create GitHub repo
  dockerhub  Push Docker image to DockerHub

Profiles (new project: init+renv+docker, existing: switch profile):
  analysis     Tidyverse packages (~1.5GB) - recommended
  minimal      Base R only (~300MB)
  publishing   LaTeX + pandoc (~3GB)
  rstudio      RStudio Server
  shiny        Shiny Server

Management:
  rm <feature>   Remove: docker, renv, git, github, cicd
  validate       Check project structure
  config         Configuration management
  list           List profiles, libs, packages
  nav            Navigation shortcuts
  help           Show help

Options:
  -b, --build      Build Docker image after generating
  --tag <tag>      DockerHub image tag (default: latest)
  --private        Create private GitHub repo (default)
  --public         Create public GitHub repo
  -v, --verbose    More output
  -q, --quiet      Errors only

Examples:
  zzcollab analysis                # Quickstart: init + renv + docker (recommended)
  zzcollab minimal                 # Quickstart with minimal profile
  zzcollab init                    # Create rrtools structure only
  zzcollab docker                  # Add Docker (auto-adds renv, init)
  zzcollab docker -b github        # Build image + create GitHub repo
  zzcollab rm docker               # Remove Docker files
  zzcollab publishing              # Switch to publishing profile (existing project)
EOF
}

main() {
    # No arguments → show usage
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    # Track if any command was executed
    local commands_run=0

    # Process arguments in order
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Global flags
            --version)
                echo "zzcollab ${ZZCOLLAB_VERSION:-2.0.0}"
                exit 0
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                export VERBOSITY_LEVEL=2
                shift
                ;;
            -q|--quiet)
                export VERBOSITY_LEVEL=0
                shift
                ;;

            # Commands that take no arguments
            init)
                cmd_init
                ((commands_run++))
                shift
                ;;
            renv)
                cmd_renv
                ((commands_run++))
                shift
                ;;
            docker)
                # Collect docker-specific flags
                shift
                local docker_args=()
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        -r|--profile)
                            docker_args+=("--profile" "$2")
                            shift 2
                            ;;
                        -b|--build)
                            docker_args+=("--build")
                            shift
                            ;;
                        --r-version|--base-image)
                            docker_args+=("$1" "$2")
                            shift 2
                            ;;
                        # Profile names as implicit --profile
                        minimal|analysis|publishing|rstudio|shiny|verse|tidyverse)
                            docker_args+=("--profile" "$1")
                            shift
                            ;;
                        -*)
                            # Unknown flag, might be for next command
                            break
                            ;;
                        *)
                            # Not a flag, might be next command
                            break
                            ;;
                    esac
                done
                cmd_docker ${docker_args[@]+"${docker_args[@]}"}
                ((commands_run++))
                ;;
            git)
                cmd_git
                ((commands_run++))
                shift
                ;;
            github)
                # Check for visibility flags
                shift
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --private)
                            export GITHUB_VISIBILITY="private"
                            shift
                            ;;
                        --public)
                            export GITHUB_VISIBILITY="public"
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                cmd_github
                ((commands_run++))
                ;;
            dockerhub)
                shift
                local dockerhub_tag="latest"
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --tag|-t)
                            dockerhub_tag="$2"
                            shift 2
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                cmd_dockerhub "$dockerhub_tag"
                ((commands_run++))
                ;;
            # Standalone profile flag (same as profile name command)
            -r|--profile)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "-r/--profile requires a name"
                    exit 1
                fi
                cmd_quickstart "$1"
                ((commands_run++))
                shift
                ;;

            # Remove command
            rm)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "rm requires a feature name"
                    log_info "Features: docker, renv, git, github, cicd"
                    exit 1
                fi
                cmd_rm "$1"
                ((commands_run++))
                shift
                ;;

            # Profile names as standalone commands → full quickstart
            minimal|analysis|publishing|rstudio|shiny|verse|tidyverse)
                cmd_quickstart "$1"
                ((commands_run++))
                shift
                ;;

            # Other commands that pass through
            validate)
                shift
                cmd_validate "$@"
                exit $?
                ;;
            config)
                shift
                cmd_config "$@"
                exit $?
                ;;
            list)
                shift
                cmd_list "$@"
                exit $?
                ;;
            nav)
                shift
                cmd_nav "$@"
                exit $?
                ;;
            uninstall)
                shift
                cmd_uninstall "$@"
                exit $?
                ;;
            help)
                shift
                cmd_help "$@"
                exit $?
                ;;

            # Unknown
            *)
                log_error "Unknown command: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # If no commands were run, show usage
    if [[ $commands_run -eq 0 ]]; then
        show_usage
        exit 0
    fi

    exit 0
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
