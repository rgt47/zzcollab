#!/bin/bash
##############################################################################
# ZZCOLLAB TEAM INITIALIZATION MODULE
##############################################################################
# 
# PURPOSE: Team setup and initialization workflows
#          - Team Docker image building and publishing
#          - Project directory setup and structure
#          - GitHub repository creation and initial commit
#          - Multi-step automated team workflow
#
# DEPENDENCIES: core.sh (logging), templates.sh (file creation)
#
# TRACKING: All created files and images are tracked for uninstall capability
##############################################################################

# Validate required modules are loaded
# Validate required modules are loaded
require_module "core"

#=============================================================================
# TEAM INITIALIZATION VALIDATION FUNCTIONS
#=============================================================================

# Function: validate_init_prerequisites
# Purpose: Validate that all required tools and accounts are available
# Checks: Docker, gh CLI, Docker Hub access, GitHub access
validate_init_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check Docker
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker Desktop."
        print_error "Download from: https://www.docker.com/products/docker-desktop"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker Desktop."
        return 1
    fi
    
    # Warn about seccomp profile (not fatal)
    if docker info 2>/dev/null | grep -q "seccomp.*default"; then
        : # Profile is default, all good
    else
        print_warning "daemon is not using the default seccomp profile"
    fi
    
    # Check Docker Hub login
    if docker info 2>/dev/null | grep -q "Username:"; then
        log_success "Docker Hub: logged in"
    else
        print_warning "Docker Hub login status unclear. You may need to run: docker login"
    fi
    
    # Check GitHub CLI
    if ! command_exists gh; then
        print_error "GitHub CLI (gh) is not installed. Please install it."
        print_error "Install: brew install gh  (macOS) or see https://cli.github.com/"
        return 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        print_error "GitHub CLI is not authenticated. Please run: gh auth login"
        return 1
    fi
    
    log_info "Verifying Docker Hub account: $TEAM_NAME"
    if ! docker search "$TEAM_NAME" >/dev/null 2>&1; then
        print_warning "Could not verify Docker Hub account '$TEAM_NAME'"
        print_warning "Make sure the account exists and you have push access"
    else
        print_success "Docker Hub account '$TEAM_NAME' verified"
    fi
    
    log_info "Verifying GitHub account: $GITHUB_ACCOUNT"
    if ! gh api "users/$GITHUB_ACCOUNT" >/dev/null 2>&1; then
        print_error "GitHub account '$GITHUB_ACCOUNT' not found or not accessible"
        return 1
    else
        print_success "GitHub account '$GITHUB_ACCOUNT' verified"
    fi
    
    print_success "All prerequisites validated"
    return 0
}

# Function: validate_required_team_parameters
# Purpose: Validate required team and project name parameters
validate_required_team_parameters() {
    # Check required team name
    if [[ -z "$TEAM_NAME" ]]; then
        print_error "Required parameter --team-name is missing"
        show_init_help
        exit 1
    fi

    # Check or infer project name
    if [[ -z "$PROJECT_NAME" ]]; then
        local current_dir
        current_dir=$(basename "$PWD")
        local file_count
        file_count=$(find . -maxdepth 1 -type f | wc -l)
        
        if [[ $file_count -le 3 ]]; then
            PROJECT_NAME="$current_dir"
            log_info "Inferred project name from current directory: $PROJECT_NAME"
        else
            if [[ "$current_dir" == "zzcollab" ]]; then
                print_error "Cannot infer project name from zzcollab source directory"
                print_error "Please specify --project-name or run from a different directory"
                show_init_help
                exit 1
            else
                print_error "Required parameter --project-name is missing"
                show_init_help
                exit 1
            fi
        fi
    fi
}

# Function: set_init_parameter_defaults
# Purpose: Set default values for optional parameters
set_init_parameter_defaults() {
    # Set default GitHub account to team name
    if [[ -z "$GITHUB_ACCOUNT" ]]; then
        GITHUB_ACCOUNT="$TEAM_NAME"
        log_info "Using default GitHub account: $GITHUB_ACCOUNT"
    fi
    
    # Set default Dockerfile path to unified template
    if [[ -z "$DOCKERFILE_PATH" ]]; then
        DOCKERFILE_PATH="$SCRIPT_DIR/templates/Dockerfile.unified"
        log_info "Using unified Dockerfile template: $DOCKERFILE_PATH"
    fi
}

# Function: validate_dotfiles_configuration
# Purpose: Validate dotfiles directory and set up configuration
validate_dotfiles_configuration() {
    if [[ -n "$DOTFILES_DIR" ]]; then
        # Expand tilde in DOTFILES_DIR for validation
        local expanded_dotfiles="${DOTFILES_DIR/#\~/$HOME}"

        if [[ ! -d "$expanded_dotfiles" ]]; then
            print_error "Dotfiles directory not found: $DOTFILES_DIR (expanded: $expanded_dotfiles)"
            exit 1
        fi
        USE_DOTFILES=true
        if [[ "$DOTFILES_NODOT" == "true" ]]; then
            log_info "Using dotfiles from: $expanded_dotfiles (files need dots added)"
        else
            log_info "Using dotfiles from: $expanded_dotfiles (files already have dots)"
        fi
    else
        log_info "No dotfiles specified, proceeding without dotfiles integration"
    fi
}

