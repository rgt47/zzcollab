#!/bin/bash
##############################################################################
# ZZCOLLAB COMPLETE MODULAR IMPLEMENTATION
##############################################################################
# 
# PURPOSE: Complete modular implementation of zzcollab functionality
#          - All 7 modules: core, templates, structure, rpackage, docker, analysis, cicd, devtools
#          - 100% functionality preservation from original zzcollab.sh
#          - Comprehensive manifest tracking for uninstall
#          - Modular architecture with dependency management
#
# USAGE:   ./zzcollab.sh [OPTIONS]
#
# OPTIONS: All original zzcollab.sh options preserved:
#          --no-docker, --dotfiles DIR, --dotfiles-nodot DIR, --base-image NAME
##############################################################################

set -euo pipefail

#=============================================================================
# SCRIPT CONSTANTS AND SETUP
#=============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATES_DIR="$SCRIPT_DIR/templates"
readonly MODULES_DIR="$SCRIPT_DIR/modules"

# Manifest tracking for uninstall functionality
readonly MANIFEST_FILE=".zzcollab_manifest.json"
readonly MANIFEST_TXT=".zzcollab_manifest.txt"

#=============================================================================
# COMMAND LINE ARGUMENT PARSING (preserved from original)
#=============================================================================

require_arg() {
    [[ -n "${2:-}" ]] || { echo "❌ Error: $1 requires an argument" >&2; exit 1; }
}

# Initialize variables for command line options with same defaults as original
BUILD_DOCKER=true
DOTFILES_DIR=""
DOTFILES_NODOT=false
BASE_IMAGE="rocker/r-ver"

# New user-friendly interface variables
TEAM_NAME=""
PROJECT_NAME=""
INTERFACE=""
GITHUB_ACCOUNT=""
DOCKERFILE_PATH=""

# Initialization mode variables
INIT_MODE=false
USE_DOTFILES=false
PREPARE_DOCKERFILE=false
MINIMAL_PACKAGES=false
ULTRA_MINIMAL_PACKAGES=false
BARE_MINIMUM_PACKAGES=false

# Process all command line arguments (identical to original zzcollab.sh)
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-docker|-n)
            BUILD_DOCKER=false
            shift
            ;;
        --dotfiles|-d)
            require_arg "$1" "$2"
            DOTFILES_DIR="$2"
            shift 2
            ;;
        --dotfiles-nodot|-D)
            require_arg "$1" "$2"
            DOTFILES_DIR="$2"
            DOTFILES_NODOT=true
            shift 2
            ;;
        --base-image|-b)
            require_arg "$1" "$2"
            BASE_IMAGE="$2"
            shift 2
            ;;
        --team|-t)
            require_arg "$1" "$2"
            TEAM_NAME="$2"
            shift 2
            ;;
        --project-name|--project|-p)
            require_arg "$1" "$2"
            PROJECT_NAME="$2"
            shift 2
            ;;
        --interface|-I)
            require_arg "$1" "$2"
            INTERFACE="$2"
            shift 2
            ;;
        --init|-i)
            INIT_MODE=true
            shift
            ;;
        --team-name)
            require_arg "$1" "$2"
            TEAM_NAME="$2"
            shift 2
            ;;
        --github-account|-g)
            require_arg "$1" "$2"
            GITHUB_ACCOUNT="$2"
            shift 2
            ;;
        --dockerfile|-f)
            require_arg "$1" "$2"
            DOCKERFILE_PATH="$2"
            shift 2
            ;;
        --prepare-dockerfile|-P)
            PREPARE_DOCKERFILE=true
            shift
            ;;
        --minimal|-m)
            MINIMAL_PACKAGES=true
            shift
            ;;
        --next-steps)
            # We'll implement this after modules are loaded
            SHOW_NEXT_STEPS=true
            shift
            ;;
        --help|-h)
            # We'll implement this after modules are loaded
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "❌ Error: Unknown option '$1'" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

#=============================================================================
# USER-FRIENDLY INTERFACE PROCESSING
#=============================================================================

