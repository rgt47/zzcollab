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
    local expr="$collect; if (n > 0L) quit(status = 1)" rc
    mkdir -p R analysis
    printf 'f <- function(x){x=1;x}\n' > R/a.R
    printf 'y <- 2\n' > analysis/b.R
    rc=0; Rscript -e "$expr" >/dev/null 2>&1 || rc=$?
    assert_equals "1" "$rc" "lints in R/ fail the gate"
    assert_false "Rscript -e \"$collect\" 2>&1 | grep -q '^\\[\\[1\\]\\]'" \
        "the listing prints as lints, not as a bare list"

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
# check-renv (gate) vs fix-renv (repair)
##############################################################################

# Dry-run a target of the given Makefile in an empty dir; echo the recipe.
_dry() {
    make -n -f "$1" CONTAINER_RUNTIME=docker "$2" 2>&1 || true
}

test_check_renv_is_a_non_editing_gate() {
    setup_test
    local mk out t
    for mk in "$ZZCOLLAB_ROOT/templates/Makefile" "$ZZCOLLAB_ROOT/Makefile"; do
        for t in check-renv check-renv-no-strict docker-check-renv; do
            out=$(_dry "$mk" "$t")
            assert_true "grep -q 'auto_fix = FALSE' <<< \"\$out\"" \
                "$(basename "$(dirname "$mk")")/$t does not edit files"
            assert_true "grep -q 'error_on_fail = TRUE' <<< \"\$out\"" \
                "$t fails on findings"
            assert_false "grep -q 'auto_fix = TRUE' <<< \"\$out\"" \
                "$t never runs the auto-fix"
        done
        for t in fix-renv fix-renv-no-strict docker-check-renv-fix; do
            out=$(_dry "$mk" "$t")
            assert_true "grep -q 'auto_fix = TRUE' <<< \"\$out\"" \
                "$t runs the auto-fix"
        done
        out=$(_dry "$mk" check-renv-no-fix)
        assert_true "grep -q 'deprecated' <<< \"\$out\"" \
            "check-renv-no-fix prints a deprecation notice"
        assert_false "grep -q 'auto_fix = TRUE' <<< \"\$out\"" \
            "check-renv-no-fix still does not edit"
    done
    out=$(_dry "$ZZCOLLAB_ROOT/templates/Makefile" check-renv-slim)
    assert_true "grep -q 'auto_fix = FALSE.*skip_image_pkgs = TRUE' <<< \"\$out\"" \
        "check-renv-slim is a non-editing gate"
    out=$(_dry "$ZZCOLLAB_ROOT/templates/Makefile" fix-renv-slim)
    assert_true "grep -q 'auto_fix = TRUE.*skip_image_pkgs = TRUE' <<< \"\$out\"" \
        "fix-renv-slim repairs"
    teardown_test
}

# Following the hint must not widen the scope: each check variant names the
# repair with the same strictness and image exemption.
test_fix_hint_matches_variant() {
    setup_test
    local mk="$ZZCOLLAB_ROOT/templates/Makefile"
    assert_true "grep -q 'make fix-renv ' <<< \"\$(_dry '$mk' check-renv)\"" \
        "check-renv hints fix-renv"
    assert_true "grep -q 'make fix-renv-no-strict ' <<< \"\$(_dry '$mk' check-renv-no-strict)\"" \
        "check-renv-no-strict hints fix-renv-no-strict"
    assert_true "grep -q 'make fix-renv-slim ' <<< \"\$(_dry '$mk' check-renv-slim)\"" \
        "check-renv-slim hints fix-renv-slim"
    mk="$ZZCOLLAB_ROOT/Makefile"
    assert_true "grep -q 'make fix-renv-no-strict ' <<< \"\$(_dry '$mk' check-renv-no-strict)\"" \
        "root check-renv-no-strict hints fix-renv-no-strict"
    teardown_test
}

