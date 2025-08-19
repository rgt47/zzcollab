# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Architecture Overview

ZZCOLLAB is a research collaboration framework that creates Docker-based
reproducible research environments. The system consists of:

### Core Components
- **Main executable**: `zzcollab.sh` - Primary framework script (439 lines, 64% reduction from original)
- **Modular shell system**: `modules/` directory contains core functionality
- **Docker-first workflow**: All development happens in containers
- **R package structure**: Standard R package with testthat for testing
- **Template system**: `templates/` for project scaffolding
- **Variant system**: Single source of truth with 14+ Docker variants
- **Configuration system**: Centralized constants and user configuration management

### Key Architecture Patterns
- **Modular design**: Shell scripts in `modules/` (core.sh, cli.sh, docker.sh, structure.sh, etc.)
- **Docker inheritance**: Team base images → personal development images
- **Automated CI/CD**: GitHub Actions for R package validation and image builds
- **Test-driven development**: Unit tests in `tests/testthat/`, integration tests expected
- **Environment monitoring**: Critical R options tracking with `check_rprofile_options.R`
- **Simplified CLI**: 3 clear build modes with shortcuts (-F, -S, -C) and selective base image building (-B, -V, -I)
- **Unified systems**: Single tracking, validation, and logging systems across all modules
- **Single source of truth**: Variant definitions in `variant_examples.yaml` eliminate duplication
- **14+ Docker variants**: From lightweight Alpine (~200MB) to full-featured environments (~3.5GB)

## Configuration System

ZZCOLLAB includes a comprehensive configuration system to eliminate repetitive typing and set project defaults.

### Configuration Commands
```bash
# Create default configuration file
zzcollab --config init

# Set configuration values  
zzcollab --config set team-name "myteam"
zzcollab --config set github-account "myusername"
zzcollab --config set build-mode "fast"
zzcollab --config set dotfiles-dir "~/dotfiles"

# Get configuration values
zzcollab --config get team-name
zzcollab --config get build-mode

# List all configuration
zzcollab --config list

# Validate configuration files
zzcollab --config validate
```

### Configuration Files
- **User config**: `~/.zzcollab/config.yaml` (your personal defaults)
- **Project config**: `./zzcollab.yaml` (project-specific overrides)
- **Priority order**: project config > user config > built-in defaults

### Example Configuration File
```yaml
defaults:
  # Team and GitHub settings
  team_name: "myteam"                  # Docker Hub team/organization name
  github_account: "myusername"         # GitHub account name
  
  # Build and environment settings  
  build_mode: "standard"               # Default build mode: fast, standard, comprehensive
  dotfiles_dir: "~/dotfiles"           # Path to dotfiles directory
  dotfiles_nodot: false                # Whether dotfiles need dots added
  
  # Automation settings
  auto_github: false                   # Automatically create GitHub repository
  skip_confirmation: false             # Skip confirmation prompts

# Custom package lists for build modes (optional)
build_modes:
  fast:
    description: "Quick development setup"
    docker_packages: [renv, remotes, here, usethis]
    renv_packages: [renv, here, usethis, devtools, testthat]
  
  standard:
    description: "Balanced research workflow"
    docker_packages: [renv, remotes, tidyverse, here, usethis, devtools]
    renv_packages: [renv, here, usethis, devtools, dplyr, ggplot2, tidyr, testthat, palmerpenguins]
```

### R Interface for Configuration
```r
# Configuration management from R
library(zzcollab)

# Initialize config
init_config()

# Set configuration values
set_config("team_name", "myteam")
set_config("build_mode", "fast")

# Get configuration values
get_config("team_name")
get_config("build_mode")

# List all configuration
list_config()

# Validate configuration
validate_config()

# Use config-aware functions (parameters use config defaults)
init_project(project_name = "my-analysis")   # Uses team_name from config
join_project(project_name = "my-analysis")   # Uses team_name and build_mode from config
setup_project()                              # Uses all defaults from config
```

## Data Documentation System (NEW 2025)

ZZCOLLAB now includes automated data documentation templates that follow research best practices for data management and reproducibility.

### Automated Data README Creation

Every new zzcollab project automatically includes a comprehensive `data/README.md` template with:

**Data Organization Structure**:
```
data/
├── raw_data/           # Original, untouched data files
├── derived_data/       # Cleaned and processed data files
└── README.md          # Comprehensive data documentation
```

**Template Features**:
- **Complete data dictionary**: Column descriptions, types, valid ranges, missing value codes
- **Processing documentation**: Links derived files to their creating scripts
- **Quality notes**: Known issues, validation checks, reproducibility instructions
- **Palmer Penguins example**: Ready-to-customize template with realistic data scenario

### Example Data Workflow Documentation

The template includes practical examples for common data preparation tasks:

```r
# scripts/01_data_preparation.R
library(here)
library(dplyr)

# Read raw penguins data
penguins_raw <- read.csv(here("data", "raw_data", "penguins.csv"))

# Create subset with first 50 records and log transformation
penguins_subset <- penguins_raw %>%
  slice_head(n = 50) %>%                    # First 50 records
  filter(!is.na(body_mass_g)) %>%           # Remove missing body mass
  mutate(log_body_mass_g = log(body_mass_g)) # Add log transformation

# Save processed data
write.csv(penguins_subset, 
         here("data", "derived_data", "penguins_subset.csv"),
         row.names = FALSE)
```

### Benefits for Reproducible Research

✅ **Standardized documentation**: All projects follow consistent data documentation patterns  
✅ **Traceability**: Clear links between raw data, processing scripts, and derived datasets  
✅ **Quality assurance**: Built-in data validation and quality check documentation  
✅ **Research best practices**: Follows academic standards for data management  
✅ **Collaboration ready**: Team members can immediately understand data structure and processing

The data README template is automatically created during project initialization and integrated into the uninstall process for complete lifecycle management.

## Docker Variant System (Enhanced 2025)

ZZCOLLAB now supports **14+ specialized Docker variants** with a single source of truth architecture that eliminates duplication and provides unlimited customization options.

### Variant Library Overview

**📦 Standard Research Environments (6 variants)**
- **minimal** (~800MB) - Essential R packages only  
- **analysis** (~1.2GB) - Tidyverse + data analysis tools
- **modeling** (~1.5GB) - Machine learning with tidymodels
- **publishing** (~3GB) - LaTeX, Quarto, bookdown, blogdown
- **shiny** (~1.8GB) - Interactive web applications
- **shiny_verse** (~3.5GB) - Shiny with tidyverse + publishing

