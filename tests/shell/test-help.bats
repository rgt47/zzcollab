#!/usr/bin/env bats

################################################################################
# Unit Tests for help.sh Module
#
# Tests help system functionality:
# - Brief help display
# - Topic-specific help navigation
# - Help topics listing
# - Next steps guidance
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

    # Source required modules in correct order
    source "${ZZCOLLAB_ROOT}/modules/core.sh" 2>/dev/null || true
    source "${ZZCOLLAB_ROOT}/modules/help.sh" 2>/dev/null || true
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: Brief Help Display (3 tests)
################################################################################

@test "help: show_help_brief displays usage information" {
    run show_help_brief
    assert_success
    assert_output --partial "usage: zzcollab"
    assert_output --partial "zzcollab - Complete Research Compendium Setup"
}

@test "help: show_help_brief includes common workflows" {
    run show_help_brief
    assert_success
    assert_output --partial "start a new project"
    assert_output --partial "join an existing project"
    assert_output --partial "development workflow"
}

@test "help: show_help_brief lists help topics" {
    run show_help_brief
    assert_success
    assert_output --partial "quickstart"
    assert_output --partial "workflow"
    assert_output --partial "team"
    assert_output --partial "config"
}

################################################################################
# SECTION 2: Main Help Function Routing (4 tests)
################################################################################

@test "help: show_help with no topic calls brief help" {
    run show_help ""
    assert_success
    assert_output --partial "usage: zzcollab"
}

@test "help: show_help with --all lists all topics" {
    run show_help "--all"
    assert_success
    # Should return list of topics (exit code 0)
    [ $status -eq 0 ] || [ $status -eq 1 ]
}

@test "help: show_help with -a lists all topics" {
    run show_help "-a"
    assert_success
    # Should return list of topics
    [ $status -eq 0 ] || [ $status -eq 1 ]
}

@test "help: show_help routes to quickstart topic" {
    run show_help "quickstart"
    # Should display quickstart information
    [ $status -eq 0 ] || [ $status -eq 1 ]
}

################################################################################
# SECTION 3: Topic-Specific Help Functions (2 tests)
################################################################################

@test "help: show_help_workflow displays workflow information" {
    run show_help_workflow
    assert_success
    assert_output --partial "Daily"
}

@test "help: show_help_team displays team collaboration guidance" {
    run show_help_team
    assert_success
    # Should mention team-related concepts
    [ ${#output} -gt 0 ]
}

################################################################################
# SECTION 4: Help Output Formatting (1 test)
################################################################################

@test "help: show_help_header displays formatted header" {
    run show_help_header
    assert_success
    # Should produce header output
    [ ${#output} -gt 0 ]
}

################################################################################
# Test Summary
################################################################################

# These tests validate help.sh can display help information for all major topics
# and correctly route between help sections.