# make r's no-host-R branch relies on the repair after a session, so it
# must call fix-renv, not the (now non-editing) check-renv.
test_post_session_hook_repairs() {
    assert_true "grep -q 'MAKE) --no-print-directory fix-renv' '$ZZCOLLAB_ROOT/templates/Makefile'" \
        "post-session validation calls fix-renv"
    assert_false "grep -q 'MAKE) --no-print-directory check-renv' '$ZZCOLLAB_ROOT/templates/Makefile'" \
        "no template recipe relies on check-renv to repair"
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
# doctor state back-fill (doctor.sh runs under set -euo pipefail)
##############################################################################

# Back-fill .zzcollab-state for the given project dir in a fresh strict
# shell, as doctor does; echo the recorded r_version, or ABORTED.
_doctor_backfill() {
    bash -c 'set -euo pipefail
        source "$1/lib/constants.sh"
        source "$1/lib/core.sh"
        # The file ends in [[ sourced-check ]] && main, which returns 1
        # when sourced; that status is not the code under test.
        source "$1/modules/doctor.sh" || true
        FIX_MODE=true DRY_RUN=false
        check_state_record "$2" >/dev/null
        grep "^r_version=" "$2/.zzcollab-state" | cut -d= -f2' \
        _ "$ZZCOLLAB_ROOT" "$1" 2>/dev/null || echo ABORTED
}

test_doctor_backfill_reads_from_tag() {
    setup_test
    mkdir -p a b c

    printf 'FROM rocker/tidyverse:4.5.0@sha256:abc\n' > a/Dockerfile
    assert_equals "4.5.0" "$(_doctor_backfill "$PWD/a")" \
        "no renv.lock: version taken from the FROM tag"

    printf 'FROM rocker/r-ver:latest\n' > b/Dockerfile
    assert_equals "" "$(_doctor_backfill "$PWD/b")" \
        "non-numeric tag, no ARG: empty, no abort"

    printf '{"Packages":{}}\n' > c/renv.lock
    printf 'FROM rocker/r-ver:4.4.1\n' > c/Dockerfile
    assert_equals "4.4.1" "$(_doctor_backfill "$PWD/c")" \
        "renv.lock without R section: no abort, tag used"
    teardown_test
}

##############################################################################
# Bare compendium: no DESCRIPTION, so dependency checks skip (not fail)
##############################################################################

# Every dependency target exits 0 with the skip message and never reaches R:
# TOOL_RSCRIPT=false would fail any recipe that got past the guard.
test_bare_make_targets_skip() {
    setup_test
    cp "$ZZCOLLAB_ROOT/templates/Makefile" Makefile
    local t out rc
    for t in check-renv check-renv-no-strict check-renv-slim check-renv-no-fix \
             fix-renv fix-renv-no-strict fix-renv-slim reset-lock ensure-zzrenvcheck; do
        rc=0
        out=$(make --no-print-directory "$t" CONTAINER_RUNTIME=docker \
            TOOL_RSCRIPT=false 2>&1) || rc=$?
        assert_equals "0" "$rc" "bare: make $t exits 0"
        if [[ "$t" != ensure-zzrenvcheck ]]; then
            assert_true "grep -q 'bare compendium' <<< \"\$out\"" \
                "bare: make $t says the check was skipped"
        fi
    done

    printf 'Package: x\nVersion: 0.1.0\n' > DESCRIPTION
    rc=0
    make --no-print-directory check-renv CONTAINER_RUNTIME=docker \
        TOOL_RSCRIPT=false >/dev/null 2>&1 || rc=$?
    assert_false "[[ $rc -eq 0 ]]" \
        "with DESCRIPTION the guard does not skip (the check runs)"
    teardown_test
}

test_bare_hook_skips_and_writes_marker() {
    local mk="$ZZCOLLAB_ROOT/templates/Makefile"
    assert_true "grep -A2 'if \[ ! -f DESCRIPTION \]; then' '$mk' | grep -q 'zzvim-r-hook-ran'" \
        "post-session hook skips a bare project and still writes the marker"
}

_seed_bare_config() {
    mkdir -p cfg proj
    cat > cfg/config.yaml << 'EOF'
author:
  name: "Gate Tester"
  email: "gate@example.com"
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

test_bare_verify_and_validate_skip() {
    setup_test
    _seed_bare_config
    cd proj
    ZZCOLLAB_ACCEPT_DEFAULTS=true ZZCOLLAB_NO_BUILD=true \
        bash "$ZZCOLLAB_ROOT/zzcollab.sh" init --force --bare \
        < /dev/null > /dev/null 2>&1 || { echo "FAIL: bare init"; teardown_test; return 1; }
    assert_false "[[ -f DESCRIPTION ]]" "bare init writes no DESCRIPTION"

    local out rc=0
    out=$(ZZCOLLAB_ACCEPT_DEFAULTS=true bash "$ZZCOLLAB_ROOT/zzcollab.sh" verify . \
        < /dev/null 2>&1) || rc=$?
    assert_true "grep -q 'bare compendium); dependency check skipped' <<< \"\$out\"" \
        "verify reports the dependency step as skipped"
    assert_false "grep -q 'zzrenvcheck reported dependency issues' <<< \"\$out\"" \
        "verify does not warn about dependencies on a bare project"

    rc=0
    out=$(bash "$ZZCOLLAB_ROOT/zzcollab.sh" validate < /dev/null 2>&1) || rc=$?
    assert_equals "0" "$rc" "validate exits 0 on a bare project"
    assert_true "grep -q 'bare compendium' <<< \"\$out\"" \
        "validate says the check was skipped"
    teardown_test
}

##############################################################################
# PLATFORM reaches the build; the run default follows the base image
##############################################################################

test_platform_override_reaches_build() {
    setup_test
    local mk="$ZZCOLLAB_ROOT/templates/Makefile" out t
    printf 'FROM rocker/tidyverse:4.5.0\n' > Dockerfile
    for t in docker-build docker-rebuild docker-build-log; do
        out=$(make -n -f "$mk" CONTAINER_RUNTIME=docker PLATFORM=linux/amd64 "$t" 2>&1 || true)
        assert_true "grep -q 'ZZCOLLAB_PLATFORM=\"linux/amd64\"' <<< \"\$out\"" \
            "make $t PLATFORM=linux/amd64 passes the platform to the build"
        out=$(make -n -f "$mk" CONTAINER_RUNTIME=docker "$t" 2>&1 || true)
        assert_false "grep -q 'ZZCOLLAB_PLATFORM' <<< \"\$out\"" \
            "make $t without PLATFORM leaves the choice to the build"
    done
    teardown_test
}

# End to end through zzc rebuild, with a recording docker on PATH: an
# explicit PLATFORM reaches docker build, and a later make r without
# PLATFORM runs the platform the image was built for (its label).
test_platform_end_to_end() {
    setup_test
    mkdir -p bin proj
    cat > bin/docker <<'EOF'
#!/bin/bash
echo "docker $*" >> "$SEAM_LOG"
case "$1 $2" in
  "image inspect") [ -n "${SEAM_LABEL:-}" ] && { echo "$SEAM_LABEL"; exit 0; }; exit 1 ;;
esac
exit 0
EOF
    chmod +x bin/docker
    local log="$PWD/docker.log" out
    cd proj
    cp "$ZZCOLLAB_ROOT/templates/Makefile" Makefile
    printf 'Package: proj\nVersion: 0.1.0\n' > DESCRIPTION
    printf '{"R":{"Version":"4.5.0"},"Packages":{}}\n' > renv.lock
    printf 'FROM rocker/tidyverse:4.5.0@sha256:abc\nCOPY renv.lock renv.lock\n' > Dockerfile
    touch .zzcollab

    SEAM_LOG="$log" PATH="$PWD/../bin:$PATH" make --no-print-directory docker-build \
        PLATFORM=linux/amd64 CONTAINER_RUNTIME=docker \
        ZZCOLLAB="$ZZCOLLAB_ROOT/zzcollab.sh" >/dev/null 2>&1 || true
    assert_true "grep '^docker build' '$log' | grep -q -- '--platform linux/amd64'" \
        "make docker-build PLATFORM=linux/amd64 reaches docker build"
    assert_true "grep '^docker build' '$log' | grep -q 'zzcollab.platform=linux/amd64'" \
        "the image is labeled with the platform it was built for"

    out=$(SEAM_LOG="$log" SEAM_LABEL=linux/amd64 PATH="$PWD/../bin:$PATH" \
        make -n --no-print-directory r CONTAINER_RUNTIME=docker 2>&1 || true)
    assert_true "grep -q -- '--platform linux/amd64' <<< \"\$out\"" \
        "make r without PLATFORM runs the platform the image was built for"
    teardown_test
}

test_platform_default_follows_base() {
    setup_test
    local mk="$ZZCOLLAB_ROOT/templates/Makefile" out
    printf 'FROM rocker/verse:4.5.0@sha256:abc\n' > Dockerfile
    out=$(make -n -f "$mk" CONTAINER_RUNTIME=docker docker-test 2>&1 || true)
    assert_true "grep -q -- '--platform linux/amd64' <<< \"\$out\"" \
        "a verse image runs as linux/amd64 on every host"
    out=$(make -n -f "$mk" CONTAINER_RUNTIME=docker docker-rstudio 2>&1 || true)
    assert_true "grep -q -- 'run --rm -it --platform linux/amd64' <<< \"\$out\"" \
        "docker-rstudio runs with the same platform as the other run targets"
    teardown_test
}

##############################################################################
# verify: digest pin and malformed renv.lock
##############################################################################

_verify_out() {
    ZZCOLLAB_ACCEPT_DEFAULTS=true bash "$ZZCOLLAB_ROOT/zzcollab.sh" verify "$1" \
        < /dev/null 2>&1 || true
}

test_verify_warns_on_unpinned_base() {
    setup_test
    mkdir -p p
    touch p/.zzcollab
    printf '{"R":{"Version":"4.5.0"},"Packages":{}}\n' > p/renv.lock
    printf 'FROM rocker/r-ver:4.5.0\nCOPY renv.lock renv.lock\n' > p/Dockerfile
    local out
    out=$(_verify_out p)
    assert_true "grep -q 'base image not pinned by digest' <<< \"\$out\"" \
        "a tag-only FROM is reported"

    printf 'FROM rocker/r-ver:4.5.0@sha256:abc\nCOPY renv.lock renv.lock\n' > p/Dockerfile
    out=$(_verify_out p)
    assert_true "grep -q 'base image pinned by digest' <<< \"\$out\"" \
        "a digest-pinned FROM passes"
    teardown_test
}

test_verify_reports_malformed_lock() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "SKIP: python3 not available"
        return 0
    fi
    setup_test
    mkdir -p p
    touch p/.zzcollab
    printf '{not json\n' > p/renv.lock
    local out
    out=$(_verify_out p)
    assert_true "grep -q 'renv.lock is malformed' <<< \"\$out\"" \
        "a malformed renv.lock is reported, not an abort"
    teardown_test
}

