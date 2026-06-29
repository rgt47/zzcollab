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
# PROFILES (quickstart in a new directory: init + renv + docker):
#   zzcollab analysis                Tidyverse compendium (recommended)
#   zzcollab minimal | rstudio
#
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
# LOAD FOUNDATION LIBRARIES AND ALL MODULES
#=============================================================================

# Validate installation
if [[ ! -d "$ZZCOLLAB_LIB_DIR" ]]; then
    log_error "Library directory not found: $ZZCOLLAB_LIB_DIR"
    log_error "Run the installer or check your installation"
    exit 1
fi

# shellcheck source=/dev/null
source "$ZZCOLLAB_LIB_DIR/constants.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_LIB_DIR/core.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_LIB_DIR/templates.sh"

# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/cli.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/config.sh"
source "$ZZCOLLAB_MODULES_DIR/config-ui.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/profiles.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/project.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/docker.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/github.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/help.sh"
# shellcheck source=/dev/null
source "$ZZCOLLAB_MODULES_DIR/status.sh"

source "$ZZCOLLAB_MODULES_DIR/verify.sh"

source "$ZZCOLLAB_MODULES_DIR/toggle.sh"
# Note: doctor.sh is executed as a standalone script by cmd_doctor, not sourced.

#=============================================================================
# WORKSPACE INITIALIZATION HELPER
#=============================================================================

# Check if zzcollab workspace is initialized (DESCRIPTION exists)
# Returns 0 if initialized, 1 if not
is_workspace_initialized() {
    [[ -f "DESCRIPTION" ]]
}

# Run setup_project; on failure, roll back the partial scaffold by removing the
# top-level entries it newly created. A snapshot taken before scaffolding means
# pre-existing files are never removed (safe even under --force). This avoids a
# half-created directory without re-introducing a manifest.
setup_project_safe() {
    local _before
    _before=$(find . -maxdepth 1 -mindepth 1 2>/dev/null)
    if setup_project; then
        return 0
    fi
    local _entry
    while IFS= read -r _entry; do
        [[ -z "$_entry" ]] && continue
        grep -qxF -- "$_entry" <<< "$_before" || rm -rf -- "$_entry"
    done < <(find . -maxdepth 1 -mindepth 1 2>/dev/null)
    log_warn "Initialization failed; rolled back the partial scaffold."
    return 1
}

# Ensure zzcollab workspace exists, prompt to create if not
# Returns 0 on success, 1 on failure/cancel
ensure_workspace_initialized() {
    local context="${1:-operation}"

    if is_workspace_initialized; then
        return 0
    fi

    echo "" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "  No zzcollab workspace detected" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  The '$context' command requires an initialized workspace." >&2
    echo "  This creates a zzcollab research compendium structure:" >&2
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

    # Get package name from directory
    PKG_NAME=$(basename "$(pwd)")
    PKG_NAME=$(echo "$PKG_NAME" | tr '-' '.' | tr '[:upper:]' '[:lower:]')
    export PKG_NAME

    # Guard against accidental scaffolding in an occupied directory. The lazy
    # auto-init path (zzc docker / zzc renv) must not bypass the same check
    # that 'init' and the profile quickstart use.
    assert_safe_init_directory || return 1

    log_info "Initializing workspace: $PKG_NAME"
    setup_project_safe || {
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

# Prompt whether to build the Docker image now.
# Returns 0 if the user wants to build, 1 to skip.
prompt_build_now() {
    local _choice
    zzc_read -r -p "Build Docker image now? [Y/n]: " _choice
    [[ ! "$_choice" =~ ^[Nn]$ ]]
}

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

    build_docker_image "$project_name"
}

#=============================================================================
# SUBCOMMAND ROUTING
#=============================================================================

# Note: main show_usage() defined later in file

# shellcheck disable=SC2120
cmd_init() {
    local force=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f) force=true; shift ;;
            --archetype) ZZCOLLAB_ARCHETYPE="$2"; shift 2 ;;
            *) break ;;
        esac
    done

    if [[ "$force" == "false" ]]; then
        assert_safe_init_directory || exit 1
    fi

    # Validate package name
    PKG_NAME=$(validate_package_name)
    export PKG_NAME

    # Load config: user-level (~/.zzcollab/config.yaml) then project-level
    # (./zzcollab.yaml). Project values override user values.
    load_config 2>/dev/null || true

    # Bring an existing user config up to the current schema (adds any missing
    # sections without touching values already set). Interactive runs only, so
    # scripted/CI invocations never rewrite the user's config unexpectedly.
    if [[ -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
        config_backfill_schema "$CONFIG_USER"
        load_config 2>/dev/null || true
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Initializing: $PKG_NAME"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Phase 1: Identity. Prompts for required fields (name, email) when absent;
    # when already set, offers an optional update pre-filled with current values.
    config_identity_review || exit 1
    load_config 2>/dev/null || true

    # Phase 2: Project overrides (per-project, writes to ./zzcollab.yaml only).
    # Skipped in non-interactive and accept-defaults modes.
    if [[ -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
        config_project_prompt "$PKG_NAME" || exit 1
        load_config 2>/dev/null || true
    fi

    # Archetype question (plan §9.4, the creation-time scaffolding axis). An
    # explicit --archetype flag or a configured default wins; otherwise ask
    # interactively. Skipped under accept-defaults (uses config/analysis), and
    # safe when stdin is closed (zzc_read returns the default on EOF).
    if [[ -z "${ZZCOLLAB_ARCHETYPE:-}" ]] && [[ -z "${CONFIG_ARCHETYPE:-}" ]] \
       && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
        local _arch
        if has_gum && [[ -t 0 ]]; then
            _arch=$(gum_choose "Research archetype (scaffolding + render gate)" \
                analysis manuscript package simulation blog) || _arch="analysis"
        else
            # || true: read returns non-zero on EOF (closed stdin), which would
            # otherwise abort init under set -e; fall back to the default.
            _arch=""
            zzc_read -r -p "Archetype [analysis/manuscript/package/simulation/blog] (default analysis): " _arch || true
            _arch="${_arch:-analysis}"
        fi
        ZZCOLLAB_ARCHETYPE="$_arch"
    fi

    # Export template-substitution vars and the resolved BASE_IMAGE from the
    # final config, for envsubst and Dockerfile generation in setup_project.
    init_export_config_vars

    # Run project setup
    setup_project_safe || exit 1

    # Every zzcollab project carries a state record, so no-Docker compendia have
    # provenance and the toggle commands never hit a missing-state fallback.
    # Write a minimal record (R version from config/default; environment fields
    # empty until Docker is added) only when none exists, so a fuller record
    # written by a later 'zzc docker' or an existing project is not clobbered.
    if [[ ! -f .zzcollab-state ]]; then
        _zzc_write_state "${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}" "" "" "" "" "${ARCHETYPE:-analysis}"
    fi
    # Record the archetype in the project config too (plan §9.4: both places).
    config_set "archetype" "${ARCHETYPE:-analysis}" true >/dev/null 2>&1 || true

    log_success "Project setup complete"
    echo ""
    echo "  To change user-level defaults:     zzc config set KEY VALUE"
    echo "  To change project-level overrides: zzc config set-local KEY VALUE"
    echo ""

    # Legacy mode: profile specified via CLI -- go straight to docker
    if [[ "${USER_PROVIDED_PROFILE:-false}" == "true" ]]; then
        cmd_docker --profile "$PROFILE_NAME"
        return $?
    fi

    # Phase 3: Reproducibility setup, via the shared feature wizard (init mode:
    # recommends renv + Docker; makes no changes under accept-defaults).
    run_feature_wizard init
    return 0
}

# Sync template substitution variables (AUTHOR_NAME etc., used by envsubst in
# setup_project) and the resolved BASE_IMAGE from the final config. A CLI
# --profile flag takes precedence over the configured profile.
init_export_config_vars() {
    [[ -n "${CONFIG_AUTHOR_NAME:-}" ]]    && AUTHOR_NAME="$CONFIG_AUTHOR_NAME"
    [[ -n "${CONFIG_AUTHOR_EMAIL:-}" ]]   && AUTHOR_EMAIL="$CONFIG_AUTHOR_EMAIL"
    [[ -n "${CONFIG_GITHUB_ACCOUNT:-}" ]] && GITHUB_ACCOUNT="$CONFIG_GITHUB_ACCOUNT"
    [[ -n "${CONFIG_TEAM_NAME:-}" ]]      && TEAM_NAME="$CONFIG_TEAM_NAME"
    export AUTHOR_NAME AUTHOR_EMAIL GITHUB_ACCOUNT TEAM_NAME

    local profile_name base_image
    if [[ "${USER_PROVIDED_PROFILE:-false}" == "true" ]] && [[ -n "${PROFILE_NAME:-}" ]]; then
        profile_name="$PROFILE_NAME"
    else
        profile_name="${CONFIG_PROFILE_NAME:-minimal}"
    fi
    base_image=$(get_profile_base_image "$profile_name")
    export BASE_IMAGE="$base_image"

    # Research archetype (init-time scaffolding axis): flag > config > analysis.
    export ARCHETYPE="${ZZCOLLAB_ARCHETYPE:-${CONFIG_ARCHETYPE:-analysis}}"
    case "$ARCHETYPE" in
        manuscript|analysis|package|simulation|blog) ;;
        *) log_warn "Unknown archetype '$ARCHETYPE'; using 'analysis'."
           export ARCHETYPE="analysis" ;;
    esac
}

# The init reproducibility prompt and its summary were replaced by the shared
# run_feature_wizard (modules/toggle.sh); cmd_init now calls that in init mode.

cmd_docker() {

    local build_image=""
    local r_version=""
    local base_image=""
    local profile=""
    local no_renv=""
    # Global flags (-v/-q/-y/--no-build) are consumed by the pre-scan in main()
    # before this runs, so they are not handled here.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build|-b) build_image=true; shift ;;
            --r-version) r_version="$2"; shift 2 ;;
            --base-image) base_image="$2"; shift 2 ;;
            --profile|-r) profile="$2"; shift 2 ;;
            --no-renv) no_renv=true; shift ;;
            help|--help|-h) show_help_docker; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Validate a user-supplied base image before doing any work
    [[ -n "$base_image" ]] && { validate_base_image "$base_image" || exit 1; }

    # Ensure zzcollab workspace is initialized
    ensure_workspace_initialized "docker" || exit 1

    # Check for outdated templates and prompt to update
    check_and_prompt_outdated_templates

    # Resolve base image first so we can validate r_version against published
    # tags before writing renv.lock (avoids R version / Docker tag mismatch).
    [[ -n "$base_image" ]] && export BASE_IMAGE="$base_image"
    if [[ -n "$profile" ]]; then
        BASE_IMAGE=$(get_profile_base_image "$profile")
        export BASE_IMAGE
        config_set "profile-name" "$profile" true 2>/dev/null || true
    elif [[ -n "$base_image" ]]; then
        : # explicit --base-image already exported above
    else
        # Re-adding Docker: prefer the base image remembered in .zzcollab-state
        # (symmetry with the renv toggle) so 'zzc docker' restores the
        # previously chosen environment without re-deriving it. The record's
        # base_image is empty for a project that never had Docker, so first-time
        # setup still falls through to the configured profile. The digest is
        # re-resolved fresh by generate_dockerfile.
        local _state_base
        _state_base=$(_zzc_state_get base_image . 2>/dev/null)
        if [[ -n "$_state_base" ]]; then
            export BASE_IMAGE="${_state_base%:*}"
            [[ -z "$r_version" ]] && r_version="${_state_base##*:}"
            log_success "Reusing remembered base image: $_state_base"
        else
            load_config 2>/dev/null || true
            if [[ -n "${CONFIG_PROFILE_NAME:-}" ]]; then
                BASE_IMAGE=$(get_profile_base_image "$CONFIG_PROFILE_NAME")
                export BASE_IMAGE
            fi
        fi
    fi

    # Determine R version: CLI arg > config > default.
    if [[ -z "$r_version" ]]; then
        load_config 2>/dev/null || true
        r_version="${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}"
    fi

    # renv is the default backend: create a minimal renv.lock if absent so the
    # Dockerfile restores from it. --no-renv opts into DESCRIPTION-install mode,
    # in which the Dockerfile self-adapts to the absence of renv.lock (the
    # install step branches on presence; see modules/docker.sh). This severs
    # the old coupling that always wrote a minimal lockfile.
    if [[ "$no_renv" == "true" ]]; then
        if [[ -f "renv.lock" ]]; then
            log_warn "--no-renv given but renv.lock exists; renv mode will be used."
            log_info "Run 'zzc rm renv' first for DESCRIPTION-install mode."
        else
            log_info "--no-renv: no renv.lock; Dockerfile installs from DESCRIPTION."
        fi
    elif [[ ! -f "renv.lock" ]]; then
        log_info "No renv.lock found, creating minimal lockfile..."
        create_renv_lock_minimal "$r_version"
    fi

    export R_VERSION="$r_version"

    # Generate Dockerfile + renv.lock (wizard handles new workspaces)
    generate_dockerfile || exit 1

    if [[ "$build_image" == "true" ]]; then
        build_docker_image || exit 1
    elif [[ "${ZZCOLLAB_NO_BUILD:-false}" == "true" ]]; then
        log_info "Build with: make docker-build"
    elif [[ -t 0 ]] || [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
        echo ""
        if prompt_build_now; then
            build_docker_image || exit 1
        else
            log_info "Build later with: make docker-build"
        fi
    else
        log_info "Build with: make docker-build"
    fi
}

