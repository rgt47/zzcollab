#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB DOCKER MODULE
##############################################################################
# 
# PURPOSE: Docker integration and containerized development environment
#          - Docker configuration files (Dockerfile)
#          - R version detection from renv.lock
#          - Docker image building with platform detection
#          - Container shell configuration
#          - Support scripts for container development
#
# DEPENDENCIES: core.sh (logging, command_exists), templates.sh (file creation)
#
# TRACKING: All created Docker files are tracked for uninstall capability
##############################################################################

# Validate required modules are loaded
require_module "core" "templates"

#=============================================================================
# MANIFEST TRACKING FUNCTIONS
#=============================================================================

# Tracking functions are now provided by core.sh

#=============================================================================
# MULTI-ARCHITECTURE SUPPORT FUNCTIONS
#=============================================================================

##############################################################################
# FUNCTION: get_multiarch_base_image
# PURPOSE:  Select appropriate Docker base image based on architecture and requirements
# USAGE:    get_multiarch_base_image "profile_name"
# ARGS:     
#   $1 - requested_variant: Docker image variant (r-ver, rstudio, verse, tidyverse)
# RETURNS:  
#   0 - Always succeeds, outputs multi-architecture compatible base image name
# GLOBALS:  
#   READ:  MULTIARCH_VERSE_IMAGE (custom ARM64 verse alternative)
#   WRITE: None (outputs to stdout)
# DESCRIPTION:
#   This function handles the complexity of Docker image architecture compatibility.
#   Some rocker images (verse, tidyverse) only support AMD64, while others (r-ver, rstudio)
#   support both AMD64 and ARM64. This function automatically selects the appropriate
#   image based on the requested variant and current system architecture.
# ARCHITECTURE SUPPORT:
#   ✅ Multi-arch: rocker/r-ver, rocker/rstudio
#   ❌ AMD64 only: rocker/verse, rocker/tidyverse, rocker/geospatial, rocker/shiny
# EXAMPLE:
#   base_image=$(get_multiarch_base_image "rstudio")
#   echo "Selected: $base_image"
##############################################################################
get_multiarch_base_image() {
    local requested_variant="$1"
    local architecture="$(uname -m)"
    
    case "$requested_variant" in
        "r-ver")
            echo "rocker/r-ver"  # Multi-arch available
            ;;
        "rstudio") 
            echo "rocker/rstudio"  # Multi-arch available
            ;;
        "verse")
            case "$architecture" in
                arm64|aarch64)
                    # Use custom ARM64-compatible alternative
                    echo "${MULTIARCH_VERSE_IMAGE}"
                    ;;
                *)
                    echo "rocker/verse"
                    ;;
            esac
            ;;
        "tidyverse")
            case "$architecture" in
                arm64|aarch64)
                    # tidyverse only supports AMD64
                    echo "rocker/tidyverse"
                    ;;
                *)
                    echo "rocker/tidyverse"
                    ;;
            esac
            ;;
        *)
            # Pass through custom images or other variants
            echo "$requested_variant"
            ;;
    esac
}

##############################################################################
# FUNCTION: get_docker_platform_args
# PURPOSE:  Generate Docker platform arguments for cross-architecture compatibility
# USAGE:    get_docker_platform_args [base_image_name]
# ARGS:     
#   $1 - base_image: Optional Docker base image name for compatibility checking
# RETURNS:  
#   0 - Always succeeds, outputs platform arguments for Docker commands
# GLOBALS:  
#   READ:  FORCE_PLATFORM (auto|amd64|arm64|native), uname -m output
#   WRITE: None (outputs to stdout)
# DESCRIPTION:
#   This function determines the appropriate --platform argument for Docker build/run
#   commands based on system architecture and image compatibility. It handles the
#   complexity of running AMD64-only images on ARM64 systems through emulation.
# PLATFORM LOGIC:
#   - auto: Automatically detect best platform based on image compatibility
#   - amd64: Force AMD64 platform (works on both architectures via emulation)
#   - arm64: Force ARM64 platform (only works on ARM64 systems)
#   - native: Use system native platform without override
# EXAMPLE:
#   platform_args=$(get_docker_platform_args "rocker/verse")
#   docker build $platform_args -t my-image .
##############################################################################
get_docker_platform_args() {
    local base_image="${1:-}"
    local architecture="$(uname -m)"
    
    case "$FORCE_PLATFORM" in
        "auto")
            case "$architecture" in
                arm64|aarch64) 
                    # Check if this is a known ARM64-incompatible image
                    if [[ "$base_image" == "rocker/verse" ]] || 
                       [[ "$base_image" == "rocker/tidyverse" ]] ||
                       [[ "$base_image" == "rocker/geospatial" ]] ||
                       [[ "$base_image" == "rocker/shiny" ]]; then
                        echo "--platform linux/amd64"  # Force AMD64 for incompatible images
                    else
                        echo ""  # Use native platform for multi-arch images
                    fi
                    ;;
                *)
                    echo ""  # Use native platform
                    ;;
            esac
            ;;
        "amd64")
            echo "--platform linux/amd64"
            ;;
        "arm64")
            echo "--platform linux/arm64"
            ;;
        "native")
            echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}

