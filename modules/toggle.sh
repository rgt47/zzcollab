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

# Install the CI workflow(s) for the configured forge (CI toggle -> on).
# GitHub gets the two Actions workflows; GitLab gets the single .gitlab-ci.yml.
# Forge comes from config (CONFIG_FORGE), defaulting to github.
_toggle_add_ci() {
    load_config 2>/dev/null || true
    if [[ "${CONFIG_FORGE:-github}" == gitlab ]]; then
        regenerate_template_file "gitlab/.gitlab-ci.yml" \
            ".gitlab-ci.yml" "GitLab CI" >/dev/null 2>&1
    else
        mkdir -p .github/workflows
        regenerate_template_file "workflows/r-package.yml" \
            ".github/workflows/r-package.yml" "check workflow" >/dev/null 2>&1
        regenerate_template_file "workflows/render-report.yml" \
            ".github/workflows/render-report.yml" "render workflow" >/dev/null 2>&1
    fi
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

# Info-box body shown in the fzf preview pane for one backend. One short
# paragraph per backend, kept next to the option list so labels and guidance
# stay in sync. Plain text; fzf draws the surrounding box.
_toggle_backend_info() {
    case "$1" in
        renv) printf '%s\n' \
            "Backend: renv (R lockfile)" \
            "Pins:    L1 - exact R package versions" \
            "Image:   pinned only when Docker is on" \
            "Deps:    renv, bundled in the project" ;;
        nix) printf '%s\n' \
            "Backend: nix (declarative environment)" \
            "Pins:    L2 - R, packages, and system libraries" \
            "Image:   reproducible without a container" \
            "Deps:    the nix package manager on the host" ;;
        none) printf '%s\n' \
            "Backend: none" \
            "Pins:    nothing - uses the ambient system R" \
            "Image:   not pinned" \
            "Use for: throwaway or exploratory work" ;;
    esac
}

# fzf-driven single-select backend chooser with a live info box. Writes one
# info file per backend to a temp dir, lists the default first so fzf
# highlights it, and echoes the chosen backend. Returns 1 when the user
# cancels (Esc). Cleans up the temp dir on every path.
_toggle_choose_backend() {
    local def="$1" cur="$2"
    local info_dir
    info_dir=$(mktemp -d "${TMPDIR:-/tmp}/zzc-backend.XXXXXX") || return 1
    local b
    for b in renv nix none; do _toggle_backend_info "$b" > "$info_dir/$b"; done
    # List the default backend first so it is the initially highlighted choice.
    local opts=(renv nix none)
    case "$def" in
        nix)  opts=(nix renv none) ;;
        none) opts=(none renv nix) ;;
    esac
    local chosen rc=0
    chosen=$(fzf_choose_preview "Package backend (current: $cur)" "$info_dir" \
        "${opts[@]}") || rc=$?
    rm -rf "$info_dir"
    [[ $rc -eq 0 ]] || return 1
    printf '%s\n' "$chosen"
}

