#!/bin/bash
##############################################################################
# ZZCOLLAB CAPTURE TEST MATRIX
##############################################################################
#
# Phase 4 of the reproducibility-toggle plan (Section 7). Scaffolds throwaway
# compendia across the capture combinations and asserts the generator's output:
# the reported level, the presence-driven artifacts, the .zzcollab-state record,
# and zzc verify coherence. These are the rows that need no Docker build, so the
# suite runs in ordinary CI; the build rows live in test-scaffold-build-run.sh.
#
#   backend (renv) | environment (Docker) | level | how reached
#   ---------------+----------------------+-------+--------------------------
#   off            | off                  | L0    | init only
#   on             | off                  | L1    | init + zzc renv
#   off            | on                   | L2    | init + zzc docker --no-renv
#   on             | on                   | L2    | init + zzc docker
#
# Run individually:
#   bash tests/shell/test-capture-matrix.sh
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

ZZCOLLAB_SH="$ZZCOLLAB_ROOT/zzcollab.sh"

##############################################################################
# Fixtures: a seeded user config makes init non-interactive (the identity gate
# blocks init otherwise), and a scaffold helper drives init into a fresh dir.
##############################################################################

# Seed a minimal user config under the temp dir and point zzcollab at it.
# Must be called after setup_test (which cd's into TEST_TEMP_DIR).
_seed_config() {
    mkdir -p cfg proj
    cat > cfg/config.yaml << 'EOF'
author:
  name: "Matrix Tester"
  email: "matrix@example.com"
  affiliation: "Test Institute"
defaults:
  profile_name: "analysis"
  r_version: "4.6.0"
license:
  type: "GPL-3"
EOF
    export ZZCOLLAB_CONFIG_USER="$PWD/cfg/config.yaml"
    export ZZCOLLAB_CONFIG_USER_DIR="$PWD/cfg"
}

# Run a zzcollab command in the project dir, non-interactively, quietly.
# (R version comes from the seeded config; the combinable-command dispatcher
# does not accept a trailing --r-version after the renv route.)
_zzc() {
    ZZCOLLAB_ACCEPT_DEFAULTS=true ZZCOLLAB_NO_BUILD=true \
        bash "$ZZCOLLAB_SH" "$@" < /dev/null > /dev/null 2>&1
}

# Remove renv with the confirmation supplied. ACCEPT_DEFAULTS is deliberately
# NOT set here: under accept-defaults zzc_read ignores piped input and defaults
# the [y/N] confirm to No, cancelling the removal.
_zzc_rm_renv() {
    printf 'y\n' | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" rm renv > /dev/null 2>&1
}

# Echo the level token (L0/L1/L2/L3) zzc status reports for the current dir.
_status_level() {
    ZZCOLLAB_ACCEPT_DEFAULTS=true bash "$ZZCOLLAB_SH" status . < /dev/null 2>&1 \
        | sed -n 's/.*level: \(L[0-9]\).*/\1/p' | head -1
}

# Run zzc verify (coherence tier) and echo its exit code.
_verify_rc() {
    ZZCOLLAB_ACCEPT_DEFAULTS=true bash "$ZZCOLLAB_SH" verify . < /dev/null > /dev/null 2>&1
    echo $?
}

# Read a key from .zzcollab-state in the current dir (local to this test, so the
# harness need not source status.sh).
_state_get() {
    [[ -f .zzcollab-state ]] || return 0
    grep -m1 "^${1}=" .zzcollab-state 2>/dev/null | cut -d= -f2- || true
}

##############################################################################
# Cell: off / off -> L0 (init only, no renv, no Docker)
##############################################################################

test_matrix_L0_locatable() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init exited non-zero"; teardown_test; return 1; }

    assert_file_exists "DESCRIPTION"     "L0: DESCRIPTION must exist"
    assert_file_exists ".zzcollab-state" "L0: state record must exist"
    assert_false "[[ -f renv.lock ]]"    "L0: no renv.lock expected"
    assert_false "[[ -f Dockerfile ]]"   "L0: no Dockerfile expected"
    assert_equals "L0" "$(_status_level)" "L0: status level"
    assert_equals "0"  "$(_verify_rc)"    "L0: verify coherence must pass"

    teardown_test
}

