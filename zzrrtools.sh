#!/bin/bash
# Create rrtools-compatible R package structure in the current directory
# This script reorganizes existing files and sets up an rrtools framework

# Bash safety options
set -euo pipefail

# Auto-detect script directory and make configuration customizable
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AUTHOR_NAME="${RRTOOLS_AUTHOR_NAME:-Ronald G. Thomas}"
readonly AUTHOR_EMAIL="${RRTOOLS_AUTHOR_EMAIL:-rgthomas@ucsd.edu}"
readonly AUTHOR_INSTITUTE="${RRTOOLS_INSTITUTE:-UCSD}"
readonly AUTHOR_INSTITUTE_FULL="${RRTOOLS_INSTITUTE_FULL:-University of California, San Diego}"
readonly BASE_PATH="${RRTOOLS_BASE_PATH:-$SCRIPT_DIR}"

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
            cat << 'EOF'
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
  RRTOOLS_BASE_PATH           Base path for support files (default: script directory)

EXAMPLES:
  ./rrtools.sh                      # Full setup with Docker
  ./rrtools.sh --no-docker          # Setup without Docker build
  RRTOOLS_AUTHOR_NAME="Jane Doe" ./rrtools.sh  # Custom author
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

# Utility functions
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate Docker installation and functionality
validate_docker() {
    if [[ "$BUILD_DOCKER" == "true" ]]; then
        log_info "Validating Docker installation..."
        
        if ! command_exists docker; then
            log_error "Docker is required but not found. Install Docker or use --no-docker flag"
            exit 1
        fi
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Docker is installed but not running. Start Docker or use --no-docker flag"
            exit 1
        fi
        
        log_success "Docker validation complete"
    fi
}

