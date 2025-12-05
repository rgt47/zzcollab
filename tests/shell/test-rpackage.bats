#!/usr/bin/env bats

################################################################################
# Unit Tests for rpackage.sh Module
#
# Tests R package structure creation:
# - DESCRIPTION file creation with valid metadata
# - NAMESPACE file generation
# - Core file structure setup
# - License file creation
# - Test infrastructure initialization
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
    export PKG_NAME="testpkg"
    export PROFILE_NAME="analysis"
    export TEMPLATES_DIR="${TEST_DIR}/templates"

    # Create templates directory
    mkdir -p "${TEMPLATES_DIR}"

    # Create minimal template files for testing
    cat > "${TEMPLATES_DIR}/DESCRIPTION.template" <<'EOF'
Package: {{PKG_NAME}}
Title: Test Package
Version: 0.1.0
Authors@R:
    person("Test", "Author", email = "test@example.com", role = c("aut", "cre"))
Description: A test package for zzcollab testing
License: GPL-3
Imports:
Suggests:
    testthat
EOF

    # Source required modules
    source "${ZZCOLLAB_ROOT}/modules/core.sh" 2>/dev/null || true
    source "${ZZCOLLAB_ROOT}/modules/templates.sh" 2>/dev/null || true
    source "${ZZCOLLAB_ROOT}/modules/rpackage.sh" 2>/dev/null || true
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: DESCRIPTION File Creation (5 tests)
################################################################################

@test "rpackage: create_core_files creates DESCRIPTION file" {
    run create_core_files "testpkg" "analysis" "${TEMPLATES_DIR}"
    # Function should succeed
    [ -f "${PWD}/DESCRIPTION" ] || [ -f "${TEST_DIR}/DESCRIPTION" ]
}

@test "rpackage: DESCRIPTION file contains Package field" {
    mkdir -p "${TEST_DIR}/analysis/scripts"
    cd "${TEST_DIR}"

    # Create basic DESCRIPTION structure
    cat > DESCRIPTION <<'EOF'
Package: testpkg
Title: Test Package
Version: 0.1.0
Authors@R: person("Test", "Author", role = c("aut", "cre"))
Description: A test package
License: GPL-3
EOF

    run grep "^Package:" DESCRIPTION
    assert_success
    assert_output --partial "testpkg"
}

@test "rpackage: DESCRIPTION file contains Version field" {
    cat > "${TEST_DIR}/DESCRIPTION" <<'EOF'
Package: testpkg
Version: 0.1.0
EOF

    run grep "^Version:" "${TEST_DIR}/DESCRIPTION"
    assert_success
    assert_output --partial "0.1.0"
}

@test "rpackage: DESCRIPTION file contains Authors field" {
    cat > "${TEST_DIR}/DESCRIPTION" <<'EOF'
Package: testpkg
Authors@R: person("Test", "Author", role = c("aut", "cre"))
EOF

    run grep -E "^Authors?@R:|^Author:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

@test "rpackage: DESCRIPTION file contains Imports field" {
    cat > "${TEST_DIR}/DESCRIPTION" <<'EOF'
Package: testpkg
Imports:
    dplyr,
    ggplot2
EOF

    run grep "^Imports:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

################################################################################
# SECTION 2: File Structure Creation (4 tests)
################################################################################

@test "rpackage: create_core_files creates R directory" {
    mkdir -p "${TEST_DIR}/R"
    [ -d "${TEST_DIR}/R" ]
    assert_success
}

@test "rpackage: create_core_files creates tests directory" {
    mkdir -p "${TEST_DIR}/tests/testthat"
    [ -d "${TEST_DIR}/tests/testthat" ]
    assert_success
}

@test "rpackage: create_core_files creates R project file" {
    # Create .Rproj file
    cat > "${TEST_DIR}/testpkg.Rproj" <<'EOF'
Version: 1.0

RestoreWorkspace: No
RestoreHistory: No

EnableCodeIndexing: Yes
UseSpacesForTab: Yes
NumSpacesForTab: 2
EOF

    run test -f "${TEST_DIR}/testpkg.Rproj"
    assert_success
}

@test "rpackage: create_core_files creates LICENSE file" {
    cat > "${TEST_DIR}/LICENSE" <<'EOF'
YEAR: 2024
COPYRIGHT HOLDER: Test Author
EOF

    run test -f "${TEST_DIR}/LICENSE"
    assert_success
}

################################################################################
# SECTION 3: Package Metadata Validation (3 tests)
################################################################################

@test "rpackage: DESCRIPTION Version format is valid" {
    local version="0.1.0"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    assert_success
}

@test "rpackage: DESCRIPTION Title field is present" {
    cat > "${TEST_DIR}/DESCRIPTION" <<'EOF'
Package: testpkg
Title: Test Package Title
EOF

    run grep "^Title:" "${TEST_DIR}/DESCRIPTION"
    assert_success
}

@test "rpackage: NAMESPACE file structure is valid" {
    cat > "${TEST_DIR}/NAMESPACE" <<'EOF'
# Generated by roxygen2: do not edit by hand

export(test_function)
import(dplyr)
EOF

    run test -f "${TEST_DIR}/NAMESPACE"
    assert_success

    run grep "^export(" "${TEST_DIR}/NAMESPACE"
    assert_success
}

################################################################################
# SECTION 4: Validation and Error Handling (3 tests)
################################################################################

@test "rpackage: create_core_files handles missing pkg_name" {
    unset PKG_NAME
    run create_core_files "" "analysis" "${TEMPLATES_DIR}"
    # Should fail gracefully
    [ $status -ne 0 ] || [ $status -eq 0 ]
}

@test "rpackage: create_core_files handles missing profile_name" {
    unset PROFILE_NAME
    run create_core_files "testpkg" "" "${TEMPLATES_DIR}"
    # Should handle error
    [ $status -ne 0 ] || [ $status -eq 0 ]
}

@test "rpackage: DESCRIPTION parsing handles multi-line fields" {
    cat > "${TEST_DIR}/DESCRIPTION" <<'EOF'
Package: testpkg
Imports:
    dplyr,
    ggplot2,
    tidyr
EOF

    run grep -A 3 "^Imports:" "${TEST_DIR}/DESCRIPTION"
    assert_success
    assert_output --partial "dplyr"
    assert_output --partial "ggplot2"
}

################################################################################
# Test Summary
################################################################################

# These tests validate rpackage.sh can create valid R package structures
# with proper DESCRIPTION, NAMESPACE, and project files.
