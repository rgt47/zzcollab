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
# PORTABILITY HELPERS
#=============================================================================

_reverse_lines() {
    awk '{a[NR]=$0} END{for(i=NR;i>=1;i--)print a[i]}'
}

#=============================================================================
# MODULE SYSTEM
#=============================================================================

# Module loading uses ZZCOLLAB_*_LOADED flags set inside each module.
# This works even if modules are sourced directly (bypassing require_module).

require_module() {
    local module
    for module in "$@"; do
        # Skip if already loaded (each module sets readonly ZZCOLLAB_<NAME>_LOADED=true)
        local module_upper
        module_upper=$(echo "$module" | tr '[:lower:]' '[:upper:]')
        local module_var="ZZCOLLAB_${module_upper}_LOADED"
        [[ "${!module_var:-}" == "true" ]] && continue

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
    done
}

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

    if [[ ! -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
        log_error "Non-interactive mode: run 'zzcollab init' first"
        return 1
    fi

    local init_choice
    zzc_read -r -p "Initialize workspace now? [Y/n]: " init_choice
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
# DOCKER IMAGE HELPER
#=============================================================================

# Ensure Docker image exists, prompt to build if not
# Usage: ensure_docker_image_built [project_name]
# Returns 0 on success, 1 on failure/cancel
ensure_docker_image_built() {
    local project_name="${1:-$(basename "$(pwd)")}"

    # Already exists
    if docker image inspect "$project_name" &>/dev/null; then
        return 0
    fi

    # Check if Dockerfile exists
    if [[ ! -f "Dockerfile" ]]; then
        log_warn "No Dockerfile found"

        if [[ ! -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
            log_error "Non-interactive mode: run 'zzc docker' first"
            return 1
        fi

        zzc_read -p "Generate Dockerfile now? [Y/n] " -n 1 -r; echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Generate later with: zzc docker"
            return 1
        fi

        cmd_docker --build || return 1
        return 0  # cmd_docker already built the image
    fi

    log_warn "Docker image '$project_name' not found"

    if [[ ! -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
        log_error "Non-interactive mode: build first with 'zzc docker --build'"
        return 1
    fi

    zzc_read -p "Build it now? [Y/n] " -n 1 -r; echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Build later with: zzc docker --build"
        return 1
    fi

    require_module "config" "profiles" "docker"
    build_docker_image "$project_name"
}

#=============================================================================
# SUBCOMMAND ROUTING
#=============================================================================

# Note: main show_usage() defined later in file

# shellcheck disable=SC2120
cmd_init() {
    require_module "cli" "config" "project" "docker" "github"

    # Process CLI arguments
    process_cli "$@" || exit 1

    # Validate package name
    PKG_NAME=$(validate_package_name)
    export PKG_NAME

    # Load config and show all defaults
    load_config 2>/dev/null || true
    local profile_name="${CONFIG_PROFILE_NAME:-minimal}"
    local base_image
    base_image=$(get_profile_base_image "$profile_name")
    local r_version="${CONFIG_R_VERSION:-$(get_cran_r_version 2>/dev/null || echo "$ZZCOLLAB_DEFAULT_R_VERSION")}"

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Initializing: $PKG_NAME"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Current settings (from ~/.zzcollab/config.yaml):"
    echo ""
    echo "  Docker:"
    printf "    %-20s %s\n" "profile-name:" "$profile_name ($base_image)"
    printf "    %-20s %s\n" "r-version:" "$r_version"
    printf "    %-20s %s\n" "registry:" "${CONFIG_DOCKER_REGISTRY:-docker.io}"
    printf "    %-20s %s\n" "dockerhub-account:" "${CONFIG_DOCKERHUB_ACCOUNT:-<not set>}"
    echo ""
    echo "  Team Lead (for DESCRIPTION):"
    printf "    %-20s %s\n" "author-name:" "${CONFIG_AUTHOR_NAME:-<not set>}"
    printf "    %-20s %s\n" "author-email:" "${CONFIG_AUTHOR_EMAIL:-<not set>}"
    printf "    %-20s %s\n" "author-orcid:" "${CONFIG_AUTHOR_ORCID:-<not set>}"
    printf "    %-20s %s\n" "author-affiliation:" "${CONFIG_AUTHOR_AFFILIATION:-<not set>}"
    echo ""
    echo "  R Package:"
    printf "    %-20s %s\n" "min-r-version:" "${CONFIG_RPACKAGE_MIN_R_VERSION:-4.1.0}"
    printf "    %-20s %s\n" "testthat-edition:" "${CONFIG_RPACKAGE_TESTTHAT_EDITION:-3}"
    printf "    %-20s %s\n" "vignette-builder:" "${CONFIG_RPACKAGE_VIGNETTE_BUILDER:-knitr}"
    echo ""
    echo "  Code Style:"
    printf "    %-20s %s\n" "line-length:" "${CONFIG_STYLE_LINE_LENGTH:-78}"
    printf "    %-20s %s\n" "use-native-pipe:" "${CONFIG_STYLE_USE_NATIVE_PIPE:-true}"
    printf "    %-20s %s\n" "assignment:" "${CONFIG_STYLE_ASSIGNMENT:-arrow}"
    echo ""
    echo "  License:"
    printf "    %-20s %s\n" "license-type:" "${CONFIG_LICENSE_TYPE:-GPL-3}"
    printf "    %-20s %s\n" "license-year:" "${CONFIG_LICENSE_YEAR:-$(date +%Y)}"
    echo ""
    echo "  GitHub:"
    printf "    %-20s %s\n" "github-account:" "${CONFIG_GITHUB_ACCOUNT:-<not set>}"
    printf "    %-20s %s\n" "default-visibility:" "${CONFIG_GITHUB_DEFAULT_VISIBILITY:-private}"
    printf "    %-20s %s\n" "default-branch:" "${CONFIG_GITHUB_DEFAULT_BRANCH:-main}"
    echo ""
    echo "  CI/CD:"
    printf "    %-20s %s\n" "r-versions:" "${CONFIG_CICD_R_VERSIONS:-4.3, 4.4}"
    printf "    %-20s %s\n" "run-coverage:" "${CONFIG_CICD_RUN_COVERAGE:-true}"
    printf "    %-20s %s\n" "coverage-threshold:" "${CONFIG_CICD_COVERAGE_THRESHOLD:-80}"
    echo ""
    echo "  ─────────────────────────────────────────────────────────"
    echo "  To manually change settings:"
    echo "    zzc config set KEY VALUE         Save to ~/.zzcollab/config.yaml (user default)"
    echo "    zzc config set-local KEY VALUE   Save to ./zzcollab.yaml (this project only)"
    echo ""

    if [[ -t 0 ]]; then
        local change_settings
        zzc_read -r -p "  Change settings now? [y/N]: " change_settings
        if [[ "$change_settings" =~ ^[Yy]$ ]]; then
            echo ""
            config_interactive_setup
            # Reload config after interactive setup
            load_config 2>/dev/null || true
            profile_name="${CONFIG_PROFILE_NAME:-minimal}"
            base_image=$(get_profile_base_image "$profile_name")
        fi
    fi

    echo ""

    # If a profile was specified via CLI, derive the base image from it
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
    zzc_read -r -p "Add reproducibility? [r/d/N]: " repro_choice

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

    local build_image=""
    local r_version=""
    local base_image=""
    local profile=""
    local profile_changed=false
    local auto_no=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build|-b) build_image=true; shift ;;
            --no-build) build_image=false; shift ;;
            -y|--yes|-Y|--yes-all) export ZZCOLLAB_ACCEPT_DEFAULTS=true; shift ;;
            -n|--no) auto_no=true; shift ;;
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
        # Save profile to project config
        require_module "config"
        config_set "profile-name" "$profile" true 2>/dev/null || true
    else
        # No profile specified via CLI - use config default
        load_config 2>/dev/null || true
        if [[ -n "${CONFIG_PROFILE_NAME:-}" ]]; then
            BASE_IMAGE=$(get_profile_base_image "$CONFIG_PROFILE_NAME")
            export BASE_IMAGE
        fi
    fi

    # Generate Dockerfile + renv.lock (wizard handles new workspaces)
    generate_dockerfile || exit 1

    if [[ "$build_image" == "true" ]]; then
        build_docker_image || exit 1
    elif [[ "$build_image" == "false" ]] || [[ "$auto_no" == "true" ]]; then
        log_info "Build with: make docker-build"
    elif [[ -t 0 ]] || [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
        echo ""
        local build_choice
        zzc_read -r -p "Build Docker image now? [Y/n]: " build_choice
        if [[ ! "$build_choice" =~ ^[Nn]$ ]]; then
            build_docker_image || exit 1
        else
            log_info "Build later with: make docker-build"
        fi
    else
        log_info "Build with: make docker-build"
    fi
}

cmd_build() {
    require_module "docker"

    local no_cache="false"
    local log_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-cache) no_cache="true"; shift ;;
            --log)      log_file="docker-build.log"; shift ;;
            --help|-h)
                cat << 'HELPEOF'
BUILD DOCKER IMAGE

Builds the Docker image using the content-addressable cache.
If an image with the same Dockerfile+renv.lock hash exists,
it is retagged instead of rebuilt.

USAGE:
    zzcollab build [OPTIONS]

OPTIONS:
    --no-cache     Skip cache check; force full rebuild
    --log          Save build output to docker-build.log
    --help, -h     Show this help
HELPEOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if [[ -n "$log_file" ]]; then
        build_docker_image "$(basename "$(pwd)")" "$no_cache" \
            2>&1 | tee "$log_file"
    else
        build_docker_image "$(basename "$(pwd)")" "$no_cache"
    fi
}

