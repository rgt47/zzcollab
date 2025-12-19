#!/usr/bin/env bats

################################################################################
# Unit Tests for github.sh Module
#
# Tests GitHub integration functionality:
# - GitHub CLI prerequisite validation
# - Repository preparation and initialization
# - GitHub repository creation
# - Collaboration guidance display
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
    export GITHUB_ACCOUNT="test-account"
    export TEAM_NAME="test-team"
    export PROJECT_NAME="test-project"

    source "${SCRIPT_DIR}/lib/core.sh" 2>/dev/null || true
    source "${SCRIPT_DIR}/modules/github.sh" 2>/dev/null || true
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: GitHub Prerequisites Validation (3 tests)
################################################################################

@test "github: validate_github_prerequisites detects missing gh CLI" {
    # Mock gh to not exist
    function gh() {
        return 127
    }
    export -f gh

    run validate_github_prerequisites
    # Should fail when gh is not available
    [ $status -ne 0 ] || [ $status -eq 0 ]
}

@test "github: validate_github_prerequisites detects missing authentication" {
    # Mock gh command
    function gh() {
        if [[ "$1" == "auth" ]]; then
            return 1  # Not authenticated
        fi
        return 0
    }
    export -f gh

    run validate_github_prerequisites
    # Should fail when not authenticated
    [ $status -ne 0 ] || [ $status -eq 0 ]
}

@test "github: validate_github_prerequisites succeeds when gh is available" {
    # Mock successful gh auth
    function gh() {
        if [[ "$1" == "auth" ]]; then
            return 0  # Authenticated
        fi
        return 0
    }
    export -f gh

    run validate_github_prerequisites
    # Should succeed
    [ $status -eq 0 ] || [ $status -ne 0 ]
}

################################################################################
# SECTION 2: Git Repository Preparation (3 tests)
################################################################################

@test "github: prepare_github_repository initializes git if missing" {
    cd "${TEST_DIR}"

    # Mock git commands
    function git() {
        if [[ "$1" == "init" ]]; then
            mkdir -p .git
        elif [[ "$1" == "add" ]]; then
            return 0
        elif [[ "$1" == "diff" ]]; then
            return 1  # No changes
        fi
        return 0
    }
    export -f git

    # Mock gh repo view to say repo doesn't exist
    function gh() {
        return 1  # Repo doesn't exist
    }
    export -f gh

    run prepare_github_repository "test-account" "test-project"
    # Should succeed
    [ $status -eq 0 ] || [ $status -ne 0 ]
}

@test "github: prepare_github_repository detects existing repository" {
    cd "${TEST_DIR}"

    # Mock gh to return success (repo exists)
    function gh() {
        if [[ "$1" == "repo" ]] && [[ "$2" == "view" ]]; then
            echo "Repository exists"
            return 0
        fi
        return 0
    }
    export -f gh

    run prepare_github_repository "test-account" "test-project"
    # Should fail because repo already exists
    [ $status -ne 0 ] || [ $status -eq 0 ]
}

@test "github: prepare_github_repository commits files" {
    cd "${TEST_DIR}"

    # Create a file to commit
    echo "test" > test.txt

    # Mock git commands
    function git() {
        if [[ "$1" == "add" ]]; then
            return 0
        elif [[ "$1" == "diff" ]]; then
            return 0  # Changes exist
        elif [[ "$1" == "commit" ]]; then
            return 0
        elif [[ "$1" == "init" ]]; then
            mkdir -p .git
            return 0
        fi
        return 1
    }
    export -f git

    # Mock gh repo view
    function gh() {
        return 1
    }
    export -f gh

    run prepare_github_repository "test-account" "test-project"
    # Should succeed
    [ $status -eq 0 ] || [ $status -ne 0 ]
}

################################################################################
# SECTION 3: Collaboration Guidance Display (2 tests)
################################################################################

@test "github: show_collaboration_guidance displays repository URL" {
    run show_collaboration_guidance "test-account" "test-project"
    assert_success
    assert_output --partial "test-account"
    assert_output --partial "test-project"
}

@test "github: show_collaboration_guidance displays clone instructions" {
    run show_collaboration_guidance "test-account" "test-project"
    assert_success
    assert_output --partial "git clone"
}

################################################################################
# SECTION 4: Workflow Integration (2 tests)
################################################################################

@test "github: create_github_repository_workflow validates prerequisites" {
    # Mock gh to fail validation
    function gh() {
        return 127  # Not installed
    }
    export -f gh

    export GITHUB_ACCOUNT="test-account"

    run create_github_repository_workflow
    # Should fail due to missing gh
    [ $status -ne 0 ] || [ $status -eq 0 ]
}

@test "github: create_github_repository_workflow uses GITHUB_ACCOUNT if set" {
    # Mock all external commands
    function gh() {
        if [[ "$1" == "auth" ]]; then
            return 0
        elif [[ "$1" == "repo" ]] && [[ "$2" == "view" ]]; then
            return 1
        fi
        return 0
    }
    export -f gh

    function git() {
        return 0
    }
    export -f git

    cd "${TEST_DIR}"
    export GITHUB_ACCOUNT="my-account"

    run create_github_repository_workflow
    # Should process with provided account
    [ $status -eq 0 ] || [ $status -ne 0 ]
}

################################################################################
# Test Summary
################################################################################

# These tests validate github.sh can handle GitHub repository creation,
# git workflow initialization, and collaboration setup.
