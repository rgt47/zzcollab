#!/bin/bash
##############################################################################
# ZZCOLLAB CORE MODULE TESTS
##############################################################################
# Tests for lib/core.sh - foundation infrastructure
##############################################################################

set -euo pipefail

# Load test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Load core module
load_module_for_testing "core.sh"

##############################################################################
# TEST: validate_package_name
##############################################################################

test_validate_package_name_valid() {
    local result
    result=$(validate_package_name "mypackage")
    assert_equals "mypackage" "$result" "Should return valid package name"
}

test_validate_package_name_with_dots() {
    local result
    result=$(validate_package_name "my.package")
    assert_equals "my.package" "$result" "Should allow dots in package name"
}

test_validate_package_name_strips_invalid() {
    local result
    result=$(validate_package_name "my-package_123")
    assert_equals "mypackage123" "$result" "Should strip invalid characters"
}

test_validate_package_name_starts_with_letter() {
    local result
    if result=$(validate_package_name "123pkg" 2>/dev/null); then
        echo "FAIL: Should reject names starting with number" >&2
        return 1
    fi
    return 0
}

test_validate_package_name_empty() {
    if validate_package_name "---" 2>/dev/null; then
        echo "FAIL: Should reject names that become empty after sanitization" >&2
        return 1
    fi
    return 0
}

##############################################################################
# TEST: command_exists
##############################################################################

test_command_exists_bash() {
    if ! command_exists "bash"; then
        echo "FAIL: bash should exist" >&2
        return 1
    fi
}

test_command_exists_nonexistent() {
    if command_exists "nonexistent_command_xyz_12345"; then
        echo "FAIL: nonexistent command should not exist" >&2
        return 1
    fi
}

##############################################################################
# TEST: logging functions (with mocked verbosity)
##############################################################################

test_log_error_always_outputs() {
    export VERBOSITY_LEVEL=0
    local output
    output=$(log_error "Test error message" 2>&1)
    assert_output_contains "$output" "Test error message" "log_error should output at verbosity 0"
}

test_log_success_respects_verbosity() {
    export VERBOSITY_LEVEL=0
    local output
    output=$(log_success "Test success" 2>&1)
    if [[ -n "$output" ]]; then
        echo "FAIL: log_success should be silent at verbosity 0" >&2
        return 1
    fi
}

test_log_success_shows_at_level_1() {
    export VERBOSITY_LEVEL=1
    local output
    output=$(log_success "Test success" 2>&1)
    assert_output_contains "$output" "Test success" "log_success should output at verbosity 1"
}

test_log_info_respects_verbosity() {
    export VERBOSITY_LEVEL=1
    local output
    output=$(log_info "Test info" 2>&1)
    if [[ -n "$output" ]]; then
        echo "FAIL: log_info should be silent at verbosity 1" >&2
        return 1
    fi
}

test_log_info_shows_at_level_2() {
    export VERBOSITY_LEVEL=2
    local output
    output=$(log_info "Test info" 2>&1)
    assert_output_contains "$output" "Test info" "log_info should output at verbosity 2"
}

##############################################################################
# TEST: safe_mkdir
##############################################################################

test_safe_mkdir_creates_directory() {
    setup_test
    export VERBOSITY_LEVEL=0
    safe_mkdir "testdir" 2>/dev/null
    assert_dir_exists "testdir" "safe_mkdir should create directory"
    teardown_test
}

test_safe_mkdir_creates_nested() {
    setup_test
    export VERBOSITY_LEVEL=0
    safe_mkdir "a/b/c" 2>/dev/null
    assert_dir_exists "a/b/c" "safe_mkdir should create nested directories"
    teardown_test
}

##############################################################################
# TEST: setup_project_safe rollback (T-4)
##############################################################################
# These tests source zzcollab.sh (BASH_SOURCE guard prevents main() from
# running) to reach setup_project_safe, which lives in the main script.

_ZZCOLLAB_SCRIPT="$(cd "${SCRIPT_DIR}/../.." && pwd)/zzcollab.sh"
_ZZCOLLAB_AVAILABLE=false
if [[ -f "$_ZZCOLLAB_SCRIPT" ]]; then
    # shellcheck source=/dev/null
    source "$_ZZCOLLAB_SCRIPT" 2>/dev/null && _ZZCOLLAB_AVAILABLE=true
fi

test_setup_project_safe_rollback_preserves_preexisting_files() {
    if [[ "$_ZZCOLLAB_AVAILABLE" != "true" ]]; then
        echo "SKIP: zzcollab.sh not found"
        return 0
    fi
    setup_test
    cd "$TEST_TEMP_DIR"
    echo "preexisting content" > sentinel.txt

    setup_project() { return 1; }

    local rc=0
    setup_project_safe 2>/dev/null || rc=$?

    unset -f setup_project 2>/dev/null || true

    if [[ "$rc" -eq 0 ]]; then
        echo "FAIL: setup_project_safe should return nonzero on failure" >&2
        teardown_test
        return 1
    fi
    assert_file_exists "sentinel.txt" \
        "Pre-existing file must survive setup_project_safe rollback"
    teardown_test
}

test_setup_project_safe_rollback_removes_new_files() {
    if [[ "$_ZZCOLLAB_AVAILABLE" != "true" ]]; then
        echo "SKIP: zzcollab.sh not found"
        return 0
    fi
    setup_test
    cd "$TEST_TEMP_DIR"

    setup_project() {
        echo "scaffold" > new-scaffold-file.txt
        return 1
    }

    setup_project_safe 2>/dev/null || true
    unset -f setup_project 2>/dev/null || true

    if [[ -f "new-scaffold-file.txt" ]]; then
        echo "FAIL: File created during failed init was not rolled back" >&2
        teardown_test
        return 1
    fi
    teardown_test
}

##############################################################################
# RUN TESTS
##############################################################################

echo "=========================================="
echo "CORE MODULE TESTS"
echo "=========================================="

tests=(
    test_validate_package_name_valid
    test_validate_package_name_with_dots
    test_validate_package_name_strips_invalid
    test_validate_package_name_starts_with_letter
    test_validate_package_name_empty
    test_command_exists_bash
    test_command_exists_nonexistent
    test_log_error_always_outputs
    test_log_success_respects_verbosity
    test_log_success_shows_at_level_1
    test_log_info_respects_verbosity
    test_log_info_shows_at_level_2
    test_safe_mkdir_creates_directory
    test_safe_mkdir_creates_nested
    test_setup_project_safe_rollback_preserves_preexisting_files
    test_setup_project_safe_rollback_removes_new_files
)

pass=0
fail=0

for test in "${tests[@]}"; do
    if ( $test ) 2>/dev/null; then
        echo "  PASS: $test"
        pass=$((pass + 1))
    else
        echo "  FAIL: $test"
        fail=$((fail + 1))
    fi
done

echo "------------------------------------------"
echo "Results: $pass passed, $fail failed"
echo "=========================================="

if [[ $fail -gt 0 ]]; then
    exit 1
fi