##############################################################################
# Cell: on / off -> L1 (init + zzc renv, no Docker)
##############################################################################

test_matrix_L1_pinned_packages() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init exited non-zero"; teardown_test; return 1; }
    _zzc renv || { echo "FAIL: zzc renv exited non-zero"; teardown_test; return 1; }

    assert_file_exists "renv.lock"      "L1: renv.lock must exist"
    assert_false "[[ -f Dockerfile ]]"  "L1: no Dockerfile expected"
    assert_equals "L1" "$(_status_level)" "L1: status level"
    assert_equals "0"  "$(_verify_rc)"    "L1: verify coherence must pass"

    teardown_test
}

##############################################################################
# Cell: off / on -> L2 (init + zzc docker --no-renv; DESCRIPTION-install)
##############################################################################

test_matrix_L2_description_backend() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init exited non-zero"; teardown_test; return 1; }
    _zzc docker --no-renv --profile analysis || { echo "FAIL: zzc docker --no-renv exited non-zero"; teardown_test; return 1; }

    assert_file_exists "Dockerfile"     "L2-desc: Dockerfile must exist"
    assert_false "[[ -f renv.lock ]]"   "L2-desc: no renv.lock expected"
    assert_equals "description" "$(_state_get install_mode)" "L2-desc: install_mode"
    assert_true "grep -q '^COPY DESCRIPTION' Dockerfile" "L2-desc: Dockerfile copies DESCRIPTION"
    assert_equals "L2" "$(_status_level)" "L2-desc: status level"
    assert_equals "0"  "$(_verify_rc)"    "L2-desc: verify coherence must pass"

    teardown_test
}

##############################################################################
# Cell: on / on -> L2 (init + zzc docker; renv-restore)
##############################################################################

test_matrix_L2_renv_backend() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init exited non-zero"; teardown_test; return 1; }
    _zzc docker --profile analysis || { echo "FAIL: zzc docker exited non-zero"; teardown_test; return 1; }

    assert_file_exists "Dockerfile"  "L2-renv: Dockerfile must exist"
    assert_file_exists "renv.lock"   "L2-renv: renv.lock must exist"
    assert_equals "renv" "$(_state_get install_mode)" "L2-renv: install_mode"
    assert_true "grep -q '^COPY renv.lock' Dockerfile" "L2-renv: Dockerfile copies renv.lock"
    assert_equals "L2" "$(_status_level)" "L2-renv: status level"
    assert_equals "0"  "$(_verify_rc)"    "L2-renv: verify coherence must pass"

    teardown_test
}

##############################################################################
# Toggle round-trip: L2-renv -> rm renv (L2-desc) -> renv (L2-renv).
# Asserts the generator self-adapts coherently in both directions.
##############################################################################

test_matrix_renv_toggle_roundtrip() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init exited non-zero"; teardown_test; return 1; }
    _zzc docker --profile analysis || { echo "FAIL: docker exited non-zero"; teardown_test; return 1; }
    assert_equals "renv" "$(_state_get install_mode)" "roundtrip: starts renv"

    _zzc_rm_renv
    assert_false "[[ -f renv.lock ]]" "roundtrip: renv.lock gone after rm renv"
    assert_equals "description" "$(_state_get install_mode)" "roundtrip: now description"
    assert_true "grep -q '^COPY DESCRIPTION' Dockerfile" "roundtrip: Dockerfile flipped to DESCRIPTION"
    assert_equals "0" "$(_verify_rc)" "roundtrip: verify passes in description mode"

    _zzc renv || { echo "FAIL: zzc renv exited non-zero"; teardown_test; return 1; }
    assert_file_exists "renv.lock" "roundtrip: renv.lock back after zzc renv"
    assert_equals "renv" "$(_state_get install_mode)" "roundtrip: back to renv"
    assert_true "grep -q '^COPY renv.lock' Dockerfile" "roundtrip: Dockerfile flipped back to renv"
    assert_equals "0" "$(_verify_rc)" "roundtrip: verify passes back in renv mode"

    teardown_test
}

##############################################################################
# Negative control: a deliberately broken state must fail verify.
##############################################################################