#=============================================================================
# R VERSION DETECTION (extracted from lines 508-523)
#=============================================================================

# Function: extract_r_version_from_lockfile
# Purpose: Extract R version from renv.lock file for Docker builds
# Returns: R version string (e.g., "4.3.1") or exits with error
#
# Process:
#   1. Verify renv.lock exists (REQUIRED for reproducibility)
#   2. Check python3 or jq available for JSON parsing
#   3. Parse JSON to extract R.Version field
#   4. FAIL if version cannot be determined (never default to "latest")
#
# Used by: Docker build process to ensure container matches project R version
# Dependencies: python3 or jq (for JSON parsing), renv.lock file (REQUIRED)
extract_r_version_from_lockfile() {
    # CRITICAL: renv.lock is REQUIRED for reproducible builds
    if [[ ! -f "renv.lock" ]]; then
        log_error "Cannot determine R version: renv.lock not found"
        log_error ""
        log_error "For reproducible builds, you must specify the R version."
        log_error "Choose one of these options:"
        log_error ""
        log_error "  Option 1 (Recommended): Initialize renv to create renv.lock"
        log_error "    R -e \"renv::init()\""
        log_error ""
        log_error "  Option 2: Specify R version explicitly with --r-version flag"
        log_error "    zzcollab --r-version 4.4.0 [other options]"
        log_error ""
        log_error "  Option 3: Use system R version (not reproducible)"
        log_error "    zzcollab --r-version \$(R --version | grep -oP 'R version \\K[0-9.]+') [options]"
        log_error ""
        return 1
    fi

    log_info "Extracting R version from renv.lock..."

    # Try jq first (faster and more reliable)
    if command_exists jq; then
        local r_version
        r_version=$(jq -r '.R.Version // empty' renv.lock 2>/dev/null)

        if [[ -n "$r_version" ]]; then
            log_success "Found R version in lockfile: $r_version" >&2
            echo "$r_version"
            return 0
        fi
    fi

    # Fall back to Python if jq not available
    if command_exists python3; then
        local r_version
        local python_exit

        # Capture stdout only (version), let stderr go to terminal (Issue #12 fix)
        r_version=$(python3 -c "
import json
import sys
try:
    with open('renv.lock', 'r') as f:
        data = json.load(f)
        version = data.get('R', {}).get('Version')
        if version:
            print(version)
            sys.exit(0)
        else:
            sys.exit(1)
except Exception as e:
    print(f'Error parsing renv.lock: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)
        python_exit=$?

        if [[ $python_exit -eq 0 ]] && [[ -n "$r_version" ]]; then
            log_success "Found R version in lockfile: $r_version" >&2
            echo "$r_version"
            return 0
        fi
    fi

    # If we get here, parsing failed
    log_error "Failed to extract R version from renv.lock"
    log_error ""
    if ! command_exists python3 && ! command_exists jq; then
        log_error "Neither python3 nor jq is available for JSON parsing."
        log_error "Please install one of them:"
        log_error "  - Ubuntu/Debian: apt-get install python3"
        log_error "  - macOS: brew install python3 (or jq)"
    else
        log_error "renv.lock may be corrupted or missing R version field."
        log_error "Try regenerating it with: R -e \"renv::snapshot()\""
    fi
    log_error ""
    log_error "Alternatively, specify R version explicitly:"
    log_error "  zzcollab --r-version 4.4.0 [other options]"
    log_error ""
    return 1
}

##############################################################################
# FUNCTION: check_docker_image_exists
# PURPOSE:  Verify that a Docker image exists on Docker Hub
# USAGE:    check_docker_image_exists "rocker/r-ver" "4.4.0"
# ARGS:
#   $1 - image_name: Docker image name (e.g., "rocker/r-ver")
#   $2 - tag: Image tag/version to check (e.g., "4.4.0")
# RETURNS:
#   0 - Image exists on Docker Hub
#   1 - Image not found or API query failed
# GLOBALS:
#   READ:  None
#   WRITE: None
# DESCRIPTION:
#   Queries Docker Hub API to verify that a specific image:tag combination exists.
#   Used to validate R versions before attempting Docker builds.
# API ENDPOINT:
#   https://hub.docker.com/v2/repositories/{image}/tags/{tag}
# EXAMPLE:
#   if check_docker_image_exists "rocker/r-ver" "4.4.0"; then
#       echo "Image exists!"
#   fi
##############################################################################
check_docker_image_exists() {
    local image_name="$1"
    local tag="$2"

    # Query Docker Hub API
    local api_url="https://hub.docker.com/v2/repositories/${image_name}/tags/${tag}"

    # Require curl for validation
    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl not available - cannot validate image on Docker Hub"
        log_warn "Install curl: 'apt-get install curl' (Linux) or 'brew install curl' (macOS)"
        log_warn "Skipping Docker Hub validation (build may fail if image doesn't exist)"
        # Return success for best-effort validation, but user is warned
        return 0
    fi

    # Use curl with explicit error handling
    local http_code
    local curl_exit

    # Get HTTP status code
    http_code=$(curl -sf -w "%{http_code}" --max-time 5 "$api_url" -o /dev/null 2>&1)
    curl_exit=$?

    if [[ $curl_exit -eq 0 ]] && [[ "$http_code" == "200" ]]; then
        # Success: image confirmed to exist
        return 0
    elif [[ $curl_exit -eq 28 ]]; then
        # Timeout: network may be slow
        log_warn "Docker Hub API timeout - network may be slow or unavailable"
        log_debug "Timeout after 5 seconds querying: $api_url"
        # Timeout is non-fatal: assume image exists
        return 0
    elif [[ "$http_code" == "404" ]]; then
        # Confirmed: image does not exist
        log_debug "Docker Hub returned 404 for: $image_name:$tag"
        return 1
    elif [[ "$http_code" == "429" ]]; then
        # Rate limited
        log_warn "Docker Hub API rate limit exceeded"
        log_debug "Try again later or reduce Docker Hub API calls"
        # Rate limit is non-fatal: assume image exists
        return 0
    else
        # Other error: API failure, network issue, etc.
        log_warn "Docker Hub API query failed (HTTP $http_code, curl exit $curl_exit)"
        log_debug "URL: $api_url"
        # API errors are non-fatal: assume image exists (Docker build will fail if it doesn't)
        return 0
    fi
}

##############################################################################
# FUNCTION: get_latest_r_version_from_dockerhub
# PURPOSE:  Query Docker Hub for the latest available R version
# USAGE:    latest=$(get_latest_r_version_from_dockerhub "rocker/r-ver")
# ARGS:
#   $1 - image_name: Docker image name (e.g., "rocker/r-ver")
# RETURNS:
#   0 - Success, outputs latest version number
#   1 - Failed to query or parse
# GLOBALS:
#   READ:  None
#   WRITE: None (outputs to stdout)
# DESCRIPTION:
#   Queries Docker Hub API for available tags and finds the latest semantic version.
#   Filters out tags like "latest", "devel", etc., and returns highest X.Y.Z version.
# EXAMPLE:
#   latest=$(get_latest_r_version_from_dockerhub "rocker/r-ver")
#   echo "Latest R version: $latest"
##############################################################################
get_latest_r_version_from_dockerhub() {
    local image_name="$1"

    # Query Docker Hub API for tags
    local api_url="https://hub.docker.com/v2/repositories/${image_name}/tags/?page_size=100"

    if ! command -v curl >/dev/null 2>&1; then
        log_debug "curl not available for version lookup"
        return 1
    fi

    # Fetch tags and parse JSON
    local tags
    if ! tags=$(curl -sf --max-time 10 "$api_url" 2>/dev/null); then
        return 1
    fi

    # Extract version tags (X.Y.Z format) and find latest
    # Use grep and sort to find highest semantic version
    local latest_version
    latest_version=$(echo "$tags" | \
        grep -oE '"name":"[0-9]+\.[0-9]+\.[0-9]+"' | \
        sed 's/"name":"//g' | sed 's/"//g' | \
        sort -V | tail -1)

    if [[ -n "$latest_version" ]]; then
        echo "$latest_version"
        return 0
    else
        return 1
    fi
}

##############################################################################
# FUNCTION: suggest_r_version
# PURPOSE:  Suggest available R versions when user provides invalid version
# USAGE:    suggest_r_version "4.99.0" "rocker/r-ver"
# ARGS:
#   $1 - invalid_version: The version user tried that doesn't exist
#   $2 - image_name: Docker image name (e.g., "rocker/r-ver")
# RETURNS:
#   Always returns 0, outputs suggestions to stderr
# GLOBALS:
#   READ:  None
#   WRITE: None (outputs suggestions via log functions)
# DESCRIPTION:
#   Provides helpful suggestions when an R version doesn't exist on Docker Hub.
#   Queries for latest version and provides actionable next steps.
# EXAMPLE:
#   suggest_r_version "4.99.0" "rocker/r-ver"
##############################################################################
suggest_r_version() {
    local invalid_version="$1"
    local image_name="${2:-rocker/r-ver}"

    log_error "R version '$invalid_version' not found in $image_name Docker image"
    log_error ""

    # Try to get latest version
    local latest_version
    if latest_version=$(get_latest_r_version_from_dockerhub "$image_name"); then
        log_error "💡 Latest available R version: $latest_version"
        log_error ""
        log_error "Try one of these options:"
        log_error "  zzcollab --r-version $latest_version"
        log_error "  zzcollab --config set r-version $latest_version"
    else
        log_error "💡 Common R versions available:"
        log_error "  - 4.4.0 (latest stable)"
        log_error "  - 4.3.1 (previous stable)"
        log_error "  - 4.2.3"
        log_error ""
        log_error "Check available versions at:"
        log_error "  https://hub.docker.com/r/$image_name/tags"
    fi
    log_error ""
}

##############################################################################
# FUNCTION: validate_r_version_early
# PURPOSE:  Validate R version BEFORE creating any project files
# USAGE:    validate_r_version_early
# ARGS:     None (uses global variables)
# RETURNS:
#   0 - R version is valid or will be determined from renv.lock
#   1 - R version is invalid
# GLOBALS:
#   READ:  USER_PROVIDED_R_VERSION, R_VERSION, CONFIG_R_VERSION
#   WRITE: None
# DESCRIPTION:
#   This function validates the R version early in the project setup workflow,
#   before any files are created. It checks format and Docker Hub availability
#   for user-provided or config-specified R versions.
# VALIDATION PRIORITY:
#   1. User-provided --r-version flag (validate immediately)
#   2. Config r-version (validate immediately)
#   3. renv.lock (skip validation - will be checked during Docker file creation)
# EXAMPLE:
#   validate_r_version_early || exit 1
##############################################################################
validate_r_version_early() {
    local r_version_to_check=""

    # Determine which R version to validate
    if [[ "${USER_PROVIDED_R_VERSION:-false}" == "true" ]] && [[ -n "${R_VERSION:-}" ]]; then
        r_version_to_check="${R_VERSION}"
        log_info "Validating user-provided R version: ${r_version_to_check}"
    elif [[ -n "${CONFIG_R_VERSION:-}" ]]; then
        r_version_to_check="${CONFIG_R_VERSION}"
        log_info "Validating R version from config: ${r_version_to_check}"
    else
        # No R version specified - check if renv.lock exists
        if [[ ! -f "renv.lock" ]]; then
            log_error "Cannot determine R version: renv.lock not found"
            log_error ""
            log_error "For reproducible builds, you must specify the R version."
            log_error "Choose one of these options:"
            log_error ""
            log_error "  Option 1: Set default R version in config (recommended)"
            log_error "    zzcollab --config set r-version 4.4.0"
            log_error "    zzcollab  # Then run zzcollab again"
            log_error ""
            log_error "  Option 2: Specify R version with --r-version flag"
            log_error "    zzcollab --r-version 4.4.0"
            log_error ""
            log_error "  Option 3: Initialize renv first to create renv.lock"
            log_error "    R -e \"renv::init()\""
            log_error "    zzcollab  # Then run zzcollab again"
            log_error ""
            return 1
        fi
        # renv.lock exists - will validate it during Docker file creation
        log_debug "No R version specified, will extract from renv.lock during Docker setup"
        return 0
    fi

    # Validate R version format (X.Y.Z or X.Y)
    if [[ ! "${r_version_to_check}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "${r_version_to_check}" =~ ^[0-9]+\.[0-9]+$ ]]; then
        log_error "R version '${r_version_to_check}' has invalid format (expected X.Y.Z)"
        suggest_r_version "${r_version_to_check}" "rocker/r-ver"
        return 1
    fi

    # Validate that Docker image exists on Docker Hub
    log_debug "Validating R version ${r_version_to_check} exists on Docker Hub..."
    if ! check_docker_image_exists "rocker/r-ver" "${r_version_to_check}"; then
        log_error "Docker image 'rocker/r-ver:${r_version_to_check}' not found on Docker Hub"
        suggest_r_version "${r_version_to_check}" "rocker/r-ver"
        return 1
    fi

    # CRITICAL: Check for mismatch between specified R version and renv.lock
    # If renv.lock exists and has a different R version, this will cause:
    # - Binary package incompatibility
    # - renv::restore() failures
    # - Silent behavior differences
    # - Breaking reproducibility
    if [[ -f "renv.lock" ]]; then
        local lockfile_r_version
        local extract_output
        local extract_status

        # Capture only stdout (version), let stderr (logs) go to terminal
        extract_output=$(extract_r_version_from_lockfile)
        extract_status=$?

        # Validate extraction was successful and returned a non-empty version
        if [[ $extract_status -ne 0 ]]; then
            log_warn "Could not extract R version from renv.lock (non-fatal)"
            log_debug "Extract error (exit status: $extract_status)"
            # Continue without validation - Docker build will catch issues later
        elif [[ -z "$extract_output" ]]; then
            log_warn "renv.lock exists but R version field is empty (non-fatal)"
            log_debug "This may indicate an incomplete or corrupted renv.lock file"
            # Continue without validation - Docker build will catch issues later
        else
            # Successfully extracted version - validate it matches
            lockfile_r_version="$extract_output"

            if [[ "${r_version_to_check}" != "${lockfile_r_version}" ]]; then
                log_error "R version MISMATCH detected!"
                log_error ""
                log_error "  Specified R version:  ${r_version_to_check}"
                log_error "  renv.lock R version:  ${lockfile_r_version}"
                log_error ""
                log_error "This mismatch will cause:"
                log_error "  • Binary package incompatibility"
                log_error "  • renv::restore() failures"
                log_error "  • Different computational results"
                log_error ""
                log_error "Choose one of these solutions:"
                log_error ""
                log_error "  Solution 1: Use R version from renv.lock (recommended)"
                log_error "    zzcollab --r-version ${lockfile_r_version}"
                log_error "    # OR set in config:"
                log_error "    zzcollab --config set r-version ${lockfile_r_version}"
                log_error ""
                log_error "  Solution 2: Update renv.lock to match specified version"
                log_error "    # Install R ${r_version_to_check}, then:"
                log_error "    R -e \"renv::init(force = TRUE)\""
                log_error "    zzcollab --r-version ${r_version_to_check}"
                log_error ""
                return 1
            fi

            log_debug "✓ R version ${r_version_to_check} matches renv.lock"
        fi
    fi

    log_info "✓ Confirmed R version ${r_version_to_check} is available on Docker Hub"
    return 0
}

#=============================================================================
# DOCKER TEMPLATE SELECTION
#=============================================================================

##############################################################################
# FUNCTION: get_dockerfile_template
# PURPOSE:  Select appropriate Dockerfile template based on build mode
# USAGE:    get_dockerfile_template
# ARGS:
#   None (uses global PROFILE_NAME variable)
# RETURNS:
#   0 - Always succeeds, outputs template filename or "GENERATE"
# GLOBALS:
#   READ:  PROFILE_NAME, BASE_IMAGE_FLAG, LIBS_BUNDLE, PKGS_BUNDLE
#   WRITE: None (outputs to stdout)
# DESCRIPTION:
#   v3.0 Profile-Specific Dockerfile System:
#   - Standard profiles (minimal, analysis, geospatial, modeling, publishing)
#     use optimized static Dockerfiles
#   - Custom configurations (custom base image or bundle combinations)
#     trigger generation from Dockerfile.base.template
#   - Team images use simplified Dockerfile.personal.team
# TEMPLATE MAPPING:
#   - Standard profiles: Dockerfile.{profile} (static, multi-stage, optimized)
#   - Custom profiles: "GENERATE" (triggers dockerfile_generator.sh)
#   - Team member: Dockerfile.personal.team
# EXAMPLE:
#   template=$(get_dockerfile_template)
#   if [[ "$template" == "GENERATE" ]]; then
#       generate_custom_dockerfile
#   else
#       install_template "$template" "Dockerfile"
#   fi
##############################################################################
get_dockerfile_template() {
    # Load dockerfile generator module for strategy selection
    if [[ -f "$MODULES_DIR/dockerfile_generator.sh" ]]; then
        source "$MODULES_DIR/dockerfile_generator.sh"

        # Get strategy from generator module
        local strategy=$(select_dockerfile_strategy)

        case "$strategy" in
            static:*)
                # Extract template name from "static:Dockerfile.minimal"
                echo "${strategy#static:}"
                ;;
            generate:*)
                # Signal that generation is needed
                echo "GENERATE"
                ;;
            *)
                log_error "Unknown Dockerfile strategy: $strategy"
                echo "Dockerfile.unified"  # Fallback to legacy
                ;;
        esac
    else
        # Fallback to legacy unified template if generator not available
        log_warn "Dockerfile generator module not found, using legacy unified template"
        echo "Dockerfile.unified"
    fi
}

#=============================================================================
# DOCKER CONFIGURATION FILES CREATION (extracted from lines 481-506)
#=============================================================================

# Function: create_docker_files
# Purpose: Creates all Docker configuration files and support scripts
# Creates:
#   - Dockerfile (main container definition)
#   - .zshrc_docker (container shell configuration)
#   - validate_package_environment.R (package validation script)
#   - ZZCOLLAB_USER_GUIDE.md (comprehensive documentation)
#
# Process:
#   1. Detect R version from renv.lock if available
#   2. Copy template files with variable substitution
#   3. Track all created files for uninstall capability
#
# Templates Used: All files are copied from templates/ directory
# Variables: R_VERSION, PKG_NAME, BASE_IMAGE are substituted in templates
create_docker_files() {
    log_info "Creating Docker configuration files..."

    # Check if this is completing a team setup (second step after 'zzcollab -i')
    local use_team_image=false
    local team_base_image=""

    if [[ -f ".zzcollab_team_setup" ]]; then
        # Read team setup information
        local team_name project_name profile_name
        team_name=$(grep "^team_name=" ".zzcollab_team_setup" | cut -d= -f2)
        project_name=$(grep "^project_name=" ".zzcollab_team_setup" | cut -d= -f2)
        profile_name=$(grep "^profile_name=" ".zzcollab_team_setup" | cut -d= -f2)

        if [[ -n "$team_name" ]] && [[ -n "$project_name" ]] && [[ -n "$profile_name" ]]; then
            # Construct team image name
            team_base_image="${team_name}/${project_name}_core-${profile_name}"
            use_team_image=true

            # Determine image tag for reproducibility
            # Priority: 1) git SHA (most precise), 2) date stamp, 3) latest (fallback only)
            local image_tag=""
            if git rev-parse --short HEAD >/dev/null 2>&1; then
                image_tag=$(git rev-parse --short HEAD)
                log_info "Detected team setup - using team image: ${team_base_image}:${image_tag} (git SHA)"
            else
                image_tag=$(date +%Y%m%d)
                log_warn "No git repository - using date-based tag: ${team_base_image}:${image_tag}"
                log_warn "Consider using git for better reproducibility tracking"
            fi
            export IMAGE_TAG="$image_tag"
        fi
    fi

    # Determine R version for Docker build
    # This ensures the container uses the same R version as the project
    # Priority: 1) User-provided --r-version, 2) Config r-version, 3) renv.lock, 4) FAIL (no default)
    local r_version=""

    if [[ "${USER_PROVIDED_R_VERSION:-false}" == "true" ]] && [[ -n "${R_VERSION:-}" ]]; then
        # User explicitly provided R version via --r-version flag (highest priority)
        r_version="${R_VERSION}"
        log_info "Using user-specified R version: ${r_version}"
    elif [[ -n "${CONFIG_R_VERSION:-}" ]]; then
        # Use R version from config file (second priority)
        r_version="${CONFIG_R_VERSION}"
        log_info "Using R version from config: ${r_version}"
    else
        # Try to extract from renv.lock (third priority, will fail if missing)
        if ! r_version=$(extract_r_version_from_lockfile); then
            log_error "Failed to determine R version for Docker build"
            log_error "Docker builds require explicit R version for reproducibility"
            return 1
        fi
        log_info "Using R version from renv.lock: ${r_version}"
    fi

    # Note: R version validation happens earlier in validate_r_version_early()
    # for user-provided and config R versions. Here we only validate renv.lock versions
    # since those are determined at this point in the workflow.

    if [[ "${USER_PROVIDED_R_VERSION:-false}" != "true" ]] && [[ -z "${CONFIG_R_VERSION:-}" ]]; then
        # This R version came from renv.lock - validate it now
        if [[ ! "${r_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "${r_version}" =~ ^[0-9]+\.[0-9]+$ ]]; then
            log_error "R version '${r_version}' from renv.lock has invalid format (expected X.Y.Z)"
            suggest_r_version "${r_version}" "rocker/r-ver"
            return 1
        fi

        log_debug "Validating R version ${r_version} from renv.lock exists on Docker Hub..."
        if ! check_docker_image_exists "rocker/r-ver" "${r_version}"; then
            log_error "Docker image 'rocker/r-ver:${r_version}' not found on Docker Hub"
            suggest_r_version "${r_version}" "rocker/r-ver"
            return 1
        fi
        log_debug "✓ Confirmed rocker/r-ver:${r_version} exists on Docker Hub"
    fi

    # Export R_VERSION for template substitution
    # This variable is used in Dockerfile template
    export R_VERSION="${r_version}"

    # Set BASE_IMAGE for template substitution
    if [[ "$use_team_image" == "true" ]]; then
        export BASE_IMAGE="$team_base_image"
        log_info "Personal Dockerfile will use team image: $BASE_IMAGE"
    else
        # Only set default if BASE_IMAGE not already set by profile expansion
        if [[ -z "${BASE_IMAGE:-}" ]]; then
            export BASE_IMAGE="rocker/r-ver"
            log_info "No profile specified, using default rocker image: $BASE_IMAGE"
        else
            log_info "Using base image from profile: $BASE_IMAGE"
        fi
    fi

    # Create Dockerfile from template OR generate custom
    # v3.0: Use optimized profile-specific Dockerfiles or generate from template
    local dockerfile_template
    if [[ "$use_team_image" == "true" ]]; then
        # Use simplified team-specific template
        dockerfile_template="Dockerfile.personal.team"
        log_info "Using Dockerfile.personal.team template (simplified for team images)"
    else
        # Get template strategy from get_dockerfile_template
        dockerfile_template=$(get_dockerfile_template)
    fi

    # Handle generation vs static template
    if [[ "$dockerfile_template" == "GENERATE" ]]; then
        # Load generator module and create custom Dockerfile
        if [[ -f "$MODULES_DIR/dockerfile_generator.sh" ]]; then
            source "$MODULES_DIR/dockerfile_generator.sh"
            log_info "Generating custom Dockerfile for your specifications..."
            if ! generate_custom_dockerfile; then
                log_error "Failed to generate custom Dockerfile"
                return 1
            fi
            log_success "✓ Custom Dockerfile generated successfully"
        else
            log_error "Dockerfile generator module not found"
            return 1
        fi
    else
        # Use static profile Dockerfile
        case "$PROFILE_NAME" in
            minimal)
                log_info "Using optimized Dockerfile.minimal (multi-stage, ~800MB)"
                ;;
            analysis)
                log_info "Using optimized Dockerfile.analysis (multi-stage, ~1.2GB)"
                ;;
            geospatial)
                log_info "Using optimized Dockerfile.geospatial (multi-stage, ~2.5GB)"
                ;;
            modeling)
                log_info "Using optimized Dockerfile.modeling (multi-stage, ~1.5GB)"
                ;;
            publishing)
                log_info "Using optimized Dockerfile.publishing (multi-stage, ~3GB)"
                ;;
            *)
                log_info "Using Dockerfile template: $dockerfile_template"
                ;;
        esac

        # Contains: R environment, system dependencies, development tools, project setup
        if ! install_template "$dockerfile_template" "Dockerfile" "Dockerfile" "Created Dockerfile from $dockerfile_template with R version $r_version"; then
            log_error "Failed to create Dockerfile"
            return 1
        fi
    fi

    # Note: .zshrc is copied directly from user's dotfiles (assumed to have OS conditionals)

    # Create comprehensive user guide in docs/ with symlink in root
    # Contains: detailed usage instructions, troubleshooting, best practices
    if ! install_template "ZZCOLLAB_USER_GUIDE.md" "docs/ZZCOLLAB_USER_GUIDE.md" "comprehensive user guide" "Created comprehensive user guide in docs/"; then
        log_error "Failed to create user guide"
        return 1
    fi

    # Create symlink in root for convenience
    if ln -sf "docs/ZZCOLLAB_USER_GUIDE.md" "ZZCOLLAB_USER_GUIDE.md"; then
        track_symlink "ZZCOLLAB_USER_GUIDE.md"
        log_debug "Created symlink to user guide in root"
    else
        log_warn "Failed to create user guide symlink (non-fatal)"
    fi
    
    log_success "Docker configuration files created successfully"
}

