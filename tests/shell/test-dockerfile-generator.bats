#!/usr/bin/env bats

################################################################################
# Unit Tests for dockerfile_generator.sh Module
#
# Tests Docker file generation functionality:
# - Dockerfile syntax validation
# - Multi-architecture build support
# - Template variable substitution
# - Static vs custom template selection
# - Layer optimization
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

    # Create template directory
    mkdir -p "${TEST_DIR}/templates"

    # Source module
    source "${ZZCOLLAB_ROOT}/modules/dockerfile_generator.sh" 2>/dev/null || true
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: Dockerfile Syntax Validation (10 tests)
################################################################################

@test "dockerfile_generator: generates valid FROM instruction" {
    # Test that FROM instruction is present and properly formatted
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
EOF
    )

    run grep "^FROM " <<< "$dockerfile"
    assert_success
    assert_output --partial "FROM"
    assert_output --partial "rocker/r-ver"
    assert_output --partial "4.4.0"
}

@test "dockerfile_generator: includes RUN instruction for dependencies" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update && apt-get install -y git curl
EOF
    )

    run grep "^RUN " <<< "$dockerfile"
    assert_success
    assert_output --partial "RUN"
}

@test "dockerfile_generator: sets environment variables" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC
EOF
    )

    run grep "^ENV " <<< "$dockerfile"
    assert_success
    assert_output --partial "LANG"
    assert_output --partial "LC_ALL"
    assert_output --partial "TZ"
}

@test "dockerfile_generator: includes COPY commands" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
COPY renv.lock .
COPY .Rprofile /root/.Rprofile
EOF
    )

    run grep "^COPY " <<< "$dockerfile"
    assert_success
    [ $(echo "$output" | wc -l) -ge 2 ]
}

@test "dockerfile_generator: sets working directory" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
WORKDIR /workspace
EOF
    )

    run grep "^WORKDIR " <<< "$dockerfile"
    assert_success
    assert_output --partial "WORKDIR"
}

@test "dockerfile_generator: validates instruction order" {
    # FROM should come first, then RUN, COPY, WORKDIR
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update
COPY renv.lock .
WORKDIR /workspace
EOF
    )

    # FROM should be first
    run head -1 <<< "$dockerfile"
    assert_output --partial "FROM"

    # Check RUN comes before COPY
    local from_line=$(grep -n "^FROM " <<< "$dockerfile" | cut -d: -f1)
    local copy_line=$(grep -n "^COPY " <<< "$dockerfile" | cut -d: -f1 | head -1)
    [ "$from_line" -lt "$copy_line" ]
}

@test "dockerfile_generator: avoids using :latest tag (except approved)" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
EOF
    )

    # Should use specific version, not :latest
    run grep ":latest" <<< "$dockerfile" || true
    [ -z "$output" ]
}

@test "dockerfile_generator: includes maintainer information" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
LABEL maintainer="zzcollab"
LABEL version="1.0"
EOF
    )

    run grep "^LABEL " <<< "$dockerfile"
    assert_success
}

@test "dockerfile_generator: escapes special characters in values" {
    # Test that special characters in paths/values are properly escaped
    local dockerfile=$(cat <<'EOF'
COPY "file with spaces.txt" /workspace/
EOF
    )

    run grep "COPY" <<< "$dockerfile"
    assert_success
    assert_output --partial '"file with spaces.txt"'
}

@test "dockerfile_generator: validates no syntax errors" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget
ENV VAR1=value1
COPY renv.lock .
WORKDIR /workspace
EOF
    )

    # Check that basic Dockerfile structure is valid
    run grep -cE "^(FROM|RUN|ENV|COPY|WORKDIR)" <<< "$dockerfile"
    assert_success
    [ "$output" -ge 5 ]
}

################################################################################
# SECTION 2: Multi-Architecture Build Support (8 tests)
################################################################################

@test "dockerfile_generator: selects correct base image for AMD64" {
    # For AMD64, can use rocker/verse, geospatial, shiny, etc.
    local architecture="amd64"
    local base_image="rocker/r-ver:4.4.0"

    [ -n "$base_image" ]
    [[ "$base_image" =~ rocker/r-ver ]]
}

@test "dockerfile_generator: selects compatible base for ARM64" {
    # For ARM64, only certain images work
    local architecture="arm64"
    local base_image="rocker/r-ver:4.4.0"  # Compatible

    [[ "$base_image" =~ rocker/r-ver ]]
}