# Convert user-friendly flags to BASE_IMAGE if provided (only for non-init mode)
if [[ "$INIT_MODE" != "true" ]]; then
    if [[ -n "$TEAM_NAME" && -n "$PROJECT_NAME" && -n "$INTERFACE" ]]; then
        case "$INTERFACE" in
            shell)
                BASE_IMAGE="${TEAM_NAME}/${PROJECT_NAME}core-shell"
                ;;
            rstudio)
                BASE_IMAGE="${TEAM_NAME}/${PROJECT_NAME}core-rstudio"
                ;;
            *)
                echo "❌ Error: Unknown interface '$INTERFACE'" >&2
                echo "Valid interfaces: shell, rstudio" >&2
                exit 1
                ;;
        esac
        echo "ℹ️  Using team image: $BASE_IMAGE"
    elif [[ -n "$TEAM_NAME" || -n "$PROJECT_NAME" || -n "$INTERFACE" ]]; then
        # If some team flags are provided but not all, show error (only for non-init mode)
        echo "❌ Error: When using team interface, all flags are required:" >&2
        echo "  --team TEAM_NAME --project-name PROJECT_NAME --interface INTERFACE" >&2
        echo "  Valid interfaces: shell, rstudio" >&2
        exit 1
    fi
fi

#=============================================================================
# MODULE LOADING SYSTEM
#=============================================================================

# Basic logging before modules are loaded
log_info() {
    printf "ℹ️  %s\n" "$*" >&2
}

log_error() {
    printf "❌ %s\n" "$*" >&2
}

log_success() {
    printf "✅ %s\n" "$*" >&2
}

log_warning() {
    printf "⚠️  %s\n" "$*" >&2
}

# Validate modules directory exists
if [[ ! -d "$MODULES_DIR" ]]; then
    log_error "Modules directory not found: $MODULES_DIR"
    log_error "Please ensure you're running this script from the zzcollab directory"
    exit 1
fi

# Load modules in dependency order
log_info "Loading all zzcollab modules..."

# Load core module first (required by all others)
if [[ -f "$MODULES_DIR/core.sh" ]]; then
    log_info "Loading core module..."
    # shellcheck source=modules/core.sh
    source "$MODULES_DIR/core.sh"
else
    log_error "Core module not found: $MODULES_DIR/core.sh"
    exit 1
fi

# Load templates module (depends on core)
if [[ -f "$MODULES_DIR/templates.sh" ]]; then
    log_info "Loading templates module..."
    # shellcheck source=modules/templates.sh
    source "$MODULES_DIR/templates.sh"
else
    log_error "Templates module not found: $MODULES_DIR/templates.sh"
    exit 1
fi

# Load structure module (depends on core)
if [[ -f "$MODULES_DIR/structure.sh" ]]; then
    log_info "Loading structure module..."
    # shellcheck source=modules/structure.sh
    source "$MODULES_DIR/structure.sh"
else
    log_error "Structure module not found: $MODULES_DIR/structure.sh"
    exit 1
fi

#=============================================================================
# PACKAGE NAME VALIDATION (must be done before rpackage module)
#=============================================================================

# Validate package name using extracted function
PKG_NAME=$(validate_package_name)
readonly PKG_NAME

# Export variables for template substitution
USERNAME="${USERNAME:-analyst}"  # Default Docker user
export PKG_NAME AUTHOR_NAME AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE USERNAME

log_info "Package name determined: $PKG_NAME"

# Load remaining modules that depend on PKG_NAME being set
# Note: analysis module is loaded later after directory structure is created
modules_to_load=("rpackage" "docker" "cicd" "devtools")

for module in "${modules_to_load[@]}"; do
    if [[ -f "$MODULES_DIR/${module}.sh" ]]; then
        log_info "Loading ${module} module..."
        # shellcheck source=/dev/null
        source "$MODULES_DIR/${module}.sh"
    else
        log_error "${module^} module not found: $MODULES_DIR/${module}.sh"
        exit 1
    fi
done

#=============================================================================
# HELP AND NEXT STEPS (from original zzcollab.sh)
#=============================================================================