test_matrix_verify_detects_drift() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init exited non-zero"; teardown_test; return 1; }
    _zzc docker --profile analysis || { echo "FAIL: docker exited non-zero"; teardown_test; return 1; }

    # Remove renv.lock while leaving install_mode=renv and COPY renv.lock: the
    # exact dangling state a broken toggle would produce.
    rm -f renv.lock
    assert_equals "1" "$(_verify_rc)" "drift: verify must fail on missing renv.lock"

    teardown_test
}

##############################################################################
# Phase 5 migration: doctor is toggle-aware and back-fills the state record.
##############################################################################

# Run doctor on the current dir; echo its exit code.
_doctor_rc() {
    bash "$ZZCOLLAB_ROOT/modules/doctor.sh" "$@" < /dev/null > /dev/null 2>&1
    echo $?
}

# An L1 repo (renv, no Docker) is a valid lower capture level, not a broken
# workspace: doctor must not flag the absent Dockerfile.
test_migration_doctor_toggle_aware() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    _zzc renv          || { echo "FAIL: renv"; teardown_test; return 1; }

    assert_false "[[ -f Dockerfile ]]" "toggle-aware: L1 has no Dockerfile"
    assert_equals "0" "$(_doctor_rc .)" "toggle-aware: doctor must pass on L1 (no Dockerfile)"

    teardown_test
}

# A repo created before .zzcollab-state existed is back-filled from artifact
# presence by 'doctor --fix', without deleting any primary artifact.
test_migration_doctor_backfills_state() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force              || { echo "FAIL: init"; teardown_test; return 1; }
    _zzc docker --profile analysis || { echo "FAIL: docker"; teardown_test; return 1; }

    # Simulate a pre-state (legacy) repo.
    rm -f .zzcollab-state
    assert_equals "1" "$(_doctor_rc .)" "backfill: missing state is flagged without --fix"

    # Back-fill and confirm the record is reconstructed from presence.
    _doctor_rc . --fix > /dev/null
    assert_file_exists ".zzcollab-state" "backfill: state record written"
    assert_equals "renv" "$(_state_get install_mode)" "backfill: install_mode from COPY renv.lock"
    assert_true "grep -q '^base_image=rocker' .zzcollab-state" "backfill: base from Dockerfile FROM"
    assert_true "grep -q '^r_version=' .zzcollab-state"        "backfill: r_version recovered"
    assert_equals "0" "$(_doctor_rc .)" "backfill: doctor clean after back-fill"

    teardown_test
}

##############################################################################
# Outdated-template advisory must respect version *direction*: a stamp newer
# than the current template (e.g. a project predating a version reset) is not
# outdated and must not be nudged toward a downgrade. Only a strictly older
# stamp is flagged. Regression guard for the naive string-inequality check.
##############################################################################

test_outdated_banner_respects_version_direction() {
    setup_test
    _seed_config
    cd proj

    local out
    # Stamps far newer than any current template version: not outdated.
    printf '# zzcollab Makefile v999.0.0\n'   > Makefile
    printf '# zzcollab .Rprofile v999.0.0\n'  > .Rprofile
    printf '# zzcollab Dockerfile v999.0.0\n' > Dockerfile
    out=$(ZZCOLLAB_ACCEPT_DEFAULTS=true bash "$ZZCOLLAB_SH" status . < /dev/null 2>&1)
    if echo "$out" | grep -q "Outdated templates"; then
        echo "FAIL: newer-than-template stamps flagged as outdated"
        teardown_test; return 1
    fi

    # Stamps older than the current template: still flagged.
    printf '# zzcollab Makefile v0.0.1\n'   > Makefile
    printf '# zzcollab .Rprofile v0.0.1\n'  > .Rprofile
    printf '# zzcollab Dockerfile v0.0.1\n' > Dockerfile
    out=$(ZZCOLLAB_ACCEPT_DEFAULTS=true bash "$ZZCOLLAB_SH" status . < /dev/null 2>&1)
    if ! echo "$out" | grep -q "Outdated templates"; then
        echo "FAIL: older-than-template stamps not flagged as outdated"
        teardown_test; return 1
    fi

    teardown_test
}

##############################################################################
# Data-integrity toggle: zzc data writes a manifest, verify checks it, rm
# removes it. A capture feature with a presence-driven artifact.
##############################################################################

