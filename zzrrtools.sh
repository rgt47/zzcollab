#!/bin/bash
# Create rrtools-compatible R package structure in the current directory
# This script reorganizes existing files and sets up an rrtools framework

# Bash safety options
set -euo pipefail

# Auto-detect script directory and make configuration customizable
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATES_DIR="$SCRIPT_DIR/templates"
readonly AUTHOR_NAME="${RRTOOLS_AUTHOR_NAME:-Ronald G. Thomas}"
readonly AUTHOR_EMAIL="${RRTOOLS_AUTHOR_EMAIL:-rgthomas@ucsd.edu}"
readonly AUTHOR_INSTITUTE="${RRTOOLS_INSTITUTE:-UCSD}"
readonly AUTHOR_INSTITUTE_FULL="${RRTOOLS_INSTITUTE_FULL:-University of California, San Diego}"

# Early variable definition and validation
validate_package_name() {
    local dir_name
    dir_name=$(basename "$(pwd)")
    local pkg_name
    pkg_name=$(printf '%s' "$dir_name" | tr -cd '[:alnum:].' | head -c 50)
    
    if [[ -z "$pkg_name" ]]; then
        echo "❌ Error: Cannot determine valid package name from directory '$dir_name'" >&2
        return 1
    fi
    
    # Ensure it starts with a letter (R package requirement)
    if [[ ! "$pkg_name" =~ ^[[:alpha:]] ]]; then
        echo "❌ Error: Package name must start with a letter: '$pkg_name'" >&2
        return 1
    fi
    
    printf '%s' "$pkg_name"
}

PKG_NAME=$(validate_package_name)
readonly PKG_NAME

# Helper function for argument validation
require_arg() {
    [[ -n "${2:-}" ]] || { log_error "$1 requires an argument"; exit 1; }
}

# Parse command line arguments
BUILD_DOCKER=true
DOTFILES_DIR=""
DOTFILES_NODOT=false
BASE_IMAGE="rocker/r-ver"
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-docker)
            BUILD_DOCKER=false
            shift
            ;;
        --dotfiles)
            require_arg "$1" "$2"
            DOTFILES_DIR="$2"
            shift 2
            ;;
        --dotfiles-nodot)
            require_arg "$1" "$2"
            DOTFILES_DIR="$2"
            DOTFILES_NODOT=true
            shift 2
            ;;
        --base-image)
            require_arg "$1" "$2"
            BASE_IMAGE="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
Usage: zzrrtools.sh [OPTIONS]

Creates a complete rrtools research compendium with Docker support.

OPTIONS:
  --no-docker       Skip Docker image build during setup
  --dotfiles DIR    Copy dotfiles from specified directory (with leading dots)
  --dotfiles-nodot DIR Copy dotfiles from directory (without leading dots)
  --base-image NAME Use custom base image (default: rocker/r-ver)
  --next-steps      Show development workflow and next steps
  --help, -h        Show this help message

ENVIRONMENT VARIABLES:
  RRTOOLS_AUTHOR_NAME         Author name (default: Ronald G. Thomas)
  RRTOOLS_AUTHOR_EMAIL        Author email (default: rgthomas@ucsd.edu)
  RRTOOLS_INSTITUTE           Institute short name (default: UCSD)
  RRTOOLS_INSTITUTE_FULL      Full institute name (default: University of California, San Diego)

EXAMPLES:
  ./zzrrtools.sh                    # Full setup with Docker
  ./zzrrtools.sh --no-docker        # Setup without Docker build
  ./zzrrtools.sh --dotfiles ~/dotfiles # Include personal dotfiles (with dots)
  ./zzrrtools.sh --dotfiles-nodot ~/dotfiles # Include dotfiles (without dots)
  ./zzrrtools.sh --base-image myorg/r-base # Use custom base image
  ./zzrrtools.sh --next-steps       # Show workflow help

TROUBLESHOOTING:
  Docker build fails:
    - Try: export DOCKER_BUILDKIT=0 (disable BuildKit)
    - Check Docker has sufficient memory/disk space
    - Ensure Docker is running and up to date
  
  Platform warnings on ARM64:
    - Use updated Makefile with --platform linux/amd64 flags
    - Or set: export DOCKER_DEFAULT_PLATFORM=linux/amd64
  
  Permission errors in container:
    - Rebuild image after copying dotfiles
    - Check file ownership in project directory
  
  Package name errors:
    - Ensure directory name contains only letters/numbers/periods
    - Avoid underscores and special characters
  
  Missing dotfiles in container:
    - Use --dotfiles or --dotfiles-nodot flag during setup
    - Rebuild Docker image after adding dotfiles