# Info-box body shown in the fzf preview pane for one feature.
_toggle_feature_info() {
    case "$1" in
        docker) printf '%s\n' \
            "Docker environment" \
            "Adds:  Dockerfile + make r / make rstudio" \
            "Pins:  L2 - the full environment, for sharing" \
            "Cost:  image build time and disk" ;;
        ci) printf '%s\n' \
            "CI workflows (GitHub Actions)" \
            "Adds:  R CMD check + report render on push" \
            "Needs: a GitHub remote to run" \
            "Cost:  none locally" ;;
        data) printf '%s\n' \
            "Data integrity hashing" \
            "Adds:  data-manifest.sha256 over data/" \
            "Verch: detects silent changes to inputs" \
            "Pillar: #5 - research data" ;;
        code-quality) printf '%s\n' \
            "Code quality (pre-commit)" \
            "Adds:  .pre-commit-config.yaml hooks" \
            "Runs:  lint/style checks before commit" \
            "Needs: pre-commit installed" ;;
        tests) printf '%s\n' \
            "Unit testing (tinytest)" \
            "Adds:  inst/tinytest + a sample test" \
            "Runner: at R CMD check time" \
            "Pillar: #4 - source code" ;;
        cloud) printf '%s\n' \
            "Cloud launch (devcontainer / Workspaces)" \
            "Adds:  devcontainer (GitHub) or .devfile.yaml (GitLab)" \
            "Use:   Codespaces / Binder one-click" \
            "Cost:  none locally" ;;
        validate-strict) printf '%s\n' \
            "Validation: strict" \
            "Scans: tests/ and vignettes/ for deps" \
            "Effect: zzrenvcheck flags undeclared use" \
            "Default: on" ;;
        validate-fix) printf '%s\n' \
            "Validation: auto-fix" \
            "Effect: writes missing deps to DESCRIPTION" \
            "Scope:  zzrenvcheck on validate / check-renv" \
            "Default: off" ;;
        git) printf '%s\n' \
            "Version control (git)" \
            "Runs:   git init + .gitignore + initial commit" \
            "Pillar: makes the compendium version-controlled" \
            "Remove: zzc rm git (this wizard never deletes)" ;;
        remote) printf '%s\n' \
            "Create remote repository now" \
            "Runs:   zzc github / zzc gitlab for the chosen forge" \
            "Default: off (opt-in); private visibility" \
            "Guard:  hidden for confidential projects" ;;
        *) printf 'No info for: %s\n' "$1" ;;
    esac
}

# fzf-driven feature checklist with a live info box. PRESELECTED_CSV is the
# comma-separated set of initially-on features; the remaining args are the full
# option list in display order. Echoes the chosen (on) features one per line -
# the same shape gum_multichoose returns - so the caller's grep parse is shared.
# Returns 1 when the user cancels (Esc).
_toggle_choose_features() {
    local sel_csv="$1"; shift
    local opts=("$@")
    local work
    work=$(mktemp -d "${TMPDIR:-/tmp}/zzc-feat.XXXXXX") || return 1
    local info_dir="$work/info" state="$work/state"
    mkdir -p "$info_dir"
    local o
    for o in "${opts[@]}"; do
        _toggle_feature_info "$o" > "$info_dir/$o"
        if [[ ",$sel_csv," == *",$o,"* ]]; then
            printf '%s on\n'  "$o" >> "$state"
        else
            printf '%s off\n' "$o" >> "$state"
        fi
    done
    local rc=0
    fzf_checklist_preview "Features" "$info_dir" "$state" || rc=$?
    if [[ $rc -eq 0 ]]; then
        awk '$2 == "on" { print $1 }' "$state"
    fi
    rm -rf "$work"
    return $rc
}

# Info-box body shown in the fzf preview pane for one forge.
_toggle_forge_info() {
    case "$1" in
        github) printf '%s\n' \
            "Forge:    GitHub" \
            "CI:       .github/workflows (Actions)" \
            "Remote:   zzc github (gh CLI)" \
            "Cloud:    Codespaces (devcontainer)" ;;
        gitlab) printf '%s\n' \
            "Forge:    GitLab (incl. self-hosted)" \
            "CI:       .gitlab-ci.yml" \
            "Remote:   zzc gitlab (glab CLI)" \
            "Cloud:    Workspaces (.devfile.yaml)" ;;
        none) printf '%s\n' \
            "Forge:    none" \
            "CI:       not installed" \
            "Remote:   set up manually" \
            "Use for:  local-only or other forges" ;;
    esac
}