# Function: validate_init_parameters
# Purpose: Validate required parameters for team initialization (coordinating function)
# Checks: TEAM_NAME, PROJECT_NAME, directory state
validate_init_parameters() {
    validate_required_team_parameters
    set_init_parameter_defaults
    validate_dotfiles_configuration
    return 0
}

#=============================================================================
# TEAM PROJECT STRUCTURE FUNCTIONS  
#=============================================================================

# Function: create_project_structure
# Purpose: Create and set up the project directory structure
create_project_structure() {
    print_status "Step 1: Setting up project directory..."
    local current_dir
    current_dir=$(basename "$PWD")
    
    if [[ "$current_dir" == "$PROJECT_NAME" ]]; then
        # Already in the target directory
        print_status "Using current directory: $PROJECT_NAME"
    elif [[ -d "$PROJECT_NAME" ]]; then
        if [[ "$PREPARE_DOCKERFILE" == true ]]; then
            print_error "Directory $PROJECT_NAME already exists"
            print_error "Remove it first or run without --prepare-dockerfile to continue with existing project"
            exit 1
        else
            cd "$PROJECT_NAME" || exit 1
            print_status "Using existing directory: $PROJECT_NAME"
        fi
    else
        mkdir -p "$PROJECT_NAME"
        cd "$PROJECT_NAME" || exit 1
        print_success "Created project directory: $PROJECT_NAME"
    fi
}

# Function: setup_team_dockerfile
# Purpose: Copy and prepare Dockerfile template for team image building
setup_team_dockerfile() {
    print_status "Step 2: Setting up team Dockerfile..."
    if [[ ! -f "$DOCKERFILE_PATH" ]]; then
        print_error "Dockerfile template not found: $DOCKERFILE_PATH"
        exit 1
    fi

    if [[ ! -f "./Dockerfile.teamcore" ]]; then
        cp "$DOCKERFILE_PATH" ./Dockerfile.teamcore
        print_success "Copied Dockerfile template to Dockerfile.teamcore"
    else
        if [[ "$PREPARE_DOCKERFILE" == true ]]; then
            print_status "Dockerfile.teamcore already exists - you can edit it directly"
        else
            print_status "Using existing Dockerfile.teamcore"
        fi
    fi
    
    # Always copy config.yaml template for teams to have the option
    if [[ ! -f "./config.yaml" ]]; then
        local config_template="${TEMPLATES_DIR}/config.yaml"
        if [[ -f "$config_template" ]]; then
            # Substitute variables in config template
            sed -e "s/\${TEAM_NAME}/$TEAM_NAME/g" \
                -e "s/\${PROJECT_NAME}/$PROJECT_NAME/g" \
                -e "s/\${AUTHOR_NAME}/${AUTHOR_NAME:-Team}/g" \
                -e "s/\${AUTHOR_EMAIL}/${AUTHOR_EMAIL:-team@example.com}/g" \
                -e "s/\${CREATION_DATE}/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" \
                "$config_template" > ./config.yaml
            print_success "Created config.yaml with predefined profiles"

            # Copy profiles.yaml library if it exists
            local profile_library="${TEMPLATES_DIR}/profiles.yaml"
            if [[ -f "$profile_library" ]] && [[ ! -f "./profiles.yaml" ]]; then
                cp "$profile_library" ./profiles.yaml
                print_success "Copied profile library: profiles.yaml"
            fi

            # Check if config.yaml has use_config_profiles enabled
            if command -v yq >/dev/null 2>&1; then
                local use_config_profiles
                use_config_profiles=$(yq eval '.build.use_config_profiles // false' ./config.yaml 2>/dev/null)
                if [[ "$use_config_profiles" == "true" ]]; then
                    print_status "🎯 Config profiles enabled by default - will use config.yaml for building"
                    USE_CONFIG_PROFILES=true
                    PROFILES_CONFIG="./config.yaml"
                else
                    print_status "💡 Edit config.yaml to customize profiles (set use_config_profiles: true to enable)"
                fi
            else
                print_status "💡 Edit config.yaml to customize profiles or install yq for automatic detection"
            fi
        else
            print_error "Config template not found: $config_template"
            return 1
        fi
    elif [[ "${USE_CONFIG_PROFILES:-false}" != "true" ]] && command -v yq >/dev/null 2>&1; then
        # Check existing config.yaml for use_config_profiles setting
        local use_config_profiles
        use_config_profiles=$(yq eval '.build.use_config_profiles // false' ./config.yaml 2>/dev/null)
        if [[ "$use_config_profiles" == "true" ]]; then
            print_status "🎯 Detected config.yaml with use_config_profiles: true - enabling config-based profiles"
            USE_CONFIG_PROFILES=true
            PROFILES_CONFIG="./config.yaml"
        fi
    fi

    # If --prepare-dockerfile, exit here for manual editing
    if [[ "$PREPARE_DOCKERFILE" == true ]]; then
        print_success "Project prepared for Dockerfile editing"
        echo ""
        print_status "Next steps:"
        echo "  1. Edit $(pwd)/Dockerfile.teamcore as needed"
        echo "  2. Test build: docker build -f Dockerfile.teamcore -t test-image ."
        echo "  3. Re-run setup: $0 -i -t $TEAM_NAME -p $PROJECT_NAME"
        echo ""
        print_status "Example build command for testing:"
        echo "     docker build -f Dockerfile.teamcore -t test-image ."
        exit 0
    fi
}

