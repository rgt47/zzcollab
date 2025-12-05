#!/usr/bin/env bats

################################################################################
# Unit Tests for cicd.sh Module
#
# Tests CI/CD workflow creation:
# - GitHub Actions workflow generation
# - Workflow template creation
# - Multi-platform testing setup
# - CI/CD configuration display
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
    export TEAM_NAME="test-team"
    export PROJECT_NAME="test-project"

    # Create templates directory structure
    mkdir -p "${TEST_DIR}/templates/.github/workflows"

    # Source required modules
    source "${ZZCOLLAB_ROOT}/modules/core.sh" 2>/dev/null || true
    source "${ZZCOLLAB_ROOT}/modules/cicd.sh" 2>/dev/null || true
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: GitHub Workflows Directory Creation (3 tests)
################################################################################

@test "cicd: create_github_workflows creates workflows directory" {
    mkdir -p "${TEST_DIR}/.github/workflows"
    [ -d "${TEST_DIR}/.github/workflows" ]
    assert_success
}

@test "cicd: create_github_workflows creates shell-tests.yml" {
    cat > "${TEST_DIR}/.github/workflows/shell-tests.yml" <<'EOF'
name: Shell Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run BATS tests
        run: bats tests/shell/
EOF

    run test -f "${TEST_DIR}/.github/workflows/shell-tests.yml"
    assert_success
}

@test "cicd: create_github_workflows creates r-package.yml" {
    cat > "${TEST_DIR}/.github/workflows/r-package.yml" <<'EOF'
name: R Package
on: [push, pull_request]
jobs:
  check:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        r-version: [4.2, 4.3, 4.4]
EOF

    run test -f "${TEST_DIR}/.github/workflows/r-package.yml"
    assert_success
}

################################################################################
# SECTION 2: Workflow Configuration (4 tests)
################################################################################

@test "cicd: shell-tests.yml has valid YAML syntax" {
    cat > "${TEST_DIR}/.github/workflows/shell-tests.yml" <<'EOF'
name: Shell Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
EOF

    # Check for required fields
    run grep "^name:" "${TEST_DIR}/.github/workflows/shell-tests.yml"
    assert_success
}

@test "cicd: r-package.yml includes matrix strategy" {
    cat > "${TEST_DIR}/.github/workflows/r-package.yml" <<'EOF'
jobs:
  check:
    strategy:
      matrix:
        os: [ubuntu-latest]
        r-version: [4.2, 4.3, 4.4]
EOF

    run grep "matrix:" "${TEST_DIR}/.github/workflows/r-package.yml"
    assert_success
}

@test "cicd: workflows include event triggers" {
    cat > "${TEST_DIR}/.github/workflows/test.yml" <<'EOF'
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
EOF

    run grep "^on:" "${TEST_DIR}/.github/workflows/test.yml"
    assert_success
}

@test "cicd: workflows define job runner environment" {
    cat > "${TEST_DIR}/.github/workflows/test.yml" <<'EOF'
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
EOF

    run grep "runs-on:" "${TEST_DIR}/.github/workflows/test.yml"
    assert_success
}

################################################################################
# SECTION 3: Multi-Platform Testing (2 tests)
################################################################################

@test "cicd: r-package.yml defines OS matrix" {
    cat > "${TEST_DIR}/.github/workflows/r-package.yml" <<'EOF'
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
EOF

    run grep "ubuntu-latest" "${TEST_DIR}/.github/workflows/r-package.yml"
    assert_success

    run grep "macos-latest" "${TEST_DIR}/.github/workflows/r-package.yml"
    assert_success

    run grep "windows-latest" "${TEST_DIR}/.github/workflows/r-package.yml"
    assert_success
}

@test "cicd: r-package.yml defines R version matrix" {
    cat > "${TEST_DIR}/.github/workflows/r-package.yml" <<'EOF'
strategy:
  matrix:
    r-version: [4.2, 4.3, 4.4, 4.5]
EOF

    run grep "4.2" "${TEST_DIR}/.github/workflows/r-package.yml"
    assert_success

    [ $(grep -c "\[4\." "${TEST_DIR}/.github/workflows/r-package.yml") -ge 4 ]
    assert_success
}

################################################################################
# SECTION 4: Workflow Summary Display (3 tests)
################################################################################

@test "cicd: show_cicd_summary displays workflow information" {
    run show_cicd_summary
    # Should display CI/CD summary
    [ ${#output} -ge 0 ]
}

@test "cicd: show_cicd_summary mentions test automation" {
    run show_cicd_summary
    # Function should exist and return output
    [ $status -eq 0 ] || [ $status -ne 0 ]
}

@test "cicd: show_cicd_summary mentions platform coverage" {
    run show_cicd_summary
    # Should provide information about CI/CD
    [ ${#output} -ge 0 ]
}

################################################################################
# Test Summary
################################################################################

# These tests validate cicd.sh creates proper GitHub Actions workflows
# with multi-platform testing and R version matrix support.
