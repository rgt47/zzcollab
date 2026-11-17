#!/bin/bash
##############################################################################
# ZZCOLLAB RENDER-REPORT GATING TESTS
##############################################################################
#
# render-report.yml belongs only in a workspace that has a report
# (zzc_has_report in lib/core.sh). These tests cover the shared definition,
# the workflow set (zzc_workflow_pairs / zzc_workflow_expected), the scaffold
# (zzc init per archetype), zzc doctor, and zzc status.
#
# Run individually:
#   bash tests/shell/test-render-report-gating.sh
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

ZZCOLLAB_SH="$ZZCOLLAB_ROOT/zzcollab.sh"

# constants.sh marks the config paths readonly, which would block the
# fixtures below from pointing them at a seeded config. run_test runs each
# test in a subshell, so the unit tests load the libraries locally.
_load_core() {
    load_module_for_testing "constants.sh"
    load_module_for_testing "core.sh"
}

##############################################################################
# Fixtures (same pattern as test-capture-matrix.sh)
##############################################################################

_seed_config() {
    mkdir -p cfg proj
    cat > cfg/config.yaml << 'EOF'
author:
  name: "Gating Tester"
  email: "gating@example.com"
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

_zzc() {
    ZZCOLLAB_ACCEPT_DEFAULTS=true ZZCOLLAB_NO_BUILD=true \
        bash "$ZZCOLLAB_SH" "$@" < /dev/null > /dev/null 2>&1
}

# Doctor output (stdout and stderr) for the current dir, colors included.
_doctor_out() {
    bash "$ZZCOLLAB_ROOT/modules/doctor.sh" . < /dev/null 2>&1 || true
}

_doctor_rc() {
    local rc=0
    bash "$ZZCOLLAB_ROOT/modules/doctor.sh" . < /dev/null > /dev/null 2>&1 || rc=$?
    echo "$rc"
}

# The 'CI render' line of zzc status for the current dir.
_status_render_line() {
    ZZCOLLAB_ACCEPT_DEFAULTS=true bash "$ZZCOLLAB_SH" status . < /dev/null 2>&1 \
        | grep 'CI render' || true
}

##############################################################################
# zzc_has_report: the shared definition
##############################################################################

test_has_report_definition() {
    _load_core
    setup_test

    assert_false "zzc_has_report ." "no analysis/: no report"
    mkdir -p analysis/data analysis/report analysis/posts analysis/paper
    assert_false "zzc_has_report ." "empty analysis/report/: no report"

    touch analysis/data/notes.Rmd
    assert_false "zzc_has_report ." "an .Rmd outside the report globs is not a report"

    touch analysis/report/index.qmd
    assert_true "zzc_has_report ." "analysis/report/index.qmd is a report"
    rm analysis/report/index.qmd

    touch analysis/report/draft.Rmd
    assert_true "zzc_has_report ." "any .Rmd in analysis/report/ is a report"
    rm analysis/report/draft.Rmd

    touch analysis/paper/report.Rmd
    assert_true "zzc_has_report ." "report.Rmd anywhere under analysis/ is a report"
    rm analysis/paper/report.Rmd

    touch analysis/posts/first.Rmd
    assert_true "zzc_has_report ." "an .Rmd in analysis/posts/ is a report"

    # Explicit DIR argument, from outside the workspace.
    local ws="$PWD"
    cd /
    assert_true "zzc_has_report '$ws'" "DIR argument is honored"
    cd "$ws"

    teardown_test
}

##############################################################################
# zzc_workflow_pairs / zzc_workflow_expected
##############################################################################

test_pairs_without_report() {
    _load_core
    setup_test
    mkdir -p ws/analysis/report

    local pairs
    pairs=$(zzc_workflow_pairs analysis ws)
    assert_equals "workflows/r-package.yml|.github/workflows/r-package.yml" "$pairs" \
        "no report: only r-package.yml"
    assert_false "zzc_workflow_expected analysis render-report.yml ws" \
        "no report: render-report.yml not expected"
    assert_true "zzc_workflow_expected analysis r-package.yml ws" \
        "no report: r-package.yml still expected"

    pairs=$(ZZCOLLAB_BARE=true zzc_workflow_pairs analysis ws)
    assert_equals "" "$pairs" "bare + no report: empty workflow set"

    teardown_test
}

test_pairs_with_report() {
    _load_core
    setup_test
    mkdir -p ws/analysis/report
    touch ws/analysis/report/report.Rmd

    local pairs
    pairs=$(zzc_workflow_pairs analysis ws)
    assert_true "grep -q '|.github/workflows/render-report.yml\$' <<< '$pairs'" \
        "report: render-report.yml in the set"
    assert_true "grep -q '|.github/workflows/r-package.yml\$' <<< '$pairs'" \
        "report: r-package.yml in the set"
    assert_true "zzc_workflow_expected analysis render-report.yml ws" \
        "report: render-report.yml expected"

    pairs=$(ZZCOLLAB_BARE=true zzc_workflow_pairs analysis ws)
    assert_equals "workflows/render-report.yml|.github/workflows/render-report.yml" \
        "$pairs" "bare + report: render-report.yml only"

    # Book and blog keep their own single workflow regardless.
    assert_equals "workflows/render-book.yml|.github/workflows/render-book.yml" \
        "$(zzc_workflow_pairs book ws)" "book set unchanged"
    assert_equals "workflows/blog-render.yml|.github/workflows/blog-render.yml" \
        "$(zzc_workflow_pairs blog ws)" "blog set unchanged"

    teardown_test
}

##############################################################################
# Scaffold: the archetype's report exists before workflows are installed
##############################################################################

test_init_installs_render_only_with_report() {
    setup_test
    _seed_config

    ( cd proj && _zzc init --force --archetype manuscript ) \
        || { echo "FAIL: init manuscript"; teardown_test; return 1; }
    assert_file_exists "proj/analysis/report/report.Rmd" "manuscript: report scaffolded"
    assert_file_exists "proj/.github/workflows/render-report.yml" \
        "manuscript: render-report.yml installed"

    rm -rf proj && mkdir proj
    ( cd proj && _zzc init --force --archetype package ) \
        || { echo "FAIL: init package"; teardown_test; return 1; }
    assert_file_exists "proj/.github/workflows/r-package.yml" \
        "package: r-package.yml installed"
    assert_false "[[ -f proj/.github/workflows/render-report.yml ]]" \
        "package: no render-report.yml without a report"

    teardown_test
}

##############################################################################
# Doctor
##############################################################################

test_doctor_no_report() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force --archetype package || { echo "FAIL: init"; teardown_test; return 1; }

    local out rc_clean
    out=$(_doctor_out)
    assert_false "grep -q 'render-report.yml.*missing' <<< \"\$out\"" \
        "doctor: render-report.yml not flagged missing without a report"
    rc_clean=$(_doctor_rc)

    # A leftover render workflow with no report: reported as unneeded,
    # informational only (exit code unchanged), and not deleted.
    cp "$ZZCOLLAB_ROOT/templates/workflows/render-report.yml" .github/workflows/
    out=$(_doctor_out)
    assert_true "grep -q 'render-report.yml.*unneeded' <<< \"\$out\"" \
        "doctor: render-report.yml without a report reported as unneeded"
    assert_equals "$rc_clean" "$(_doctor_rc)" \
        "doctor: unneeded render-report.yml does not change the exit code"
    assert_file_exists ".github/workflows/render-report.yml" \
        "doctor: unneeded render-report.yml is not deleted"

    teardown_test
}

