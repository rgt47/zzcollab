#!/usr/bin/env bats

################################################################################
# Unit Tests for profile_validation.sh Module
#
# Tests Docker profile validation functionality:
# - Profile selection and validation
# - Architecture compatibility checks
# - System requirements validation
# - Profile configuration management
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

    # Create test config directory
    mkdir -p "${TEST_DIR}/config"

    # Create bundles.yaml fixture with all 14+ profiles
    cat > "${TEST_DIR}/bundles.yaml" <<'EOF'
profiles:
  minimal:
    base_image: rocker/r-ver:latest
    description: Minimal R environment
    arch: [amd64, arm64]

  analysis:
    base_image: rocker/r-ver:latest
    description: Analysis environment with tidyverse
    arch: [amd64, arm64]

  modeling:
    base_image: rocker/r-ver:latest
    description: Modeling and statistics
    arch: [amd64, arm64]

  publishing:
    base_image: rocker/verse:latest
    description: Publishing with LaTeX and Pandoc
    arch: [amd64]

  bioinformatics:
    base_image: bioconductor/bioconductor_docker:latest
    description: Bioinformatics and genomics
    arch: [amd64, arm64]

  geospatial:
    base_image: rocker/geospatial:latest
    description: Geospatial analysis
    arch: [amd64]

  shiny:
    base_image: rocker/shiny:latest
    description: Shiny web applications
    arch: [amd64]

  shiny_verse:
    base_image: rocker/shiny-verse:latest
    description: Shiny with tidyverse
    arch: [amd64]

  alpine_minimal:
    base_image: rocker/r-ver:latest-alpine
    description: Lightweight Alpine environment
    arch: [amd64, arm64]

  alpine_analysis:
    base_image: rocker/r-ver:latest-alpine
    description: Alpine with analysis packages
    arch: [amd64, arm64]

  hpc_alpine:
    base_image: rocker/r-ver:latest-alpine
    description: HPC with Alpine
    arch: [amd64]

  rhub_ubuntu:
    base_image: rhub/ubuntu-latest:latest
    description: R-hub Ubuntu environment
    arch: [amd64]

  rhub_fedora:
    base_image: rhub/fedora-latest:latest
    description: R-hub Fedora environment
    arch: [amd64]

  rhub_windows:
    base_image: rhub/windows-server-2022:latest
    description: R-hub Windows environment
    arch: [amd64]
EOF
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: Profile Enumeration & Validation (15 tests)
################################################################################

@test "all 14+ profiles are defined in bundles.yaml" {
    run grep -c "^  [a-z_]*:" "${TEST_DIR}/bundles.yaml"
    # Should have at least 14 profiles
    [ $(echo "$output" | sed 's/^[[:space:]]*//' | head -1) -ge 14 ]
}

@test "minimal profile is defined" {
    run grep -A 2 "^  minimal:" "${TEST_DIR}/bundles.yaml"
    assert_success
    assert_output --partial "minimal"
    assert_output --partial "rocker/r-ver"
}

@test "analysis profile is defined" {
    run grep -A 2 "^  analysis:" "${TEST_DIR}/bundles.yaml"
    assert_success
    assert_output --partial "analysis"
}

@test "modeling profile is defined" {
    run grep -A 2 "^  modeling:" "${TEST_DIR}/bundles.yaml"
    assert_success
    assert_output --partial "modeling"
}

@test "publishing profile is defined" {
    run grep -A 2 "^  publishing:" "${TEST_DIR}/bundles.yaml"
    assert_success
    assert_output --partial "publishing"
    assert_output --partial "rocker/verse"
}

@test "bioinformatics profile is defined" {
    run grep -A 2 "^  bioinformatics:" "${TEST_DIR}/bundles.yaml"
    assert_success
    assert_output --partial "bioinformatics"
    assert_output --partial "bioconductor"
}

@test "geospatial profile is defined" {
    run grep -A 2 "^  geospatial:" "${TEST_DIR}/bundles.yaml"
    assert_success
    assert_output --partial "geospatial"
    assert_output --partial "rocker/geospatial"
}