cmd_build() {

    local no_cache="false"
    local log_file=""
    local project_name
    project_name=$(basename "$(pwd)")

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-cache) no_cache="true"; shift ;;
            --log)      log_file="docker-build.log"; shift ;;
            help|--help|-h)
                cat << 'HELPEOF'
REBUILD DOCKER IMAGE

Rebuilds the project's Docker image using the content-addressable cache.
If an image with the same Dockerfile+renv.lock hash exists, it is retagged
instead of rebuilt. To generate the Dockerfile and build in one step,
use 'zzcollab docker --build' instead.

USAGE:
    zzcollab rebuild [OPTIONS]

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
        build_docker_image "$project_name" "$no_cache" \
            2>&1 | tee "$log_file"
    else
        build_docker_image "$project_name" "$no_cache"
    fi
}

# shellcheck disable=SC2120
cmd_renv() {

    local r_version=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --r-version) r_version="$2"; shift 2 ;;
            help|--help|-h)
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

    # Ensure zzcollab workspace is initialized
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
        cran_version="${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}"
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

    # Create .Rprofile from template (always overwrite to ensure latest
    # version). Use regenerate_template_file, not a raw copy, so the
    # $ZZCOLLAB_TEMPLATE_VERSION stamp and other template variables are
    # substituted; a raw safe_cp left the literal stamp, which doctor then
    # reported as "(no stamp)".
    if [[ -f "$ZZCOLLAB_TEMPLATES_DIR/.Rprofile" ]]; then
        regenerate_template_file ".Rprofile" ".Rprofile" ".Rprofile"
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
        # utils:: qualifier: this runs while .Rprofile is sourced, when only
        # the base package is attached, so bare install.packages() is not yet
        # on the search path (see ?Startup).
        utils::install.packages("renv", repos = "https://cloud.r-project.org")
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

    # Symmetric to cmd_rm_renv: a present Dockerfile may have been generated in
    # DESCRIPTION-install mode. renv.lock now exists, so regenerate it to flip
    # to renv-restore mode; otherwise adding renv leaves the image installing
    # from DESCRIPTION and ignoring the lockfile. Base image and R version come
    # from .zzcollab-state to avoid the interactive wizard.
    if [[ -f "Dockerfile" ]]; then
        local _sb _sr
        _sb=$(_zzc_state_get base_image . 2>/dev/null)
        _sr=$(_zzc_state_get r_version . 2>/dev/null)
        if [[ -n "$_sb" ]]; then
            export BASE_IMAGE="${_sb%:*}"
            export R_VERSION="${_sr:-${_sb##*:}}"
            if generate_dockerfile >/dev/null 2>&1; then
                echo "  Dockerfile regenerated in renv-restore mode"
                echo "  rebuild to apply:  make docker-build"
            else
                log_warn "Could not regenerate Dockerfile; run 'zzc docker' manually."
            fi
        else
            log_warn "Dockerfile present but no .zzcollab-state."
            echo "  Run 'zzc docker' to switch it to renv-restore mode."
        fi
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

    # Offer to save R version to config. This is optional convenience and must
    # never fail the command: skip the prompt entirely when non-interactive
    # (no tty or accept-defaults), and keep config_set non-fatal otherwise so a
    # write failure or EOF does not abort zzc renv under set -e.
    if [[ -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
        local save_config
        zzc_read -r -p "Save R version to config? [Y/n]: " save_config || true
        if [[ ! "$save_config" =~ ^[Nn]$ ]]; then
            config_set "r-version" "$r_version" || true
        fi
    fi
}

# cmd_data - data-integrity toggle (capture feature). Writes a sha256 manifest
# of the immutable raw-data directory so later silent mutations are detectable.
# Presence of data-manifest.sha256 is the feature's on state (zzc status); zzc
# verify checks the data still matches it. Mirrors the Makefile hash-data target
# so the manifest is identical whether written from the CLI or `make hash-data`.
cmd_data() {
    case "${1:-}" in
        help|--help|-h)
            cat << 'EOF'
DATA INTEGRITY

Writes a sha256 manifest of the raw-data directory (analysis/data/raw_data)
so any later mutation of immutable source data is detectable.

USAGE:
    zzcollab data        # write/refresh data-manifest.sha256
    zzcollab rm data     # remove the manifest (feature off)

The manifest is the feature's presence signal. Commit it; refresh with
'zzc data' after intentional data updates. 'zzc verify' checks the data
against it. Equivalent to 'make hash-data' / 'make verify-data'.
EOF
            return 0 ;;
    esac

    ensure_workspace_initialized "data" || exit 1

    local raw="analysis/data/raw_data"
    if [[ ! -d "$raw" ]]; then
        log_error "No $raw directory found; nothing to hash."
        log_info "Place immutable source data in $raw, then run 'zzc data'."
        return 1
    fi
    if ! command -v shasum >/dev/null 2>&1; then
        log_error "shasum not found; cannot write the data manifest."
        return 1
    fi

    local files
    files=$(find "$raw" -type f | sort)
    if [[ -z "$files" ]]; then
        log_warn "No files under $raw; manifest not written."
        return 1
    fi
    printf '%s\n' "$files" | xargs shasum -a 256 > data-manifest.sha256

    local n
    n=$(wc -l < data-manifest.sha256 | tr -d ' ')
    log_success "Wrote data-manifest.sha256 (${n} file(s) under $raw)"
    echo "  Commit it so later data mutations are detectable."
    echo "  Refresh after intentional updates:  zzc data"
    echo "  Check the data against it:          zzc verify"
}

# cmd_code_quality - code-quality toggle (validation feature). Installs a
# .pre-commit-config.yaml driving styler and lintr. Presence is the feature's
# on state (zzc status); it captures nothing, so it does not move the level.
cmd_code_quality() {
    case "${1:-}" in
        help|--help|-h)
            cat << 'EOF'
CODE QUALITY

Installs a .pre-commit-config.yaml that runs styler and lintr (plus hygiene
checks) on staged R code before each commit.

USAGE:
    zzcollab code-quality     # install .pre-commit-config.yaml
    zzcollab rm code-quality  # remove it (feature off)

Activate the hooks after installing:
    pip install pre-commit    # or: brew install pre-commit
    pre-commit install
    pre-commit run --all-files
EOF
            return 0 ;;
    esac

    ensure_workspace_initialized "code-quality" || exit 1

    if [[ -f ".pre-commit-config.yaml" ]]; then
        log_info ".pre-commit-config.yaml already present; refreshing from template."
    fi
    if regenerate_template_file ".pre-commit-config.yaml" \
           ".pre-commit-config.yaml" "pre-commit config"; then
        echo ""
        echo "  Code-quality hooks installed (styler + lintr)."
        echo "  Activate them:"
        echo "    pip install pre-commit    # or: brew install pre-commit"
        echo "    pre-commit install"
        echo "    pre-commit run --all-files"
    else
        log_error "Failed to install .pre-commit-config.yaml"
        return 1
    fi
}

cmd_rm_code_quality() {
    if [[ -f ".pre-commit-config.yaml" ]]; then
        rm -f ".pre-commit-config.yaml"
        log_success "Removed .pre-commit-config.yaml (code-quality off)"
        log_info "Pre-commit git hooks, if installed, remain; run 'pre-commit uninstall' to remove them."
    else
        log_info "No .pre-commit-config.yaml to remove"
    fi
}