**🔬 Specialized Domains (2 variants)**
- **bioinformatics** (~2GB) - Bioconductor genomics packages
- **geospatial** (~2.5GB) - sf, terra, leaflet mapping tools

**🏔️ Lightweight Alpine Variants (3 variants)**  
- **alpine_minimal** (~200MB) - Ultra-lightweight for CI/CD
- **alpine_analysis** (~400MB) - Essential analysis in tiny container
- **hpc_alpine** (~600MB) - High-performance parallel processing

**🧪 R-Hub Testing Environments (3 variants)**
- **rhub_ubuntu** (~1GB) - CRAN-compatible package testing
- **rhub_fedora** (~1.2GB) - Test against R-devel
- **rhub_windows** (~1.5GB) - Windows compatibility testing

### Single Source of Truth Architecture

All variant definitions are centralized in `variant_examples.yaml` with team configurations referencing them:

**Master Library**: `templates/variant_examples.yaml`
```yaml
minimal:
  base_image: "rocker/r-ver:latest"
  description: "Minimal development environment with essential R packages"  
  packages: [renv, devtools, usethis, testthat, roxygen2]
  system_deps: [libxml2-dev, libcurl4-openssl-dev, libssl-dev]
  category: "standard"
  size: "~800MB"

modeling:  
  base_image: "rocker/r-ver:latest"
  description: "Machine learning and statistical modeling environment"
  packages: [renv, devtools, tidyverse, tidymodels, xgboost, randomForest]
  system_deps: [libxml2-dev, libssl-dev, build-essential, gfortran]
  category: "standard"
  size: "~1.5GB"
```

**Team Configuration**: `templates/config.yaml`
```yaml
variants:
  minimal:
    enabled: true    # Essential development environment (~800MB)
    # Full definition in variant_examples.yaml
  
  modeling:
    enabled: false   # Machine learning environment (~1.5GB)  
    # Full definition in variant_examples.yaml

build:
  use_config_variants: true
  variant_library: "variant_examples.yaml"
```

### Interactive Variant Management

**Browse and Add Variants**:
```bash
# Interactive variant browser with 14 options
./add_variant.sh

# Displays categorized menu:
# 📦 STANDARD RESEARCH ENVIRONMENTS
#  1) minimal          ~800MB  - Essential R packages
#  2) analysis         ~1.2GB  - Tidyverse + data analysis  
#  3) modeling         ~1.5GB  - Machine learning with tidymodels
#  4) publishing       ~3GB    - LaTeX, Quarto, bookdown
#  5) shiny            ~1.8GB  - Interactive web applications
#  6) shiny_verse      ~3.5GB  - Shiny with tidyverse + publishing

# Select variants and they're automatically added to config.yaml
```

### Modern Workflow Commands

**Team Initialization**:
```bash
# Quick start - creates optimal default variants
zzcollab -i -p myproject --github    # Creates: minimal + analysis variants

# Custom variants via config file
zzcollab -i -p myproject             # Creates project + config.yaml
./add_variant.sh                     # Browse and select variants
zzcollab --variants-config config.yaml --github  # Build selected variants

# Legacy approach (limited to 3 variants)  
zzcollab -i -p myproject -B rstudio --github     # Traditional RStudio only
```

**Solo Developer Workflow**:
```bash
# Configuration-based (recommended)
zzcollab --config set team-name "myteam"
zzcollab -i -p analysis-project      # Uses config defaults

# Traditional explicit
zzcollab -i -t myteam -p analysis-project -B analysis -d ~/dotfiles
```

### Benefits of New Variant System

- ✅ **Eliminates duplication** - Single source of truth in `variant_examples.yaml`
- ✅ **14+ specialized environments** - From 200MB Alpine to 3.5GB full-featured
- ✅ **Domain-specific variants** - Bioinformatics, geospatial, HPC, web apps
- ✅ **Professional testing** - R-hub environments match CRAN infrastructure
- ✅ **Lightweight options** - Alpine variants 5x smaller than standard images
- ✅ **Interactive discovery** - Browse variants with `./add_variant.sh`
- ✅ **Backward compatibility** - Legacy full definitions still supported
- ✅ **Easy maintenance** - Update variant in one place, propagates everywhere

## Solo Developer Workflow (Enhanced 2025)

ZZCOLLAB provides a streamlined workflow for solo developers with professional-grade reproducibility and minimal overhead.

### Quick Start Solo Workflow

**1. Initial Setup (One-Time)**:
```bash
# Install ZZCOLLAB
git clone https://github.com/rgt47/zzcollab.git
cd zzcollab && ./install.sh

# Configure defaults (eliminates repetitive typing)
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"
zzcollab --config set dotfiles-dir "~/dotfiles"
```

**2. Project Creation**:
```bash
# Quick start - optimal variants automatically
zzcollab -i -p penguin-analysis --github

# Power users - browse 14+ variants interactively
mkdir penguin-analysis && cd penguin-analysis
zzcollab -i -p penguin-analysis
./add_variant.sh    # Select from bioinformatics, geospatial, alpine, etc.
```

**3. Daily Development Cycle**:
```bash
# Start development environment
cd penguin-analysis
make docker-zsh     # Enter container with all packages pre-installed

# Work inside container (example):
vim scripts/01_penguin_exploration.R    # Create analysis
vim R/penguin_functions.R              # Add reusable functions  
vim tests/testthat/test-functions.R     # Write tests

# Test and run analysis
R
devtools::load_all()
devtools::test()
source("scripts/01_penguin_exploration.R")
quit()

# Exit container
exit

# Validate and commit
make docker-test                        # Run tests in clean environment
git add . && git commit -m "Add analysis" && git push
```

### Practical Example: Penguin Bill Analysis

**Complete iterative development example with bill_depth vs log(bill_length) analysis**:

**Initial Analysis (First Iteration)**:
```r
# scripts/01_penguin_exploration.R
library(palmerpenguins)
library(ggplot2) 
library(dplyr)

create_bill_plot <- function() {
  penguins %>%
    filter(!is.na(bill_length_mm), !is.na(bill_depth_mm)) %>%
    ggplot(aes(x = log(bill_length_mm), y = bill_depth_mm)) +
    geom_point(aes(color = species), alpha = 0.7, size = 2) +
    labs(title = "Penguin Bill Depth vs Log(Bill Length)",
         x = "Log(Bill Length) (mm)", y = "Bill Depth (mm)") +
    theme_minimal()
}

bill_plot <- create_bill_plot()
ggsave("figures/bill_analysis.png", bill_plot, width = 8, height = 6)
```