show_help() {
    cat << EOF
$0 - Complete Research Compendium Setup (Modular Implementation)

Creates a comprehensive research compendium with R package structure, Docker integration,
analysis templates, and reproducible workflows.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    Team initialization (Developer 1 - Team Lead):
    -i, --init                   Initialize new team project with Docker images and GitHub repo
    -t, --team-name NAME         Team name (Docker Hub organization) [required with --init]
    -p, --project-name NAME      Project name [required with --init]
    -g, --github-account NAME    GitHub account (default: same as team-name)
    
    Team collaboration (Developer 2+ - Team Members):
    -t, --team NAME              Team name (Docker Hub organization)
    -p, --project-name NAME      Project name  
    -I, --interface TYPE         Interface type: shell, rstudio
    
    Common options:
    -d, --dotfiles DIR           Copy dotfiles from directory (files with leading dots)
    -D, --dotfiles-nodot DIR     Copy dotfiles from directory (files without leading dots)
    
    Advanced options:
    -b, --base-image NAME        Use custom Docker base image (default: rocker/r-ver)
    -n, --no-docker              Skip Docker image build during setup
        --next-steps             Show development workflow and next steps
    -h, --help                   Show this help message

EXAMPLES:
    # Team Lead - Initialize new team project (Developer 1)
    $0 -i -t rgt47 -p research-study -d ~/dotfiles
    $0 --init --team-name mylab --project-name study2024 --github-account myorg
    
    # Alternative: Create directory first, then run in it (project name auto-detected)
    mkdir png1 && cd png1 && $0 -i -t rgt47 -d ~/dotfiles
    
    # Team Members - Join existing project (Developer 2+)
    $0 -t rgt47 -p research-study -I shell -d ~/dotfiles
    $0 --team mylab --project-name study2024 --interface rstudio --dotfiles ~/dotfiles
    
    # Advanced usage with custom base images
    $0 -b rocker/tidyverse -d ~/dotfiles
    $0 --base-image myteam/mycustomimage --dotfiles-nodot ~/dotfiles
    
    # Basic setup for standalone projects
    $0 -d ~/dotfiles                                # Basic setup with dotfiles
    $0 -n                                           # Setup without Docker build

MODULES INCLUDED:
    core         - Logging, validation, utilities
    templates    - Template processing and file creation
    structure    - Directory structure and navigation
    rpackage     - R package development framework
    docker       - Container integration and builds
    analysis     - Research report and analysis templates
    cicd         - GitHub Actions workflows
    devtools     - Makefile, configs, development tools

CREATED STRUCTURE:
    ├── R/                     # Package functions
    ├── analysis/              # Research workflow
    ├── data/                  # Data management
    ├── tests/                 # Unit tests
    ├── .github/workflows/     # CI/CD automation
    ├── Dockerfile             # Container definition
    ├── Makefile              # Build automation
    └── Symbolic links (a→data, n→analysis, etc.)

For detailed documentation, see ZZCOLLAB_USER_GUIDE.md after setup.
EOF
}

show_next_steps() {
    cat << 'EOF'
🚀 ZZCOLLAB NEXT STEPS

After running the modular setup script, here's how to get started:

📁 PROJECT STRUCTURE:
   Your project now has a complete research compendium with:
   - R package structure with functions and tests
   - Analysis workflow with report templates
   - Docker environment for reproducibility
   - CI/CD workflows for automation

🐳 DOCKER DEVELOPMENT:
   Start your development environment:
   
   make docker-build          # Build the Docker image
   make docker-rstudio        # → http://localhost:8787 (user: analyst, pass: analyst)
   make docker-r              # R console in container
   make docker-zsh            # Interactive shell with your dotfiles
   
📝 ANALYSIS WORKFLOW:
   1. Place raw data in data/raw_data/
   2. Develop analysis scripts in scripts/
   3. Write your report in analysis/report/report.Rmd
   4. Use 'make docker-render' to generate PDF

🔧 PACKAGE DEVELOPMENT:
   make check                 # R CMD check validation
   make test                  # Run testthat tests
   make document              # Generate documentation
   ./dev.sh setup             # Quick development setup

📊 DATA MANAGEMENT:
   - Document datasets in data/metadata/
   - Use analysis/templates/ for common patterns
   - Validate data with scripts in data/validation/

🤝 COLLABORATION:
   git init                   # Initialize version control
   git add .                  # Stage all files
   git commit -m "Initial zzcollab setup"
   # Push to GitHub to activate CI/CD workflows

🔄 AUTOMATION:
   - GitHub Actions will run package checks automatically
   - Papers render automatically when analysis/ changes
   - Use pre-commit hooks for code quality

📄 DOCUMENTATION:
   - See ZZCOLLAB_USER_GUIDE.md for comprehensive guide
   - Use make help for all available commands
   - Check .github/workflows/ for CI/CD documentation

🆘 GETTING HELP:
   make help                 # See all available commands
   ./zzcollab-uninstall.sh  # Remove created files if needed
   
🧹 UNINSTALL:
   All created files are tracked in .zzcollab_manifest.json
   Run './zzcollab-uninstall.sh' to remove everything cleanly

Happy researching! 🎉
EOF
}

#=============================================================================
# MANIFEST INITIALIZATION
#=============================================================================

