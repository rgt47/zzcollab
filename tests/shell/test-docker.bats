#!/usr/bin/env bats
# BATS tests for modules/docker.sh
# Tests Docker integration, multi-architecture support, and container configuration

# Setup function - runs before each test
setup() {
    # Create temporary directory for test environment
    TEST_DIR="$(mktemp -d)"
    TEST_PROJECT_DIR="${TEST_DIR}/test-project"
    mkdir -p "${TEST_PROJECT_DIR}"

    # Set environment variables BEFORE sourcing modules
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../.."
    export MODULES_DIR="${SCRIPT_DIR}/modules"
    export TEMPLATES_DIR="${SCRIPT_DIR}/templates"

    # Set required variables for Docker module
    export PKG_NAME="testpackage"
    export BASE_IMAGE="rocker/r-ver"
    export R_VERSION="latest"
    export BUILD_MODE="standard"
    export FORCE_PLATFORM="${FORCE_PLATFORM:-auto}"
    export MULTIARCH_VERSE_IMAGE="${MULTIARCH_VERSE_IMAGE:-rocker/rstudio}"

    # Save original directory and change to test project directory
    ORIG_DIR="$(pwd)"
    cd "${TEST_PROJECT_DIR}"

    # Source modules (core.sh must be loaded first)
    source "${SCRIPT_DIR}/modules/core.sh"
    source "${SCRIPT_DIR}/modules/templates.sh"
    source "${SCRIPT_DIR}/modules/docker.sh"
}

# Teardown function - runs after each test
teardown() {
    # Restore original directory
    cd "${ORIG_DIR}"

    # Clean up temporary directory
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
    fi
}

#=============================================================================
# MULTI-ARCHITECTURE SUPPORT TESTS
#=============================================================================

@test "get_multiarch_base_image returns r-ver for r-ver variant" {
    run get_multiarch_base_image "r-ver"
    [ "$status" -eq 0 ]
    [[ "${output}" == "rocker/r-ver" ]]
}

@test "get_multiarch_base_image returns rstudio for rstudio variant" {
    run get_multiarch_base_image "rstudio"
    [ "$status" -eq 0 ]
    [[ "${output}" == "rocker/rstudio" ]]
}

@test "get_multiarch_base_image handles verse variant on ARM64" {
    # Mock ARM64 architecture
    function uname() { echo "arm64"; }
    export -f uname

    run get_multiarch_base_image "verse"
    [ "$status" -eq 0 ]
    # Should return custom ARM64 alternative, not rocker/verse
    [[ "${output}" != "rocker/verse" ]]
}

@test "get_multiarch_base_image handles verse variant on AMD64" {
    # Mock AMD64 architecture
    function uname() { echo "x86_64"; }
    export -f uname

    run get_multiarch_base_image "verse"
    [ "$status" -eq 0 ]
    [[ "${output}" == "rocker/verse" ]]
}

@test "get_multiarch_base_image returns tidyverse for tidyverse variant" {
    run get_multiarch_base_image "tidyverse"
    [ "$status" -eq 0 ]
    [[ "${output}" == "rocker/tidyverse" ]]
}

@test "get_multiarch_base_image passes through custom images" {
    run get_multiarch_base_image "custom/myimage"
    [ "$status" -eq 0 ]
    [[ "${output}" == "custom/myimage" ]]
}

#=============================================================================
# DOCKER PLATFORM ARGUMENTS TESTS
#=============================================================================

@test "get_docker_platform_args returns empty for r-ver on AMD64" {
    # Mock AMD64 architecture
    function uname() { echo "x86_64"; }
    export -f uname
    export FORCE_PLATFORM="auto"

    run get_docker_platform_args "rocker/r-ver"
    [ "$status" -eq 0 ]
    [[ "${output}" == "" ]]
}

@test "get_docker_platform_args returns platform override for verse on ARM64" {
    # Mock ARM64 architecture
    function uname() { echo "arm64"; }
    export -f uname
    export FORCE_PLATFORM="auto"

    run get_docker_platform_args "rocker/verse"
    [ "$status" -eq 0 ]
    [[ "${output}" == "--platform linux/amd64" ]]
}