# Function: create_basic_files
# Purpose: Create minimal project files needed for Docker build
create_basic_files() {
    print_status "Step 3: Creating basic project structure..."
    
    # Create basic files needed for Docker build
    # We need to create minimal versions of files that the Dockerfile expects
    
    # Create minimal DESCRIPTION file
    if [[ ! -f "DESCRIPTION" ]]; then
        cat > DESCRIPTION << EOF
Package: ${PROJECT_NAME}
Title: Research Compendium for ${PROJECT_NAME}
Version: 0.0.0.9000
Authors@R: 
    person("Team Lead", email = "lead@example.com", role = c("aut", "cre"))
Description: This is a research compendium for the ${PROJECT_NAME} project.
License: GPL-3
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.2.0
Imports:
    here,
    renv
Suggests: 
    testthat (>= 3.0.0),
    knitr,
    rmarkdown
Config/testthat/edition: 3
VignetteBuilder: knitr
EOF
        print_success "Created basic DESCRIPTION file"
    fi
    
    # Create minimal .zshrc_docker file
    if [[ ! -f ".zshrc_docker" ]]; then
        cat > .zshrc_docker << 'EOF'
# Basic zsh configuration for Docker container
# This is a minimal version for team image building
export PS1="%F{blue}%n@%m%f:%F{green}%~%f$ "
EOF
        print_success "Created basic .zshrc_docker file"
    fi
}

#=============================================================================
# DOCKER IMAGE BUILDING FUNCTIONS
#=============================================================================

# Function: build_team_images
# Purpose: Build core images for the team based on INIT_BASE_IMAGE selection or config.yaml
build_team_images() {
    local step_counter=4
    
    # Check if using config-based profiles
    if [[ "${USE_CONFIG_PROFILES:-false}" == "true" ]]; then
        print_status "Step $step_counter: Building profiles from configuration..."
        
        # Default to config.yaml if no specific file provided
        local config_file="${PROFILES_CONFIG:-config.yaml}"
        
        if parse_config_profiles "$config_file"; then
            print_success "✅ All configured profiles built successfully"
        else
            print_error "❌ Failed to build some configured profiles"
            return 1
        fi
        return 0
    fi
    
    # Legacy mode: build based on INIT_BASE_IMAGE flag
    print_status "Step $step_counter: Building images using legacy mode..."
    case "$INIT_BASE_IMAGE" in
        "r-ver")
            print_status "Step $step_counter: Building shell core image..."
            build_single_team_image "rocker/r-ver" "shell"
            print_success "Built shell core image: ${TEAM_NAME}/${PROJECT_NAME}_core-shell:v1.0.0"
            ;;
        "rstudio")
            print_status "Step $step_counter: Building RStudio core image..."
            build_single_team_image "rocker/rstudio" "rstudio"
            print_success "Built RStudio core image: ${TEAM_NAME}/${PROJECT_NAME}_core-rstudio:v1.0.0"
            ;;
        "verse")
            print_status "Step $step_counter: Building verse core image..."
            local verse_image
            verse_image=$(get_multiarch_base_image "verse")
            build_single_team_image "$verse_image" "verse"
            print_success "Built verse core image: ${TEAM_NAME}/${PROJECT_NAME}_core-verse:v1.0.0"
            ;;
        "all")
            # Build all three variants (r-ver, rstudio, verse)
            print_status "Step $step_counter: Building shell core image..."
            build_single_team_image "rocker/r-ver" "shell"
            print_success "Built shell core image: ${TEAM_NAME}/${PROJECT_NAME}_core-shell:v1.0.0"
            
            ((step_counter++))
            print_status "Step $step_counter: Building RStudio core image..."
            build_single_team_image "rocker/rstudio" "rstudio"
            print_success "Built RStudio core image: ${TEAM_NAME}/${PROJECT_NAME}_core-rstudio:v1.0.0"
            
            ((step_counter++))
            print_status "Step $step_counter: Building verse core image..."
            local verse_image
            verse_image=$(get_multiarch_base_image "verse")
            build_single_team_image "$verse_image" "verse"
            print_success "Built verse core image: ${TEAM_NAME}/${PROJECT_NAME}_core-verse:v1.0.0"
            ;;
        *)
            print_error "Invalid INIT_BASE_IMAGE: $INIT_BASE_IMAGE"
            exit 1
            ;;
    esac
}

