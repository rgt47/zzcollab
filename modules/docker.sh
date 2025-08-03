#!/bin/bash
##############################################################################
# ZZCOLLAB DOCKER MODULE
##############################################################################
# 
# PURPOSE: Docker integration and containerized development environment
#          - Docker configuration files (Dockerfile, docker-compose.yml)
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

# Function: get_multiarch_base_image
# Purpose: Select appropriate base image based on architecture and requirements
# Arguments: $1 - requested variant (r-ver, rstudio, verse, etc.)
# Returns: Multi-architecture compatible base image name
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

# Function: get_docker_platform_args
# Purpose: Get platform arguments for Docker build/run commands
# Arguments: $1 - base image name (optional)
# Returns: Platform arguments for Docker commands
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
# Returns: R version string (e.g., "4.3.1") or "latest" if not found
# 
# Process:
#   1. Check if renv.lock exists and python3 is available
#   2. Parse JSON to extract R.Version field
#   3. Fall back to "latest" if parsing fails or file doesn't exist
#
# Used by: Docker build process to ensure container matches project R version
# Dependencies: python3 (for JSON parsing), renv.lock file (optional)
extract_r_version_from_lockfile() {
    # Check if renv.lock file exists and python3 is available for JSON parsing
    if [[ -f "renv.lock" ]] && command_exists python3; then
        log_info "Extracting R version from renv.lock..."
        
        # Use Python to parse JSON and extract R version
        # This approach is more reliable than bash JSON parsing
        local r_version
        r_version=$(python3 -c "
import json
try:
    with open('renv.lock', 'r') as f:
        data = json.load(f)
        print(data.get('R', {}).get('Version', 'latest'))
except:
    print('latest')
" 2>/dev/null)
        
        # Validate the extracted version
        if [[ -n "$r_version" ]] && [[ "$r_version" != "latest" ]]; then
            log_info "Found R version in lockfile: $r_version"
            echo "$r_version"
        else
            log_info "Could not extract R version from lockfile, using 'latest'"
            echo "latest"
        fi
    else
        # Fallback when renv.lock doesn't exist or python3 not available
        if [[ ! -f "renv.lock" ]]; then
            log_info "No renv.lock file found, using R version 'latest'"
        else
            log_info "python3 not available for JSON parsing, using R version 'latest'"
        fi
        echo "latest"
    fi
}

#=============================================================================
# DOCKER CONFIGURATION FILES CREATION (extracted from lines 481-506)
#=============================================================================

# Function: create_docker_files
# Purpose: Creates all Docker configuration files and support scripts
# Creates:
#   - Dockerfile (main container definition)
#   - docker-compose.yml (multi-service container orchestration)
#   - .zshrc_docker (container shell configuration)
#   - check_renv_for_commit.R (package validation script)
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
    
    # Determine R version for Docker build
    # This ensures the container uses the same R version as the project
    local r_version="latest"
    if [[ -f "renv.lock" ]]; then
        r_version=$(extract_r_version_from_lockfile)
        log_info "Using R version from lockfile: $r_version"
    else
        log_info "No renv.lock found, using R version: $r_version"
    fi
    
    # Export R_VERSION for template substitution
    # This variable is used in Dockerfile template
    export R_VERSION="$r_version"
    
    # Create Dockerfile from template
    # Choose template based on build mode (with legacy compatibility)
    local dockerfile_template
    dockerfile_template=$(get_dockerfile_template)
    
    case "$BUILD_MODE" in
        fast)
            log_info "Using minimal Dockerfile template for fastest builds"
            ;;
        comprehensive)
            log_info "Using extended Dockerfile template with comprehensive packages"
            ;;
        *)
            log_info "Using standard Dockerfile template"
            ;;
    esac
    
    # Contains: R environment, system dependencies, development tools, project setup
    if ! install_template "$dockerfile_template" "Dockerfile" "Dockerfile" "Created Dockerfile from $dockerfile_template with R version $r_version"; then
        log_error "Failed to create Dockerfile"
        return 1
    fi
    
    # Create docker-compose.yml from template
    # Defines: rstudio service, development services, volume mounts, networking
    if ! install_template "docker-compose.yml" "docker-compose.yml" "Docker Compose configuration" "Created Docker Compose configuration"; then
        log_error "Failed to create docker-compose.yml"
        return 1
    fi
    
    # Create .zshrc_docker for container shell configuration
    # Provides: custom prompt, aliases, development tools setup in container
    if ! install_template ".zshrc_docker" ".zshrc_docker" "zsh configuration for Docker container" "Created container shell configuration"; then
        log_error "Failed to create .zshrc_docker"
        return 1
    fi
    
    # Create renv validation script
    # Used by: CI/CD workflows, development workflow validation
    # Purpose: Ensures package dependencies are properly synchronized
    if ! install_template "check_renv_for_commit.R" "check_renv_for_commit.R" "renv validation script" "Created renv validation script"; then
        log_error "Failed to create renv validation script"
        return 1
    fi
    
    # Create comprehensive user guide
    # Contains: detailed usage instructions, troubleshooting, best practices
    if ! install_template "ZZCOLLAB_USER_GUIDE.md" "ZZCOLLAB_USER_GUIDE.md" "comprehensive user guide" "Created comprehensive user guide"; then
        log_error "Failed to create user guide"
        return 1
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
    # --build-arg PACKAGE_MODE: Pass package mode to unified Dockerfile
    # -t "$PKG_NAME": Tag image with package name for easy reference
    local docker_cmd="DOCKER_BUILDKIT=1 docker build ${DOCKER_PLATFORM} --build-arg R_VERSION=\"$R_VERSION\" --build-arg BASE_IMAGE=\"$BASE_IMAGE\" --build-arg PACKAGE_MODE=\"$BUILD_MODE\" -t \"$PKG_NAME\" ."
    
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

# Function: validate_docker_environment
# Purpose: Comprehensive validation of Docker setup and configuration
# Checks: Docker installation, daemon status, required files, image existence
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
        "docker-compose.yml"
        ".zshrc_docker"
    )
    
    if ! validate_files_exist "Docker configuration" "${required_files[@]}"; then
        return 1
    fi
    
    # Check if image exists
    if docker image inspect "$PKG_NAME" >/dev/null 2>&1; then
        log_success "Docker image '$PKG_NAME' exists and ready to use"
    else
        log_info "Docker image '$PKG_NAME' not built yet - run build_docker_image()"
    fi
    
    return 0
}

# Function: show_docker_summary
# Purpose: Display Docker setup summary and usage instructions
show_docker_summary() {
    log_info "Docker environment summary:"
    cat << 'EOF'
🐳 DOCKER ENVIRONMENT CREATED:

├── Dockerfile                    # Main container definition
├── docker-compose.yml           # Multi-service orchestration
├── .zshrc_docker                # Container shell configuration
├── check_renv_for_commit.R      # Package validation script
└── ZZCOLLAB_USER_GUIDE.md      # Comprehensive documentation

🚀 CONTAINER SERVICES:
- rstudio    → RStudio Server (http://localhost:8787)
- r-console  → Interactive R session
- dev        → Development shell with tools
- render     → Paper rendering service
- test       → Package testing service

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