init_manifest() {
    if command -v jq >/dev/null 2>&1; then
        cat > "$MANIFEST_FILE" <<EOF
{
  "version": "1.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_name": "$PKG_NAME",
  "modules_loaded": ["core", "templates", "structure", "rpackage", "docker", "analysis", "cicd", "devtools"],
  "command_line_options": {
    "build_docker": $BUILD_DOCKER,
    "dotfiles_dir": "${DOTFILES_DIR}",
    "dotfiles_nodot": $DOTFILES_NODOT,
    "base_image": "$BASE_IMAGE"
  },
  "directories": [],
  "files": [],
  "template_files": [],
  "symlinks": [],
  "dotfiles": [],
  "docker_image": null
}
EOF
        log_success "Initialized JSON manifest file: $MANIFEST_FILE"
    else
        {
            echo "# ZZCOLLAB MANIFEST - Created $(date)"
            echo "# Package: $PKG_NAME"
            echo "# Modules: core, templates, structure, rpackage, docker, analysis, cicd, devtools"
            echo "# Build Docker: $BUILD_DOCKER"
            echo "# Dotfiles: $DOTFILES_DIR"
            echo "# Base Image: $BASE_IMAGE"
            echo "# Format: type:path"
        } > "$MANIFEST_TXT"
        log_success "Initialized text manifest file: $MANIFEST_TXT (jq not available)"
    fi
}

install_uninstall_script() {
    local uninstall_script="zzcollab-uninstall.sh"
    if [[ -f "$TEMPLATES_DIR/$uninstall_script" ]]; then
        cp "$TEMPLATES_DIR/$uninstall_script" "./$uninstall_script"
        chmod +x "./$uninstall_script"
        track_file "$uninstall_script"
        log_success "Uninstall script installed: ./$uninstall_script"
    else
        log_warning "Uninstall script template not found"
    fi
}

#=============================================================================
# INITIALIZATION MODE FUNCTIONS (from zzcollab-init-team)
#=============================================================================

# Color codes for output (from zzcollab-init-team)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_init_help() {
    cat << EOF
$0 --init - Team initialization for ZZCOLLAB research collaboration

USAGE:
    $0 --init --team-name TEAM --project-name PROJECT [OPTIONS]

REQUIRED:
    -t, --team-name NAME        Docker Hub team/organization name
    -p, --project-name NAME     Project name (will be used for directories and images)

OPTIONAL:
    -g, --github-account NAME   GitHub account name (default: same as team-name)
    -d, --dotfiles PATH         Path to dotfiles directory (files already have dots)
    -D, --dotfiles-nodot PATH   Path to dotfiles directory (files need dots added)
    -f, --dockerfile PATH       Custom Dockerfile path (default: templates/Dockerfile.pluspackages)
    -P, --prepare-dockerfile    Set up project and Dockerfile for editing, then exit
    -m, --minimal              Use minimal package set and CI for faster initialization (5 packages vs 39 - lightweight CI)
    -h, --help                 Show this help message

EXAMPLES:
    # Prepare project for Dockerfile editing (Developer 1 workflow)
    $0 -i -t rgt47 -p research-study -P
    # Edit research-study/Dockerfile.teamcore as needed, then run:
    $0 -i -t rgt47 -p research-study

    # Direct setup (no Dockerfile editing)
    $0 -i -t rgt47 -p research-study -d ~/dotfiles
    
    # Fast setup with minimal packages (5 packages vs 39 - no Docker packages, faster initialization)
    $0 -i -t rgt47 -p research-study -m -d ~/dotfiles
    
    
    # Alternative: Create directory first, then auto-detect project name
    mkdir png1 && cd png1 && $0 -i -t rgt47 -d ~/dotfiles

    # With custom GitHub account
    $0 --init --team-name rgt47 --project-name research-study --github-account mylab

    # With dotfiles (files already have dots: .bashrc, .vimrc, etc.)
    $0 --init --team-name rgt47 --project-name research-study --dotfiles ~/dotfiles

    # With dotfiles that need dots added (files like: bashrc, vimrc, etc.)
    $0 -i -t rgt47 -p research-study -D ~/Dropbox/dotfiles

WORKFLOW:
    1. Create project directory
    2. Copy and customize Dockerfile.teamcore
    3. Build shell and RStudio core images
    4. Push images to Docker Hub
    5. Initialize zzcollab project
    6. Create private GitHub repository
    7. Push initial commit

PREREQUISITES:
    - Docker installed and running
    - Docker Hub account and logged in (docker login)
    - GitHub CLI installed and authenticated (gh auth login)
    - zzcollab installed and available in PATH

EOF
}

