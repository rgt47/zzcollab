#!/bin/bash
##############################################################################
# ZZCOLLAB CONFIG MODULE TESTS
##############################################################################
# Tests for modules/config.sh - configuration management
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

load_module_for_testing "core.sh"
load_module_for_testing "config.sh"

##############################################################################
# TEST: validate_email
##############################################################################

test_validate_email_valid() {
  validate_email "user@example.com"
}

test_validate_email_valid_with_plus() {
  validate_email "user+tag@example.com"
}

test_validate_email_valid_subdomain() {
  validate_email "user@sub.domain.com"
}

test_validate_email_empty_ok() {
  validate_email ""
}

test_validate_email_invalid_no_at() {
  ! validate_email "userexample.com"
}

test_validate_email_invalid_no_domain() {
  ! validate_email "user@"
}

test_validate_email_invalid_no_tld() {
  ! validate_email "user@example"
}

##############################################################################
# TEST: validate_orcid
##############################################################################

test_validate_orcid_valid() {
  validate_orcid "0000-0002-1825-0097"
}

test_validate_orcid_valid_with_x() {
  validate_orcid "0000-0001-5109-361X"
}

test_validate_orcid_empty_ok() {
  validate_orcid ""
}

test_validate_orcid_invalid_short() {
  ! validate_orcid "0000-0002-1825"
}

test_validate_orcid_invalid_format() {
  ! validate_orcid "00000002182500097"
}

##############################################################################
# TEST: validate_positive_int
##############################################################################

test_validate_positive_int_valid() {
  validate_positive_int "42"
}

test_validate_positive_int_one() {
  validate_positive_int "1"
}

test_validate_positive_int_empty_ok() {
  validate_positive_int ""
}

test_validate_positive_int_zero_invalid() {
  ! validate_positive_int "0"
}

test_validate_positive_int_negative_invalid() {
  ! validate_positive_int "-1"
}

test_validate_positive_int_float_invalid() {
  ! validate_positive_int "3.14"
}

test_validate_positive_int_text_invalid() {
  ! validate_positive_int "abc"
}

##############################################################################
# TEST: config_set / config_get (requires yq)
##############################################################################

test_config_set_and_get() {
  if ! command -v yq &>/dev/null; then
    echo "SKIP: yq not available" >&2
    return 0
  fi

  setup_test
  export CONFIG_USER="$TEST_TEMP_DIR/config.yaml"
  export CONFIG_PROJECT="$TEST_TEMP_DIR/zzcollab.yaml"

  cat > "$CONFIG_USER" << 'EOF'
defaults:
  team_name: ""
author:
  name: ""
docker:
  default_profile: ""
EOF

  config_set "author-name" "Test User" >/dev/null 2>&1
  local result
  result=$(config_get "author-name")
  assert_equals "Test User" "$result" \
    "config_get should return value set by config_set"
  teardown_test
}

test_config_set_kebab_to_snake() {
  if ! command -v yq &>/dev/null; then
    echo "SKIP: yq not available" >&2
    return 0
  fi

  setup_test
  export CONFIG_USER="$TEST_TEMP_DIR/config.yaml"
  export CONFIG_PROJECT="$TEST_TEMP_DIR/zzcollab.yaml"

  cat > "$CONFIG_USER" << 'EOF'
defaults:
  team_name: ""
docker:
  default_profile: ""
EOF

  config_set "profile-name" "analysis" >/dev/null 2>&1
  local result
  result=$(config_get "profile-name")
  assert_equals "analysis" "$result" \
    "kebab-case keys should map correctly"
  teardown_test
}

test_config_key_mapping_author() {
  if ! command -v yq &>/dev/null; then
    echo "SKIP: yq not available" >&2
    return 0
  fi

  setup_test
  export CONFIG_USER="$TEST_TEMP_DIR/config.yaml"
  export CONFIG_PROJECT="$TEST_TEMP_DIR/zzcollab.yaml"

  cat > "$CONFIG_USER" << 'EOF'
author:
  email: ""
  orcid: ""
EOF

  config_set "author-email" "test@example.com" >/dev/null 2>&1
  local result
  result=$(yq '.author.email' "$CONFIG_USER")
  assert_equals "test@example.com" "$result" \
    "author-email should map to author.email yaml path"
  teardown_test
}

##############################################################################
# TEST: Config precedence - project overrides user (T-5)
##############################################################################