# cmd_tests - unit-testing toggle (validation feature). Scaffolds the tinytest
# infrastructure (tests/tinytest.R + inst/tinytest/). Presence of inst/tinytest/
# is the feature's on state (zzc status). Reuses the init scaffolder so the
# layout is identical whether created at init or added later.
cmd_tests() {
    case "${1:-}" in
        help|--help|-h)
            cat << 'EOF'
UNIT TESTING (tinytest)

Scaffolds tests/tinytest.R and inst/tinytest/ with an example test.

USAGE:
    zzcollab tests        # scaffold the tinytest infrastructure
    zzcollab rm tests     # remove it (feature off)

Run the tests with:  make test   (or: make docker-test)
EOF
            return 0 ;;
    esac

    ensure_workspace_initialized "tests" || exit 1
    export PKG_NAME="${PKG_NAME:-$(basename "$(pwd)" | tr '-' '.' | tr '[:upper:]' '[:lower:]')}"
    create_test_infrastructure
    echo ""
    echo "  Add tests under inst/tinytest/ (bare expect_*() expressions)."
    echo "  Run them:  make test    (or: make docker-test)"
}

cmd_rm_tests() {
    local removed=0
    [[ -d "inst/tinytest" ]]   && rm -rf "inst/tinytest"   && removed=1
    [[ -f "tests/tinytest.R" ]] && rm -f "tests/tinytest.R" && removed=1
    # Leave tests/ itself (it may hold testthat); prune only if now empty.
    [[ -d "tests" ]] && rmdir "tests" 2>/dev/null || true
    if [[ "$removed" -eq 1 ]]; then
        log_success "Removed unit tests (inst/tinytest/, tests/tinytest.R)"
    else
        log_info "No tinytest infrastructure to remove"
    fi
}

# cmd_cloud - cloud-launch toggle (+ platform parameter). Scaffolds a
# browser-launchable container config. Presence of .devcontainer/ (or .binder/)
# is the feature's on state (zzc status). devcontainer drives VS Code / GitHub
# Codespaces; binder is recognised by status but not yet templated.
cmd_cloud() {
    local platform=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform) platform="$2"; shift 2 ;;
            help|--help|-h)
                cat << 'EOF'
CLOUD LAUNCH

Scaffolds a config that lets the compendium run in a browser-based
container.

USAGE:
    zzcollab cloud                       # platform by forge (see below)
    zzcollab cloud --platform devcontainer   # GitHub Codespaces / VS Code
    zzcollab cloud --platform workspace      # GitLab Workspaces (.devfile.yaml)
    zzcollab rm cloud                    # remove cloud config

Platforms: devcontainer (GitHub Codespaces / VS Code) and workspace
(GitLab Workspaces). With no --platform, the default follows the
configured forge (workspace when forge=gitlab, else devcontainer).
binder is detected by 'zzc status' but not yet templated.
EOF
                return 0 ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    ensure_workspace_initialized "cloud" || exit 1

    # Default platform follows the forge: GitLab Workspaces for forge=gitlab,
    # GitHub Codespaces (devcontainer) otherwise.
    if [[ -z "$platform" ]]; then
        load_config 2>/dev/null || true
        [[ "${CONFIG_FORGE:-github}" == gitlab ]] && platform="workspace" || platform="devcontainer"
    fi

    case "$platform" in
        devcontainer)
            if [[ ! -f "$ZZCOLLAB_TEMPLATES_DIR/devcontainer.json" ]]; then
                log_error "devcontainer template not found."
                return 1
            fi
            mkdir -p ".devcontainer"
            install_template "devcontainer.json" ".devcontainer/devcontainer.json" \
                "devcontainer config"
            echo ""
            echo "  Cloud launch (devcontainer) enabled."
            echo "  Open in GitHub Codespaces, or VS Code: 'Reopen in Container'."
            ;;
        workspace)
            if [[ ! -f "$ZZCOLLAB_TEMPLATES_DIR/gitlab/devfile.yaml" ]]; then
                log_error "GitLab Workspaces devfile template not found."
                return 1
            fi
            install_template "gitlab/devfile.yaml" ".devfile.yaml" \
                "GitLab Workspaces devfile"
            echo ""
            echo "  Cloud launch (GitLab Workspaces) enabled."
            echo "  Launch from the GitLab project: Edit > New workspace."
            ;;
        binder)
            log_error "binder platform is not yet templated; use --platform devcontainer or workspace."
            return 1 ;;
        *)
            log_error "Unknown platform: $platform (supported: devcontainer, workspace)"
            return 1 ;;
    esac
}

cmd_rm_cloud() {
    local removed=0
    [[ -d ".devcontainer" ]] && rm -rf ".devcontainer" && removed=1
    [[ -d ".binder" ]]       && rm -rf ".binder"       && removed=1
    [[ -f ".devfile.yaml" ]] && rm -f ".devfile.yaml"  && removed=1
    if [[ "$removed" -eq 1 ]]; then
        log_success "Removed cloud launch config (.devcontainer/, .binder/, and/or .devfile.yaml)"
    else
        log_info "No cloud launch config to remove"
    fi
}

# cmd_nix - Nix backend (capture choice, mutually exclusive with renv). Writes a
# starter flake.nix pinning the whole environment to one nixpkgs revision (L2
# without a container). Presence of flake.nix/default.nix is the backend's on
# state (zzc status); flake.lock is the exact pin (the renv.lock analogue).
cmd_nix() {
    case "${1:-}" in
        help|--help|-h)
            cat << 'EOF'
NIX BACKEND

Writes a starter flake.nix that pins R, packages, and system libraries to
one nixpkgs revision - reproducibility level L2 without a container.

USAGE:
    zzcollab nix          # write flake.nix
    zzcollab rm nix       # remove the Nix files

Next steps:
    nix flake update      # write flake.lock (the exact pin)
    nix develop           # enter the environment

Nix and renv are mutually exclusive backends; switch between them with
'zzc toggle'. For exact DESCRIPTION-tracked packages, regenerate the flake
with rix::rix().
EOF
            return 0 ;;
    esac

    ensure_workspace_initialized "nix" || exit 1

    if [[ -f renv.lock ]]; then
        log_error "renv.lock present: renv and Nix are mutually exclusive backends."
        log_info "Switch with 'zzc toggle' (backend: nix), or run 'zzc rm renv' first."
        return 1
    fi
    if [[ -f flake.nix || -f default.nix ]]; then
        log_info "Nix backend already present (flake.nix/default.nix)."
        return 0
    fi
    if [[ ! -f "$ZZCOLLAB_TEMPLATES_DIR/flake.nix" ]]; then
        log_error "flake.nix template not found."
        return 1
    fi

    # Copy without variable substitution: the flake uses nix ${...}
    # interpolation, which envsubst would mangle.
    safe_cp "$ZZCOLLAB_TEMPLATES_DIR/flake.nix" flake.nix
    log_success "Created flake.nix (Nix backend)"
    echo "  Pin and enter the environment:"
    echo "    nix flake update      # writes flake.lock (the exact pin)"
    echo "    nix develop           # enter the R environment"
    echo "  For exact DESCRIPTION-tracked packages, regenerate with rix::rix()."
}

cmd_rm_nix() {
    local removed=0
    for f in flake.nix default.nix flake.lock; do
        [[ -f "$f" ]] && rm -f "$f" && removed=1
    done
    if [[ "$removed" -eq 1 ]]; then
        log_success "Removed Nix backend (flake.nix/default.nix/flake.lock)"
    else
        log_info "No Nix files to remove"
    fi
}

cmd_validate() {
    # Dependency validation is delegated to the zzrenvcheck R package.
    # Runs on the host if R + zzrenvcheck are installed; otherwise advises
    # running inside the container (make check-renv).
    #
    # Defaults come from the configured validate.strict / validate.fix
    # (settable via 'zzc toggle'), and explicit flags below override them.
    load_config 2>/dev/null || true
    local strict auto_fix
    [[ "${CONFIG_VALIDATE_STRICT:-true}" == "false" ]] && strict="FALSE" || strict="TRUE"
    [[ "${CONFIG_VALIDATE_FIX:-false}"   == "true"  ]] && auto_fix="TRUE" || auto_fix="FALSE"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fix)         auto_fix="TRUE";  shift ;;
            --no-fix)      auto_fix="FALSE"; shift ;;
            --strict)      strict="TRUE";    shift ;;
            --no-strict)   strict="FALSE";   shift ;;
            --verbose|-v)  shift ;;
            help|--help|-h)
                echo "Usage: zzcollab validate [--fix|--no-fix] [--strict|--no-strict]"
                echo "Validates package dependencies via zzrenvcheck."
                echo "Inside a container, prefer: make check-renv"
                return 0 ;;
            *) shift ;;
        esac
    done

    if ! command -v Rscript >/dev/null 2>&1; then
        log_error "Rscript not found on host."
        log_info "Run validation inside the container: make check-renv"
        return 1
    fi

    Rscript -e "if (!requireNamespace('zzrenvcheck', quietly = TRUE)) {
        message('zzrenvcheck not installed. Install with: remotes::install_github(\"rgt47/zzrenvcheck\")')
        message('Or validate inside the container: make check-renv')
        quit(status = 1)
    }
    zzrenvcheck::check_packages(auto_fix = ${auto_fix}, strict = ${strict})"
}

cmd_doctor() {
    local script="$ZZCOLLAB_MODULES_DIR/doctor.sh"
    if [[ ! -f "$script" ]]; then
        log_error "doctor module not found: $script"
        return 1
    fi
    bash "$script" "$@"
}

# Static template files that 'zzc update' regenerates via a straight
# template copy. Format: "template-relative-path|destination-relative-path".
# The Dockerfile is handled separately (regenerated via generate_dockerfile,
# since its content is parameterised by renv.lock, base image, and install
# mode). User-owned paths (R/, analysis/, DESCRIPTION, renv.lock, data/) are
# never in this set.
_ZZC_UPDATE_MANAGED=(
    "Makefile|Makefile"
    ".Rprofile|.Rprofile"
    "workflows/r-package.yml|.github/workflows/r-package.yml"
    "workflows/render-report.yml|.github/workflows/render-report.yml"
    "gitlab/.gitlab-ci.yml|.gitlab-ci.yml"
    "ZZCOLLAB_USER_GUIDE.md|docs/ZZCOLLAB_USER_GUIDE.md"
)

