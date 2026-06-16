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
# RUN ALL TESTS
##############################################################################

run_test_suite
