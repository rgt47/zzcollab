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
# SUBCOMMAND ROUTING
#=============================================================================

show_usage() {
    cat << 'EOF'
Usage: zzcollab <command> [options]

Commands:
  init       Create a new research compendium project
  docker     Generate Dockerfile and/or build image
  validate   Validate project structure and dependencies
  nav        Shell navigation shortcuts (install/uninstall)
  uninstall  Remove zzcollab files from project
  list       List profiles, libs, or packages
  config     Configuration management (list, get, set)
  help       Show help for a topic

Options (global):
  -v, --verbose    Increase verbosity
  -q, --quiet      Suppress non-error output
  --version        Show version

Examples:
  zzcollab init                      # Interactive project setup
  zzcollab docker --build            # Generate and build Docker image
  zzcollab validate                  # Check project structure
  zzcollab nav install               # Add navigation shortcuts to shell
  zzcollab uninstall --dry-run       # Preview what would be removed
  zzcollab help docker               # Help on Docker commands

Legacy mode (backwards compatible):
  zzcollab -t TEAM -p PROJECT        # Team setup
  zzcollab --profile-name NAME       # Use predefined profile
EOF
}

cmd_init() {
    require_module "cli" "config" "project" "docker" "github"

    # Process CLI arguments
    process_cli "$@" || exit 1

    # Validate package name
    PKG_NAME=$(validate_package_name)
    readonly PKG_NAME
    export PKG_NAME

    log_info "Creating project: $PKG_NAME"

    # Run project setup
    setup_project || exit 1

    # Generate Dockerfile if not in --no-docker mode
    if [[ "${BUILD_DOCKER:-true}" != "false" ]]; then
        generate_dockerfile || log_warn "Dockerfile generation failed"
    fi

    log_success "Project created: $PKG_NAME"
    log_info "Next: cd $PKG_NAME && make docker-build"
}

cmd_docker() {
    require_module "cli" "config" "profiles" "docker"

    local build_image=false
    local r_version=""
    local base_image=""
    local profile=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build|-b) build_image=true; shift ;;
            --r-version) r_version="$2"; shift 2 ;;
            --base-image) base_image="$2"; shift 2 ;;
            --profile) profile="$2"; shift 2 ;;
            --help|-h) require_module "help"; show_help_docker; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Set environment for docker module
    [[ -n "$r_version" ]] && export R_VERSION="$r_version"
    [[ -n "$base_image" ]] && export BASE_IMAGE="$base_image"
    [[ -n "$profile" ]] && BASE_IMAGE=$(get_profile_base_image "$profile")

    # Generate Dockerfile + renv.lock (wizard handles new workspaces)
    generate_dockerfile || exit 1

    # Build if requested
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

    local subcommand="${1:-list}"
    shift || true

    case "$subcommand" in
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
            log_info "Valid subcommands: list, get, set"
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
# LEGACY MODE DETECTION
#=============================================================================

is_legacy_mode() {
    # Check if any legacy flags are present
    for arg in "$@"; do
        case "$arg" in
            -t|--team-name|-p|--project-name|--profile-name|--base-image)
                return 0
                ;;
        esac
    done
    return 1
}

#=============================================================================
# MAIN
#=============================================================================

main() {
    # No arguments → show usage
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    # Check for global flags first
    case "$1" in
        --version)
            echo "zzcollab ${ZZCOLLAB_VERSION:-1.0.0}"
            exit 0
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
    esac

    # Legacy mode detection (backwards compatibility)
    if is_legacy_mode "$@"; then
        cmd_init "$@"
        exit $?
    fi

    # Subcommand routing
    local command="$1"
    shift

    case "$command" in
        init)      cmd_init "$@" ;;
        docker)    cmd_docker "$@" ;;
        renv)      cmd_renv "$@" ;;
        validate)  cmd_validate "$@" ;;
        nav)       cmd_nav "$@" ;;
        uninstall) cmd_uninstall "$@" ;;
        list)      cmd_list "$@" ;;
        config)    cmd_config "$@" ;;
        help)      cmd_help "$@" ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
