#!/usr/bin/env bash
##############################################################################
# toggle.sh - `zzc toggle`: interactive view-and-change of reproducibility
# features for an existing compendium (plan §12.2).
#
# Reads the current state by artifact presence (and .zzcollab-state), asks for
# the package backend (single-select) and a feature checklist (multi-select),
# diffs the desired state against the current one, confirms once, and applies
# the change set by driving the existing zzc <feature> / zzc rm <feature>
# commands. Cancellation makes no changes.
#
# Uses gum when available and attached to a terminal; otherwise falls back to
# zzc_read prompts (so the flow is also driveable by piped input). Under
# accept-defaults every prompt keeps the current value, i.e. no changes - so
# non-interactive callers should use the explicit commands instead.
#
# Depends on lib/core.sh (gum_*, zzc_read, log_*), modules/status.sh
# (_zzc_detect_backend, cmd_status), and the cmd_* feature commands in
# zzcollab.sh (resolved at call time). Sourced by zzcollab.sh.
##############################################################################

# Install both CI workflow templates (CI validation toggle -> on).
_toggle_add_ci() {
    mkdir -p .github/workflows
    regenerate_template_file "workflows/r-package.yml" \
        ".github/workflows/r-package.yml" "check workflow" >/dev/null 2>&1
    regenerate_template_file "workflows/render-report.yml" \
        ".github/workflows/render-report.yml" "render workflow" >/dev/null 2>&1
}

# Ask on/off for one feature, defaulting to its current value (fallback path).
_toggle_ask() {
    local label="$1" cur="$2" ans
    zzc_read -r -p "  $label [on/off] (current: $cur): " ans
    ans="${ans:-$cur}"
    case "$ans" in
        on|y|yes|1)  echo on ;;
        off|n|no|0)  echo off ;;
        *)           echo "$cur" ;;
    esac
}

cmd_toggle() {
    case "${1:-}" in
        help|--help|-h)
            cat << 'EOF'
TOGGLE - view and change reproducibility features

USAGE:
    zzc toggle

Interactively shows the current features (backend, Docker, CI, data
integrity, code quality), lets you change them, confirms the diff, and
applies it by reusing the per-feature commands. Cancellation makes no
changes.

For scripts and CI use the explicit commands instead:
    zzc renv | zzc docker | zzc data | zzc code-quality
    zzc rm <feature>