test_toggle_data_integrity() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    echo "immutable source row" > analysis/data/raw_data/sample.csv
    _zzc data || { echo "FAIL: zzc data"; teardown_test; return 1; }

    assert_file_exists "data-manifest.sha256" "data: manifest written"
    assert_equals "0" "$(_verify_rc .)" "data: verify passes when data matches manifest"

    # Tampering with the immutable data must make verify fail.
    echo "tampered row" >> analysis/data/raw_data/sample.csv
    assert_equals "1" "$(_verify_rc .)" "data: verify fails when data changed"

    # Refreshing the manifest re-establishes the match.
    _zzc data || { echo "FAIL: zzc data refresh"; teardown_test; return 1; }
    assert_equals "0" "$(_verify_rc .)" "data: verify passes again after refresh"

    _zzc rm data
    assert_false "[[ -f data-manifest.sha256 ]]" "data: manifest removed by rm data"

    teardown_test
}

##############################################################################
# Code-quality toggle: a validation feature (does not move the level). Its
# artifact is .pre-commit-config.yaml; zzc status reports it on/off.
##############################################################################

test_toggle_code_quality() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    assert_false "[[ -f .pre-commit-config.yaml ]]" "code-quality: off by default"

    _zzc code-quality || { echo "FAIL: zzc code-quality"; teardown_test; return 1; }
    assert_file_exists ".pre-commit-config.yaml" "code-quality: config installed"
    assert_true "grep -q 'lintr' .pre-commit-config.yaml"  "code-quality: lintr hook present"
    assert_true "grep -q 'style-files' .pre-commit-config.yaml" "code-quality: styler hook present"
    # Validation toggle: the level is unchanged (init repo is L0).
    assert_equals "L0" "$(_status_level)" "code-quality: level unchanged (validation, not capture)"

    _zzc rm code-quality
    assert_false "[[ -f .pre-commit-config.yaml ]]" "code-quality: removed by rm"

    teardown_test
}

##############################################################################
# zzc toggle: interactive view-and-change. Driven here through the zzc_read
# fallback by piping answers (ACCEPT_DEFAULTS is NOT set, so the reads consume
# the piped input). Prompt order: backend, docker, ci, data, code-quality,
# then a confirm.
##############################################################################

# Run zzc toggle with the given newline-separated answers; echo its exit code.
_toggle_with() {
    printf '%b' "$1" | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle \
        > /dev/null 2>&1
    echo $?
}

test_toggle_noop_makes_no_changes() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    # Keep every feature (empty answers default to current); no confirm reached.
    # 7 prompts (backend, docker, ci, data, code-quality, tests, cloud), all kept.
    assert_equals "0" "$(_toggle_with '\n\n\n\n\n\n\n')" "toggle: no-op exits 0"
    assert_false "[[ -f data-manifest.sha256 ]]"  "toggle: no-op created no manifest"
    assert_false "[[ -f .pre-commit-config.yaml ]]" "toggle: no-op installed no pre-commit"

    teardown_test
}

test_toggle_enables_features() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    echo "immutable row" > analysis/data/raw_data/d.csv

    # backend keep, docker keep, ci keep, data ON, code-quality ON,
    # tests keep, cloud keep, validate-strict keep, validate-fix keep, confirm y.
    _toggle_with '\n\n\non\non\n\n\n\n\ny\n' > /dev/null

    assert_file_exists "data-manifest.sha256"   "toggle: enabled data integrity"
    assert_file_exists ".pre-commit-config.yaml" "toggle: enabled code quality"

    teardown_test
}

test_toggle_enables_tests_and_cloud() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    # init scaffolds both; start from off so the enable is observable.
    rm -rf inst/tinytest tests/tinytest.R .devcontainer .binder

    # keep backend/docker/ci/data/code-quality, enable tests + cloud, keep both
    # validate options, confirm y.
    _toggle_with '\n\n\n\n\non\non\n\n\ny\n' > /dev/null

    assert_dir_exists  "inst/tinytest"                   "toggle: enabled unit tests"
    assert_file_exists ".devcontainer/devcontainer.json" "toggle: enabled cloud launch"

    teardown_test
}

