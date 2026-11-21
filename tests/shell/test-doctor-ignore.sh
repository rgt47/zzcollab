#!/bin/bash
##############################################################################
# ZZCOLLAB DOCTOR IGNORE-FILE TESTS
##############################################################################
#
# zzc doctor checks .gitignore and .Rbuildignore for required entries
# (check_ignore_files in modules/doctor.sh). Entries are matched against
# whole lines, not substrings, and missing entries are appended so that a
# file without a final newline does not have its last line corrupted.
#
# Run individually:
#   bash tests/shell/test-doctor-ignore.sh
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# doctor.sh reads ZZCOLLAB_TEMPLATE_VERSION (constants.sh) at source time,
# and its last line ('[[ sourced ]] && main') returns 1 when sourced, so the
# load is judged by whether the function exists rather than by its status.
_load_doctor() {
    load_module_for_testing "constants.sh"
    load_module_for_testing "doctor.sh" > /dev/null 2>&1 || true
    declare -F check_ignore_files > /dev/null || {
        echo "FAIL: doctor.sh did not load"
        return 1
    }
}

##############################################################################
# Fixtures
##############################################################################

# The .gitignore and .Rbuildignore that 'zzc init' writes
# (create_dev_tools in modules/project.sh).
_good_gitignore() {
    printf '%s\n' .Rproj.user .Rhistory .RData '*.Rproj' renv/library/ \
        renv/staging/ .make/ '**/.claude/settings.local.json' '.zz.*' \
        .zzc.R .zzo.txt '.zzhud_*' .graphics/ > "$1"
}

_good_rbuildignore() {
    printf '%s\n' '^.*\.Rproj$' '^\.Rproj\.user$' '^analysis$' '^docs$' \
        '^\.github$' '^renv$' '^renv\.lock$' '^Makefile$' '^Dockerfile$' \
        '^\.dockerignore$' '^\.graphics$' '^\.zz' > "$1"
}

# Missing-entry count reported by check_ignore_files for the current dir.
_missing() {
    local rc=0
    check_ignore_files . < /dev/null > /dev/null 2>&1 || rc=$?
    echo "$rc"
}

##############################################################################
# Matching
##############################################################################

test_fresh_init_files_pass() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_gitignore .gitignore
    _good_rbuildignore .Rbuildignore
    assert_equals "0" "$(_missing)" "ignore files written by zzc init pass"
    teardown_test
}

# A line glued onto the previous one by the old append bug must not
# satisfy the entry it contains.
test_glued_line_does_not_count() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_gitignore .gitignore
    _good_rbuildignore r.tmp
    grep -v -x -F '^docs$' r.tmp > .Rbuildignore
    printf '%s\n' '^.*\.Rproj$^docs$' >> .Rbuildignore
    assert_equals "1" "$(_missing)" "'^.*\\.Rproj\$^docs\$' leaves ^docs missing"
    teardown_test
}

test_zzcollab_line_does_not_cover_zz() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_gitignore .gitignore
    _good_rbuildignore r.tmp
    grep -v -x -F '^\.zz' r.tmp > .Rbuildignore
    printf '%s\n' '^\.zzcollab$' >> .Rbuildignore
    assert_equals "1" "$(_missing)" "'^\\.zzcollab\$' does not satisfy ^\\.zz"
    teardown_test
}

test_substring_does_not_count() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_rbuildignore .Rbuildignore
    _good_gitignore g.tmp
    grep -v -x -F '.Rhistory' g.tmp > .gitignore
    printf '%s\n' '.Rhistory.bak' >> .gitignore
    assert_equals "1" "$(_missing)" "'.Rhistory.bak' does not satisfy .Rhistory"
    teardown_test
}

test_comment_does_not_count() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_rbuildignore .Rbuildignore
    _good_gitignore g.tmp
    grep -v -x -F '.RData' g.tmp > .gitignore
    printf '%s\n' '# .RData' >> .gitignore
    assert_equals "1" "$(_missing)" "'# .RData' does not satisfy .RData"
    teardown_test
}

# Projects scaffolded before the patterns were anchored still pass: an
# unanchored prefix excludes everything the anchored entry does.
test_unanchored_legacy_rbuildignore_passes() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_gitignore .gitignore
    printf '%s\n' '^analysis' '^docs' '^\.github' '^renv' '^Makefile' \
        '^Dockerfile' '^\.graphics' '^\.zz' > .Rbuildignore
    assert_equals "0" "$(_missing)" "unanchored legacy patterns pass"
    teardown_test
}

test_crlf_and_trailing_blanks_pass() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_gitignore g.tmp
    _good_rbuildignore r.tmp
    awk '{ printf "%s \r\n", $0 }' g.tmp > .gitignore
    awk '{ printf "%s\r\n", $0 }' r.tmp > .Rbuildignore
    assert_equals "0" "$(_missing)" "CRLF and trailing blanks do not cause misses"
    teardown_test
}

test_equivalent_gitignore_spellings_pass() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_rbuildignore .Rbuildignore
    _good_gitignore g.tmp
    sed -e 's#^\.make/$#/.make/#' -e 's#^\.Rhistory$#*.Rhistory#' \
        -e 's#^\.Rproj\.user$#.Rproj.user/#' g.tmp > .gitignore
    assert_equals "0" "$(_missing)" "/.make/, *.Rhistory, .Rproj.user/ accepted"
    teardown_test
}

##############################################################################
# Appending (the fix step)
##############################################################################

test_append_keeps_last_line_without_newline() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    printf '%s' '^.*\.Rproj$' > .Rbuildignore
    _append_lines .Rbuildignore '^docs$' '^\.zz'
    assert_equals "^.*\\.Rproj\$" "$(sed -n 1p .Rbuildignore)" \
        "existing last line is left intact"
    assert_equals "^docs\$" "$(sed -n 2p .Rbuildignore)" \
        "first appended entry is on its own line"
    assert_equals "3" "$(wc -l < .Rbuildignore | tr -d ' ')" \
        "one line per entry, final newline present"
    teardown_test
}

test_append_adds_no_blank_line() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    printf '%s\n' '^.*\.Rproj$' > .Rbuildignore
    _append_lines .Rbuildignore '^docs$'
    assert_equals "0" "$(grep -c -x '' .Rbuildignore || true)" \
        "no blank line inserted when the file ends in a newline"
    teardown_test
}

test_append_to_empty_file() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    : > .Rbuildignore
    _append_lines .Rbuildignore '^docs$'
    assert_equals "^docs\$" "$(cat .Rbuildignore)" \
        "empty file gets the entry with no leading blank line"
    teardown_test
}

# Appending what check_ignore_files reports as missing makes a file that
# lacked a final newline pass on re-check.
test_append_missing_then_recheck_passes() {
    setup_test
    _load_doctor || { teardown_test; return 1; }
    _good_gitignore .gitignore
    printf '%s' '^.*\.Rproj$' > .Rbuildignore
    _append_lines .Rbuildignore "${REQUIRED_RBUILDIGNORE[@]}"
    assert_equals "0" "$(_missing)" "re-check passes after appending entries"
    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