# Print the 'vX.Y.Z' template stamp carried by a generated file, or '?' when no
# stamp is present. Read-only.
_zzc_update_stamp() {
    local f="$1"
    [[ -f "$f" ]] || { printf '?'; return 0; }
    local v
    v=$(grep -m1 -oE 'zzcollab [^ ]+ v[0-9]+\.[0-9]+\.[0-9]+' "$f" 2>/dev/null \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    printf '%s' "${v:-?}"
}

# Preview-regenerate TEMPLATE for project PROJ into a temp file and report
# whether the result differs from the current DEST. Returns 0 if it WOULD
# change, 1 if it is already current, 2 on error. Writes nothing to the project.
_zzc_update_would_change() {
    local proj="$1" tmpl="$2" dest="$3"
    local tmp
    tmp=$(mktemp) || return 2
    if ! cp "${ZZCOLLAB_TEMPLATES_DIR}/$tmpl" "$tmp" 2>/dev/null; then
        rm -f "$tmp"; return 2
    fi
    # PKG_NAME and other placeholders derive from the project directory, so run
    # the substitution with the project as the working directory.
    if ! ( cd "$proj" && substitute_variables "$tmp" ) >/dev/null 2>&1; then
        rm -f "$tmp"; return 2
    fi
    if diff -q "$proj/$dest" "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"; return 1
    fi
    rm -f "$tmp"; return 0
}

# cmd_update [DIR] [--dry-run] [--force]
# Regenerate the framework-managed template files from the current templates,
# re-stamping them to the current template version. This is the migration path
# for projects whose stamps differ from the current version in either direction
# (e.g. after a version re-baseline) -- 'doctor --fix' only bumps older stamps
# forward, so it cannot resync newer-but-stale files.
cmd_update() {
    local dir="." dry_run=false force=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)        dry_run=true; shift ;;
            -f|--force)       force=true; shift ;;
            help|--help|-h)
                cat << 'EOF'
Usage: zzcollab update [DIR] [--dry-run] [--force]

Regenerate the framework-managed files (Makefile, .Rprofile, CI workflows,
user guide, and the Dockerfile) from the current templates, re-stamping them
to the current template version. The existing Posit Package Manager pin is
preserved, and a missing .zzcollab-state record is back-filled.

Never touches user content (R/, analysis/, DESCRIPTION, renv.lock, data/). The
Dockerfile is regenerated from renv.lock/base image/install mode without
building an image.

  --dry-run   Show which files would change; write nothing.
  --force     Proceed even if the git working tree is dirty or absent.

A clean git working tree is required (changes are reversible via git) unless
--force is given.
EOF
                return 0 ;;
            -*)               log_error "Unknown option: $1"; return 1 ;;
            *)                dir="$1"; shift ;;
        esac
    done

    if [[ ! -f "$dir/.zzcollab" && ! ( -f "$dir/DESCRIPTION" && -f "$dir/Makefile" ) ]]; then
        log_error "Not a zzcollab workspace (no .zzcollab marker or DESCRIPTION+Makefile): $dir"
        return 1
    fi

    # Git is the safety net for an operation that overwrites tracked files.
    # Require a clean tree (or --force) so every change is revertible. Skip the
    # check for --dry-run, which writes nothing.
    if [[ "$dry_run" != true ]]; then
        if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            if [[ "$force" != true ]] && [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null || true)" ]]; then
                log_error "Working tree has uncommitted changes."
                log_info  "Commit or stash first (so the update is reversible), or pass --force."
                return 1
            fi
        elif [[ "$force" != true ]]; then
            log_error "$dir is not a git repository (no safety net for an overwrite)."
            log_info  "Initialise git or pass --force to proceed anyway."
            return 1
        fi
    fi

    load_config 2>/dev/null || true

    # Preserve the project's existing PPM snapshot pin and Ubuntu codename so
    # regenerating .Rprofile does not silently re-pin the repository to today's
    # date. substitute_variables honours these when exported.
    if [[ -f "$dir/.Rprofile" ]]; then
        local _pin
        _pin=$(grep -m1 -oE '__linux__/[a-z]+/[0-9]{4}-[0-9]{2}-[0-9]{2}' "$dir/.Rprofile" 2>/dev/null | head -1 || true)
        if [[ -n "$_pin" ]]; then
            local _cn="${_pin#__linux__/}"
            export UBUNTU_CODENAME="${_cn%%/*}"
            export PPM_SNAPSHOT="${_pin##*/}"
        fi
    fi

    local cur_ver="${ZZCOLLAB_TEMPLATE_VERSION:-unknown}"
    local n_changed=0 n_total=0 entry tmpl dest old
    for entry in "${_ZZC_UPDATE_MANAGED[@]}"; do
        tmpl="${entry%%|*}"; dest="${entry##*|}"
        [[ -f "$dir/$dest" ]] || continue
        n_total=$((n_total + 1))
        old=$(_zzc_update_stamp "$dir/$dest")
        if [[ "$dry_run" == true ]]; then
            if _zzc_update_would_change "$dir" "$tmpl" "$dest"; then
                printf "  %-34s %s -> v%s (would update)\n" "$dest" "$old" "$cur_ver"
                n_changed=$((n_changed + 1))
            else
                printf "  %-34s %s (current)\n" "$dest" "$old"
            fi
        else
            if ( cd "$dir" && regenerate_template_file "$tmpl" "$dest" "$dest" ) >/dev/null; then
                n_changed=$((n_changed + 1))
            else
                log_warn "Failed to regenerate $dest"
            fi
        fi
    done

    # The Dockerfile is template-derived but parameterised by renv.lock, base
    # image, and install mode, so it is regenerated via the docker path
    # (generate_dockerfile, no image build) rather than a static template copy.
    if [[ -f "$dir/Dockerfile" ]]; then
        n_total=$((n_total + 1))
        old=$(_zzc_update_stamp "$dir/Dockerfile")
        if [[ "$dry_run" == true ]]; then
            # Generating the Dockerfile resolves a base-image digest (a network
            # call) and is not side-effect-free, so preview by stamp only.
            if [[ "$old" != "v$cur_ver" ]]; then
                printf "  %-34s %s -> v%s (would update)\n" "Dockerfile" "$old" "$cur_ver"
                n_changed=$((n_changed + 1))
            else
                printf "  %-34s %s (current)\n" "Dockerfile" "$old"
            fi
        else
            if ( cd "$dir" && generate_dockerfile ) >/dev/null 2>&1; then
                n_changed=$((n_changed + 1))
            else
                log_warn "Failed to regenerate Dockerfile (run 'zzcollab docker' manually)"
            fi
        fi
    fi

    # Back-fill the generator state record if absent, reusing the doctor's
    # derive-from-artifacts logic. Skipped in dry-run (writes nothing).
    if [[ "$dry_run" != true ]] && [[ ! -f "$dir/.zzcollab-state" ]]; then
        if bash "$ZZCOLLAB_MODULES_DIR/doctor.sh" "$dir" --fix </dev/null >/dev/null 2>&1; then
            log_info "Back-filled .zzcollab-state."
        fi
    fi

    if [[ "$dry_run" == true ]]; then
        log_info "Dry run: $n_changed of $n_total managed file(s) would change. Nothing written."
    elif [[ "$n_total" -eq 0 ]]; then
        log_info "No framework-managed files found to update in $dir."
    else
        log_success "Regenerated $n_changed of $n_total managed file(s) to v${cur_ver}."
        log_info "Changes are reversible via git (e.g. git -C \"$dir\" restore <file>)."
    fi
    return 0
}

# Silent advisory: warn once if any workspace template is outdated
# Extract the 'vX.Y.Z' stamp from a stamped template file (empty if absent).
# The stamp line is '# zzcollab <file> vX.Y.Z'.
_template_stamp_version() {
    sed -n "s/^# zzcollab ${1} v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p" "$1" | head -1
}

warn_if_templates_outdated() {
    local cur="${ZZCOLLAB_TEMPLATE_VERSION:-}"
    [[ -z "$cur" ]] && return 0

    local file ver outdated=""
    for file in Makefile .Rprofile Dockerfile; do
        [[ -f "$file" ]] || continue
        ver=$(_template_stamp_version "$file")
        # Only a stamp strictly older than the current template is outdated.
        # A newer stamp (e.g. a project built with a later zzcollab, or one
        # predating a version reset) must not be flagged for a downgrade.
        if [[ -n "$ver" ]] && [[ "$(semver_cmp "$ver" "$cur")" == "-1" ]]; then
            outdated="${outdated:+$outdated, }${file} (v${ver})"
        fi
    done

    if [[ -n "$outdated" ]]; then
        printf '\033[1;33m⚠  Outdated templates: %s → v%s. Run: zzc doctor\033[0m\n' \
            "$outdated" "$cur" >&2
    fi
}

