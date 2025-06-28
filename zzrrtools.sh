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
PKG_NAME=$(basename "$(pwd)" | tr -cd '[:alnum:]_' | head -c 50)
if [[ -z "$PKG_NAME" ]]; then
    echo "❌ Error: Cannot determine valid package name from directory '$(basename "$(pwd)")'" >&2
    exit 1
fi
readonly PKG_NAME

# Parse command line arguments
BUILD_DOCKER=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-docker)
            BUILD_DOCKER=false
            shift
            ;;
        --help|-h)
            cat << EOF
Usage: rrtools.sh [OPTIONS]

Creates a complete rrtools research compendium with Docker support.

OPTIONS:
  --no-docker    Skip Docker image build during setup
  --help, -h     Show this help message

ENVIRONMENT VARIABLES:
  RRTOOLS_AUTHOR_NAME         Author name (default: Ronald G. Thomas)
  RRTOOLS_AUTHOR_EMAIL        Author email (default: rgthomas@ucsd.edu)
  RRTOOLS_INSTITUTE           Institute short name (default: UCSD)
  RRTOOLS_INSTITUTE_FULL      Full institute name (default: University of California, San Diego)

EXAMPLES:
  ./rrtools.sh                      # Full setup with Docker
  ./rrtools.sh --no-docker          # Setup without Docker build

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo "ℹ️  $*" >&2
}

log_warn() {
    echo "⚠️  $*" >&2
}

log_error() {
    echo "❌ $*" >&2
}

log_success() {
    echo "✅ $*" >&2
}

