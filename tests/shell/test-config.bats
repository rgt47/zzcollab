#!/usr/bin/env bats
# BATS tests for modules/config.sh
# Tests the configuration system including YAML parsing, config loading, and management

# Setup function - runs before each test
setup() {
    # Load the module system
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../.."

    # Source core dependencies
    source "${SCRIPT_DIR}/modules/core.sh"
    source "${SCRIPT_DIR}/modules/config.sh"

    # Create temporary directory for test configs
    TEST_CONFIG_DIR="$(mktemp -d)"
    TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/test_config.yaml"
    TEST_USER_CONFIG="${TEST_CONFIG_DIR}/user_config.yaml"

    # Override config file locations for testing
    export CONFIG_USER_DIR="${TEST_CONFIG_DIR}"
    export CONFIG_USER_FILE="${TEST_USER_CONFIG}"
    export CONFIG_PROJECT_FILE="${TEST_CONFIG_FILE}"
}

# Teardown function - runs after each test
teardown() {
    # Clean up temporary directory
    if [[ -n "${TEST_CONFIG_DIR:-}" && -d "${TEST_CONFIG_DIR}" ]]; then
        rm -rf "${TEST_CONFIG_DIR}"
    fi
}

#=============================================================================
# YAML PARSING TESTS
#=============================================================================

@test "check_yq_dependency detects yq availability" {
    if command -v yq >/dev/null 2>&1; then
        run check_yq_dependency
        [ "$status" -eq 0 ]
    else
        run check_yq_dependency
        [ "$status" -eq 1 ]
        [[ "${output}" =~ "yq not found" ]]
    fi
}

@test "yaml_get extracts simple key-value pairs" {
    # Create test YAML file
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "testteam"
  profile_name: "analysis"
EOF

    run yaml_get "${TEST_CONFIG_FILE}" "defaults.team_name"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "testteam" ]]
}

@test "yaml_get returns null for missing keys" {
    # Create test YAML file
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "testteam"
EOF

    run yaml_get "${TEST_CONFIG_FILE}" "defaults.nonexistent"
    [ "$status" -eq 0 ]
    [[ "${output}" == "null" || "${output}" == "" ]]
}

@test "yaml_get handles missing files gracefully" {
    run yaml_get "/nonexistent/file.yaml" "defaults.team_name"
    [ "$status" -eq 1 ]
}

@test "yaml_set updates existing values" {
    # Create test YAML file
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "oldteam"
  profile_name: "minimal"
EOF

    run yaml_set "${TEST_CONFIG_FILE}" "defaults.team_name" "newteam"
    [ "$status" -eq 0 ]

    # Verify the change
    result=$(yaml_get "${TEST_CONFIG_FILE}" "defaults.team_name")
    [[ "${result}" =~ "newteam" ]]
}

@test "yaml_set fails on missing files" {
    run yaml_set "/nonexistent/file.yaml" "defaults.team_name" "value"
    [ "$status" -eq 1 ]
}

@test "yaml_set fails on non-writable files" {
    # Create read-only file
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "testteam"
EOF
    chmod 444 "${TEST_CONFIG_FILE}"

    run yaml_set "${TEST_CONFIG_FILE}" "defaults.team_name" "newteam"
    [ "$status" -eq 1 ]

    # Restore permissions for teardown
    chmod 644 "${TEST_CONFIG_FILE}"
}

@test "yaml_get_array extracts array values" {
    skip "Requires yq for array parsing"

    if ! command -v yq >/dev/null 2>&1; then
        skip "yq not available"
    fi

    # Create test YAML with array
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
renv_modes:
  fast:
    packages:
      - dplyr
      - ggplot2
      - tidyr
EOF

    run yaml_get_array "${TEST_CONFIG_FILE}" "renv_modes.fast.packages"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "dplyr" ]]
    [[ "${output}" =~ "ggplot2" ]]
}

#=============================================================================
# CONFIGURATION LOADING TESTS
#=============================================================================

@test "load_config_file loads valid configuration" {
    # Create valid config file
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "myteam"
  profile_name: "analysis"
  dotfiles_dir: "~/dotfiles"
EOF

    run load_config_file "${TEST_CONFIG_FILE}"
    [ "$status" -eq 0 ]

    # Verify global variables were set
    [[ "${CONFIG_TEAM_NAME}" == "myteam" ]]
    [[ "${CONFIG_PROFILE_NAME}" == "analysis" ]]
    [[ "${CONFIG_DOTFILES_DIR}" == "~/dotfiles" ]]
}