test_doctor_report_missing_workflow() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force --archetype manuscript || { echo "FAIL: init"; teardown_test; return 1; }
    rm -f .github/workflows/render-report.yml

    local out
    out=$(_doctor_out)
    assert_true "grep -q 'render-report.yml.*missing' <<< \"\$out\"" \
        "doctor: render-report.yml flagged missing when a report exists"
    assert_equals "1" "$(_doctor_rc)" "doctor: missing render workflow is an issue"

    teardown_test
}

##############################################################################
# Status
##############################################################################

test_status_render_line() {
    setup_test
    _seed_config
    cd proj
    _zzc init --force --archetype package || { echo "FAIL: init"; teardown_test; return 1; }

    local line
    line=$(_status_render_line)
    assert_true "grep -q 'off (no report)' <<< \"\$line\"" \
        "status: no report shows 'off (no report)'"

    cp "$ZZCOLLAB_ROOT/templates/workflows/render-report.yml" .github/workflows/
    line=$(_status_render_line)
    assert_true "grep -q 'on  (no report: unneeded)' <<< \"\$line\"" \
        "status: workflow without a report shows unneeded"

    # A report with no render workflow: plain 'off', not 'no report'.
    rm -f .github/workflows/render-report.yml
    mkdir -p analysis/report
    touch analysis/report/report.Rmd
    line=$(_status_render_line)
    assert_true "grep -q 'CI render *off ' <<< \"\$line\"" \
        "status: report without workflow shows off"
    assert_false "grep -q 'no report' <<< \"\$line\"" \
        "status: report without workflow is not labeled 'no report'"

    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