# Function to extract R version from renv.lock using Docker
extract_r_version() {
    local container_image="${1:-rocker/r-ver:latest}"
    local mount_path="${2:-/work}"
    
    if [[ ! -f "renv.lock" ]]; then
        echo "latest"
        return 0
    fi
    
    log_info "Extracting R version from renv.lock..."
    
    # Validate Docker before using it
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker not available for R version extraction, using 'latest'"
        echo "latest"
        return 0
    fi
    
    local r_version
    r_version=$(docker run --rm -v "$(pwd):${mount_path}" -w "${mount_path}" "${container_image}" R --slave -e "
        tryCatch({
            if (!requireNamespace('jsonlite', quietly = TRUE)) {
                cat('latest')
            } else {
                lockfile <- jsonlite::read_json('renv.lock')
                cat(lockfile\$R\$Version %||% 'latest')
            }
        }, error = function(e) {
            cat('latest')
        })
    " 2>/dev/null || echo "latest")
    
    echo "$r_version"
}

# Function to cleanup temporary Docker images
cleanup_temp_image() {
    if docker images -q "${PKG_NAME}_temp" >/dev/null 2>&1; then
        log_info "Cleaning up temporary Docker image..."
        docker tag "${PKG_NAME}_temp" "${PKG_NAME}" 2>/dev/null || true
        docker rmi "${PKG_NAME}_temp" >/dev/null 2>&1 || true
    fi
}

# Function for structured output
print_section() {
    local title="$1"
    shift
    local items=("$@")
    
    echo "$title"
    for item in "${items[@]}"; do
        echo "$item"
    done
    echo ""
}

# Enhanced file copying function with rollback capability
copy_file_with_status() {
    local source="$1"
    local dest="$2"
    local description="$3"
    local make_executable="${4:-false}"
    
    if [[ ! -f "$source" ]]; then
        log_warn "${description} not found at $source"
        return 1
    fi
    
    # Create backup if destination exists
    if [[ -f "$dest" ]]; then
        cp "$dest" "${dest}.backup.$(date +%s)" 2>/dev/null || true
    fi
    
    log_info "Copying ${description}..."
    if cp "$source" "$dest"; then
        [[ "$make_executable" == "true" ]] && chmod +x "$dest"
        return 0
    else
        log_error "Failed to copy ${description}"
        return 1
    fi
}

# Function to copy external files to project
copy_external_files() {
    log_info "Copying external files..."
    
    # Copy script itself first
    copy_file_with_status "$0" "./rrtools.sh" "rrtools setup script" "true"
    
    # Define all files to copy in single array (source:dest:description:executable)
    local files_to_copy=(
        "${BASE_PATH}/RRTOOLS_USER_GUIDE.md:./RRTOOLS_USER_GUIDE.md:rrtools user guide:false"
        "${BASE_PATH}/check_renv_for_commit.R:./check_renv_for_commit.R:renv validation script:true"
        "${BASE_PATH}/.zshrc_docker:./.zshrc_docker:container-specific .zshrc:false"
        "$HOME/.vimrc:./.vimrc:vim configuration:false"
        "$HOME/.tmux.conf:./.tmux.conf:tmux configuration:false"
        "$HOME/.gitconfig:./.gitconfig:git configuration:false"
        "$HOME/.inputrc:./.inputrc:readline configuration:false"
        "$HOME/.bashrc:./.bashrc:bash configuration:false"
        "$HOME/.profile:./.profile:shell profile:false"
        "$HOME/.aliases:./.aliases:shell aliases:false"
        "$HOME/.functions:./.functions:shell functions:false"
        "$HOME/.exports:./.exports:environment variables:false"
        "$HOME/.editorconfig:./.editorconfig:editor configuration:false"
        "$HOME/.ctags:./.ctags:ctags configuration:false"
        "$HOME/.ackrc:./.ackrc:ack search tool configuration:false"
        "$HOME/.ripgreprc:./.ripgreprc:ripgrep search configuration:false"
    )
    
    # Process all files in unified loop with failure tracking
    local failed_copies=0
    for file_spec in "${files_to_copy[@]}"; do
        IFS=':' read -r source dest description executable <<< "$file_spec"
        copy_file_with_status "$source" "$dest" "$description" "$executable" || ((failed_copies++))
    done
    
    # Special handling for git config (remove personal info for container)
    if [[ -f "./.gitconfig" ]]; then
        log_info "Sanitizing .gitconfig for container use..."
        sed -i.bak '/^\[user\]/,/^\[/ { /^\[user\]/d; /^[[:space:]]*name/d; /^[[:space:]]*email/d; }' ./.gitconfig 2>/dev/null || true
        rm -f ./.gitconfig.bak 2>/dev/null || true
    fi
    
    if [[ $failed_copies -gt 0 ]]; then
        log_warn "$failed_copies files could not be copied (this is usually OK)"
    fi
    
    log_success "External files copied"
}

# Function to create multiple files in batch
create_core_files() {
    local pkg_name="$1"
    local year=$(date +"%Y")
    
    # Create core package files
    create_file_if_missing "DESCRIPTION" "Package: $pkg_name
Title: Research Project
Version: 0.1.0
Authors@R: 
    person(\"${AUTHOR_NAME%% *}\", \"${AUTHOR_NAME#* }\", email = \"${AUTHOR_EMAIL}\", role = c(\"aut\", \"cre\"))
Description: Research project using rrtools framework for reproducible research.
License: GPL-3 + file LICENSE
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.2.3
Imports:
    knitr,
    rmarkdown
Suggests:
    devtools,
    usethis,
    roxygen2,
    testthat (>= 3.0.0),
    renv
Config/testthat/edition: 3"

    create_file_if_missing "LICENSE" "YEAR: $year
COPYRIGHT HOLDER: ${AUTHOR_NAME}"

    create_file_if_missing "NAMESPACE" "# Generated by roxygen2: do not edit by hand

export(create_ar1_corr)"

    # Create utility functions
    create_file_if_missing "R/utils.R" "#' Create AR(1) correlation matrix
#'
#' @param n_times Number of time points
#' @param rho Correlation parameter
#' @return A correlation matrix with AR(1) structure
#' @export
create_ar1_corr <- function(n_times, rho) {
  matrix(rho^abs(outer(1:n_times, 1:n_times, \"-\")), n_times, n_times)
}"

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

    # Create test stub
    create_file_if_missing "tests/testthat.R" "library(testthat)
library(${pkg_name})

test_check(\"${pkg_name}\")"

    # Create .gitignore
    create_file_if_missing ".gitignore" "# R specific
.Rproj.user
.Rhistory
.RData
.Ruserdata
*.Rproj

# Generated files
vignettes/*.html
vignettes/*.pdf
inst/doc/*.html
inst/doc/*.pdf
*.log
*.aux
*.out
*.toc
*.tex

# renv
renv/library/
renv/python/

# Temporary files
*~
.DS_Store
Thumbs.db

# Large data files
#data/raw_data/*
#data/derived_data/*"

    # Create .Rprofile
    create_file_if_missing ".Rprofile" "# Activate renv for this project
if (file.exists(\"renv/activate.R\")) {
  source(\"renv/activate.R\")
}

# Set CRAN mirror
options(repos = c(CRAN = \"https://cloud.r-project.org\"))

# Load conflicted package to handle namespace conflicts
if (requireNamespace(\"conflicted\", quietly = TRUE)) {
  library(conflicted)
}"

    # Create .dockerignore
    create_file_if_missing ".dockerignore" "# Git
.git
.gitignore

# R
.Rhistory
.RData
.Ruserdata
*.Rproj
.Rproj.user

# renv library (will be restored from lockfile)
renv/library/
renv/python/
renv/staging/

# Temporary files
*~
.DS_Store
Thumbs.db

# Personal dotfiles (copied selectively)
.bash_history
.zsh_history
.vscode/
.ssh/
.aws/
.docker/
.gradle/
.npm/
.cache/

# Large data files that shouldn't be in container
analysis/data/raw_data/*.csv
analysis/data/derived_data/*.rds

# Generated outputs
analysis/figures/*.png
analysis/figures/*.pdf
analysis/paper/*.html
analysis/paper/*.pdf
analysis/paper/*.docx

# Archive
archive/

# Documentation
docs/*.pdf"
}

# Function to generate Docker configuration files
generate_docker_config() {
    local pkg_name="$1"
    local r_version="$2"
    
    # Generate Dockerfile
    create_file_if_missing "Dockerfile" "FROM rocker/verse:${r_version}

# Install system dependencies and development tools
RUN apt-get update && apt-get install -y \\
    # R package dependencies
    libxml2-dev \\
    libcurl4-openssl-dev \\
    libssl-dev \\
    libgit2-dev \\
    libfontconfig1-dev \\
    libcairo2-dev \\
    libxt-dev \\
    # Shell and development tools
    zsh \\
    bash-completion \\
    curl \\
    wget \\
    git \\
    # Text editors and terminal tools
    vim \\
    nano \\
    tmux \\
    screen \\
    htop \\
    tree \\
    # Search and file tools
    ripgrep \\
    fd-find \\
    fzf \\
    # Build tools
    build-essential \\
    make \\
    cmake \\
    # Network and debugging tools
    less \\
    man-db \\
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with zsh as default shell
ARG USERNAME=analyst
RUN useradd --create-home --shell /bin/zsh \${USERNAME}

# Install renv
RUN R -e \"install.packages('renv', repos = c(CRAN = 'https://cloud.r-project.org'))\""

# Set working directory
WORKDIR /home/\${USERNAME}/project

# Copy project files first (for better Docker layer caching)
COPY --chown=\${USERNAME}:\${USERNAME} DESCRIPTION .
COPY --chown=\${USERNAME}:\${USERNAME} renv.lock* ./
COPY --chown=\${USERNAME}:\${USERNAME} .Rprofile* ./
COPY --chown=\${USERNAME}:\${USERNAME} renv/activate.R* renv/activate.R

# Configure renv library path
ENV RENV_PATHS_LIBRARY renv/library

# Switch to non-root user for R package installation
USER \${USERNAME}

# Restore R packages from lockfile (if exists)
RUN R -e "if (file.exists('renv.lock')) renv::restore() else cat('No renv.lock found, skipping restore\\n')\"

# Copy dotfiles (consolidated with wildcards)
COPY --chown=\${USERNAME}:\${USERNAME} .vimrc* .tmux.conf* .gitconfig* .inputrc* .bashrc* .profile* .aliases* .functions* .exports* .editorconfig* .ctags* .ackrc* .ripgreprc* /home/\${USERNAME}/
COPY --chown=\${USERNAME}:\${USERNAME} .zshrc_docker /home/\${USERNAME}/.zshrc"

# Install zsh plugins
RUN mkdir -p /home/\${USERNAME}/.zsh && \\
    git clone https://github.com/zsh-users/zsh-autosuggestions /home/\${USERNAME}/.zsh/zsh-autosuggestions && \\
    chown -R \${USERNAME}:\${USERNAME} /home/\${USERNAME}/.zsh

# Install vim-plug and vim plugins
RUN mkdir -p /home/\${USERNAME}/.vim/autoload && \\
    curl -fLo /home/\${USERNAME}/.vim/autoload/plug.vim \\
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim && \\
    chown -R \${USERNAME}:\${USERNAME} /home/\${USERNAME}/.vim

# Install vim plugins (suppress interactive mode)
RUN vim +PlugInstall +qall || true

# Copy rest of project
COPY --chown=\${USERNAME}:\${USERNAME} . .

# Install the research compendium as a package
RUN R -e "devtools::install('.', dependencies = TRUE)"

# Set default shell and working directory
WORKDIR /home/\${USERNAME}/project
CMD [\"/bin/zsh\"]"

    # Generate docker-compose.yml
    create_file_if_missing "docker-compose.yml" "version: '3.8'

services:
  # RStudio Server for GUI users
  rstudio:
    build: .
    ports:
      - \"8787:8787\"
    volumes:
      - .:/project
      - renv-cache:/renv/cache
    environment:
      - DISABLE_AUTH=true
      - RENV_PATHS_CACHE=/renv/cache
    working_dir: /project
    
  # R session for command line users
  r-session:
    build: .
    volumes:
      - .:/project
      - renv-cache:/renv/cache
    environment:
      - RENV_PATHS_CACHE=/renv/cache
    working_dir: /project
    stdin_open: true
    tty: true
    command: R
    
  # Bash session for command line users  
  bash:
    build: .
    volumes:
      - .:/project
      - renv-cache:/renv/cache
    environment:
      - RENV_PATHS_CACHE=/renv/cache
    working_dir: /project
    stdin_open: true
    tty: true
    command: /bin/bash
    
  # Research paper rendering
  research:
    build: .
    volumes:
      - .:/project
      - renv-cache:/renv/cache
      - ./analysis/paper:/output
    environment:
      - RENV_PATHS_CACHE=/renv/cache
    working_dir: /project
    command: R -e "rmarkdown::render('analysis/paper/paper.Rmd', output_dir = '/output')"

  # Package testing
  test:
    build: .
    volumes:
      - .:/project
      - renv-cache:/renv/cache
    environment:
      - RENV_PATHS_CACHE=/renv/cache
    working_dir: /project
    command: R -e "devtools::test()"

  # Package checking
  check:
    build: .
    volumes:
      - .:/project
      - renv-cache:/renv/cache
    environment:
      - RENV_PATHS_CACHE=/renv/cache
    working_dir: /project
    command: R -e "devtools::check()"

volumes:
  renv-cache:"
}

# Function to generate Makefile with consistent patterns
generate_makefile() {
    local pkg_name="$1"
    
    cat > Makefile << EOF
# Makefile for ${pkg_name} project

# Default target
all: document build check

# Native R commands (require R installation)
document:
	Rscript -e \"devtools::document()\"

build:
	Rscript -e \"devtools::build()\"

check:
	Rscript -e \"devtools::check()\"

install:
	Rscript -e \"devtools::install()\"

vignettes:
	Rscript -e \"devtools::build_vignettes()\"

test:
	Rscript -e \"devtools::test()\"

deps:
	Rscript setup_renv.R

check-renv:
	Rscript check_renv_for_commit.R

check-renv-fix:
	Rscript check_renv_for_commit.R --fix

check-renv-ci:
	Rscript check_renv_for_commit.R --quiet --fail-on-issues

# Docker commands (work without local R installation)
docker-build:
	docker build -t ${pkg_name} .

EOF

    # Generate Docker targets directly
    cat >> Makefile << EOF
docker-document:
	docker run --rm -v \$(PWD):/project ${pkg_name} R -e \"devtools::document()\"

docker-build-pkg:
	docker run --rm -v \$(PWD):/project ${pkg_name} R -e \"devtools::build()\"

docker-vignettes:
	docker run --rm -v \$(PWD):/project ${pkg_name} R -e \"devtools::build_vignettes()\"

docker-check-renv:
	docker run --rm -v \$(PWD):/project ${pkg_name} Rscript check_renv_for_commit.R

docker-check-renv-fix:
	docker run --rm -v \$(PWD):/project ${pkg_name} Rscript check_renv_for_commit.R --fix

EOF
    
    # Add Docker Compose targets
    cat >> Makefile << EOF
# Docker Compose services
docker-check:
	docker-compose run --rm check

docker-test:
	docker-compose run --rm test

docker-render:
	docker-compose run --rm research

docker-r:
	docker-compose run --rm r-session

docker-bash:
	docker-compose run --rm bash

docker-rstudio:
	docker-compose up rstudio

# Clean up
clean:
	rm -rf ${pkg_name}_*.tar.gz
	rm -rf ${pkg_name}.Rcheck
	rm -rf inst/doc/*.html
	rm -rf inst/doc/*.pdf

docker-clean:
	docker rmi ${pkg_name} || true
	docker-compose down --volumes

# Help
help:
	@echo "Available targets:"
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo "    check-renv, check-renv-fix, check-renv-ci"
	@echo ""
	@echo "  Docker - works without local R:"
	@echo "    docker-build, docker-document, docker-build-pkg"
	@echo "    docker-check, docker-test, docker-vignettes, docker-render"
	@echo "    docker-r, docker-bash, docker-rstudio"
	@echo "    docker-check-renv, docker-check-renv-fix"
	@echo ""
	@echo "  Cleanup:"
	@echo "    clean, docker-clean"

.PHONY: all document build check install vignettes test deps check-renv check-renv-fix check-renv-ci docker-build docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-r docker-bash docker-rstudio docker-check-renv docker-check-renv-fix clean docker-clean help
EOF
}

# Function to safely create file if it doesn't exist
create_file_if_missing() {
    local file_path="$1"
    local content="$2"
    local description="${3:-$file_path}"
    
    if [[ -f "$file_path" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Ensure parent directory exists
    local parent_dir
    parent_dir="$(dirname "$file_path")"
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir" || {
            log_error "Failed to create directory $parent_dir"
            return 1
        }
    fi
    
    log_info "Creating $description..."
    if echo "$content" > "$file_path"; then
        return 0
    else
        log_error "Failed to create $description"
        return 1
    fi
}

# Function to organize files efficiently
organize_files() {
    echo "Organizing existing files..."
    
    # Define file patterns and destinations
    declare -A file_destinations=(
        ["*.R"]="scripts"
        ["*.Rmd"]="analysis"
        ["*.rmd"]="analysis"
        ["*.csv"]="data/raw_data"
        ["*.CSV"]="data/raw_data"
        ["*.pdf"]="docs"
        ["*.PDF"]="docs"
    )
    
    # Create a list of important files to preserve in root
    local preserve_files="setup_renv.R DESCRIPTION LICENSE README.md .gitignore Makefile Dockerfile docker-compose.yml .Rprofile .dockerignore ${PKG_NAME}.Rproj"
    
    # Move files based on patterns
    for pattern in "${!file_destinations[@]}"; do
        destination="${file_destinations[$pattern]}"
        for file in $pattern; do
            if [ -f "$file" ] && [ ! -f "$destination/$(basename "$file")" ]; then
                # Skip setup_renv.R which should stay in root
                if [[ "$file" == "setup_renv.R" && "$destination" == "R" ]]; then
                    continue
                fi
                echo "Moving $file to $destination/"
                mv "$file" "$destination/"
            fi
        done
    done
    
    # Move remaining files to archive (excluding important ones)
    for file in *; do
        if [ -f "$file" ] && [[ ! " $preserve_files " =~ " $(basename "$file") " ]]; then
            echo "Moving $file to archive/"
            mv "$file" "archive/"
        fi
    done
}

# Validate environment early
validate_docker

log_info "Running from directory: $(pwd)"
log_info "Using package name: $PKG_NAME"
log_info "Creating rrtools-compatible project structure..."

# Function to create project directory structure
create_project_directories() {
    echo "Creating directory structure..."
    
    # Define directory structure as array for easier maintenance
    local directories=(
        "R"
        "man" 
        "analysis/paper"
        "analysis/figures"
        "analysis/templates"
        "analysis/tables"
        "data/raw_data"
        "data/derived_data"
        "data/metadata"
        "data/validation"
        "data/external_data"
        "scripts"
        "inst/doc"
        "tests/testthat"
        "vignettes"
        "docs"
        "archive"
        ".github/workflows"
    )
    
    # Create all directories in one call
    mkdir -p "${directories[@]}"
}

# 1. Create project directories
create_project_directories

# 2. Create core package files
create_core_files "${PKG_NAME}"

# 4. Organize existing files
organize_files

# 5. Create research templates
create_vignette_template() {
    {
        printf "---\\n"
        printf "title: \"%s Research Project\"\\n" "$PKG_NAME"
        printf "author: \"%s\"\\n" "$AUTHOR_NAME" 
        printf "date: \"$(date +%Y-%m-%d)\"\\n"
        printf "output: rmarkdown::html_vignette\\n"
        printf "vignette: >\\n"
        printf "  %%\\\\VignetteIndexEntry{%s Research Project}\\n" "$PKG_NAME"
        printf "  %%\\\\VignetteEngine{knitr::rmarkdown}\\n"
        printf "  %%\\\\VignetteEncoding{UTF-8}\\n"
        printf "---\\n\\n"
        printf "\\\`\\\`\\\`{r, include = FALSE}\\n"
        printf "knitr::opts_chunk\\$set(\\n"
        printf "  collapse = TRUE,\\n"
        printf "  comment = \"#>\"\\n"
        printf ")\\n"
        printf "\\\`\\\`\\\`\\n\\n"
        printf "\\\`\\\`\\\`{r setup}\\n"
        printf "library(%s)\\n" "$PKG_NAME"
        printf "\\\`\\\`\\\`\\n\\n"
        printf "# Introduction\\n\\n"
        printf "This is a template for the %s research project.\\n\\n" "$PKG_NAME"
        printf "# Methods\\n\\nDescribe your methods here.\\n\\n"
        printf "# Results\\n\\nPresent your results here.\\n\\n"
        printf "# Discussion\\n\\nDiscuss your findings here.\\n"
    } > "vignettes/${PKG_NAME}-main.Rmd"
}

if [[ ! -f "vignettes/${PKG_NAME}-main.Rmd" ]]; then
    log_info "Creating vignette template..."
    create_vignette_template
else
    log_info "Vignette template already exists, skipping creation"
fi

create_file_if_missing "analysis/paper/paper.Rmd" "---
title: \"Title Goes Here\"
author:
  - ${AUTHOR_NAME}:
      email: ${AUTHOR_EMAIL}
      institute: [${AUTHOR_INSTITUTE}]
      correspondence: true
institute:
  - ${AUTHOR_INSTITUTE}: ${AUTHOR_INSTITUTE_FULL}
date: \"\\`r format(Sys.time(), '%d %B, %Y')\\`\"
output:
  bookdown::pdf_document2:
    fig_caption: yes
    number_sections: true
    toc: false
    keep_tex: true
bibliography: references.bib
csl: \"../templates/statistics-in-medicine.csl\"
abstract: |
  Text of abstract
keywords: |
  keyword 1; keyword 2; keyword 3
highlights: |
  These are the highlights.
---

\`\`\`{r setup, include=FALSE}
knitr::opts_chunk\$set(
  echo = FALSE,
  message = FALSE,
  warning = FALSE,
  fig.path = \"../figures/\",
  dpi = 300
)
library(${PKG_NAME})
# other packages
library(rmarkdown)
library(knitr)
\`\`\`

# Introduction

Here is the text of your introduction.

# Materials and methods

Here are the methods.

# Results

Here are the results.

# Discussion

Discussion text goes here.

# Conclusion

Conclusions text goes here.

# References"

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

# 6. Download CSL style with integrity checking
download_csl_style() {
    local csl_file="analysis/templates/statistics-in-medicine.csl"
    
    if [[ -f "$csl_file" ]]; then
        log_info "CSL template already exists, skipping download"
        return 0
    fi
    
    if command_exists curl; then
        log_info "Downloading CSL style..."
        local url="https://raw.githubusercontent.com/citation-style-language/styles/master/statistics-in-medicine.csl"
        
        if curl -fsSL "$url" -o "$csl_file"; then
            # Basic validation - check if it looks like a CSL file
            if grep -q "citation-style-language" "$csl_file" 2>/dev/null; then
                log_success "CSL style downloaded successfully"
            else
                log_warn "Downloaded file doesn't appear to be a valid CSL file"
                rm -f "$csl_file"
            fi
        else
            log_warn "Could not download CSL file from $url"
        fi
    else
        log_warn "curl not found, CSL file not downloaded"
    fi
}

download_csl_style

# 7. Create renv setup
create_file_if_missing "setup_renv.R" "# Run this in R to set up renv
if (!requireNamespace(\"renv\", quietly = TRUE)) {
  install.packages(\"renv\")
}
renv::init(settings = list(snapshot.type = \"explicit\"))

# Install minimal required packages for rrtools functionality
install.packages(c(
  # Package development essentials
  \"devtools\", \"usethis\", \"roxygen2\", \"testthat\",
  
  # Documentation and reporting
  \"knitr\", \"rmarkdown\",
  
  # Package management
  \"renv\"
))

# Take snapshot of the environment
renv::snapshot()"

# 8a. renv setup (Docker-first approach)
echo "📦 renv environment will be initialized in Docker container"
echo "⚠️  To initialize renv locally (optional): run 'source(\"setup_renv.R\")' in R"

# Note: .gitignore, .Rproj, tests, .Rprofile, .dockerignore now created by create_core_files

# 11. Create Makefile
generate_makefile "${PKG_NAME}"

# 12. Create Docker configuration
# Get R version from renv.lock or use latest (Docker-first approach)
if [ -f "renv.lock" ]; then
    echo "Found renv.lock, extracting R version..."
    R_VERSION=$(extract_r_version)
    if [ "$R_VERSION" != "latest" ]; then
        echo "Using R version $R_VERSION from renv.lock"
    else
        echo "Could not parse R version from renv.lock, using latest"
    fi
else
    echo "No renv.lock found, using latest R version (rocker/verse:latest)"
    echo "💡 Tip: After creating renv.lock, rebuild Docker image to pin specific R version"
    R_VERSION="latest"
fi

# Generate Docker configuration files
generate_docker_config "${PKG_NAME}" "${R_VERSION}"

# 15. Copy external files to project
copy_external_files

# Function to generate GitHub Actions workflows (simplified for local Docker workflow)
generate_github_actions() {
    
    # Simple R package check workflow - just uses native R since Docker is local-only
    create_file_if_missing ".github/workflows/r-package.yml" "name: R Package Check

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  check:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: r-lib/actions/setup-pandoc@v2
      
      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: 'release'
          use-public-rspm: true
      
      - uses: r-lib/actions/setup-renv@v2
      
      - name: Check renv synchronization
        run: |
          Rscript check_renv_for_commit.R --quiet --fail-on-issues
      
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::rcmdcheck
          needs: check
      
      - uses: r-lib/actions/check-r-package@v2
        with:
          upload-snapshots: true"

    # Simple paper rendering workflow  
    create_file_if_missing ".github/workflows/render-paper.yml" "name: Render Research Paper

on:
  workflow_dispatch:  # Manual trigger
  push:
    paths:
      - 'analysis/paper/**'
      - 'R/**'

jobs:
  render:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: r-lib/actions/setup-pandoc@v2
      
      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: 'release'
          use-public-rspm: true
      
      - uses: r-lib/actions/setup-renv@v2
      
      - name: Render paper
        run: |
          Rscript -e \"rmarkdown::render('analysis/paper/paper.Rmd')\"
      
      - name: Upload paper
        uses: actions/upload-artifact@v4
        with:
          name: research-paper
          path: analysis/paper/paper.pdf"
}

# 16. Create GitHub Actions workflows
generate_github_actions

# 17. Create symbolic links for navigation
echo "Creating symbolic links for easier navigation..."
# Remove existing symlinks first
for link in a n f t s m e o c p; do
    [ -L "$link" ] && rm "$link"
done

# Create new symlinks
ln -s ./data a                   # a -> data
ln -s ./analysis n               # n -> analysis
ln -s ./analysis/figures f       # f -> analysis/figures
ln -s ./analysis/tables t        # t -> analysis/tables
ln -s ./scripts s                # s -> scripts
ln -s ./man m                    # m -> man
ln -s ./tests e                  # e -> tests
ln -s ./docs o                   # o -> docs
ln -s ./archive c                # c -> archive
ln -s ./analysis/paper p         # p -> analysis/paper

# Function to build Docker image with proper error handling
build_docker_image() {
    log_info "Building Docker environment (3-phase process)..."
    log_info "This may take several minutes on first build..."
    
    # Trap to ensure cleanup on exit
    trap cleanup_temp_image EXIT
    
    # Phase 1: Build initial image
    log_info "Phase 1: Building bootstrap image with R ${R_VERSION}..."
    if docker build --build-arg R_VERSION="$R_VERSION" -t "${PKG_NAME}_temp" .; then
        log_success "Bootstrap image built successfully"
    else
        log_error "Docker build failed - you can build manually later with:"
        log_error "   docker build --build-arg R_VERSION=${R_VERSION} -t ${PKG_NAME} ."
        return 1
    fi
    
    # Phase 2: Initialize renv inside container
    log_info "Phase 2: Initializing renv environment..."
    if docker run --rm -v "$(pwd):/home/analyst/project" -w /home/analyst/project "${PKG_NAME}_temp" R -e "source('setup_renv.R')"; then
        log_success "renv environment initialized"
    else
        log_warn "renv initialization failed - using bootstrap image as '${PKG_NAME}'"
        cleanup_temp_image
        return 0
    fi
    
    # Phase 3: Extract R version and rebuild with proper environment
    if [[ -f "renv.lock" ]]; then
        local final_r_version
        final_r_version=$(extract_r_version "${PKG_NAME}_temp" /home/analyst/project)
        log_info "Phase 3: Rebuilding with R ${final_r_version} and packages..."
        
        if docker build --build-arg R_VERSION="$final_r_version" -t "$PKG_NAME" .; then
            docker rmi "${PKG_NAME}_temp" >/dev/null 2>&1 || true
            log_success "Production Docker image '${PKG_NAME}' ready!"
            log_success "🚀 Complete environment with R ${final_r_version} and all packages"
        else
            log_warn "Final build failed - using bootstrap image as '${PKG_NAME}'"
            cleanup_temp_image
        fi
    else
        log_warn "renv.lock not created - using bootstrap image"
        cleanup_temp_image
    fi
}

# 18. Build Docker image and initialize renv by default
if [[ "$BUILD_DOCKER" == "true" ]]; then
    echo
    build_docker_image
else
    echo
    log_info "Skipped Docker build (--no-docker flag used)"
    log_info "Build manually when ready: docker build --build-arg R_VERSION=${R_VERSION} -t ${PKG_NAME} ."
fi

echo ""
echo "✅ rrtools-compatible structure setup complete!"
echo ""

# Summary of what was created
local features=(
    "- R package structure for reproducible research"
    "- Analysis directory with paper, figures, and templates subdirectories"
    "- Data directory with raw, derived, metadata, and validation subdirectories"
    "- Scripts directory for working R files and code snippets"
    "- R function templates in R/ with documentation in man/"
    "- Research paper template in analysis/paper/ (PDF output)"
    "- Comprehensive user guide (RRTOOLS_USER_GUIDE.md)"
    "- renv setup for package dependency management"
    "- Docker integration with rocker/verse base image"
    "- GitHub Actions CI/CD workflow for automated testing"
)

print_section "📁 Directory structure created with:" "${features[@]}"
# Function to show next steps
show_next_steps() {
    local getting_started=(
        "1. Read RRTOOLS_USER_GUIDE.md for comprehensive documentation"
    )
    
    if [ "$BUILD_DOCKER" = true ]; then
        getting_started+=(
            "2. 🎉 Ready to develop immediately! Start Docker container:"
            "3. ✅ renv already initialized with packages installed!"
        )
        local next_step=4
    else
        getting_started+=(
            "2. Build Docker image: 'make docker-build'"
            "3. Start developing in Docker container (no local R needed!):"
            "4. In container: run 'source(\"setup_renv.R\")' to initialize renv"
        )
        local next_step=5
    fi
    
    getting_started+=(
        "   - RStudio: 'make docker-rstudio' → http://localhost:8787"
        "   - R console: 'make docker-r'"
        "   - Bash: 'make docker-bash'"
        "${next_step}. Develop your analysis, install packages as needed"
        "$((next_step + 1)). When ready to commit: 'exit' container → 'make docker-check-renv-fix'"
    )
    
    print_section "🚀 Next steps (Docker-first workflow):" "${getting_started[@]}"
}

show_next_steps

# Define workflow sections
local dev_workflow=(
    "• Development: 'make docker-r' → do R work → 'exit'"
    "• Pre-commit: 'make docker-check-renv-fix' (validates dependencies)"
    "• Version control: 'git add .' → 'git commit' → 'git push'"
)

local collab_workflow=(
    "• Initial setup: Clone repo → run './rrtools.sh' → identical environment!"
    "• Stay in sync: 'git pull' → 'make docker-build' (updates environment)"
    "• Continue development: Same workflow as above"
    "• Note: 'make docker-build' is safe to run anytime (idempotent)"
)

local advanced_features=(
    "• Run 'rrtools_plus.sh' to add advanced research compendium features:"
    "   - Enhanced data management and validation infrastructure"
    "   - Ethics and legal documentation templates (IRB, data sharing)"
    "   - Collaboration tools (GitHub issue templates, contribution guidelines)"
    "   - Quality assurance (pre-commit hooks, reproducibility checks)"
    "   - Publication infrastructure (journal checklists, dissemination planning)"
)

local package_dev=(
    "7. Run 'devtools::document()' to generate documentation"
    "8. Run 'devtools::load_all()' to load the package"
    "9. Edit your research paper in analysis/paper/paper.Rmd"
    "10. Add your R functions in the R directory"
    "11. Run 'devtools::test()' to run tests"
)

local docker_tasks=(
    "12. Render paper: 'make docker-render'"
    "13. Run tests: 'make docker-test'" 
    "14. Check package: 'make docker-check'"
    "15. Validate renv: 'make docker-check-renv'"
    "16. See all options: 'make help'"
)

local symlinks=(
    "  a -> ./data              (data files)"
    "  n -> ./analysis          (analysis files)"
    "  f -> ./analysis/figures  (figures)"
    "  t -> ./analysis/tables   (tables)"
    "  s -> ./scripts           (working R scripts)"
    "  m -> ./man               (function documentation)"
    "  e -> ./tests             (tests)"
    "  o -> ./docs              (documentation)"
    "  c -> ./archive           (archived files)"
    "  p -> ./analysis/paper    (research paper)"
)

# Print all sections
print_section "RECOMMENDED DEVELOPMENT WORKFLOW:" "${dev_workflow[@]}"
print_section "ONGOING COLLABORATION WORKFLOW:" "${collab_workflow[@]}"
print_section "ADVANCED FEATURES (OPTIONAL):" "${advanced_features[@]}"
print_section "R PACKAGE DEVELOPMENT (in Docker container):" "${package_dev[@]}"
print_section "COMMON DOCKER TASKS:" "${docker_tasks[@]}"
print_section "📂 Symbolic links created for convenience:" "${symlinks[@]}"