# fzf-driven single-select forge chooser with a live info box. Mirrors
# _toggle_choose_backend: writes per-forge info files, lists the default first,
# echoes the chosen forge. Returns 1 on cancel (Esc).
_toggle_choose_forge() {
    local def="$1" cur="$2"
    local info_dir
    info_dir=$(mktemp -d "${TMPDIR:-/tmp}/zzc-forge.XXXXXX") || return 1
    local f
    for f in github gitlab none; do _toggle_forge_info "$f" > "$info_dir/$f"; done
    local opts=(github gitlab none)
    case "$def" in
        gitlab) opts=(gitlab github none) ;;
        none)   opts=(none github gitlab) ;;
    esac
    local chosen rc=0
    chosen=$(fzf_choose_preview "Git forge (current: $cur)" "$info_dir" \
        "${opts[@]}") || rc=$?
    rm -rf "$info_dir"
    [[ $rc -eq 0 ]] || return 1
    printf '%s\n' "$chosen"
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
    local cur_backend cur_docker cur_ci cur_data cur_quality cur_tests cur_cloud cur_forge
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
        cur_forge="${CONFIG_FORGE:-github}"
    else
        cur_backend=$(_zzc_detect_backend ".")
        [[ "$cur_backend" == "conflict" ]] && { log_error "Backend conflict (renv.lock and a nix file); resolve first."; return 1; }
        [[ -f Dockerfile ]]                       && cur_docker=on  || cur_docker=off
        [[ "$(zzc_ci_forge .)" != none ]]         && cur_ci=on      || cur_ci=off
        [[ -f data-manifest.sha256 ]]             && cur_data=on    || cur_data=off
        [[ -f .pre-commit-config.yaml ]]          && cur_quality=on || cur_quality=off
        [[ -d inst/tinytest ]]                    && cur_tests=on   || cur_tests=off
        { [[ -d .devcontainer ]] || [[ -d .binder ]] || [[ -f .devfile.yaml ]]; } && cur_cloud=on || cur_cloud=off
        # Forge: an installed CI is the most reliable signal; otherwise the
        # configured forge (default github).
        cur_forge=$(zzc_ci_forge .)
        [[ "$cur_forge" == none ]] && cur_forge="${CONFIG_FORGE:-github}"
    fi

    # Dependency-validation defaults are config-backed (not artifacts), so they
    # are read from config in every mode (strict default on, fix default off).
    load_config 2>/dev/null || true
    local cur_vstrict cur_vfix
    [[ "${CONFIG_VALIDATE_STRICT:-true}" == "false" ]] && cur_vstrict=off || cur_vstrict=on
    [[ "${CONFIG_VALIDATE_FIX:-false}"   == "true"  ]] && cur_vfix=on    || cur_vfix=off

    # Pre-selected defaults: current state, except init recommends renv + Docker
    # (overridable by the configured global feature defaults).
    local def_backend="$cur_backend" def_docker="$cur_docker"
    local def_ci="$cur_ci" def_data="$cur_data" def_quality="$cur_quality"
    local def_tests="$cur_tests" def_cloud="$cur_cloud"
    local def_vstrict="$cur_vstrict" def_vfix="$cur_vfix"
    local def_forge="$cur_forge"
    if [[ "$mode" == init ]]; then
        load_config 2>/dev/null || true
        def_backend="${CONFIG_FEAT_BACKEND:-renv}"
        def_docker="${CONFIG_FEAT_DOCKER:-on}"
        def_ci="${CONFIG_FEAT_CI:-$cur_ci}"
        def_data="${CONFIG_FEAT_DATA:-$cur_data}"
        def_quality="${CONFIG_FEAT_CODE_QUALITY:-$cur_quality}"
        def_tests="${CONFIG_FEAT_TESTS:-$cur_tests}"
        def_cloud="${CONFIG_FEAT_CLOUD:-$cur_cloud}"
        def_forge="${CONFIG_FORGE:-github}"
        echo "Reproducibility setup. Recommended: renv + Docker (untick to skip)."
    fi

    echo ""
    if [[ "$mode" == global ]]; then
        echo "Global defaults for new projects (~/.zzcollab/config.yaml):"
    fi
    echo "Current: forge=$cur_forge  backend=$cur_backend  docker=$cur_docker  ci=$cur_ci  data=$cur_data  code-quality=$cur_quality  tests=$cur_tests  cloud=$cur_cloud"
    echo ""

    local use_gum=false
    has_gum && [[ -t 0 ]] && use_gum=true
    # fzf adds a live info box to the backend chooser and feature checklist;
    # preferred over gum when present, with the gum/text paths unchanged as the
    # fallback.
    local use_fzf=false
    has_fzf && [[ -t 0 ]] && use_fzf=true

    # --- Desired backend (single-select: renv | none) ----------------------
    # nix is documented as a future backend; only renv|none are buildable today.
    # Backend is single-select (renv | nix | none): the three are mutually
    # exclusive, so they are values of one choice, not checklist items.
    local want_backend
    if [[ "$use_fzf" == true ]]; then
        want_backend=$(_toggle_choose_backend "$def_backend" "$cur_backend") \
            || { echo "Cancelled; no changes."; return 0; }
    elif [[ "$use_gum" == true ]]; then
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

    # --- Desired forge (single-select: github | gitlab | none) -------------
    # The forge drives which CI is installed, the remote-creation command, and
    # the cloud-launch platform. Mutually exclusive, so a single choice.
    local want_forge
    if [[ "$use_fzf" == true ]]; then
        want_forge=$(_toggle_choose_forge "$def_forge" "$cur_forge") \
            || { echo "Cancelled; no changes."; return 0; }
    elif [[ "$use_gum" == true ]]; then
        local _fopts=(github gitlab none)
        case "$def_forge" in
            gitlab) _fopts=(gitlab github none) ;;
            none)   _fopts=(none github gitlab) ;;
        esac
        want_forge=$(gum_choose "Git forge (current: $cur_forge)" "${_fopts[@]}") \
            || { echo "Cancelled; no changes."; return 0; }
    else
        local _f
        zzc_read -r -p "Forge [github/gitlab/none] (default: $def_forge): " _f
        want_forge="${_f:-$def_forge}"
    fi
    case "$want_forge" in github|gitlab|none) ;; *) want_forge="$def_forge" ;; esac

    # --- Version-control items (init mode only) ----------------------------
    # git (default on) and remote (default off) are creation-time, one-shot
    # actions, not steady-state toggles: removal is owned by `zzc rm git` /
    # `zzc rm github`. They are therefore offered only during `zzc init`, never
    # in a later `zzc toggle`. See docs/git-setup-flow-spec.md.
    # def_remote pre-selects the "create remote" checkbox. It is off unless the
    # user opted into auto-creation via config (auto_github -> CONFIG_AUTO_GITHUB);
    # this is the only wiring that makes that preference take effect. The actual
    # creation still runs through the guarded path below (show_remote requires a
    # real forge, an interactive session, an installed+authenticated forge CLI,
    # and remote_allowed).
    local cur_git=off cur_remote=off def_git=on def_remote=off
    [[ "${CONFIG_AUTO_GITHUB:-false}" == true ]] && def_remote=on
    local show_git=false show_remote=false
    if [[ "$mode" == init ]]; then
        [[ -d .git ]] && cur_git=on
        git remote get-url origin &>/dev/null && cur_remote=on
        show_git=true
        # remote is offered only when it can actually succeed: a real forge, an
        # interactive session, the forge CLI installed and authenticated, and
        # the confidential-repo guard permitting it. When the only thing missing
        # is a fixable tooling/auth step, say so rather than hiding the option
        # with no explanation (a confidential denial stays quiet, by design).
        if [[ "$want_forge" != none ]] && [[ -t 0 ]] && remote_allowed; then
            local _forge_cli=gh
            [[ "$want_forge" == gitlab ]] && _forge_cli=glab
            if ! command -v "$_forge_cli" >/dev/null 2>&1; then
                echo "  Note: 'create remote' hidden - $_forge_cli is not installed."
            elif ! "$_forge_cli" auth status >/dev/null 2>&1; then
                echo "  Note: 'create remote' hidden - not logged in to $_forge_cli."
                echo "        Run '$_forge_cli auth login', then 'zzc github' from the project root."
            else
                show_remote=true
            fi
        fi
    fi

    # Build the checklist option list, appending the version-control items when
    # shown, so the static feature set and the init-only items share one widget.
    local -a feat_opts=(docker ci data code-quality tests cloud \
        validate-strict validate-fix)
    [[ "$show_git" == true ]]    && feat_opts+=(git)
    [[ "$show_remote" == true ]] && feat_opts+=(remote)

    # --- Desired feature checklist (multi-select) --------------------------
    local want_docker want_ci want_data want_quality want_tests want_cloud
    local want_vstrict want_vfix want_git="$cur_git" want_remote=off
    if [[ "$use_fzf" == true || "$use_gum" == true ]]; then
        local sel=() chosen
        [[ "$def_docker" == on ]]  && sel+=("docker")
        [[ "$def_ci" == on ]]      && sel+=("ci")
        [[ "$def_data" == on ]]    && sel+=("data")
        [[ "$def_quality" == on ]] && sel+=("code-quality")
        [[ "$def_tests" == on ]]   && sel+=("tests")
        [[ "$def_cloud" == on ]]   && sel+=("cloud")
        # validate-strict / validate-fix are dependency-validation defaults
        # (zzrenvcheck), not artifacts; carried in the same checklist.
        [[ "$def_vstrict" == on ]] && sel+=("validate-strict")
        [[ "$def_vfix" == on ]]    && sel+=("validate-fix")
        [[ "$show_git" == true && "$def_git" == on ]]       && sel+=("git")
        [[ "$show_remote" == true && "$def_remote" == on ]] && sel+=("remote")
        local sel_csv; sel_csv=$(IFS=,; echo "${sel[*]}")
        if [[ "$use_fzf" == true ]]; then
            chosen=$(_toggle_choose_features "$sel_csv" "${feat_opts[@]}") \
                || { echo "Cancelled; no changes."; return 0; }
        else
            chosen=$(gum_multichoose "Features (space toggles, enter applies)" \
                "$sel_csv" "${feat_opts[@]}") \
                || { echo "Cancelled; no changes."; return 0; }
        fi
        grep -qx docker          <<< "$chosen" && want_docker=on  || want_docker=off
        grep -qx ci              <<< "$chosen" && want_ci=on      || want_ci=off
        grep -qx data            <<< "$chosen" && want_data=on    || want_data=off
        grep -qx code-quality    <<< "$chosen" && want_quality=on || want_quality=off
        grep -qx tests           <<< "$chosen" && want_tests=on   || want_tests=off
        grep -qx cloud           <<< "$chosen" && want_cloud=on   || want_cloud=off
        grep -qx validate-strict <<< "$chosen" && want_vstrict=on || want_vstrict=off
        grep -qx validate-fix    <<< "$chosen" && want_vfix=on    || want_vfix=off
        [[ "$show_git" == true ]]    && { grep -qx git    <<< "$chosen" && want_git=on    || want_git=off; }
        [[ "$show_remote" == true ]] && { grep -qx remote <<< "$chosen" && want_remote=on || want_remote=off; }
    else
        want_docker=$(_toggle_ask  "Docker environment"          "$def_docker")
        want_ci=$(_toggle_ask      "CI workflows"                "$def_ci")
        want_data=$(_toggle_ask    "Data integrity hashing"      "$def_data")
        want_quality=$(_toggle_ask "Code quality (pre-commit)"   "$def_quality")
        want_tests=$(_toggle_ask   "Unit testing (tinytest)"     "$def_tests")
        want_cloud=$(_toggle_ask   "Cloud launch (devcontainer)" "$def_cloud")
        want_vstrict=$(_toggle_ask "Validation: strict (scan tests/ & vignettes/)" "$def_vstrict")
        want_vfix=$(_toggle_ask    "Validation: auto-fix DESCRIPTION" "$def_vfix")
        [[ "$show_git" == true ]]    && want_git=$(_toggle_ask    "Initialize git + first commit" "$def_git")
        [[ "$show_remote" == true ]] && want_remote=$(_toggle_ask "Create $want_forge remote now"  "$def_remote")
    fi

    # Backend nudge (advisory, not a constraint): renv pins packages (L1) but
    # reaches L2 only with Docker; flag the gap rather than forcing it.
    if [[ "$want_backend" == renv && "$want_docker" == off ]]; then
        echo "  Note: renv pins packages (L1); enable Docker to pin the environment (L2)."
    fi

    # --- Global mode: persist the choices as new-project defaults ----------
    if [[ "$mode" == global ]]; then
        config_set forge                 "$want_forge"   >/dev/null
        config_set features-backend      "$want_backend" >/dev/null
        config_set features-docker       "$want_docker"  >/dev/null
        config_set features-ci           "$want_ci"      >/dev/null
        config_set features-data         "$want_data"    >/dev/null
        config_set features-code-quality "$want_quality" >/dev/null
        config_set features-tests        "$want_tests"   >/dev/null
        config_set features-cloud        "$want_cloud"   >/dev/null
        config_set validate-strict "$([[ "$want_vstrict" == on ]] && echo true || echo false)" >/dev/null
        config_set validate-fix    "$([[ "$want_vfix" == on ]] && echo true || echo false)"    >/dev/null
        echo ""
        log_success "Saved global feature defaults for new projects."
        echo "  forge=$want_forge  backend=$want_backend  docker=$want_docker  ci=$want_ci  data=$want_data  code-quality=$want_quality  tests=$want_tests  cloud=$want_cloud"
        echo "  validate: strict=$want_vstrict  fix=$want_vfix"
        return 0
    fi

    # --- Diff desired against current --------------------------------------
    local -a changes=()
    [[ "$want_forge"   != "$cur_forge"   ]] && changes+=("forge: $cur_forge -> $want_forge")
    [[ "$want_backend" != "$cur_backend" ]] && changes+=("backend: $cur_backend -> $want_backend")
    [[ "$want_docker"  != "$cur_docker"  ]] && changes+=("docker: $cur_docker -> $want_docker")
    [[ "$want_ci"      != "$cur_ci"      ]] && changes+=("ci: $cur_ci -> $want_ci")
    [[ "$want_data"    != "$cur_data"    ]] && changes+=("data: $cur_data -> $want_data")
    [[ "$want_quality" != "$cur_quality" ]] && changes+=("code-quality: $cur_quality -> $want_quality")
    [[ "$want_tests"   != "$cur_tests"   ]] && changes+=("tests: $cur_tests -> $want_tests")
    [[ "$want_cloud"   != "$cur_cloud"   ]] && changes+=("cloud: $cur_cloud -> $want_cloud")
    [[ "$want_vstrict" != "$cur_vstrict" ]] && changes+=("validate-strict: $cur_vstrict -> $want_vstrict")
    [[ "$want_vfix"    != "$cur_vfix"    ]] && changes+=("validate-fix: $cur_vfix -> $want_vfix")
    [[ "$show_git" == true && "$want_git" != "$cur_git" ]] && changes+=("git: $cur_git -> $want_git")
    [[ "$show_remote" == true && "$want_remote" == on ]]   && changes+=("remote: create $want_forge repository")

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
    # Persist the forge project-local first, so _toggle_add_ci and cmd_cloud
    # (which read CONFIG_FORGE via load_config) act on the chosen forge.
    if [[ "$want_forge" != "$cur_forge" ]]; then
        config_set forge "$want_forge" true >/dev/null
    fi

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

    # Forge change while CI stays on: swap the CI files to the new forge.
    if [[ "$want_ci" == on && "$cur_ci" == on && "$want_forge" != "$cur_forge" ]]; then
        cmd_rm_cicd >/dev/null 2>&1
        _toggle_add_ci && log_success "Switched CI to $want_forge"
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

    # Dependency-validation defaults are config (not artifacts): persist them
    # project-local so this compendium's `zzc validate` / `make check-renv`
    # picks them up. Explicit --strict/--fix flags still override per-invocation.
    if [[ "$want_vstrict" != "$cur_vstrict" ]]; then
        config_set validate-strict "$([[ "$want_vstrict" == on ]] && echo true || echo false)" true >/dev/null
    fi
    if [[ "$want_vfix" != "$cur_vfix" ]]; then
        config_set validate-fix "$([[ "$want_vfix" == on ]] && echo true || echo false)" true >/dev/null
    fi

    # Version control genuinely last, after every file and config mutation
    # above (CI, Docker, zzcollab.yaml writes), so the initial commit captures
    # the complete scaffold. git init is idempotent (cmd_git no-ops when .git
    # exists); removal is not offered here, only via `zzc rm git`.
    if [[ "$show_git" == true && "$want_git" == on && "$cur_git" == off ]]; then
        cmd_git && _ensure_initial_commit
    fi
    # Remote creation (opt-in) dispatches to the forge command, which re-checks
    # the confidential guard, auth, and an existing remote before pushing.
    if [[ "$show_remote" == true && "$want_remote" == on ]]; then
        case "$want_forge" in
            github) cmd_github ;;
            gitlab) cmd_gitlab ;;
        esac
    fi

    echo ""
    cmd_status "."
}