EOF
            exit 0
            ;;
        --next-steps)
            show_workflow_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging functions with timestamps and better formatting
log_info() {
    printf "ℹ️  %s\n" "$*" >&2
}

log_warn() {
    printf "⚠️  %s\n" "$*" >&2
}

log_error() {
    printf "❌ %s\n" "$*" >&2
}

log_success() {
    printf "✅ %s\n" "$*" >&2
}

# Template copying and variable substitution functions
copy_template_file() {
    local template="$1"
    local dest="$2"
    local description="${3:-$dest}"
    
    [[ $# -ge 2 ]] || { log_error "copy_template_file: need template and destination"; return 1; }
    
    if [[ ! -f "$TEMPLATES_DIR/$template" ]]; then
        log_error "Template not found: $TEMPLATES_DIR/$template"
        return 1
    fi
    
    if [[ -f "$dest" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    local dest_dir
    dest_dir=$(dirname "$dest")
    if [[ "$dest_dir" != "." ]] && [[ ! -d "$dest_dir" ]]; then
        if ! mkdir -p "$dest_dir"; then
            log_error "Failed to create directory: $dest_dir"
            return 1
        fi
    fi
    
    # Copy template and substitute variables
    if ! cp "$TEMPLATES_DIR/$template" "$dest"; then
        log_error "Failed to copy template: $template"
        return 1
    fi
    
    if ! substitute_variables "$dest"; then
        log_error "Failed to substitute variables in: $dest"
        return 1
    fi
    
    log_info "Created $description from template"
}

substitute_variables() {
    local file="$1"
    
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    
    # Export variables for envsubst
    export PKG_NAME AUTHOR_NAME AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE
    export R_VERSION="${R_VERSION:-latest}"
    
    if ! envsubst < "$file" > "$file.tmp" && mv "$file.tmp" "$file"; then
        log_error "Failed to substitute variables in file: $file"
        rm -f "$file.tmp"
        return 1
    fi
}

# Function to safely create file if it doesn't exist (for simple content)
create_file_if_missing() {
    local file_path="$1"
    local content="$2"
    local description="${3:-$file_path}"
    
    [[ $# -ge 2 ]] || { log_error "create_file_if_missing: need file_path and content"; return 1; }
    
    if [[ -f "$file_path" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create directory if needed
    local dir
    dir=$(dirname "$file_path")
    if [[ "$dir" != "." ]] && [[ ! -d "$dir" ]]; then
        if ! mkdir -p "$dir"; then
            log_error "Failed to create directory: $dir"
            return 1
        fi
    fi
    
    # Use printf for safer output
    if ! printf '%s\n' "$content" > "$file_path"; then
        log_error "Failed to create file: $file_path"
        return 1
    fi
    
    log_info "Created $description"
}

# Function to check if command exists
command_exists() {
    [[ $# -eq 1 ]] || { log_error "command_exists: need command name"; return 1; }
    command -v "$1" >/dev/null 2>&1
}

# Create core directory structure
create_directory_structure() {
    log_info "Creating directory structure..."
    
    local -r dirs=(
        "R"
        "man" 
        "tests/testthat"
        "vignettes"
        "data"
        "data/raw_data"
        "data/derived_data"
        "data/metadata"
        "data/validation"
        "analysis"
        "analysis/paper"
        "analysis/figures"
        "analysis/tables"
        "analysis/templates"
        "scripts"
        "archive"
        "docs"
        ".github/workflows"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" || { log_error "Failed to create directory: $dir"; return 1; }
    done
    
    log_success "Directory structure created"
}

# Create core R package files
create_core_files() {
    local pkg_name="$PKG_NAME"
    local year=$(date +%Y)
    
    log_info "Creating core R package files..."
    
    # DESCRIPTION file
    copy_template_file "DESCRIPTION" "DESCRIPTION" "DESCRIPTION file"

    # LICENSE file (GPL-3 doesn't require a separate LICENSE file, but we'll create a note)
    create_file_if_missing "LICENSE" "This package is licensed under GPL-3.
See https://www.gnu.org/licenses/gpl-3.0.en.html for details."

    # NAMESPACE file
    create_file_if_missing "NAMESPACE" "# Generated by roxygen2: do not edit by hand

export(create_ar1_corr)"

    # Copy R utility functions from template
    copy_template_file "R/utils.R" "R/utils.R" "R utility functions"

    # Create R project file
    create_file_if_missing "${pkg_name}.Rproj" "Version: 1.0

RestoreWorkspace: Default
SaveWorkspace: Default
AlwaysSaveHistory: Default

EnableCodeIndexing: Yes
UseSpacesForTab: Yes
NumSpacesForTab: 2
Encoding: UTF-8

RnwWeave: Sweave
LaTeX: pdfLaTeX

AutoAppendNewline: Yes
StripTrailingWhitespace: Yes

BuildType: Package
PackageUseDevtools: Yes
PackageInstallArgs: --no-multiarch --with-keep.source"

    # Test files
    mkdir -p "tests"
    create_file_if_missing "tests/testthat.R" "library(testthat)
library($pkg_name)

test_check(\"$pkg_name\")"

    # Basic test file
    mkdir -p "tests/testthat"
    create_file_if_missing "tests/testthat/test-utils.R" "test_that(\"AR(1) correlation matrix works\", {
  corr_mat <- create_ar1_corr(3, 0.5)
  expect_equal(dim(corr_mat), c(3, 3))
  expect_equal(corr_mat[1,1], 1)
  expect_equal(corr_mat[1,2], 0.5)
})"

    log_success "Core R package files created"
}

# Create Docker configuration files
create_docker_files() {
    log_info "Creating Docker configuration files..."
    
    # Determine R version
    local r_version="latest"
    if [[ -f "renv.lock" ]]; then
        r_version=$(extract_r_version_from_lockfile)
    fi
    R_VERSION="$r_version"
    
    # Copy Dockerfile from template
    copy_template_file "Dockerfile" "Dockerfile" "Dockerfile"
    
    # Copy docker-compose.yml from template  
    copy_template_file "docker-compose.yml" "docker-compose.yml" "Docker Compose configuration"
    
    # Copy .zshrc_docker for container shell configuration
    copy_template_file ".zshrc_docker" ".zshrc_docker" "zsh configuration for Docker container"
    
    # Copy additional support files
    copy_template_file "check_renv_for_commit.R" "check_renv_for_commit.R" "renv validation script"
    copy_template_file "ZZRRTOOLS_USER_GUIDE.md" "ZZRRTOOLS_USER_GUIDE.md" "comprehensive user guide"
    
    log_success "Docker configuration files created"
}

# Extract R version from renv.lock file
extract_r_version_from_lockfile() {
    if [[ -f "renv.lock" ]] && command_exists python3; then
        python3 -c "
import json
try:
    with open('renv.lock', 'r') as f:
        data = json.load(f)
        print(data.get('R', {}).get('Version', 'latest'))
except:
    print('latest')
" 2>/dev/null || echo "latest"
    else
        echo "latest"
    fi
}

# Create analysis and paper templates
create_analysis_files() {
    log_info "Creating analysis and paper files..."
    
    # Copy paper template
    copy_template_file "paper.Rmd" "analysis/paper/paper.Rmd" "Research paper template"
    
    # References file
    copy_template_file "references.bib" "analysis/paper/references.bib" "references.bib file"
    
    log_success "Analysis files created"
}

# Create GitHub Actions workflows
create_github_workflows() {
    log_info "Creating GitHub Actions workflows..."
    
    mkdir -p ".github/workflows"
    
    # Copy workflow templates
    copy_template_file "workflows/r-package.yml" ".github/workflows/r-package.yml" "R package check workflow"
    copy_template_file "workflows/render-paper.yml" ".github/workflows/render-paper.yml" "Paper rendering workflow"
    
    log_success "GitHub Actions workflows created"
}

# Create renv setup
create_renv_setup() {
    log_info "Creating renv setup..."
    
    # Copy renv setup script from template
    copy_template_file "setup_renv.R" "setup_renv.R" "renv setup script"
    
    log_success "renv setup created"
}

# Create Makefile
create_makefile() {
    log_info "Creating Makefile..."
    
    # Copy Makefile from template
    copy_template_file "Makefile" "Makefile" "Makefile for Docker workflow"
    
    log_success "Makefile created"
}

# Copy dotfiles if directory specified
copy_dotfiles() {
    if [[ -n "$DOTFILES_DIR" ]]; then
        log_info "Copying dotfiles from $DOTFILES_DIR..."
        
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            log_error "Dotfiles directory not found: $DOTFILES_DIR"
            return 1
        fi
        
        if [[ "$DOTFILES_NODOT" = true ]]; then
            # Files without leading dots (e.g., vimrc -> .vimrc)
            local dotfiles=("vimrc" "tmux.conf" "gitconfig" "inputrc" "bashrc" "profile" "aliases" "functions" "exports" "editorconfig" "ctags" "ackrc" "ripgreprc")
            
            for dotfile in "${dotfiles[@]}"; do
                if [[ -f "$DOTFILES_DIR/$dotfile" ]]; then
                    cp "$DOTFILES_DIR/$dotfile" ".$dotfile"
                    log_info "Copied $dotfile -> .$dotfile"
                fi
            done
        else
            # Files with leading dots (e.g., .vimrc)
            local dotfiles=(".vimrc" ".tmux.conf" ".gitconfig" ".inputrc" ".bashrc" ".profile" ".aliases" ".functions" ".exports" ".editorconfig" ".ctags" ".ackrc" ".ripgreprc")
            
            for dotfile in "${dotfiles[@]}"; do
                if [[ -f "$DOTFILES_DIR/$dotfile" ]]; then
                    cp "$DOTFILES_DIR/$dotfile" "."
                    log_info "Copied $dotfile"
                fi
            done
        fi
        
        log_success "Dotfiles copied"
    fi
}

# Create other configuration files
create_config_files() {
    log_info "Creating configuration files..."
    
    # Copy personal dotfiles first (if specified)
    copy_dotfiles
    
    # .gitignore
    copy_template_file ".gitignore" ".gitignore" ".gitignore file"

    # .Rprofile
    copy_template_file ".Rprofile" ".Rprofile" ".Rprofile file"

    log_success "Configuration files created"
}

# Create symbolic links for convenience
create_symbolic_links() {
    log_info "Creating symbolic links for convenience..."
    
    # Remove existing symlinks to avoid conflicts
    local symlinks=("a" "n" "f" "t" "s" "m" "e" "o" "c" "p")
    for link in "${symlinks[@]}"; do
        [[ -L "$link" ]] && rm "$link"
    done
    
    # Create new symlinks
    ln -s ./data a                    # a -> data
    ln -s ./analysis n                # n -> analysis  
    ln -s ./analysis/figures f        # f -> analysis/figures
    ln -s ./analysis/tables t         # t -> analysis/tables
    ln -s ./scripts s                 # s -> scripts
    ln -s ./man m                     # m -> man
    ln -s ./tests e                   # e -> tests
    ln -s ./docs o                    # o -> docs
    ln -s ./archive c                 # c -> archive
    ln -s ./analysis/paper p          # p -> analysis/paper
    
    log_success "Symbolic links created"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker environment..."
    log_info "This may take several minutes on first build..."
    
    # Validate prerequisites
    if ! command_exists docker; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if [[ ! -f "Dockerfile" ]]; then
        log_error "Dockerfile not found in current directory"
        return 1
    fi
    
    # Validate required variables
    if [[ -z "$R_VERSION" ]]; then
        log_error "R_VERSION is not set"
        return 1
    fi
    
    if [[ -z "$PKG_NAME" ]]; then
        log_error "PKG_NAME is not set"
        return 1
    fi
    
    # Auto-detect platform and set Docker build args
    local DOCKER_PLATFORM=""
    case "$(uname -m)" in
        arm64|aarch64) 
            DOCKER_PLATFORM="--platform linux/amd64"
            log_info "Using linux/amd64 platform for ARM compatibility"
            ;;
    esac
    
    # Build the Docker command
    local docker_cmd="DOCKER_BUILDKIT=1 docker build ${DOCKER_PLATFORM} --build-arg R_VERSION=\"$R_VERSION\" -t \"$PKG_NAME\" ."
    
    if eval "$docker_cmd"; then
        log_success "Docker image '$PKG_NAME' built successfully!"
    else
        log_error "Docker build failed - you can build manually later with:"
        log_error "   $docker_cmd"
        return 1
    fi
}

# Show workflow help and next steps
show_workflow_help() {
    echo "🚀 rrtools Development Workflow"
    echo
    echo "📋 What was created:"
    echo "  - Complete R package structure with documentation"
    echo "  - Analysis directory with paper, figures, and templates subdirectories"
    echo "  - Data directory with raw, derived, metadata, and validation subdirectories"
    echo "  - Scripts directory for working R files and code snippets"
    echo "  - Research paper template in analysis/paper/ with PDF output"
    echo "  - renv setup for package dependency management"
    echo "  - Docker integration with rocker/r-ver base image"
    echo "  - GitHub Actions CI/CD workflow for automated testing"
    echo "  - Symbolic links for convenient navigation"
    echo
    echo "🚀 Next steps:"
    echo "  1. Start developing: 'make docker-r' for R console"
    echo "  2. Or use RStudio: 'make docker-rstudio' → http://localhost:8787"
    echo "  3. Initialize renv: Run setup_renv.R in R"
    echo "  4. Edit your research paper in analysis/paper/paper.Rmd"
    echo "  5. Add your R functions in the R directory"
    echo "  6. Use symbolic links for quick navigation (e.g., 'cd p' for paper)"
    echo
    echo "💡 Useful commands:"
    echo "  - 'make help' - Show all Docker commands"
    echo "  - 'make docker-build' - Rebuild Docker image"
    echo "  - 'make docker-test' - Run tests"
    echo "  - 'make docker-render' - Render paper"
    echo
    echo "📚 More info: Read ZZRRTOOLS_USER_GUIDE.md for comprehensive documentation"
}

# Main execution
main() {
    log_info "Setting up rrtools research compendium in $(pwd)"
    log_info "Package name: $PKG_NAME"
    log_info "Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"
    
    # Check if templates directory exists
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found: $TEMPLATES_DIR"
        log_error "Make sure you're running the script from the correct location"
        exit 1
    fi
    
    create_directory_structure
    create_core_files
    create_config_files
    create_docker_files
    create_analysis_files
    create_github_workflows
    create_renv_setup
    create_makefile
    create_symbolic_links
    
    # Determine R version for Docker
    R_VERSION=$(extract_r_version_from_lockfile)
    log_info "Using R version: $R_VERSION"
    
    # Build Docker image if requested
    if [ "$BUILD_DOCKER" = true ]; then
        echo
        if command_exists docker; then
            build_docker_image
        else
            log_warn "Docker not found, skipping Docker build"
            log_info "Install Docker and run appropriate build command for your platform"
        fi
    else
        echo
        log_info "Skipped Docker build - no-docker flag used"
        log_info "Build manually when ready (see Makefile for platform-specific commands)"
    fi
    
    echo
    log_success "✅ rrtools research compendium setup complete!"
    echo
    echo "📋 What was created:"
    echo "  - Complete R package structure with documentation"
    echo "  - Analysis directory with paper, figures, and templates subdirectories"
    echo "  - Data directory with raw, derived, metadata, and validation subdirectories"
    echo "  - Scripts directory for working R files and code snippets"
    echo "  - Research paper template in analysis/paper/ with PDF output"
    echo "  - renv setup for package dependency management"
    echo "  - Docker integration with rocker/r-ver base image"
    echo "  - GitHub Actions CI/CD workflow for automated testing"
    echo "  - Symbolic links for convenient navigation"
    echo
    echo "🚀 Next steps:"
    echo "  1. Start developing: 'make docker-r' for R console"
    echo "  2. Or use RStudio: 'make docker-rstudio' → http://localhost:8787"
    echo "  3. Initialize renv: Run setup_renv.R in R"
    echo "  4. Edit your research paper in analysis/paper/paper.Rmd"
    echo "  5. Add your R functions in the R directory"
    echo "  6. Use symbolic links for quick navigation (e.g., 'cd p' for paper)"
    echo
    echo "💡 To see this help again: ~/prj/zzrrtools/zzrrtools.sh --next-steps"
    echo
}

# Run main function
main "$@"