##############################################################################
# Unit-testing and cloud-launch toggles (validation features; detected by
# status, now with add/remove commands).
##############################################################################

test_toggle_unit_tests() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    # init scaffolds tinytest; start from off.
    rm -rf inst/tinytest tests/tinytest.R
    assert_false "[[ -d inst/tinytest ]]" "tests: starts off"

    _zzc tests || { echo "FAIL: zzc tests"; teardown_test; return 1; }
    assert_dir_exists  "inst/tinytest"    "tests: inst/tinytest scaffolded"
    assert_file_exists "tests/tinytest.R" "tests: runner scaffolded"

    _zzc rm tests
    assert_false "[[ -d inst/tinytest ]]" "tests: removed by rm tests"

    teardown_test
}

test_toggle_cloud_devcontainer() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    rm -rf .devcontainer .binder

    _zzc cloud || { echo "FAIL: zzc cloud"; teardown_test; return 1; }
    assert_file_exists ".devcontainer/devcontainer.json" "cloud: devcontainer scaffolded"

    _zzc rm cloud
    assert_false "[[ -d .devcontainer ]]" "cloud: removed by rm cloud"

    teardown_test
}

##############################################################################
# init/toggle unification: cmd_init's Phase 3 is run_feature_wizard in init
# mode. Interactively it recommends renv + Docker; accepting the defaults
# builds L2. (Accept-defaults init skipping to L0 is covered by every other
# test, which inits non-interactively.)
##############################################################################

test_init_wizard_recommends_renv_docker() {
    setup_test
    _seed_config
    cd proj
    # Interactive (no ACCEPT_DEFAULTS), no build. First line answers the
    # archetype prompt (empty -> analysis); then 9 checklist prompts kept at
    # their defaults (backend=renv, docker=on recommended, validate-strict on /
    # validate-fix off) + confirm y.
    printf '\n\n\n\n\n\n\n\n\n\ny\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" init --force > /dev/null 2>&1

    assert_file_exists "renv.lock"  "init wizard: recommended renv enabled"
    assert_file_exists "Dockerfile" "init wizard: recommended Docker enabled"

    teardown_test
}

##############################################################################
# Section 12.3 couplings/nudges enforced by the wizard.
##############################################################################

# Enabling CI when no report exists offers to scaffold one (answered yes here).
test_coupling_render_scaffolds_report() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    rm -rf .github/workflows
    find analysis -name 'report.Rmd' -delete 2>/dev/null
    assert_false "[[ -n \"\$(find analysis -name report.Rmd)\" ]]" "coupling: no report to start"

    # backend keep, docker keep, ci ON, data/code-quality/tests/cloud keep,
    # validate-strict/validate-fix keep, confirm y, scaffold-report y.
    printf '\n\non\n\n\n\n\n\n\ny\ny\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle > /dev/null 2>&1

    assert_file_exists "analysis/report/report.Rmd" "coupling: report scaffolded on CI enable"

    teardown_test
}

# Choosing renv while leaving Docker off surfaces the L1/L2 nudge.
test_coupling_renv_docker_nudge() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    local out
    # backend renv, docker off, rest keep, decline the confirm (no changes).
    out=$(printf 'renv\noff\n\n\n\n\n\nn\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle 2>&1)
    echo "$out" | grep -q "renv pins packages" \
        || { echo "FAIL: renv/Docker nudge not shown"; teardown_test; return 1; }

    teardown_test
}

##############################################################################
# zzc toggle --global: edits the new-project feature defaults in config,
# which the init wizard then honours. No project artifacts change.
##############################################################################

test_toggle_global_writes_config() {
    setup_test
    _seed_config
    # global mode needs no workspace; run from the temp root.
    # 7 prompts: backend renv, docker off, ci keep, data ON, code-quality keep,
    # tests keep, cloud keep (no confirm step in global mode).
    printf 'renv\noff\n\non\n\n\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle --global > /dev/null 2>&1

    assert_equals "off" "$(bash "$ZZCOLLAB_SH" config get features-docker 2>/dev/null)" \
        "global: docker default saved"
    assert_equals "on" "$(bash "$ZZCOLLAB_SH" config get features-data 2>/dev/null)" \
        "global: data default saved"

    teardown_test
}