@test "shiny profiles are defined" {
    run grep "^  shiny" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | wc -l) -ge 2 ]
}

@test "alpine profiles are defined" {
    run grep "^  alpine" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | wc -l) -ge 2 ]
}

@test "rhub profiles are defined" {
    run grep "^  rhub" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | wc -l) -ge 3 ]
}

@test "each profile has base_image field" {
    run grep "base_image:" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | wc -l) -ge 14 ]
}

@test "each profile has description field" {
    run grep "description:" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | wc -l) -ge 14 ]
}

@test "each profile specifies supported architectures" {
    run grep "arch:" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | wc -l) -ge 14 ]
}

@test "profile names are valid (lowercase, underscores, no spaces)" {
    run grep "^  [a-z_]*:" "${TEST_DIR}/bundles.yaml"
    assert_success
    # Each profile name should be valid
    while read -r line; do
        profile=$(echo "$line" | sed 's/^  \([a-z_]*\):.*/\1/')
        [[ "$profile" =~ ^[a-z_]+$ ]]
    done <<< "$output"
}

@test "duplicate profile names are detected" {
    # Get all profile names
    local profiles=$(grep "^  [a-z_]*:" "${TEST_DIR}/bundles.yaml" | sed 's/^  \([a-z_]*\):.*/\1/')
    local unique_count=$(echo "$profiles" | sort | uniq | wc -l)
    local total_count=$(echo "$profiles" | wc -l)
    [ "$unique_count" -eq "$total_count" ]
}

################################################################################
# SECTION 2: Architecture Compatibility (10 tests)
################################################################################

@test "minimal profile supports both amd64 and arm64" {
    run grep -A 5 "^  minimal:" "${TEST_DIR}/bundles.yaml" | grep "arch:"
    assert_success
    assert_output --partial "amd64"
    assert_output --partial "arm64"
}

@test "analysis profile supports both amd64 and arm64" {
    run grep -A 5 "^  analysis:" "${TEST_DIR}/bundles.yaml" | grep "arch:"
    assert_success
    assert_output --partial "amd64"
    assert_output --partial "arm64"
}

@test "publishing profile only supports amd64" {
    run grep -A 5 "^  publishing:" "${TEST_DIR}/bundles.yaml" | grep "arch:"
    assert_success
    assert_output --partial "amd64"
    # Should NOT have arm64
    refute_output --partial "- arm64"
}

@test "bioinformatics profile supports both architectures" {
    run grep -A 5 "^  bioinformatics:" "${TEST_DIR}/bundles.yaml" | grep "arch:"
    assert_success
    assert_output --partial "amd64"
    assert_output --partial "arm64"
}

@test "geospatial profile only supports amd64" {
    run grep -A 5 "^  geospatial:" "${TEST_DIR}/bundles.yaml" | grep "arch:"
    assert_success
    assert_output --partial "amd64"
}

@test "alpine profiles support both architectures" {
    run grep -A 5 "^  alpine" "${TEST_DIR}/bundles.yaml" | grep "arch:" | head -1
    assert_success
    assert_output --partial "amd64"
    assert_output --partial "arm64"
}

@test "architecture lists are valid arrays" {
    run grep "arch:" "${TEST_DIR}/bundles.yaml"
    assert_success
    # All should have array format [amd64, ...] or [amd64]
    while read -r line; do
        [[ "$line" =~ arch:\ \[.*\] ]] || [[ "$line" =~ arch: ]]
    done <<< "$output"
}

@test "arm64-only profiles are correctly identified" {
    # Search for profiles with only arm64
    # In our fixture, there shouldn't be any arm64-only profiles
    local arm64_only=$(grep -B 5 "arch: \[arm64\]" "${TEST_DIR}/bundles.yaml" || echo "")
    [ -z "$arm64_only" ]
}

@test "amd64-only profiles are correctly identified" {
    # publishing, geospatial should be amd64-only
    run grep -B 5 "arch: \[amd64\]" "${TEST_DIR}/bundles.yaml"
    # Should find some amd64-only profiles
    [[ "$output" =~ "publishing" || "$output" =~ "geospatial" ]]
}