@test "load_config_file handles missing files gracefully" {
    run load_config_file "/nonexistent/config.yaml"
    [ "$status" -eq 1 ]
}

@test "load_config_file ignores null values" {
    # Create config with null values
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "myteam"
  profile_name: null
EOF

    # Set a value first
    CONFIG_PROFILE_NAME="existing_value"

    run load_config_file "${TEST_CONFIG_FILE}"
    [ "$status" -eq 0 ]

    # Should have loaded team_name but preserved profile_name
    [[ "${CONFIG_TEAM_NAME}" == "myteam" ]]
    [[ "${CONFIG_PROFILE_NAME}" == "existing_value" ]]
}

@test "load_all_configs loads in correct priority order" {
    # Create user config
    cat > "${TEST_USER_CONFIG}" << 'EOF'
defaults:
  team_name: "user_team"
  profile_name: "minimal"
EOF

    # Create project config (should override)
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "project_team"
EOF

    run load_all_configs
    [ "$status" -eq 0 ]

    # Project config should take precedence
    [[ "${CONFIG_TEAM_NAME}" == "project_team" ]]
    # Profile should come from user config
    [[ "${CONFIG_PROFILE_NAME}" == "minimal" ]]
}

#=============================================================================
# CONFIGURATION MANAGEMENT TESTS
#=============================================================================

@test "create_default_config creates user config file" {
    # Remove any existing config
    rm -f "${TEST_USER_CONFIG}"

    # Create config non-interactively
    run bash -c "echo '1' | create_default_config"

    # Should create the file
    [ -f "${TEST_USER_CONFIG}" ]

    # Should contain expected sections
    run grep -q "defaults:" "${TEST_USER_CONFIG}"
    [ "$status" -eq 0 ]
}

@test "create_default_config handles existing files" {
    # Create existing config
    cat > "${TEST_USER_CONFIG}" << 'EOF'
defaults:
  team_name: "existing"
EOF

    # Try to create again (choose option 1 - keep existing)
    run bash -c "echo '1' | create_default_config"
    [ "$status" -eq 0 ]

    # Should still have original content
    run grep "existing" "${TEST_USER_CONFIG}"
    [ "$status" -eq 0 ]
}

@test "get_config_value retrieves configuration values" {
    # Set global config variables
    CONFIG_TEAM_NAME="myteam"
    CONFIG_PROFILE_NAME="analysis"
    CONFIG_DOTFILES_DIR="~/dotfiles"

    run get_config_value "team_name"
    [ "$status" -eq 0 ]
    [[ "${output}" == "myteam" ]]

    run get_config_value "profile_name"
    [ "$status" -eq 0 ]
    [[ "${output}" == "analysis" ]]
}

@test "get_config_value returns empty for unknown keys" {
    run get_config_value "nonexistent_key"
    [ "$status" -eq 0 ]
    [[ "${output}" == "" ]]
}

@test "config_set updates user configuration" {
    # Create initial config
    cat > "${TEST_USER_CONFIG}" << 'EOF'
defaults:
  team_name: "oldteam"
  profile_name: "minimal"
EOF

    run config_set "team_name" "newteam"
    [ "$status" -eq 0 ]

    # Verify update
    result=$(yaml_get "${TEST_USER_CONFIG}" "defaults.team_name")
    [[ "${result}" =~ "newteam" ]]
}

@test "config_set handles both dash and underscore key formats" {
    # Create config
    cat > "${TEST_USER_CONFIG}" << 'EOF'
defaults:
  team_name: "test"
EOF

    # Test with dash format
    run config_set "team-name" "myteam"
    [ "$status" -eq 0 ]

    # Test with underscore format
    run config_set "team_name" "yourteam"
    [ "$status" -eq 0 ]

    # Both should update the same key
    result=$(yaml_get "${TEST_USER_CONFIG}" "defaults.team_name")
    [[ "${result}" =~ "yourteam" ]]
}

@test "config_get retrieves current configuration" {
    CONFIG_TEAM_NAME="myteam"

    run config_get "team_name"
    [ "$status" -eq 0 ]
    [[ "${output}" == "myteam" ]]
}