# Interactive prompt to update outdated templates before docker operations
# Returns 0 if no updates needed or user declined, 1 if updates were made
check_and_prompt_outdated_templates() {
    local cur="${ZZCOLLAB_TEMPLATE_VERSION:-}"
    [[ -z "$cur" ]] && return 0

    local file ver
    local outdated_files=()
    local unstamped_files=()

    for file in Makefile .Rprofile; do
        [[ -f "$file" ]] || continue
        ver=$(_template_stamp_version "$file")
        if [[ -z "$ver" ]]; then
            unstamped_files+=("$file")
        elif [[ "$(semver_cmp "$ver" "$cur")" == "-1" ]]; then
            # Strictly older than the current template; newer/equal is not a
            # candidate for a downgrade prompt before docker operations.
            outdated_files+=("$file (v${ver})")
        fi
    done

    # Nothing to update
    if [[ ${#outdated_files[@]} -eq 0 && ${#unstamped_files[@]} -eq 0 ]]; then
        return 0
    fi

    # Build message
    echo ""
    log_warn "Template files need updating:"
    if [[ ${#outdated_files[@]} -gt 0 ]]; then
        for item in "${outdated_files[@]}"; do
            printf "  • %s → v%s\n" "$item" "$cur"
        done
    fi
    if [[ ${#unstamped_files[@]} -gt 0 ]]; then
        for item in "${unstamped_files[@]}"; do
            printf "  • %s (no version stamp)\n" "$item"
        done
    fi
    echo ""

    # Non-interactive: skip prompt
    if [[ ! -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
        log_info "Run 'zzc doctor' for details"
        return 0
    fi

    local update_choice
    zzc_read -r -p "Update templates to v${cur}? [Y/n]: " update_choice
    if [[ "$update_choice" =~ ^[Nn]$ ]]; then
        log_info "Skipping template update"
        return 0
    fi

    # Regenerate outdated/unstamped files
    local all_files=()
    if [[ ${#outdated_files[@]} -gt 0 ]]; then
        for item in "${outdated_files[@]}"; do
            all_files+=("${item%% (*}")
        done
    fi
    if [[ ${#unstamped_files[@]} -gt 0 ]]; then
        for item in "${unstamped_files[@]}"; do
            all_files+=("$item")
        done
    fi

    for file in "${all_files[@]+"${all_files[@]}"}"; do
        if regenerate_template_file "$file" "$file" "$file"; then
            : # Success logged by function
        else
            log_error "Failed to regenerate $file"
        fi
    done

    echo ""
    return 0
}

cmd_config() {

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
        set-local)
            [[ $# -lt 2 ]] && { log_error "Usage: zzcollab config set-local KEY VALUE"; exit 1; }
            config_set "$1" "$2" "true"
            ;;
        validate)
            # Confirm each existing config file parses as valid YAML. load_config
            # returns 0 unconditionally and swallows yq parse errors, so check
            # syntax directly with `yq eval '.'`.
            command -v yq >/dev/null 2>&1 || {
                log_error "yq required to validate configuration but not found"
                return 1
            }
            local _cfg _cfg_ok=true
            for _cfg in "$CONFIG_USER" "$CONFIG_PROJECT"; do
                [[ -f "$_cfg" ]] || continue
                if yq eval '.' "$_cfg" >/dev/null 2>&1; then
                    log_info "Valid YAML: $_cfg"
                else
                    log_error "Malformed YAML: $_cfg"
                    _cfg_ok=false
                fi
            done
            if [[ "$_cfg_ok" == "true" ]]; then
                log_success "Configuration is valid"
                return 0
            else
                return 1
            fi
            ;;
        *)
            log_error "Unknown config subcommand: $subcommand"
            log_info "Valid subcommands: init, list, get, set, set-local, validate"
            log_info "Or run 'zzc config' with no args for interactive setup"
            exit 1
            ;;
    esac
}

# Shared zzcollab scaffold inventory (everything zzc generates except analysis/
# and .git/). Single source of truth so cmd_uninstall and cmd_rm_all cannot
# drift. cmd_uninstall removes this set (preserving analysis/); cmd_rm_all
# removes this set plus analysis/.
readonly ZZCOLLAB_SCAFFOLD_DIRS=(R tests man vignettes docs .github renv .zzcollab)
readonly ZZCOLLAB_SCAFFOLD_FILES=(DESCRIPTION NAMESPACE LICENSE Makefile Dockerfile
    renv.lock .Rprofile .gitignore .Rbuildignore)

cmd_uninstall() {
    local force=false
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)  force=true;   shift ;;
            -n|--dry-run) dry_run=true; shift ;;
            help|--help|-h)
                echo "Usage: zzcollab uninstall [-f|--force] [-n|--dry-run]"
                echo "Remove the zzcollab scaffold from the current project directory."
                echo "Data and analysis files are preserved."
                return 0 ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    # Shared scaffold, minus analysis/ (preserved, per --help), plus the
    # project-level zzcollab.yaml.
    local known_dirs=("${ZZCOLLAB_SCAFFOLD_DIRS[@]}")
    local known_files=("${ZZCOLLAB_SCAFFOLD_FILES[@]}" zzcollab.yaml)

    if [[ "$dry_run" == "true" ]]; then
        log_info "Would remove:"
        for d in "${known_dirs[@]}"; do [[ -e "$d" ]] && echo "  $d"; done
        for f in "${known_files[@]}"; do [[ -e "$f" ]] && echo "  $f"; done
        return 0
    fi

    if [[ "$force" != "true" ]]; then
        log_warn "This will remove the zzcollab scaffold from: $(pwd)"
        confirm "Proceed?" || return 0
    fi

    rm -rf "${known_dirs[@]}"
    rm -f  "${known_files[@]}"
    log_success "Uninstall complete"
}

cmd_list() {
    local list_type="${1:-}"

    case "$list_type" in
        profiles)
            list_profiles
            ;;
        libs)
            list_library_bundles
            ;;
        pkgs)
            list_package_bundles
            ;;
        all|"")
            cmd_list profiles
            echo ""
            cmd_list libs
            echo ""
            cmd_list pkgs
            ;;
        help|--help|-h)
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
    local topic="${1:-}"
    case "$topic" in
        validate) cmd_validate --help 2>/dev/null || true ;;
        update) cmd_update --help 2>/dev/null || true ;;
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

# Ensure the repo has at least one commit (a remote push needs one). Pure git,
# shared by cmd_github and cmd_gitlab.
_ensure_initial_commit() {
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
}

# Locate the zzcollab workspace root by walking up from the current directory
# and cd into it, so forge operations always act on the project root even when
# invoked from a subdirectory (e.g. .github/workflows). Without this, git init,
# the repo name, and `gh repo create --source=.` key to whatever subtree the
# command was run in, publishing the wrong files under the wrong name. A root
# is marked by a .zzcollab file or a DESCRIPTION+Makefile pair (the same test
# cmd_validate uses). Refuse only if no root exists between here and /.
_cd_workspace_root() {
    local dir
    dir=$(pwd)
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.zzcollab" || ( -f "$dir/DESCRIPTION" && -f "$dir/Makefile" ) ]]; then
            if [[ "$dir" != "$(pwd)" ]]; then
                log_success "Found workspace root, running from: $dir"
                cd "$dir" || { log_error "Could not enter workspace root: $dir"; return 1; }
            fi
            return 0
        fi
        dir=$(dirname "$dir")
    done
    log_error "Not inside a zzcollab workspace (no .zzcollab or DESCRIPTION+Makefile found above $(pwd))"
    log_info "Run this from within a zzcollab project."
    return 1
}

cmd_github() {
    _cd_workspace_root || return 1

    # Confidential-repo guard: refuse before any git/gh action when remotes are
    # denied for this project (marker file, remote.allow=false, or a blocked
    # path prefix). See docs/git-setup-flow-spec.md.
    if ! remote_allowed; then
        log_error "Remote creation is disabled for this project"
        log_info "Reason: ${ZZCOLLAB_REMOTE_DENY_REASON}"
        return 1
    fi

    # Ensure git is initialized first
    cmd_git || return 1
    _ensure_initial_commit || return 1

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
                git push -u origin main --force-with-lease
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

# cmd_gitlab - GitLab counterpart to cmd_github, via the glab CLI. Honours the
# configured host (gitlab.host, default gitlab.com) for self-hosted instances,
# the namespace (gitlab.account, else the authenticated user), and visibility
# (gitlab.default_visibility, default private; GitLab also allows internal).
cmd_gitlab() {
    # Confidential-repo guard (see cmd_github and docs/git-setup-flow-spec.md).
    _cd_workspace_root || return 1
    if ! remote_allowed; then
        log_error "Remote creation is disabled for this project"
        log_info "Reason: ${ZZCOLLAB_REMOTE_DENY_REASON}"
        return 1
    fi

    cmd_git || return 1
    _ensure_initial_commit || return 1

    if ! command -v glab &>/dev/null; then
        log_error "GitLab CLI (glab) not installed"
        log_info "Install: https://gitlab.com/gitlab-org/cli"
        return 1
    fi

    if git remote get-url origin &>/dev/null; then
        log_info "Git remote already configured"
        git remote get-url origin
        return 0
    fi

    load_config 2>/dev/null || true
    local host="${CONFIG_GITLAB_HOST:-gitlab.com}"
    local project_name
    project_name=$(basename "$(pwd)")

    if ! glab auth status --hostname "$host" &>/dev/null; then
        log_error "Not authenticated with GitLab ($host)"
        log_info "Run: glab auth login --hostname $host"
        return 1
    fi

    # Namespace: the configured account, else the authenticated user.
    local namespace="${CONFIG_GITLAB_ACCOUNT:-}"
    if [[ -z "$namespace" ]]; then
        namespace=$(forge_user gitlab "$host") || {
            log_error "Could not determine GitLab username"
            log_info "Set it with: zzc config set gitlab-account <username>"
            return 1
        }
        [[ -n "$namespace" ]] || {
            log_error "Could not determine GitLab username"
            log_info "Set it with: zzc config set gitlab-account <username>"
            return 1
        }
    fi

    local visibility="${GITLAB_VISIBILITY:-${CONFIG_GITLAB_DEFAULT_VISIBILITY:-private}}"
    local vis_flag
    case "$visibility" in
        public)   vis_flag="--public" ;;
        internal) vis_flag="--internal" ;;
        *)        vis_flag="--private"; visibility="private" ;;
    esac

    local remote_url="https://${host}/${namespace}/${project_name}.git"

    if GITLAB_HOST="$host" glab repo view "${namespace}/${project_name}" &>/dev/null; then
        log_warn "Repository ${namespace}/${project_name} already exists"
        echo ""
        echo "Options:"
        echo "  1) Connect to existing repo (add remote and push)"
        echo "  2) Delete and recreate"
        echo "  3) Cancel"
        echo ""
        local choice
        zzc_read -r -p "Choice [1]: " choice
        choice="${choice:-1}"
        case "$choice" in
            1)
                log_info "Connecting to existing repository..."
                git remote add origin "$remote_url" 2>/dev/null || \
                    git remote set-url origin "$remote_url"
                git branch -M main
                git push -u origin main --force-with-lease
                log_success "Connected and pushed to existing repository"
                return 0
                ;;
            2)
                log_warn "Deleting existing repository..."
                GITLAB_HOST="$host" glab repo delete "${namespace}/${project_name}" -y || {
                    log_error "Failed to delete repository"
                    return 1
                }
                log_success "Deleted ${namespace}/${project_name}"
                ;;
            *)
                log_info "Cancelled"
                return 0
                ;;
        esac
    fi

    log_info "Creating GitLab repository: ${namespace}/${project_name} ($visibility) on $host"
    if GITLAB_HOST="$host" glab repo create "$project_name" "$vis_flag"; then
        git remote add origin "$remote_url" 2>/dev/null || \
            git remote set-url origin "$remote_url"
        git branch -M main
        if git push -u origin main; then
            log_success "GitLab repository created and pushed"
            GITLAB_HOST="$host" glab repo view --web 2>/dev/null || true
        else
            log_error "Repository created but push failed. Check: git push -u origin main"
            return 1
        fi
    else
        log_error "Failed to create GitLab repository"
        return 1
    fi
    return 0
}

cmd_rm_gitlab() {
    if ! git remote get-url origin &>/dev/null; then
        log_info "No GitLab remote to remove"
        return 0
    fi

    git remote remove origin
    log_success "GitLab remote removed (local repo preserved)"
    log_info "Note: Remote repository still exists on GitLab"
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

    load_config 2>/dev/null || true

    # Registry: explicit docker.registry config wins; otherwise default by forge
    # (GitLab Container Registry when forge=gitlab, Docker Hub otherwise).
    # Honouring docker.registry here fixes the prior behaviour where it was
    # ignored and every push went to Docker Hub.
    local registry="${CONFIG_DOCKER_REGISTRY:-}"
    if [[ -z "$registry" ]]; then
        if [[ "${CONFIG_FORGE:-github}" == gitlab ]]; then
            registry="registry.gitlab.com"
        else
            registry="docker.io"
        fi
    fi

    # Resolve the namespace account and its config key for this registry.
    local account account_key label
    case "$registry" in
        docker.io)
            account="${DOCKERHUB_ACCOUNT:-${CONFIG_DOCKERHUB_ACCOUNT:-}}"
            account_key="dockerhub-account"; label="Docker Hub" ;;
        ghcr.io)
            account="${CONFIG_GITHUB_ACCOUNT:-}"
            account_key="github-account"; label="GitHub Container Registry" ;;
        *)
            # registry.gitlab.com or a self-hosted GitLab registry host.
            account="${CONFIG_GITLAB_ACCOUNT:-}"
            account_key="gitlab-account"; label="GitLab Container Registry" ;;
    esac

    if [[ -z "$account" ]]; then
        if [[ ! -t 0 ]] && [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" != "true" ]]; then
            log_error "$label account not configured"
            echo "  Set with: zzc config set $account_key <name>" >&2
            return 1
        fi
        zzc_read -r -p "$label account/namespace: " account
        if [[ -z "$account" ]]; then
            log_error "$label account required"
            return 1
        fi
        local _save
        zzc_read -r -p "Save to config? [Y/n]: " _save
        if [[ ! "$_save" =~ ^[Nn]$ ]]; then
            config_set "$account_key" "$account"
        fi
    fi

    # Build the image reference. docker.io is implicit, so no host prefix
    # (preserving the historical Docker Hub tag form); other registries are
    # prefixed with the registry host.
    local remote_image
    if [[ "$registry" == docker.io ]]; then
        remote_image="${account}/${project_name}:${tag}"
    else
        remote_image="${registry}/${account}/${project_name}:${tag}"
    fi

    log_info "Tagging: $project_name → $remote_image"
    docker tag "$project_name" "$remote_image" || {
        log_error "Failed to tag image"
        return 1
    }

    local login_hint="docker login"
    [[ "$registry" == docker.io ]] || login_hint="docker login $registry"

    log_info "Pushing to $label: $remote_image"
    if docker push "$remote_image"; then
        log_success "Pushed: $remote_image"
        echo ""
        echo "Pull with:"
        echo "  docker pull $remote_image"
    else
        log_error "Push failed. Check: $login_hint"
        return 1
    fi

    return 0
}