##############################################################################
# zzrenvcheck is installed at the tag tooling.lock records
##############################################################################

test_zzrenvcheck_pinned_to_lock() {
    setup_test
    local mk="$ZZCOLLAB_ROOT/templates/Makefile" const min
    printf 'Package: x\nVersion: 0.1.0\n' > DESCRIPTION

    const=$(grep -m1 'ZZRENVCHECK_TAG=' "$ZZCOLLAB_ROOT/lib/constants.sh" \
        | sed 's/.*:-\(v[0-9.]*\)}.*/\1/')
    min=$(grep -m1 '^ZZRENVCHECK_MIN  *:= ' "$mk" | sed 's/.*:= *//')
    assert_not_empty "$const" "constants.sh defines a tag"
    assert_equals "$const" "$min" "Makefile minimum equals ZZRENVCHECK_TAG"
    assert_false "grep -q \"install_github('rgt47/zzrenvcheck'\" '$mk'" \
        "no unpinned install remains (host or post-session paths)"
    teardown_test
}

# Evaluate the Makefile's install expression with install_github and
# packageVersion stubbed: echo which tag it would install (NONE if it keeps
# the installed release), plus any message.
_wanted_tag() {
    local lock="$1" installed="$2" expr
    expr=$(make -n --no-print-directory -f "$ZZCOLLAB_ROOT/templates/Makefile" \
        CONTAINER_RUNTIME=docker ensure-zzrenvcheck 2>/dev/null \
        | sed -n 's/.* -e "\(lock <- .*\)"$/\1/p')
    Rscript --vanilla -e "
      requireNamespace <- function(pkg, ...) TRUE
      utils_pv <- package_version('$installed')
      packageVersion <- function(...) utils_pv
      assign('packageVersion', packageVersion, envir = globalenv())
      remotes_install <- function(ref, ...) cat('INSTALL', ref, '\n')
      expr <- gsub('utils::packageVersion', 'packageVersion', '$(printf '%s' "$expr" | sed "s/'/\\\\'/g")', fixed = TRUE)
      expr <- gsub('remotes::install_github', 'remotes_install', expr, fixed = TRUE)
      eval(parse(text = expr))
      cat('DONE\n')" 2>&1
}

