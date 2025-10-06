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

##############################################################################
# FUNCTION: get_multiarch_base_image
# PURPOSE:  Select appropriate Docker base image based on architecture and requirements
# USAGE:    get_multiarch_base_image "variant_name"
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
# DOCKER TEMPLATE SELECTION
#=============================================================================

##############################################################################
# FUNCTION: get_dockerfile_template
# PURPOSE:  Select appropriate Dockerfile template based on build mode
# USAGE:    get_dockerfile_template
# ARGS:     
#   None (uses global BUILD_MODE variable)
# RETURNS:  
#   0 - Always succeeds, outputs template filename
# GLOBALS:  
#   READ:  BUILD_MODE (fast|standard|comprehensive)
#   WRITE: None (outputs to stdout)
# DESCRIPTION:
#   This function maps build modes to their corresponding Dockerfile templates.
#   The unified Dockerfile system uses a single template with build arguments
#   to control package installation, replacing the previous multiple template approach.
# TEMPLATE MAPPING:
#   - All modes: "Dockerfile.unified" (single template with PACKAGE_MODE arg)
#   - Legacy support maintained for backward compatibility
# EXAMPLE:
#   template=$(get_dockerfile_template)
#   echo "Using template: $template"
##############################################################################
get_dockerfile_template() {
    # Use unified Dockerfile template for all build modes
    # The template uses PACKAGE_MODE build argument to control package installation
    echo "Dockerfile.unified"
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
        minimal)
            log_info "Using minimal Dockerfile template for ultra-fast builds (~30 seconds)"
            ;;
        fast)
            log_info "Using fast Dockerfile template for rapid builds (2-3 minutes)"
            ;;
        comprehensive)
            log_info "Using extended Dockerfile template with comprehensive packages (15-20 minutes)"
            ;;
        *)
            log_info "Using standard Dockerfile template (4-6 minutes)"
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
    
    # Create package environment validation script
    # Used by: CI/CD workflows, development workflow validation
    # Purpose: Ensures package dependencies are properly synchronized across CRAN, Bioconductor, and GitHub
    if ! install_template "validate_package_environment.R" "validate_package_environment.R" "package validation script" "Created package environment validation script"; then
        log_error "Failed to create package environment validation script"
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
    # --build-arg PACKAGE_MODE: Pass build mode to unified Dockerfile (fast/standard/comprehensive)
    # -t "$PKG_NAME": Tag image with package name for easy reference
    
    # Determine package selection mode based on build mode
    local package_mode="$BUILD_MODE"
    log_info "Using build mode: $BUILD_MODE"

    local docker_cmd="DOCKER_BUILDKIT=1 docker build ${DOCKER_PLATFORM} --build-arg R_VERSION=\"$R_VERSION\" --build-arg BASE_IMAGE=\"$BASE_IMAGE\" --build-arg PACKAGE_MODE=\"$package_mode\" -t \"$PKG_NAME\" ."
    
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
#   - docker-compose.yml (service orchestration)
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
├── docker-compose.yml              # Multi-service orchestration
├── .zshrc_docker                   # Container shell configuration
├── validate_package_environment.R  # Package validation script
└── ZZCOLLAB_USER_GUIDE.md         # Comprehensive documentation

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


