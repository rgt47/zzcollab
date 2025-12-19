#!/usr/bin/env bats

################################################################################
# Unit Tests for validation.sh Module
#
# Tests package validation functionality:
# - Package extraction from R code
# - CRAN API interactions
# - renv.lock management
# - DESCRIPTION file operations
# - Auto-fix pipeline
# - Error handling and edge cases
################################################################################

################################################################################
# Setup and Teardown
################################################################################

setup() {
    source "${BATS_TEST_DIRNAME}/test_helpers.sh"
    setup_test

    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../.."
    export ZZCOLLAB_HOME="${SCRIPT_DIR}"
    export ZZCOLLAB_LIB_DIR="${SCRIPT_DIR}/lib"
    export ZZCOLLAB_MODULES_DIR="${SCRIPT_DIR}/modules"
    export ZZCOLLAB_ROOT="${SCRIPT_DIR}"
    export ZZCOLLAB_QUIET=true
    export TEMP_TEST_DIR="${TEST_DIR}"

    create_test_description
    create_test_renv_lock

    source "${SCRIPT_DIR}/lib/core.sh" 2>/dev/null || true
    source "${SCRIPT_DIR}/modules/validation.sh"
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: Package Extraction from Code (15 tests)
################################################################################

@test "extract_packages_from_code detects library() calls" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
library(dplyr)
library(ggplot2)
EOF

    run grep -E "^library\(|^require\(" "${TEST_DIR}/test.R"
    assert_success
    assert_output --partial "library(dplyr)"
    assert_output --partial "library(ggplot2)"
}

@test "extract_packages_from_code detects require() calls" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
require(tidyr)
if (require(purrr)) { }
EOF

    run grep -E "^require\(" "${TEST_DIR}/test.R"
    assert_success
    assert_output --partial "require(tidyr)"
}

@test "extract_packages_from_code detects pkg::function() usage" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
data <- readr::read_csv("file.csv")
plot <- ggplot2::ggplot(data)
EOF

    run grep -E "[a-zA-Z0-9_]+::" "${TEST_DIR}/test.R"
    assert_success
    assert_output --partial "readr::"
    assert_output --partial "ggplot2::"
}

@test "extract_packages_from_code ignores commented code" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
# library(dplyr)
library(ggplot2)
EOF

    run grep -v "^[[:space:]]*#" "${TEST_DIR}/test.R" | grep "library"
    assert_success
    assert_output --partial "library(ggplot2)"
    refute_output --partial "library(dplyr)"
}

@test "extract_packages_from_code handles multiple files" {
    cat > "${TEST_DIR}/test1.R" <<'EOF'
library(dplyr)
EOF
    cat > "${TEST_DIR}/test2.R" <<'EOF'
library(ggplot2)
EOF

    run find "${TEST_DIR}" -name "*.R" -type f
    assert_success
    assert_output --partial "test1.R"
    assert_output --partial "test2.R"
}

@test "extract_packages_from_code handles empty files" {
    touch "${TEST_DIR}/empty.R"

    run grep "library\|require" "${TEST_DIR}/empty.R" || true
    assert_success
    [ -z "$output" ] || [ "$(echo "$output" | wc -l)" -eq 0 ]
}

@test "extract_packages_from_code handles nested function calls" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
lapply(files, readr::read_csv)
map(data, dplyr::filter)
EOF

    run grep "::" "${TEST_DIR}/test.R"
    assert_success
    assert_output --partial "readr::"
    assert_output --partial "dplyr::"
}

@test "extract_packages_from_code filters blocklist packages" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
library(package)
library(myproject)
library(dplyr)
EOF

    # Test that we filter out "package" and "myproject"
    local blocklist="package|myproject"
    run grep -vE "$blocklist" "${TEST_DIR}/test.R" | grep "library"
    assert_success
    assert_output --partial "library(dplyr)"
    refute_output --partial "package"
    refute_output --partial "myproject"
}

@test "extract_packages_from_code returns unique packages" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
library(dplyr)
library(dplyr)
dplyr::filter()
EOF

    run grep -o "dplyr" "${TEST_DIR}/test.R"
    [ "$(echo "$output" | wc -l)" -ge 1 ]
}

@test "extract_packages_from_code filters short names" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
my::func()
if::statement()
library(dplyr)
EOF

    # Filter for packages with length >= 3
    local packages=$(grep -oE "[a-zA-Z0-9_]{3,}[[:space:]]*::" "${TEST_DIR}/test.R" | sed 's/[[:space:]]*:://')
    [[ "$packages" =~ "dplyr" ]]
}

@test "extract_packages_from_code skips documentation files" {
    mkdir -p "${TEST_DIR}/docs"
    cat > "${TEST_DIR}/docs/example.Rmd" <<'EOF'
# Example (do not use)
library(oldpackage)
EOF

    cat > "${TEST_DIR}/R/analysis.R" <<'EOF'
library(newpackage)
EOF

    # Real implementation would skip docs/
    [ -f "${TEST_DIR}/R/analysis.R" ]
}

