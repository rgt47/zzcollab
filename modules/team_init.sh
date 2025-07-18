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
if [[ "${ZZCOLLAB_CORE_LOADED:-}" != "true" ]]; then
    echo "❌ Error: team_init.sh requires core.sh to be loaded first" >&2
    exit 1
fi

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

# Function: validate_init_parameters
# Purpose: Validate required parameters for team initialization
# Checks: TEAM_NAME, PROJECT_NAME, directory state
validate_init_parameters() {
    # Check required parameters
    if [[ -z "$TEAM_NAME" ]]; then
        print_error "Required parameter --team-name is missing"
        show_init_help
        exit 1
    fi

    if [[ -z "$PROJECT_NAME" ]]; then
        # Try to infer project name from current directory if it's empty or minimal
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

    # Set defaults
    if [[ -z "$GITHUB_ACCOUNT" ]]; then
        GITHUB_ACCOUNT="$TEAM_NAME"
        log_info "Using default GitHub account: $GITHUB_ACCOUNT"
    fi

    # Validate dotfiles
    if [[ -n "$DOTFILES_DIR" ]]; then
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            print_error "Dotfiles directory not found: $DOTFILES_DIR"
            exit 1
        fi
        USE_DOTFILES=true
        log_info "Using dotfiles from: $DOTFILES_DIR (files already have dots)"
    elif [[ -n "$DOTFILES_DIR" && "$DOTFILES_NODOT" == "true" ]]; then
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            print_error "Dotfiles directory not found: $DOTFILES_DIR"
            exit 1
        fi
        USE_DOTFILES=true
        log_info "Using dotfiles from: $DOTFILES_DIR (files need dots added)"
    else
        log_info "No dotfiles specified, proceeding without dotfiles integration"
    fi

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
            cd "$PROJECT_NAME"
            print_status "Using existing directory: $PROJECT_NAME"
        fi
    else
        mkdir -p "$PROJECT_NAME"
        cd "$PROJECT_NAME"
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
# Purpose: Build shell and RStudio core images for the team
build_team_images() {
    # Step 4: Build shell core image
    print_status "Step 4: Building shell core image..."
    docker build -f Dockerfile.teamcore \
        --build-arg BASE_IMAGE=rocker/r-ver \
        --build-arg TEAM_NAME="$TEAM_NAME" \
        --build-arg PROJECT_NAME="$PROJECT_NAME" \
        -t "${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0" .

    docker tag "${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0" \
        "${TEAM_NAME}/${PROJECT_NAME}core-shell:latest"
    print_success "Built shell core image: ${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0"

    # Step 5: Build RStudio core image
    print_status "Step 5: Building RStudio core image..."
    docker build -f Dockerfile.teamcore \
        --build-arg BASE_IMAGE=rocker/rstudio \
        --build-arg TEAM_NAME="$TEAM_NAME" \
        --build-arg PROJECT_NAME="$PROJECT_NAME" \
        -t "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0" .

    docker tag "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0" \
        "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:latest"
    print_success "Built RStudio core image: ${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0"
}

# Function: push_team_images  
# Purpose: Push team images to Docker Hub
push_team_images() {
    print_status "Step 6: Pushing images to Docker Hub..."
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0"
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-shell:latest"
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0"
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:latest"
    print_success "Pushed all images to Docker Hub"
}

#=============================================================================
# PROJECT INITIALIZATION FUNCTIONS
#=============================================================================

# Function: initialize_full_project
# Purpose: Run full zzcollab setup with team base image
initialize_full_project() {
    print_status "Step 7: Initializing full zzcollab project..."
    
    # Prepare zzcollab arguments
    local ZZCOLLAB_ARGS="--base-image ${TEAM_NAME}/${PROJECT_NAME}core-shell"
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
    
    # Legacy compatibility: Add legacy flags if they were passed to the original command
    if [[ "${MINIMAL_DOCKER:-}" == "true" ]]; then
        ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --minimal-docker"
    fi
    if [[ "${EXTRA_DOCKER:-}" == "true" ]]; then
        ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --extra-docker"
    fi
    if [[ "${MINIMAL_PACKAGES_ONLY:-}" == "true" ]]; then
        ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --minimal-packages"
    fi
    
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
- Team core images published to Docker Hub: ${TEAM_NAME}/${PROJECT_NAME}core:v1.0.0
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
    echo "  ${TEAM_NAME}/${PROJECT_NAME}core-shell:latest"
    echo "  ${TEAM_NAME}/${PROJECT_NAME}core-rstudio:latest"
}

#=============================================================================
# MAIN TEAM INITIALIZATION FUNCTION
#=============================================================================

# Function: run_team_initialization
# Purpose: Main orchestration function for team setup workflow
run_team_initialization() {
    # Show configuration summary
    log_info "Configuration Summary:"
    cat << EOF
  Team Name: $TEAM_NAME
  Project Name: $PROJECT_NAME
  GitHub Account: $GITHUB_ACCOUNT
  Dotfiles: ${DOTFILES_DIR:-"None"}
  Dockerfile: ${DOCKERFILE_PATH##*/}
  Mode: Complete setup
EOF

    echo ""
    if ! confirm "Proceed with team setup?"; then
        print_status "Team setup cancelled by user"
        exit 0
    fi

    if [[ "$PREPARE_DOCKERFILE" != true ]]; then
        print_status "Starting automated team setup..."
    fi

    # Execute all steps in sequence
    create_project_structure
    setup_team_dockerfile
    create_basic_files
    build_team_images
    push_team_images
    initialize_full_project
    setup_git_repository
    create_github_repository
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

# Set team_init module loaded flag
readonly ZZCOLLAB_TEAM_INIT_LOADED=true

log_info "Team initialization module loaded successfully"