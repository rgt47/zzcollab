#!/usr/bin/env bash
##############################################################################
# status.sh - `zzc status`: read-only, presence-driven feature report
#
# Phase 0 of the reproducibility-toggle plan (docs/, local). The artifacts in
# the project directory are the single source of truth for which features are
# on; this command detects them, computes the reproducibility level, and
# prints the result alongside the user-global defaults. It is strictly
# read-only: it creates, deletes, and modifies nothing.
#
# Depends on lib/core.sh (log_*, has_gum) and modules/config.sh (load_config,
# CONFIG_* state). Sourced by zzcollab.sh.
##############################################################################

# Detect the package backend from artifact presence.
# Echoes one of: renv | nix | none | conflict
_zzc_detect_backend() {
    local d="${1:-.}"
    local has_renv=false has_nix=false
    [[ -f "$d/renv.lock" ]] && has_renv=true
    { [[ -f "$d/flake.nix" ]] || [[ -f "$d/default.nix" ]]; } && has_nix=true
    if [[ "$has_renv" == true && "$has_nix" == true ]]; then
        echo "conflict"
    elif [[ "$has_renv" == true ]]; then
        echo "renv"
    elif [[ "$has_nix" == true ]]; then
        echo "nix"
    else
        echo "none"
    fi
}

# Compute the reproducibility level from the two capture axes.
# Args: <backend> <docker on|off>. Echoes L0 | L1 | L2.
# L3 (verified) is not presence-detectable and is reported separately.
_zzc_compute_level() {
    local backend="$1" docker="$2"
    if [[ "$docker" == "on" ]]; then
        echo "L2"          # environment pinned (image), regardless of backend
    elif [[ "$backend" == "nix" ]]; then
        echo "L2"          # Nix pins the environment without a container
    elif [[ "$backend" == "renv" ]]; then
        echo "L1"          # packages pinned, environment not
    else
        echo "L0"          # locatable only
    fi
}