test_toggle_global_affects_init() {
    setup_test
    _seed_config
    # Set the global Docker default off, keep the rest at recommendation.
    printf '\noff\n\n\n\n\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle --global > /dev/null 2>&1

    cd proj
    # Interactive init: archetype prompt (empty -> analysis), then the wizard
    # accepting defaults (renv recommended on, Docker now off from global).
    printf '\n\n\n\n\n\n\n\n\n\ny\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" init --force > /dev/null 2>&1

    assert_file_exists "renv.lock"            "global->init: renv still recommended"
    assert_false "[[ -f Dockerfile ]]"        "global->init: Docker default off honoured"

    teardown_test
}

##############################################################################
# Nix backend: mutually exclusive with renv; flake.nix is the presence signal
# (status reports backend nix at L2). Nix is not evaluated here (no nix).
##############################################################################

test_nix_backend_add_remove() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    _zzc nix || { echo "FAIL: zzc nix"; teardown_test; return 1; }
    assert_file_exists "flake.nix" "nix: flake.nix created"
    assert_equals "L2" "$(_status_level)" "nix: level L2 (env pinned without container)"

    _zzc rm nix
    assert_false "[[ -f flake.nix ]]" "nix: flake.nix removed"

    teardown_test
}

test_nix_renv_mutually_exclusive() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    _zzc renv || { echo "FAIL: renv"; teardown_test; return 1; }

    # zzc nix must refuse while renv.lock is present (single-select backend).
    _zzc nix
    assert_false "[[ -f flake.nix ]]" "nix: refused while renv.lock present"
    assert_file_exists "renv.lock" "nix: renv.lock untouched by refused nix"

    teardown_test
}

test_toggle_backend_renv_to_nix() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    _zzc renv || { echo "FAIL: renv"; teardown_test; return 1; }

    # backend nix, then 6 feature prompts kept, confirm y.
    printf 'nix\n\n\n\n\n\n\n\n\ny\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle > /dev/null 2>&1

    assert_file_exists "flake.nix"        "toggle: switched to nix"
    assert_false "[[ -f renv.lock ]]"     "toggle: renv removed (backends exclusive)"

    teardown_test
}

##############################################################################
# Explicit 'zzc add <feature>' form, symmetric with 'zzc rm <feature>'.
##############################################################################

test_add_form_routes_to_features() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    echo "row" > analysis/data/raw_data/d.csv

    _zzc add data         || { echo "FAIL: add data"; teardown_test; return 1; }
    _zzc add code-quality || { echo "FAIL: add code-quality"; teardown_test; return 1; }
    assert_file_exists "data-manifest.sha256"    "add: data routed"
    assert_file_exists ".pre-commit-config.yaml" "add: code-quality routed"

    # add/rm are inverses.
    _zzc rm data
    assert_false "[[ -f data-manifest.sha256 ]]" "add/rm: symmetric"

    teardown_test
}

test_add_unknown_feature_fails() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }
    local rc=0
    ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" add bogus > /dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "add: unknown feature exits non-zero"
    teardown_test
}

##############################################################################
# Container-runtime parameter (Podman). The Makefile uses $(CONTAINER_RUNTIME)
# for run commands, defaulting to the configured docker.runtime (else docker),
# overridable with `make CONTAINER_RUNTIME=...`.
##############################################################################

test_runtime_makefile_parameterised() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    assert_true "grep -q 'CONTAINER_RUNTIME ?= docker' Makefile" "runtime: default docker baked"
    assert_true "grep -q '[$][(]CONTAINER_RUNTIME[)] run' Makefile" "runtime: run uses the variable"
    assert_false "grep -qE '^[[:space:]]*docker run' Makefile" "runtime: no bare 'docker run' left"
    # Local image management (rmi) is runtime-aware too; multi-arch team
    # publishing (buildx) stays docker-specific.
    assert_true "grep -q '[$][(]CONTAINER_RUNTIME[)] rmi' Makefile" "runtime: docker-clean uses the variable"

    teardown_test
}