# Function: build_single_team_image
# Purpose: Build a single team core image with specified base
# Arguments: $1 = base image (e.g. rocker/r-ver), $2 = variant name (e.g. shell), $3 = dockerfile path, $4 = build context
build_single_team_image() {
    local base_image="$1"
    local variant="$2"
    local dockerfile="${3:-Dockerfile.teamcore}"
    local context="${4:-.}"
    
    docker build -f "$dockerfile" \
        --build-arg BASE_IMAGE="$base_image" \
        --build-arg TEAM_NAME="$TEAM_NAME" \
        --build-arg PROJECT_NAME="$PROJECT_NAME" \
        --build-arg PACKAGE_MODE="$BUILD_MODE" \
        -t "${TEAM_NAME}/${PROJECT_NAME}_core-${variant}:v1.0.0" "$context"

    docker tag "${TEAM_NAME}/${PROJECT_NAME}_core-${variant}:v1.0.0" \
        "${TEAM_NAME}/${PROJECT_NAME}_core-${variant}:latest"
}

# Function: push_team_images
# Purpose: Push team images to Docker Hub based on what was built
push_team_images() {
    local step_counter=5
    if [[ "$INIT_BASE_IMAGE" == "all" ]]; then
        step_counter=7  # Adjust for three builds
    fi

    print_status "Step $step_counter: Pushing images to Docker Hub..."

    # Check if we're using config-based profiles
    if [[ -f "./config.yaml" ]] && grep -q "use_config_profiles: true" ./config.yaml 2>/dev/null; then
        log_info "Pushing profile images from config.yaml..."

        # Get enabled profiles from config.yaml
        local enabled_variants=$(yq eval '.profiles | to_entries | .[] | select(.value.enabled == true) | .key' ./config.yaml 2>/dev/null)

        if [[ -z "$enabled_variants" ]]; then
            log_warn "No enabled profiles found in config.yaml"
            return 0
        fi

        # Push each enabled variant
        while IFS= read -r variant; do
            [[ -z "$variant" ]] && continue
            log_info "Pushing profile: $variant"
            docker push "${TEAM_NAME}/${PROJECT_NAME}_core-${variant}:v1.0.0" || log_warn "Failed to push ${variant}:v1.0.0"
            docker push "${TEAM_NAME}/${PROJECT_NAME}_core-${variant}:latest" || log_warn "Failed to push ${variant}:latest"
        done <<< "$enabled_variants"
    else
        # Legacy base image push
        case "$INIT_BASE_IMAGE" in
            "r-ver")
                push_single_team_image "shell"
                ;;
            "rstudio")
                push_single_team_image "rstudio"
                ;;
            "verse")
                push_single_team_image "verse"
                ;;
            "all")
                push_single_team_image "shell"
                push_single_team_image "rstudio"
                push_single_team_image "verse"
                ;;
        esac
    fi

    print_success "Pushed all images to Docker Hub"
}

# Function: push_single_team_image
# Purpose: Push a single team image variant to Docker Hub
# Arguments: $1 = variant name (e.g. shell, rstudio, verse)
push_single_team_image() {
    local variant="$1"
    docker push "${TEAM_NAME}/${PROJECT_NAME}_core-${variant}:v1.0.0"
    docker push "${TEAM_NAME}/${PROJECT_NAME}_core-${variant}:latest"
}

#=============================================================================
# PROJECT INITIALIZATION FUNCTIONS
#=============================================================================

# Function: initialize_full_project
# Purpose: Run full zzcollab setup with team base image
initialize_full_project() {
    print_status "Step 7: Initializing full zzcollab project..."
    
    # Prepare zzcollab arguments - select appropriate base image
    local base_variant
    case "$INIT_BASE_IMAGE" in
        "r-ver")
            base_variant="shell"
            ;;
        "rstudio")
            base_variant="rstudio"
            ;;
        "verse")
            base_variant="verse"
            ;;
        "all")
            base_variant="shell"  # Default to shell for personal development
            ;;
    esac
    local ZZCOLLAB_ARGS="--base-image ${TEAM_NAME}/${PROJECT_NAME}_core-${base_variant}"
    if [[ "$USE_DOTFILES" == true ]]; then
        if [[ "$DOTFILES_NODOT" == "true" ]]; then
            ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --dotfiles-nodot $DOTFILES_DIR"
        else
            ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --dotfiles $DOTFILES_DIR"
        fi
    fi
    
    # Add build mode based on current configuration
    case "$BUILD_MODE" in
        fast)
            ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --fast"
            ;;
        comprehensive)
            ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --comprehensive"
            ;;
        *)
            ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --standard"
            ;;
    esac
    
    # Run zzcollab setup (calling main script recursively but without --init)
    eval "$0 $ZZCOLLAB_ARGS"
    print_success "Initialized zzcollab project with custom base image"
}

#=============================================================================
# GIT AND GITHUB FUNCTIONS
#=============================================================================

# Function: setup_git_repository
# Purpose: Initialize git repository and create initial commit
setup_git_repository() {
    print_status "Step 8: Initializing git repository..."
    git init
    git add .
    git commit -m "🎉 Initial research project setup

- Complete zzcollab research compendium  
- Team core images published to Docker Hub: ${TEAM_NAME}/${PROJECT_NAME}_core:v1.0.0
- Private repository protects unpublished research
- CI/CD configured for automatic team image updates

🐳 Generated with zzcollab --init

Co-Authored-By: zzcollab <noreply@zzcollab.dev>"
    print_success "Initialized git repository with initial commit"
}