# Write the generator state record (key=value, dependency-free; never
# hand-edited). Overwrites .zzcollab-state in the current directory. All keys
# are always written so the schema stays stable; callers pass empty strings for
# fields they do not know (e.g. cmd_init has no base image yet). zzc status and
# the toggle commands read this for robust read-back instead of re-parsing the
# Dockerfile (toggle plan, Section 4).
#   $1 r_version  $2 base_image:tag  $3 base_digest  $4 ppm_snapshot  $5 install_mode
_zzc_write_state() {
    {
        echo "schema=1"
        echo "template_version=${ZZCOLLAB_TEMPLATE_VERSION:-unknown}"
        echo "r_version=${1:-}"
        echo "base_image=${2:-}"
        echo "base_digest=${3:-}"
        echo "ppm_snapshot=${4:-}"
        echo "install_mode=${5:-}"
        echo "generated=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > .zzcollab-state
}

# Read a key from the generator-written .zzcollab-state record (key=value,
# dependency-free). Echoes the value, or nothing if absent. Always returns 0:
# a missing key makes grep exit nonzero, which under `set -o pipefail` would
# otherwise abort an assignment in a `set -e` caller (e.g. optional keys like
# `verified`).
_zzc_state_get() {
    local key="$1" d="${2:-.}"
    [[ -f "$d/.zzcollab-state" ]] || return 0
    grep -m1 "^${key}=" "$d/.zzcollab-state" 2>/dev/null | cut -d= -f2- || true
}

# Read the base image from a Dockerfile's FROM line. Fallback for older repos
# that predate .zzcollab-state; the state record is preferred.
_zzc_base_from_dockerfile() {
    local d="${1:-.}"
    [[ -f "$d/Dockerfile" ]] || return 0
    grep -m1 '^FROM ' "$d/Dockerfile" 2>/dev/null | awk '{print $2}'
}

# Print "on" or "off" for a presence test, padded.
_zzc_onoff() { [[ "$1" == true ]] && echo "on " || echo "off"; }

# cmd_status [dir] - print the global and local feature report.
cmd_status() {
    local d="${1:-.}"

    # A zzcollab workspace is marked by the .zzcollab file or, for older
    # projects, by a DESCRIPTION beside a Makefile.
    if [[ ! -f "$d/.zzcollab" && ! ( -f "$d/DESCRIPTION" && -f "$d/Makefile" ) ]]; then
        log_error "Not a zzcollab workspace (no .zzcollab marker or DESCRIPTION)."
        log_info  "Run 'zzc init' here, or cd into a compendium."
        return 1
    fi

    # --- Global tier: defaults for new projects -----------------------------
    # config_get triggers a guarded load_config; degrade quietly if yq or the
    # user config is absent.
    local g_profile g_account
    g_profile=$(config_get profile_name 2>/dev/null || true)
    g_account=$(config_get dockerhub_account 2>/dev/null || true)
    [[ -z "$g_profile" ]] && g_profile="${CONFIG_DOCKER_DEFAULT_PROFILE:-${CONFIG_PROFILE_NAME:-}}"
    [[ -z "$g_account" ]] && g_account="${CONFIG_DOCKERHUB_ACCOUNT:-}"

    echo ""
    echo "GLOBAL  ${CONFIG_USER:-~/.zzcollab/config.yaml}   (defaults for new projects)"
    printf "  %-14s %s\n" "profile"  "${g_profile:-(unset)}"
    printf "  %-14s %s\n" "registry" "ghcr"
    printf "  %-14s %s\n" "dockerhub" "${g_account:-(unset)}"

    # --- Local tier: live state from artifact presence ----------------------
    local backend docker_on ci_check ci_render tests data dev binder git_on
    backend=$(_zzc_detect_backend "$d")
    [[ -f "$d/Dockerfile" ]] && docker_on=on || docker_on=off
    [[ -f "$d/.github/workflows/r-package.yml" ]]    && ci_check=true  || ci_check=false
    [[ -f "$d/.github/workflows/render-report.yml" ]] && ci_render=true || ci_render=false
    [[ -d "$d/inst/tinytest" ]]        && tests=true  || tests=false
    [[ -f "$d/data-manifest.sha256" ]] && data=true   || data=false
    [[ -d "$d/.devcontainer" ]]        && dev=true     || dev=false
    [[ -d "$d/.binder" ]]              && binder=true  || binder=false
    [[ -d "$d/.git" ]]                 && git_on=true  || git_on=false

    local level base digest mode src verified
    level=$(_zzc_compute_level "$backend" "$docker_on")
    # zzc verify --full stamps this on a successful rebuild+test. Any later
    # regeneration rewrites .zzcollab-state without the key, so a changed
    # environment reverts to unverified automatically.
    verified=$(_zzc_state_get verified "$d")
    if [[ -n "$verified" ]]; then level="L3"; fi
    # Prefer the generator-written state record; fall back to grepping FROM
    # for older repos that predate .zzcollab-state.
    base=$(_zzc_state_get base_image "$d")
    digest=$(_zzc_state_get base_digest "$d")
    mode=$(_zzc_state_get install_mode "$d")
    if [[ -n "$base" ]]; then
        src=".zzcollab-state"
        [[ -n "$digest" && "$digest" != unknown ]] && base="${base}@${digest:0:14}…"
    else
        base=$(_zzc_base_from_dockerfile "$d")
        src="Dockerfile FROM (no state record)"
    fi

    echo ""
    echo "LOCAL   $(cd "$d" && pwd)   (level: $level, verified: ${verified:-no})"
    # Capture axes
    if [[ "$backend" == "conflict" ]]; then
        printf "  %-14s %s\n" "backend" "CONFLICT: both renv.lock and a nix file present; resolve to one"
    else
        printf "  %-14s %s\n" "backend" "$backend  (capture)"
    fi
    # base image and install mode describe the Docker environment; suppress
    # them when Docker is off so a stale .zzcollab-state record (kept as the
    # remembered config for a later re-add) does not read as the live state.
    local env_detail=""
    if [[ "$docker_on" == on ]]; then
        env_detail="${base:+   base: $base}${mode:+   install: $mode}"
    fi
    printf "  %-14s %s\n" "environment" "docker $docker_on  (capture)${env_detail}"
    # Validation layer
    printf "  %-14s %s\n" "CI check"   "$(_zzc_onoff "$ci_check")  (validation)   r-package.yml"
    printf "  %-14s %s\n" "CI render"  "$(_zzc_onoff "$ci_render")  (validation)   render-report.yml"
    printf "  %-14s %s\n" "unit tests" "$(_zzc_onoff "$tests")  (validation)   inst/tinytest/"
    printf "  %-14s %s\n" "data hash"  "$(_zzc_onoff "$data")  (capture)      data-manifest.sha256"
    printf "  %-14s %s\n" "cloud"      "devcontainer $(_zzc_onoff "$dev")  binder $(_zzc_onoff "$binder")"
    printf "  %-14s %s\n" "git"        "$(_zzc_onoff "$git_on")"
    echo ""
    echo "Levels: L0 locatable, L1 pinned packages, L2 pinned environment, L3 verified."
    if [[ -n "$verified" ]]; then
        echo "verified: $verified  (zzc verify --full)"
    else
        echo "verified: no  (run 'zzc verify' for coherence, 'zzc verify --full' for L3)"
    fi
    echo ""
}