test_runtime_config_default_podman() {
    setup_test
    _seed_config
    # Configure podman as the default before generating the project.
    bash "$ZZCOLLAB_SH" config set docker-runtime podman > /dev/null 2>&1
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    assert_true "grep -q 'CONTAINER_RUNTIME ?= podman' Makefile" "runtime: configured podman baked as default"

    teardown_test
}

test_runtime_rejects_unknown() {
    setup_test
    _seed_config
    local rc=0
    bash "$ZZCOLLAB_SH" config set docker-runtime singularity > /dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "runtime: unknown value rejected (valid: docker, podman, apptainer)"
    teardown_test
}

##############################################################################
# Archetype axis (init-time scaffolding parameter, plan §9.4). Determines
# whether a report exists (the render gate) and is recorded in .zzcollab-state.
##############################################################################

test_archetype_report_vs_package() {
    setup_test
    _seed_config
    # manuscript/analysis/blog scaffold a report; package/simulation do not.
    ( cd proj && _zzc init --force --archetype manuscript ) \
        || { echo "FAIL: init manuscript"; teardown_test; return 1; }
    assert_file_exists "proj/analysis/report/report.Rmd" "archetype: manuscript has a report"

    rm -rf proj && mkdir proj
    ( cd proj && _zzc init --force --archetype package ) \
        || { echo "FAIL: init package"; teardown_test; return 1; }
    assert_false "[[ -f proj/analysis/report/report.Rmd ]]" "archetype: package has no report"

    teardown_test
}

test_archetype_simulation_starter() {
    setup_test
    _seed_config
    ( cd proj && _zzc init --force --archetype simulation ) \
        || { echo "FAIL: init simulation"; teardown_test; return 1; }
    assert_file_exists "proj/analysis/scripts/simulation.R" "archetype: simulation starter scaffolded"
    assert_false "[[ -f proj/analysis/report/report.Rmd ]]" "archetype: simulation has no report"
    assert_equals "simulation" "$(cd proj && _state_get archetype)" "archetype: recorded in state"

    teardown_test
}

test_archetype_preserved_across_docker() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force --archetype package || { echo "FAIL: init"; teardown_test; return 1; }
    _zzc docker --profile analysis        || { echo "FAIL: docker"; teardown_test; return 1; }
    assert_equals "package" "$(_state_get archetype)" "archetype: preserved across Dockerfile regeneration"
    teardown_test
}

test_archetype_invalid_rejected() {
    setup_test
    _seed_config
    local rc=0
    bash "$ZZCOLLAB_SH" config set archetype bogus > /dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "archetype: invalid value rejected"
    teardown_test
}

##############################################################################
# Nix Makefile wiring: host R targets run via `nix develop -c` when a flake is
# present, on the host otherwise. Verified by `make -n` (no nix toolchain run).
##############################################################################

test_nix_makefile_wiring() {
    command -v make >/dev/null 2>&1 || { echo "SKIP: make not available"; return 0; }
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    # Host backend: bare R.
    make -n test 2>/dev/null | grep -qE '^[[:space:]]*R --quiet' \
        || { echo "FAIL: host target not bare R"; teardown_test; return 1; }

    # Nix backend: same target wrapped in nix develop -c.
    _zzc nix || { echo "FAIL: zzc nix"; teardown_test; return 1; }
    make -n test 2>/dev/null | grep -q 'nix develop -c R' \
        || { echo "FAIL: nix target not via nix develop"; teardown_test; return 1; }

    teardown_test
}

##############################################################################
# Archetype depth: interactive init prompt and a distinct blog layout.
##############################################################################

test_archetype_blog_layout() {
    setup_test
    _seed_config
    ( cd proj && _zzc init --force --archetype blog ) \
        || { echo "FAIL: init blog"; teardown_test; return 1; }
    assert_file_exists "proj/analysis/posts/first-post.Rmd" "blog: posts/ layout scaffolded"
    teardown_test
}

test_archetype_interactive_prompt() {
    setup_test
    _seed_config
    cd proj
    # Not accept-defaults, so the archetype prompt fires. Answer 'blog', then
    # step through the init feature wizard (7 prompts kept) and decline the
    # confirm so no features change.
    printf 'blog\n\n\n\n\n\n\n\nn\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" init --force > /dev/null 2>&1

    assert_equals "blog" "$(_state_get archetype)" "interactive: archetype from prompt"
    assert_file_exists "analysis/posts/first-post.Rmd" "interactive: blog layout applied"

    teardown_test
}

