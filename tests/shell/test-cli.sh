#!/bin/bash
##############################################################################
# ZZCOLLAB CLI MODULE TESTS
##############################################################################
# Tests for modules/cli.sh - command line interface parsing and validation
##############################################################################

set -euo pipefail

# Load test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Load required modules
load_module_for_testing "core.sh"
load_module_for_testing "cli.sh"

##############################################################################
# TEST: require_arg
##############################################################################

test_require_arg_with_value() {
    if ! require_arg "--flag" "value"; then
        echo "FAIL: require_arg should succeed with value" >&2
        return 1
    fi
}

test_require_arg_empty() {
    local exit_code=0
    require_arg "--flag" "" 2>/dev/null || exit_code=$?
    if [[ "$exit_code" -eq 0 ]]; then
        echo "FAIL: require_arg should fail with empty value" >&2
        return 1
    fi
}

test_require_arg_missing() {
    local exit_code=0
    require_arg "--flag" 2>/dev/null || exit_code=$?
    if [[ "$exit_code" -eq 0 ]]; then
        echo "FAIL: require_arg should fail with missing value" >&2
        return 1
    fi
}

##############################################################################
# TEST: validate_team_name
##############################################################################

test_validate_team_name_valid() {
    export VERBOSITY_LEVEL=0
    if ! validate_team_name "my-team" 2>/dev/null; then
        echo "FAIL: 'my-team' should be valid" >&2
        return 1
    fi
}

test_validate_team_name_valid_simple() {
    export VERBOSITY_LEVEL=0
    if ! validate_team_name "research" 2>/dev/null; then
        echo "FAIL: 'research' should be valid" >&2
        return 1
    fi
}

test_validate_team_name_valid_numbers() {
    export VERBOSITY_LEVEL=0
    if ! validate_team_name "lab123" 2>/dev/null; then
        echo "FAIL: 'lab123' should be valid" >&2
        return 1
    fi
}

test_validate_team_name_empty() {
    export VERBOSITY_LEVEL=0
    if validate_team_name "" 2>/dev/null; then
        echo "FAIL: empty team name should be invalid" >&2
        return 1
    fi
}

test_validate_team_name_too_short() {
    export VERBOSITY_LEVEL=0
    if validate_team_name "a" 2>/dev/null; then
        echo "FAIL: single character team name should be invalid" >&2
        return 1
    fi
}

test_validate_team_name_invalid_chars() {
    export VERBOSITY_LEVEL=0
    if validate_team_name "my_team" 2>/dev/null; then
        echo "FAIL: underscores should be invalid in team names" >&2
        return 1
    fi
}

test_validate_team_name_reserved() {
    export VERBOSITY_LEVEL=0
    if validate_team_name "docker" 2>/dev/null; then
        echo "FAIL: reserved name 'docker' should be invalid" >&2
        return 1
    fi
}

test_validate_team_name_reserved_zzcollab() {
    export VERBOSITY_LEVEL=0
    if validate_team_name "zzcollab" 2>/dev/null; then
        echo "FAIL: reserved name 'zzcollab' should be invalid" >&2
        return 1
    fi
}

##############################################################################
# TEST: validate_project_name
##############################################################################

test_validate_project_name_valid() {
    export VERBOSITY_LEVEL=0
    if ! validate_project_name "myproject" 2>/dev/null; then
        echo "FAIL: 'myproject' should be valid" >&2
        return 1
    fi
}

test_validate_project_name_with_hyphen() {
    export VERBOSITY_LEVEL=0
    if ! validate_project_name "my-project" 2>/dev/null; then
        echo "FAIL: 'my-project' should be valid" >&2
        return 1
    fi
}

test_validate_project_name_with_underscore() {
    export VERBOSITY_LEVEL=0
    if ! validate_project_name "my_project" 2>/dev/null; then
        echo "FAIL: 'my_project' should be valid" >&2
        return 1
    fi
}

test_validate_project_name_empty() {
    export VERBOSITY_LEVEL=0
    if validate_project_name "" 2>/dev/null; then
        echo "FAIL: empty project name should be invalid" >&2
        return 1
    fi
}

test_validate_project_name_invalid_start() {
    export VERBOSITY_LEVEL=0
    if validate_project_name "-myproject" 2>/dev/null; then
        echo "FAIL: project name starting with hyphen should be invalid" >&2
        return 1
    fi
}

##############################################################################
# TEST: validate_base_image
##############################################################################

test_validate_base_image_simple() {
    export VERBOSITY_LEVEL=0
    if ! validate_base_image "rocker/rstudio" 2>/dev/null; then
        echo "FAIL: 'rocker/rstudio' should be valid" >&2
        return 1
    fi
}

test_validate_base_image_with_tag() {
    export VERBOSITY_LEVEL=0
    if ! validate_base_image "rocker/rstudio:4.3.1" 2>/dev/null; then
        echo "FAIL: 'rocker/rstudio:4.3.1' should be valid" >&2
        return 1
    fi
}

test_validate_base_image_registry() {
    export VERBOSITY_LEVEL=0
    if ! validate_base_image "ghcr.io/org/image" 2>/dev/null; then
        echo "FAIL: 'ghcr.io/org/image' should be valid" >&2
        return 1
    fi
}

test_validate_base_image_with_port() {
    export VERBOSITY_LEVEL=0
    if ! validate_base_image "localhost:5000/myimage" 2>/dev/null; then
        echo "FAIL: 'localhost:5000/myimage' should be valid" >&2
        return 1
    fi
}

test_validate_base_image_empty() {
    export VERBOSITY_LEVEL=0
    if validate_base_image "" 2>/dev/null; then
        echo "FAIL: empty base image should be invalid" >&2
        return 1
    fi
}

test_validate_base_image_invalid_double_slash() {
    export VERBOSITY_LEVEL=0
    if validate_base_image "registry//image" 2>/dev/null; then
        echo "FAIL: double slash should be invalid" >&2
        return 1
    fi
}

##############################################################################
# RUN TESTS
##############################################################################

echo "=========================================="
echo "CLI MODULE TESTS"
echo "=========================================="

tests=(
    test_require_arg_with_value
    test_require_arg_empty
    test_require_arg_missing
    test_validate_team_name_valid
    test_validate_team_name_valid_simple
    test_validate_team_name_valid_numbers
    test_validate_team_name_empty
    test_validate_team_name_too_short
    test_validate_team_name_invalid_chars
    test_validate_team_name_reserved
    test_validate_team_name_reserved_zzcollab
    test_validate_project_name_valid
    test_validate_project_name_with_hyphen
    test_validate_project_name_with_underscore
    test_validate_project_name_empty
    test_validate_project_name_invalid_start
    test_validate_base_image_simple
    test_validate_base_image_with_tag
    test_validate_base_image_registry
    test_validate_base_image_with_port
    test_validate_base_image_empty
    test_validate_base_image_invalid_double_slash
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