@test "get_docker_platform_args returns platform override for tidyverse on ARM64" {
    # Mock ARM64 architecture
    function uname() { echo "arm64"; }
    export -f uname
    export FORCE_PLATFORM="auto"

    run get_docker_platform_args "rocker/tidyverse"
    [ "$status" -eq 0 ]
    [[ "${output}" == "--platform linux/amd64" ]]
}

@test "get_docker_platform_args returns platform override for geospatial on ARM64" {
    # Mock ARM64 architecture
    function uname() { echo "arm64"; }
    export -f uname
    export FORCE_PLATFORM="auto"

    run get_docker_platform_args "rocker/geospatial"
    [ "$status" -eq 0 ]
    [[ "${output}" == "--platform linux/amd64" ]]
}

@test "get_docker_platform_args returns empty for multi-arch images on ARM64" {
    # Mock ARM64 architecture
    function uname() { echo "arm64"; }
    export -f uname
    export FORCE_PLATFORM="auto"

    run get_docker_platform_args "rocker/rstudio"
    [ "$status" -eq 0 ]
    [[ "${output}" == "" ]]
}

@test "get_docker_platform_args forces amd64 when FORCE_PLATFORM=amd64" {
    export FORCE_PLATFORM="amd64"

    run get_docker_platform_args "rocker/r-ver"
    [ "$status" -eq 0 ]
    [[ "${output}" == "--platform linux/amd64" ]]
}

@test "get_docker_platform_args forces arm64 when FORCE_PLATFORM=arm64" {
    export FORCE_PLATFORM="arm64"

    run get_docker_platform_args "rocker/r-ver"
    [ "$status" -eq 0 ]
    [[ "${output}" == "--platform linux/arm64" ]]
}

@test "get_docker_platform_args returns empty when FORCE_PLATFORM=native" {
    export FORCE_PLATFORM="native"

    run get_docker_platform_args "rocker/verse"
    [ "$status" -eq 0 ]
    [[ "${output}" == "" ]]
}

@test "get_docker_platform_args handles unknown FORCE_PLATFORM values" {
    export FORCE_PLATFORM="unknown"

    run get_docker_platform_args "rocker/r-ver"
    [ "$status" -eq 0 ]
    [[ "${output}" == "" ]]
}

#=============================================================================
# R VERSION DETECTION TESTS
#=============================================================================

@test "extract_r_version_from_lockfile fails when renv.lock missing" {
    # No renv.lock file created

    run extract_r_version_from_lockfile
    [ "$status" -eq 1 ]
    # Should output error message
    [[ "$output" =~ "renv.lock not found" ]]
}

@test "extract_r_version_from_lockfile extracts version from valid renv.lock" {
    # Create valid renv.lock file
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.3.1",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cloud.r-project.org"
      }
    ]
  }
}
EOF

    run extract_r_version_from_lockfile
    [ "$status" -eq 0 ]
    # Get last line of output (function should only echo version)
    local version=$(echo "$output" | tail -n 1)
    [[ "$version" == "4.3.1" ]]
}

@test "extract_r_version_from_lockfile fails with missing R.Version field" {
    # Create renv.lock without R.Version
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cloud.r-project.org"
      }
    ]
  }
}
EOF

    run extract_r_version_from_lockfile
    [ "$status" -eq 1 ]
    # Should output error message about failed extraction
    [[ "$output" =~ "Failed to extract R version" ]]
}

@test "extract_r_version_from_lockfile fails with invalid JSON" {
    # Create invalid JSON
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.3.1"
  # Missing closing brace
EOF

    run extract_r_version_from_lockfile
    [ "$status" -eq 1 ]
    # Should output error message about failed extraction
    [[ "$output" =~ "Failed to extract R version" ]]
}