# Function: create_github_repository
# Purpose: Create private GitHub repository and push code
create_github_repository() {
    print_status "Step 9: Creating private GitHub repository..."

    # Check if repository already exists
    if gh repo view "${GITHUB_ACCOUNT}/${PROJECT_NAME}" >/dev/null 2>&1; then
        print_error "❌ Repository ${GITHUB_ACCOUNT}/${PROJECT_NAME} already exists on GitHub!"
        echo ""
        print_status "Options to resolve this:"
        echo "  1. Delete existing repository: gh repo delete ${GITHUB_ACCOUNT}/${PROJECT_NAME} --confirm"
        echo "  2. Use a different project name: --project-name PROJECT_NAME_V2"
        echo "  3. Manual setup: Skip automatic creation and push manually"
        echo ""
        print_status "If you want to push to existing repository:"
        echo "  git remote add origin https://github.com/${GITHUB_ACCOUNT}/${PROJECT_NAME}.git"
        echo "  git push origin main --force  # WARNING: This will overwrite existing content"
        echo ""
        exit 1
    fi

    # Create private repository
    gh repo create "${GITHUB_ACCOUNT}/${PROJECT_NAME}" \
        --private \
        --description "Research compendium for ${PROJECT_NAME} project" \
        --clone=false

    # Add remote and push
    git remote add origin "https://github.com/${GITHUB_ACCOUNT}/${PROJECT_NAME}.git"
    git branch -M main
    git push -u origin main

    print_success "Created private repository: https://github.com/${GITHUB_ACCOUNT}/${PROJECT_NAME}"
    print_success "🎉 Team setup complete!"
    echo ""
    print_status "Next steps for team members:"
    echo "  git clone https://github.com/${GITHUB_ACCOUNT}/${PROJECT_NAME}.git"
    echo "  cd ${PROJECT_NAME}"
    echo "  zzcollab -t ${TEAM_NAME} -p ${PROJECT_NAME} -I shell"
    echo ""
    print_status "Team images available:"
    echo "  ${TEAM_NAME}/${PROJECT_NAME}_core-shell:latest"
    echo "  ${TEAM_NAME}/${PROJECT_NAME}_core-rstudio:latest"
}

#=============================================================================
# YAML CONFIGURATION FUNCTIONS
#=============================================================================

# Function: parse_config_profiles
# Purpose: Parse variants from config.yaml and build enabled ones
parse_config_profiles() {
    local config_file="${1:-config.yaml}"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        print_error "Run with traditional flags or create config.yaml first."
        return 1
    fi
    
    # Check if yq is available for YAML parsing
    if ! command -v yq >/dev/null 2>&1; then
        print_error "yq is required for YAML configuration parsing"
        print_error "Install with: brew install yq (macOS) or apt install yq (Ubuntu)"
        print_error "Alternatively, use traditional command-line flags."
        return 1
    fi
    
    print_status "📋 Parsing profiles from $config_file..."
    
    # Get list of enabled profiles
    local enabled_variants
    enabled_variants=$(yq eval '.profiles | to_entries | map(select(.value.enabled == true)) | .[].key' "$config_file")
    
    if [[ -z "$enabled_variants" ]]; then
        print_warning "No enabled profiles found in $config_file"
        print_status "💡 Set 'enabled: true' for profiles you want to build"
        return 1
    fi
    
    print_status "Found enabled profiles: $(echo "$enabled_variants" | tr '\n' ' ')"
    
    # Build each enabled variant
    echo "$enabled_variants" | while read -r profile_name; do
        [[ -n "$profile_name" ]] || continue
        build_config_profile "$config_file" "$profile_name"
    done
}