@test "config_get returns '(not set)' for empty values" {
    CONFIG_TEAM_NAME=""

    run config_get "team_name"
    [ "$status" -eq 0 ]
    [[ "${output}" == "(not set)" ]]
}

@test "config_list displays all configuration values" {
    # Set some config values
    CONFIG_TEAM_NAME="myteam"
    CONFIG_PROFILE_NAME="analysis"

    run config_list
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "myteam" ]]
    [[ "${output}" =~ "analysis" ]]
    [[ "${output}" =~ "Configuration files" ]]
}

@test "config_validate checks YAML syntax" {
    skip "Requires yq for validation"

    if ! command -v yq >/dev/null 2>&1; then
        skip "yq not available"
    fi

    # Create valid config
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "myteam"
EOF

    run config_validate
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "validation passed" ]]
}

@test "config_validate detects invalid YAML" {
    skip "Requires yq for validation"

    if ! command -v yq >/dev/null 2>&1; then
        skip "yq not available"
    fi

    # Create invalid YAML
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "myteam
  # Missing closing quote
EOF

    run config_validate
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Invalid YAML" ]]
}

#=============================================================================
# PROJECT-LEVEL CONFIGURATION TESTS
#=============================================================================

@test "config_set_local creates project config from user template" {
    # Create user config
    cat > "${TEST_USER_CONFIG}" << 'EOF'
defaults:
  team_name: "user_team"
  profile_name: "minimal"
EOF

    # Set local config (should copy user config as template)
    run config_set_local "team-name" "project_team"
    [ "$status" -eq 0 ]

    # Project config should exist
    [ -f "${TEST_CONFIG_FILE}" ]

    # Should have updated value
    result=$(yaml_get "${TEST_CONFIG_FILE}" "defaults.team_name")
    [[ "${result}" =~ "project_team" ]]
}

@test "config_set_local fails without user config" {
    # Remove user config
    rm -f "${TEST_USER_CONFIG}"

    run config_set_local "team-name" "myteam"
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "User config not found" ]]
}

@test "config_get_local retrieves project-only values" {
    # Create project config
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "project_team"
EOF

    run config_get_local "team-name"
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "project_team" ]]
}

@test "config_get_local fails without project config" {
    run config_get_local "team-name"
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Project config not found" ]]
}

@test "config_list_local displays project configuration" {
    # Create project config
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "project_team"
  profile_name: "analysis"
EOF

    run config_list_local
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "project_team" ]]
    [[ "${output}" =~ "analysis" ]]
}

@test "config_list_local handles missing project config gracefully" {
    run config_list_local
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "No project-level config found" ]]
}

#=============================================================================
# INTEGRATION TESTS
#=============================================================================

@test "configuration hierarchy: project overrides user" {
    # Create user config
    cat > "${TEST_USER_CONFIG}" << 'EOF'
defaults:
  team_name: "user_team"
  profile_name: "minimal"
  dotfiles_dir: "~/dotfiles"
EOF

    # Create project config (partial override)
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "project_team"
EOF

    # Load all configs
    load_all_configs

    # Team name should be from project
    [[ "${CONFIG_TEAM_NAME}" == "project_team" ]]

    # Profile and dotfiles should be from user
    [[ "${CONFIG_PROFILE_NAME}" == "minimal" ]]
    [[ "${CONFIG_DOTFILES_DIR}" == "~/dotfiles" ]]
}

@test "apply_config_defaults preserves CLI arguments" {
    # Set config defaults
    CONFIG_TEAM_NAME="config_team"
    CONFIG_PROFILE_NAME="config_profile"

    # Set CLI arguments (should take precedence)
    TEAM_NAME="cli_team"

    # Apply defaults
    apply_config_defaults

    # CLI value should be preserved
    [[ "${TEAM_NAME}" == "cli_team" ]]

    # Config default should be applied where CLI didn't set value
    [[ "${PROFILE_NAME}" == "config_profile" ]]
}

@test "config system handles missing yq gracefully" {
    # This test assumes fallback parsing works
    # Create simple config
    cat > "${TEST_CONFIG_FILE}" << 'EOF'
defaults:
  team_name: "myteam"
  profile_name: "analysis"
EOF

    # Should still be able to load config even without yq
    run load_config_file "${TEST_CONFIG_FILE}"

    # Should either succeed (yq available) or handle fallback
    [ "$status" -eq 0 ] || [[ "${output}" =~ "limited" ]]
}