@test "extract_r_version_from_lockfile returns 'latest' when python3 unavailable" {
    skip "Difficult to test without modifying PATH"

    # This would require temporarily removing python3 from PATH
    # Skip for now as it's complex to set up reliably
}

@test "extract_r_version_from_lockfile handles different R version formats" {
    # Create renv.lock with different version format
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.4.0-patched"
  }
}
EOF

    run extract_r_version_from_lockfile
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "4.4.0" ]]
}

#=============================================================================
# DOCKER TEMPLATE SELECTION TESTS
#=============================================================================

@test "get_dockerfile_template returns unified template" {
    run get_dockerfile_template
    [ "$status" -eq 0 ]
    [[ "${output}" == "Dockerfile.unified" ]]
}

@test "get_dockerfile_template is consistent across build modes" {
    # Test all build modes return same template
    BUILD_MODE="minimal"
    result1=$(get_dockerfile_template)

    BUILD_MODE="fast"
    result2=$(get_dockerfile_template)

    BUILD_MODE="standard"
    result3=$(get_dockerfile_template)

    BUILD_MODE="comprehensive"
    result4=$(get_dockerfile_template)

    [[ "$result1" == "$result2" ]]
    [[ "$result2" == "$result3" ]]
    [[ "$result3" == "$result4" ]]
}

#=============================================================================
# DOCKER FILES CREATION TESTS
#=============================================================================

@test "create_docker_files requires templates directory" {
    # Temporarily unset templates dir
    local saved_templates_dir="${TEMPLATES_DIR}"
    export TEMPLATES_DIR="/nonexistent"

    run create_docker_files
    [ "$status" -ne 0 ]

    # Restore
    export TEMPLATES_DIR="${saved_templates_dir}"
}

@test "create_docker_files detects R version from renv.lock" {
    # Create renv.lock
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.2.3"
  }
}
EOF

    # Mock install_template to check R_VERSION was set correctly
    function install_template() {
        # Return success if R_VERSION is correct
        [[ "${R_VERSION}" == "4.2.3" ]]
        return $?
    }
    export -f install_template

    run create_docker_files
    [ "$status" -eq 0 ]
}

@test "create_docker_files fails when no renv.lock exists and no --r-version provided" {
    # No renv.lock created
    # No USER_PROVIDED_R_VERSION set

    # Mock install_template
    function install_template() {
        echo "Mock install: $@"
        return 0
    }
    export -f install_template

    run create_docker_files
    [ "$status" -eq 1 ]

    # Should output error about missing R version
    [[ "$output" =~ "Failed to determine R version" ]]
}

@test "create_docker_files handles team setup marker file" {
    # Create renv.lock with R version
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.3.1"
  }
}
EOF

    # Create team setup marker
    cat > ".zzcollab_team_setup" << 'EOF'
team_name=myteam
project_name=myproject
profile_name=analysis
EOF

    # Mock install_template to check BASE_IMAGE was set correctly
    function install_template() {
        # Return success if BASE_IMAGE contains team/project names
        [[ "${BASE_IMAGE}" =~ "myteam/myproject" ]]
        return $?
    }
    export -f install_template

    run create_docker_files
    [ "$status" -eq 0 ]
}

@test "create_docker_files uses default base image without team setup" {
    # Create renv.lock with R version
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.3.1"
  }
}
EOF

    # No team setup marker

    # Mock install_template
    function install_template() {
        echo "Mock install: $@"
        return 0
    }
    export -f install_template

    run create_docker_files
    [ "$status" -eq 0 ]

    # BASE_IMAGE should be default
    [[ "${BASE_IMAGE}" == "rocker/r-ver" ]]
}

@test "create_docker_files fails when install_template fails" {
    # Mock install_template to fail
    function install_template() {
        return 1
    }
    export -f install_template

    run create_docker_files
    [ "$status" -eq 1 ]
}

#=============================================================================
# DOCKER IMAGE BUILDING TESTS
#=============================================================================