# Function: build_config_profile
# Purpose: Build a single profile, merging from profiles.yaml if needed
build_config_profile() {
    local config_file="$1"
    local profile_name="$2"
    
    print_status "🐳 Building profile: $profile_name"
    
    # NEW: Check if variant has full definition or just enabled flag
    local has_full_definition
    has_full_definition=$(yq eval ".profiles.${profile_name}.base_image" "$config_file")
    
    local base_image description packages system_deps profile_library
    
    if [[ "$has_full_definition" == "null" || -z "$has_full_definition" ]]; then
        # Profile only has enabled flag - get definition from profiles.yaml
        profile_library=$(yq eval ".build.profile_library // \"profiles.yaml\"" "$config_file")
        
        if [[ ! -f "$profile_library" ]]; then
            print_error "❌ Profile library not found: $profile_library"
            return 1
        fi
        
        print_status "  🔗 Loading definition from $profile_library"
        base_image=$(yq eval ".${profile_name}.base_image" "$profile_library")
        description=$(yq eval ".${profile_name}.description" "$profile_library")
        packages=$(yq eval ".${profile_name}.packages[]" "$profile_library" | tr '\n' ' ')
        system_deps=$(yq eval ".${profile_name}.system_deps[]?" "$profile_library" | tr '\n' ' ')
        
        if [[ "$base_image" == "null" || -z "$base_image" ]]; then
            print_error "❌ Profile '$profile_name' not found in $profile_library"
            return 1
        fi
    else
        # Variant has full definition in config.yaml (legacy support)
        print_status "  📝 Using full definition from config.yaml"
        base_image=$(yq eval ".profiles.${profile_name}.base_image" "$config_file")
        description=$(yq eval ".profiles.${profile_name}.description" "$config_file")
        packages=$(yq eval ".profiles.${profile_name}.packages[]" "$config_file" | tr '\n' ' ')
        system_deps=$(yq eval ".profiles.${profile_name}.system_deps[]?" "$config_file" | tr '\n' ' ')
    fi
    
    print_status "  Base image: $base_image"
    print_status "  Description: $description"
    print_status "  Packages: $packages"
    [[ -n "$system_deps" ]] && print_status "  System deps: $system_deps"
    
    # Create temporary Dockerfile for this variant
    create_profile_dockerfile "$profile_name" "$base_image" "$packages" "$system_deps"
    
    # Build the Docker image
    local image_name="${TEAM_NAME}/${PROJECT_NAME}_core-${profile_name}"
    print_status "  Building: $image_name:latest"
    
    if docker build -f "Dockerfile.variant.${profile_name}" \
        --build-arg TEAM_NAME="$TEAM_NAME" \
        --build-arg PROJECT_NAME="$PROJECT_NAME" \
        --build-arg PROFILE_NAME="$profile_name" \
        --build-arg VARIANT_DESCRIPTION="$description" \
        -t "${image_name}:latest" \
        -t "${image_name}:v1.0.0" .; then
        
        print_success "✅ Built $profile_name variant: ${image_name}:latest"
        
        # Clean up temporary Dockerfile
        rm -f "Dockerfile.variant.${profile_name}"
    else
        print_error "❌ Failed to build $profile_name variant"
        return 1
    fi
}

# Function: create_profile_dockerfile
# Purpose: Generate Dockerfile for a specific variant
create_profile_dockerfile() {
    local profile_name="$1"
    local base_image="$2" 
    local packages="$3"
    local system_deps="$4"
    local dockerfile="Dockerfile.variant.${profile_name}"
    
    cat > "$dockerfile" << EOF
# Generated Dockerfile for variant: $profile_name
# Base: $base_image
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)

FROM $base_image

# Build arguments
ARG TEAM_NAME
ARG PROJECT_NAME
ARG PROFILE_NAME
ARG VARIANT_DESCRIPTION

# Labels for identification
LABEL org.zzcollab.team="\$TEAM_NAME"
LABEL org.zzcollab.project="\$PROJECT_NAME"
LABEL org.zzcollab.variant="\$PROFILE_NAME"
LABEL org.zzcollab.description="\$VARIANT_DESCRIPTION"
LABEL org.zzcollab.created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Install system dependencies if specified
EOF

    if [[ -n "$system_deps" ]]; then
        cat >> "$dockerfile" << EOF
