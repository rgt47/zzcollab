#!/bin/bash
##############################################################################
# ZZCOLLAB GATE TESTS
##############################################################################
#
# Gates that must fail when they validated nothing:
#   - the tinytest runner (TINYTEST_RUN in both Makefiles) fails a suite in
#     which no expectation ran;
#   - verify credits a baseline only when the file ran to completion with at
#     least one expectation (_vrf_baseline_ran);
#   - verify reads the R version from the generated FROM line
#     (_vrf_dockerfile_r_version), since generated Dockerfiles carry no
#     ARG R_VERSION.
#
# Run individually:
#   bash tests/shell/test-gates.sh
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

_load_verify() {
    # shellcheck source=/dev/null
    source "$ZZCOLLAB_ROOT/modules/verify.sh"
}

# Extract the TINYTEST_RUN expression from a Makefile.
_tinytest_run() {
    grep -m1 '^TINYTEST_RUN := ' "$1" | sed 's/^TINYTEST_RUN := //'
}

_have_tinytest() {
    command -v Rscript >/dev/null 2>&1 &&
        Rscript -e "quit(status = if (requireNamespace('tinytest', quietly = TRUE)) 0L else 1L)" \
            >/dev/null 2>&1
}

# Run a Makefile's TINYTEST_RUN in the current dir; echo its exit status.
_run_suite() {
    local expr status=0
    expr=$(_tinytest_run "$1")
    Rscript -e "$expr" >/dev/null 2>&1 || status=$?
    echo "$status"
}

##############################################################################
# TINYTEST_RUN
##############################################################################

test_tinytest_run_definitions_agree() {
    local a b
    a=$(_tinytest_run "$ZZCOLLAB_ROOT/Makefile")
    b=$(_tinytest_run "$ZZCOLLAB_ROOT/templates/Makefile")
    assert_not_empty "$a" "root Makefile defines TINYTEST_RUN"
    assert_equals "$a" "$b" "root and template TINYTEST_RUN agree"
    assert_true "grep -q 'length(r) == 0L' <<< \"\$a\"" \
        "TINYTEST_RUN fails when no expectation ran"
}

test_tinytest_run_exit_status() {
    if ! _have_tinytest; then
        echo "SKIP: Rscript or tinytest not available"
        return 0
    fi
    setup_test
    local mk="$ZZCOLLAB_ROOT/templates/Makefile"
    mkdir -p inst/tinytest

    printf 'x <- 1\n' > inst/tinytest/test-none.R
    assert_equals "1" "$(_run_suite "$mk")" \
        "a suite with no expectations fails"

    printf 'expect_true(TRUE)\n' > inst/tinytest/test-pass.R
    assert_equals "0" "$(_run_suite "$mk")" \
        "a suite with a passing expectation passes"

    printf 'expect_true(FALSE)\n' > inst/tinytest/test-fail.R
    assert_equals "1" "$(_run_suite "$mk")" \
        "a failing expectation fails the suite"

    teardown_test
}

test_ci_templates_fail_on_empty_suite() {
    local f
    for f in templates/workflows/r-package.yml templates/gitlab/.gitlab-ci.yml; do
        assert_true "grep -q 'length(out) == 0L' '$ZZCOLLAB_ROOT/$f'" \
            "$f fails when no expectation ran"
    done
    assert_false "grep -q 'non-blocking' '$ZZCOLLAB_ROOT/templates/gitlab/.gitlab-ci.yml'" \
        "GitLab test steps are blocking"
}

##############################################################################
# make lint
##############################################################################

test_lint_target_fails_on_lints() {
    local mk="$ZZCOLLAB_ROOT/templates/Makefile" collect lint_line
    collect=$(grep -m1 '^LINT_COLLECT := ' "$mk" | sed 's/^LINT_COLLECT := //')
    lint_line=$(grep -A1 '^lint:' "$mk" | tail -1)
    assert_not_empty "$collect" "template defines LINT_COLLECT"
    assert_true "grep -q 'quit(status = 1)' <<< \"\$lint_line\"" \
        "lint recipe exits nonzero on lints"
    assert_true "grep -q '^lint-report:' '$mk'" "lint-report target exists"

    if ! command -v Rscript >/dev/null 2>&1 ||
        ! Rscript -e "quit(status = if (requireNamespace('lintr', quietly = TRUE)) 0L else 1L)" \
            >/dev/null 2>&1; then
        echo "SKIP: Rscript or lintr not available"
        return 0
    fi
    setup_test
    local expr="$collect; if (length(l) > 0L) quit(status = 1)" rc
    mkdir -p R analysis
    printf 'f <- function(x){x=1;x}\n' > R/a.R
    printf 'y <- 2\n' > analysis/b.R
    rc=0; Rscript -e "$expr" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "lints in R/ fail the gate"

    printf 'f <- function(x) {\n  x\n}\n' > R/a.R
    printf 'y = 2\n' > analysis/b.R
    rc=0; Rscript -e "$expr" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "lints in analysis/ fail the gate"

    printf 'y <- 2\n' > analysis/b.R
    rc=0; Rscript -e "$expr" >/dev/null 2>&1 || rc=$?
    assert_equals "0" "$rc" "clean code passes"
    teardown_test
}