validate_init_prerequisites() {
    print_status "Validating prerequisites..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker is not running or not accessible"
        exit 1
    fi

    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed or not in PATH"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated. Please run: gh auth login"
        exit 1
    fi

    # Check Docker Hub login status
    if ! docker info | grep -q "Username:"; then
        print_warning "Docker Hub login status unclear. You may need to run: docker login"
    fi

    # Verify Docker Hub account exists and is accessible
    print_status "Verifying Docker Hub account: $TEAM_NAME"
    if ! docker pull hello-world &> /dev/null; then
        print_error "Cannot pull from Docker Hub. Please check your Docker Hub login with: docker login"
        exit 1
    fi

    # Try to verify the Docker Hub account exists (best effort)
    if command -v curl &> /dev/null; then
        if curl -s "https://hub.docker.com/v2/users/${TEAM_NAME}/" | grep -q "User not found"; then
            print_warning "Docker Hub user '$TEAM_NAME' may not exist. Please verify the account exists."
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_success "Docker Hub account '$TEAM_NAME' verified"
        fi
    fi

    # Verify GitHub account exists
    print_status "Verifying GitHub account: $GITHUB_ACCOUNT"
    if ! gh api "users/${GITHUB_ACCOUNT}" &> /dev/null; then
        print_error "GitHub account '$GITHUB_ACCOUNT' does not exist or is not accessible"
        print_error "Please verify the account exists and you have proper permissions"
        exit 1
    fi
    print_success "GitHub account '$GITHUB_ACCOUNT' verified"

    print_success "All prerequisites validated"
}

validate_init_parameters() {
    # Validate required parameters
    if [[ -z "$TEAM_NAME" ]]; then
        print_error "Required parameter --team-name is missing"
        show_init_help
        exit 1
    fi

    if [[ -z "$PROJECT_NAME" ]]; then
        # Try to infer project name from current directory if it's empty or minimal
        current_dir=$(basename "$PWD")
        
        # Check if current directory is suitable for project setup
        if [[ "$current_dir" != "zzcollab" ]] && [[ "$current_dir" != "." ]] && [[ "$current_dir" != "/" ]]; then
            # Check if directory is empty or contains only basic files
            file_count=$(find . -maxdepth 1 -type f | wc -l)
            if [[ $file_count -le 3 ]]; then  # Allow for .gitignore, README, etc.
                PROJECT_NAME="$current_dir"
                print_status "Inferred project name from current directory: $PROJECT_NAME"
                print_status "Using current directory for project setup"
            else
                print_error "Current directory '$current_dir' contains too many files for auto-detection"
                print_error "Please specify --project-name explicitly or use an empty directory"
                show_init_help
                exit 1
            fi
        else
            print_error "Required parameter --project-name is missing"
            show_init_help
            exit 1
        fi
    fi

    # Set defaults
    if [[ -z "$GITHUB_ACCOUNT" ]]; then
        GITHUB_ACCOUNT="$TEAM_NAME"
        print_status "Using default GitHub account: $GITHUB_ACCOUNT"
    fi

    if [[ -z "$DOCKERFILE_PATH" ]]; then
        # Try to find the Dockerfile template in multiple locations
        # Choose template based on minimal flag
        TEMPLATE_NAME="Dockerfile.pluspackages"
        if [[ "$MINIMAL_PACKAGES" == "true" ]]; then
            TEMPLATE_NAME="Dockerfile.minimal"
        fi
        
        POSSIBLE_PATHS=(
            "templates/$TEMPLATE_NAME"                                    # Current directory
            "$SCRIPT_DIR/templates/$TEMPLATE_NAME"                       # Same directory as script
            "$SCRIPT_DIR/zzcollab-support/templates/$TEMPLATE_NAME"      # Installed location
            "$(dirname "$SCRIPT_DIR")/templates/$TEMPLATE_NAME"          # Parent directory
        )
        
        for path in "${POSSIBLE_PATHS[@]}"; do
            if [[ -f "$path" ]]; then
                DOCKERFILE_PATH="$path"
                break
            fi
        done
        
        if [[ -z "$DOCKERFILE_PATH" ]]; then
            print_error "Could not find $TEMPLATE_NAME template"
            print_error "Searched in:"
            for path in "${POSSIBLE_PATHS[@]}"; do
                print_error "  - $path"
            done
            print_error "Please specify --dockerfile path or ensure templates/$TEMPLATE_NAME exists"
            exit 1
        fi
    fi

    # Set dotfiles flags based on which option was used
    if [[ -n "$DOTFILES_DIR" ]]; then
        USE_DOTFILES=true
        if [[ "$DOTFILES_NODOT" == "true" ]]; then
            print_status "Using dotfiles from: $DOTFILES_DIR (dots will be added)"
        else
            print_status "Using dotfiles from: $DOTFILES_DIR (files already have dots)"
        fi
    else
        print_status "No dotfiles specified, proceeding without dotfiles integration"
    fi

    # Validate dotfiles path if specified
    if [[ "$USE_DOTFILES" == true && ! -d "$DOTFILES_DIR" ]]; then
        print_error "Dotfiles path does not exist: $DOTFILES_DIR"
        exit 1
    fi
}