RUN apt-get update && apt-get install -y \\
$(echo "$system_deps" | sed 's/ / \\\n    /g') \\
    && rm -rf /var/lib/apt/lists/*

EOF
    fi

    if [[ -n "$packages" ]]; then
        cat >> "$dockerfile" << EOF
# Install R packages
RUN install2.r --error --skipinstalled --ncpus -1 \\
$(echo "$packages" | sed 's/ / \\\n    /g') \\
    && rm -rf /tmp/downloaded_packages

EOF
    fi

    cat >> "$dockerfile" << EOF
# Set default user (will be overridden in personal Dockerfile)
ENV USER=rstudio

# Set working directory
WORKDIR /home/rstudio

# Default command
CMD ["/bin/bash"]
EOF

    print_status "  Generated: $dockerfile"
}

#=============================================================================
# BUILD VARIANT FUNCTIONS (Legacy for -V flag)
#=============================================================================

# Function: build_additional_profile
# Purpose: Build additional team image variants after initial setup using config system
# Arguments: $1 = comma-separated variant names (e.g., "rstudio,analysis,publishing")
build_additional_profile() {
    local profile_input="$1"

    # Parse comma-separated variants
    local variants=()
    while IFS= read -r variant; do
        variants+=("$variant")
    done < <(parse_profile_list "$profile_input" 2>/dev/null || echo "$profile_input")

    if [[ ${#variants[@]} -eq 0 ]]; then
        print_error "No profiles specified"
        exit 1
    fi


    # Check if we're in a zzcollab project directory with config.yaml
    local config_file="config.yaml"
    local working_dir="."

    if [[ ! -f "$config_file" ]]; then
        # Check if we're inside a project directory and can find config.yaml in parent
        if [[ -f ".zzcollab_team_setup" ]] || [[ -f ".zzcollab_manifest.json" ]] || [[ -f ".zzcollab_manifest.txt" ]]; then
            if [[ -f "../config.yaml" ]]; then
                print_status "📁 Running from project directory - using parent directory's config.yaml"
                config_file="../config.yaml"
                working_dir=".."
            else
                print_error "❌ config.yaml not found in parent directory!"
                print_error "The -V flag requires config.yaml for profile definitions."
                exit 1
            fi
        else
            print_error "❌ config.yaml not found."
            print_error "The -V flag must be run from either:"
            print_error "   1. The directory where 'zzcollab -i' was executed (contains config.yaml)"
            print_error "   2. Inside a zzcollab project directory (looks for ../config.yaml)"
            exit 1
        fi
    fi

    # Change to working directory for builds
    cd "$working_dir" || exit 1

    # Detect team and project names from config.yaml or directory
    if [[ -z "$TEAM_NAME" ]]; then
        TEAM_NAME=$(yq eval '.team.name' "$config_file" 2>/dev/null)
        if [[ -z "$TEAM_NAME" || "$TEAM_NAME" == "null" ]]; then
            # Try to detect from Docker images
            if docker images --format "{{.Repository}}" | grep -q "_core-"; then
                TEAM_NAME=$(docker images --format "{{.Repository}}" | grep "_core-" | head -1 | cut -d'/' -f1)
            fi
        fi
        if [[ -z "$TEAM_NAME" ]]; then
            print_error "Could not detect team name. Use --team flag."
            exit 1
        fi
    fi

    if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME=$(yq eval '.team.project' "$config_file" 2>/dev/null)
        if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == "null" ]]; then
            PROJECT_NAME=$(basename "$(pwd)")
        fi
    fi

    print_status "Building additional profiles for: $TEAM_NAME/$PROJECT_NAME"
    print_status "Profiles: ${variants[*]}"
    echo ""

    # Enable and build each variant
    for profile_name in "${variants[@]}"; do
        print_status "Processing variant: $profile_name"

        # Enable variant in config.yaml if not already enabled
        local is_enabled=$(yq eval ".profiles.${profile_name}.enabled // false" "$config_file")
        if [[ "$is_enabled" != "true" ]]; then
            print_status "  Enabling $profile_name in config.yaml..."
            yq eval ".profiles.${profile_name}.enabled = true" -i "$config_file"
        else
            print_status "  $profile_name already enabled in config.yaml"
        fi

        # Build the variant using config system
        if build_config_profile "$config_file" "$profile_name"; then
            print_success "✅ Built $profile_name variant"

            # Push to Docker Hub
            echo ""
            if confirm "Push $profile_name image to Docker Hub?"; then
                docker push "${TEAM_NAME}/${PROJECT_NAME}_core-${profile_name}:v1.0.0"
                docker push "${TEAM_NAME}/${PROJECT_NAME}_core-${profile_name}:latest"
                print_success "✅ Pushed $profile_name to Docker Hub"
            else
                print_status "Image built locally only. To push later, run:"
                print_status "  docker push ${TEAM_NAME}/${PROJECT_NAME}_core-${profile_name}:v1.0.0"
                print_status "  docker push ${TEAM_NAME}/${PROJECT_NAME}_core-${profile_name}:latest"
            fi
        else
            print_error "❌ Failed to build $profile_name variant"
        fi
        echo ""
    done

    print_success "✅ All profiles processed successfully!"
}

#=============================================================================
# MAIN TEAM INITIALIZATION FUNCTION
#=============================================================================

# Function: run_team_initialization
# Purpose: Main orchestration function for team setup workflow
run_team_initialization() {
    # Check if team initialization was already completed in this directory
    if [[ -f ".zzcollab_team_setup" ]]; then
        log_error "❌ Team initialization already completed in this directory!"
        log_error "Found existing .zzcollab_team_setup marker file."
        log_error ""
        
        # Check if user is trying to add variants (common mistake)
        if [[ -n "${INIT_BASE_IMAGE:-}" ]] && [[ "${INIT_BASE_IMAGE}" != "r-ver" ]]; then
            log_error "🔍 To add additional Docker profiles (${INIT_BASE_IMAGE}), use:"
            log_error "   cd .. && zzcollab -V ${INIT_BASE_IMAGE}    # Add variant from parent directory"
            log_error ""
        fi
        
        log_error "🔍 To complete the project setup, run:"
        log_error "   zzcollab              # Complete the project setup (no -i flag)"
        log_error "   zzcollab -d ~/dotfiles # With dotfiles"
        log_error "   zzcollab -I rstudio   # With RStudio interface"
        log_error ""
        log_error "💡 The -i flag is only for initial team setup, not project completion."
        log_error "💡 Use -V flag to add Docker profiles after initial setup."
        exit 1
    fi
    
    # Check if this looks like an existing zzcollab project
    if [[ -f ".zzcollab_manifest.json" ]] || [[ -f ".zzcollab_manifest.txt" ]] || [[ -f "DESCRIPTION" && -d "R" && -d "analysis" ]]; then
        log_error "❌ Cannot run team initialization in existing zzcollab project!"
        log_error "This directory already contains a zzcollab project."
        log_error ""
        log_error "🔍 You probably meant to run:"
        log_error "   zzcollab              # Update project settings"
        log_error "   zzcollab -S           # Change build mode"
        log_error "   zzcollab -d ~/dotfiles # Add dotfiles"
        log_error ""
        log_error "💡 Use -i only for creating new team images, not updating existing projects."
        exit 1
    fi
    
    # Show configuration summary
    log_info "Configuration Summary:"
    cat << EOF
  Team Name: $TEAM_NAME
  Project Name: $PROJECT_NAME
  GitHub Account: $GITHUB_ACCOUNT
  Base Image(s): $INIT_BASE_IMAGE
  Build Mode: $BUILD_MODE
  Dotfiles: ${DOTFILES_DIR:-"None"}
  Dockerfile: ${DOCKERFILE_PATH##*/}
  Mode: Complete setup