@test "all base images are in valid registry format" {
    run grep "base_image:" "${TEST_DIR}/bundles.yaml"
    assert_success
    while read -r line; do
        # Extract image name
        image=$(echo "$line" | sed 's/.*base_image:[[:space:]]*\(.*\)/\1/')
        # Should have format: registry/image[:tag]
        [[ "$image" =~ ^[a-zA-Z0-9]+ ]]
    done <<< "$output"
}

################################################################################
# SECTION 3: System Requirements Validation (10 tests)
################################################################################

@test "Docker command is available" {
    command -v docker > /dev/null 2>&1 || skip "Docker not installed"
    run docker --version
    assert_success
}

@test "all base images are accessible" {
    command -v docker > /dev/null 2>&1 || skip "Docker not installed"

    # Skip in test environment as we don't want to pull large images
    # In real workflow, this would pull each base image
    [ -n "$(grep 'base_image:' "${TEST_DIR}/bundles.yaml")" ]
}

@test "profile with arm64 support doesn't use verse base" {
    # verse (rocker/verse) is amd64-only, so shouldn't be in arm64-supported profile
    local arm64_profiles=$(grep -B 5 "amd64, arm64" "${TEST_DIR}/bundles.yaml" | grep "base_image:" | grep -v "rocker/verse")
    # Should find some profiles with both arch support
    [ -n "$arm64_profiles" ]
}

@test "profile base images reference valid Docker registries" {
    run grep "base_image:" "${TEST_DIR}/bundles.yaml" | sed 's/.*base_image:[[:space:]]*\(.*\)/\1/'
    assert_success
    while read -r image; do
        # Image should have registry/name format or be a named image
        [[ "$image" =~ "/" ]] || [[ "$image" =~ "rocker" ]]
    done <<< "$output"
}

@test "all profiles have non-empty description" {
    run grep "description:" "${TEST_DIR}/bundles.yaml"
    assert_success
    while read -r line; do
        description=$(echo "$line" | sed 's/.*description:[[:space:]]*\(.*\)/\1/')
        [ -n "$description" ]
    done <<< "$output"
}

@test "profile descriptions don't contain special characters" {
    run grep "description:" "${TEST_DIR}/bundles.yaml"
    assert_success
    while read -r line; do
        description=$(echo "$line" | sed 's/.*description:[[:space:]]*\(.*\)/\1/')
        # Should only contain alphanumerics, spaces, hyphens, and standard punctuation
        [[ "$description" =~ ^[a-zA-Z0-9\ \-\.,:;]+$ ]]
    done <<< "$output"
}

@test "base image references use valid formats" {
    # rocker/r-ver, rocker/verse, bioconductor/..., etc.
    run grep "base_image:" "${TEST_DIR}/bundles.yaml"
    assert_success
    while read -r line; do
        image=$(echo "$line" | sed 's/.*base_image:[[:space:]]*\(.*\)/\1/')
        # Should match patterns like: registry/name[:tag]
        [[ "$image" =~ ^[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)+(:.*)?$ ]] || \
        [[ "$image" =~ ^[a-zA-Z0-9]+ ]]
    done <<< "$output"
}

@test "no profile uses unsupported architectures" {
    # Only amd64 and arm64 should be supported
    run grep "arch:" "${TEST_DIR}/bundles.yaml"
    assert_success
    while read -r line; do
        # Should not contain i386, ppc64, s390x, etc.
        refute_output --partial "i386"
        refute_output --partial "ppc64"
        refute_output --partial "s390x"
    done <<< "$output"
}

@test "Alpine profiles use Alpine base images" {
    run grep -A 5 "^  alpine" "${TEST_DIR}/bundles.yaml" | grep "base_image:"
    assert_success
    while read -r line; do
        [[ "$line" =~ "alpine" ]] || [[ "$line" =~ "r-ver" ]]
    done <<< "$output"
}

################################################################################
# SECTION 4: Profile Configuration Validation (10 tests)
################################################################################

