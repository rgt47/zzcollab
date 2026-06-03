#!/bin/bash
##############################################################################
# ZZCOLLAB END-TO-END: SCAFFOLD → BUILD → RUN
##############################################################################
#
# Full pipeline test: scaffold a minimal project, build its Docker image,
# run R inside the container, and assert known outputs.
#
# Skipped when Docker is not available (SKIP_DOCKER_TESTS=1 or no daemon).
# Designed to catch regressions in the generated Dockerfile and .Rprofile
# that unit tests cannot reach (e.g. the renv::init-before-restore bug).
#
# Run individually:
#   bash tests/shell/test-scaffold-build-run.sh
#
# Run as part of CI with Docker available:
#   SKIP_DOCKER_TESTS=0 bash tests/shell/test-scaffold-build-run.sh
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

ZZCOLLAB_SH="$ZZCOLLAB_ROOT/zzcollab.sh"

##############################################################################
# Skip logic
##############################################################################

_docker_available() {
    command -v docker > /dev/null 2>&1 && docker ps > /dev/null 2>&1
}

_skip_if_no_docker() {
    if [[ "${SKIP_DOCKER_TESTS:-}" == "1" ]]; then
        echo "SKIP: SKIP_DOCKER_TESTS=1"
        return 1
    fi
    if ! _docker_available; then
        echo "SKIP: Docker not available"
        return 1
    fi
    return 0
}

##############################################################################
# TEST: scaffold → build → run
##############################################################################

test_scaffold_build_and_run_r() {
    _skip_if_no_docker || return 0

    setup_test
    cd "$TEST_TEMP_DIR"

    # --- 1. Scaffold with author identity pre-set ---
    ZZCOLLAB_ACCEPT_DEFAULTS=true \
    ZZCOLLAB_NO_BUILD=true \
      bash "$ZZCOLLAB_SH" minimal --yes --no-build > /dev/null 2>&1 || {
        echo "FAIL: scaffold exited non-zero" >&2
        teardown_test
        return 1
    }

    assert_file_exists "Dockerfile"   "Dockerfile must exist after scaffold"
    assert_file_exists "renv.lock"    "renv.lock must exist after scaffold"
    assert_file_exists "Makefile"     "Makefile must exist after scaffold"
    assert_file_exists "tooling.lock" "tooling.lock must exist after scaffold"
    assert_file_exists ".Rprofile"    ".Rprofile must exist after scaffold"

    # --- 2. Verify Dockerfile contains all remediation fixes ---
    if ! grep -q "RENV_PATHS_LIBRARY=/opt/renv/library" Dockerfile; then
        echo "FAIL: Dockerfile missing RENV_PATHS_LIBRARY fix" >&2
        teardown_test
        return 1
    fi
    if ! grep -q "ZZCOLLAB_AUTO_RESTORE=false" Dockerfile; then
        echo "FAIL: Dockerfile missing ZZCOLLAB_AUTO_RESTORE fix" >&2
        teardown_test
        return 1
    fi
    if ! grep -q "renv::init" Dockerfile; then
        echo "FAIL: Dockerfile missing renv::init before renv::restore" >&2
        teardown_test
        return 1
    fi
    if ! grep -q "sha256:" Dockerfile; then
        echo "FAIL: Dockerfile FROM line not digest-pinned" >&2
        teardown_test
        return 1
    fi

    # --- 3. Build the Docker image ---
    local image_name
    image_name="zzc-e2e-test-$$"
    docker build --platform linux/amd64 -t "$image_name" . > /dev/null 2>&1 || {
        echo "FAIL: docker build exited non-zero" >&2
        teardown_test
        return 1
    }

    # --- 4. Run assertions inside the container ---
    local output
    output=$(docker run --rm --platform linux/amd64 \
        -v "$(pwd)":/home/analyst/project \
        -v "$HOME/.cache/R/renv":/opt/renv/cache \
        -w /home/analyst/project \
        "$image_name" \
        Rscript -e '
            # Arithmetic: proves R is functional
            cat("arithmetic:", 2L + 2L, "\n")

            # Library path: proves R-1 fix is active
            lib <- Sys.getenv("RENV_PATHS_LIBRARY")
            cat("lib_path:", lib, "\n")

            # Auto-restore: proves R-1 fix is active
            cat("auto_restore:", Sys.getenv("ZZCOLLAB_AUTO_RESTORE"), "\n")

            # RNGkind: proves R-7 fix is active (set by .Rprofile)
            cat("rng_kind:", RNGkind()[1], "\n")

            # Library populated: proves renv::init+restore fix worked
            pkgs <- list.files(renv::paths$library())
            cat("library_populated:", length(pkgs) > 0, "\n")
        ' 2>/dev/null) || {
        echo "FAIL: container Rscript exited non-zero" >&2
        docker rmi "$image_name" > /dev/null 2>&1 || true
        teardown_test
        return 1
    }

    # Clean up the image before asserting so failures still clean up
    docker rmi "$image_name" > /dev/null 2>&1 || true

    local fail=0

    if ! echo "$output" | grep -q "arithmetic: 4"; then
        echo "FAIL: arithmetic check failed (expected '4')" >&2
        echo "  output: $output" >&2
        fail=1
    fi
    if ! echo "$output" | grep -q "lib_path: /opt/renv/library"; then
        echo "FAIL: RENV_PATHS_LIBRARY not /opt/renv/library" >&2
        echo "  output: $output" >&2
        fail=1
    fi
    if ! echo "$output" | grep -q "auto_restore: false"; then
        echo "FAIL: ZZCOLLAB_AUTO_RESTORE not false" >&2
        echo "  output: $output" >&2
        fail=1
    fi
    if ! echo "$output" | grep -q "rng_kind: Mersenne-Twister"; then
        echo "FAIL: RNGkind not Mersenne-Twister (R-7 fix missing)" >&2
        echo "  output: $output" >&2
        fail=1
    fi
    if ! echo "$output" | grep -q "library_populated: TRUE"; then
        echo "FAIL: baked library is empty (renv::init fix missing)" >&2
        echo "  output: $output" >&2
        fail=1
    fi

    teardown_test
    return $fail
}

##############################################################################
# TEST: scaffold structure is complete
##############################################################################

test_scaffold_produces_citation_and_devcontainer() {
    _skip_if_no_docker || return 0

    setup_test
    cd "$TEST_TEMP_DIR"

    ZZCOLLAB_ACCEPT_DEFAULTS=true \
    ZZCOLLAB_NO_BUILD=true \
      bash "$ZZCOLLAB_SH" minimal --yes --no-build > /dev/null 2>&1 || {
        echo "FAIL: scaffold exited non-zero" >&2
        teardown_test
        return 1
    }

    assert_file_exists "CITATION.cff"                  "CITATION.cff must be scaffolded"
    assert_file_exists ".devcontainer/devcontainer.json" "devcontainer.json must be scaffolded"
    assert_file_exists "tooling.lock"                  "tooling.lock must be scaffolded"

    # CITATION.cff must have been substituted (not raw template variables)
    if grep -q '\$PKG_NAME\|\$AUTHOR_NAME\|\$DATE' CITATION.cff 2>/dev/null; then
        echo "FAIL: CITATION.cff contains unsubstituted template variables" >&2
        teardown_test
        return 1
    fi

    teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