# The documented invariant: a project-level key overrides the same key in the
# user-level config. load_config loads user first, then project, so the last
# write wins. This test pins that contract.
test_project_config_overrides_user_config() {
  setup_test
  cd "$TEST_TEMP_DIR"

  # Write user-level config with one team name.
  local user_cfg="$TEST_TEMP_DIR/user-config.yaml"
  cat > "$user_cfg" << 'EOF'
defaults:
  team_name: user-team
EOF

  # Write project-level config with a different team name.
  local project_cfg="$TEST_TEMP_DIR/project-config.yaml"
  cat > "$project_cfg" << 'EOF'
defaults:
  team_name: project-team
EOF

  # Drive _load_file directly in precedence order (user then project).
  # CONFIG_* variables are reset first so the test is not polluted by prior state.
  CONFIG_TEAM_NAME=""
  _load_file "$user_cfg" 2>/dev/null || true
  _load_file "$project_cfg" 2>/dev/null || true

  assert_equals "project-team" "$CONFIG_TEAM_NAME" \
    "Project config must override user config for the same key"

  teardown_test
}

##############################################################################
# TEST: C-1 - profile_name get/load symmetry
##############################################################################

# config get profile_name must return the value written by the default template
# under defaults.profile_name, not the empty CONFIG_DOCKER_DEFAULT_PROFILE.
test_profile_name_get_is_symmetric_with_load() {
  setup_test
  cd "$TEST_TEMP_DIR"

  local cfg="$TEST_TEMP_DIR/zzcollab.yaml"
  cat > "$cfg" << 'EOF'
defaults:
  profile_name: analysis
EOF

  CONFIG_PROFILE_NAME=""
  CONFIG_DOCKER_DEFAULT_PROFILE=""
  _load_file "$cfg" 2>/dev/null || true

  assert_equals "analysis" "$CONFIG_DOCKER_DEFAULT_PROFILE" \
    "defaults.profile_name must populate CONFIG_DOCKER_DEFAULT_PROFILE (C-1)"
  teardown_test
}

##############################################################################
# TEST: C-3 - malformed config propagates error
##############################################################################

test_load_file_errors_on_malformed_yaml() {
  setup_test
  cd "$TEST_TEMP_DIR"

  local bad_cfg="$TEST_TEMP_DIR/bad.yaml"
  printf 'defaults:\n  team_name: [unclosed\n' > "$bad_cfg"

  local rc=0
  _load_file "$bad_cfg" 2>/dev/null || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: _load_file should return nonzero on malformed YAML" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

##############################################################################
# TEST: C-4 - yq version detection
##############################################################################

test_require_yq_succeeds_when_mikefarah_v4_present() {
  if ! command -v yq >/dev/null 2>&1; then
    echo "SKIP: yq not installed"
    return 0
  fi
  _YQ_AVAILABLE=""
  if ! _require_yq 2>/dev/null; then
    echo "FAIL: _require_yq should succeed when mikefarah yq v4 is installed" >&2
    return 1
  fi
}

##############################################################################
# TEST: C-5 - config set validates values
##############################################################################

test_config_set_rejects_bad_email() {
  setup_test
  cd "$TEST_TEMP_DIR"

  local cfg="$TEST_TEMP_DIR/user.yaml"
  printf 'author:\n  email: ""\n' > "$cfg"
  CONFIG_USER_OVERRIDE="$cfg"

  local rc=0
  ZZCOLLAB_CONFIG_USER="$cfg" config_set "author_email" "not-an-email" 2>/dev/null || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: config set should reject an invalid email" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

test_config_set_rejects_unknown_profile() {
  setup_test
  cd "$TEST_TEMP_DIR"

  local cfg="$TEST_TEMP_DIR/user.yaml"
  printf 'defaults:\n  profile_name: ""\n' > "$cfg"

  local rc=0
  ZZCOLLAB_CONFIG_USER="$cfg" config_set "profile_name" "shiny" 2>/dev/null || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: config set should reject unknown profile 'shiny'" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

test_config_set_accepts_valid_profile() {
  setup_test
  cd "$TEST_TEMP_DIR"

  local cfg="$TEST_TEMP_DIR/user.yaml"
  printf 'defaults:\n  profile_name: ""\n' > "$cfg"

  if ! ZZCOLLAB_CONFIG_USER="$cfg" config_set "profile_name" "analysis" 2>/dev/null; then
    echo "FAIL: config set should accept valid profile 'analysis'" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