# Template copying and variable substitution functions
copy_template_file() {
    local template="$1"
    local dest="$2"
    local description="${3:-$dest}"
    
    if [[ ! -f "$TEMPLATES_DIR/$template" ]]; then
        log_error "Template not found: $TEMPLATES_DIR/$template"
        return 1
    fi
    
    if [[ -f "$dest" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    local dest_dir=$(dirname "$dest")
    [[ "$dest_dir" != "." ]] && mkdir -p "$dest_dir"
    
    # Copy template and substitute variables
    cp "$TEMPLATES_DIR/$template" "$dest"
    substitute_variables "$dest"
    log_info "Created $description from template"
}

substitute_variables() {
    local file="$1"
    
    # Use sed to replace template variables
    sed -i.bak \
        -e "s/\${PKG_NAME}/$PKG_NAME/g" \
        -e "s/\${AUTHOR_NAME}/$AUTHOR_NAME/g" \
        -e "s/\${AUTHOR_EMAIL}/$AUTHOR_EMAIL/g" \
        -e "s/\${AUTHOR_INSTITUTE}/$AUTHOR_INSTITUTE/g" \
        -e "s/\${AUTHOR_INSTITUTE_FULL}/$AUTHOR_INSTITUTE_FULL/g" \
        -e "s/\${R_VERSION}/${R_VERSION:-latest}/g" \
        "$file"
    
    # Clean up backup file
    rm -f "$file.bak"
}

# Function to safely create file if it doesn't exist (for simple content)
create_file_if_missing() {
    local file_path="$1"
    local content="$2"
    local description="${3:-$file_path}"
    
    if [[ -f "$file_path" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create directory if needed
    local dir=$(dirname "$file_path")
    [[ "$dir" != "." ]] && mkdir -p "$dir"
    
    echo "$content" > "$file_path"
    log_info "Created $description"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create core directory structure
create_directory_structure() {
    log_info "Creating directory structure..."
    
    local dirs=(
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
        mkdir -p "$dir"
    done
    
    log_success "Directory structure created"
}

# Create core R package files
create_core_files() {
    local pkg_name="$PKG_NAME"
    local year=$(date +%Y)
    
    log_info "Creating core R package files..."
    
    # DESCRIPTION file
    create_file_if_missing "DESCRIPTION" "Package: $pkg_name
Title: Research Compendium for $pkg_name
Version: 0.0.0.9000
Authors@R: 
    person(\"${AUTHOR_NAME}\", email = \"${AUTHOR_EMAIL}\", role = c(\"aut\", \"cre\"))
Description: This is a research compendium for the $pkg_name project.
License: MIT + file LICENSE
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.2.0
Suggests: 
    testthat (>= 3.0.0),
    knitr,
    rmarkdown
Config/testthat/edition: 3
VignetteBuilder: knitr"

    # LICENSE file
    create_file_if_missing "LICENSE" "YEAR: $year
COPYRIGHT HOLDER: ${AUTHOR_NAME}"

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
    create_file_if_missing "analysis/paper/references.bib" "@article{marwick2017,
  title={Computational reproducibility in archaeological research: basic principles and a case study of their implementation},
  author={Marwick, Ben},
  journal={Journal of Archaeological Method and Theory},
  volume={24},
  number={2},
  pages={424--450},
  year={2017},
  publisher={Springer}
}"
    
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

# Create other configuration files
create_config_files() {
    log_info "Creating configuration files..."
    
    # .gitignore
    create_file_if_missing ".gitignore" "# R specific
.Rhistory
.Rapp.history
.RData
.Ruserdata
.Rproj.user/

# renv
renv/library/
renv/local/
renv/cellar/
renv/lock/
renv/python/
renv/staging/

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE
.vscode/
.idea/

# Temporary files
*.tmp
*.temp
*~

# Log files
*.log

# Archives
*.tar.gz
*.zip

# Large data files that shouldn't be in container
analysis/data/raw_data/*.csv
analysis/data/derived_data/*.rds

# Generated outputs
analysis/figures/*.png
analysis/figures/*.pdf
analysis/paper/*.html
analysis/paper/*.pdf
analysis/paper/*.tex
analysis/paper/*_files/

# Docker
.dockerignore

# Python
__pycache__/
*.py[cod]
*\$py.class
.Python
env/
venv/
ENV/

# Node.js
node_modules/
npm-debug.log*"

    # .Rprofile
    create_file_if_missing ".Rprofile" "# Activate renv for this project
if (file.exists(\"renv/activate.R\")) {
  source(\"renv/activate.R\")
}

# Set CRAN mirror
options(repos = c(CRAN = \"https://cloud.r-project.org\"))

# Load common packages for interactive use
if (interactive()) {
  suppressMessages({
    if (requireNamespace(\"devtools\", quietly = TRUE)) library(devtools)
    if (requireNamespace(\"usethis\", quietly = TRUE)) library(usethis)
  })
}"

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
    
    if docker build --build-arg R_VERSION="$R_VERSION" -t "$PKG_NAME" .; then
        log_success "Docker image '$PKG_NAME' built successfully!"
    else
        log_error "Docker build failed - you can build manually later with:"
        log_error "   docker build --build-arg R_VERSION=$R_VERSION -t $PKG_NAME ."
        return 1
    fi
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
            log_info "Install Docker and run: docker build --build-arg R_VERSION=$R_VERSION -t $PKG_NAME ."
        fi
    else
        echo
        log_info "Skipped Docker build - no-docker flag used"
        log_info "Build manually when ready: docker build --build-arg R_VERSION=$R_VERSION -t $PKG_NAME ."
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
    echo "  - Docker integration with rocker/verse base image"
    echo "  - GitHub Actions CI/CD workflow for automated testing"
    echo "  - Symbolic links for convenient navigation"
    echo
    echo "🚀 Next steps:"
    echo "  1. Run 'docker build -t $PKG_NAME .' if you skipped Docker build"
    echo "  2. Start developing: 'docker run -it --rm -v \$(pwd):/project $PKG_NAME'"
    echo "  3. Initialize renv: Run setup_renv.R in R"
    echo "  4. Edit your research paper in analysis/paper/paper.Rmd"
    echo "  5. Add your R functions in the R directory"
    echo "  6. Use symbolic links for quick navigation (e.g., 'cd p' for paper)"
    echo
}

# Run main function
main "$@"