**Function + Tests**:
```r
# R/penguin_functions.R  
#' Create scatter plot of bill depth vs log(bill length)
#' @export
create_bill_plot <- function(data = palmerpenguins::penguins) {
  # Implementation with proper error handling
}

# tests/testthat/test-penguin_functions.R
test_that("create_bill_plot works correctly", {
  plot <- create_bill_plot()
  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "Penguin Bill Depth vs Log(Bill Length)")
})
```

**Enhanced Analysis (Second Iteration)**:
```r
# Add regression analysis
create_enhanced_bill_plot <- function() {
  penguins %>%
    filter(!is.na(bill_length_mm), !is.na(bill_depth_mm)) %>%
    ggplot(aes(x = log(bill_length_mm), y = bill_depth_mm)) +
    geom_point(aes(color = species), alpha = 0.7, size = 2) +
    geom_smooth(method = "lm", se = TRUE) +  # Add regression line
    labs(title = "Penguin Bill Analysis with Regression")
}

fit_bill_model <- function() {
  # Linear regression with model diagnostics
  # Returns list with model, r_squared, coefficients
}
```

### Solo Developer Benefits

- ✅ **Reproducible**: Identical environment every development session
- ✅ **Professional**: Automated testing, validation, CI/CD
- ✅ **Flexible**: 14+ variants for different research domains  
- ✅ **Lightweight**: Alpine variants ~200MB vs standard ~1GB+
- ✅ **Team-ready**: Easy transition to collaboration later
- ✅ **Container-based**: No conflicts with host system R

### From Solo to Team Transition

Solo projects are automatically team-ready:
```bash
# Others can join your project immediately
git clone https://github.com/yourname/penguin-analysis.git
cd penguin-analysis
zzcollab -t yourname -p penguin-analysis -I analysis
make docker-zsh    # Same environment, instant collaboration
```

## Development Commands

### R Package Development
```bash
# Native R (requires local R installation)
make test                    # Run R package tests
make check                   # R CMD check validation
make document               # Generate documentation
make build                  # Build R package

# Docker-based (works without local R)
make docker-test           # Run tests in container
make docker-check          # Package validation
make docker-document       # Generate docs
make docker-render         # Render analysis reports

# CI/CD validation (enhanced with build mode awareness)
Rscript check_renv_for_commit.R --quiet --fail-on-issues  # Dependency validation
Rscript check_renv_for_commit.R --build-mode fast --quiet --fail-on-issues  # Fast mode validation
ZZCOLLAB_BUILD_MODE=comprehensive Rscript check_renv_for_commit.R --fix --fail-on-issues  # Environment variable
Rscript check_rprofile_options.R                          # R options monitoring

# Container-based CI commands (used in GitHub Actions)
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript check_renv_for_commit.R --quiet --fail-on-issues
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning')"
```

### Docker Development Environments
```bash
make docker-zsh            # Zsh shell with dotfiles (recommended)
make docker-rstudio        # RStudio Server at localhost:8787
make docker-verse          # Verse environment with LaTeX (publishing)
make docker-r              # R console only
make docker-bash           # Bash shell
```

### Variant Management (New)
```bash
# Interactive variant discovery and addition
./add_variant.sh           # Browse and add variants from comprehensive library

# Manual variant management
./variant_examples.yaml    # View all available variant definitions
vim config.yaml            # Edit team variants (set enabled: true to build)

# Build custom variants
zzcollab --variants-config config.yaml              # Build enabled variants
zzcollab -i -t TEAM -p PROJECT --variants-config config.yaml  # Team init with custom variants

# Default behavior (uses config.yaml automatically if use_config_variants: true)
zzcollab -i -p PROJECT     # Builds default variants (minimal + analysis)
```

### Dependency Management
```bash
make check-renv            # Check renv status
make check-renv-fix        # Update renv.lock
make docker-check-renv     # Validate in container
Rscript check_renv_for_commit.R --quiet --fail-on-issues  # CI validation
Rscript check_renv_for_commit.R --fix --fail-on-issues    # Auto-fix missing packages
Rscript check_renv_for_commit.R --build-mode fast --fix   # Build mode aware validation
```

### Installation and Setup
```bash
# One-time zzcollab installation
./install.sh                    # Installs zzcollab to ~/bin
export PATH="$HOME/bin:$PATH"   # Add to shell config if needed
```

### Core Image Building Workflow
```bash
# NEW: Selective Base Image Building (recommended) - faster, more efficient
# Build only what your team needs:
zzcollab -i -t TEAM -p PROJECT -B r-ver -S -d ~/dotfiles      # Shell only (fastest)
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -d ~/dotfiles    # RStudio only
zzcollab -i -t TEAM -p PROJECT -B verse -S -d ~/dotfiles      # Verse only (publishing)
zzcollab -i -t TEAM -p PROJECT -B all -S -d ~/dotfiles        # All 3 variants (traditional)

# Skip confirmation prompt for automation/CI:
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -y -d ~/dotfiles # No confirmation prompt

# Combine selective building with build modes:
zzcollab -i -t TEAM -p PROJECT -B rstudio -F -d ~/dotfiles    # RStudio with minimal packages (8)
zzcollab -i -t TEAM -p PROJECT -B all -C -d ~/dotfiles        # All variants with full packages (27+)

# Incremental approach - start small, add variants later:
zzcollab -i -t TEAM -p PROJECT -B r-ver -S -d ~/dotfiles      # Start with shell only
# Later, add more variants as needed:
zzcollab -V rstudio                                            # Add RStudio variant
zzcollab -V verse                                              # Add verse variant for publishing

# Environment variable support for build mode detection
ZZCOLLAB_BUILD_MODE=fast zzcollab -i -t TEAM -p PROJECT -B r-ver -d ~/dotfiles

# GitHub repository creation shortcuts
zzcollab -d ~/dotfiles -G                                     # Basic setup with automatic GitHub repo creation
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -G -d ~/dotfiles # Team setup with automatic GitHub repo

# Legacy: Traditional approach (builds all variants)
# zzcollab -i -t TEAM -p PROJECT -F -d ~/dotfiles              # Fast mode, all variants
# zzcollab -i -t TEAM -p PROJECT -C -d ~/dotfiles              # Comprehensive mode, all variants


# Manual core image building (if needed)
cd /path/to/zzcollab
cp templates/Dockerfile.unified ./Dockerfile.teamcore

# Build shell variant
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/r-ver \
    --build-arg TEAM_NAME="TEAM" \
    --build-arg PROJECT_NAME="PROJECT" \
    --build-arg PACKAGE_MODE="standard" \
    -t "TEAM/PROJECTcore-shell:v1.0.0" .

# Build RStudio variant
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/rstudio \
    --build-arg TEAM_NAME="TEAM" \
    --build-arg PROJECT_NAME="PROJECT" \
    --build-arg PACKAGE_MODE="standard" \
    -t "TEAM/PROJECTcore-rstudio:v1.0.0" .

# Build verse variant (publishing workflow)
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/verse \
    --build-arg TEAM_NAME="TEAM" \
    --build-arg PROJECT_NAME="PROJECT" \
    --build-arg PACKAGE_MODE="standard" \
    -t "TEAM/PROJECTcore-verse:v1.0.0" .

# Build with different package modes
# Fast mode (minimal packages)
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/r-ver \
    --build-arg PACKAGE_MODE="fast" \
    -t "TEAM/PROJECTcore-shell:fast" .

# Comprehensive mode (full packages)
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/r-ver \
    --build-arg PACKAGE_MODE="comprehensive" \
    -t "TEAM/PROJECTcore-shell:comprehensive" .

# Push to Docker Hub
docker push "TEAM/PROJECTcore-shell:v1.0.0"
docker push "TEAM/PROJECTcore-rstudio:v1.0.0"
docker push "TEAM/PROJECTcore-verse:v1.0.0"
```