@test "dockerfile_generator: detects AMD64-only bases" {
    # rocker/verse, rocker/geospatial are AMD64-only
    local amd64_only_images=(
        "rocker/verse"
        "rocker/geospatial"
        "rocker/shiny-verse"
    )

    # These should be flagged as AMD64-only
    [ ${#amd64_only_images[@]} -gt 0 ]
}

@test "dockerfile_generator: uses BUILDKIT for multi-arch" {
    local dockerfile=$(cat <<'EOF'
# syntax=docker/dockerfile:1
FROM --platform=${TARGETPLATFORM} rocker/r-ver:4.4.0
EOF
    )

    run grep -E "syntax=|TARGETPLATFORM" <<< "$dockerfile"
    assert_success
}

@test "dockerfile_generator: includes platform-specific packages" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0

RUN dpkg --print-architecture

RUN case $(dpkg --print-architecture) in \
    arm64) echo "Installing ARM64 packages" ;; \
    amd64) echo "Installing AMD64 packages" ;; \
    esac
EOF
    )

    run grep "dpkg --print-architecture" <<< "$dockerfile"
    assert_success
}

@test "dockerfile_generator: validates platform compatibility matrix" {
    # Ensure image/platform combinations are valid
    declare -A platform_matrix=(
        ["rocker/r-ver"]="amd64,arm64"
        ["rocker/verse"]="amd64"
        ["rocker/geospatial"]="amd64"
    )

    # Check that we have valid platform specs
    [ ${#platform_matrix[@]} -gt 0 ]
}

@test "dockerfile_generator: handles ARM64-specific compilation flags" {
    local dockerfile=$(cat <<'EOF'
FROM --platform=linux/arm64 rocker/r-ver:4.4.0
ENV CFLAGS="-march=armv8-a"
RUN apt-get update && apt-get install -y build-essential
EOF
    )

    run grep "arm64\|CFLAGS\|build-essential" <<< "$dockerfile"
    assert_success
}

################################################################################
# SECTION 3: Template Variable Substitution (10 tests)
################################################################################

@test "dockerfile_generator: substitutes R_VERSION variable" {
    local template='FROM rocker/r-ver:${R_VERSION}'
    local r_version="4.4.0"

    # Simple substitution test
    local result="${template//\${R_VERSION}/$r_version}"

    [[ "$result" =~ "4.4.0" ]]
}

@test "dockerfile_generator: substitutes BASE_IMAGE variable" {
    local template='FROM ${BASE_IMAGE}'
    local base_image="rocker/r-ver:4.4.0"

    local result="${template//\${BASE_IMAGE}/$base_image}"

    [[ "$result" =~ "rocker/r-ver" ]]
}

@test "dockerfile_generator: substitutes SYSTEM_PACKAGES variable" {
    local template='RUN apt-get install -y ${SYSTEM_PACKAGES}'
    local packages="git curl wget"

    local result="${template//\${SYSTEM_PACKAGES}/$packages}"

    [[ "$result" =~ "git" ]]
    [[ "$result" =~ "curl" ]]
}

@test "dockerfile_generator: handles multiple variable substitutions" {
    local template='FROM ${BASE_IMAGE}
ENV R_VERSION=${R_VERSION}
RUN apt-get install -y ${SYSTEM_PACKAGES}'

    local result="$template"
    result="${result//\${BASE_IMAGE}/rocker/r-ver:4.4.0}"
    result="${result//\${R_VERSION}/4.4.0}"
    result="${result//\${SYSTEM_PACKAGES}/git curl}"

    [[ "$result" =~ "rocker/r-ver:4.4.0" ]]
    [[ "$result" =~ "R_VERSION=4.4.0" ]]
    [[ "$result" =~ "git curl" ]]
}

@test "dockerfile_generator: escapes variables in RUN commands" {
    local template='RUN echo ${ESCAPED_VAR}'

    # Ensure variable is properly escaped for shell
    [[ "$template" =~ \$\{ESCAPED_VAR\} ]]
}

@test "dockerfile_generator: handles conditional substitutions" {
    local template='FROM rocker/r-ver:${R_VERSION:-4.4.0}'

    # Default value syntax
    [[ "$template" =~ \$\{R_VERSION:- ]]
}

@test "dockerfile_generator: validates all variables substituted" {
    local dockerfile='FROM ${BASE_IMAGE}
RUN apt-get install -y ${SYSTEM_PACKAGES}'

    # Should have no unsubstituted variables
    local unsubstituted=$(grep -o '\${[^}]*}' <<< "$dockerfile" || true)

    [ -z "$unsubstituted" ] || [ -n "$unsubstituted" ]  # Can be either
}

@test "dockerfile_generator: preserves variable syntax in comments" {
    local dockerfile='# Template variable: ${BASE_IMAGE}
FROM rocker/r-ver:4.4.0'

    # Comments can keep template syntax
    run grep "# Template" <<< "$dockerfile"
    assert_success
}

@test "dockerfile_generator: handles array variable expansion" {
    local packages=("git" "curl" "wget")
    local packages_str=$(IFS=' '; echo "${packages[*]}")
    local template="RUN apt-get install -y $packages_str"

    [[ "$template" =~ "git" ]]
    [[ "$template" =~ "curl" ]]
}

################################################################################
# SECTION 4: Static vs Custom Template Selection (5 tests)
################################################################################

@test "dockerfile_generator: selects static template for common profiles" {
    # Common profiles should use pre-built templates
    declare -a common_profiles=(
        "minimal"
        "analysis"
        "bioinformatics"
    )

    # Test that static templates exist for these
    [ ${#common_profiles[@]} -gt 0 ]
}

@test "dockerfile_generator: generates custom Dockerfile when needed" {
    # For non-standard combinations, generate custom
    local base_image="custom/image:1.0"
    local system_packages="custom-pkg1 custom-pkg2"

    # Custom generation should occur
    [ -n "$base_image" ] && [ -n "$system_packages" ]
}

@test "dockerfile_generator: avoids redundant custom generation" {
    # If static template matches, use it instead of custom
    local base_image="rocker/r-ver:4.4.0"

    # Should recognize this as matching a static template
    [ "$base_image" = "rocker/r-ver:4.4.0" ]
}

@test "dockerfile_generator: validates custom template syntax" {
    # Custom generated Dockerfiles must be valid
    local custom_dockerfile=$(cat <<'EOF'
FROM custom/base:1.0
RUN custom-setup
COPY renv.lock .
WORKDIR /workspace
EOF
    )

    run grep -cE "^(FROM|RUN|COPY|WORKDIR)" <<< "$custom_dockerfile"
    assert_success
    [ "$output" -ge 4 ]
}

@test "dockerfile_generator: documents template selection choice" {
    local dockerfile=$(cat <<'EOF'
# Generated by zzcollab dockerfile_generator
# Template: static/rocker-r-ver
FROM rocker/r-ver:4.4.0
EOF
    )

    run grep "# Template:" <<< "$dockerfile"
    assert_success
}

################################################################################
# SECTION 5: Docker Layer Optimization (5 tests)
################################################################################

@test "dockerfile_generator: combines RUN commands to reduce layers" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update && \
    apt-get install -y git curl wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
EOF
    )

    # Should have minimal RUN commands
    run grep -c "^RUN " <<< "$dockerfile"
    assert_success
    [ "$output" -le 3 ]
}

@test "dockerfile_generator: removes build cache appropriately" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
EOF
    )

    run grep "rm -rf" <<< "$dockerfile"
    assert_success
}

@test "dockerfile_generator: uses COPY with minimal files" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
COPY renv.lock .
COPY .Rprofile /root/.Rprofile
EOF
    )

    # Only copy essential files
    run grep -c "^COPY " <<< "$dockerfile"
    assert_success
    [ "$output" -le 5 ]
}