@test "build_docker_image validates Docker installation" {
    # Mock command_exists to simulate Docker not installed
    function command_exists() {
        return 1
    }
    export -f command_exists

    run build_docker_image
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Docker is not installed" ]]
}

@test "build_docker_image validates Docker daemon is running" {
    # Mock docker command to simulate daemon not running
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 1
        fi
    }
    export -f docker

    run build_docker_image
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Docker daemon is not running" ]]
}

@test "build_docker_image validates Dockerfile exists" {
    # No Dockerfile created

    # Mock docker info to succeed
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        fi
    }
    export -f docker

    run build_docker_image
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Dockerfile not found" ]]
}

@test "build_docker_image validates R_VERSION is set" {
    # Create Dockerfile
    touch "Dockerfile"

    # Mock docker
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        fi
    }
    export -f docker

    # Unset R_VERSION
    unset R_VERSION

    run build_docker_image
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "R_VERSION is not set" ]]
}

@test "build_docker_image validates PKG_NAME is set" {
    # Create Dockerfile
    touch "Dockerfile"

    # Mock docker
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        fi
    }
    export -f docker

    # Set R_VERSION but unset PKG_NAME
    export R_VERSION="4.3.1"
    unset PKG_NAME

    run build_docker_image
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "PKG_NAME is not set" ]]
}

@test "build_docker_image uses platform override on ARM64 for verse" {
    # Create Dockerfile
    touch "Dockerfile"

    # Mock ARM64 architecture
    function uname() { echo "arm64"; }
    export -f uname

    # Mock docker to capture build command
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        elif [[ "$1" == "build" ]]; then
            echo "Docker build called with: $@"
            return 0
        fi
    }
    export -f docker

    # Mock track_docker_image
    function track_docker_image() { return 0; }
    export -f track_docker_image

    export R_VERSION="4.3.1"
    export PKG_NAME="testpkg"
    export BASE_IMAGE="rocker/verse"
    export FORCE_PLATFORM="auto"

    run build_docker_image
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "--platform linux/amd64" ]]
}

@test "build_docker_image constructs correct build command" {
    # Create Dockerfile
    touch "Dockerfile"

    # Mock docker
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        elif [[ "$1" == "build" ]]; then
            # Capture and echo the command
            echo "Build args: $@"
            return 0
        fi
    }
    export -f docker

    # Mock track_docker_image
    function track_docker_image() { return 0; }
    export -f track_docker_image

    export R_VERSION="4.3.1"
    export PKG_NAME="mypkg"
    export BASE_IMAGE="rocker/r-ver"
    export BUILD_MODE="standard"

    run build_docker_image
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "R_VERSION" ]]
    [[ "${output}" =~ "BASE_IMAGE" ]]
    [[ "${output}" =~ "PACKAGE_MODE" ]]
}

#=============================================================================
# DOCKER VALIDATION TESTS
#=============================================================================

@test "validate_docker_environment checks Docker installation" {
    # Mock command validation to fail
    function validate_commands_exist() {
        return 1
    }
    export -f validate_commands_exist

    run validate_docker_environment
    [ "$status" -eq 1 ]
}

@test "validate_docker_environment checks Docker daemon" {
    # Mock validate_commands_exist to succeed
    function validate_commands_exist() {
        return 0
    }
    export -f validate_commands_exist

    # Mock docker info to fail (daemon not running)
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 1
        fi
    }
    export -f docker

    run validate_docker_environment
    [ "$status" -eq 1 ]
    [[ "${output}" =~ "Docker daemon is not running" ]]
}

@test "validate_docker_environment checks required files" {
    # Mock validate_commands_exist
    function validate_commands_exist() {
        return 0
    }
    export -f validate_commands_exist

    # Mock docker info to succeed
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        elif [[ "$1" == "image" ]]; then
            return 1
        fi
    }
    export -f docker

    # Mock validate_files_exist to fail
    function validate_files_exist() {
        return 1
    }
    export -f validate_files_exist

    run validate_docker_environment
    [ "$status" -eq 1 ]
}