##############################################################################
# FUNCTION: install_zzvimr_graphics_template
# PURPOSE:  Copy zzvim-R .Rprofile.local for terminal graphics support
# RETURNS:  0 if copied, 1 if not found (non-fatal)
##############################################################################
install_zzvimr_graphics_template() {
    local template_locations=(
        "$HOME/.vim/pack/plugins/start/zzvim-R/templates/.Rprofile.local"
        "$HOME/.vim/bundle/zzvim-R/templates/.Rprofile.local"
        "$HOME/.local/share/nvim/site/pack/plugins/start/zzvim-R/templates/.Rprofile.local"
        "$HOME/vimplugins/zzvim-R/templates/.Rprofile.local"
        "$HOME/prj/sfw/04-zzvim-r/zzvim-R/templates/.Rprofile.local"
    )

    for loc in "${template_locations[@]}"; do
        if [[ -f "$loc" ]]; then
            safe_cp "$loc" .Rprofile.local
            log_success "Installed .Rprofile.local (zzvim-R graphics)"
            return 0
        fi
    done

    log_warn "zzvim-R not found; skipping .Rprofile.local"
    log_info "Install zzvim-R for terminal graphics: https://github.com/rgt47/zzvim-R"
    return 1
}

##############################################################################
# FUNCTION: _quickstart_existing_project
# PURPOSE:  Handle 'zzc <profile>' when the directory is already a workspace.
#           Reports status for a matching profile, refuses a non-destructive
#           profile switch (directing the user to 'docker --profile'), or
#           regenerates a missing Dockerfile for the current profile. Always
#           returns, so the caller propagates its exit status.
# ARGS:     $1 - requested profile name
#           $2 - resolved base image for that profile
##############################################################################
_quickstart_existing_project() {
    local profile="$1" base_image="$2"
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
        echo "  To rebuild:  make docker-rebuild" >&2
        return 0
    fi

    # A different profile is requested for an existing project. Do NOT
    # silently switch: that path used to overwrite a customized
    # .Rprofile/Makefile. A bare profile token is create-only; switching is
    # an explicit, non-destructive operation via 'docker --profile'.
    if [[ "$current_profile" != "$profile" ]]; then
        if [[ -n "$current_profile" ]]; then
            log_error "This project is configured with the '$current_profile' profile."
            log_info  "To switch it to '$profile':  zzcollab docker --profile $profile"
        else
            log_error "This project has no profile set."
            log_info  "To configure it with '$profile':  zzcollab docker --profile $profile"
        fi
        log_info  "(That regenerates the Dockerfile only; your .Rprofile and Makefile are left untouched.)"
        return 1
    fi

    # Same profile, missing Dockerfile
    log_info "Generating missing Dockerfile for profile: $profile"
    export BASE_IMAGE="$base_image"
    generate_dockerfile || return 1
    log_success "Dockerfile generated with $profile profile"
    return 0
}

##############################################################################
# FUNCTION: cmd_quickstart
# PURPOSE:  Smart profile command - quickstart for new, switch for existing
# USAGE:    zzcollab tidyverse
#           zzcollab minimal
# ARGS:     $1 - profile name (minimal, tidyverse, rstudio; 'analysis' is a
#           deprecated alias for 'tidyverse')
##############################################################################
cmd_quickstart() {
    local profile="${1:-tidyverse}"


    # Load resolved config so scaffolded metadata (DESCRIPTION/LICENSE author,
    # license, roxygen version) reflects the user's settings.
    load_config 2>/dev/null || true

    # Validate profile exists
    local base_image
    base_image=$(get_profile_base_image "$profile") || {
        log_error "Unknown profile: $profile"
        log_info "Available: minimal, tidyverse, rstudio, publishing"
        return 1
    }

    # Existing project → the handler decides what (if anything) to do and
    # always returns; propagate its status.
    if is_workspace_initialized; then
        _quickstart_existing_project "$profile" "$base_image"
        return $?
    fi

    # New project → full quickstart
    assert_safe_init_directory || return 1
    local project_name
    project_name=$(basename "$(pwd)")
    # The project name is the directory name; reject malformed names before
    # scaffolding (validate_package_name later derives the R-safe variant).
    validate_project_name "$project_name" || return 1

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  zzcollab quickstart: $project_name"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Profile:    $profile"
    echo "  Base image: $base_image"
    echo ""
    echo "  This will create:"
    echo "    - zzcollab research compendium structure"
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
    setup_project_safe || return 1
    log_success "Project structure created"

    # Install zzvim-R graphics template for the tidyverse profile
    # ('analysis' accepted as the deprecated alias).
    if [[ "$profile" == "tidyverse" || "$profile" == "analysis" ]]; then
        install_zzvimr_graphics_template || true
    fi

    # Step 2: Set up renv
    echo ""
    log_info "Step 2/3: Setting up renv..."
    local r_version
    r_version="${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}"
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
        if prompt_build_now; then
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
# TOOLS COMMAND
#=============================================================================

# Function: cmd_tools
# Purpose: Retrofit the render-stamp helpers into an existing
#          project: tools/stamp.tex, stamp-render.R, render.sh,
#          and a README. Existing files are left untouched, so the
#          command is safe to run repeatedly.
cmd_tools() {

    if ! is_workspace_initialized; then
        log_error "Not in a zzcollab project"
        log_info "Run a profile command first, e.g. 'zzc tidyverse'"
        return 1
    fi

    create_tools_directory || return 1

    echo "" >&2
    log_info "Render a stamped PDF with:"
    echo "    bash tools/render.sh <document.Rmd|.qmd|.md>" >&2
    return 0
}

#=============================================================================
# ADD / REMOVE COMMANDS
#=============================================================================

# cmd_add - explicit add form mirroring cmd_rm. Routes 'zzc add <feature>' to
# the per-feature command, passing through any flags (e.g. add docker
# --base-image IMG). The bare verbs (zzc docker, zzc renv, ...) still work; this
# is the symmetric, discoverable form the plan's explicit-flags note assumes.
cmd_add() {
    local feature="${1:-}"
    shift || true
    case "$feature" in
        docker)        cmd_docker "$@" ;;
        renv)          cmd_renv "$@" ;;
        nix)           cmd_nix "$@" ;;
        data)          cmd_data "$@" ;;
        code-quality)  cmd_code_quality "$@" ;;
        tests)         cmd_tests "$@" ;;
        cloud)         cmd_cloud "$@" ;;
        github)        cmd_github "$@" ;;
        gitlab)        cmd_gitlab "$@" ;;
        cicd)
            ensure_workspace_initialized "cicd" || return 1
            _toggle_add_ci && log_success "Installed CI workflows"
            ;;
        ""|help|--help|-h)
            echo "Usage: zzcollab add <feature> [options]"
            echo "Features: docker, renv, nix, data, code-quality, tests, cloud, cicd, github, gitlab"
            echo "Equivalent to the bare verbs (zzc docker, zzc renv, ...); 'rm' is the inverse."
            [[ -z "$feature" ]] && return 1 || return 0
            ;;
        *)
            log_error "Unknown feature: $feature"
            log_info "Features: docker, renv, nix, data, code-quality, tests, cloud, cicd, github, gitlab"
            return 1
            ;;
    esac
}

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
        gitlab)
            cmd_rm_gitlab
            ;;
        cicd)
            cmd_rm_cicd
            ;;
        data)
            cmd_rm_data
            ;;
        code-quality)
            cmd_rm_code_quality
            ;;
        tests)
            cmd_rm_tests
            ;;
        cloud)
            cmd_rm_cloud
            ;;
        nix)
            cmd_rm_nix
            ;;
        all)
            cmd_rm_all "$@"  # Pass through flags like -f, --force
            ;;
        "")
            log_error "Usage: zzcollab rm <feature>"
            log_info "Features: docker, renv, nix, git, github, cicd, data, code-quality, tests, cloud, all"
            return 1
            ;;
        *)
            log_error "Unknown feature: $feature"
            log_info "Features: docker, renv, nix, git, github, cicd, data, code-quality, tests, cloud, all"
            return 1
            ;;
    esac
}

