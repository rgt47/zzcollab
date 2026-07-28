#!/bin/bash
##############################################################################
# ZZCOLLAB ARCHETYPE SYMLINK TOPOLOGY TESTS
##############################################################################
# Tests for create_relative_symlink / create_archetype_symlinks in
# modules/project.sh - the symlink topology publishing archetypes need.
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

load_module_for_testing "core.sh"
load_module_for_testing "project.sh"

##############################################################################
# TEST: create_relative_symlink is idempotent and points at the target
##############################################################################

test_create_relative_symlink_idempotent() {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p analysis/data

    create_relative_symlink "data" "analysis/data"
    create_relative_symlink "data" "analysis/data"   # second call must not fail

    assert_true "[ -L data ]"                 "data must be a symlink"
    assert_equals "analysis/data" "$(readlink data)" "data must point at analysis/data"
    assert_true "[ -d data ]"                 "data symlink must resolve to a dir"

    teardown_test
}

##############################################################################
# TEST: blog archetype gets the full root + in-report symlink topology
##############################################################################

test_blog_symlink_topology() {
    setup_test
    cd "$TEST_TEMP_DIR"

    # Prerequisites the blog scaffold would have created before symlinking.
    mkdir -p analysis/data analysis/figures analysis/media/images analysis/report
    echo "post" > analysis/report/index.qmd

    create_archetype_symlinks "blog"

    # Root symlinks surface the report + assets for a parent Quarto site.
    assert_true "[ -L index.qmd ]"  "root index.qmd must be a symlink"
    assert_equals "analysis/report/index.qmd" "$(readlink index.qmd)" \
        "root index.qmd must point into analysis/report"
    assert_true "[ -e index.qmd ]"  "root index.qmd symlink must resolve"
    for a in data figures media; do
        assert_true "[ -L $a ]"     "root $a must be a symlink"
    done

    # In-report symlinks let index.qmd resolve assets when rendered in place.
    for a in data figures media; do
        assert_true "[ -L analysis/report/$a ]" "analysis/report/$a must be a symlink"
        assert_equals "../$a" "$(readlink analysis/report/$a)" \
            "analysis/report/$a must point at ../$a"
    done

    teardown_test
}

##############################################################################
# TEST: non-publishing archetype gets no symlinks
##############################################################################

test_analysis_archetype_no_symlinks() {
    setup_test
    cd "$TEST_TEMP_DIR"
    mkdir -p analysis/data

    create_archetype_symlinks "analysis"

    assert_false "[ -L index.qmd ]" "analysis archetype must not create root index.qmd symlink"
    assert_false "[ -L data ]"      "analysis archetype must not symlink data"

    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