##############################################################################
# _vrf_baseline_ran
##############################################################################

test_baseline_ran_parses_tinytest_log() {
    _load_verify
    setup_test
    local cr=$'\r'
    {
        printf '%stest-baseline-exit.R....    0 tests    22ms [Exited at #2: skip]\n' "$cr"
        printf '%stest-baseline-late.R....    1 tests OK %stest-baseline-late.R....    1 tests OK 1ms [Exited at #2: later]\n' "$cr" "$cr"
        printf '%stest-baseline-one.R.....    1 tests OK 1ms\n' "$cr"
        printf '%stest-baseline-two.R.....    1 tests OK %stest-baseline-two.R.....    2 tests OK 1ms\n' "$cr" "$cr"
        printf '\033[0;32m%stest-baseline-color.R...    3 tests OK 1ms\033[0m\n' "$cr"
        printf 'All ok, 7 results (27ms)\n'
    } > log.txt

    assert_true "_vrf_baseline_ran log.txt test-baseline-one.R" \
        "one expectation, completed: credited"
    assert_true "_vrf_baseline_ran log.txt test-baseline-two.R" \
        "rewritten line: final segment is used"
    assert_true "_vrf_baseline_ran log.txt test-baseline-color.R" \
        "ANSI color codes are ignored"
    assert_false "_vrf_baseline_ran log.txt test-baseline-exit.R" \
        "early exit with 0 tests: not credited"
    assert_false "_vrf_baseline_ran log.txt test-baseline-late.R" \
        "exit part way: not credited"
    assert_false "_vrf_baseline_ran log.txt test-baseline-missing.R" \
        "file absent from the log: not credited"
    teardown_test
}

##############################################################################
# _vrf_dockerfile_r_version
##############################################################################

test_dockerfile_r_version() {
    _load_verify
    setup_test
    local v

    printf 'FROM rocker/r-ver:4.4.1@sha256:abc123\n' > Dockerfile
    v=$(_vrf_dockerfile_r_version Dockerfile)
    assert_equals "4.4.1" "$v" "digest-pinned FROM"

    printf 'ARG BASE_IMAGE=rocker/tidyverse\nFROM rocker/tidyverse:4.5.0\n' > Dockerfile
    v=$(_vrf_dockerfile_r_version Dockerfile)
    assert_equals "4.5.0" "$v" "tag-only FROM"

    printf 'FROM rocker/r-ver:latest\n' > Dockerfile
    v=$(_vrf_dockerfile_r_version Dockerfile)
    assert_equals "" "$v" "non-numeric tag and no ARG: empty, no abort"

    printf 'ARG R_VERSION=4.3.2\nFROM rocker/r-ver:${R_VERSION}\n' > Dockerfile
    v=$(_vrf_dockerfile_r_version Dockerfile)
    assert_equals "4.3.2" "$v" "legacy ARG R_VERSION"

    rm -f Dockerfile
    v=$(_vrf_dockerfile_r_version Dockerfile)
    assert_equals "" "$v" "no Dockerfile: empty"
    teardown_test
}

# run_test_suite calls each test inside a `||` list, which disables set -e,
# so errexit behavior is checked in a fresh shell. zzcollab.sh runs under
# set -euo pipefail; a helper returning nonzero from an assignment there
# aborted verify mid-check (the pre-fix ARG R_VERSION read did exactly this).
test_dockerfile_r_version_survives_errexit() {
    setup_test
    local rc=0
    printf 'FROM rocker/r-ver:latest\n' > Dockerfile
    bash -c 'set -euo pipefail
        source "$1/modules/verify.sh"
        v=$(_vrf_dockerfile_r_version Dockerfile)
        printf "FROM rocker/r-ver:4.4.1\n" > Dockerfile
        v=$(_vrf_dockerfile_r_version Dockerfile)
        [[ "$v" == 4.4.1 ]]' _ "$ZZCOLLAB_ROOT" || rc=$?
    assert_equals "0" "$rc" "no-match read does not abort under set -e"
    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
