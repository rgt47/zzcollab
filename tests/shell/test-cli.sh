#!/bin/bash
################################################################################
# Unit Tests for cli.sh Module
#
# Tests command-line interface functionality:
# - Argument parsing
# - Flag validation
# - Variable assignment
# - Error handling
################################################################################

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"

################################################################################
# Test Suite: require_arg Function
################################################################################

test_require_arg_with_value() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Should succeed when argument provided
    assert_success require_arg "--team" "myteam"
}

test_require_arg_missing() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Should fail when argument empty
    assert_failure require_arg "--team" ""
}

test_require_arg_error_message() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Error message should mention flag
    output=$(require_arg "--team" "" 2>&1 || true)
    assert_contains "$output" "--team" "Error should mention flag name"
}

################################################################################
# Test Suite: validate_team_name
################################################################################

test_validate_team_name_valid() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Valid team names should pass
    assert_success validate_team_name "my-team"
    assert_success validate_team_name "lab-123"
    assert_success validate_team_name "research"
}

test_validate_team_name_too_short() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Single character should fail
    assert_failure validate_team_name "a"
}

test_validate_team_name_invalid_chars() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Special characters should fail
    assert_failure validate_team_name "my_team!"
    assert_failure validate_team_name "my team"
}

test_validate_team_name_too_long() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Name longer than 50 chars should fail
    long_name=$(printf 'a%.0s' {1..51})
    assert_failure validate_team_name "$long_name"
}

test_validate_team_name_reserved() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Reserved names should fail
    assert_failure validate_team_name "zzcollab"
    assert_failure validate_team_name "docker"
    assert_failure validate_team_name "github"
}

test_validate_team_name_error_message() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Error message should be helpful
    output=$(validate_team_name "invalid!" 2>&1 || true)
    assert_contains "$output" "Invalid" "Should say name is invalid"
}

################################################################################
# Test Suite: validate_project_name
################################################################################

test_validate_project_name_valid() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Valid project names should pass
    assert_success validate_project_name "my-project"
    assert_success validate_project_name "my_project"
    assert_success validate_project_name "project123"
}

test_validate_project_name_invalid_start() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Names starting with special char should fail
    assert_failure validate_project_name "-invalid"
    assert_failure validate_project_name "_invalid"
}

test_validate_project_name_special_chars() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Disallowed special characters should fail
    assert_failure validate_project_name "my project!"
    assert_failure validate_project_name "project@home"
}

################################################################################
# Test Suite: validate_base_image
################################################################################

test_validate_base_image_docker_hub() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Docker Hub images should be valid
    assert_success validate_base_image "rocker/rstudio"
    assert_success validate_base_image "rocker/r-ver"
    assert_success validate_base_image "ubuntu"
}

test_validate_base_image_with_tag() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Images with tags should be valid
    assert_success validate_base_image "rocker/rstudio:4.3.1"
    assert_success validate_base_image "ubuntu:20.04"
}

test_validate_base_image_custom_registry() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Custom registries should be valid
    assert_success validate_base_image "ghcr.io/org/image"
    assert_success validate_base_image "localhost:5000/image"
}

test_validate_base_image_invalid() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Invalid formats should fail
    assert_failure validate_base_image "invalid image name!"
    assert_failure validate_base_image "image with spaces"
}

################################################################################
# Test Suite: validate_r_version
################################################################################

test_validate_r_version_valid() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Semantic versions should be valid
    assert_success validate_r_version "4.3.1"
    assert_success validate_r_version "3.6.0"
    assert_success validate_r_version "4.0.0"
}

test_validate_r_version_incomplete() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Incomplete versions should fail
    assert_failure validate_r_version "4.3"
    assert_failure validate_r_version "4"
}

test_validate_r_version_invalid_format() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Non-numeric versions should fail
    assert_failure validate_r_version "4.3.x"
    assert_failure validate_r_version "latest"
}

################################################################################
# Test Suite: validate_bundle_name
################################################################################

test_validate_bundle_name_empty() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: Empty bundle name should be OK (optional)
    assert_success validate_bundle_name "package_bundles" ""
}

test_validate_bundle_name_missing_bundles_file() {
    # Setup
    setup_test
    cd "$TEMP_TEST_DIR"
    load_module_for_testing "cli.sh"

    # Test: Should handle missing bundles file gracefully
    assert_success validate_bundle_name "package_bundles" "tidyverse"

    teardown_test
}

################################################################################
# Test Suite: Integration Tests
################################################################################

test_validate_all_cli_args_success() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: All validation should pass for valid args
    assert_success validate_team_name "my-team"
    assert_success validate_project_name "my-project"
    assert_success validate_base_image "rocker/r-ver"
    assert_success validate_r_version "4.3.1"
}

test_cli_variables_initialized() {
    # Setup
    setup_test_logging
    load_module_for_testing "cli.sh"

    # Test: All expected variables should be initialized
    if [[ -z "${BUILD_DOCKER+x}" ]]; then
        echo "❌ FAILED: BUILD_DOCKER not initialized"
        return 1
    fi

    if [[ -z "${TEAM_NAME+x}" ]]; then
        echo "❌ FAILED: TEAM_NAME not initialized"
        return 1
    fi

    if [[ -z "${PROJECT_NAME+x}" ]]; then
        echo "❌ FAILED: PROJECT_NAME not initialized"
        return 1
    fi
}

################################################################################
# Test Execution
################################################################################

run_tests() {
    local pass=0
    local fail=0

    # Array of test names
    local tests=(
        "test_require_arg_with_value"
        "test_require_arg_missing"
        "test_require_arg_error_message"
        "test_validate_team_name_valid"
        "test_validate_team_name_too_short"
        "test_validate_team_name_invalid_chars"
        "test_validate_team_name_too_long"
        "test_validate_team_name_reserved"
        "test_validate_team_name_error_message"
        "test_validate_project_name_valid"
        "test_validate_project_name_invalid_start"
        "test_validate_project_name_special_chars"
        "test_validate_base_image_docker_hub"
        "test_validate_base_image_with_tag"
        "test_validate_base_image_custom_registry"
        "test_validate_base_image_invalid"
        "test_validate_r_version_valid"
        "test_validate_r_version_incomplete"
        "test_validate_r_version_invalid_format"
        "test_validate_bundle_name_empty"
        "test_validate_bundle_name_missing_bundles_file"
        "test_validate_all_cli_args_success"
        "test_cli_variables_initialized"
    )

    echo "=================================="
    echo "Testing: cli.sh Module"
    echo "=================================="

    for test in "${tests[@]}"; do
        if $test 2>/dev/null; then
            echo "✅ $test"
            ((pass++))
        else
            echo "❌ $test"
            ((fail++))
        fi
    done

    echo ""
    echo "=================================="
    echo "Results: $pass passed, $fail failed"
    echo "=================================="

    return $((fail > 0 ? 1 : 0))
}

# Run all tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