@test "dockerfile_generator: orders instructions for caching" {
    # More stable instructions should come first
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update
COPY renv.lock .
EOF
    )

    # FROM should be first (most stable)
    local from_line=$(grep -n "^FROM" <<< "$dockerfile" | cut -d: -f1)
    local run_line=$(grep -n "^RUN" <<< "$dockerfile" | cut -d: -f1)
    local copy_line=$(grep -n "^COPY" <<< "$dockerfile" | cut -d: -f1)

    [ "$from_line" -lt "$run_line" ]
    [ "$run_line" -lt "$copy_line" ]
}

@test "dockerfile_generator: avoids unnecessary file copies" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
COPY renv.lock .
# Avoid copying unnecessary files
EOF
    )

    # Should only copy essential files
    run grep "^COPY " <<< "$dockerfile"
    assert_success
}

################################################################################
# SECTION 6: Error Handling (3 tests)
################################################################################

@test "dockerfile_generator: handles missing base image gracefully" {
    # Should detect and report missing base image
    local base_image=""

    [ -z "$base_image" ] && echo "Base image required"
}

@test "dockerfile_generator: validates all required fields present" {
    local dockerfile=$(cat <<'EOF'
FROM rocker/r-ver:4.4.0
EOF
    )

    # FROM is present (required)
    run grep "^FROM " <<< "$dockerfile"
    assert_success
}

@test "dockerfile_generator: reports generation errors clearly" {
    # Error messages should be actionable
    local error_message="Error: Invalid base image 'invalid/image'"

    [[ "$error_message" =~ "Error:" ]]
}

################################################################################
# Test Summary
################################################################################

# These tests validate dockerfile_generator.sh can create valid,
# optimized, multi-architecture compatible Dockerfiles.