# shellcheck disable=SC2120
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
        zzc_read -r -p "R version [1]: " version_choice
        version_choice="${version_choice:-1}"

        case "$version_choice" in
            1) r_version="$cran_version" ;;
            2)
                zzc_read -r -p "Enter R version (e.g., 4.3.2): " r_version
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

    # Create .Rprofile from template (always overwrite to ensure latest version)
    if [[ -f "$ZZCOLLAB_TEMPLATES_DIR/.Rprofile" ]]; then
        cp "$ZZCOLLAB_TEMPLATES_DIR/.Rprofile" .Rprofile
        log_success "Created .Rprofile from template"
    else
        log_error "Template .Rprofile not found at $ZZCOLLAB_TEMPLATES_DIR/.Rprofile"
        return 1
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
    local save_config
    zzc_read -r -p "Save R version to config? [Y/n]: " save_config
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

cmd_check_updates() {
    local script="$ZZCOLLAB_MODULES_DIR/check-updates.sh"
    if [[ ! -f "$script" ]]; then
        log_error "check-updates module not found: $script"
        return 1
    fi
    bash "$script" "$@"
}

# Silent advisory: warn once if any workspace template is outdated
warn_if_templates_outdated() {
    local cur="${ZZCOLLAB_TEMPLATE_VERSION:-}"
    [[ -z "$cur" ]] && return 0

    local file ver outdated=""
    for file in Makefile .Rprofile Dockerfile; do
        [[ -f "$file" ]] || continue
        ver=$(sed -n "s/^# zzcollab ${file} v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p" "$file" | head -1)
        if [[ -n "$ver" && "$ver" != "$cur" ]]; then
            outdated="${outdated:+$outdated, }${file} (v${ver})"
        fi
    done

    if [[ -n "$outdated" ]]; then
        printf '\033[1;33m⚠  Outdated templates: %s → v%s. Run: zzc check-updates\033[0m\n' \
            "$outdated" "$cur" >&2
    fi
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
            jq -r '.files[]?, .directories[]?, (.template_files[]? | .destination)?' "$manifest" 2>/dev/null | while read -r item; do
                [[ -n "$item" ]] && [[ -e "$item" ]] && echo "  $item"
            done || true
        else
            grep -E '^(file|dir|template):' "$manifest" 2>/dev/null | cut -d: -f2- | while read -r item; do
                [[ -n "$item" ]] && [[ -e "$item" ]] && echo "  $item"
            done || true
        fi
        return 0
    fi

    if [[ "$force" != "true" ]]; then
        log_warn "This will remove zzcollab files from the current project"
        zzc_read -p "Continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi

    log_info "Removing zzcollab files..."

    # Remove tracked files
    if [[ "$manifest" == *.json ]] && command -v jq >/dev/null 2>&1; then
        # Remove files first
        jq -r '.files[]? // empty' "$manifest" 2>/dev/null | while read -r item; do
            if [[ -f "$item" ]]; then
                rm -f "$item" && log_info "Removed file: $item"
            fi
        done

        # Remove template destinations
        jq -r '.template_files[]? | .destination // empty' "$manifest" 2>/dev/null | while read -r item; do
            if [[ -f "$item" ]]; then
                rm -f "$item" && log_info "Removed file: $item"
            fi
        done

        # Remove directories (in reverse order to handle nested dirs)
        jq -r '.directories[]? // empty' "$manifest" 2>/dev/null | _reverse_lines | while read -r item; do
            if [[ -d "$item" ]] && [[ -z "$(ls -A "$item" 2>/dev/null)" ]]; then
                rmdir "$item" && log_info "Removed directory: $item"
            fi
        done
    else
        # Text manifest fallback
        grep -E '^file:' "$manifest" 2>/dev/null | cut -d: -f2- | while read -r item; do
            if [[ -f "$item" ]]; then
                rm -f "$item" && log_info "Removed file: $item"
            fi
        done

        grep -E '^template:' "$manifest" 2>/dev/null | cut -d: -f3- | while read -r item; do
            if [[ -f "$item" ]]; then
                rm -f "$item" && log_info "Removed file: $item"
            fi
        done

        grep -E '^directory:' "$manifest" 2>/dev/null | cut -d: -f2- | _reverse_lines | while read -r item; do
            if [[ -d "$item" ]] && [[ -z "$(ls -A "$item" 2>/dev/null)" ]]; then
                rmdir "$item" && log_info "Removed directory: $item"
            fi
        done
    fi

    # Remove manifest directory
    rm -rf .zzcollab
    log_success "Uninstall complete"
}

