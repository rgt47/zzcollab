#!/bin/bash
##############################################################################
# ZZCOLLAB VALIDATION MODULE TESTS
##############################################################################
# Tests for modules/validation.sh - package dependency validation
##############################################################################

set -euo pipefail

# Load test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Load required modules
load_module_for_testing "core.sh"
load_module_for_testing "validation.sh"

##############################################################################
# TEST: verify_description_file
##############################################################################

test_verify_description_exists() {
    setup_test
    echo "Package: testpkg" > DESCRIPTION
    echo "Title: Test Package" >> DESCRIPTION
    if ! verify_description_file "DESCRIPTION" 2>/dev/null; then
        teardown_test
        echo "FAIL: verify_description_file should succeed when file exists" >&2
        return 1
    fi
    teardown_test
}

test_verify_description_missing() {
    setup_test
    export VERBOSITY_LEVEL=0
    if verify_description_file "DESCRIPTION" 2>/dev/null; then
        teardown_test
        echo "FAIL: verify_description_file should fail when file missing" >&2
        return 1
    fi
    teardown_test
}

test_verify_description_writable() {
    setup_test
    echo "Package: testpkg" > DESCRIPTION
    if ! verify_description_file "DESCRIPTION" true 2>/dev/null; then
        teardown_test
        echo "FAIL: verify_description_file should succeed for writable file" >&2
        return 1
    fi
    teardown_test
}

##############################################################################
# TEST: format_r_package_vector
##############################################################################

test_format_r_package_vector_empty() {
    local result
    result=$(format_r_package_vector)
    assert_equals "c()" "$result" "Empty array should return c()"
}

test_format_r_package_vector_single() {
    local result
    result=$(format_r_package_vector "dplyr")
    assert_equals 'c("dplyr")' "$result" "Single package should format correctly"
}

test_format_r_package_vector_multiple() {
    local result
    result=$(format_r_package_vector "dplyr" "ggplot2" "tidyr")
    assert_equals 'c("dplyr", "ggplot2", "tidyr")' "$result" "Multiple packages should format correctly"
}

##############################################################################
# TEST: add_package_to_description
##############################################################################

test_add_package_to_description() {
    setup_test
    cat > DESCRIPTION << 'EOF'
Package: testpkg
Title: Test Package
Imports:
    dplyr,
    ggplot2
EOF
    export VERBOSITY_LEVEL=0
    add_package_to_description "tidyr" 2>/dev/null
    if ! grep -q "tidyr" DESCRIPTION; then
        teardown_test
        echo "FAIL: tidyr should be added to DESCRIPTION" >&2
        return 1
    fi
    teardown_test
}

test_add_package_no_duplicate() {
    setup_test
    cat > DESCRIPTION << 'EOF'
Package: testpkg
Title: Test Package
Imports:
    dplyr,
    ggplot2
EOF
    export VERBOSITY_LEVEL=0
    add_package_to_description "dplyr" 2>/dev/null
    local count
    count=$(grep -c "dplyr" DESCRIPTION || true)
    if [[ "$count" -gt 1 ]]; then
        teardown_test
        echo "FAIL: dplyr should not be duplicated" >&2
        return 1
    fi
    teardown_test
}

test_add_package_creates_imports() {
    setup_test
    cat > DESCRIPTION << 'EOF'
Package: testpkg
Title: Test Package
EOF
    export VERBOSITY_LEVEL=0
    add_package_to_description "dplyr" 2>/dev/null
    if ! grep -q "Imports:" DESCRIPTION; then
        teardown_test
        echo "FAIL: Imports section should be created" >&2
        return 1
    fi
    if ! grep -q "dplyr" DESCRIPTION; then
        teardown_test
        echo "FAIL: dplyr should be added" >&2
        return 1
    fi
    teardown_test
}

##############################################################################
# TEST: BASE_PACKAGES array
##############################################################################

test_base_packages_defined() {
    if [[ ${#BASE_PACKAGES[@]} -eq 0 ]]; then
        echo "FAIL: BASE_PACKAGES should be defined and non-empty" >&2
        return 1
    fi
}

test_base_packages_contains_base() {
    local found=false
    for pkg in "${BASE_PACKAGES[@]}"; do
        if [[ "$pkg" == "base" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" != "true" ]]; then
        echo "FAIL: BASE_PACKAGES should contain 'base'" >&2
        return 1
    fi
}

test_base_packages_contains_stats() {
    local found=false
    for pkg in "${BASE_PACKAGES[@]}"; do
        if [[ "$pkg" == "stats" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" != "true" ]]; then
        echo "FAIL: BASE_PACKAGES should contain 'stats'" >&2
        return 1
    fi
}

##############################################################################
# TEST: PLACEHOLDER_PACKAGES array
##############################################################################

test_placeholder_packages_defined() {
    if [[ ${#PLACEHOLDER_PACKAGES[@]} -eq 0 ]]; then
        echo "FAIL: PLACEHOLDER_PACKAGES should be defined and non-empty" >&2
        return 1
    fi
}

test_placeholder_packages_contains_test() {
    local found=false
    for pkg in "${PLACEHOLDER_PACKAGES[@]}"; do
        if [[ "$pkg" == "test" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" != "true" ]]; then
        echo "FAIL: PLACEHOLDER_PACKAGES should contain 'test'" >&2
        return 1
    fi
}

##############################################################################
# RUN TESTS
##############################################################################

echo "=========================================="
echo "VALIDATION MODULE TESTS"
echo "=========================================="

tests=(
    test_verify_description_exists
    test_verify_description_missing
    test_verify_description_writable
    test_format_r_package_vector_empty
    test_format_r_package_vector_single
    test_format_r_package_vector_multiple
    test_add_package_to_description
    test_add_package_no_duplicate
    test_add_package_creates_imports
    test_base_packages_defined
    test_base_packages_contains_base
    test_base_packages_contains_stats
    test_placeholder_packages_defined
    test_placeholder_packages_contains_test
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