cmd_rm_data() {
    if [[ -f data-manifest.sha256 ]]; then
        rm -f data-manifest.sha256
        log_success "Removed data-manifest.sha256 (data-integrity hashing off)"
    else
        log_info "No data-manifest.sha256 to remove"
    fi
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
        return 0
    fi

    # The render workflow self-adapts to artifact presence at run time, so with
    # the Dockerfile gone it falls back to a host render. Refresh it from the
    # template so repos carrying an older Docker-only render-report.yml pick up
    # the dual-mode version; without this the next render would `docker build`
    # against a missing Dockerfile and fail.
    local refreshed=false
    if [[ -f ".github/workflows/render-report.yml" ]]; then
        if regenerate_template_file "workflows/render-report.yml" \
               ".github/workflows/render-report.yml" "render workflow" \
               >/dev/null 2>&1; then
            refreshed=true
        else
            log_warn "Could not refresh render-report.yml; it may still expect a Dockerfile"
        fi
    fi

    log_success "Docker configuration removed"
    echo ""
    echo "  The project now runs on the host environment:"
    if [[ -f "renv.lock" ]]; then
        echo "    packages pinned by renv.lock (capture level L1)"
    else
        echo "    packages installed from DESCRIPTION, unpinned (capture level L0)"
        echo "    add renv to pin package versions:  zzc renv"
    fi
    [[ "$refreshed" == true ]] && \
        echo "    render workflow updated to host-render mode"
    echo "    review the configuration:          zzc status"
    echo ""
}

cmd_rm_renv() {
    # ZZCOLLAB_ASSUME_YES skips the prompt for callers that have already
    # confirmed (e.g. zzc toggle), so the removal is not double-confirmed.
    if [[ "${ZZCOLLAB_ASSUME_YES:-}" != "1" ]]; then
        echo ""
        log_warn "This will remove renv.lock and renv/ directory"
        zzc_read -r -p "Continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi

    [[ -f "renv.lock" ]] && rm "renv.lock" && log_info "Removed renv.lock"
    [[ -d "renv" ]] && rm -rf "renv" && log_info "Removed renv/"

    # The check workflow self-adapts to backend presence at run time, but an
    # older r-package.yml hard-requires renv.lock and would now fail CI.
    # Refresh it from the template so the DESCRIPTION-backend path is available.
    if [[ -f ".github/workflows/r-package.yml" ]]; then
        if regenerate_template_file "workflows/r-package.yml" \
               ".github/workflows/r-package.yml" "check workflow" \
               >/dev/null 2>&1; then
            echo "  Check workflow updated to DESCRIPTION-backend mode"
        else
            log_warn "Could not refresh r-package.yml; CI may still require renv.lock"
        fi
    fi

    # The .Rprofile is left untouched: it self-adapts at run time, gating its
    # renv workflow (auto-init, restore, snapshot) on ZZCOLLAB_INSTALL_MODE,
    # which the regenerated Dockerfile sets to "description" below. Editing the
    # file with grep would mangle the conditional renv blocks in the current
    # template; the env-driven gate is both correct and reversible.

    # A present Dockerfile was generated to restore from renv.lock; regenerate
    # it so it self-adapts to DESCRIPTION-install mode now that renv is gone,
    # otherwise the toggle leaves a broken COPY renv.lock. Base image and R
    # version come from .zzcollab-state, which avoids the interactive wizard.
    if [[ -f "Dockerfile" ]]; then
        local _sb _sr
        _sb=$(_zzc_state_get base_image . 2>/dev/null)
        _sr=$(_zzc_state_get r_version . 2>/dev/null)
        if [[ -n "$_sb" ]]; then
            export BASE_IMAGE="${_sb%:*}"
            export R_VERSION="${_sr:-${_sb##*:}}"
            if generate_dockerfile >/dev/null 2>&1; then
                echo "  Dockerfile regenerated in DESCRIPTION-install mode"
                echo "  rebuild to apply:  make docker-build"
            else
                log_warn "Could not regenerate Dockerfile; run 'zzc docker --no-renv' manually."
            fi
        else
            log_warn "Dockerfile present but no .zzcollab-state."
            echo "  Run 'zzc docker --no-renv' to switch it to DESCRIPTION mode."
        fi
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
    local removed=false
    if [[ -d ".github/workflows" ]]; then
        rm -rf .github/workflows
        # Remove .github if empty
        rmdir .github 2>/dev/null || true
        removed=true
    fi
    if [[ -f ".gitlab-ci.yml" ]]; then
        rm -f .gitlab-ci.yml
        removed=true
    fi
    if [[ "$removed" == true ]]; then
        log_success "CI/CD workflows removed"
    else
        log_info "No CI/CD workflows to remove"
    fi
}

cmd_rm_all() {
    echo ""
    log_warn "Removing all zzcollab scaffolding (hardcoded file list)"
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

    # Directories: the shared scaffold (which includes renv) plus analysis/ and
    # inst/ (generated by scaffolding; uninstall keeps it, the nuke removes it).
    local dirs=("${ZZCOLLAB_SCAFFOLD_DIRS[@]}" analysis inst)
    for d in "${dirs[@]}"; do
        [[ -d "$d" ]] && rm -rf "$d" && log_info "Removed $d/"
    done

    # Files: the shared scaffold plus .dockerignore and the project config, so
    # 'rm all' leaves only the user's original files (a superset of uninstall).
    local files=("${ZZCOLLAB_SCAFFOLD_FILES[@]}" .dockerignore zzcollab.yaml)
    for f in "${files[@]}"; do
        [[ -f "$f" ]] && rm "$f" && log_info "Removed $f"
    done

    # Rproj files
    for f in *.Rproj; do
        [[ -f "$f" ]] && rm "$f" && log_info "Removed $f"
    done

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
  init       Create zzcollab structure (DESCRIPTION, R/, analysis/)
  renv       Add renv package tracking (renv.lock)
  docker     Add Docker containerization (Dockerfile)
  git        Initialize git repository
  github     Initialize git + create GitHub repo
  gitlab     Initialize git + create GitLab repo (forge: gitlab)
  push       Push Docker image to the configured registry (alias: dockerhub)

Profiles (new project: init+renv+docker, existing: switch profile):
  minimal       Base R, command-line only (~650MB)
  analysis      Tidyverse data analysis (~1.2GB) - recommended
  rstudio       RStudio Server (~980MB)

Management:
  rebuild        Rebuild Docker image (uses content-addressable cache)
  tools          Install render-stamp helpers in tools/ (PDF provenance)
  rm <feature>   Remove: docker, renv, git, github, gitlab, cicd
  uninstall      Remove the zzcollab scaffold from this directory
  doctor         Check workspace files are current with templates
  update         Regenerate framework-managed files to the current template version
  validate       Validate package dependencies (renv / zzrenvcheck)
  config         Configuration management
  menu           Interactive hub for common project actions
  list           List profiles, libs, packages
  help           Show help

Global options (any position):
  -v, --verbose    More output
  -q, --quiet      Errors only
  -y, --yes        Accept defaults (non-interactive)
  --no-build       Skip Docker build prompt
  --version        Print version and exit
  -h, --help       Show this help

Per-command options (must follow their command):
  docker:    -b, --build              Build image after generating
             -r, --profile <name>     Select profile (tidyverse, minimal, ...)
             --base-image <img>       Override base image
             --r-version <ver>        Pin R version
  push:      -t, --tag <tag>          Image tag (default: latest); alias: dockerhub
  github:    --private | --public     Repo visibility (default: private)
  gitlab:    --private | --public | --internal   Repo visibility (default: private)
  rm:        -f, --force              Skip confirmation
  update:    --dry-run                Preview changes; write nothing
             -f, --force              Proceed on a dirty/non-git tree

Note: When commands are combined, a per-command option binds to the command
      immediately before it. In 'zzcollab docker -b github', -b applies to
      docker (build the image), not to github.
Note: -t is the DockerHub image tag, not team; set the team with
      'zzcollab config set dockerhub-account NAME'.

Examples:
  zzcollab tidyverse               # Quickstart: init + renv + docker (recommended)
  zzcollab minimal                 # Quickstart with minimal profile
  zzcollab init                    # Create zzcollab structure only
  zzcollab docker                  # Add Docker (auto-adds renv, init)
  zzcollab docker -b github        # Build image + create GitHub repo
  zzcollab rm docker               # Remove Docker files
  zzcollab menu                    # Interactive hub (change profile, add package, ...)
  zzcollab docker --profile rstudio # Switch an existing project's profile
EOF
}

#=============================================================================
# INTERACTIVE POST-INIT HUB (zzcollab menu)
#=============================================================================

