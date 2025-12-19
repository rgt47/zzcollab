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
  config     Configuration management (list, get, set)
  help       Show help for a topic

Options (global):
  -v, --verbose    Increase verbosity
  -q, --quiet      Suppress non-error output
  --version        Show version

Examples:
  zzcollab init                      # Interactive project setup
  zzcollab init -n myproject         # Create project with name
  zzcollab docker --build            # Generate and build Docker image
  zzcollab validate                  # Check project structure
  zzcollab config list               # Show configuration
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
            --help|-h) show_docker_help; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Set environment for docker module
    [[ -n "$r_version" ]] && export R_VERSION="$r_version"
    [[ -n "$base_image" ]] && export BASE_IMAGE="$base_image"
    [[ -n "$profile" ]] && BASE_IMAGE=$(get_profile_base_image "$profile")

    # Generate Dockerfile
    generate_dockerfile || exit 1

    # Build if requested
    if [[ "$build_image" == "true" ]]; then
        build_docker_image || exit 1
    fi
}

cmd_validate() {
    require_module "validation"

    local check_all=false
    local check_structure=false
    local check_packages=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a) check_all=true; shift ;;
            --structure|-s) check_structure=true; shift ;;
            --packages|-p) check_packages=true; shift ;;
            --help|-h)
                cat << 'EOF'
Usage: zzcollab validate [options]

Options:
  -a, --all        Run all validations
  -s, --structure  Check directory structure
  -p, --packages   Check R package dependencies
  -h, --help       Show this help
EOF
                exit 0
                ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Default to all if nothing specified
    if [[ "$check_all" == "false" && "$check_structure" == "false" && "$check_packages" == "false" ]]; then
        check_all=true
    fi

    local exit_code=0

    if [[ "$check_all" == "true" || "$check_structure" == "true" ]]; then
        log_info "Validating project structure..."
        validate_project_structure || exit_code=1
    fi

    if [[ "$check_all" == "true" || "$check_packages" == "true" ]]; then
        log_info "Validating R packages..."
        validate_r_packages || exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "All validations passed"
    else
        log_error "Some validations failed"
    fi

    return $exit_code
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

cmd_help() {
    require_module "help"

    local topic="${1:-}"

    if [[ -z "$topic" ]]; then
        show_usage
    else
        case "$topic" in
            init) show_init_help ;;
            docker) show_docker_help ;;
            validate) show_validate_help 2>/dev/null || log_info "Validate: Check project structure" ;;
            config) show_config_help ;;
            github) show_github_help ;;
            workflow) show_workflow_help ;;
            renv) show_renv_help ;;
            *) log_error "Unknown help topic: $topic"; show_usage ;;
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
        init)     cmd_init "$@" ;;
        docker)   cmd_docker "$@" ;;
        validate) cmd_validate "$@" ;;
        config)   cmd_config "$@" ;;
        help)     cmd_help "$@" ;;
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
