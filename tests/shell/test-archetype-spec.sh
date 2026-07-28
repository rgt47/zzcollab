#!/bin/bash
##############################################################################
# ZZCOLLAB ARCHETYPE SPEC ENGINE TESTS
##############################################################################
# Tests for archetype_spec (declarative table) and the ZZCOLLAB_BARE gating of
# the R-package skeleton in create_directory_structure (R9).
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

load_module_for_testing "core.sh"
load_module_for_testing "project.sh"

##############################################################################
# TEST: archetype_spec maps each archetype to its render entry
##############################################################################

test_archetype_spec_render_entry() {
    assert_equals "report_rmd"     "$(archetype_spec manuscript render_entry)" "manuscript -> report_rmd"
    assert_equals "analysis_index" "$(archetype_spec analysis render_entry)"   "analysis -> analysis_index (R4)"
    assert_equals "blog_index"     "$(archetype_spec blog render_entry)"       "blog -> blog_index"
    assert_equals "book"           "$(archetype_spec book render_entry)"       "book -> book"
    assert_equals "simulation"     "$(archetype_spec simulation render_entry)" "simulation -> simulation"
    assert_equals "none"           "$(archetype_spec package render_entry)"    "package -> none"
}

##############################################################################
# TEST: only blog carries the symlink set
##############################################################################

test_archetype_spec_symlinks() {
    assert_equals "blog" "$(archetype_spec blog symlinks)"       "blog -> blog symlinks"
    assert_equals "none" "$(archetype_spec manuscript symlinks)" "manuscript -> no symlinks"
    assert_equals "none" "$(archetype_spec book symlinks)"       "book -> no symlinks (R7 standalone)"
}

##############################################################################
# TEST: ZZCOLLAB_BARE skips the R-package directories (R9)
##############################################################################

test_bare_skips_package_dirs() {
    setup_test
    cd "$TEST_TEMP_DIR"

    ZZCOLLAB_BARE=true create_directory_structure >/dev/null 2>&1

    assert_false "[ -d R ]"           "bare: R/ must not be created"
    assert_false "[ -d tests ]"       "bare: tests/ must not be created"
    assert_false "[ -d inst/tinytest ]" "bare: inst/tinytest must not be created"
    assert_true  "[ -d analysis ]"    "bare: analysis/ must still be created"
    assert_true  "[ -d analysis/report ]" "bare: analysis/report must still be created"

    teardown_test
}

##############################################################################
# TEST: default (non-bare) still creates the R-package directories
##############################################################################

test_nonbare_creates_package_dirs() {
    setup_test
    cd "$TEST_TEMP_DIR"

    create_directory_structure >/dev/null 2>&1

    assert_true "[ -d R ]"     "default: R/ must be created"
    assert_true "[ -d tests ]" "default: tests/ must be created"

    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
