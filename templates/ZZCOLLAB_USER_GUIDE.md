# ZZCOLLAB Framework User Guide v3.1

## Table of Contents
1. [What is ZZCOLLAB?](#what-is-zzcollab)
2. [Architecture Overview](#architecture-overview)
3. [Unified Research Compendium](#unified-research-compendium)
4. [Configuration System](#configuration-system)
5. [Docker Environment System](#docker-variant-system)
6. [Data Documentation System](#data-documentation-system)
7. [Getting Started](#getting-started)
8. [Installation & Distribution](#installation--distribution)
9. [Solo Developer Workflow](#solo-developer-workflow)
10. [Team Collaboration Setup](#team-collaboration-setup)
11. [Directory Structure](#directory-structure)
12. [Navigation Shortcuts](#navigation-shortcuts)
13. [Development Environments](#development-environments)
14. [Package Management with renv](#package-management-with-renv)
15. [Docker Environment](#docker-environment)
16. [Build System with Make](#build-system-with-make)
17. [GitHub Actions CI/CD](#github-actions-cicd)
18. [R Interface Functions](#r-interface-functions)
19. [Team Collaboration Workflows](#team-collaboration-workflows)
20. [Common Tasks](#common-tasks)
21. [Recent Enhancements](#recent-enhancements)
22. [Troubleshooting](#troubleshooting)
23. [Platform-Specific Notes](#platform-specific-notes)

## What is ZZCOLLAB?

**ZZCOLLAB** is a framework for creating **research compendia** with
systematic team collaboration capabilities - self-contained, reproducible
research projects that combine:
- **Unified research structure** following Marwick et al. (2018) framework
- R package structure for code organization
- Data management and documentation
- Analysis scripts and notebooks
- Manuscript preparation
- Docker containerization for reproducibility
- **Automated team collaboration workflows**
- **Automated package management**
- **Integrated Git/GitHub workflows**

### Key Characteristics

- **Unified Structure**: Single flexible workflow for entire research lifecycle
- **Progressive Disclosure**: Start simple, add complexity as research evolves
- **Team Collaboration**: Automated workflows for multiple researchers
- **Reproducibility**: Systematic recreation of analytical procedures
- **Organization**: Standardized structure for project components
- **Publication**: Integrated manuscript preparation workflow
- **Portability**: Cross-platform compatibility
- **Containerized**: Isolated computational environments
- **Automated CI/CD**: Systematic development workflows

## Architecture Overview

ZZCOLLAB employs a modular architecture designed to provide
research infrastructure that maintains accessibility for users
with varying levels of technical expertise.

### Core Components

**Main Executable**: `zzcollab.sh`

- Primary framework script (439 lines, representing a 64% reduction
  from the original monolithic implementation)
- Command-line interface for all major operations

**Modular Shell System**: `modules/` directory

- **constants.sh**: Centralized configuration and global variables
- **cli.sh**: Command-line argument parsing
- **core.sh**: Core utility functions
- **docker.sh**: Docker image management
- **structure.sh**: Project structure creation, including data templates
- **team_init.sh**: Team collaboration setup
- **help.sh**: Help system with pagination
- Additional modules for git operations, validation, and logging

**Docker-First Workflow**

- Development occurs within containers to ensure reproducibility
- Team base images inherit from specialized variants
- Personal development images layer dotfiles on team images

**Template System**: `templates/` directory

- Project scaffolding for three research paradigms
- Docker environment definitions (`environments.yaml`)
- Configuration templates (`config.yaml`)
- Data documentation templates (created automatically)

**Environment System**

- Single source of truth: `environments.yaml`
- 14+ Docker environments ranging from lightweight Alpine (~200MB) to
  full-featured environments (~3.5GB)
- Team configuration selects which environments to enable

**Configuration System**

- Multi-level hierarchy: project > user > system > built-in defaults
- Centralized constants reduce repetitive parameter specification
- User and team customization without repository forking

### Key Architecture Patterns

**Modular Design**

- Functions adhere to single responsibility principle (< 60 lines each)
- Unified validation system employing single `require_module()`
  function
- Elimination of code duplication: 3,000+ lines of redundant code
  removed

**Docker Inheritance Chain**

```
rocker/r-ver (base image)
  → Team core image (shared packages)
    → Personal development image (+ dotfiles)
```

**Automated CI/CD**

- GitHub Actions for R package validation
- Automatic team image rebuilds upon dependency changes
- Multi-platform builds supporting AMD64 and ARM64 architectures

**Test-Driven Development**

- Unit tests in `tests/testthat/`
- Integration tests for analysis pipelines
- Data validation framework with >90% coverage requirements

**Single Source of Truth**

- Variant definitions maintained in single file
  (`environments.yaml`)
- Teams reference environments by name, eliminating duplication
- Configuration inheritance: user → team → project

### Code Quality Improvements (2024-2025)

**Architecture Enhancements**

- Expanded to 15 specialized modules from monolithic script
- Function decomposition: refactored 7 oversized functions (963 lines
  total) into 30 focused functions
- Unified validation: replaced 17 duplicate validation patterns with
  single system
- Performance optimization through caching of expensive operations

**Maintainability**

- Eliminated 150+ lines of duplicate code
- All functions conform to single responsibility principle
- Complete dependency mapping and loading order documentation
- Quality monitoring tools to prevent regression

**Backward Compatibility**

- Preservation of all existing functionality
- No breaking changes to user interfaces
- Enhanced performance through systematic optimization

## Unified Research Compendium

ZZCOLLAB follows the **unified research compendium framework** proposed by Marwick, Boettiger, and Mullen (2018). This single flexible structure supports your entire research lifecycle from initial data exploration to package distribution—**without requiring upfront decisions or structural migrations**.

### **Core Philosophy: Progressive Disclosure**

**Key Principle**: Research evolves organically. No upfront choice. No migration friction.

Start with data analysis, naturally progress to manuscript writing, and ultimately create distributable packages—all within the same structure.

### **Unified Directory Structure**

```
your-research-project/
├── analysis/
│   ├── data/
│   │   ├── raw_data/         # Original, unmodified data (read-only)
│   │   └── derived_data/     # Processed, analysis-ready data
│   ├── paper/
│   │   ├── paper.Rmd         # Manuscript (add when ready)
│   │   └── references.bib    # Bibliography
│   ├── figures/              # Generated visualizations
│   └── scripts/              # Analysis code (empty initially - you create)
├── R/                        # Reusable functions (add as needed)
├── tests/                    # Unit tests (add as needed)
├── man/                      # Documentation (add for packages)
├── vignettes/                # Tutorials (add for packages)
├── Dockerfile                # Computational environment
└── renv.lock                 # Exact package versions
```

**Compatible with**: benmarwick/rrtools, Marwick et al. (2018) research compendium standards

### **Four-Stage Research Evolution**

**Stage 1: Data Analysis** (Day 1)
```r
# Start simple - create analysis scripts
analysis/scripts/01_explore_data.R
analysis/scripts/02_model_data.R
```

**Stage 2: Manuscript Writing** (Week 2)
```r
# Add manuscript when ready
analysis/paper/paper.Rmd
analysis/paper/references.bib
```

**Stage 3: Function Extraction** (Month 1)
```r
# Extract reusable code to functions
R/data_cleaning.R
R/modeling_functions.R
tests/testthat/test-functions.R
```

**Stage 4: Package Distribution** (Month 3)
```r
# Add package documentation
man/data_cleaning.Rd
vignettes/getting-started.Rmd
```

**No migration required** - research evolves organically within the unified structure.

### **Quick Start**

**Command Line:**
```bash
# Create unified research project
zzcollab -i -p my-research

# Or specify team
zzcollab -i -t myteam -p research-project
```

**R Interface:**
```r
library(zzcollab)

# Create unified project
init_project("my-research")

# Or with team
init_project(team_name = "myteam", project_name = "research-project")
```

### **Learning Resources**

For detailed information about the unified paradigm approach:
- `docs/UNIFIED_PARADIGM_GUIDE.md` - Complete guide
- `docs/MARWICK_COMPARISON_ANALYSIS.md` - Comparison with Marwick framework
- `examples/` directory - Practical examples for different research stages

## Configuration System

ZZCOLLAB implements a multi-layered configuration system designed to
reduce parameter repetition and establish consistent project defaults
across different organizational contexts.

### Configuration Architecture

The system employs a hierarchical configuration structure where settings
at more specific levels override broader defaults:

**Configuration Hierarchy** (highest priority first):

1. **Project config** (`./zzcollab.yaml`) - Team-specific settings for
   shared projects
2. **User config** (`~/.zzcollab/config.yaml`) - Personal defaults
   across all projects
3. **System config** (`/etc/zzcollab/config.yaml`) - Organization-wide
   defaults
4. **Built-in defaults** - Fallback values ensuring system functionality

**Three Configuration Domains**:

- **Docker Variant Management** - 14+ specialized environments with
  custom base images and packages
- **Package Management** - Build modes (Fast/Standard/Comprehensive)
  with flexible package selection
- **Development Settings** - Team collaboration, GitHub integration,
  and automation preferences

### Configuration Files

- **User config**: `~/.zzcollab/config.yaml` (personal defaults)
- **Project config**: `./zzcollab.yaml` (team-specific overrides)
- **System config**: `/etc/zzcollab/config.yaml` (organizational
  defaults)

### Configuration Commands
```bash
zzcollab --config init                    # Create default config file
zzcollab --config set team-name "myteam"  # Set a configuration value
zzcollab --config get team-name           # Get a configuration value
zzcollab --config list                    # List all configuration
zzcollab --config validate               # Validate YAML syntax
```

### One-time Setup
```bash
# Initialize configuration
zzcollab --config init

# Set your team defaults
zzcollab --config set team-name "myteam"
zzcollab --config set github-account "myusername"
zzcollab --config set build-mode "standard"
zzcollab --config set dotfiles-dir "~/dotfiles"

# View your configuration
zzcollab --config list
```

### Customizable Settings
- **Team settings**: `team_name`, `github_account`
- **Build settings**: `build_mode`, `dotfiles_dir`, `dotfiles_nodot`
- **Automation**: `auto_github`, `skip_confirmation`
- **Custom package lists**: Override default packages for each build mode

### Custom Package Lists
Edit your config file (`~/.zzcollab/config.yaml`) to customize packages:

```yaml
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

### Comprehensive Configuration Examples

**User Configuration** (`~/.zzcollab/config.yaml`):

```yaml
defaults:
  # Personal development preferences
  team_name: "myteam"
  github_account: "myusername"
  build_mode: "standard"          # fast, standard, comprehensive
  dotfiles_dir: "~/dotfiles"
  dotfiles_nodot: false

  # Automation preferences
  auto_github: false
  skip_confirmation: false

# Custom package lists for build modes (optional)
build_modes:
  fast:
    description: "Quick development setup"
    docker_packages: [renv, remotes, here, usethis]
    renv_packages: [renv, here, usethis, devtools, testthat]

  custom_analysis:
    description: "Personal data science workflow"
    docker_packages: [renv, tidyverse, targets, pins]
    renv_packages: [renv, tidyverse, targets, pins, vetiver,
                    plumber, shiny]
```

**Team Project Configuration** (`./zzcollab.yaml`):

```yaml
#=========================================================
# TEAM METADATA
#=========================================================
team:
  name: "datasci-lab"
  project: "customer-churn-analysis"
  description: "Machine learning analysis of customer
                retention patterns"
  maintainer: "Dr. Smith <smith@university.edu>"

#=========================================================
# BUILD CONFIGURATION
#=========================================================
build:
  use_config_environments: true
  environment_library: "environments.yaml"

  docker:
    platform: "auto"              # auto, linux/amd64, linux/arm64
    no_cache: false
    parallel_builds: true

  packages:
    repos: "https://cran.rstudio.com/"
    install_suggests: false
    dependencies: ["Depends", "Imports", "LinkingTo"]

#=========================================================
# TEAM COLLABORATION SETTINGS
#=========================================================
collaboration:
  github:
    auto_create_repo: false
    default_visibility: "private"
    enable_actions: true

  development:
    default_interface: "analysis"
    container:
      default_user: "analyst"
      working_dir: "/home/analyst/project"
```

### Configuration Workflows

**Solo Developer Setup**:

```bash
# Initialize personal configuration
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"

# Create projects using defaults
zzcollab -i -p data-analysis    # Uses config defaults automatically
```

**Team Leader Setup**:

```bash
# Create team configuration
mkdir team-project && cd team-project
zzcollab -i -p team-project    # Creates base config.yaml

# Customize team environments and settings
vim config.yaml

# Build and share team images
zzcollab --variants-config config.yaml --github
```

**Team Member Joining**:

```bash
# Clone team project
git clone https://github.com/team/team-project.git
cd team-project

# Join with appropriate interface
zzcollab -t team -p team-project -I analysis
make docker-zsh
```

### Configuration Validation

```bash
# Check configuration syntax and values
zzcollab --config validate

# Debug configuration loading
zzcollab --config list

# Verify Docker platform compatibility
zzcollab --config get docker.platform
```

### R Interface for Configuration

```r
library(zzcollab)

# Configuration management
init_config()                           # Initialize config file
set_config("team_name", "myteam")       # Set configuration values
get_config("team_name")                 # Get configuration values
list_config()                           # List all configuration
validate_config()                       # Validate configuration files

# Use config-aware functions
init_project(project_name = "my-analysis")   # Uses config defaults
join_project(project_name = "my-analysis")   # Uses config defaults
setup_project()                              # Uses all defaults
```

## Docker Environment System

ZZCOLLAB supports 14+ specialized Docker environments through a
single source of truth architecture that eliminates duplication
and provides extensive customization options.

### Variant Library Overview

**Standard Research Environments (6 variants)**

- **minimal** (~800MB) - Essential R packages only
- **analysis** (~1.2GB) - Tidyverse with data analysis tools
- **modeling** (~1.5GB) - Machine learning with tidymodels
- **publishing** (~3GB) - LaTeX, Quarto, bookdown, blogdown
- **shiny** (~1.8GB) - Interactive web applications
- **shiny_verse** (~3.5GB) - Shiny with tidyverse and publishing

**Specialized Domains (2 variants)**

- **bioinformatics** (~2GB) - Bioconductor genomics packages
- **geospatial** (~2.5GB) - sf, terra, leaflet mapping tools

**Lightweight Alpine Environments (3 variants)**

- **alpine_minimal** (~200MB) - Ultra-lightweight for CI/CD
- **alpine_analysis** (~400MB) - Essential analysis in minimal
  container
- **hpc_alpine** (~600MB) - High-performance parallel processing

**R-Hub Testing Environments (3 variants)**

- **rhub_ubuntu** (~1GB) - CRAN-compatible package testing
- **rhub_fedora** (~1.2GB) - Test against R-devel
- **rhub_windows** (~1.5GB) - Windows compatibility testing

### Single Source of Truth Architecture

All environment definitions are centralized in `environments.yaml`
with team configurations referencing them by name:

**Master Library**: `templates/environments.yaml`

```yaml
minimal:
  base_image: "rocker/r-ver:latest"
  description: "Minimal development environment with
                essential R packages"
  packages: [renv, devtools, usethis, testthat, roxygen2]
  system_deps: [libxml2-dev, libcurl4-openssl-dev, libssl-dev]
  category: "standard"
  size: "~800MB"

modeling:
  base_image: "rocker/r-ver:latest"
  description: "Machine learning and statistical modeling
                environment"
  packages: [renv, devtools, tidyverse, tidymodels, xgboost,
             randomForest]
  system_deps: [libxml2-dev, libssl-dev, build-essential,
                gfortran]
  category: "standard"
  size: "~1.5GB"
```

**Team Configuration**: `templates/config.yaml`

```yaml
environments:
  minimal:
    enabled: true    # Essential development (~800MB)
    # Full definition in environments.yaml

  modeling:
    enabled: false   # Machine learning environment (~1.5GB)
    # Full definition in environments.yaml

build:
  use_config_environments: true
  environment_library: "environments.yaml"
```

### Interactive Variant Management

```bash
# Interactive environment browser with 14 options
./add_environment.sh

# Displays categorized menu showing all available environments
# organized by: Standard Research, Specialized Domains,
# Lightweight Alpine, R-Hub Testing

# Select environments and they are automatically added to config.yaml
```

### Variant Usage Commands

**Team Initialization**:

```bash
# Quick start - creates optimal default variants
zzcollab -i -p myproject --github

# Custom environments via config file
zzcollab -i -p myproject
./add_environment.sh
zzcollab --variants-config config.yaml --github

# Legacy approach (limited to 3 variants)
zzcollab -i -p myproject -B rstudio --github
```

**Solo Developer Workflow**:

```bash
# Configuration-based (recommended)
zzcollab --config set team-name "myteam"
zzcollab -i -p research-paper

# Traditional explicit
zzcollab -i -t myteam -p analysis-project \
  -B rstudio -d ~/dotfiles
```

### Benefits of Environment System

- Eliminates duplication through single source of truth
- Provides 14+ specialized environments from 200MB to 3.5GB
- Offers domain-specific environments for bioinformatics, geospatial,
  HPC, web applications
- Includes professional testing environments matching CRAN
  infrastructure
- Supports lightweight Alpine environments (5x smaller than standard
  images)
- Enables interactive discovery through environment browser
- Maintains backward compatibility with legacy full definitions
- Simplifies maintenance through centralized updates

## Data Documentation System

ZZCOLLAB includes an automated data documentation system that
implements research best practices for data management and
reproducibility.

### Automated Data README Creation

Every new zzcollab project automatically includes a comprehensive
`data/README.md` template with:

**Data Organization Structure**:

```
data/
├── raw_data/           # Original, untouched data files
├── derived_data/       # Cleaned and processed data files
├── correspondence/     # Email communications, data transfer notes
└── README.md          # Comprehensive data documentation
```

**Template Features**:

- Complete data dictionary with column descriptions, types, valid
  ranges, missing value codes
- Processing documentation linking derived files to their creating
  scripts
- Quality notes documenting known issues, validation checks,
  reproducibility instructions
- Palmer Penguins example providing ready-to-customize template
  with realistic data scenario

### Data Workflow Guide

ZZCOLLAB includes a detailed `DATA_WORKFLOW_GUIDE.md` providing
step-by-step guidance for data management throughout the research
lifecycle. The guide is automatically installed with all new
projects.

**6-Phase Workflow Process**:

1. **Data Receipt & Initial Setup** (HOST) - File placement, initial
   documentation, data source recording
2. **Data Exploration & Validation** (CONTAINER) - Quality assessment,
   diagnostic plots, missing data analysis
3. **Data Preparation Development** (CONTAINER) - Function development,
   processing scripts, transformation logic
4. **Unit Testing & Validation** (CONTAINER) - Comprehensive test
   coverage, edge case testing
5. **Integration Testing & Documentation** (HOST/CONTAINER) - Pipeline
   validation, full workflow testing
6. **Final Validation & Deployment** (HOST/CONTAINER) - Production
   readiness, reproducibility verification

**Key Features**:

- Scientific rationale explaining how data testing prevents research
  integrity issues
- Clear HOST vs CONTAINER operation indicators for environment
  context
- Complete documentation structure guidance with 13 specific sections
- Palmer Penguins examples with working code throughout all 6 phases
- Template integration automatically installed via
  `create_data_templates()`
- Testing framework including unit tests, integration tests, helper
  functions, data file validation
- Quality assurance requirements with >90% test coverage
- Container workflow guidance indicating when to exit/enter
  containers

### Example Data Workflow Documentation

The guide includes practical Palmer Penguins examples for all phases:

```r
# Palmer Penguins data preparation function
prepare_penguin_data <- function(data, n_records = 50) {
  # Input validation
  required_cols <- c("species", "island", "bill_length_mm",
                     "bill_depth_mm", "flipper_length_mm",
                     "body_mass_g", "sex", "year")

  # Processing with log transformation
  result <- data %>%
    slice_head(n = n_records) %>%
    filter(!is.na(body_mass_g)) %>%
    mutate(log_body_mass_g = log(body_mass_g)) %>%
    mutate(species = as.factor(species))

  return(result)
}
```

### Benefits for Reproducible Research

- Standardized documentation following consistent patterns with 13
  structured sections
- Traceability through clear links between raw data, processing
  scripts, and derived datasets
- Quality assurance via built-in data validation and quality check
  documentation
- Research standards compliance following academic data management
  standards
- Collaboration support enabling team members to immediately
  understand data structure and processing
- Testing framework providing comprehensive validation preventing
  silent data quality issues
- Docker workflow integration with proper separation of host file
  management and container analysis
- Template automation with both `data/README.md` and
  `DATA_WORKFLOW_GUIDE.md` automatically installed
- Enhanced documentation including scientific rationale,
  troubleshooting guidance, and complete command references

## Getting Started

### Prerequisites
- **Docker** (required for containerized workflow)
- **Git** (required for collaboration)
- **GitHub CLI** (`gh`) for automated repository management
- **Docker Hub account** for team image publishing

### Quick Start for Teams

#### Developer 1 (Team Lead) - Automated Setup
```bash
# 1. Install zzcollab (one-time)
git clone https://github.com/your-org/zzcollab.git
cd zzcollab
./install.sh                    # Installs to ~/bin

# 2a. Create team Docker images only (two-step process)
cd ~/projects                   # Your preferred projects directory
# NEW: -i flag now ONLY creates and pushes team Docker images, then stops
zzcollab -i -t mylab -p study2024 -d ~/dotfiles                      # Creates
                                                                      # team images,
                                                                      # stops
zzcollab -i -t mylab -p study2024 -F -d ~/dotfiles                   # Fast mode:
                                                                      # minimal
                                                                      # packages
zzcollab -i -t mylab -p study2024 -C -d ~/dotfiles                   # Comprehensive:
                                                                      # full packages
zzcollab -i -t mylab -p study2024 -B rstudio -d ~/dotfiles          # RStudio
                                                                      # environment only

# Alternative: Auto-detect project name from directory
mkdir study2024 && cd study2024
zzcollab -i -t mylab -B all -d ~/dotfiles                           # All variants
                                                                     # (shell, rstudio,
                                                                     # verse)

# 2b. Create full project structure separately
mkdir study2024 && cd study2024  # or git clone if repo exists
zzcollab -t mylab -p study2024 -I shell -d ~/dotfiles               # Full
                                                                       # project
                                                                       # setup


# For teams needing custom packages - two-step process:
# zzcollab -i -t mylab -p study2024 -P
# Edit study2024/Dockerfile.teamcore to add packages, then:
# zzcollab -i -t mylab -p study2024 -d ~/dotfiles

# 3. Start developing immediately
cd study2024
make docker-zsh                # → Enhanced development environment
```

#### Developers 2+ (Team Members) - Join Project
```bash
# 1. Clone team repository (private)
git clone https://github.com/mylab/study2024.git
cd study2024

# 2. Join project with one command
zzcollab -t mylab -p study2024 -I shell -d ~/dotfiles
# Note: -p can be omitted if current directory name matches project

# Alternative build modes for team members:
# zzcollab -t mylab -p study2024 -I shell -F -d ~/dotfiles  # Fast mode
# zzcollab -t mylab -p study2024 -I shell -C -d ~/dotfiles  # Comprehensive
                                                              # mode

# 3. Start developing immediately
make docker-zsh                # → Same environment as team lead
```

## Installation & Distribution

### One-Time Installation

```bash
# Clone and install globally
git clone https://github.com/your-org/zzcollab.git
cd zzcollab
./install.sh                   # Installs zzcollab to ~/bin

# Verify installation
which zzcollab                 # Should show ~/bin/zzcollab
```

### Self-Replicating Team Strategy

ZZCOLLAB implements automated team distribution:

- Team lead runs `zzcollab -i` once to create team infrastructure
- Creates private GitHub repository with full project structure
- Team members clone and obtain everything automatically
- No separate installation required for team members

### Team Collaboration Workflow

```bash
# Team member workflow
git clone https://github.com/mylab/study2024.git
cd study2024

# Choose available interface:
zzcollab -t mylab -p study2024 -I shell -d ~/dotfiles
zzcollab -t mylab -p study2024 -I rstudio -d ~/dotfiles
zzcollab -t mylab -p study2024 -I verse -d ~/dotfiles
```

## Solo Developer Workflow

ZZCOLLAB provides a streamlined workflow for individual researchers
requiring professional-grade reproducibility with minimal overhead.

### Quick Start Solo Workflow

**Initial Setup (One-Time)**:

```bash
# Install ZZCOLLAB
git clone https://github.com/rgt47/zzcollab.git
cd zzcollab && ./install.sh

# Configure defaults to eliminate repetitive typing
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"
zzcollab --config set dotfiles-dir "~/dotfiles"
```

**Project Creation**:

```bash
# Quick start with optimal environments automatically selected
zzcollab -i -p penguin-analysis --github

# Advanced users can browse 14+ environments interactively
mkdir penguin-analysis && cd penguin-analysis
zzcollab -i -p penguin-analysis
./add_environment.sh
```

**Daily Development Cycle**:

```bash
# Start development environment
cd penguin-analysis
make docker-zsh

# Work inside container
vim scripts/01_penguin_exploration.R
vim R/penguin_functions.R
vim tests/testthat/test-functions.R

# Test and run analysis
R
devtools::load_all()
devtools::test()
source("scripts/01_penguin_exploration.R")
quit()

# Exit container
exit

# Validate and commit
make docker-test
git add . && git commit -m "Add analysis" && git push
```

### Practical Example: Penguin Bill Analysis

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
         x = "Log(Bill Length) (mm)",
         y = "Bill Depth (mm)") +
    theme_minimal()
}

bill_plot <- create_bill_plot()
ggsave("figures/bill_analysis.png", bill_plot,
       width = 8, height = 6)
```

**Function with Tests**:

```r
# R/penguin_functions.R
#' Create scatter plot of bill depth vs log(bill length)
#' @export
create_bill_plot <- function(data =
                              palmerpenguins::penguins) {
  # Implementation with proper error handling
}

# tests/testthat/test-penguin_functions.R
test_that("create_bill_plot works correctly", {
  plot <- create_bill_plot()
  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title,
               "Penguin Bill Depth vs Log(Bill Length)")
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
    geom_smooth(method = "lm", se = TRUE) +
    labs(title = "Penguin Bill Analysis with Regression")
}

fit_bill_model <- function() {
  # Linear regression with model diagnostics
  # Returns list with model, r_squared, coefficients
}
```

### Solo Developer Benefits

- **Reproducible**: Identical environment for every development session
- **Professional**: Automated testing, validation, and CI/CD
- **Flexible**: 14+ environments for different research domains
- **Lightweight**: Alpine environments at approximately 200MB versus
  standard 1GB+
- **Team-ready**: Facilitates transition to collaboration
- **Container-based**: Eliminates conflicts with host system R
  installation

### From Solo to Team Transition

Solo projects are inherently team-ready:

```bash
# Others can join your project immediately
git clone https://github.com/yourname/penguin-analysis.git
cd penguin-analysis
zzcollab -t yourname -p penguin-analysis -I analysis
make docker-zsh
```

## Team Collaboration Setup

### Developer 1 (Team Lead): Complete Project Initialization

#### Automated Approach (Three Options)
**Choose between modern environment system, legacy approach, or R interface:**

**Option A: Modern Environment System (NEW - Recommended)**
```bash
# Advanced Variant Management: Create Custom Docker Environments
# Default: Creates minimal + analysis environments automatically
zzcollab -i -t mylab -p study2024 -d ~/dotfiles                     # Modern approach

# Interactive environment discovery and management:
mkdir study2024 && cd study2024
zzcollab -i -t mylab -p study2024 -d ~/dotfiles                     # Creates config.yaml
./add_environment.sh                                                    # Interactive environment browser

# Variant categories available:
# Standard: minimal, analysis, modeling, publishing (~800MB-3GB)
# Specialized: bioinformatics (Bioconductor), geospatial (sf/terra) (~2-2.5GB)
# Alpine: ultra-lightweight for CI/CD (~200-600MB vs ~1GB rocker)
# R-hub: CRAN-compatible testing (Ubuntu, Fedora, Windows environments)

# Manual environment configuration (edit config.yaml):
# Set enabled: true for environments you want built
# Customize packages and system dependencies as needed
```

**Option B: Legacy Selective Building**
```bash
# Traditional approach: limited to r-ver, rstudio, verse variants
zzcollab -i -t mylab -p study2024 -B rstudio -d ~/dotfiles          # RStudio only
zzcollab -i -t mylab -p study2024 -B all -S -d ~/dotfiles           # All 3 variants
zzcollab -i -t mylab -p study2024 -F -d ~/dotfiles                  # Fast mode (8 packages)
zzcollab -i -t mylab -p study2024 -C -d ~/dotfiles                  # Comprehensive (27+ packages)
```

**Step 2: Create Full Project Structure Separately**
```bash
# After team images are created and pushed, create project structure:
mkdir study2024 && cd study2024  # or git clone if repository exists
zzcollab -t mylab -p study2024 -I shell -d ~/dotfiles               # Full
                                                                       # project
                                                                       # setup with shell interface
zzcollab -t mylab -p study2024 -I rstudio -d ~/dotfiles             # Or with RStudio interface

# Auto-detect with fast build mode
mkdir study2024 && cd study2024
zzcollab -i -t mylab -F -d ~/dotfiles

# Auto-detect with comprehensive build mode
mkdir study2024 && cd study2024
zzcollab -i -t mylab -C -d ~/dotfiles


# OR with custom Dockerfile editing:
zzcollab -i -t mylab -p study2024 -P
# Edit study2024/Dockerfile.teamcore as needed, then:
zzcollab -i -t mylab -p study2024 -d ~/dotfiles
```

**Option B: R Interface (R-Centric Workflow)**
```r
# From R console
library(zzcollab)

# Complete automated setup from within R
init_project(
  team_name = "mylab",
  project_name = "study2024",
  dotfiles_path = "~/dotfiles"
)
```

**Both approaches automatically:**
- Creates project directory with complete R package structure
- Sets up customizable Dockerfile.teamcore for team's packages
- Builds shell and RStudio core images (multi-platform)
- Tags and pushes images to Docker Hub (public for reproducibility)
- Initializes zzcollab project with team base image
- Creates private GitHub repository
- Sets up initial commit with proper structure
- Configures automated CI/CD for team image management

### Developers 2+ (Team Members): Join Existing Project

**Choose between command-line or R interface:**

**Option A: Command-Line Interface**
```bash
# 1. Clone team repository (must be added as collaborator first or use public repo)
git clone https://github.com/mylab/study2024.git
cd study2024

# 2. Join project with automated environment setup using existing team images
zzcollab -t mylab -p study2024 -I shell -d ~/dotfiles             # Shell interface
zzcollab -t mylab -p study2024 -I rstudio -d ~/dotfiles           # RStudio interface (if team built this environment)
zzcollab -t mylab -p study2024 -I verse -d ~/dotfiles             # Publishing interface (if available)
# Note: --project-name can be omitted if current directory name matches project

# If team image environment not available, you'll get helpful guidance:
# Error: Team image 'mylab/study2024core-rstudio:latest' not found
# Available environments: mylab/study2024core-shell:latest
# Solutions: Use available environment or ask team lead to build missing variant

# 3. Start development immediately
make docker-zsh                # Shell interface with vim/tmux
# OR (if RStudio environment was built by team)
make docker-rstudio            # RStudio Server at localhost:8787
```

**Option B: R Interface (R-Centric Workflow)**
```r
# From R console after cloning repository
library(zzcollab)

# Standard join
join_project(
  team_name = "mylab",
  project_name = "study2024",
  interface = "shell",          # or "rstudio"
  dotfiles_path = "~/dotfiles"
)

# With specific build mode
join_project(
  team_name = "mylab",
  project_name = "study2024",
  interface = "shell",
  build_mode = "fast",          # or "comprehensive"
  dotfiles_path = "~/dotfiles"
)
```

### Configuration Options

#### Build Modes
zzcollab supports four build modes optimized for different use cases:

| Mode | Flag | Packages | Build Time | Use Case |
|------|------|----------|------------|----------|
| **Minimal** | `-M` | 3 packages | Ultra-fast (~30s) | Learning, bare essentials |
| **Fast** | `-F` | ~9 packages | Fast (2-3 min) | Quick development, CI/CD |
| **Standard** | `-S` (default) | ~17 packages | Medium (4-6 min) | Balanced workflows |
| **Comprehensive** | `-C` | ~47 packages | Slow (15-20 min) | Full feature environments |

```bash
# Build mode examples
zzcollab -i -t mylab -p study2024 -M -d ~/dotfiles    # Minimal mode (ultra-fast)
zzcollab -i -t mylab -p study2024 -F -d ~/dotfiles    # Fast mode
zzcollab -i -t mylab -p study2024 -S -d ~/dotfiles    # Standard mode (default)
zzcollab -i -t mylab -p study2024 -C -d ~/dotfiles    # Comprehensive mode

# Build mode detection via environment variable
ZZCOLLAB_BUILD_MODE=fast zzcollab -i -t mylab -p study2024 -d ~/dotfiles

# Team member with specific build mode
zzcollab -t mylab -p study2024 -I shell -F -d ~/dotfiles
```

#### Advanced Configuration
```bash
# Team lead with custom GitHub account
zzcollab -i -t mylab -p study2024 --github-account myuniversity

# With dotfiles that need dots added (files like: bashrc, vimrc)
zzcollab -i -t mylab -p study2024 --dotfiles-nodot ~/Dropbox/dotfiles

# Team member with specific interface preference
zzcollab -t mylab -p study2024 -I rstudio -d ~/dotfiles
```

## Directory Structure

### Core Directories

```
your-project/
├── R/                          # Package functions (exported to users)
├── man/                        # Function documentation (auto-generated)
├── scripts/                    # Working R scripts and analysis code
├── data/                       # All data files and documentation
│   ├── raw_data/              # Original, unmodified datasets
│   ├── derived_data/          # Processed, analysis-ready data
│   ├── metadata/              # Data dictionaries and documentation
│   ├── validation/            # Data quality reports
│   └── external_data/         # Third-party datasets
├── analysis/                   # Research analysis components
│   ├── report/                # Manuscript files (report.Rmd → report.pdf)
│   ├── figures/               # Generated plots and figures
│   ├── tables/                # Generated tables
│   └── templates/             # Document templates
├── tests/                      # Unit tests for R functions
│   ├── testthat/              # Unit tests for package functions
│   └── integration/           # Integration tests for analysis scripts
├── vignettes/                  # Package tutorials and examples
├── docs/                       # Project documentation and outputs
├── archive/                    # Moved files and legacy code
├── .github/workflows/          # GitHub Actions CI/CD (automated team image management)
└── Key files (DESCRIPTION, Makefile, Docker files, etc.)
```

### What Goes Where?

| Content Type | Location | Purpose |
|--------------|----------|---------|
| **Reusable functions** | `R/` | Functions you want others to use |
| **Function documentation** | `man/` | Auto-generated help files (.Rd) |
| **Analysis scripts** | `scripts/` | Working code, exploratory analysis |
| **Research paper** | `analysis/report/` | Manuscript and publication files |
| **Generated figures** | `analysis/figures/` | Plots and visualizations |
| **Generated tables** | `analysis/tables/` | Statistical tables |
| **Raw data** | `data/raw_data/` | Original, unmodified datasets |
| **Clean data** | `data/derived_data/` | Processed, analysis-ready data |
| **Data documentation** | `data/metadata/` | Data dictionaries, codebooks |
| **Unit tests** | `tests/testthat/` | Tests for your R functions |
| **Integration tests** | `tests/integration/` | Tests for analysis scripts |
| **Tutorials** | `vignettes/` | Package examples and tutorials |

## Navigation Shortcuts

Convenient navigation scripts for quick directory access:

```bash
# First, generate the navigation scripts (one-time setup)
./navigation_scripts.sh

# Then use the generated navigation shortcuts
./a     # → Navigate to ./data              (data files)
./n     # → Navigate to ./analysis          (analysis files)
./f     # → Navigate to ./analysis/figures  (figures)
./t     # → Navigate to ./analysis/tables   (tables)
./s     # → Navigate to ./scripts           (working R scripts)
./m     # → Navigate to ./man               (function documentation)
./e     # → Navigate to ./tests             (tests)
./o     # → Navigate to ./docs              (documentation)
./c     # → Navigate to ./archive           (archived files)
./p     # → Navigate to ./analysis/report   (research paper)
```

**Setup**: Run `./navigation_scripts.sh` once to create the navigation shortcuts.

**Usage**: `./a` to go to data directory, `./n` to go to analysis, etc. Each command opens a new shell in the target directory.

## Development Environments

### Team Development Workflow

#### Daily Development Cycle (All Team Members)
```bash
# 1. Sync with latest team changes
git pull                        # Get latest code changes
docker pull mylab/study2024:latest  # Get latest team environment

# 2. Start development environment
make docker-zsh                # → Enhanced zsh shell with vim/tmux
# OR
make docker-rstudio            # → RStudio at http://localhost:8787

# 3. Do your analysis, install packages as needed
# Inside container: install.packages("package_name")
# 4. When done, exit container
exit

# 5. Validate dependencies before committing
make docker-check-renv-fix

# 6. Commit and push your work
git add .
git commit -m "Analysis update with comprehensive tests"
git push
```

#### Team Synchronization (When Dependencies Change)
```bash
# When any team member adds packages and pushes changes:
git pull                        # Get latest renv.lock changes
# GitHub Actions automatically rebuilds team image
docker pull mylab/study2024:latest  # Get updated environment
make docker-zsh                # Continue development with new packages
```

### Development Environment Options

| Environment | Command | Use Case |
|-------------|---------|----------|
| **Enhanced Shell** | `make docker-zsh` | Vim/tmux development with dotfiles |
| **RStudio Server** | `make docker-rstudio` | GUI-based development |
| **R Console** | `make docker-r` | Command-line R work |
| **Bash Shell** | `make docker-bash` | File management, git operations |
| **Paper Rendering** | `make docker-render` | Generate manuscript |
| **Package Testing** | `make docker-test` | Run unit tests |

## Package Management with renv

### Automated Team Package Management
ZZCOLLAB includes **systematic automated package management**:

1. **Team image creation**: Base packages pre-installed in team Docker images
2. **Individual additions**: Use normal `install.packages()` in development
3. **Automatic synchronization**: `renv::snapshot()` when adding packages
4. **Team notification**: GitHub Actions rebuilds and notifies team
5. **Zero friction sync**: Team members get updates automatically

### Package Workflow (Any Team Member)
```bash
# Inside Docker container:
install.packages("tidymodels")    # Install new package
# Use package in your analysis...
renv::snapshot()                  # Save to renv.lock
exit

# Outside container:
make docker-check-renv-fix        # Validate and update DESCRIPTION
git add .                         # Commit changes
git commit -m "Add tidymodels for machine learning analysis"
git push                          # → Triggers automatic team image rebuild
```

### Automated Team Image Management
When any team member adds packages:
1. **Push triggers GitHub Actions** → detects renv.lock changes
2. **New Docker image built** → includes all team packages
3. **Image pushed to Docker Hub** → available to all team members
4. **Team notification** → commit comment with update instructions
5. **Team members sync** → `docker pull` gets new environment

### renv Validation System
**Automated validation** ensures package consistency:

```bash
# Check if packages are in sync
make check-renv

# Auto-fix any issues
make check-renv-fix

# Silent check for CI/CD (with build mode awareness)
Rscript validate_package_environment.R --fix --strict-imports --fail-on-issues

# With explicit build mode override
Rscript validate_package_environment.R --fix --build-mode fast --fail-on-issues

# Using environment variable for build mode detection
ZZCOLLAB_BUILD_MODE=comprehensive Rscript validate_package_environment.R --fix --fail-on-issues
```

**Enhanced validation features**:
- **Build mode awareness**: Adapts validation rules based on fast/standard/comprehensive modes
- **Robust package extraction**: Handles wrapped calls like `suppressMessages(library(pkg))`
- **Enhanced edge case handling**: Detects conditional package loading, roxygen imports
- **Comprehensive error handling**: Structured exit codes and detailed error messages
- **zzcollab integration**: Uses zzcollab logging and respects system configuration
- **Base package filtering**: Automatically excludes R base packages from CRAN validation
- **Network resilience**: Graceful handling of CRAN API failures

**What it validates**:
- All packages used in code (R/, scripts/, analysis/, tests/, vignettes/, inst/) are in DESCRIPTION
- All packages in DESCRIPTION exist on CRAN (with base package exclusion)
- renv.lock is synchronized with DESCRIPTION
- Build mode compatibility (fast mode limits to essential packages)
- **Strict mode**: Scans all directories for maximum reproducibility

## Docker Environment

### Single-Image Interface Architecture
ZZCOLLAB uses a **single Docker image approach** where you select one interface type at setup time:

| Interface | Purpose | Setup Command | Access |
|-----------|---------|---------------|---------|
| `shell` | Enhanced shell development | `zzcollab -I shell` | `make docker-zsh` |
| `rstudio` | GUI development | `zzcollab -I rstudio` | http://localhost:8787 |
| `verse` | Publishing workflow with LaTeX | `zzcollab -I verse` | `make docker-verse` |

Each interface provides access to specialized development tasks:
- **Research tasks**: `make docker-render`, `make docker-test`, `make docker-check`
- **Shell access**: `make docker-bash`, `make docker-r` (R console)

### Team Docker Image Strategy
- **Team core images**: Public on Docker Hub (software only, no data)
- **Personal development images**: Local only (includes dotfiles)
- **Automated rebuilds**: GitHub Actions triggers on renv.lock changes
- **Multi-platform**: Supports AMD64 and ARM64 architectures

### Docker Features
- **Automatic R version detection** from renv.lock
- **Team base image integration**: Inherits from custom team environments
- **Persistent package cache** for faster rebuilds
- **Developer tools included**: vim, tmux, ripgrep, fzf, zsh, etc.
- **Dotfiles support**: Your `.vimrc`, `.zshrc`, etc. copied to container

### Docker Commands
```bash
# Build/rebuild environment
make docker-build

# Development environments (interface-specific)
make docker-zsh                 # Enhanced zsh with dotfiles (shell interface)
make docker-rstudio             # RStudio GUI (rstudio interface)
make docker-verse               # Publishing workflow (verse interface)
make docker-r                   # R console (all interfaces)
make docker-bash                # Shell access (all interfaces)

# Automated tasks
make docker-render              # Render paper
make docker-test                # Run tests
make docker-check              # Validate package
make docker-check-renv         # Check dependencies

# Cleanup
make docker-clean              # Remove images and volumes
```

## Build System with Make

### Native R Commands
*Require local R installation*

```bash
make document                   # Generate documentation
make build                      # Build package
make check                      # Check package
make install                    # Install package locally
make test                       # Run tests
make vignettes                  # Build vignettes

# Dependency management
make deps                       # Run setup_renv.R
make check-renv                 # Validate dependencies
make check-renv-fix            # Auto-fix dependency issues
make check-renv-ci             # Silent validation for CI
```

### Docker Commands
*Work without local R installation*

```bash
make docker-build              # Build Docker image
make docker-document           # Generate docs in container
make docker-test               # Run tests in container
make docker-check-renv         # Validate deps in container
make docker-check-renv-fix     # Fix deps in container
make docker-render             # Render paper in container
```

### Cleanup Commands
```bash
make clean                     # Remove build artifacts
make docker-clean             # Remove Docker images/volumes
```

### Help System
```bash
make help                      # Show all available targets
```

## GitHub Actions CI/CD

### Automated Team Image Management

ZZCOLLAB includes sophisticated automated Docker image management that reduces manual container maintenance while ensuring consistent environment compatibility across research teams.

#### Complete GitHub Actions Workflow

The system automatically detects package changes, rebuilds Docker images, and notifies team members through a comprehensive GitHub Actions workflow:

**Key Features:**
- **Intelligent change detection**: Monitors `renv.lock`, `DESCRIPTION`, `Dockerfile`
- **Multi-platform support**: AMD64 and ARM64 architectures
- **Advanced caching**: GitHub Actions cache with BuildKit optimization
- **Comprehensive tagging**: `latest`, `r4.3.0`, `abc1234`, `2024-01-15` tags
- **Automated configuration**: Updates Dockerfile references
- **Team communication**: Detailed commit comments with usage instructions

#### Workflow Triggers
```yaml
# Automatic triggers
on:
  push:
    branches: [main]
    paths: 
      - 'renv.lock'           # R package dependency changes
      - 'DESCRIPTION'         # Package metadata changes
      - 'Dockerfile'          # Container definition changes
  workflow_dispatch:           # Manual triggering
```

#### Usage Scenarios

**Scenario 1: Developer Adds New Package**
```bash
# Developer workflow
R
install.packages("tidymodels")
renv::snapshot()
# Create PR and merge

# Automatic result:
# GitHub Actions detects renv.lock changes
# Rebuilds image with tidymodels
# Pushes to mylab/study2024:latest on Docker Hub
# Updates Dockerfile configuration
# Notifies team via commit comment
```

**Scenario 2: Team Member Gets Updates**
```bash
# Team member workflow
git pull                        # Gets latest changes
docker pull mylab/study2024:latest  # Gets updated environment
make docker-zsh                # Instant access to new packages
```

### Security and Privacy Model

**🔒 PRIVATE GitHub Repository:**
- Protects unpublished research and sensitive methodologies
- Secures proprietary data analysis and preliminary results
- Controls access to research collaborators only

**🌍 PUBLIC Docker Images (Docker Hub):**
- Enables reproducible research by sharing computational environments
- Supports open science through transparent methodology
- No sensitive data included - only software packages and configurations

### Repository Secrets Setup
For automated Docker Hub publishing, configure these secrets in your **private** GitHub repository:

```bash
# In GitHub repository: Settings → Secrets and variables → Actions
DOCKERHUB_USERNAME: your-dockerhub-username
DOCKERHUB_TOKEN: your-dockerhub-access-token  # Create at hub.docker.com/settings/security
```

### Standard R Package Validation

#### R Package Check (`.github/workflows/r-package.yml`)
- **Triggers**: Push/PR to main/master
- **Purpose**: Validate package structure and dependencies
- **Features**:
  - Native R setup (fast execution)
  - renv synchronization validation with enhanced dependency scanning
  - Package checks across platforms
  - Dependency validation with `validate_package_environment.R --strict-imports`

#### Paper Rendering (`.github/workflows/render-report.yml`)
- **Triggers**: Manual dispatch, changes to analysis files
- **Purpose**: Generate research paper automatically
- **Features**:
  - Automatic PDF generation
  - Artifact upload
  - Native R environment (faster than Docker)

## R Interface Functions

ZZCOLLAB provides a comprehensive R interface that allows you to manage your research workflow entirely from within R. These functions provide R-native access to Docker infrastructure, project management, and reproducibility tools.

### Docker Environment Helpers

#### `status()`
Check the status of running zzcollab containers.

```r
# Check container status
status()
# Returns container information or message if none running
```

#### `rebuild(target = "docker-build")`
Trigger a Docker image rebuild for your project.

```r
# Rebuild the Docker image
rebuild()

# Rebuild specific target
rebuild("docker-test")
```

#### `team_images()`
List available team Docker images with details.

```r
# View team images
images <- team_images()
print(images)
# Returns data frame with repository, tag, size, created columns
```

### Project Management Functions

#### `init_project()`
Initialize a new zzcollab project from within R. **Note**: This is the R interface to `zzcollab --init` and should only be used by **Developer 1 (team lead)** to create the initial team infrastructure.

```r
# Developer 1: Complete team setup (creates team images + GitHub repo)
init_project(
  team_name = "mylab", 
  project_name = "study2024"
)

# With dotfiles and specific build mode
init_project(
  team_name = "mylab",
  project_name = "study2024", 
  build_mode = "standard",        # "fast", "standard", or "comprehensive"
  dotfiles_path = "~/dotfiles"
)

# Fast setup for quick development (8 packages)
init_project(
  team_name = "mylab",
  project_name = "study2024",
  build_mode = "fast",
  dotfiles_path = "~/dotfiles"
)

# Comprehensive setup for full ecosystem (27+ packages)
init_project(
  team_name = "mylab",
  project_name = "study2024",
  build_mode = "comprehensive",
  dotfiles_path = "~/dotfiles"
)
```

#### `join_project()`
Join an existing zzcollab project (for **Developers 2+**).

```r
# Join existing project with shell interface
join_project(
  team_name = "mylab",
  project_name = "study2024", 
  interface = "shell",
  dotfiles_path = "~/dotfiles"
)

# Join with RStudio interface and specific build mode
join_project(
  team_name = "mylab",
  project_name = "study2024",
  interface = "rstudio",
  build_mode = "standard",        # "fast", "standard", or "comprehensive"
  dotfiles_path = "~/dotfiles"
)

# Join with fast build mode for quick setup
join_project(
  team_name = "mylab",
  project_name = "study2024",
  interface = "shell",
  build_mode = "fast",
  dotfiles_path = "~/dotfiles"
)
```

#### `add_package(packages, update_snapshot = TRUE)`
Add R packages to your project with automatic renv integration.

```r
# Add single package
add_package("tidyverse")

# Add multiple packages
add_package(c("brms", "targets", "cmdstanr"))

# Add packages without updating renv.lock immediately
add_package("ggplot2", update_snapshot = FALSE)
```

#### `sync_env()`
Synchronize your R environment across team members.

```r
# Restore environment from renv.lock
sync_env()
# Automatically checks if Docker rebuild is needed
```

### Analysis Workflow Functions

#### `run_script(script_path, container_cmd = "docker-r")`
Execute R scripts inside Docker containers.

```r
# Run analysis script in container
run_script("scripts/01_data_processing.R")

# Run with specific container command
run_script("scripts/02_modeling.R", "docker-rstudio")
```

#### `render_report(report_path = NULL)`
Render analysis reports in containerized environment.

```r
# Render default report
render_report()

# Render specific report
render_report("analysis/report/manuscript.Rmd")
```

#### `validate_repro()`
Check reproducibility of your research project.

```r
# Run all reproducibility checks
is_reproducible <- validate_repro()

if (is_reproducible) {
  message("Project is fully reproducible")
} else {
  message("Reproducibility issues detected")
}
```

### Git and GitHub Integration Functions

#### `git_status()`
Check the current git status of your project.

```r
# Check for uncommitted changes
git_status()
```

#### `create_branch(branch_name)`
Create and switch to a new feature branch.

```r
# Create feature branch for new analysis
create_branch("feature/advanced-modeling")
```

#### `git_commit(message, add_all = TRUE)`
Create a git commit with all changes.

```r
# Commit your analysis work
git_commit("Add multilevel modeling analysis with comprehensive tests")
```

#### `git_push(branch = NULL)`
Push commits to GitHub.

```r
# Push current branch to GitHub
git_push()

# Push specific branch
git_push("feature/advanced-modeling")
```

#### `create_pr(title, body = NULL, base = "main")`
Create a GitHub pull request.

```r
# Create pull request
create_pr(
  title = "Add advanced multilevel modeling analysis",
  body = "This PR adds comprehensive multilevel modeling with full test coverage and reproducibility validation."
)
```

### Help System Functions

#### `zzcollab_help(topic = NULL)`
Access zzcollab's comprehensive help system directly from R. Displays specialized help pages covering configuration, workflows, Docker, and more.

```r
# Display main help
zzcollab_help()

# Get quick start guide for individual researchers
zzcollab_help("quickstart")

# Learn about daily development workflow
zzcollab_help("workflow")

# Troubleshooting common issues
zzcollab_help("troubleshooting")

# Configuration system guide
zzcollab_help("config")

# Dotfiles setup and management
zzcollab_help("dotfiles")

# Package management with renv
zzcollab_help("renv")

# Build mode selection guide
zzcollab_help("build-modes")

# Docker essentials for researchers
zzcollab_help("docker")

# CI/CD and GitHub Actions
zzcollab_help("cicd")

# Docker environments configuration
zzcollab_help("variants")

# GitHub integration
zzcollab_help("github")

# Team initialization help
zzcollab_help("init")

# Development workflow guidance
zzcollab_help("next-steps")
```

**Available Topics:**
- `"quickstart"` - Individual researcher quick start guide
- `"workflow"` - Daily development workflow
- `"troubleshooting"` - Top 10 common issues and solutions
- `"config"` - Configuration system guide
- `"dotfiles"` - Dotfiles setup and management
- `"renv"` - Package management with renv
- `"build-modes"` - Build mode selection guide
- `"docker"` - Docker essentials for researchers
- `"cicd"` - CI/CD and GitHub Actions
- `"variants"` - Docker environments configuration
- `"github"` - GitHub integration and automation
- `"init"` - Team initialization process
- `"next-steps"` - Development workflow guidance

### Benefits of R Interface

- **Native R workflow**: No need to switch between R and terminal
- **RStudio integration**: Works effectively in RStudio environment
- **Error handling**: R-style error messages and debugging
- **Return values**: Functions return logical values for programmatic use
- **Documentation**: Full R help system with `?status`
- **Type safety**: R parameter validation and type checking

## Team Collaboration Workflows

### Developer 1 (Team Lead): Complete R Workflow

#### Setup Phase (R Console)
```r
library(zzcollab)

# 1. Initialize new team project (creates team infrastructure)
init_project(
  team_name = "mylab",
  project_name = "study2024",
  dotfiles_path = "~/dotfiles"
)
# This creates Docker images, GitHub repo, and full project structure

# Change to project directory and exit R for containerized development
setwd("study2024")
quit()
```

#### Development Phase (Container)
```bash
# Enter containerized development environment
make docker-zsh  # or make docker-rstudio
```

#### Analysis Phase (Back in R - now containerized)
```r
library(zzcollab)

# 2. Add required packages
add_package(c("tidyverse", "brms", "targets", "rmarkdown", "here"))

# 3. Run analysis pipeline
run_script("scripts/01_data_import.R")
run_script("scripts/02_data_analysis.R") 
run_script("scripts/03_visualization.R")

# 4. Render final report
render_report("analysis/report/report.Rmd")

# 5. Validate reproducibility
validate_repro()

# 6. Git workflow - all from R!
git_status()  # Check what changed
git_commit("Initial analysis pipeline with reproducibility validation")
git_push()   # Push to GitHub

# 7. Sync environment for team
sync_env()
```

### Developers 2+ (Team Members): Complete R Workflow

#### Initial Setup (Command Line)
```bash
git clone https://github.com/mylab/study2024.git
cd study2024
```

#### Project Join (R Console)
```r
library(zzcollab)

# 1. Join the project
join_project(
  team_name = "mylab",
  project_name = "study2024",
  interface = "shell",  # or "rstudio"
  dotfiles_path = "~/dotfiles"
)

# Exit R to enter containerized environment
quit()
```

#### Development Phase (Container)
```bash
make docker-zsh  # Enter containerized development with team packages
```

#### Analysis Phase (Back in R - now containerized)
```r
library(zzcollab)

# 2. Sync with team environment
sync_env()

# 3. Create feature branch for your work
create_branch("feature/visualization-analysis")

# 4. Add any additional packages needed
add_package("ggridges")  # Example: specific package for your analysis

# 5. Run your analysis pipeline
run_script("scripts/my_visualization_analysis.R")
render_report("analysis/my_section.Rmd")

# 6. Validate reproducibility
validate_repro()

# 7. Complete R-based git workflow
git_status()  # Check your changes
git_commit("Add visualization analysis with ridge plots and comprehensive tests")
git_push("feature/visualization-analysis")

# 8. Create pull request - all from R!
create_pr(
  title = "Add visualization analysis with ridge plots",
  body = "This PR adds new visualization analysis using ggridges with full test coverage and reproducibility validation."
)
```

### Collaboration Features

#### Automated Quality Assurance on Every Push
- **R Package Validation**: R CMD check with dependency validation
- **Comprehensive Testing Suite**: Unit tests, integration tests, and data validation
- **Paper Rendering**: Automated PDF generation and artifact upload
- **Multi-platform Testing**: Ensures compatibility across environments
- **Dependency Sync**: renv validation and DESCRIPTION file updates

#### Test-Driven Development Workflow
- **Unit Tests**: Every R function has corresponding tests in `tests/testthat/`
- **Integration Tests**: Analysis scripts tested end-to-end in `tests/integration/`
- **Data Validation**: Automated data quality checks
- **Reproducibility Testing**: Environment validation with enhanced dependency scanning
- **Paper Testing**: Manuscript rendering validation for each commit

#### Enhanced GitHub Templates
- **Pull Request Template**: Analysis impact assessment, reproducibility checklist
- **Issue Templates**: Bug reports with environment details, feature requests with research use cases
- **Collaboration Guidelines**: Research-specific workflow standards

## Common Tasks

### Starting a New Analysis
```bash
# 1. Start development environment
make docker-zsh

# 2. Create new analysis script (in container with vim/tmux)
vim scripts/01_data_exploration.R

# 3. Install needed packages
R
install.packages(c("tidyverse", "ggplot2"))
renv::snapshot()
quit()

# 4. Write your analysis...

# 5. Exit container and validate
exit
make docker-check-renv-fix
```

### Rendering Your Paper
```bash
# Render paper to PDF
make docker-render

# View generated paper
open analysis/report/report.pdf
```

### Running Tests
```bash
# Run all package tests
make docker-test

# Check package structure
make docker-check
```

### Adding a New Function
```bash
# 1. Start R environment
make docker-zsh

# 2. Create function file (in container)
vim R/my_function.R

# 3. Document and test the function
R
devtools::document()
devtools::load_all()
my_function(test_data)

# 4. Add unit tests
# Edit tests/testthat/test-my_function.R

# 5. Run tests
devtools::test()
quit()
```

### Team Package Management
```bash
# Add packages (any team member)
make docker-zsh
R
install.packages("new_package")
renv::snapshot()
quit()

# Validate and commit
make docker-check-renv-fix
git add .
git commit -m "Add new_package for advanced modeling"
git push

# Other team members sync automatically:
# GitHub Actions rebuilds image → team gets notification → docker pull gets updates
```

## Recent Enhancements

ZZCOLLAB has undergone substantial development during 2024-2025,
with focus on architecture, usability, and comprehensive
documentation.

### Data Documentation System (2025)

**Automated Data Templates**:

- Comprehensive `data/README.md` automatically created with Palmer
  Penguins examples
- Complete `DATA_WORKFLOW_GUIDE.md` with 6-phase workflow process
- Standardized data structure: raw_data/, derived_data/,
  correspondence/
- Template integration via `create_data_templates()` in
  `modules/structure.sh`
- Testing framework with >90% coverage requirements
- Scientific rationale explaining research integrity benefits

**Critical Safety Improvements**:

- Home directory protection preventing accidental installation in
  `$HOME`
- System directory protection blocking dangerous directories
- Intelligent conflict detection showing only actual zzcollab file
  conflicts
- Enhanced uninstall system with complete cleanup

### Docker Environment System Refactoring (2025)

**Single Source of Truth Architecture**:

- Variant definitions centralized in `environments.yaml`
- Eliminated duplication: team configs reference central library
- Added 14+ environments including shiny, shiny_verse, specialized
  domains
- Interactive environment browser via `./add_environment.sh`
- Backward compatibility maintained for legacy definitions
- Verified system libraries across all variants

**Technical Implementation**:

- Simplified config.yaml: reduced from 455 to 154 lines (66%
  reduction)
- Enhanced add_environment.sh generating lightweight YAML entries
- Updated team_init.sh with dynamic environment loading
- Comprehensive testing validating new format and integration

### Selective Base Image Building System (2024)

**Incremental Workflow**:

- Teams can build only required environments (r-ver, rstudio, verse)
- Start with one environment, add others later with `-V` flag
- Enhanced error handling with helpful guidance
- Short flags for all major options (-i, -t, -p, -I, -B, -V)
- Verse support for publishing workflow with LaTeX via rocker/verse
- Clear team communication about available tooling

**CLI Improvements**:

```bash
# Selective base image flags
-B, --init-base-image TYPE   # r-ver, rstudio, verse, all
-V, --build-variant TYPE     # r-ver, rstudio, verse
-I, --interface TYPE         # shell, rstudio, verse
```

### Enhanced Dependency Validation (2025)

**validate_package_environment.R Improvements**:

- Build mode integration adapting validation rules
- Enhanced package extraction handling wrapped calls, conditional
  loading
- Robust error handling with structured exit codes
- zzcollab integration using system logging
- Base package filtering excluding R base packages from CRAN
  validation
- Network resilience with graceful CRAN API failure handling

### Complete CI/CD Pipeline Resolution (2025)

**R Package Pipeline**:

- Fixed NAMESPACE imports for utils and jsonlite
- Resolved vignette system with proper VignetteBuilder
- Fixed workflow-team.Rmd undefined variables
- Corrected non-ASCII characters using escape sequences
- Resolved roxygen2 documentation warnings
- Added proper operator documentation

**Quality Assurance**:

- All GitHub Actions workflows passing
- Eliminated blocking warnings
- Complete roxygen2 documentation with proper LaTeX formatting
- Clean dependency management
- Robust vignette system with executable examples

### R-Only Workflow Vignettes (2025)

**Pure R Interface Documentation**:

- r-solo-workflow.Rmd for solo developers using only R functions
- r-team-workflow.Rmd for team collaboration via R interface
- Zero Docker exposure for R users unfamiliar with containers
- Complete workflow coverage from setup to deployment
- Real-world examples: penguin analysis and customer churn
  analysis

**Target Audience Expansion**:

- R users familiar with RStudio/tidyverse but not Docker/bash
- Research teams requiring reproducibility without DevOps
  complexity
- Data scientists focused on analysis rather than infrastructure
- Academic labs with varying technical skill levels

### Professional Help System (2025)

**Smart Pagination Implementation**:

- Interactive terminals automatically pipe through `less -R`
- Script-friendly output for redirection
- Color preservation in paged output
- User customizable via `$PAGER` environment variable

**Specialized Help Sections**:

```bash
zzcollab -h                    # Main help
zzcollab --help-init          # Team initialization
zzcollab --help-variants      # Docker environments system
zzcollab --next-steps         # Development workflow
```

### Security Assessment (2025)

**Comprehensive Security Audit Results**:

- No unsafe cd commands (all use proper error handling)
- No unquoted rm operations (all file operations properly quoted)
- No unquoted test conditions (variables safely handled)
- No word splitting vulnerabilities
- Production-ready security posture with no HIGH RISK
  vulnerabilities

### Repository Cleanup (2025)

**Production Readiness**:

- Proper R package vignettes following R package standards
- Consolidated documentation with single source of truth
- Safe artifact removal using trash-put
- Enhanced .gitignore preventing future artifact accumulation
- Professional repository structure for contributors

### Critical Bug Fixes

**-i Flag Behavior (2025)**:

- Fixed incorrect continuation with full project setup
- Modified `modules/team_init.sh` to stop after team image creation
- Added clear completion messages with next steps guidance
- Two-step process: team images creation, then project setup

**Conflict Detection System (2025)**:

- Fixed array handling bugs causing "unbound variable" errors
- Enhanced conflict intelligence distinguishing true conflicts from
  safe coexistence
- Proper .github directory handling
- Comprehensive testing across all scenarios

## Troubleshooting

### Common Issues and Solutions

#### Docker Problems
```bash
# Docker not running
Error: Docker is installed but not running
Solution: Start Docker Desktop

# Permission denied
Error: Permission denied writing to directory
Solution: Check directory permissions, run as correct user

# Out of disk space
Error: No space left on device
Solution: make docker-clean, docker system prune
```

#### Package Issues
```bash
# Package installation fails
Error: Package 'xyz' not available
Solution: Check package name, try renv::install("xyz")

# Dependency conflicts
Error: Dependencies not synchronized
Solution: make docker-check-renv-fix

# renv cache issues
Error: renv cache corrupted
Solution: renv::restore(), renv::rebuild()
```

#### Team Collaboration Issues
```bash
# Team image not found
Error: Unable to pull team/project:latest
Solution: Check Docker Hub permissions, verify team member has access

# GitHub repository creation fails
Error: Repository creation failed
Solution: Check GitHub CLI authentication: gh auth login

# Environment inconsistency across team
Error: Package versions differ between team members
Solution: All team members run: git pull && docker pull team/project:latest
```

#### Build Issues
```bash
# Make targets fail
Error: make: *** [target] Error 1
Solution: Check Docker is running, try make docker-build

# Paper rendering fails
Error: Pandoc not found
Solution: Use make docker-render instead of local rendering

# Tests fail
Error: Test failures
Solution: Check function implementations, update tests
```

#### Performance Issues
```bash
# Slow Docker builds
Solution: Use .dockerignore, clean up large files, leverage team images

# RStudio slow in browser
Solution: Check available RAM, close other containers

# Large repository
Solution: Use .gitignore for data files, Git LFS for large files
```

### Team Workflow Debugging
```bash
# Check team image status
docker images | grep mylab/study2024

# Verify team environment
docker run --rm mylab/study2024:latest R --version
docker run --rm mylab/study2024:latest R -e "installed.packages()[,1]"

# Manual team image pull
docker pull mylab/study2024:latest

# Check GitHub Actions status
gh run list --workflow=update-team-image.yml
```

### Getting Help

1. **Check this guide** for common workflows
2. **Use `make help`** to see available targets
3. **Check script help**: `zzcollab --help` or `zzcollab --init --help`
4. **Validate environment**: `make docker-check-renv`
5. **Clean and rebuild**: `make docker-clean && make docker-build`
6. **Team sync**: `git pull && docker pull team/project:latest`

### Advanced Configuration

#### Custom Team Docker Environment
```bash
# Modify templates/Dockerfile.pluspackages for team needs
# Add domain-specific R packages, system tools, etc.
# Team lead rebuilds: zzcollab --init rebuilds and pushes new images
```

#### Custom Build Targets
```bash
# Add to Makefile:
my-analysis:
	docker run --rm -v $(PWD):/project $(TEAM_NAME)/$(PROJECT_NAME):latest Rscript scripts/my_analysis.R

.PHONY: my-analysis
```

#### Environment Variables for Team Setup

```bash
# Set in shell or .env file:
export DOCKERHUB_USERNAME="mylab"
export GITHUB_ACCOUNT="myuniversity"
export DOTFILES_PATH="~/dotfiles"
```

## Platform-Specific Notes

### ARM64 Compatibility (Apple Silicon)

ZZCOLLAB supports multi-platform Docker builds, but certain base
images have architecture-specific limitations.

**Architecture Support Matrix**:

```
ARM64 and AMD64 Compatible:
- rocker/r-ver     (Both architectures supported)
- rocker/rstudio   (Both architectures supported)

AMD64 Only:
- rocker/verse     (Publishing workflow with LaTeX)
- rocker/tidyverse (AMD64 only)
- rocker/geospatial (AMD64 only)
- rocker/shiny     (AMD64 only)
```

**Solutions for ARM64 Users**:

1. **Use compatible base images only**:

```bash
zzcollab -i -t TEAM -p PROJECT -B r-ver,rstudio -S
```

2. **Build custom ARM64 verse equivalent**:

```dockerfile
# Dockerfile.verse-arm64 - ARM64 compatible verse + shiny
FROM rocker/tidyverse:latest

# Install system dependencies (from official rocker
# install_verse.sh)
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
docker build -f Dockerfile.verse-arm64 \
  -t rgt47/verse-arm64:latest .

# Test locally
docker run --rm -p 8787:8787 rgt47/verse-arm64:latest

# Push to Docker Hub (free for public images)
docker login
docker push rgt47/verse-arm64:latest
```

4. **Use in zzcollab workflows**:

Modify team Dockerfile to use custom image for verse variant
conditionally based on architecture.

**Key Insights**:

- Public Docker Hub storage is provided at no cost
- rocker/verse combines rocker/tidyverse with publishing tools
  (bookdown, blogdown, LaTeX)
- rocker/rstudio does not include Shiny by default
- Custom images can combine verse and shiny functionality for
  complete publishing workflow

### Configuration Validation and Troubleshooting

**Common Configuration Issues**:

- **Missing yq dependency**: Install with `brew install yq` (macOS)
  or `snap install yq` (Ubuntu)
- **Variant build failures**: Check Docker platform compatibility
  (ARM64 vs AMD64)
- **Package installation errors**: Verify custom package lists in
  build_modes section
- **Permission issues**: Ensure proper Docker daemon access and
  directory permissions

**Validation Commands**:

```bash
# Test environment definitions
./add_environment.sh --validate

# Verify Docker platform compatibility
zzcollab --config get docker.platform
```

---

## Summary

ZZCOLLAB provides a comprehensive research collaboration platform
with the following capabilities:

- Systematic team collaboration with automated workflows
- Docker-first development eliminating local R installation
  requirements
- Automatic dependency management with renv and intelligent scanning
- Integrated collaboration tools via Git/GitHub with CI/CD
- Publication-ready workflows from analysis to manuscript
- Reproducible environments across team members
- Automated package management with systematic team image updates
- Comprehensive R interface for R-centric workflows
- Professional testing infrastructure with unit and integration tests
- Flexible initialization options with minimal (9 packages),
  standard (17 packages), or comprehensive (47+ packages) modes

### Automation Benefits

| Traditional Workflow | ZZCOLLAB Workflow |
|----------------------|-------------------|
| Manual image rebuilds | Automatic rebuilds on package changes |
| Inconsistent environments | Guaranteed environment consistency |
| 30-60 min setup per developer | 3-5 min setup with pre-built images |
| Manual dependency management | Automated dependency tracking |
| Docker expertise required | Minimal Docker knowledge needed |
| Build failures block development | Centralized, tested builds |
| Slow initialization (5-10 min) | Fast setup (2-3 min with fast mode) |

### Developer Experience

- Researchers can focus on research rather than DevOps operations
- Onboarding new team members requires minutes rather than hours
- Package management occurs transparently
- Environment drift cannot occur
- Collaboration friction is minimized

The framework manages technical complexity, enabling researchers
to focus on their work while maintaining rigorous collaboration
standards and complete reproducibility across research teams.