#=============================================================================
# DOCKER IMAGE BUILDING (extracted from lines 648-694)
#=============================================================================

# Function: build_docker_image
# Purpose: Build Docker image for the research project with comprehensive error handling
# Features:
#   - Platform detection (ARM64/AMD64 compatibility)
#   - BuildKit optimization
#   - Comprehensive validation
#   - Detailed error reporting
#   - Manual fallback instructions
#
# Prerequisites: Docker installed, Dockerfile exists, R_VERSION and PKG_NAME set
# Platform Handling: Automatically adds --platform linux/amd64 for ARM64 systems
# Error Handling: Provides manual build command on failure
build_docker_image() {
    log_info "Building Docker environment..."
    log_info "This may take several minutes on first build..."
    
    # Validate Docker installation and availability
    if ! command_exists docker; then
        log_error "Docker is not installed or not in PATH"
        log_error "Install Docker Desktop from https://www.docker.com/products/docker-desktop"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        log_error "Start Docker Desktop and try again"
        return 1
    fi
    
    # Validate that Dockerfile exists
    if [[ ! -f "Dockerfile" ]]; then
        log_error "Dockerfile not found in current directory"
        log_error "Run the setup script to create Docker configuration files"
        return 1
    fi
    
    # Validate required environment variables
    if [[ -z "${R_VERSION:-}" ]]; then
        log_error "R_VERSION is not set"
        log_error "This should be set automatically by create_docker_files()"
        return 1
    fi
    
    if [[ -z "${PKG_NAME:-}" ]]; then
        log_error "PKG_NAME is not set"
        log_error "This should be set automatically from directory name"
        return 1
    fi

    # Update renv.lock to use r2u renv version from Docker base image
    # This prevents compiling renv from source (~7s) and uses binary (~0.1s)
    if [[ -n "${BASE_IMAGE:-}" ]]; then
        local full_base_image="${BASE_IMAGE}:${R_VERSION}"
        update_renv_version_from_docker "$full_base_image" || log_warn "Could not update renv version"
    fi

    # Auto-detect platform and set appropriate Docker build arguments
    # Use new multi-architecture support functions
    local DOCKER_PLATFORM
    DOCKER_PLATFORM=$(get_docker_platform_args "$BASE_IMAGE")
    
    if [[ -n "$DOCKER_PLATFORM" ]]; then
        log_info "Using platform override: $DOCKER_PLATFORM"
        log_info "This ensures compatibility with images that may not support native architecture"
    else
        log_info "Using native platform for architecture: $(uname -m)"
    fi
    
    # Build the Docker command with all necessary arguments
    # DOCKER_BUILDKIT=1: Enable BuildKit for faster builds and better caching
    # --build-arg R_VERSION: Pass R version to Dockerfile
    # --build-arg BASE_IMAGE: Pass base image to Dockerfile
    # -t "$PKG_NAME": Tag image with package name for easy reference

    log_info "Using Docker profile: ${PROFILE_NAME:-${ZZCOLLAB_DEFAULT_PROFILE_NAME}}"

    # Extract RENV_VERSION from renv.lock if it exists
    local RENV_VERSION="1.0.11"  # Default fallback
    if [[ -f "renv.lock" ]] && command -v jq &>/dev/null; then
        RENV_VERSION=$(jq -r '.Packages.renv.Version // "1.0.11"' renv.lock 2>/dev/null || echo "1.0.11")
        log_info "Using renv version from renv.lock: $RENV_VERSION"
    else
        log_info "Using default renv version: $RENV_VERSION"
    fi

    local docker_cmd="DOCKER_BUILDKIT=1 docker build ${DOCKER_PLATFORM} --build-arg R_VERSION=\"$R_VERSION\" --build-arg RENV_VERSION=\"$RENV_VERSION\" --build-arg BASE_IMAGE=\"$BASE_IMAGE\" -t \"$PKG_NAME\" ."
    
    log_info "Running: $docker_cmd"
    
    # Execute Docker build with comprehensive error handling
    if eval "$docker_cmd"; then
        # Track successful Docker image creation for uninstall capability
        track_docker_image "$PKG_NAME"
        
        log_success "Docker image '$PKG_NAME' built successfully!"
        log_success "You can now use Docker commands:"
        log_info "  docker run -it --rm $PKG_NAME R         # Interactive R session"
        log_info "  docker-compose up rstudio              # RStudio Server (http://localhost:8787)"
        log_info "  make docker-rstudio                    # Alternative RStudio launch"
    else
        # Detailed error reporting and recovery instructions
        log_error "Docker build failed"
        log_error ""
        log_error "TROUBLESHOOTING STEPS:"
        log_error "1. Check Docker Desktop is running"
        log_error "2. Ensure you have sufficient disk space (>2GB free)"
        log_error "3. Try building manually with verbose output:"
        log_error "   $docker_cmd"
        log_error ""
        log_error "If the build continues to fail:"
        log_error "1. Check the Dockerfile for syntax errors"
        log_error "2. Try building with no cache: docker build --no-cache ..."
        log_error "3. Check Docker logs for specific error messages"
        log_error "4. Consult ZZCOLLAB_USER_GUIDE.md for additional troubleshooting"
        
        return 1
    fi
}