# _menu_choose HEADER ITEM...
# Single-select via gum when available, else a numbered zzc_read fallback.
# Prints the chosen item to stdout; returns 1 on cancel.
_menu_choose() {
    local header="$1"; shift
    local items=("$@")
    if has_gum; then
        gum choose --header "$header" "${items[@]}"
        return $?
    fi
    printf '%s\n' "$header" >&2
    local i
    for i in "${!items[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${items[$i]}" >&2
    done
    local sel
    zzc_read -r -p "Choice: " sel || return 1
    [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#items[@]} )) \
        && { printf '%s' "${items[$((sel - 1))]}"; return 0; }
    return 1
}

# Change the project's profile (non-destructive: regenerates the Dockerfile via
# 'docker --profile'). Preselects the current profile in the gum picker.
_menu_change_profile() {
    local current new
    current=$(config_get profile-name 2>/dev/null || echo "")
    if has_gum; then
        local args=(gum choose --header "Select profile (current: ${current:-none})")
        [[ -n "$current" ]] && args+=(--selected "$current")
        args+=(minimal tidyverse rstudio)
        new=$("${args[@]}") || return 0
    else
        new=$(_menu_choose "Select profile (current: ${current:-none})" \
            minimal tidyverse rstudio) || return 0
    fi
    [[ -z "$new" ]] && return 0
    cmd_docker --profile "$new"
}

# Set a single config value (with the current value as the default).
_menu_set_value() {
    local key="$1" label="$2" current val
    current=$(config_get "$key" 2>/dev/null || echo "")
    if has_gum; then
        val=$(gum_input "${current:-(enter value)}" "$label" "$current") || return 0
    else
        zzc_read -r -p "$label [${current:-unset}]: " val || return 0
        val="${val:-$current}"
    fi
    [[ -z "$val" ]] && return 0
    config_set "$key" "$val"
}

# Install R package(s) into the project image and snapshot renv.lock.
_menu_add_package() {
    local image pkgs rvec
    image=$(basename "$(pwd)")
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed."
        return 0
    fi
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        log_error "Docker image '$image' not found. Build it first (menu: Rebuild Docker image)."
        return 0
    fi
    if has_gum; then
        pkgs=$(gum_input "dplyr ggplot2" "R package(s) to add (space or comma separated)" "") || return 0
    else
        zzc_read -r -p "R package(s) to add (space/comma separated): " pkgs || return 0
    fi
    [[ -z "$pkgs" ]] && return 0

    # S-4: Validate each token against the R package-name grammar before
    # building the argument list. Names containing shell metacharacters or
    # quotes could break out of the Rscript invocation.
    # Allowed: CRAN names ([A-Za-z][A-Za-z0-9.]*), GitHub refs (user/pkg),
    # and version-pinned refs (user/pkg@tag or pkg@version).
    local -a pkg_list=()
    local _tok
    while IFS= read -r _tok; do
        [[ -z "$_tok" ]] && continue
        if ! [[ "$_tok" =~ ^[A-Za-z][A-Za-z0-9.]*(/[A-Za-z][A-Za-z0-9._-]*)?(@[A-Za-z0-9._-]+)?$ ]]; then
            log_error "Invalid package name: '$_tok'"
            log_error "  CRAN: letters/numbers/dots, e.g. 'dplyr', 'R.utils'"
            log_error "  GitHub: 'user/pkg' or 'user/pkg@tag'"
            return 1
        fi
        pkg_list+=("$_tok")
    done < <(printf '%s' "$pkgs" | tr ',' ' ' | xargs -n1 2>/dev/null)
    [[ "${#pkg_list[@]}" -eq 0 ]] && return 0

    log_info "Installing into '$image' and recording in renv.lock..."
    if [[ "$(uname -m)" == "arm64" ]]; then
        log_info "Note: on Apple Silicon, packages that compile from source may fail to load unless the image provides a working amd64 toolchain (see DOCKER_DEFAULT_PLATFORM). Pure-R packages install reliably."
    fi
    # Install, then renv::record the packages directly into the lockfile.
    # 'record' is used rather than 'snapshot' because the project uses
    # implicit snapshots (renv/settings.json snapshot.type=implicit), which
    # only capture packages declared/used in code; a freshly added package
    # would otherwise be dropped. ZZCOLLAB_AUTO_SNAPSHOT=false stops the
    # .Rprofile .Last hook from re-running an implicit snapshot on exit.
    # Package names are passed as positional arguments (no string interpolation).
    if docker run --rm \
        -e ZZCOLLAB_AUTO_SNAPSHOT=false \
        -v "$(pwd):/home/analyst/project" \
        -w /home/analyst/project \
        "$image" \
        Rscript -e 'args <- commandArgs(trailingOnly=TRUE); renv::install(args); renv::record(args)' \
        --args "${pkg_list[@]}"; then
        log_success "Added: ${pkg_list[*]} (recorded in renv.lock). Commit renv.lock to share."
    else
        log_error "Package install failed."
    fi
}

# Interactive post-init hub. Each action dispatches to an existing command.
cmd_menu() {
    if ! is_workspace_initialized; then
        log_error "No zzcollab project in this directory."
        log_info  "Create one first:  zzcollab tidyverse  (or minimal, rstudio)"
        return 1
    fi
    # Repo entry follows the configured forge (GitHub or GitLab).
    load_config 2>/dev/null || true
    local repo_label="Create GitHub repo"
    [[ "${CONFIG_FORGE:-github}" == gitlab ]] && repo_label="Create GitLab repo"
    while true; do
        local choice
        choice=$(_menu_choose "zzcollab — what would you like to do?" \
            "Change profile" \
            "Add R package(s)" \
            "Set DockerHub account" \
            "Set GitHub account" \
            "Pin R version" \
            "Rebuild Docker image" \
            "Push image to registry" \
            "$repo_label" \
            "View configuration" \
            "Check workspace health" \
            "Quit") || break
        case "$choice" in
            "Change profile")            _menu_change_profile ;;
            "Add R package(s)")          _menu_add_package ;;
            "Set DockerHub account")     _menu_set_value dockerhub-account "DockerHub account" ;;
            "Set GitHub account")        _menu_set_value github-account "GitHub account" ;;
            "Pin R version")             _menu_set_value r-version "R version (X.Y.Z)" ;;
            "Rebuild Docker image")      cmd_build ;;
            "Push image to registry")    cmd_dockerhub ;;
            "Create GitHub repo")        cmd_github ;;
            "Create GitLab repo")        cmd_gitlab ;;
            "View configuration")        config_list ;;
            "Check workspace health")    cmd_doctor ;;
            "Quit"|"")                   break ;;
        esac
        echo "" >&2
    done
    return 0
}

main() {
    # No arguments → context-aware entry point
    if [[ $# -eq 0 ]]; then
        if is_workspace_initialized; then
            show_usage
        else
            cmd_init
        fi
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
            -y|--yes)              export ZZCOLLAB_ACCEPT_DEFAULTS=true ;;
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
                echo "zzcollab ${ZZCOLLAB_VERSION:-0.1.0}"
                exit 0
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;

            init)
                shift
                # Forward trailing flags (e.g. --force, --archetype X) so the
                # guard's escape hatch is reachable; cmd_init parses leading
                # flags, so consume them here before the next command. Flags that
                # take a value (--archetype) consume the value too, else it would
                # be misread as the next command.
                cmd_init "$@"
                commands_run=$((commands_run + 1))
                while [[ $# -gt 0 ]] && [[ "$1" == -* ]]; do
                    case "$1" in
                        --archetype) shift 2 ;;
                        *) shift ;;
                    esac
                done
                ;;
            renv)
                cmd_renv
                commands_run=$((commands_run + 1))
                shift
                ;;
            data)
                shift
                cmd_data "$@"
                exit $?
                ;;
            code-quality)
                shift
                cmd_code_quality "$@"
                exit $?
                ;;
            tests)
                shift
                cmd_tests "$@"
                exit $?
                ;;
            cloud)
                shift
                cmd_cloud "$@"
                exit $?
                ;;
            nix)
                shift
                cmd_nix "$@"
                exit $?
                ;;
            tools)
                cmd_tools
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
                        --no-renv)
                            docker_args+=("--no-renv")
                            shift
                            ;;
                        --r-version|--base-image)
                            docker_args+=("$1" "$2")
                            shift 2
                            ;;
                        # Profile names as implicit --profile ('analysis' is a
                        # deprecated alias for 'tidyverse').
                        minimal|tidyverse|analysis|rstudio|publishing)
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
            gitlab)
                shift
                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        --private)  export GITLAB_VISIBILITY="private";  shift ;;
                        --public)   export GITLAB_VISIBILITY="public";   shift ;;
                        --internal) export GITLAB_VISIBILITY="internal"; shift ;;
                        *)          break ;;
                    esac
                done
                cmd_gitlab
                commands_run=$((commands_run + 1))
                ;;
            push|dockerhub)
                # 'push' is the forge-neutral name (it honours docker.registry);
                # 'dockerhub' is kept as a back-compat alias.
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
            add)
                # Explicit, non-interactive add form mirroring 'rm'. Routes to
                # the per-feature commands so scripts/CI never hit the wizard.
                shift
                cmd_add "$@"
                exit $?
                ;;

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
            # ('analysis' is a deprecated alias for 'tidyverse').
            minimal|tidyverse|analysis|rstudio|publishing)
                local profile_name="$1"
                shift
                # The quickstart takes no flags. A trailing flag (e.g.
                # --r-version) would otherwise be silently ignored after the
                # project is scaffolded; reject it before doing any work. A
                # trailing command (e.g. 'github') is still allowed to chain.
                if [[ "${1:-}" == -* ]]; then
                    log_error "'zzcollab $profile_name' does not take flags (got '$1')."
                    log_info  "Pin the R version: 'zzcollab config set r-version X.Y.Z' then 'zzcollab $profile_name'."
                    log_info  "Override the base image: 'zzcollab docker --base-image IMG'."
                    exit 2
                fi
                cmd_quickstart "$profile_name"
                commands_run=$((commands_run + 1))
                ;;

            # Other commands that pass through
            rebuild)
                shift
                cmd_build "$@"
                exit $?
                ;;
            build)
                # Deprecated alias for 'rebuild' (kept for already-generated
                # project Makefiles that still call 'zzcollab build').
                shift
                log_warn "'zzcollab build' is deprecated; use 'zzcollab rebuild'."
                cmd_build "$@"
                exit $?
                ;;
            status)
                shift
                cmd_status "$@"
                exit $?
                ;;
            validate)
                shift
                cmd_validate "$@"
                exit $?
                ;;
            verify)
                shift
                cmd_verify "$@"
                exit $?
                ;;
            toggle)
                shift
                cmd_toggle "$@"
                exit $?
                ;;
            doctor)
                shift
                cmd_doctor "$@"
                exit $?
                ;;
            update)
                shift
                cmd_update "$@"
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
            menu)
                shift
                cmd_menu "$@"
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