EOF
            return 0 ;;
    esac

    if [[ ! -f .zzcollab && ! ( -f DESCRIPTION && -f Makefile ) ]]; then
        log_error "Not a zzcollab workspace (no .zzcollab marker or DESCRIPTION)."
        return 1
    fi

    # --- Detect current state ----------------------------------------------
    local cur_backend cur_docker cur_ci cur_data cur_quality
    cur_backend=$(_zzc_detect_backend ".")
    [[ "$cur_backend" == "conflict" ]] && { log_error "Backend conflict (renv.lock and a nix file); resolve before toggling."; return 1; }
    [[ -f Dockerfile ]]                       && cur_docker=on  || cur_docker=off
    [[ -f .github/workflows/r-package.yml ]]  && cur_ci=on      || cur_ci=off
    [[ -f data-manifest.sha256 ]]             && cur_data=on    || cur_data=off
    [[ -f .pre-commit-config.yaml ]]          && cur_quality=on || cur_quality=off

    echo ""
    echo "Current: backend=$cur_backend  docker=$cur_docker  ci=$cur_ci  data=$cur_data  code-quality=$cur_quality"
    echo ""

    local use_gum=false
    has_gum && [[ -t 0 ]] && use_gum=true

    # --- Desired backend (single-select: renv | none) ----------------------
    # nix is documented as a future backend; only renv|none are buildable today.
    local want_backend
    if [[ "$use_gum" == true ]]; then
        want_backend=$(gum_choose "Package backend (current: $cur_backend)" renv none) \
            || { echo "Cancelled; no changes."; return 0; }
    else
        local _b
        zzc_read -r -p "Backend [renv/none] (current: $cur_backend): " _b
        want_backend="${_b:-$cur_backend}"
    fi
    case "$want_backend" in renv|none) ;; *) want_backend="$cur_backend" ;; esac

    # --- Desired feature checklist (multi-select) --------------------------
    local want_docker want_ci want_data want_quality
    if [[ "$use_gum" == true ]]; then
        local sel=() chosen
        [[ "$cur_docker" == on ]]  && sel+=("docker")
        [[ "$cur_ci" == on ]]      && sel+=("ci")
        [[ "$cur_data" == on ]]    && sel+=("data")
        [[ "$cur_quality" == on ]] && sel+=("code-quality")
        local sel_csv; sel_csv=$(IFS=,; echo "${sel[*]}")
        chosen=$(gum_multichoose "Features (space toggles, enter applies)" \
            "$sel_csv" docker ci data code-quality) \
            || { echo "Cancelled; no changes."; return 0; }
        grep -qx docker       <<< "$chosen" && want_docker=on  || want_docker=off
        grep -qx ci           <<< "$chosen" && want_ci=on      || want_ci=off
        grep -qx data         <<< "$chosen" && want_data=on    || want_data=off
        grep -qx code-quality <<< "$chosen" && want_quality=on || want_quality=off
    else
        want_docker=$(_toggle_ask  "Docker environment"        "$cur_docker")
        want_ci=$(_toggle_ask      "CI workflows"              "$cur_ci")
        want_data=$(_toggle_ask    "Data integrity hashing"    "$cur_data")
        want_quality=$(_toggle_ask "Code quality (pre-commit)" "$cur_quality")
    fi

    # --- Diff desired against current --------------------------------------
    local -a changes=()
    [[ "$want_backend" != "$cur_backend" ]] && changes+=("backend: $cur_backend -> $want_backend")
    [[ "$want_docker"  != "$cur_docker"  ]] && changes+=("docker: $cur_docker -> $want_docker")
    [[ "$want_ci"      != "$cur_ci"      ]] && changes+=("ci: $cur_ci -> $want_ci")
    [[ "$want_data"    != "$cur_data"    ]] && changes+=("data: $cur_data -> $want_data")
    [[ "$want_quality" != "$cur_quality" ]] && changes+=("code-quality: $cur_quality -> $want_quality")

    if [[ ${#changes[@]} -eq 0 ]]; then
        echo "No changes."
        return 0
    fi

    echo ""
    echo "Planned changes:"
    local c
    for c in "${changes[@]}"; do echo "  - $c"; done
    echo ""

    # --- Confirm once ------------------------------------------------------
    if [[ "$use_gum" == true ]]; then
        gum_confirm "Apply these changes?" || { echo "Cancelled; no changes."; return 0; }
    else
        local _ok
        zzc_read -r -p "Apply these changes? [y/N]: " _ok
        [[ "$_ok" =~ ^[Yy]$ ]] || { echo "Cancelled; no changes."; return 0; }
    fi

    # --- Apply (order matters: backend before docker so the Dockerfile is
    # regenerated in the right install mode) --------------------------------
    if [[ "$want_backend" != "$cur_backend" ]]; then
        if [[ "$want_backend" == "renv" ]]; then
            cmd_renv
        else
            ZZCOLLAB_ASSUME_YES=1 cmd_rm_renv
        fi
    fi

    if [[ "$want_docker" != "$cur_docker" ]]; then
        if [[ "$want_docker" == on ]]; then
            if [[ "$want_backend" == "none" ]]; then cmd_docker --no-renv; else cmd_docker; fi
        else
            cmd_rm_docker
        fi
    fi

    if [[ "$want_ci" != "$cur_ci" ]]; then
        if [[ "$want_ci" == on ]]; then _toggle_add_ci && log_success "Installed CI workflows"; else cmd_rm_cicd; fi
    fi

    [[ "$want_data" != "$cur_data" ]] && { [[ "$want_data" == on ]] && cmd_data || cmd_rm_data; }
    [[ "$want_quality" != "$cur_quality" ]] && { [[ "$want_quality" == on ]] && cmd_code_quality || cmd_rm_code_quality; }

    echo ""
    cmd_status "."
}