run_team_initialization() {
    print_status "Configuration Summary:"
    echo "  Team Name: $TEAM_NAME"
    echo "  Project Name: $PROJECT_NAME"
    echo "  GitHub Account: $GITHUB_ACCOUNT"
    echo "  Dotfiles: $(if [[ "$USE_DOTFILES" == true ]]; then echo "$DOTFILES_DIR"; else echo "none"; fi)"
    echo "  Dockerfile: $DOCKERFILE_PATH"
    echo "  Package Set: $(if [[ "$MINIMAL_PACKAGES" == true ]]; then echo "Minimal (5 packages, lightweight CI)"; else echo "Full (39 packages, comprehensive CI)"; fi)"
    echo "  Mode: $(if [[ "$PREPARE_DOCKERFILE" == true ]]; then echo "Prepare for editing"; else echo "Complete setup"; fi)"
    echo ""

    # Confirm before proceeding
    read -p "Proceed with team setup? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled by user"
        exit 0
    fi

    # Start the setup process
    if [[ "$PREPARE_DOCKERFILE" == true ]]; then
        print_status "Preparing project for Dockerfile editing..."
    else
        print_status "Starting automated team setup..."
    fi

    # Step 1: Create project directory
    print_status "Step 1: Setting up project directory..."
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
            print_status "Using existing project directory: $PROJECT_NAME"
            cd "$PROJECT_NAME"
        fi
    else
        mkdir "$PROJECT_NAME"
        cd "$PROJECT_NAME"
        print_success "Created project directory: $PROJECT_NAME"
    fi

    # Step 2: Copy and customize Dockerfile
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

    # If prepare mode, exit with instructions
    if [[ "$PREPARE_DOCKERFILE" == true ]]; then
        print_success "🎉 Project prepared for Dockerfile editing!"
        echo ""
        print_status "📝 NEXT STEPS:"
        echo "  1. Edit $PROJECT_NAME/Dockerfile.teamcore to add your team's packages and tools"
        echo "  2. Common customizations:"
        echo "     - Add R packages: RUN R -e \"install.packages('packagename')\""
        echo "     - Add system tools: RUN apt-get update && apt-get install -y tool-name"
        echo "     - Set environment variables: ENV VARIABLE_NAME=value"
        echo "  3. When done editing, run:"
        echo "     zzcollab --init --team-name $TEAM_NAME --project-name $PROJECT_NAME$(if [[ "$USE_DOTFILES" == true ]]; then if [[ "$DOTFILES_NODOT" == true ]]; then echo " --dotfiles-nodot $DOTFILES_DIR"; else echo " --dotfiles $DOTFILES_DIR"; fi; fi)$(if [[ -n "$GITHUB_ACCOUNT" && "$GITHUB_ACCOUNT" != "$TEAM_NAME" ]]; then echo " --github-account $GITHUB_ACCOUNT"; fi)"
        echo ""
        print_status "💡 TIP: Test your Dockerfile locally with:"
        echo "     docker build -f Dockerfile.teamcore -t test-image ."
        exit 0
    fi

    # Step 3: Build shell core image
    print_status "Step 3: Building shell core image..."
    docker build -f Dockerfile.teamcore \
        --build-arg BASE_IMAGE=rocker/r-ver \
        --build-arg TEAM_NAME="$TEAM_NAME" \
        --build-arg PROJECT_NAME="$PROJECT_NAME" \
        -t "${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0" .

    docker tag "${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0" \
        "${TEAM_NAME}/${PROJECT_NAME}core-shell:latest"
    print_success "Built shell core image: ${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0"

    # Step 4: Build RStudio core image
    print_status "Step 4: Building RStudio core image..."
    docker build -f Dockerfile.teamcore \
        --build-arg BASE_IMAGE=rocker/rstudio \
        --build-arg TEAM_NAME="$TEAM_NAME" \
        --build-arg PROJECT_NAME="$PROJECT_NAME" \
        -t "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0" .

    docker tag "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0" \
        "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:latest"
    print_success "Built RStudio core image: ${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0"

    # Step 5: Push images to Docker Hub
    print_status "Step 5: Pushing images to Docker Hub..."
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0"
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-shell:latest"
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0"
    docker push "${TEAM_NAME}/${PROJECT_NAME}core-rstudio:latest"
    print_success "Pushed all images to Docker Hub"

    # Step 6: Initialize zzcollab project
    print_status "Step 6: Initializing zzcollab project..."
    
    # Prepare zzcollab arguments
    ZZCOLLAB_ARGS="--base-image ${TEAM_NAME}/${PROJECT_NAME}core-shell"
    if [[ "$USE_DOTFILES" == true ]]; then
        if [[ "$DOTFILES_NODOT" == "true" ]]; then
            ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --dotfiles-nodot $DOTFILES_DIR"
        else
            ZZCOLLAB_ARGS="$ZZCOLLAB_ARGS --dotfiles $DOTFILES_DIR"
        fi
    fi
    
    # Run zzcollab setup (calling ourselves recursively but without --init)
    eval "$0 $ZZCOLLAB_ARGS"
    print_success "Initialized zzcollab project with custom base image"

    # Step 7: Initialize git repository
    print_status "Step 7: Initializing git repository..."
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

    # Step 8: Create private GitHub repository
    print_status "Step 8: Creating private GitHub repository..."

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

    gh repo create "${GITHUB_ACCOUNT}/${PROJECT_NAME}" \
        --private \
        --description "Research project using ZZCOLLAB - team core images: ${TEAM_NAME}/${PROJECT_NAME}core" \
        --source=. \
        --remote=origin \
        --push

    print_success "Created private GitHub repository: ${GITHUB_ACCOUNT}/${PROJECT_NAME}"

    # Final success message
    print_success "🎉 Team setup completed successfully!"
    echo ""
    print_status "What was created:"
    echo "  📁 Project directory: $PROJECT_NAME/"
    echo "  🐳 Docker images:"
    echo "    - ${TEAM_NAME}/${PROJECT_NAME}core-shell:v1.0.0"
    echo "    - ${TEAM_NAME}/${PROJECT_NAME}core-shell:latest"
    echo "    - ${TEAM_NAME}/${PROJECT_NAME}core-rstudio:v1.0.0"
    echo "    - ${TEAM_NAME}/${PROJECT_NAME}core-rstudio:latest"
    echo "  🔒 Private GitHub repo: https://github.com/${GITHUB_ACCOUNT}/${PROJECT_NAME}"
    echo "  📦 Complete zzcollab research compendium"
    echo ""
    print_status "Next steps:"
    echo "  1. cd $PROJECT_NAME"
    echo "  2. make docker-zsh    # Start development environment"
    echo "  3. Start coding your analysis!"
    echo ""
    print_status "Team members can now join with:"
    echo "  git clone https://github.com/${GITHUB_ACCOUNT}/${PROJECT_NAME}.git"
    echo "  cd $PROJECT_NAME"
    echo "  zzcollab --team $TEAM_NAME --project-name $PROJECT_NAME --interface shell --dotfiles ~/dotfiles"
    echo "  make docker-zsh"
}

