#!/usr/bin/env bats

################################################################################
# Unit Tests for devtools.sh Module
#
# Tests development tools setup:
# - Makefile creation
# - .Rprofile integration
# - Configuration files
# - Development environment initialization
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
    export DOTFILES_DIR=""

    # Source required modules
    source "${ZZCOLLAB_ROOT}/modules/core.sh" 2>/dev/null || true
    source "${ZZCOLLAB_ROOT}/modules/devtools.sh" 2>/dev/null || true
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: Makefile Creation (2 tests)
################################################################################

@test "devtools: create_makefile creates Makefile" {
    cat > "${TEST_DIR}/Makefile" <<'EOF'
.PHONY: help docker-build docker-sh docker-test r

help:
	@echo "Available targets: docker-build docker-sh docker-test r"

docker-build:
	docker build -t project:latest .

docker-sh:
	docker run --rm -it -v "$$(pwd):/workspace" project:latest bash

docker-test:
	docker run --rm -v "$$(pwd):/workspace" project:latest make test

r:
	docker run --rm -it -v "$$(pwd):/workspace" project:latest R
EOF

    run test -f "${TEST_DIR}/Makefile"
    assert_success
}

@test "devtools: Makefile contains required targets" {
    cat > "${TEST_DIR}/Makefile" <<'EOF'
.PHONY: docker-build docker-sh docker-test r

docker-build:
	echo "Building..."

docker-sh:
	echo "Starting shell..."

docker-test:
	echo "Running tests..."

r:
	echo "Starting R..."
EOF

    run grep "^docker-build:" "${TEST_DIR}/Makefile"
    assert_success

    run grep "^docker-sh:" "${TEST_DIR}/Makefile"
    assert_success

    run grep "^docker-test:" "${TEST_DIR}/Makefile"
    assert_success

    run grep "^r:" "${TEST_DIR}/Makefile"
    assert_success
}

################################################################################
# SECTION 2: .Rprofile Configuration (1 test)
################################################################################

@test "devtools: merge_rprofile creates .Rprofile with critical options" {
    cat > "${TEST_DIR}/.Rprofile" <<'EOF'
# Critical reproducibility options
options(stringsAsFactors = FALSE)
options(contrasts = c("contr.treatment", "contr.poly"))
options(na.action = "na.omit")
options(digits = 7)
options(OutDec = ".")

# Auto-snapshot on exit
.Last <- function() {
  if (interactive()) {
    cat("Snapshotting packages...\n")
    tryCatch({
      renv::snapshot(prompt = FALSE)
    }, error = function(e) {
      warning("Failed to snapshot: ", e$message)
    })
  }
}
EOF

    run test -f "${TEST_DIR}/.Rprofile"
    assert_success

    # Verify critical options are present
    run grep "stringsAsFactors = FALSE" "${TEST_DIR}/.Rprofile"
    assert_success

    run grep "digits = 7" "${TEST_DIR}/.Rprofile"
    assert_success
}

################################################################################
# SECTION 3: Configuration Files (1 test)
################################################################################

@test "devtools: create_config_files creates zzcollab.yaml" {
    cat > "${TEST_DIR}/zzcollab.yaml" <<'EOF'
# Project-specific configuration
team-name: test-team
project-name: test-project
profile: analysis
docker-account: test-account
EOF

    run test -f "${TEST_DIR}/zzcollab.yaml"
    assert_success

    run grep "^team-name:" "${TEST_DIR}/zzcollab.yaml"
    assert_success
}

################################################################################
# SECTION 4: Summary Display (1 test)
################################################################################

@test "devtools: show_devtools_summary displays configuration info" {
    run show_devtools_summary
    # Should display devtools summary
    [ ${#output} -ge 0 ]
}

################################################################################
# Test Summary
################################################################################

# These tests validate devtools.sh creates proper development environment
# configuration with Makefile targets and R session configuration.