##############################################################################
# Blog post-rendering: the render workflow collects analysis/posts/*.Rmd in
# addition to report.Rmd (template-level check; the workflow is unrunnable here).
##############################################################################

test_blog_render_workflow_includes_posts() {
    local wf="$ZZCOLLAB_ROOT/templates/workflows/render-report.yml"
    assert_file_exists "$wf" "render workflow template present"
    # All three render branches (nix/docker/host) must collect posts.
    local n
    n=$(grep -c 'list.files("analysis/posts"' "$wf")
    assert_equals "3" "$n" "render: posts collected in all three backend branches"
}

##############################################################################
# Apptainer runtime: a SIF built from the project image, run via apptainer
# exec/shell (no --platform). Verified by config + `make -n` (no apptainer run).
##############################################################################

test_apptainer_config_accepted() {
    setup_test
    _seed_config
    bash "$ZZCOLLAB_SH" config set docker-runtime apptainer > /dev/null 2>&1
    assert_equals "apptainer" "$(bash "$ZZCOLLAB_SH" config get docker-runtime 2>/dev/null)" \
        "apptainer: accepted as a runtime"
    teardown_test
}

test_apptainer_makefile_wiring() {
    command -v make >/dev/null 2>&1 || { echo "SKIP: make not available"; return 0; }
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    # run targets exec the SIF under the apptainer runtime
    make CONTAINER_RUNTIME=apptainer -n docker-document 2>/dev/null \
        | grep -q 'apptainer exec env.sif' \
        || { echo "FAIL: docker-document not via apptainer exec"; teardown_test; return 1; }
    # the SIF build target uses apptainer build
    make -n sif 2>/dev/null | grep -q 'apptainer build env.sif' \
        || { echo "FAIL: sif target missing"; teardown_test; return 1; }

    teardown_test
}

##############################################################################
# r-package.yml Nix path: a detect job routes to a container check (non-nix) or
# a nix check job that runs R CMD check in `nix develop` (template-level check).
##############################################################################

test_rpackage_nix_check_job() {
    local wf="$ZZCOLLAB_ROOT/templates/workflows/r-package.yml"
    assert_file_exists "$wf" "r-package workflow template present"
    grep -q '^  check-nix:' "$wf" \
        || { echo "FAIL: no check-nix job"; return 1; }
    grep -q 'nix develop -c' "$wf" \
        || { echo "FAIL: nix check does not use nix develop"; return 1; }
    # The container check must be gated off for the nix backend.
    grep -q "nix != 'true'" "$wf" \
        || { echo "FAIL: container check not gated against nix"; return 1; }
}

##############################################################################
# Dependency-validation toggles (zzrenvcheck strict / auto-fix) ride the same
# gum checklist. They are config (not artifacts): project mode persists them
# project-local; global mode persists user-level. `zzc validate` reads them.
##############################################################################

test_toggle_validate_persists_project_local() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force || { echo "FAIL: init"; teardown_test; return 1; }

    # keep the 7 feature prompts, then validate-strict OFF, validate-fix ON,
    # confirm y. Config (not artifacts) so it persists to the project config.
    printf '\n\n\n\n\n\n\noff\non\ny\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle > /dev/null 2>&1

    assert_equals "false" "$(bash "$ZZCOLLAB_SH" config get validate-strict 2>/dev/null)" \
        "toggle: validate-strict off persisted project-local"
    assert_equals "true" "$(bash "$ZZCOLLAB_SH" config get validate-fix 2>/dev/null)" \
        "toggle: validate-fix on persisted project-local"

    teardown_test
}

test_toggle_validate_global_persists_user_level() {
    setup_test
    _seed_config
    # global mode, no workspace: keep features, validate-strict keep, fix ON.
    printf '\n\n\n\n\n\n\n\non\n' \
        | ZZCOLLAB_NO_BUILD=true bash "$ZZCOLLAB_SH" toggle --global > /dev/null 2>&1

    assert_equals "true" "$(bash "$ZZCOLLAB_SH" config get validate-fix 2>/dev/null)" \
        "global: validate-fix default saved user-level"

    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