test_zzrenvcheck_version_rule() {
    if ! command -v Rscript >/dev/null 2>&1; then
        echo "SKIP: Rscript not available"
        return 0
    fi
    setup_test
    printf 'Package: x\nVersion: 0.1.0\n' > DESCRIPTION
    local out

    printf '{ "tools": { "zzrenvcheck": { "tag": "v0.3.1" } } }\n' > tooling.lock
    out=$(_wanted_tag v0.3.1 0.3.1)
    assert_true "grep -q 'INSTALL rgt47/zzrenvcheck@v0.11.0' <<< \"\$out\"" \
        "a v0.3.1 lock installs the minimum, never v0.3.1"
    assert_true "grep -q 'Rerun zzc docker' <<< \"\$out\"" \
        "a stale lock says how to update it"

    out=$(_wanted_tag v0.3.1 0.12.0)
    assert_true "grep -q '^DONE' <<< \"\$out\"" "the expression ran to the end"
    assert_false "grep -q 'INSTALL' <<< \"\$out\"" \
        "a newer installed release (shared library, dev install) is kept"

    printf '{ "tools": { "zzrenvcheck": { "tag": "v0.12.0" } } }\n' > tooling.lock
    out=$(_wanted_tag v0.12.0 0.11.0)
    assert_true "grep -q 'INSTALL rgt47/zzrenvcheck@v0.12.0' <<< \"\$out\"" \
        "a newer lock tag than the minimum is honored"

    rm -f tooling.lock
    out=$(_wanted_tag "" 0.10.0)
    assert_true "grep -q 'INSTALL rgt47/zzrenvcheck@v0.11.0' <<< \"\$out\"" \
        "without a lock the minimum is installed"
    teardown_test
}