cmd_list() {
    local list_type="${1:-}"

    case "$list_type" in
        profiles)
            require_module "profiles"
            list_profiles
            ;;
        libs)
            require_module "profiles"
            list_library_bundles
            ;;
        pkgs)
            require_module "profiles"
            list_package_bundles
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
    case "$topic" in
        nav|navigation) cmd_nav --help ;;
        validate) cmd_validate --help 2>/dev/null || true ;;
        uninstall) cmd_uninstall --help ;;
        *) show_help "$topic" ;;
    esac
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
        zzc_read -r -p "Choice [1]: " choice
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

    # Ensure image exists (prompts to build if not)
    ensure_docker_image_built "$project_name" || return 1

    # Get DockerHub username from config or environment
    # Priority: DOCKERHUB_ACCOUNT env > docker.account > defaults.dockerhub_account
    require_module "config"
    load_config 2>/dev/null || true
    local dockerhub_user="${DOCKERHUB_ACCOUNT:-${CONFIG_DOCKER_ACCOUNT:-${CONFIG_DOCKERHUB_ACCOUNT:-}}}"

    if [[ -z "$dockerhub_user" ]]; then
        if [[ ! -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
            log_error "DockerHub username not configured"
            echo "  Set with: zzc config set docker-account <username>" >&2
            return 1
        fi
        zzc_read -r -p "DockerHub username: " dockerhub_user
        if [[ -z "$dockerhub_user" ]]; then
            log_error "DockerHub username required"
            return 1
        fi
        local _save
        zzc_read -r -p "Save to config? [Y/n]: " _save
        if [[ ! "$_save" =~ ^[Nn]$ ]]; then
            config_set "docker-account" "$dockerhub_user"
        fi
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

    # Existing project → check if anything needs to be done
    if is_workspace_initialized; then
        local current_profile
        current_profile=$(config_get "profile-name" true 2>/dev/null || echo "")
        local project_name
        project_name=$(basename "$(pwd)")
        local image_exists=false
        docker image inspect "$project_name" &>/dev/null && image_exists=true

        # Check if profile matches and files exist (don't require Docker image)
        if [[ "$current_profile" == "$profile" ]] && [[ -f "Dockerfile" ]]; then
            log_success "Project already configured with '$profile' profile"
            if [[ "$image_exists" == "true" ]]; then
                echo "  Docker image '$project_name' exists" >&2
                echo "  To develop:  make r" >&2
            else
                echo "  To build:    zzc docker" >&2
            fi
            echo "  To rebuild:  zzc docker --force" >&2
            return 0
        fi

        # Profile change requested
        if [[ "$current_profile" != "$profile" ]]; then
            log_info "Switching profile: ${current_profile:-<none>} → $profile"
            config_set "profile-name" "$profile" true 2>/dev/null || true

            # Update .Rprofile from template
            if [[ -f "$ZZCOLLAB_TEMPLATES_DIR/.Rprofile" ]]; then
                cp "$ZZCOLLAB_TEMPLATES_DIR/.Rprofile" .Rprofile
                log_success "Updated .Rprofile from template"
            fi

            # Update Makefile from template
            if [[ -f "$ZZCOLLAB_TEMPLATES_DIR/Makefile" ]]; then
                cp "$ZZCOLLAB_TEMPLATES_DIR/Makefile" Makefile
                log_success "Updated Makefile from template"
            fi

            # Regenerate Dockerfile with new profile
            export BASE_IMAGE="$base_image"
            generate_dockerfile || return 1
            log_success "Dockerfile regenerated with $profile profile"

            # Prompt to build
            if [[ "${ZZCOLLAB_NO_BUILD:-false}" == "true" ]]; then
                log_info "Build later with: zzc docker"
            else
                echo ""
                local build_choice
                zzc_read -r -p "Build Docker image now? [Y/n]: " build_choice
                if [[ ! "$build_choice" =~ ^[Nn]$ ]]; then
                    build_docker_image || return 1
                else
                    log_info "Build later with: zzc docker"
                fi
            fi
        else
            # Same profile, missing Dockerfile
            log_info "Generating missing Dockerfile for profile: $profile"
            export BASE_IMAGE="$base_image"
            generate_dockerfile || return 1
            log_success "Dockerfile generated with $profile profile"
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

    zzc_read -r -p "Continue? [Y/n]: " confirm
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
    config_set "profile-name" "$profile" true 2>/dev/null || true
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

    if [[ "${ZZCOLLAB_NO_BUILD:-false}" == "true" ]]; then
        echo ""
        log_info "Build later with: make docker-build"
    else
        local build_choice
        zzc_read -r -p "Build Docker image now? [Y/n]: " build_choice
        if [[ ! "$build_choice" =~ ^[Nn]$ ]]; then
            echo ""
            build_docker_image || return 1
            echo ""
            log_success "Ready! Run 'make r' to start development"
        else
            echo ""
            log_info "Build later with: make docker-build"
        fi
    fi

    return 0
}

#=============================================================================
# REMOVE COMMANDS
#=============================================================================

cmd_rm() {
    local feature="${1:-}"
    shift || true  # Remove feature from args, keep remaining flags

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
            cmd_rm_all "$@"  # Pass through flags like -f, --force
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
            removed=$((removed + 1))
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
    zzc_read -r -p "Continue? [y/N]: " confirm
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
    # If manifest exists, use manifest-based uninstall (preferred)
    if [[ -f ".zzcollab/manifest.json" ]] || [[ -f ".zzcollab/manifest.txt" ]]; then
        echo ""
        log_info "Found zzcollab manifest - using manifest-based removal"
        echo "  Note: .git/ will NOT be removed (use 'zzc rm git' separately)"
        echo ""
        cmd_uninstall "$@"
        return $?
    fi

    # Fallback for legacy projects without manifest
    echo ""
    log_warn "No manifest found - using legacy removal (hardcoded file list)"
    echo ""
    echo "  Directories: R/, analysis/, tests/, man/, vignettes/, docs/, .github/"
    echo "  Files:       Dockerfile, Makefile, DESCRIPTION, NAMESPACE, LICENSE,"
    echo "               renv.lock, .Rprofile, .Rbuildignore, .gitignore"
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
  build          Build Docker image (uses content-addressable cache)
  rm <feature>   Remove: docker, renv, git, github, cicd
  uninstall      Remove all zzcollab files (uses manifest)
  validate       Check project structure
  config         Configuration management
  list           List profiles, libs, packages
  nav            Navigation shortcuts
  help           Show help

Options:
  -b, --build      Build Docker image after generating
  --no-build       Skip Docker build prompt
  --tag <tag>      DockerHub image tag (default: latest)
  --private        Create private GitHub repo (default)
  --public         Create public GitHub repo
  -v, --verbose    More output
  -q, --quiet      Errors only
  -y, --yes        Accept defaults (non-interactive)
  -Y, --yes-all    Same as -y

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

    # Advisory: one-line warning if workspace templates are behind
    warn_if_templates_outdated

    # Pre-scan: extract global flags regardless of position
    local _filtered=()
    for _arg in "$@"; do
        case "$_arg" in
            -v|--verbose)          export VERBOSITY_LEVEL=2 ;;
            -q|--quiet)            export VERBOSITY_LEVEL=0 ;;
            -y|--yes|-Y|--yes-all) export ZZCOLLAB_ACCEPT_DEFAULTS=true ;;
            --no-build)            export ZZCOLLAB_NO_BUILD=true ;;
            *)                     _filtered+=("$_arg") ;;
        esac
    done
    set -- ${_filtered[@]+"${_filtered[@]}"}

    # Track if any command was executed
    local commands_run=0

    # Process commands
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                echo "zzcollab ${ZZCOLLAB_VERSION:-2.0.0}"
                exit 0
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;

            init)
                cmd_init
                commands_run=$((commands_run + 1))
                shift
                ;;
            renv)
                cmd_renv
                commands_run=$((commands_run + 1))
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
                commands_run=$((commands_run + 1))
                ;;
            git)
                cmd_git
                commands_run=$((commands_run + 1))
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
                commands_run=$((commands_run + 1))
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
                commands_run=$((commands_run + 1))
                ;;
            # Standalone profile flag (same as profile name command)
            -r|--profile)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "-r/--profile requires a name"
                    exit 1
                fi
                local profile_name="$1"
                shift
                cmd_quickstart "$profile_name"
                commands_run=$((commands_run + 1))
                ;;

            # Remove command
            rm)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "rm requires a feature name"
                    log_info "Features: docker, renv, git, github, cicd, all"
                    exit 1
                fi
                local rm_feature="$1"
                shift
                # Pass remaining args (e.g., -f, --force) to cmd_rm
                cmd_rm "$rm_feature" "$@"
                commands_run=$((commands_run + 1))
                # Consume any flags that were passed
                while [[ $# -gt 0 ]] && [[ "$1" == -* ]]; do
                    shift
                done
                ;;

            # Profile names as standalone commands → full quickstart
            minimal|analysis|publishing|rstudio|shiny|verse|tidyverse)
                local profile_name="$1"
                shift
                cmd_quickstart "$profile_name"
                commands_run=$((commands_run + 1))
                ;;

            # Other commands that pass through
            build)
                shift
                cmd_build "$@"
                exit $?
                ;;
            validate)
                shift
                cmd_validate "$@"
                exit $?
                ;;
            check-updates)
                shift
                cmd_check_updates "$@"
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