#=============================================================================
# DOCKER UTILITIES AND VALIDATION
#=============================================================================

##############################################################################
# FUNCTION: validate_docker_environment
# PURPOSE:  Comprehensive validation of Docker setup and configuration
# USAGE:    validate_docker_environment
# ARGS:     
#   None
# RETURNS:  
#   0 - All Docker environment validations passed
#   1 - One or more validations failed
# GLOBALS:  
#   READ:  PKG_NAME (for image name validation)
#   WRITE: None (outputs validation messages)
# DESCRIPTION:
#   This function performs a comprehensive health check of the Docker development
#   environment, validating that all necessary components are properly installed,
#   configured, and ready for use. It's typically called before attempting Docker
#   operations to provide early failure detection and helpful error messages.
# VALIDATION STEPS:
#   1. Docker command availability and installation
#   2. Docker daemon running status
#   3. Required configuration files existence
#   4. Docker image build status
# FILES CHECKED:
#   - Dockerfile (container definition)
#   - .zshrc_docker (container shell configuration)
# EXAMPLE:
#   if validate_docker_environment; then
#       echo "Docker environment ready"
#   else
#       echo "Docker environment needs setup"
#   fi
##############################################################################
validate_docker_environment() {
    # Check Docker installation and daemon
    if ! validate_commands_exist "Docker environment" "docker"; then
        return 1
    fi
    
    # Check Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    # Check required files
    local -r required_files=(
        "Dockerfile"
        ".zshrc_docker"
    )
    
    if ! validate_files_exist "Docker configuration" "${required_files[@]}"; then
        return 1
    fi
    
    # Check if image exists
    if docker image inspect "$PKG_NAME" >/dev/null 2>&1; then
        log_success "Docker image '$PKG_NAME' exists and ready to use"
    else
        echo "Docker image '$PKG_NAME' not built yet - run build_docker_image()"
    fi
    
    return 0
}