##############################################################################
# renv snapshot type: analysis/-only packages reach renv.lock
##############################################################################

# Read the snapshot type the template's renv_init_quiet() uses, then run the
# same init + snapshot on a compendium whose analysis/ alone uses jsonlite.
test_template_snapshot_records_analysis_packages() {
    if ! command -v Rscript >/dev/null 2>&1 ||
        ! Rscript --vanilla -e "quit(status = if (all(c('renv', 'jsonlite') %in% rownames(installed.packages()))) 0L else 1L)" \
            >/dev/null 2>&1; then
        echo "SKIP: Rscript, renv, or jsonlite not available"
        return 0
    fi
    local type
    type=$(sed -n 's/.*snapshot.type = "\([a-z]*\)".*/\1/p' \
        "$ZZCOLLAB_ROOT/templates/.Rprofile" | head -1)
    assert_equals "implicit" "$type" "template initializes renv with implicit snapshots"

    setup_test
    mkdir -p analysis
    printf 'Package: snapfx\nVersion: 0.1.0\n' > DESCRIPTION
    printf 'jsonlite::toJSON(1)\n' > analysis/x.R
    local out
    out=$(RENV_CONFIG_AUTOLOADER_ENABLED=FALSE Rscript --vanilla -e "
        d <- getwd()
        renv::init(project = d, bare = TRUE,
                   settings = list(snapshot.type = '$type'),
                   force = TRUE, restart = FALSE, load = FALSE)
        renv::snapshot(project = d, library = .libPaths(), prompt = FALSE,
                       force = TRUE)
        lock <- jsonlite::read_json(file.path(d, 'renv.lock'))
        cat('LOCKED', 'jsonlite' %in% names(lock\$Packages), '\n')" 2>&1)
    assert_true "grep -q 'LOCKED TRUE' <<< \"\$out\"" \
        "a package used only in analysis/ is recorded in renv.lock"
    teardown_test
}

##############################################################################
# Auto-snapshot on exit is off unless opted in
##############################################################################

# Extract the template's .Last() from the parsed .Rprofile, replace
# renv::snapshot with a stub that records the call, and run it in a project
# that has renv.lock and renv/activate.R. Echoes SNAPSHOT or NO_SNAPSHOT.
_run_last_hook() {
    local setting="$1"
    Rscript --vanilla -e "
      exprs <- parse('$ZZCOLLAB_ROOT/templates/.Rprofile')
      find_last <- function(e) {
        if (is.call(e)) {
          if (identical(e[[1]], as.name('<-')) && identical(e[[2]], as.name('.Last')))
            return(e[[3]])
          for (x in as.list(e)[-1]) { r <- find_last(x); if (!is.null(r)) return(r) }
        }
        NULL
      }
      def <- NULL
      for (e in exprs) { def <- find_last(e); if (!is.null(def)) break }
      if (is.null(def)) { cat('NO_LAST_FOUND\n'); quit(status = 1) }
      src <- gsub('renv::snapshot', 'snap_stub', paste(deparse(def), collapse = '\n'), fixed = TRUE)
      env <- new.env()
      env\$in_ci <- FALSE
      env\$called <- FALSE
      env\$snap_stub <- function(...) assign('called', TRUE, envir = env)
      f <- eval(parse(text = src), envir = env)
      if (nzchar('$setting')) Sys.setenv(ZZCOLLAB_AUTO_SNAPSHOT = '$setting') else Sys.unsetenv('ZZCOLLAB_AUTO_SNAPSHOT')
      suppressMessages(f())
      cat(if (env\$called) 'SNAPSHOT' else 'NO_SNAPSHOT', '\n')" 2>&1
}

test_auto_snapshot_off_by_default() {
    if ! command -v Rscript >/dev/null 2>&1; then
        echo "SKIP: Rscript not available"
        return 0
    fi
    setup_test
    mkdir -p renv
    printf '{}\n' > renv.lock
    touch renv/activate.R
    assert_true "grep -q '^NO_SNAPSHOT' <<< \"\$(_run_last_hook '')\"" \
        "unset: the exit hook does not snapshot"
    assert_true "grep -q '^SNAPSHOT' <<< \"\$(_run_last_hook true)\"" \
        "ZZCOLLAB_AUTO_SNAPSHOT=true opts in"
    assert_true "grep -q '^NO_SNAPSHOT' <<< \"\$(_run_last_hook false)\"" \
        "ZZCOLLAB_AUTO_SNAPSHOT=false keeps it off"
    teardown_test
}

test_auto_snapshot_passed_to_runs() {
    setup_test
    local mk="$ZZCOLLAB_ROOT/templates/Makefile" out t
    printf 'FROM rocker/r-ver:4.5.0\n' > Dockerfile
    for t in docker-test docker-rstudio; do
        out=$(make -n -f "$mk" CONTAINER_RUNTIME=docker "$t" 2>&1 || true)
        assert_true "grep -q 'ZZCOLLAB_AUTO_SNAPSHOT=false' <<< \"\$out\"" \
            "$t passes the off default to the container"
        out=$(make -n -f "$mk" CONTAINER_RUNTIME=docker ZZCOLLAB_AUTO_SNAPSHOT=true "$t" 2>&1 || true)
        assert_true "grep -q 'ZZCOLLAB_AUTO_SNAPSHOT=true' <<< \"\$out\"" \
            "make $t ZZCOLLAB_AUTO_SNAPSHOT=true opts in"
    done
    teardown_test
}

##############################################################################
# The deprecated 'analysis' profile alias
##############################################################################

test_help_recommends_tidyverse_and_docker_profile() {
    local out
    out=$(bash "$ZZCOLLAB_ROOT/zzcollab.sh" --help 2>&1 || true)
    assert_true "grep -q '^  tidyverse  *Tidyverse data analysis' <<< \"\$out\"" \
        "help lists tidyverse as the recommended profile"
    assert_false "grep -q '^  analysis  *Tidyverse' <<< \"\$out\"" \
        "help no longer recommends the deprecated alias"
    assert_true "grep -q \"zzcollab docker --profile NAME\" <<< \"\$out\"" \
        "help says how to switch an existing project"
    assert_false "grep -q 'existing: switch profile' <<< \"\$out\"" \
        "help no longer claims a profile command switches a project"
}

test_config_set_analysis_profile_warns() {
    setup_test
    _seed_bare_config
    local out
    out=$(VERBOSITY_LEVEL=1 bash "$ZZCOLLAB_ROOT/zzcollab.sh" config set profile-name analysis \
        < /dev/null 2>&1 || true)
    assert_true "grep -q 'deprecated alias for the .tidyverse. profile' <<< \"\$out\"" \
        "config set profile-name analysis warns"
    out=$(VERBOSITY_LEVEL=1 bash "$ZZCOLLAB_ROOT/zzcollab.sh" config set profile-name tidyverse \
        < /dev/null 2>&1 || true)
    assert_false "grep -q 'deprecated' <<< \"\$out\"" "tidyverse does not warn"
    teardown_test
}

test_make_r_profile_label() {
    setup_test
    local mk="$ZZCOLLAB_ROOT/templates/Makefile" expr label
    printf 'FROM rocker/r-ver:4.5.0\nARG BASE_IMAGE=rocker/tidyverse\n' > Dockerfile
    expr=$(make -n -f "$mk" CONTAINER_RUNTIME=docker r 2>/dev/null \
        | grep -o "sed 's|\.\*/||;[^']*'" | head -1 | sed "s/^sed '//; s/'\$//")
    assert_not_empty "$expr" "make r derives a profile label with sed"
    label=$(printf '%s\n' rocker/tidyverse rocker/verse rocker/r-ver | sed "$expr" | tr '\n' ' ')
    assert_equals "tidyverse publishing minimal " "$label" \
        "labels: tidyverse stays tidyverse (not 'analysis' or 'tidyrocker/verse')"
    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