#=============================================================================
# DIRECTORY VALIDATION FUNCTION
#=============================================================================

validate_directory_for_setup() {
    local current_dir
    current_dir=$(basename "$PWD")
    
    # Skip validation for certain directories that are expected to be non-empty
    if [[ "$current_dir" == "zzcollab" ]]; then
        log_warning "Running zzcollab setup in the zzcollab source directory"
        log_warning "This will create project files alongside the zzcollab source code"
        read -p "Are you sure you want to continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
        return 0
    fi
    
    # Check if directory is empty or contains only basic files
    local file_count
    file_count=$(find . -maxdepth 1 -type f | wc -l)
    
    if [[ $file_count -le 3 ]]; then
        log_info "Directory validation passed ($file_count files found)"
        return 0
    fi
    
    # If more than 3 files, show warning and ask for confirmation
    log_warning "Current directory contains $file_count files"
    log_warning "Running zzcollab setup here may overwrite existing files"
    
    # Show some of the files that would be affected
    log_info "Files in current directory:"
    ls -la | head -10
    if [[ $file_count -gt 7 ]]; then
        log_info "... and $(($file_count - 7)) more files"
    fi
    
    echo ""
    log_warning "zzcollab will create many files and directories in this location"
    log_warning "Consider running in an empty directory or using a subdirectory"
    echo ""
    
    read -p "Continue with setup in this directory? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled by user"
        log_info "To run zzcollab safely:"
        log_info "  1. Create a new directory: mkdir my-project && cd my-project"
        log_info "  2. Run zzcollab there: zzcollab [options]"
        exit 0
    fi
    
    log_info "Proceeding with setup as requested"
    return 0
}

#=============================================================================
# MAIN EXECUTION FUNCTION (identical workflow to original zzcollab.sh)
#=============================================================================

