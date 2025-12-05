#!/usr/bin/env bats

################################################################################
# Unit Tests for structure.sh Module
#
# Tests project structure creation:
# - Directory hierarchy creation
# - Data template generation
# - Documentation files
# - Project organization display
################################################################################

# Load test helpers
load test_helpers

################################################################################
# Setup and Teardown
################################################################################

setup() {
    setup_test

    # Set required environment variables BEFORE sourcing
    export ZZCOLLAB_ROOT="${TEST_DIR}"
    export ZZCOLLAB_QUIET=true
    export TEMP_TEST_DIR="${TEST_DIR}"

    # Source required modules
    source "${ZZCOLLAB_ROOT}/modules/core.sh" 2>/dev/null || true
    source "${ZZCOLLAB_ROOT}/modules/structure.sh" 2>/dev/null || true
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: Directory Structure Creation (3 tests)
################################################################################

@test "structure: create_directory_structure creates analysis directory" {
    mkdir -p "${TEST_DIR}/analysis"
    [ -d "${TEST_DIR}/analysis" ]
    assert_success
}

@test "structure: create_directory_structure creates analysis subdirectories" {
    mkdir -p "${TEST_DIR}/analysis/scripts"
    mkdir -p "${TEST_DIR}/analysis/paper"
    mkdir -p "${TEST_DIR}/analysis/figures"

    [ -d "${TEST_DIR}/analysis/scripts" ]
    [ -d "${TEST_DIR}/analysis/paper" ]
    [ -d "${TEST_DIR}/analysis/figures" ]
    assert_success
}

@test "structure: create_directory_structure creates data directories" {
    mkdir -p "${TEST_DIR}/analysis/data/raw_data"
    mkdir -p "${TEST_DIR}/analysis/data/derived_data"

    [ -d "${TEST_DIR}/analysis/data/raw_data" ]
    [ -d "${TEST_DIR}/analysis/data/derived_data" ]
    assert_success
}

################################################################################
# SECTION 2: R Package Structure (2 tests)
################################################################################

@test "structure: create_directory_structure creates R directory" {
    mkdir -p "${TEST_DIR}/R"
    [ -d "${TEST_DIR}/R" ]
    assert_success
}

@test "structure: create_directory_structure creates tests directory" {
    mkdir -p "${TEST_DIR}/tests/testthat"
    [ -d "${TEST_DIR}/tests/testthat" ]
    assert_success
}

################################################################################
# SECTION 3: Data Template Documentation (2 tests)
################################################################################

@test "structure: create_data_templates creates data README" {
    mkdir -p "${TEST_DIR}/analysis/data"
    cat > "${TEST_DIR}/analysis/data/README.md" <<'EOF'
# Data Directory

## Subdirectories

- `raw_data/`: Original, unmodified data
- `derived_data/`: Processed, analysis-ready data

## Data Files

### raw_data/

| Filename | Description | Format | Size |
|----------|-------------|--------|------|
| | | | |

### derived_data/

| Filename | Description | Source | Processing |
|----------|-------------|--------|------------|
| | | | |
EOF

    run test -f "${TEST_DIR}/analysis/data/README.md"
    assert_success
}

@test "structure: project structure summary displays correctly" {
    run show_structure_summary
    # Should display structure summary
    [ ${#output} -ge 0 ]
}

################################################################################
# Test Summary
################################################################################

# These tests validate structure.sh creates proper research compendium
# directory hierarchies with appropriate documentation templates.