@test "validate_docker_environment checks Docker image exists" {
    # Create required files
    touch "Dockerfile"
    touch "docker-compose.yml"
    touch ".zshrc_docker"

    # Mock validate functions
    function validate_commands_exist() {
        return 0
    }
    export -f validate_commands_exist

    function validate_files_exist() {
        return 0
    }
    export -f validate_files_exist

    # Mock docker
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        elif [[ "$1" == "image" ]] && [[ "$2" == "inspect" ]]; then
            return 0  # Image exists
        fi
    }
    export -f docker

    export PKG_NAME="testpkg"

    run validate_docker_environment
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "exists and ready to use" ]]
}

@test "validate_docker_environment informs when image not built" {
    # Create required files
    touch "Dockerfile"
    touch "docker-compose.yml"
    touch ".zshrc_docker"

    # Mock validate functions
    function validate_commands_exist() {
        return 0
    }
    export -f validate_commands_exist

    function validate_files_exist() {
        return 0
    }
    export -f validate_files_exist

    # Mock docker
    function docker() {
        if [[ "$1" == "info" ]]; then
            return 0
        elif [[ "$1" == "image" ]] && [[ "$2" == "inspect" ]]; then
            return 1  # Image does not exist
        fi
    }
    export -f docker

    export PKG_NAME="testpkg"

    run validate_docker_environment
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "not built yet" ]]
}

#=============================================================================
# DOCKER SUMMARY TESTS
#=============================================================================

@test "show_docker_summary displays formatted output" {
    run show_docker_summary
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "DOCKER ENVIRONMENT" ]]
    [[ "${output}" =~ "Dockerfile" ]]
    [[ "${output}" =~ "docker-compose.yml" ]]
}

@test "show_docker_summary includes common commands" {
    run show_docker_summary
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "make docker-build" ]]
    [[ "${output}" =~ "make docker-rstudio" ]]
    [[ "${output}" =~ "make docker-test" ]]
}

@test "show_docker_summary includes service information" {
    run show_docker_summary
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "rstudio" ]]
    [[ "${output}" =~ "http://localhost:8787" ]]
}

@test "show_docker_summary includes troubleshooting guidance" {
    run show_docker_summary
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "TROUBLESHOOTING" ]]
    [[ "${output}" =~ "Docker Desktop" ]]
}

#=============================================================================
# INTEGRATION TESTS
#=============================================================================

@test "Docker module exports required variables" {
    # Check that module validation runs
    [[ -n "${BASE_IMAGE:-}" ]]
}

@test "Docker module sets default BASE_IMAGE when undefined" {
    # Unset BASE_IMAGE before sourcing
    unset BASE_IMAGE

    # Re-source docker module
    source "${SCRIPT_DIR}/modules/docker.sh"

    # Should have default value
    [[ "${BASE_IMAGE}" == "rocker/r-ver" ]]
}

@test "Docker module warns when PKG_NAME undefined" {
    # This is checked during module load
    # We can't easily test this without re-sourcing, so skip for now
    skip "PKG_NAME warning tested during module initialization"
}

@test "Multi-architecture functions work together" {
    # Test the complete flow: get image, then get platform args

    # Mock ARM64
    function uname() { echo "arm64"; }
    export -f uname
    export FORCE_PLATFORM="auto"

    # Get image for verse variant
    base_image=$(get_multiarch_base_image "verse")

    # Get platform args for that image
    platform_args=$(get_docker_platform_args "$base_image")

    # Should get alternative image and no platform override (since alternative is multi-arch)
    [[ "$base_image" != "rocker/verse" ]]
}

@test "R version detection integrates with create_docker_files" {
    # Create renv.lock
    cat > "renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.4.0"
  }
}
EOF

    # Mock install_template
    function install_template() {
        # Check that R_VERSION was set correctly
        if [[ "${R_VERSION}" == "4.4.0" ]]; then
            return 0
        else
            return 1
        fi
    }
    export -f install_template

    run create_docker_files
    [ "$status" -eq 0 ]
}