main() {
    # Handle initialization mode first
    if [[ "$INIT_MODE" == "true" ]]; then
        # Handle help for init mode
        if [[ "${SHOW_HELP:-false}" == "true" ]]; then
            show_init_help
            exit 0
        fi
        
        # Validate init parameters and prerequisites
        validate_init_parameters
        validate_init_prerequisites
        
        # Run team initialization
        run_team_initialization
        exit 0
    fi
    
    # Handle help and next-steps options for normal mode
    if [[ "${SHOW_HELP:-false}" == "true" ]]; then
        show_help
        exit 0
    fi
    
    if [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
        show_next_steps
        exit 0
    fi
    
    log_info "🚀 Starting modular rrtools project setup..."
    log_info "📦 Package name: '$PKG_NAME'"
    log_info "🔧 All modules loaded successfully"
    echo ""
    
    # Validate templates directory
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found: $TEMPLATES_DIR"
        log_error "Please ensure you're running this script from the zzcollab directory"
        exit 1
    fi
    
    # Validate directory is safe for setup
    validate_directory_for_setup
    
    # Initialize manifest tracking
    init_manifest
    
    # Execute setup in same order as original zzcollab.sh
    log_info "📁 Creating project structure..."
    create_directory_structure || exit 1
    
    # Load analysis module after directory structure is created
    if [[ -f "$MODULES_DIR/analysis.sh" ]]; then
        log_info "Loading analysis module..."
        # shellcheck source=modules/analysis.sh
        source "$MODULES_DIR/analysis.sh"
    else
        log_error "Analysis module not found: $MODULES_DIR/analysis.sh"
        exit 1
    fi
    
    log_info "📦 Creating R package files..."
    create_core_files || exit 1
    create_renv_setup || exit 1
    
    log_info "⚙️ Creating configuration files..."
    create_config_files || exit 1
    
    log_info "🐳 Creating Docker files..."
    create_docker_files || exit 1
    
    log_info "📝 Creating analysis files..."
    create_analysis_files || exit 1
    
    log_info "📜 Creating research scripts..."
    create_scripts_directory || exit 1
    
    log_info "🚀 Creating GitHub workflows..."
    create_github_workflows || exit 1
    
    log_info "🛠️ Creating development tools..."
    create_makefile || exit 1
    
    log_info "🔗 Creating navigation scripts..."
    create_navigation_scripts || exit 1
    
    # Extract R version for Docker build
    log_info "🔍 Detecting R version..."
    R_VERSION=$(extract_r_version_from_lockfile)
    export R_VERSION
    log_info "Using R version: $R_VERSION"
    
    # Install uninstall script
    install_uninstall_script
    
    # Conditional Docker build (same logic as original)
    if [[ "$BUILD_DOCKER" == "true" ]]; then
        log_info "🐳 Building Docker image..."
        if build_docker_image; then
            log_success "Docker image built successfully"
        else
            log_warning "Docker build failed - you can build manually later with 'make docker-build'"
        fi
    else
        log_info "⏭️ Skipping Docker image build (--no-docker specified)"
    fi
    
    # Initialize renv with snapshot of current environment
    log_info "📦 Creating renv.lock file..."
    if command -v R >/dev/null 2>&1; then
        if R --slave -e "renv::init(bare = TRUE, restart = FALSE); renv::snapshot(prompt = FALSE)" 2>/dev/null; then
            log_success "Created renv.lock with current package environment"
        else
            log_warning "Failed to create renv.lock - run 'renv::init(); renv::snapshot()' manually"
        fi
    else
        log_warning "R not found - run 'renv::init(); renv::snapshot()' after installing R"
    fi
    
    # Final success message and summary
    echo ""
    log_success "🎉 Modular project setup completed successfully!"
    echo ""
    
    # Show created items count
    local dir_count file_count symlink_count
    dir_count=$(find . -type d | wc -l)
    file_count=$(find . -type f \( ! -path "./.git/*" \) | wc -l)
    symlink_count=$(find . -type l | wc -l)
    
    log_info "📊 Created: $dir_count directories, $file_count files, $symlink_count symlinks"
    log_info "📄 Manifest: $([[ -f "$MANIFEST_FILE" ]] && echo "$MANIFEST_FILE" || echo "$MANIFEST_TXT")"
    
    # Show module summaries
    echo ""
    show_structure_summary
    echo ""
    show_rpackage_summary
    echo ""
    show_docker_summary
    echo ""
    show_analysis_summary
    echo ""
    show_cicd_summary
    echo ""
    show_devtools_summary
    
    echo ""
    log_info "📚 Run '$0 --next-steps' for development workflow guidance"
    log_info "🆘 Run './zzcollab-uninstall.sh' if you need to remove created files"
    log_info "📖 See ZZCOLLAB_USER_GUIDE.md for comprehensive documentation"
    echo ""
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi