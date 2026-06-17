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
    local mode=toggle
    case "${1:-}" in
        help|--help|-h)
            cat << 'EOF'
TOGGLE - view and change reproducibility features

USAGE:
    zzc toggle            # change this project's features
    zzc toggle --global   # change the defaults new projects start from

Interactively shows the features (backend, Docker, CI, data integrity,
code quality, unit tests, cloud launch), lets you change them, confirms
the diff, and applies it by reusing the per-feature commands. With
--global it edits ~/.zzcollab/config.yaml instead of a project.
Cancellation makes no changes.

For scripts and CI use the explicit commands instead:
    zzc renv | zzc docker | zzc data | zzc code-quality | zzc tests | zzc cloud
    zzc rm <feature>
EOF
            return 0 ;;
        --global) mode=global ;;
    esac

    if [[ "$mode" != global ]]; then
        if [[ ! -f .zzcollab && ! ( -f DESCRIPTION && -f Makefile ) ]]; then
            log_error "Not a zzcollab workspace (no .zzcollab marker or DESCRIPTION)."
            return 1
        fi
    fi
    run_feature_wizard "$mode"
}

# run_feature_wizard [init|toggle] - the one wizard shared by cmd_init (Phase 3,
# with the scaffold's defaults present) and cmd_toggle (existing project). It
# detects the current state by presence, presents the backend (single-select)
# and the feature checklist (multi-select), diffs the desired state against the
# current one, confirms once, applies via the per-feature commands, and prints
# zzc status. In init mode the pre-selected defaults are the recommended L2 set
# (renv + Docker); in toggle mode they mirror the current state. Non-interactive
# (accept-defaults) makes no changes.
run_feature_wizard() {
    local mode="${1:-toggle}"

    # Accept-defaults / non-interactive: make no changes. Init under
    # accept-defaults therefore scaffolds without renv/Docker, as before.
    if [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
        if [[ "$mode" == init ]]; then
            log_info "Non-interactive: skipping reproducibility setup."
            log_info "Add it later with 'zzc toggle', 'zzc renv', or 'zzc docker'."
        else
            echo "Accept-defaults: no changes."
        fi
        return 0
    fi

    # --- Detect current state ----------------------------------------------
    local cur_backend cur_docker cur_ci cur_data cur_quality cur_tests cur_cloud
    if [[ "$mode" == global ]]; then
        # Global mode reads the configured defaults (empty -> recommendation),
        # not any project's artifacts.
        load_config 2>/dev/null || true
        cur_backend="${CONFIG_FEAT_BACKEND:-renv}"
        cur_docker="${CONFIG_FEAT_DOCKER:-on}"
        cur_ci="${CONFIG_FEAT_CI:-on}"
        cur_data="${CONFIG_FEAT_DATA:-off}"
        cur_quality="${CONFIG_FEAT_CODE_QUALITY:-off}"
        cur_tests="${CONFIG_FEAT_TESTS:-on}"
        cur_cloud="${CONFIG_FEAT_CLOUD:-on}"
    else
        cur_backend=$(_zzc_detect_backend ".")
        [[ "$cur_backend" == "conflict" ]] && { log_error "Backend conflict (renv.lock and a nix file); resolve first."; return 1; }
        [[ -f Dockerfile ]]                       && cur_docker=on  || cur_docker=off
        [[ -f .github/workflows/r-package.yml ]]  && cur_ci=on      || cur_ci=off
        [[ -f data-manifest.sha256 ]]             && cur_data=on    || cur_data=off
        [[ -f .pre-commit-config.yaml ]]          && cur_quality=on || cur_quality=off
        [[ -d inst/tinytest ]]                    && cur_tests=on   || cur_tests=off
        { [[ -d .devcontainer ]] || [[ -d .binder ]]; } && cur_cloud=on || cur_cloud=off
    fi

    # Pre-selected defaults: current state, except init recommends renv + Docker
    # (overridable by the configured global feature defaults).
    local def_backend="$cur_backend" def_docker="$cur_docker"
    local def_ci="$cur_ci" def_data="$cur_data" def_quality="$cur_quality"
    local def_tests="$cur_tests" def_cloud="$cur_cloud"
    if [[ "$mode" == init ]]; then
        load_config 2>/dev/null || true
        def_backend="${CONFIG_FEAT_BACKEND:-renv}"
        def_docker="${CONFIG_FEAT_DOCKER:-on}"
        def_ci="${CONFIG_FEAT_CI:-$cur_ci}"
        def_data="${CONFIG_FEAT_DATA:-$cur_data}"
        def_quality="${CONFIG_FEAT_CODE_QUALITY:-$cur_quality}"
        def_tests="${CONFIG_FEAT_TESTS:-$cur_tests}"
        def_cloud="${CONFIG_FEAT_CLOUD:-$cur_cloud}"
        echo "Reproducibility setup. Recommended: renv + Docker (untick to skip)."
    fi

    echo ""
    if [[ "$mode" == global ]]; then
        echo "Global defaults for new projects (~/.zzcollab/config.yaml):"
    fi
    echo "Current: backend=$cur_backend  docker=$cur_docker  ci=$cur_ci  data=$cur_data  code-quality=$cur_quality  tests=$cur_tests  cloud=$cur_cloud"
    echo ""

    local use_gum=false
    has_gum && [[ -t 0 ]] && use_gum=true

    # --- Desired backend (single-select: renv | none) ----------------------
    # nix is documented as a future backend; only renv|none are buildable today.
    # Backend is single-select (renv | nix | none): the three are mutually
    # exclusive, so they are values of one choice, not checklist items.
    local want_backend
    if [[ "$use_gum" == true ]]; then
        # List the default backend first so it is the highlighted choice.
        local _opts=(renv nix none)
        case "$def_backend" in
            nix)  _opts=(nix renv none) ;;
            none) _opts=(none renv nix) ;;
        esac
        want_backend=$(gum_choose "Package backend (current: $cur_backend)" "${_opts[@]}") \
            || { echo "Cancelled; no changes."; return 0; }
    else
        local _b
        zzc_read -r -p "Backend [renv/nix/none] (default: $def_backend): " _b
        want_backend="${_b:-$def_backend}"
    fi
    case "$want_backend" in renv|nix|none) ;; *) want_backend="$def_backend" ;; esac

    # Nix nudge (Section 12.3): Nix reaches L2 without a container, so default
    # Docker off when Nix is chosen. A default, not a constraint.
    if [[ "$want_backend" == nix && "$cur_backend" != nix ]]; then
        def_docker="off"
        echo "  Note: Nix pins the environment (L2) without a container; Docker is for distribution only."
    fi

    # --- Desired feature checklist (multi-select) --------------------------
    local want_docker want_ci want_data want_quality want_tests want_cloud
    if [[ "$use_gum" == true ]]; then
        local sel=() chosen
        [[ "$def_docker" == on ]]  && sel+=("docker")
        [[ "$def_ci" == on ]]      && sel+=("ci")
        [[ "$def_data" == on ]]    && sel+=("data")
        [[ "$def_quality" == on ]] && sel+=("code-quality")
        [[ "$def_tests" == on ]]   && sel+=("tests")
        [[ "$def_cloud" == on ]]   && sel+=("cloud")
        local sel_csv; sel_csv=$(IFS=,; echo "${sel[*]}")
        chosen=$(gum_multichoose "Features (space toggles, enter applies)" \
            "$sel_csv" docker ci data code-quality tests cloud) \
            || { echo "Cancelled; no changes."; return 0; }
        grep -qx docker       <<< "$chosen" && want_docker=on  || want_docker=off
        grep -qx ci           <<< "$chosen" && want_ci=on      || want_ci=off
        grep -qx data         <<< "$chosen" && want_data=on    || want_data=off
        grep -qx code-quality <<< "$chosen" && want_quality=on || want_quality=off
        grep -qx tests        <<< "$chosen" && want_tests=on   || want_tests=off
        grep -qx cloud        <<< "$chosen" && want_cloud=on   || want_cloud=off
    else
        want_docker=$(_toggle_ask  "Docker environment"        "$def_docker")
        want_ci=$(_toggle_ask      "CI workflows"              "$def_ci")
        want_data=$(_toggle_ask    "Data integrity hashing"    "$def_data")
        want_quality=$(_toggle_ask "Code quality (pre-commit)" "$def_quality")
        want_tests=$(_toggle_ask   "Unit testing (tinytest)"   "$def_tests")
        want_cloud=$(_toggle_ask   "Cloud launch (devcontainer)" "$def_cloud")
    fi

    # Backend nudge (advisory, not a constraint): renv pins packages (L1) but
    # reaches L2 only with Docker; flag the gap rather than forcing it.
    if [[ "$want_backend" == renv && "$want_docker" == off ]]; then
        echo "  Note: renv pins packages (L1); enable Docker to pin the environment (L2)."
    fi

    # --- Global mode: persist the choices as new-project defaults ----------
    if [[ "$mode" == global ]]; then
        config_set features-backend      "$want_backend" >/dev/null
        config_set features-docker       "$want_docker"  >/dev/null
        config_set features-ci           "$want_ci"      >/dev/null
        config_set features-data         "$want_data"    >/dev/null
        config_set features-code-quality "$want_quality" >/dev/null
        config_set features-tests        "$want_tests"   >/dev/null
        config_set features-cloud        "$want_cloud"   >/dev/null
        echo ""
        log_success "Saved global feature defaults for new projects."
        echo "  backend=$want_backend  docker=$want_docker  ci=$want_ci  data=$want_data  code-quality=$want_quality  tests=$want_tests  cloud=$want_cloud"
        return 0
    fi

    # --- Diff desired against current --------------------------------------
    local -a changes=()
    [[ "$want_backend" != "$cur_backend" ]] && changes+=("backend: $cur_backend -> $want_backend")
    [[ "$want_docker"  != "$cur_docker"  ]] && changes+=("docker: $cur_docker -> $want_docker")
    [[ "$want_ci"      != "$cur_ci"      ]] && changes+=("ci: $cur_ci -> $want_ci")
    [[ "$want_data"    != "$cur_data"    ]] && changes+=("data: $cur_data -> $want_data")
    [[ "$want_quality" != "$cur_quality" ]] && changes+=("code-quality: $cur_quality -> $want_quality")
    [[ "$want_tests"   != "$cur_tests"   ]] && changes+=("tests: $cur_tests -> $want_tests")
    [[ "$want_cloud"   != "$cur_cloud"   ]] && changes+=("cloud: $cur_cloud -> $want_cloud")

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
        # Backends are mutually exclusive: remove the old one before adding the
        # new, so renv.lock and a nix file never coexist (status would flag it).
        [[ "$cur_backend" == renv ]] && ZZCOLLAB_ASSUME_YES=1 cmd_rm_renv
        [[ "$cur_backend" == nix ]]  && cmd_rm_nix
        case "$want_backend" in
            renv) cmd_renv ;;
            nix)  cmd_nix ;;
            none) : ;;
        esac
    fi

    if [[ "$want_docker" != "$cur_docker" ]]; then
        if [[ "$want_docker" == on ]]; then
            if [[ "$want_backend" == "none" ]]; then cmd_docker --no-renv; else cmd_docker; fi
        else
            cmd_rm_docker
        fi
    fi

    if [[ "$want_ci" != "$cur_ci" ]]; then
        if [[ "$want_ci" == on ]]; then
            _toggle_add_ci && log_success "Installed CI workflows"
            # Coupling: the render workflow renders analysis/**/report.Rmd. With
            # no report it has nothing to render, so offer to scaffold one.
            if [[ -z "$(find analysis -name 'report.Rmd' 2>/dev/null | head -1)" ]] \
               && [[ -f "$ZZCOLLAB_TEMPLATES_DIR/report.Rmd" ]]; then
                local _scaffold=false
                if [[ "$use_gum" == true ]]; then
                    gum_confirm "Render CI is on but no report exists. Scaffold analysis/report/report.Rmd?" && _scaffold=true
                else
                    local _a
                    zzc_read -r -p "  Render CI is on but no report exists. Scaffold analysis/report/report.Rmd? [y/N]: " _a
                    [[ "$_a" =~ ^[Yy]$ ]] && _scaffold=true
                fi
                if [[ "$_scaffold" == true ]]; then
                    mkdir -p analysis/report
                    install_template "report.Rmd" "analysis/report/report.Rmd" "report" \
                        && log_success "Scaffolded analysis/report/report.Rmd"
                fi
            fi
        else
            cmd_rm_cicd
        fi
    fi

    [[ "$want_data" != "$cur_data" ]] && { [[ "$want_data" == on ]] && cmd_data || cmd_rm_data; }
    [[ "$want_quality" != "$cur_quality" ]] && { [[ "$want_quality" == on ]] && cmd_code_quality || cmd_rm_code_quality; }
    [[ "$want_tests" != "$cur_tests" ]] && { [[ "$want_tests" == on ]] && cmd_tests || cmd_rm_tests; }
    [[ "$want_cloud" != "$cur_cloud" ]] && { [[ "$want_cloud" == on ]] && cmd_cloud || cmd_rm_cloud; }

    echo ""
    cmd_status "."
}