### Team Collaboration Setup
```bash
# Developer 1 (Team Lead) - Team Image Creation Only
# Step 1: Create and push team Docker images (this is all -i does now)
zzcollab -i -t TEAM -p PROJECT -B r-ver -F -d ~/dotfiles      # Creates TEAM/PROJECTcore-shell:latest only
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -d ~/dotfiles    # Creates TEAM/PROJECTcore-rstudio:latest only  
zzcollab -i -t TEAM -p PROJECT -B all -C -d ~/dotfiles        # Creates all variants (shell, rstudio, verse)

# Step 2: Create full project structure (run separately)
mkdir PROJECT && cd PROJECT  # or git clone if repo exists
zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles            # Full project setup with shell interface

# Add more image variants later (incremental workflow)
zzcollab -V rstudio                                            # Add RStudio variant
zzcollab -V verse                                              # Add verse variant

# Developer 2+ (Team Members) - Join Existing Project
git clone https://github.com/TEAM/PROJECT.git                 # Clone existing project
cd PROJECT
# Choose available interface:
zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles             # Command-line development
zzcollab -t TEAM -p PROJECT -I rstudio -d ~/dotfiles           # RStudio Server (if variant available)
zzcollab -t TEAM -p PROJECT -I verse -d ~/dotfiles             # Publishing workflow (if variant available)

# Error handling: If team image variant not available, you'll get helpful guidance:
# ❌ Error: Team image 'TEAM/PROJECTcore-rstudio:latest' not found
# ✅ Available variants for this project:
#     - TEAM/PROJECTcore-shell:latest
# 💡 Solutions:
#    1. Use available variant: zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles
#    2. Ask team lead to build rstudio variant: zzcollab -V rstudio

# Note: Build modes comparison:
# Fast (-F): Minimal Docker + lightweight packages (fastest builds, 9 packages)
#   → renv, here, usethis, devtools, testthat, knitr, rmarkdown, targets
# Standard (-S): Balanced Docker + standard packages (recommended, 17 packages)
#   → + dplyr, ggplot2, tidyr, palmerpenguins, broom, janitor, DT, conflicted
# Comprehensive (-C): Extended Docker + full packages (kitchen sink, 47 packages)
#   → + tidymodels, shiny, plotly, quarto, flexdashboard, survival, lme4, databases
```

### Simplified Build Modes (NEW)

ZZCOLLAB now uses a simplified 3-mode system that replaces the previous complex flag combinations. This provides clear, intuitive choices for users:

#### Build Modes:
- **Fast (-F)**: Essential packages for quick development (9 packages)
  - Core: renv, here, usethis, devtools
  - Analysis: testthat, knitr, rmarkdown, targets
- **Standard (-S)**: Balanced package set for most workflows (17 packages, default)
  - Fast packages + tidyverse core: dplyr, ggplot2, tidyr
  - Research tools: palmerpenguins, broom, janitor, DT, conflicted
- **Comprehensive (-C)**: Full ecosystem for extensive environments (47 packages)
  - Standard packages + advanced tools: tidymodels, shiny, plotly, quarto
  - Specialized: flexdashboard, survival, lme4, database connectors, parallel processing


## Major Refactoring and Simplification (2024)

ZZCOLLAB has undergone comprehensive refactoring to improve maintainability and user experience:

### Code Architecture Improvements:
- **Modular design**: Extracted functionality into focused modules (cli.sh, team_init.sh, help.sh, etc.)
- **Unified systems**: Single tracking, validation, and logging systems across all modules
- **Code reduction**: Main script reduced from 1,235 to 439 lines (64% reduction)
- **Total cleanup**: Removed 3,000+ lines of duplicate/dead code

### User Experience Enhancements:
- **Simplified CLI**: 3 clear build modes (-F, -S, -C) replace 8+ complex flags
- **Comprehensive shortcuts**: All major flags now have single-letter shortcuts
- **Better error messages**: Clear, actionable error messages with helpful guidance
- **Backward compatibility**: Legacy flags still work with deprecation warnings

### Technical Improvements:
- **Unified tracking**: Single `track_item()` function replaces 6 duplicates
- **Unified validation**: Standardized validation patterns across modules
- **Clean dependencies**: Proper module loading order and dependency management
- **Consistent patterns**: Standardized error handling and logging throughout

## Recent Enhancements (2025)

### Docker Variant System Refactoring (Latest)
Major architectural improvement implementing single source of truth for variant management:

**Key Changes:**
- **Eliminated duplication**: Variant definitions centralized in `variant_examples.yaml`
- **14+ variants available**: Added shiny, shiny_verse, and comprehensive specialized options
- **Interactive variant browser**: `./add_variant.sh` with categorized 14-option menu
- **Single source of truth**: Team configs reference central library instead of duplicating
- **Backward compatibility**: Legacy full variant definitions still supported
- **Verified system libraries**: Fixed missing dependencies across all variants

**Technical Implementation:**
- **Simplified config.yaml**: Reduced from 455 to 154 lines (66% reduction) 
- **Enhanced add_variant.sh**: Generates lightweight YAML entries with library references
- **Updated team_init.sh**: Dynamic variant loading during build process
- **Comprehensive testing**: Validated new format, legacy compatibility, and integration

### Selective Base Image Building System
Major improvement to team initialization workflow with selective base image building:

**New Features:**
- **Selective building**: Teams can build only needed variants (r-ver, rstudio, verse) instead of all
- **Incremental workflow**: Start with one variant, add others later with `-V` flag  
- **Enhanced error handling**: Helpful guidance when team members request unavailable variants
- **Short flags**: All major options now have one-letter shortcuts (-i, -t, -p, -I, -B, -V)
- **Verse support**: Publishing workflow with LaTeX support via rocker/verse
- **Team communication**: Clear coordination between team leads and members about available tooling

**CLI Improvements:**
```bash
# New selective base image flags
-B, --init-base-image TYPE   # r-ver, rstudio, verse, all (for team initialization)
-V, --build-variant TYPE     # r-ver, rstudio, verse (for adding variants later)
-I, --interface TYPE         # shell, rstudio, verse (for team members joining)

# Examples
zzcollab -i -t mylab -p study -B rstudio -S -d ~/dotfiles    # RStudio only
zzcollab -V verse                                             # Add verse variant later
zzcollab -t mylab -p study -I shell -d ~/dotfiles           # Join with shell interface
```

**Error Handling Enhancements:**
- **Image availability checking**: Validates team images exist before proceeding
- **Helpful error messages**: Shows available variants and provides solutions
- **Team coordination**: Guides team members on how to request missing variants
- **Docker Hub integration**: Checks image availability via `docker manifest inspect`

### Revolutionary Docker Variant Management System
Complete transformation from fixed 3-variant system to unlimited custom environments:

**Unlimited Custom Variants:**
- **YAML-based configuration**: Define any number of Docker variants with custom base images and R packages
- **Comprehensive variant library**: 12+ predefined variants (standard, Alpine, R-hub, specialized domains)
- **Interactive variant manager**: `add_variant.sh` script for easy discovery and addition of variants
- **Variant examples library**: `variant_examples.yaml` with complete definitions organized by category

**New Configuration Architecture:**
```yaml
# Team-level config.yaml supports unlimited variants
variants:
  bioinformatics:
    base_image: "bioconductor/bioconductor_docker:latest"
    packages: ["renv", "BiocManager", "DESeq2", "edgeR", "limma"]
    system_deps: ["libxml2-dev", "zlib1g-dev", "libbz2-dev"]
    enabled: true
    
  alpine_minimal:
    base_image: "velaco/alpine-r:latest"  
    packages: ["renv", "devtools", "testthat"]
    system_deps: ["git", "make", "curl-dev"]
    enabled: true
    size: "~200MB"  # vs ~1GB for rocker images
```

**Variant Categories Available:**
- **Standard**: minimal, analysis, modeling, publishing (rocker-based, ~800MB-3GB)
- **Specialized**: bioinformatics, geospatial (domain-specific, ~2-2.5GB)
- **Alpine**: ultra-lightweight variants for CI/CD (~200-600MB)
- **R-hub**: CRAN-compatible testing environments (Ubuntu, Fedora, Windows)

**Interactive Variant Management:**
```bash
# Discover and add variants interactively
./add_variant.sh

# Menu shows categorized variants with size estimates:
# 🏔️ LIGHTWEIGHT ALPINE VARIANTS
#  7) alpine_minimal       ~200MB  - Ultra-lightweight CI/CD
#  8) alpine_analysis      ~400MB  - Lightweight data analysis
# 🧪 R-HUB TESTING ENVIRONMENTS  
# 10) rhub_ubuntu          ~1GB    - CRAN-compatible testing

# Automatically copies YAML to config.yaml with enabled: true
```