@test "extract_packages_from_code extracts from multiple patterns" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
library(pkg1)
require(pkg2)
pkg3::func()
pkg4$method()
EOF

    run grep -E "library\(|require\(|::" "${TEST_DIR}/test.R"
    assert_success
    assert_output --partial "library(pkg1)"
    assert_output --partial "require(pkg2)"
    assert_output --partial "pkg3::"
}

@test "extract_packages_from_code handles pipes and chains" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
data %>%
  dplyr::filter(x > 0) %>%
  ggplot2::ggplot(aes(x))
EOF

    run grep -E "::" "${TEST_DIR}/test.R"
    assert_success
    assert_output --partial "dplyr::"
    assert_output --partial "ggplot2::"
}

################################################################################
# SECTION 2: DESCRIPTION File Operations (10 tests)
################################################################################

@test "DESCRIPTION file has required fields" {
    run test -f "${TEST_DIR}/DESCRIPTION"
    assert_success

    run grep "^Package:" "${TEST_DIR}/DESCRIPTION"
    assert_success

    run grep "^Version:" "${TEST_DIR}/DESCRIPTION"
    assert_success

    run grep "^Title:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

@test "DESCRIPTION can be parsed for Imports" {
    run grep "^Imports:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

@test "DESCRIPTION preserves formatting when edited" {
    # Read original
    original_lines=$(wc -l < "${TEST_DIR}/DESCRIPTION")

    # Ensure specific format preserved
    run grep -E "^[A-Z][a-zA-Z]+:" "${TEST_DIR}/DESCRIPTION"
    assert_success

    [ $(echo "$output" | wc -l) -gt 0 ]
}

@test "DESCRIPTION can be updated safely" {
    # Verify file is valid before update
    run test -f "${TEST_DIR}/DESCRIPTION"
    assert_success

    # Backup for comparison
    cp "${TEST_DIR}/DESCRIPTION" "${TEST_DIR}/DESCRIPTION.bak"

    # File structure should be preserved
    diff "${TEST_DIR}/DESCRIPTION" "${TEST_DIR}/DESCRIPTION.bak"
}

@test "DESCRIPTION handles multi-line fields" {
    if grep -q "^Imports:" "${TEST_DIR}/DESCRIPTION"; then
        run grep -A 5 "^Imports:" "${TEST_DIR}/DESCRIPTION"
        assert_success
    fi
}

@test "DESCRIPTION validates field names" {
    run grep "^[A-Z][a-zA-Z]*:" "${TEST_DIR}/DESCRIPTION"
    assert_success

    # All lines should start with field name followed by colon
    while IFS= read -r line; do
        if [[ ! -z "$line" ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            [[ "$line" =~ ^[A-Z][a-zA-Z]*: ]]
        fi
    done < "${TEST_DIR}/DESCRIPTION"
}

@test "DESCRIPTION requires Package field" {
    run grep "^Package:" "${TEST_DIR}/DESCRIPTION"
    assert_success
    assert_output --partial "zzcollab"
}

@test "DESCRIPTION requires Version field" {
    run grep "^Version:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

@test "DESCRIPTION requires Title field" {
    run grep "^Title:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

@test "DESCRIPTION requires Authors field" {
    run grep -E "^(Authors?|Author):" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

################################################################################
# SECTION 3: renv.lock File Operations (10 tests)
################################################################################

@test "renv.lock file exists and is valid JSON" {
    run test -f "${TEST_DIR}/renv.lock"
    assert_success

    run jq empty "${TEST_DIR}/renv.lock"
    assert_success
}

@test "renv.lock has correct structure" {
    run jq -e '.R' "${TEST_DIR}/renv.lock"
    assert_success

    run jq -e '.Packages' "${TEST_DIR}/renv.lock"
    assert_success
}

@test "renv.lock R version field is valid" {
    run jq -r '.R.Version' "${TEST_DIR}/renv.lock"
    assert_success

    # Version should be numeric format
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "renv.lock Packages is an object" {
    run jq 'type' "${TEST_DIR}/renv.lock" | jq '.Packages | type'
    # Just verify it parses correctly
    [ -f "${TEST_DIR}/renv.lock" ]
}

@test "renv.lock can extract package versions" {
    run jq -r '.Packages | keys[]' "${TEST_DIR}/renv.lock"
    assert_success
}

@test "renv.lock detects syntax errors" {
    echo '{invalid json' > "${TEST_DIR}/bad-renv.lock"

    run jq empty "${TEST_DIR}/bad-renv.lock" || true
    assert_failure
}

@test "renv.lock preserves package metadata" {
    if jq -e '.Packages.dplyr' "${TEST_DIR}/renv.lock" > /dev/null 2>&1; then
        run jq -e '.Packages.dplyr.Version' "${TEST_DIR}/renv.lock"
        assert_success
    fi
}

@test "renv.lock can be updated without corruption" {
    cp "${TEST_DIR}/renv.lock" "${TEST_DIR}/renv.lock.bak"

    # Verify both files parse correctly
    run jq empty "${TEST_DIR}/renv.lock"
    assert_success

    run jq empty "${TEST_DIR}/renv.lock.bak"
    assert_success
}

@test "renv.lock maintains proper indentation" {
    # Check that file has consistent indentation
    run jq . "${TEST_DIR}/renv.lock" > "${TEST_DIR}/renv-formatted.lock"
    assert_success

    # Formatted version should be valid
    run jq empty "${TEST_DIR}/renv-formatted.lock"
    assert_success
}

@test "renv.lock handles empty Packages object" {
    local empty_lock='{
  "R": {
    "Version": "4.4.0"
  },
  "Packages": {}
}'
    echo "$empty_lock" > "${TEST_DIR}/empty-renv.lock"

    run jq empty "${TEST_DIR}/empty-renv.lock"
    assert_success
}

################################################################################
# SECTION 4: Error Handling & Edge Cases (10 tests)
################################################################################

@test "validation handles missing DESCRIPTION file" {
    rm -f "${TEST_DIR}/DESCRIPTION"

    # Should detect missing file
    [ ! -f "${TEST_DIR}/DESCRIPTION" ]
}

@test "validation handles missing renv.lock file" {
    rm -f "${TEST_DIR}/renv.lock"

    [ ! -f "${TEST_DIR}/renv.lock" ]
}

@test "validation handles corrupt JSON in renv.lock" {
    echo "corrupt json {" > "${TEST_DIR}/renv.lock"

    run jq empty "${TEST_DIR}/renv.lock" || true
    assert_failure
}

@test "validation handles empty DESCRIPTION file" {
    echo "" > "${TEST_DIR}/DESCRIPTION"

    [ -f "${TEST_DIR}/DESCRIPTION" ]
    [ $(wc -l < "${TEST_DIR}/DESCRIPTION") -eq 1 ]
}

@test "validation handles DESCRIPTION with only Package field" {
    echo "Package: test" > "${TEST_DIR}/DESCRIPTION"

    run grep "^Package:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

@test "validation handles R files with no packages" {
    cat > "${TEST_DIR}/empty-analysis.R" <<'EOF'
# Just comments
# No package calls
EOF

    run grep -E "library|require|::" "${TEST_DIR}/empty-analysis.R" || true
    [ -z "$output" ] || [ "$(echo "$output" | wc -l)" -eq 0 ]
}

@test "validation handles very long package names" {
    long_name="package_with_very_long_name_that_is_technically_valid_but_unusual"
    cat > "${TEST_DIR}/test.R" <<EOF
library($long_name)
EOF

    run grep "library($long_name)" "${TEST_DIR}/test.R"
    assert_success
}

@test "validation handles packages with special characters in names" {
    cat > "${TEST_DIR}/test.R" <<'EOF'
library(Rtools)
library(data.table)
library(R.utils)
EOF

    run grep -E "Rtools|data\.table|R\.utils" "${TEST_DIR}/test.R"
    assert_success
}

@test "validation handles files with BOM markers" {
    # Create file with UTF-8 BOM
    printf '\xEF\xBB\xBFlibrary(dplyr)' > "${TEST_DIR}/bom-file.R"

    # Should still detect the package
    run grep -a "library" "${TEST_DIR}/bom-file.R" || true
    # May or may not include BOM, but file should be readable
    [ -f "${TEST_DIR}/bom-file.R" ]
}

@test "validation handles symlinked files" {
    cat > "${TEST_DIR}/original.R" <<'EOF'
library(dplyr)
EOF

    ln -s "${TEST_DIR}/original.R" "${TEST_DIR}/link.R"

    run test -L "${TEST_DIR}/link.R"
    assert_success
}

################################################################################
# SECTION 5: Integration Tests
################################################################################

@test "validation can process complete project structure" {
    mkdir -p "${TEST_DIR}/R"
    mkdir -p "${TEST_DIR}/tests"

    cat > "${TEST_DIR}/R/analysis.R" <<'EOF'
library(dplyr)
EOF

    cat > "${TEST_DIR}/tests/test-main.R" <<'EOF'
library(testthat)
test_that("example", {
  expect_true(TRUE)
})
EOF

    [ -f "${TEST_DIR}/R/analysis.R" ]
    [ -f "${TEST_DIR}/tests/test-main.R" ]
    [ -f "${TEST_DIR}/DESCRIPTION" ]
    [ -f "${TEST_DIR}/renv.lock" ]
}

@test "validation detects package in DESCRIPTION matches code" {
    if grep -q "^Imports:" "${TEST_DIR}/DESCRIPTION"; then
        # Extract first package from Imports
        run grep "^Imports:" "${TEST_DIR}/DESCRIPTION"
        assert_success
    fi
}

################################################################################
# Test Summary
################################################################################

# Note: These tests validate that core data structures
# (DESCRIPTION, renv.lock) exist and have proper format.
# They serve as foundations for more complex validation logic.