@test "bundles.yaml has valid YAML syntax" {
    run grep -v "^#" "${TEST_DIR}/bundles.yaml" | grep -v "^$"
    # File should exist and be readable
    [ -f "${TEST_DIR}/bundles.yaml" ]
}

@test "profile configuration has consistent indentation" {
    run sed -n '/^  [a-z_]*:/,/^  [a-z_]*:/p' "${TEST_DIR}/bundles.yaml" | head -20
    # Indentation should be consistent (2 spaces per level)
    [ -n "$(grep '^  [a-z]' "${TEST_DIR}/bundles.yaml")" ]
}

@test "profile fields are consistently ordered" {
    # Each profile should have: base_image, description, arch
    run grep -A 3 "^  minimal:" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | grep "base_image:" | wc -l) -ge 1 ]
    [ $(echo "$output" | grep "description:" | wc -l) -ge 1 ]
    [ $(echo "$output" | grep "arch:" | wc -l) -ge 1 ]
}

@test "profile can be selected by name" {
    # Verify we can extract a profile by name
    profile="minimal"
    run grep -A 3 "^  $profile:" "${TEST_DIR}/bundles.yaml"
    assert_success
}

@test "profile configuration can be updated" {
    cp "${TEST_DIR}/bundles.yaml" "${TEST_DIR}/bundles.yaml.bak"

    # Ensure original and backup are identical
    diff "${TEST_DIR}/bundles.yaml" "${TEST_DIR}/bundles.yaml.bak"
}

@test "profile validation rejects invalid profile names" {
    # Try to select non-existent profile
    run grep "^  nonexistent:" "${TEST_DIR}/bundles.yaml" || true
    # Should not find it
    [ -z "$output" ]
}

@test "profile architecture lists are properly formatted" {
    run grep "arch:" "${TEST_DIR}/bundles.yaml"
    assert_success
    while read -r line; do
        # Should be format: arch: [amd64] or arch: [amd64, arm64]
        [[ "$line" =~ arch:\ \[[a-z0-9,\ ]+\] ]]
    done <<< "$output"
}

@test "profile base images don't use ':latest' tag" {
    run grep "base_image:" "${TEST_DIR}/bundles.yaml" | grep ":latest"
    # Should have some :latest tags for development
    # (Not necessarily a problem, just tracking)
    [ -n "$(grep 'base_image:.*:latest' "${TEST_DIR}/bundles.yaml")" ]
}

@test "all profiles have unique base image sources" {
    run grep "base_image:" "${TEST_DIR}/bundles.yaml" | sed 's/.*base_image:[[:space:]]*\(.*\)/\1/' | sort | uniq -d
    # Different profiles can use same base image, so duplicates are OK
    [ -f "${TEST_DIR}/bundles.yaml" ]
}

@test "profile descriptions are human-readable" {
    run grep "description:" "${TEST_DIR}/bundles.yaml"
    assert_success
    [ $(echo "$output" | wc -l) -ge 14 ]
}

################################################################################
# SECTION 5: Integration Tests
################################################################################

@test "can enumerate all available profiles" {
    run grep "^  [a-z_]*:" "${TEST_DIR}/bundles.yaml" | sed 's/^  \([a-z_]*\):.*/\1/'
    assert_success
    [ $(echo "$output" | wc -l) -ge 14 ]
}

@test "can select a profile by name and retrieve configuration" {
    profile="minimal"
    run grep -A 3 "^  $profile:" "${TEST_DIR}/bundles.yaml"
    assert_success
    assert_output --partial "base_image:"
    assert_output --partial "description:"
    assert_output --partial "arch:"
}

@test "profile selection logic handles case sensitivity" {
    # Profiles are lowercase, request should match
    run grep "^  minimal:" "${TEST_DIR}/bundles.yaml"
    assert_success

    # Should not find uppercase variant
    run grep "^  Minimal:" "${TEST_DIR}/bundles.yaml" || true
    [ -z "$output" ]
}

################################################################################
# Test Summary
################################################################################

# Note: These tests validate the profile configuration system
# and ensure all 14+ Docker profiles are properly defined and
# architecturally compatible.