##############################################################################
# FUNCTION: show_docker_summary
# PURPOSE:  Display comprehensive Docker environment summary and usage instructions
# USAGE:    show_docker_summary
# ARGS:     
#   None
# RETURNS:  
#   0 - Always succeeds
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs formatted summary to stdout)
# DESCRIPTION:
#   This function provides a comprehensive overview of the Docker development
#   environment that has been created, including file structure, available services,
#   common commands, and troubleshooting information. It serves as both documentation
#   and quick reference for users.
# OUTPUT SECTIONS:
#   - File structure: Shows all created Docker configuration files
#   - Container services: Lists available Docker Compose services
#   - Common commands: Most frequently used make/docker commands
#   - Credentials: Default login information for services
#   - Troubleshooting: Common issues and solutions
# EXAMPLE:
#   show_docker_summary  # Display complete environment overview
##############################################################################
show_docker_summary() {
    log_info "Docker environment summary:"
    cat << 'EOF'
🐳 DOCKER ENVIRONMENT CREATED:

├── Dockerfile                      # Main container definition
├── .zshrc_docker                   # Container shell configuration
├── validate_package_environment.R  # Package validation script
└── ZZCOLLAB_USER_GUIDE.md         # Comprehensive documentation

🚀 MAKEFILE TARGETS:
- make docker-build    → Build Docker image
- make docker-rstudio  → RStudio Server (http://localhost:8787)
- make docker-r        → Interactive R session
- make docker-zsh      → Development shell (zsh)
- make docker-bash     → Development shell (bash)

🔧 COMMON COMMANDS:
- make docker-build          # Build Docker image
- make docker-rstudio        # Start RStudio Server
- make docker-r              # Interactive R console
- make docker-bash           # Bash shell in container
- make docker-render         # Render research paper
- make docker-test           # Run package tests

📝 CREDENTIALS:
- RStudio Server: user 'analyst', password 'analyst'
- Container working directory: /home/analyst/project
- Data persistence: via Docker volumes

🔍 TROUBLESHOOTING:
- Check Docker Desktop is running
- Ensure sufficient disk space (>2GB)
- See ZZCOLLAB_USER_GUIDE.md for detailed help
EOF
}

#=============================================================================
# DOCKER MODULE VALIDATION
#=============================================================================

# Validate that required variables are available
if [[ -z "${PKG_NAME:-}" ]]; then
    log_warn "PKG_NAME not defined - Docker image naming may fail"
fi

if [[ -z "${BASE_IMAGE:-}" ]]; then
    export BASE_IMAGE="rocker/r-ver"
    log_info "BASE_IMAGE not defined - using default: $BASE_IMAGE"
fi