**Two-Level Configuration System:**
- **User config** (`~/.zzcollab/config.yaml`): Personal preferences and variant library
- **Team config** (project's `config.yaml`): Which variants actually get built as Docker images

**Legacy vs Modern System:**
```bash
# Legacy approach (overrides config.yaml)
zzcollab -i -p png1 -B r-ver        # Creates: png1core-shell:latest only

# Modern approach (uses config.yaml)  
zzcollab -i -p png1                  # Creates: minimal + analysis variants (default)
zzcollab -i -p png1 --variants-config config.yaml  # Explicit config usage
```

**Key Innovation**: Teams can now create specialized environments (bioinformatics with Bioconductor, geospatial with sf/terra, HPC with parallel processing, CI/CD with Alpine Linux) instead of being limited to generic r-ver/rstudio/verse variants.

### Enhanced check_renv_for_commit.R Script
The dependency validation script has been significantly improved:

**New Features:**
- **Build mode integration**: Adapts validation rules based on zzcollab build modes
- **Enhanced package extraction**: Handles wrapped calls, conditional loading, roxygen imports  
- **Robust error handling**: Structured exit codes (0=success, 1=critical issues, 2=config error)
- **zzcollab integration**: Uses zzcollab logging and respects system configuration
- **Base package filtering**: Automatically excludes R base packages from CRAN validation
- **Network resilience**: Graceful handling of CRAN API failures

**Usage Examples:**
```bash
# Build mode aware validation
Rscript check_renv_for_commit.R --build-mode fast --fix --fail-on-issues

# Environment variable detection
ZZCOLLAB_BUILD_MODE=comprehensive Rscript check_renv_for_commit.R --fix

# Enhanced edge case handling for complex package patterns
Rscript check_renv_for_commit.R --strict-imports --fix --fail-on-issues
```

### Documentation Synchronization
All documentation has been updated to reflect current system capabilities:
- **vignettes/workflow-comprehensive.Rmd**: Updated with selective base image building and error handling examples
- **workflow vignettes**: Moved to vignettes/ directory as proper R package documentation
- **ZZCOLLAB_USER_GUIDE.md**: Enhanced with new flags, interface options, and team coordination guidance
- **~/prj/p25/index.qmd**: Updated team collaboration examples with current CLI syntax
- **Command consistency**: All examples now use current flag syntax (-F, -S, -C, -B, -V, -I)
- **Error handling**: Comprehensive examples of helpful guidance when team images unavailable
- **Platform coverage**: Complete setup instructions for macOS, Windows, and Ubuntu systems

**Workflow Vignettes:**
- **workflow-solo.Rmd**: Solo developer focus with streamlined config-to-development cycle
- **workflow-team.Rmd**: Team collaboration with 3-developer penguin analysis scenario
- **Practical examples**: Complete penguin bill analysis with bill_depth vs log(bill_length) 
- **Two-iteration demo**: Initial scatter plot → enhanced with regression analysis (solo vs team approaches)
- **Professional practices**: Function development, comprehensive testing, reproducible outputs
- **14+ variant showcase**: Interactive variant selection with use case recommendations
- **Container-based development**: Clear enter-container → work → exit-container → commit patterns
- **R package integration**: Proper vignette structure with executable code examples

### R Package Integration (25 Functions)
Complete R interface for CLI functionality with build mode support:
```r
# Team Lead with build modes
init_project(team_name = "mylab", project_name = "study", build_mode = "fast")

# Team Member with build modes  
join_project(team_name = "mylab", project_name = "study", build_mode = "comprehensive")

# Full R workflow support
add_package("tidyverse")
git_commit("Add analysis")
create_pr("New feature")
```

### R-Centric Workflow (Enhanced with Configuration)
```r
# Method 1: Using Configuration (Recommended)
library(zzcollab)

# One-time setup for team lead
init_config()                                      # Initialize config file
set_config("team_name", "TEAM")                    # Set team name
set_config("build_mode", "standard")               # Set preferred mode
set_config("dotfiles_dir", "~/dotfiles")           # Set dotfiles path

# Developer 1 (Team Lead) - Simplified with config
init_project(project_name = "PROJECT")             # Uses config defaults

# Developer 2+ (Team Members) - Simplified with config  
set_config("team_name", "TEAM")                    # Match team settings
join_project(project_name = "PROJECT", interface = "shell")  # Uses config defaults

# Method 2: Traditional Explicit Parameters
library(zzcollab)
# Developer 1 (Team Lead) - R Interface with build modes
init_project(
  team_name = "TEAM",
  project_name = "PROJECT", 
  build_mode = "standard",  # "fast", "standard", "comprehensive"
  dotfiles_path = "~/dotfiles"
)

# Developer 2+ (Team Members) - R Interface with build modes
join_project(
  team_name = "TEAM",
  project_name = "PROJECT",
  interface = "shell",  # or "rstudio" or "verse"
  build_mode = "fast",  # matches team's preferred mode
  dotfiles_path = "~/dotfiles"
)
```

### Default Base Image Change (August 2025)
**Change**: Modified default base image from "all" to "r-ver" for faster, more efficient builds.

**Rationale**: 
- **Faster builds**: r-ver (shell-only) builds significantly faster than all variants
- **Resource efficiency**: Teams often don't need all 3 variants (shell, rstudio, verse)
- **Selective approach**: Users can explicitly request additional variants when needed
- **Backward compatibility**: `-B all` still available for teams that want all variants

**Implementation**:
- `modules/constants.sh:64`: `ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE="r-ver"`
- `modules/help.sh`: Updated help text to reflect new default
- Documentation updated with clarifying comments for examples without explicit `-B`

**Impact**:
```bash
# Old behavior (built all 3 variants by default):
zzcollab -i -t mylab -p study    # Built shell + rstudio + verse

# New behavior (builds shell-only by default):
zzcollab -i -t mylab -p study    # Builds shell only (faster)
zzcollab -i -t mylab -p study -B all  # Explicit flag for all variants
```

### Critical Bug Fix: -i Flag Behavior (July 2025)
**Issue**: The `-i` (team initialization) flag was incorrectly continuing with full project setup instead of stopping after team image creation.

**Root Cause**: In `modules/team_init.sh`, the `run_team_initialization` function was calling:
- `initialize_full_project` (line 618)
- `setup_git_repository` 
- `create_github_repository`

This caused `-i` to create team images AND run full project setup, defeating the purpose of separating team image creation from project setup.

**Fix Applied**: 
- **Modified**: `modules/team_init.sh:612-644`
- **Removed**: Calls to `initialize_full_project`, `setup_git_repository`, `create_github_repository`
- **Added**: Clear completion message with next steps guidance
- **Result**: `-i` now stops after `push_team_images` as intended

**New Correct Behavior**:
```bash
# Team Lead (Dev 1) - Two-Step Process
zzcollab -i -t mylab -p study -B rstudio -S    # Step 1: Creates & pushes team images, then stops
mkdir study && cd study                         # Step 2a: Create project directory  
zzcollab -t mylab -p study -I rstudio -S       # Step 2b: Full project setup
```

**Documentation Updated**:
- `vignettes/workflow-comprehensive.Rmd`: Updated team collaboration workflows
- `ZZCOLLAB_USER_GUIDE.md`: Clarified two-step process for team leads
- `templates/ZZCOLLAB_USER_GUIDE.md`: Updated template examples
- `CLAUDE.md`: Updated team collaboration examples

**Testing**: Verified that `-i` flag now stops after team image creation with helpful guidance messages.

## Docker Image Architecture and Custom Images

### ARM64 Compatibility Issues and Solutions

**Problem**: rocker/verse only supports AMD64 architecture, causing build failures on Apple Silicon (ARM64).

**Architecture Support Matrix**:
```
✅ ARM64 Compatible:
- rocker/r-ver     (Both AMD64 and ARM64)
- rocker/rstudio   (Both AMD64 and ARM64)

❌ AMD64 Only:
- rocker/verse     (Publishing workflow with LaTeX)
- rocker/tidyverse (AMD64 only)
- rocker/geospatial (AMD64 only)
- rocker/shiny     (AMD64 only)
```

**Solutions for ARM64 Users**:

1. **Use compatible base images only**:
   ```bash
   zzcollab -i -t TEAM -p PROJECT -B r-ver,rstudio -S    # Skip verse
   ```

2. **Build custom ARM64 verse equivalent**:
   ```dockerfile
   # Dockerfile.verse-arm64 - ARM64 compatible verse + shiny image
   FROM rocker/tidyverse:latest
   
   # Install system dependencies (from official rocker install_verse.sh)
   RUN apt-get update && apt-get install -y \
       cmake \
       default-jdk \
       fonts-roboto \
       ghostscript \
       hugo \
       less \
       libglpk-dev \
       libgmp3-dev \
       libfribidi-dev \
       libharfbuzz-dev \
       libmagick++-dev \
       qpdf \
       texinfo \
       vim \
       wget \
       && rm -rf /var/lib/apt/lists/*
   
   # Install R packages (official verse packages)
   RUN install2.r --error --skipinstalled --ncpus -1 \
       blogdown \
       bookdown \
       distill \
       rticles \
       rmdshower \
       rJava \
       xaringan \
       redland \
       tinytex \
       && rm -rf /tmp/downloaded_packages
   
   # Add Shiny support (not in official verse)
   RUN install2.r --error --skipinstalled --ncpus -1 \
       shiny \
       shinydashboard \
       DT \
       && rm -rf /tmp/downloaded_packages
   
   # Install TinyTeX for LaTeX support
   RUN R -e "tinytex::install_tinytex()"
   ```

3. **Build and deploy custom image**:
   ```bash
   # Build ARM64 compatible verse+shiny image
   docker build -f Dockerfile.verse-arm64 -t rgt47/verse-arm64:latest .
   
   # Test locally
   docker run --rm -p 8787:8787 rgt47/verse-arm64:latest
   
   # Push to Docker Hub (free for public images)
   docker login
   docker push rgt47/verse-arm64:latest
   ```

4. **Use in zzcollab workflows**:
   ```bash
   # Modify team Dockerfile to use custom image for verse variant
   # In Dockerfile.teamcore, conditionally use rgt47/verse-arm64 instead of rocker/verse
   ```

**Key Insights**:
- **Public Docker Hub storage is free** - no cost for hosting custom ARM64 images
- **rocker/verse** = rocker/tidyverse + publishing tools (bookdown, blogdown, LaTeX)
- **rocker/rstudio does NOT include Shiny** by default
- **Custom images can combine** verse + shiny functionality for complete publishing workflow

## Recent Code Quality Improvements (2025)

ZZCOLLAB has undergone comprehensive code quality improvements focused on maintainability, performance, and best practices:

### Architecture Enhancements
- **Modular Architecture**: Expanded from core system to **15 specialized modules** including new `constants.sh` for centralized configuration
- **Function Decomposition**: Broke down **7 oversized functions** (963 lines total) into **30 focused, single-responsibility functions**
- **Unified Validation System**: Replaced 17 duplicate validation patterns with single `require_module()` function
- **Centralized Constants**: All global variables and configuration consolidated in `constants.sh`
- **Performance Optimization**: Cached expensive operations (command availability checks)

### Code Quality Metrics
- **Lines Reduced**: Eliminated 150+ lines of duplicate code
- **Functions Refactored**: All functions now follow single responsibility principle (<60 lines each)
- **Module Consistency**: Unified loading patterns and dependency management
- **Error Handling**: Improved function-level error handling and validation

### Documentation and Quality Assurance
- **Comprehensive Documentation**: Added MODULE_DEPENDENCIES.md and IMPROVEMENTS_SUMMARY.md
- **Quality Monitoring**: Created `check-function-sizes.sh` to prevent regression to oversized functions
- **Architecture Mapping**: Complete dependency graphs and loading order documentation

### Maintained Compatibility
- **100% Backward Compatibility**: All existing functionality preserved
- **No Breaking Changes**: User interfaces and command-line options unchanged
- **Enhanced Performance**: Improved execution speed through optimization

These improvements ensure ZZCOLLAB maintains professional software engineering standards while preserving its powerful research collaboration capabilities.

For detailed information about the improvements, see:
- **docs/IMPROVEMENTS_SUMMARY.md**: Comprehensive summary of all code quality improvements
- **docs/MODULE_DEPENDENCIES.md**: Module dependency mapping and loading order
- **scripts/check-function-sizes.sh**: Quality assurance tool for function size monitoring

## Recent Work Completed (August 2025)

### Automated Data Documentation System and Safety Enhancements

**Data Documentation Templates (NEW)**:
- **Automated README creation**: Every new zzcollab project includes comprehensive `data/README.md` with Palmer Penguins example
- **Research best practices**: Complete data dictionary, processing documentation, quality notes, and reproducibility instructions
- **Workflow integration**: Template creation integrated into project initialization and uninstall processes
- **Standardized structure**: `raw_data/`, `derived_data/`, and comprehensive documentation for all projects

**Critical Safety Improvements**:
- **Home directory protection**: Prevents accidental installation in `$HOME` with clear error messages and actionable guidance
- **System directory protection**: Blocks installation in dangerous directories (`/Users`, `/home`, `/root`, `/tmp`, etc.)
- **Intelligent conflict detection**: Replaced generic file count warnings with precise conflict detection showing only actual zzcollab file conflicts
- **Enhanced uninstall**: Added missing files (`.Rbuildignore`, `navigation_scripts.sh`, `data/README.md`) for complete cleanup

### Complete CI/CD Pipeline Resolution and Production Readiness
Comprehensive resolution of all GitHub Actions workflow failures, bringing the repository to production-ready status:

**R Package CI/CD Pipeline Fully Resolved:**
- **NAMESPACE imports**: Fixed missing `importFrom("utils", "install.packages")`, `importFrom("jsonlite", "fromJSON", "toJSON")`, `importFrom("utils", "packageVersion")`
- **Vignette system**: Added `VignetteBuilder: knitr` to DESCRIPTION and resolved all vignette build failures
- **workflow-team.Rmd**: Fixed undefined `model_results` variable by implementing proper setup chunk with function definitions and `eval = TRUE` for demonstration chunks
- **Non-ASCII characters**: Replaced all Unicode emojis (✅❌📝) with proper escape sequences (`\u2705`, `\u274c`, `\ud83d\udcdd`) 
- **Documentation warnings**: Fixed roxygen2 "lost braces" errors by correcting double backslashes (`\\code{\\link{...}}` → `\code{\link{...}}`)
- **Operator documentation**: Added proper `@name` and `@rdname` tags for `%||%` operator to resolve illegal character warnings

**ShellCheck Analysis Pipeline:**
- **Variable reference fix**: Corrected undefined `team_variant_name` variable to `variant_name` in `templates/add_variant.sh`
- **Workflow optimization**: Enhanced ShellCheck configuration to focus on functional issues while maintaining code quality

**Documentation Expansion and Quality Improvements:**
- **Comprehensive inline comments**: Enhanced zzcollab.sh with detailed architecture overview and workflow explanations
- **Roxygen2 standardization**: All R functions now have complete roxygen2 documentation with @param, @return, @details, @examples
- **Module documentation**: Critical shell functions documented with architectural context and usage patterns
- **Dependency validation**: Enhanced check_renv_for_commit.R with comprehensive architectural documentation

**Quality Assurance Improvements:**
- **GitHub workflows optimization**: Removed research-focused workflows inappropriate for framework source repo
- **R package workflow fix**: Resolved 140+ package installation by focusing on core dependencies only
- **ShellCheck configuration**: Optimized to focus on errors/warnings while ignoring pure style suggestions
- **Security audit**: Comprehensive audit confirmed no HIGH RISK security vulnerabilities in codebase

**Critical Bug Fixes:**
- **R package "undefined exports"**: Fixed .Rbuildignore pattern `^[a-z]$` that was excluding R/ directory from built packages
- **Documentation formatting**: Fixed malformed roxygen2 syntax causing build warnings
- **Workflow validation**: Both ShellCheck and R package workflows now pass successfully

**Production Readiness Achievements:**
- **✅ All CI workflows passing**: Both R package validation and ShellCheck analysis execute successfully
- **✅ No critical warnings**: Eliminated all blocking warnings in package documentation and code analysis
- **✅ Professional documentation**: Complete roxygen2 documentation with proper LaTeX formatting
- **✅ Clean dependency management**: All imports properly declared and functional
- **✅ Robust vignette system**: All workflow documentation renders correctly with executable examples

**Key Technical Insights:**
- `.Rbuildignore` patterns can accidentally exclude critical directories - use specific patterns
- `devtools::load_all()` vs `R CMD INSTALL` have different behaviors for package validation
- ShellCheck severity levels allow focusing on functional issues vs. style preferences
- Roxygen2 documentation requires single backslashes for LaTeX commands, not double backslashes
- Vignette chunks with `eval = FALSE` prevent inline R expressions from accessing defined variables
- Unicode characters in R source code must use escape sequences for CRAN compliance

### R-Only Workflow Vignettes for Non-Docker Users (August 2025)
**Comprehensive R-native interface expansion** - making ZZCOLLAB accessible to R developers without Docker/bash knowledge:

**New Vignette Documentation System:**
- **r-solo-workflow.Rmd**: Pure R interface for solo developers using only R functions (`init_project()`, `start_rstudio()`, `git_commit()`)
- **r-team-workflow.Rmd**: Team collaboration workflow with role-based approach (team lead vs members) using R-only functions
- **Complete workflow coverage**: From project setup to daily development to team coordination, all through familiar R interface
- **Real-world examples**: Penguin analysis (solo) and customer churn analysis (3-person team collaboration)

**Target Audience Expansion:**
- **R users familiar with RStudio/tidyverse** but unfamiliar with Docker/bash commands
- **Research teams** wanting reproducibility without DevOps complexity
- **Data scientists** focused on analysis rather than infrastructure management
- **Academic labs** needing seamless collaboration across different skill levels

**R-Native Interface Design:**
- **Zero Docker exposure**: Users never see Docker commands or concepts, all handled transparently
- **Familiar R patterns**: `library()`, `install.packages()`, RStudio workflows, Git through R functions
- **Transparent reproducibility**: Perfect environment consistency without manual Docker management
- **Professional workflows**: Feature branching (`create_branch()`), pull requests (`create_pr()`), team coordination

**Key Innovation - Pure R Development Experience:**
```r
# Solo workflow - feels like regular R development
library(zzcollab)
init_project("my-analysis")        # Creates reproducible project
start_rstudio()                    # Opens RStudio at localhost:8787
# ... familiar R development in RStudio ...
git_commit("Add analysis")         # Version control through R
git_push()                         # Sharing through R

# Team workflow - seamless collaboration
init_project("team-project", team_name = "lab")  # Team lead setup
join_project("lab", "team-project")              # Team members join
start_rstudio()                                   # Identical environments
```

**Documentation Quality Achievements:**
- **Complete examples**: Full analysis workflows from project creation to results publication
- **Role-based guidance**: Clear separation of team lead vs team member responsibilities  
- **Troubleshooting sections**: Common issues and R-based solutions
- **Best practices integration**: Professional development patterns without complexity exposure

This expansion makes ZZCOLLAB accessible to the broader R community by eliminating the need to learn Docker/bash while maintaining all reproducibility benefits.

### Security Assessment Results
**Comprehensive security audit completed** - zzcollab codebase demonstrates excellent security practices:
- ✅ **No unsafe cd commands** - All use proper error handling (`|| exit 1`)
- ✅ **No unquoted rm operations** - All file operations properly quote variables
- ✅ **No unquoted test conditions** - Variables in conditionals safely handled
- ✅ **No word splitting vulnerabilities** - Defensive programming throughout
- ✅ **Production-ready security posture** - No HIGH RISK vulnerabilities found

### Repository Cleanup and Production Readiness (August 2025)
**Comprehensive cleanup completed** - repository now follows open source best practices for production-ready projects:

**Documentation Structure Improvements:**
- ✅ **Proper R package vignettes**: All workflow documentation moved to `vignettes/` following R package standards
- ✅ **Complete vignette suite**: `workflow-solo.Rmd`, `workflow-team.Rmd`, `workflow-comprehensive.Rmd`, `data-analysis-testing.Rmd`
- ✅ **Consolidated documentation**: Single source of truth for all user workflows and testing guidance

**Development Artifacts Cleanup:**
- ✅ **Safe removal using trash-put**: All development artifacts moved to trash (recoverable if needed)
- ✅ **Legacy documentation removed**: Duplicate workflow.md, DATA_ANALYSIS_TESTING_GUIDE.md files
- ✅ **Build artifacts cleaned**: zzcollab.Rcheck/, temp_check/, *.tar.gz packages removed
- ✅ **Development scripts archived**: md2pdf.sh, minimal_test.sh, navigation_scripts.sh eliminated
- ✅ **Generated files cleanup**: All PDF outputs, text files, workflow mini files removed

**Enhanced Git Management:**
- ✅ **Improved .gitignore**: Added patterns for development artifacts (*.pdf, *test/, temp_*, *_check/)
- ✅ **Future clutter prevention**: Patterns prevent generated files from being committed
- ✅ **Professional repository structure**: Clean, focused codebase for contributors

**Production-Ready Benefits:**
- ✅ **Faster repository clones**: Reduced size improves developer experience
- ✅ **Clear project structure**: Contributors see only production-relevant code
- ✅ **Professional appearance**: Mature, well-maintained open source project
- ✅ **Maintainable codebase**: Documentation and code properly organized following industry standards

**Key Technical Insights:**
- Used `tp` (trash-put) for safe file deletion with recovery option
- Followed R package standards by moving documentation to proper vignettes/ structure
- Enhanced .gitignore prevents future development artifact accumulation
- Repository structure now optimized for both solo developers and team collaboration

## Troubleshooting Memories

### renv Initialization Errors
- **Memory**: Bootstrapping renv 1.1.4 showed installation issues
  - Download of renv was successful
  - Package installation completed 
  - Encountered error with script configuration
  - Error message: `Error in if (script_config) { : the condition has length > 1`
  - Execution halted with exit code 1
- **Potential Solutions**:
  - Check renv lockfile for consistency
  - Verify script configuration parameters
  - Use `renv::status()` to diagnose specific package installation issues
  - Potentially use `renv::restore()` to rebuild environment

[... rest of the existing content remains unchanged ...]