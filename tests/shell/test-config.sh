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
# RUN ALL TESTS
##############################################################################

run_test_suite