EOF

    echo ""
    if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
        if ! confirm "Proceed with team setup?"; then
            print_status "Team setup cancelled by user"
            exit 0
        fi
    else
        log_info "ℹ️  Proceeding with team setup (--yes flag provided)"
    fi

    if [[ "$PREPARE_DOCKERFILE" != true ]]; then
        print_status "Starting automated team setup..."
    fi

    # Execute all steps in sequence
    create_project_structure
    setup_team_dockerfile
    create_basic_files

    # Interactive variant selection if using config-based profiles
    if [[ "${USE_CONFIG_PROFILES:-false}" == "true" ]]; then
        print_status ""
        print_status "📝 Configuration file created: config.yaml"
        print_status ""
        print_status "Current enabled profiles (set to build Docker images):"
        if command -v yq >/dev/null 2>&1; then
            yq eval '.profiles | to_entries | map(select(.value.enabled == true)) | .[] | "  - " + .key' config.yaml 2>/dev/null || echo "  - Unable to parse variants"
        else
            echo "  - minimal (default)"
            echo "  - analysis (default)"
        fi
        print_status ""
        print_status "💡 You can edit config.yaml now to enable/disable profiles before building."
        print_status "💡 To add profiles interactively, run: ./add_profile.sh"
        print_status ""

        if [[ "$SKIP_CONFIRMATION" != "true" ]]; then
            echo -n "Do you want to edit config.yaml before building? (y/n): "
            read -r response

            if [[ "$response" =~ ^[Yy] ]]; then
                print_status "Please edit config.yaml and press Enter when ready to continue..."
                print_status "(Set 'enabled: true' for profiles you want to build)"

                # Open editor if available
                if [[ -n "${EDITOR:-}" ]]; then
                    $EDITOR config.yaml
                elif command -v vim >/dev/null 2>&1; then
                    vim config.yaml
                elif command -v nano >/dev/null 2>&1; then
                    nano config.yaml
                else
                    print_status "No editor found. Edit config.yaml manually and press Enter..."
                fi

                echo -n "Press Enter to continue with building..."
                read -r
            fi
        fi
    fi

    build_team_images
    push_team_images
    
    # Create marker file to identify this as a partial zzcollab setup
    # This allows the next zzcollab run (without -i) to be recognized as safe
    # ONLY if run in the same directory where -i was executed
    cat > ".zzcollab_team_setup" << EOF
# ZZCOLLAB Team Setup Marker
# This file indicates that team initialization was completed here.
# The next 'zzcollab' run will complete the full project setup.
# IMPORTANT: Must be run in the same directory as the -i command.
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
team_name=$TEAM_NAME
project_name=$PROJECT_NAME
build_mode=$BUILD_MODE
init_base_image=$INIT_BASE_IMAGE
team_setup_complete=true
full_project_setup_needed=true
setup_directory=$PWD
EOF

    # Team initialization complete - stop here for -i flag
    # Team members will run zzcollab without -i to do full project setup
    log_info "✅ 🎉 Team initialization complete!"
    log_info ""
    log_info "ℹ️  Team images created and pushed to Docker Hub:"
    
    # List the created images
    if [[ "$INIT_BASE_IMAGE" == "all" ]] || [[ "$INIT_BASE_IMAGE" == *"r-ver"* ]]; then
        log_info "  ${TEAM_NAME}/${PROJECT_NAME}_core-shell:latest"
    fi
    if [[ "$INIT_BASE_IMAGE" == "all" ]] || [[ "$INIT_BASE_IMAGE" == *"rstudio"* ]]; then
        log_info "  ${TEAM_NAME}/${PROJECT_NAME}_core-rstudio:latest"
    fi
    if [[ "$INIT_BASE_IMAGE" == "all" ]] || [[ "$INIT_BASE_IMAGE" == *"verse"* ]]; then
        log_info "  ${TEAM_NAME}/${PROJECT_NAME}_core-verse:latest"
    fi
    
    log_info ""
    log_info "ℹ️  Next steps for complete project setup:"
    log_info "  ⚠️  IMPORTANT: Must cd into the project directory first!"
    log_info "  1. cd ${PROJECT_NAME}"
    log_info "  2. zzcollab                     # Basic setup"
    log_info "  3. zzcollab -d ~/dotfiles -S    # With dotfiles and standard mode"
    log_info "  4. zzcollab -I rstudio          # With RStudio interface"
    log_info ""
    log_info "💡 Correct workflow: zzcollab -i -p png1 && cd png1 && zzcollab"
    log_info "❌ Wrong workflow: zzcollab -i -p png1 && zzcollab  # Forgets to cd!"
    log_info ""
    log_info "ℹ️  Team members can now join with:"
    log_info "  git clone https://github.com/${TEAM_NAME}/${PROJECT_NAME}.git"
    log_info "  cd ${PROJECT_NAME}"
    log_info "  zzcollab -t ${TEAM_NAME} -p ${PROJECT_NAME} -I shell"
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


