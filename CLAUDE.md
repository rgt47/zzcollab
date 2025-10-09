# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Critical Thinking and Technical Review

When working with the user on this codebase, prioritize technical accuracy and critical analysis:

- **Challenge assumptions**: Question design decisions, implementation approaches, and stated requirements when they may lead to suboptimal outcomes
- **Identify flaws**: Point out potential bugs, architectural issues, security concerns, or maintenance problems in proposed solutions
- **Offer alternatives**: When disagreeing with an approach, explain why and suggest better alternatives with specific technical reasoning
- **Be direct**: State clearly when something is incorrect, inefficient, or violates best practices - do not soften criticism unnecessarily
- **Focus on facts**: Base feedback on technical merits, not agreement. If the user is wrong about how something works, explain the correct behavior
- **Acknowledge good ideas**: When the user's approach is sound, say so and explain why it is effective
- **Ask clarifying questions**: When requirements are unclear or seem problematic, probe deeper before implementing

This codebase values correctness and maintainability over politeness. Prioritize helping the user build robust software through honest technical assessment.

## Architecture Overview

ZZCOLLAB is a research collaboration framework that creates Docker-based
reproducible research environments. The system consists of:

### Core Components
- **Main executable**: `zzcollab.sh` - Primary framework script (439 lines, 64% reduction from original)
- **Modular shell system**: `modules/` directory contains core functionality
- **Docker-first workflow**: All development happens in containers
- **R package structure**: Standard R package with testthat for testing
- **Template system**: `templates/` for project scaffolding
- **Profile system**: Single source of truth with 14+ Docker profiles
- **Configuration system**: Centralized constants and user configuration management

### Documentation Structure
- **Root README.md**: Quick start and overview for framework users
- **Root CLAUDE.md**: Developer/AI assistant context (this file)
- **ZZCOLLAB_USER_GUIDE.md**: Comprehensive user documentation (symlinked from templates/)
- **docs/**: Technical documentation and definitive guides
  - **BUILD_MODES.md**: Comprehensive build mode system documentation
  - **TESTING_GUIDE.md**: Complete testing framework and best practices
  - **CONFIGURATION.md**: Multi-layered configuration system guide
  - **VARIANTS.md**: Docker profile system and customization
  - **README.md**: Documentation directory index
  - Additional technical documents (improvements, architecture, motivations)

### Key Architecture Patterns
- **Modular design**: Shell scripts in `modules/` (core.sh, cli.sh, docker.sh, structure.sh, etc.)
- **Docker inheritance**: Team base images → personal development images
- **Automated CI/CD**: GitHub Actions for R package validation and image builds
- **Test-driven development**: Unit tests in `tests/testthat/`, integration tests expected
- **Environment monitoring**: Critical R options tracking with `check_rprofile_options.R`
- **Simplified CLI**: 4 clear renv modes with shortcuts (-M, -F, -S, -C)
- **Unified systems**: Single tracking, validation, and logging systems across all modules
- **Single source of truth**: Profile definitions in `bundles.yaml` eliminate duplication
- **14+ Docker profiles**: From lightweight Alpine (~200MB) to full-featured environments (~3.5GB)
- **Two-layer package management**: Docker profiles (shared/team) + renv modes (personal/independent)

### Four Pillars of Reproducibility

ZZCOLLAB ensures complete reproducibility through four version-controlled components:

1. **Dockerfile** - Computational environment foundation
   - R version (e.g., 4.4.0)
   - System dependencies (GDAL, PROJ, libcurl, etc.)
   - Base image specification (rocker/verse, bioconductor, etc.)
   - Environment variables (LANG, LC_ALL, TZ, OMP_NUM_THREADS)

2. **renv.lock** - Exact R package versions (source of truth)
   - Every package with exact version
   - Complete dependency tree
   - CRAN/Bioconductor/GitHub sources
   - Contains packages from ALL team members

3. **.Rprofile** - R session configuration (version controlled)
   - Critical R options (`stringsAsFactors`, `contrasts`, `na.action`, `digits`, `OutDec`)
   - Automatically monitored with `check_rprofile_options.R`
   - Copied into Docker image to ensure consistent R session settings
   - Changes tracked in CI/CD to prevent unintended behavior modifications

4. **Source Code** - Computational logic
   - Analysis scripts (`analysis/scripts/`)
   - Reusable functions (`R/`)
   - Reports (`analysis/paper/`)
   - Tests (`tests/testthat/`)
   - Explicit random seeds (`set.seed()`) for stochastic analyses

**Additional Reproducibility Elements**:
- **Data**: Raw data, derived data, and data acquisition/processing scripts
- **Environment variables**: Locale settings (sorting, number formatting), timezone, parallelization controls
- **Documentation**: Data dictionary (`data/README.md`), analysis workflow documentation

**Key Design Principle**: Docker images provide foundation and performance (pre-installed base packages), but `renv.lock` is the source of truth for R package reproducibility. `.Rprofile` ensures consistent R session behavior across environments. Anyone can reproduce analysis from ANY compatible Docker base by running `renv::restore()` with the committed `renv.lock` file.

## Unified Research Compendium Structure

ZZCOLLAB follows the unified research compendium framework proposed by Marwick, Boettiger, and Mullen (2018), providing a single flexible structure that supports the entire research lifecycle from data collection through analysis, manuscript writing, and package publication:

### Directory Structure

The unified compendium uses a single flexible layout based on Marwick et al. (2018):

```
project/
├── analysis/
│   ├── data/
│   │   ├── raw_data/         # Original, unmodified data (read-only)
│   │   └── derived_data/     # Processed, analysis-ready data
│   ├── paper/
│   │   ├── paper.Rmd         # Manuscript
│   │   └── references.bib    # Bibliography
│   ├── figures/              # Generated visualizations
│   └── scripts/              # Analysis code (empty - user creates)
├── R/                        # Reusable functions (add as needed)
├── tests/                    # Unit tests (add as needed)
├── .github/workflows/        # CI/CD automation
├── DESCRIPTION               # Project metadata
├── Dockerfile                # Computational environment
└── renv.lock                 # Package versions
```

### Progressive Disclosure Philosophy

**Start Simple, Add Complexity As Needed**:

1. **Data Analysis** (Day 1):
   - Place raw data in `analysis/data/raw_data/`
   - Create analysis scripts in `analysis/scripts/`
   - Generate figures in `analysis/figures/`

2. **Manuscript Writing** (Week 2):
   - Add `analysis/paper/paper.Rmd` for manuscript
   - No restructuring required - manuscript references scripts and figures

3. **Function Extraction** (Month 1):
   - Move reusable code to `R/` directory
   - Add documentation with roxygen2
   - Create tests in `tests/testthat/`

4. **Package Distribution** (Month 3):
   - Add `man/` for documentation
   - Add `vignettes/` for tutorials
   - Ready for CRAN submission without migration

**Key Principle**: Research evolves organically. No upfront paradigm choice. No migration friction.

### Usage Examples

**Command Line**:
```bash
# Create unified research compendium
zzcollab -d ~/dotfiles

# With team collaboration
zzcollab -i -t mylab -p study -B rstudio -d ~/dotfiles

# With build mode selection
zzcollab --comprehensive -d ~/dotfiles  # 51 packages - complete toolkit
zzcollab --standard -d ~/dotfiles       # 17 packages - balanced (default)
zzcollab --fast -d ~/dotfiles           # 9 packages - minimal
```

**R Interface**:
```r
library(zzcollab)

# Create unified research compendium
init_project("my-research")

# With team and build mode
init_project(
  team_name = "mylab",
  project_name = "study",
  build_mode = "standard"
)
```

### Learning Resources

**Tutorial Examples** (in zzcollab repo, not installed):
- **Step-by-step workflows**: EDA, modeling, validation, dashboards, reporting
- **Complete projects**: Full example research compendia
- **Code patterns**: Reusable patterns for common tasks

**Location**: `https://github.com/rgt47/zzcollab/tree/main/examples`

**Philosophy**: Examples teach patterns. Projects start clean (empty `scripts/` directory). Users create their own workflow rather than modifying templates.

### Unified Compendium Features

- **Flexible Structure**: Supports data analysis, manuscript writing, and package development in one layout
- **CI/CD Included**: Minimal `render-paper.yml` workflow with comprehensive documentation
- **Marwick Compatible**: Follows rrtools conventions for research compendia
- **Progressive Complexity**: Start simple, add directories as research evolves
- **Docker Integration**: Reproducible computational environment included
- **Comprehensive Guide**: `docs/UNIFIED_PARADIGM_GUIDE.md` with migration help

## Advanced Configuration System (Enhanced 2025)

ZZCOLLAB features a powerful multi-layered configuration system that controls Docker images, R packages, build modes, and team settings. This system eliminates repetitive typing while providing extensive customization for teams and individuals.

*For comprehensive configuration documentation, see [Configuration Guide](docs/CONFIGURATION.md)*

### Configuration Architecture Overview

**Multi-Level Hierarchy** (highest priority first):
1. **Project config** (`./zzcollab.yaml`) - Team-specific settings for shared projects
2. **User config** (`~/.zzcollab/config.yaml`) - Personal defaults across all projects
3. **System config** (`/etc/zzcollab/config.yaml`) - Organization-wide defaults
4. **Built-in defaults** - Fallback values ensuring system functionality

**Three Configuration Domains**:
- **Docker Profile Management** - 14+ specialized environments with custom base images and packages
- **Package Management** - Build modes (Fast/Standard/Comprehensive) with flexible package selection
- **Development Settings** - Team collaboration, GitHub integration, and automation preferences

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

### Docker Profile Configuration System

ZZCOLLAB's profile system provides 14+ specialized Docker environments with a single source of truth architecture:

*For comprehensive profile documentation, see [Profile System Guide](docs/VARIANTS.md)*

**Interactive Profile Management**:
```bash
# Browse and add profiles interactively
./add_profile.sh    # Shows categorized menu with 14+ options

# Manual profile management
vim config.yaml     # Edit team profiles (set enabled: true to build)

# Build with custom profiles
zzcollab --profiles-config config.yaml
zzcollab -i -t TEAM -p PROJECT --profiles-config config.yaml
```

**Profile Categories Available**:
- **Standard Research** (6 profiles): minimal (~800MB), analysis (~1.2GB), modeling (~1.5GB), publishing (~3GB), shiny (~1.8GB), shiny_verse (~3.5GB)
- **Specialized Domains** (2 profiles): bioinformatics (~2GB), geospatial (~2.5GB)
- **Lightweight Alpine** (3 profiles): alpine_minimal (~200MB), alpine_analysis (~400MB), hpc_alpine (~600MB)
- **R-Hub Testing** (3 profiles): rhub_ubuntu (~1GB), rhub_fedora (~1.2GB), rhub_windows (~1.5GB)

**Single Source of Truth**:
- **Master Library**: `templates/profiles.yaml` contains all profile definitions
- **Team Configuration**: `templates/config.yaml`
- **No Duplication**: Teams reference profiles by name, full definitions pulled automatically

### Package Management System

*For comprehensive build mode documentation, see [Build Modes Guide](docs/BUILD_MODES.md)*

**Build Mode Package Control**:
- **Minimal Mode (-M)**: Ultra-fast bare essentials (3 packages, ~30 seconds)
  - Core: renv, remotes, here
- **Fast Mode (-F)**: Development essentials (9 packages, 2-3 minutes)
  - Core: renv, remotes, here, usethis, devtools, testthat, knitr, rmarkdown, targets
- **Standard Mode (-S)**: Balanced package set for most workflows (17 packages, 4-6 minutes, default)
  - Fast packages + tidyverse core: dplyr, ggplot2, tidyr, palmerpenguins, broom, janitor, DT, conflicted
- **Comprehensive Mode (-C)**: Full ecosystem for extensive environments (47+ packages, 15-20 minutes)
  - Standard packages + advanced tools: tidymodels, shiny, plotly, quarto, flexdashboard, survival, lme4, databases

**Custom Package Lists** (in configuration files):
```yaml
build_modes:
  fast:
    description: "Quick development setup"
    docker_packages: [renv, remotes, here, usethis]
    renv_packages: [renv, here, usethis, devtools, testthat]

  custom_analysis:
    description: "Custom data science workflow"
    docker_packages: [renv, tidyverse, targets, pins]
    renv_packages: [renv, tidyverse, targets, pins, vetiver, plumber]
```

### Configuration Files

**File Hierarchy**:
- **User config**: `~/.zzcollab/config.yaml` (personal defaults across all projects)
- **Project config**: `./zzcollab.yaml` (team-specific settings for shared projects)
- **System config**: `/etc/zzcollab/config.yaml` (organization-wide defaults)
- **Built-in defaults**: Fallback values ensuring system functionality

### Comprehensive Configuration Examples

**User Configuration** (`~/.zzcollab/config.yaml`):
```yaml
defaults:
  # Personal development preferences
  team_name: "myteam"                  # Default team for new projects
  github_account: "myusername"         # GitHub account name
  build_mode: "standard"               # Preferred build mode: fast, standard, comprehensive
  dotfiles_dir: "~/dotfiles"           # Path to dotfiles directory
  dotfiles_nodot: false                # Whether dotfiles need dots added

  # Automation preferences
  auto_github: false                   # Automatically create GitHub repositories
  skip_confirmation: false             # Skip confirmation prompts

# Custom package lists for build modes (optional)
build_modes:
  fast:
    description: "Quick development setup"
    docker_packages: [renv, remotes, here, usethis]
    renv_packages: [renv, here, usethis, devtools, testthat]

  custom_analysis:
    description: "Personal data science workflow"
    docker_packages: [renv, tidyverse, targets, pins]
    renv_packages: [renv, tidyverse, targets, pins, vetiver, plumber, shiny]
```

**Team Project Configuration** (`./zzcollab.yaml`):
```yaml
#=============================================================================
# TEAM METADATA
#=============================================================================
team:
  name: "datasci-lab"
  project: "customer-churn-analysis"
  description: "Machine learning analysis of customer retention patterns"
  maintainer: "Dr. Smith <smith@university.edu>"

#=============================================================================
# DOCKER PROFILES CONFIGURATION
#=============================================================================
profiles:
  # Essential development environment
  minimal:
    enabled: true    # ~800MB - Essential R packages only

  # Primary analysis environment
  analysis:
    enabled: true    # ~1.2GB - Tidyverse + data analysis tools

  # Machine learning environment
  modeling:
    enabled: true    # ~1.5GB - ML packages (tidymodels, xgboost, etc.)

  # Lightweight CI/CD environment
  alpine_minimal:
    enabled: true    # ~200MB - Ultra-lightweight for testing

  # Advanced environments (disabled by default)
  publishing:
    enabled: false   # ~3GB - LaTeX, Quarto, bookdown
  geospatial:
    enabled: false   # ~2.5GB - sf, terra, leaflet mapping
  bioinformatics:
    enabled: false   # ~2GB - Bioconductor packages

#=============================================================================
# BUILD CONFIGURATION
#=============================================================================
build:
  # Use profiles defined in this config file
  use_config_profiles: true
  profile_library: "profiles.yaml"

  # Docker build settings
  docker:
    platform: "auto"              # auto, linux/amd64, linux/arm64
    no_cache: false
    parallel_builds: true

  # Package installation settings
  packages:
    repos: "https://cran.rstudio.com/"
    install_suggests: false
    dependencies: ["Depends", "Imports", "LinkingTo"]

#=============================================================================
# TEAM COLLABORATION SETTINGS
#=============================================================================
collaboration:
  # GitHub integration
  github:
    auto_create_repo: false
    default_visibility: "private"
    enable_actions: true

  # Development environment defaults
  development:
    default_interface: "analysis"     # Which profile team members use by default
    container:
      default_user: "analyst"
      working_dir: "/home/analyst/project"
```

### Configuration Workflows

**Solo Developer Setup**:
```bash
# 1. Initialize personal configuration
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"

# 2. Create projects using defaults
zzcollab -i -p data-analysis    # Uses config defaults automatically

# 3. Customize profiles for specific projects
cd data-analysis
./add_profile.sh               # Browse and add specialized environments
```

**Team Leader Setup**:
```bash
# 1. Create team configuration
mkdir team-project && cd team-project
zzcollab -i -p team-project    # Creates base config.yaml

# 2. Customize team profiles
./add_profile.sh               # Add modeling, alpine_minimal for CI/CD
vim config.yaml                # Adjust collaboration settings

# 3. Build and share team images
zzcollab --profiles-config config.yaml --github
```

**Team Member Joining**:
```bash
# 1. Clone team project
git clone https://github.com/team/team-project.git
cd team-project

# 2. Join with appropriate interface
zzcollab -t team -p team-project -I analysis    # Uses team's analysis profile
make docker-zsh                                 # Start development environment
```

**Advanced Custom Variants**:
```bash
# 1. Copy and modify existing profile
cp templates/profiles.yaml custom_profiles.yaml
vim custom_profiles.yaml       # Add profiles with specific packages

# 2. Reference custom library
vim config.yaml                # Set profile_library: "custom_profiles.yaml"

# 3. Build custom environments
zzcollab --profiles-config config.yaml
```

### Configuration Validation and Troubleshooting

**Validation Commands**:
```bash
# Check configuration syntax and values
zzcollab --config validate

# Debug configuration loading
zzcollab --config list         # Shows effective configuration values

# Test profile definitions
./add_profile.sh --validate    # Check profiles.yaml syntax

# Verify Docker platform compatibility
zzcollab --config get docker.platform
```

**Common Configuration Issues**:
- **Missing yq dependency**: Install with `brew install yq` (macOS) or `snap install yq` (Ubuntu)
- **Profile build failures**: Check Docker platform compatibility (ARM64 vs AMD64)
- **Package installation errors**: Verify custom package lists in build_modes section
- **Permission issues**: Ensure proper Docker daemon access and directory permissions

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
join_project(project_name = "my-analysis")   # Uses team_name, build_mode from config
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
├── correspondence/     # Email communications, data transfer notes
└── README.md          # Comprehensive data documentation
```

**Template Features**:
- **Complete data dictionary**: Column descriptions, types, valid ranges, missing value codes
- **Processing documentation**: Links derived files to their creating scripts
- **Quality notes**: Known issues, validation checks, reproducibility instructions
- **Palmer Penguins example**: Ready-to-customize template with realistic data scenario

### Comprehensive Data Workflow Guide (Enhanced)

ZZCOLLAB includes a detailed **`DATA_WORKFLOW_GUIDE.md`** that provides step-by-step guidance for data management throughout the research lifecycle. The guide is automatically installed with all new projects via the enhanced template system.

**6-Phase Workflow Process**:
1. **Data Receipt & Initial Setup** (HOST) - File placement, initial documentation, data source recording
2. **Data Exploration & Validation** (CONTAINER) - Quality assessment, diagnostic plots, missing data analysis
3. **Data Preparation Development** (CONTAINER) - Function development, processing scripts, transformation logic
4. **Unit Testing & Validation** (CONTAINER) - Comprehensive test coverage, edge case testing
5. **Integration Testing & Documentation** (HOST/CONTAINER) - Pipeline validation, full workflow testing
6. **Final Validation & Deployment** (HOST/CONTAINER) - Production readiness, reproducibility verification

**Enhanced Key Features**:
- **Scientific rationale**: Comprehensive explanation of why data testing prevents research integrity issues
- **HOST vs CONTAINER operations**: Clear visual separation with and indicators for environment context
- **Documentation structure**: Complete guidance on structured data documentation with 13 specific sections
- **Palmer Penguins examples**: Working code examples throughout all 6 phases
- **Template integration**: Automatically installed via `create_data_templates()` in `modules/structure.sh`
- **Testing framework**: Unit tests (6,689 lines), integration tests, helper functions, data file validation
- **Quality assurance**: >90% test coverage requirements with specific validation checks
- **Container workflow**: Clear guidance on when to exit/enter containers for different operations

### Example Data Workflow Documentation

The guide includes practical Palmer Penguins examples for all phases:

```r
# Actual Palmer Penguins data preparation function
prepare_penguin_data <- function(data, n_records = 50) {
  # Input validation for Palmer Penguins
  required_cols <- c("species", "island", "bill_length_mm", "bill_depth_mm", 
                     "flipper_length_mm", "body_mass_g", "sex", "year")
  
  # Processing with log transformation
  result <- data %>%
    slice_head(n = n_records) %>%                    # First n records
    filter(!is.na(body_mass_g)) %>%                  # Remove missing body mass
    mutate(log_body_mass_g = log(body_mass_g)) %>%   # Add log transformation
    mutate(species = as.factor(species))             # Ensure factors
    
  return(result)
}
```

### Benefits for Reproducible Research

**Key benefits for reproducible research:**

- **Standardized documentation**: All projects follow consistent data documentation patterns with 13 structured sections
- **Traceability**: Clear links between raw data, processing scripts, and derived datasets with explicit file references
- **Quality assurance**: Built-in data validation and quality check documentation with specific Palmer Penguins examples
- **Research standards compliance**: Follows academic standards for data management with scientific integrity emphasis
- **Collaboration support**: Team members can immediately understand data structure and processing through comprehensive READMEs
- **Testing framework**: Comprehensive validation prevents silent data quality issues with >90% coverage requirements
- **Docker workflow integration**: Proper separation of host file management and container analysis with clear operational guidance
- **Template automation**: Both `data/README.md` and `DATA_WORKFLOW_GUIDE.md` automatically installed via `create_data_templates()`
- **Enhanced documentation**: Includes scientific rationale, troubleshooting guidance, and complete command references

The enhanced data workflow system provides a complete framework for scientific data processing from receipt to deployment. Both templates are automatically created during project initialization and integrated into the uninstall process for complete lifecycle management. The comprehensive workflow guide ensures systematic, tested data processing that meets scientific reproducibility standards with professional-grade testing and documentation practices.

## Docker Profile System (Enhanced 2025)

ZZCOLLAB now supports **14+ specialized Docker profiles** with a single source of truth architecture that eliminates duplication and provides unlimited customization options.

### Profile Library Overview

**Standard Research Environments (6 profiles)**
- **minimal** (~800MB) - Essential R packages only  
- **analysis** (~1.2GB) - Tidyverse + data analysis tools
- **modeling** (~1.5GB) - Machine learning with tidymodels
- **publishing** (~3GB) - LaTeX, Quarto, bookdown, blogdown
- **shiny** (~1.8GB) - Interactive web applications
- **shiny_verse** (~3.5GB) - Shiny with tidyverse + publishing

**Specialized Domains (2 profiles)**
- **bioinformatics** (~2GB) - Bioconductor genomics packages
- **geospatial** (~2.5GB) - sf, terra, leaflet mapping tools

**Lightweight Alpine Variants (3 profiles)**  
- **alpine_minimal** (~200MB) - Ultra-lightweight for CI/CD
- **alpine_analysis** (~400MB) - Essential analysis in tiny container
- **hpc_alpine** (~600MB) - High-performance parallel processing

**R-Hub Testing Environments (3 profiles)**
- **rhub_ubuntu** (~1GB) - CRAN-compatible package testing
- **rhub_fedora** (~1.2GB) - Test against R-devel
- **rhub_windows** (~1.5GB) - Windows compatibility testing

### Single Source of Truth Architecture

All profile definitions are centralized in `profiles.yaml` with team configurations referencing them:

**Master Library**: `templates/profiles.yaml`
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
profiles:
  minimal:
    enabled: true    # Essential development environment (~800MB)
    # Full definition in profiles.yaml
  
  modeling:
    enabled: false   # Machine learning environment (~1.5GB)  
    # Full definition in profiles.yaml

build:
  use_config_profiles: true
  profile_library: "profiles.yaml"
```

### Interactive Profile Management

**Browse and Add Variants**:
```bash
# Interactive profile browser with 14 options
./add_profile.sh

# Displays categorized menu:
# STANDARD RESEARCH ENVIRONMENTS
#  1) minimal          ~800MB  - Essential R packages
#  2) analysis         ~1.2GB  - Tidyverse + data analysis  
#  3) modeling         ~1.5GB  - Machine learning with tidymodels
#  4) publishing       ~3GB    - LaTeX, Quarto, bookdown
#  5) shiny            ~1.8GB  - Interactive web applications
#  6) shiny_verse      ~3.5GB  - Shiny with tidyverse + publishing

# Select profiles and they are automatically added to config.yaml
```

### Modern Workflow Commands

**Team Initialization**:
```bash
# Quick start - creates optimal default profiles
zzcollab -i -p myproject --github              # Creates: minimal + analysis profiles

# Custom profiles via config file
zzcollab -i -p myproject             # Creates project + config.yaml
./add_profile.sh                     # Browse and select profiles
zzcollab --profiles-config config.yaml --github  # Build selected profiles

# Legacy approach (limited to 3 profiles)
zzcollab -i -p myproject -B rstudio --github     # Traditional RStudio only
```

**Solo Developer Workflow**:
```bash
# Configuration-based (recommended)
zzcollab --config set team-name "myteam"
zzcollab -i -p research-paper        # Uses config defaults

# Traditional explicit
zzcollab -i -t myteam -p analysis-project -B rstudio -d ~/dotfiles
```

### Benefits of New Profile System

- **Eliminates duplication** - Single source of truth in `profiles.yaml`
- **14+ specialized environments** - From 200MB Alpine to 3.5GB full-featured
- **Domain-specific profiles** - Bioinformatics, geospatial, HPC, web apps
- **Professional testing** - R-hub environments match CRAN infrastructure
- **Lightweight options** - Alpine profiles 5x smaller than standard images
- **Interactive discovery** - Browse profiles with `./add_profile.sh`
- **Backward compatibility** - Legacy full definitions still supported
- **Easy maintenance** - Update profile in one place, propagates everywhere

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
# Quick start - optimal profiles automatically
zzcollab -i -p penguin-analysis --github

# Power users - browse 14+ profiles interactively
mkdir penguin-analysis && cd penguin-analysis
zzcollab -i -p penguin-analysis
./add_profile.sh    # Select from bioinformatics, geospatial, alpine, etc.
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

- **Reproducible**: Identical environment every development session
- **Professional**: Automated testing, validation, CI/CD
- **Flexible**: 14+ profiles for different research domains
- **Lightweight**: Alpine profiles ~200MB vs standard ~1GB+
- **Team-ready**: Easy transition to collaboration later
- **Container-based**: No conflicts with host system R

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

*For comprehensive testing documentation, see [Testing Guide](docs/TESTING_GUIDE.md)*

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
Rscript validate_package_environment.R --quiet --fail-on-issues  # Dependency validation
Rscript validate_package_environment.R --build-mode fast --quiet --fail-on-issues  # Fast mode validation
ZZCOLLAB_BUILD_MODE=comprehensive Rscript validate_package_environment.R --fix --fail-on-issues  # Environment variable
Rscript check_rprofile_options.R                          # R options monitoring

# Container-based CI commands (used in GitHub Actions)
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript validate_package_environment.R --quiet --fail-on-issues
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

### Profile Management (New)
```bash
# Interactive profile discovery and addition
./add_profile.sh           # Browse and add profiles from comprehensive library

# Manual profile management
./profiles.yaml    # View all available profile definitions
vim config.yaml            # Edit team profiles (set enabled: true to build)

# Build custom profiles
zzcollab --profiles-config config.yaml              # Build enabled profiles
zzcollab -i -t TEAM -p PROJECT --profiles-config config.yaml  # Team init with custom profiles

# Default behavior (uses config.yaml automatically if use_config_profiles: true)
zzcollab -i -p PROJECT     # Builds default profiles (minimal + analysis)
```

### Dependency Management
```bash
make check-renv            # Check renv status
make check-renv-fix        # Update renv.lock
make docker-check-renv     # Validate in container
Rscript validate_package_environment.R --quiet --fail-on-issues  # CI validation
Rscript validate_package_environment.R --fix --fail-on-issues    # Auto-fix missing packages
Rscript validate_package_environment.R --build-mode fast --fix   # Build mode aware validation
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
zzcollab -i -t TEAM -p PROJECT -B all -S -d ~/dotfiles        # All 3 profiles (traditional)

# Skip confirmation prompt for automation/CI:
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -y -d ~/dotfiles # No confirmation prompt

# Combine selective building with build modes:
zzcollab -i -t TEAM -p PROJECT -B rstudio -F -d ~/dotfiles    # RStudio with minimal packages (8)
zzcollab -i -t TEAM -p PROJECT -B all -C -d ~/dotfiles        # All profiles with full packages (27+)

# Incremental approach - start small, add profiles later:
zzcollab -i -t TEAM -p PROJECT -B r-ver -S -d ~/dotfiles      # Start with shell only
# Later, add more profiles as needed:
zzcollab -V rstudio                                            # Add profile
zzcollab -V verse                                              # Add profile for publishing

# Environment variable support for build mode detection
ZZCOLLAB_BUILD_MODE=fast zzcollab -i -t TEAM -p PROJECT -B r-ver -d ~/dotfiles

# GitHub repository creation shortcuts
zzcollab -d ~/dotfiles -G                                     # Basic setup with automatic GitHub repo creation
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -G -d ~/dotfiles # Team setup with automatic GitHub repo

# Legacy: Traditional approach (builds all profiles)
# zzcollab -i -t TEAM -p PROJECT -F -d ~/dotfiles              # Fast mode, all profiles
# zzcollab -i -t TEAM -p PROJECT -C -d ~/dotfiles              # Comprehensive mode, all profiles


# Manual core image building (if needed)
cd /path/to/zzcollab
cp templates/Dockerfile.unified ./Dockerfile.teamcore

# Build shell profile
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/r-ver \
    --build-arg TEAM_NAME="TEAM" \
    --build-arg PROJECT_NAME="PROJECT" \
    --build-arg PACKAGE_MODE="standard" \
    -t "TEAM/PROJECTcore-shell:v1.0.0" .

# Build RStudio profile
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/rstudio \
    --build-arg TEAM_NAME="TEAM" \
    --build-arg PROJECT_NAME="PROJECT" \
    --build-arg PACKAGE_MODE="standard" \
    -t "TEAM/PROJECTcore-rstudio:v1.0.0" .

# Build verse profile (publishing workflow)
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
zzcollab -i -t TEAM -p PROJECT -B all -C -d ~/dotfiles        # Creates all profiles (shell, rstudio, verse)

# Step 2: Create full project structure (run separately)
mkdir PROJECT && cd PROJECT  # or git clone if repo exists
zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles            # Full project setup with shell interface

# Add profiles later (incremental workflow)
zzcollab -V rstudio                                            # Add profile
zzcollab -V verse                                              # Add profile

# Developer 2+ (Team Members) - Join Existing Project
git clone https://github.com/TEAM/PROJECT.git                 # Clone existing project
cd PROJECT
# Choose available interface:
zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles             # Command-line development
zzcollab -t TEAM -p PROJECT -I rstudio -d ~/dotfiles           # RStudio Server (if profile available)
zzcollab -t TEAM -p PROJECT -I verse -d ~/dotfiles             # Publishing workflow (if profile available)

# Error handling: If team image profile not available, you'll get helpful guidance:
# Error: Team image 'TEAM/PROJECTcore-rstudio:latest' not found
# Available profiles for this project:
#     - TEAM/PROJECTcore-shell:latest
# Solutions:
#    1. Use available profile: zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles
#    2. Ask team lead to build rstudio profile: zzcollab -V rstudio

# Note: Build modes comparison:
# Minimal (-M): Ultra-fast bare essentials (~30 seconds, 3 packages)
#   → renv, remotes, here
# Fast (-F): Development essentials (2-3 minutes, 9 packages)
#   → renv, remotes, here, usethis, devtools, testthat, knitr, rmarkdown, targets
# Standard (-S): Balanced Docker + standard packages (4-6 minutes, 17 packages, default)
#   → + dplyr, ggplot2, tidyr, palmerpenguins, broom, janitor, DT, conflicted
# Comprehensive (-C): Extended Docker + full packages (15-20 minutes, 47 packages)
#   → + tidymodels, shiny, plotly, quarto, flexdashboard, survival, lme4, databases
```

### Simplified Build Modes (NEW)

ZZCOLLAB now uses a simplified 4-mode system that replaces the previous complex flag combinations. This provides clear, intuitive choices for users:

#### Build Modes:
- **Minimal (-M)**: Ultra-fast bare essentials (3 packages, ~30 seconds)
  - Core: renv, remotes, here
- **Fast (-F)**: Development essentials (9 packages, 2-3 minutes)
  - Core: renv, remotes, here, usethis, devtools
  - Analysis: testthat, knitr, rmarkdown, targets
- **Standard (-S)**: Balanced package set for most workflows (17 packages, 4-6 minutes, default)
  - Fast packages + tidyverse core: dplyr, ggplot2, tidyr
  - Research tools: palmerpenguins, broom, janitor, DT, conflicted
- **Comprehensive (-C)**: Full ecosystem for extensive environments (47 packages, 15-20 minutes)
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
- **Simplified CLI**: 4 clear build modes (-M, -F, -S, -C) replace 8+ complex flags
- **Comprehensive shortcuts**: All major flags now have single-letter shortcuts
- **Better error messages**: Clear, actionable error messages with helpful guidance
- **Backward compatibility**: Legacy flags still work with deprecation warnings

### Technical Improvements:
- **Unified tracking**: Single `track_item()` function replaces 6 duplicates
- **Unified validation**: Standardized validation patterns across modules
- **Clean dependencies**: Proper module loading order and dependency management
- **Consistent patterns**: Standardized error handling and logging throughout

## Recent Enhancements (2025)

### Unified Paradigm Consolidation (October 2025) - Latest
**Major architectural transformation**: Successfully consolidated from three-paradigm system (analysis/manuscript/package) to unified research compendium framework based on Marwick et al. (2018).

**Consolidation Complete** (100% - Production Ready):
- **Core system**: Removed paradigm from 6 shell modules, created unified templates
- **Documentation**: Updated 5 major files (README, CONFIGURATION, vignettes, CLAUDE.md, USER_GUIDE)
- **References removed**: 108 paradigm references across entire codebase
- **Vignettes**: Deprecated 9 paradigm-specific vignettes (421K) with comprehensive migration guide
- **Testing**: 0 breaking changes, 34/34 R package tests passing

**Key Benefits**:
- **One structure** for entire research lifecycle (data → analysis → paper → package)
- **No upfront decisions** - start simple, add complexity as research evolves
- **Progressive disclosure** - research evolves organically without migration
- **Marwick/rrtools compatible** - follows research compendium best practices
- **Simplified package selection** - 4 build modes instead of 3 paradigms × 3 modes

**Unified Directory Structure**:
```
project/
├── analysis/
│   ├── data/
│   │   ├── raw_data/         # Original data (read-only)
│   │   └── derived_data/     # Processed data
│   ├── paper/
│   │   ├── paper.Rmd         # Manuscript (add when ready)
│   │   └── references.bib
│   ├── figures/              # Generated visualizations
│   └── scripts/              # Analysis code (user creates)
├── R/                        # Functions (add as needed)
├── tests/                    # Unit tests (add as needed)
├── Dockerfile                # Computational environment
└── renv.lock                 # Package versions
```

**Four-Stage Evolution**:
1. **Data Analysis** (Day 1): Create `analysis/scripts/` for analysis
2. **Manuscript Writing** (Week 2): Add `analysis/paper/paper.Rmd`
3. **Function Extraction** (Month 1): Move reusable code to `R/`
4. **Package Distribution** (Month 3): Add `man/`, `vignettes/`

**Documentation**:
- `docs/CONSOLIDATION_FINAL_SUMMARY.md` - Comprehensive consolidation summary
- `docs/UNIFIED_PARADIGM_GUIDE.md` - Complete unified paradigm guide
- `vignettes/deprecated/README.md` - Migration guide from three-paradigm system

**System Version**: zzcollab 2.0 (unified paradigm)

### Docker Profile System Refactoring (September 2025)
Major architectural improvement implementing single source of truth for profile management:

**Key Changes:**
- **Eliminated duplication**: Profile definitions centralized in `profiles.yaml`
- **14+ profiles available**: Added shiny, shiny_verse, and comprehensive specialized options
- **Interactive profile browser**: `./add_profile.sh` with categorized 14-option menu
- **Single source of truth**: Team configs reference central library instead of duplicating
- **Backward compatibility**: Legacy full profile definitions still supported
- **Verified system libraries**: Fixed missing dependencies across all profiles

**Technical Implementation:**
- **Simplified config.yaml**: Reduced from 455 to 154 lines (66% reduction) 
- **Enhanced add_profile.sh**: Generates lightweight YAML entries with library references
- **Updated team_init.sh**: Dynamic profile loading during build process
- **Comprehensive testing**: Validated new format, legacy compatibility, and integration

### Selective Base Image Building System
Major improvement to team initialization workflow with selective base image building:

**New Features:**
- **Selective building**: Teams can build only needed profiles (r-ver, rstudio, verse) instead of all
- **Incremental workflow**: Start with one profile, add others later with `-V` flag  
- **Enhanced error handling**: Helpful guidance when team members request unavailable profiles
- **Short flags**: All major options now have one-letter shortcuts (-i, -t, -p, -I, -B, -V)
- **Verse support**: Publishing workflow with LaTeX support via rocker/verse
- **Team communication**: Clear coordination between team leads and members about available tooling

**CLI Improvements:**
```bash
# New selective base image flags
-B, --init-base-image TYPE   # r-ver, rstudio, verse, all (for team initialization)
-V, -V TYPE     # r-ver, rstudio, verse (for adding profiles later)
-I, --interface TYPE         # shell, rstudio, verse (for team members joining)

# Examples
zzcollab -i -t mylab -p study -B rstudio -S -d ~/dotfiles    # RStudio only
zzcollab -V verse                                             # Add profile later
zzcollab -t mylab -p study -I shell -d ~/dotfiles           # Join with shell interface
```

**Error Handling Enhancements:**
- **Image availability checking**: Validates team images exist before proceeding
- **Helpful error messages**: Shows available profiles and provides solutions
- **Team coordination**: Guides team members on how to request missing profiles
- **Docker Hub integration**: Checks image availability via `docker manifest inspect`

### Revolutionary Docker Profile Management System
Complete transformation from fixed 3-profile system to unlimited custom environments:

**Unlimited Custom Variants:**
- **YAML-based configuration**: Define any number of Docker profiles with custom base images and R packages
- **Comprehensive profile library**: 12+ predefined profiles (standard, Alpine, R-hub, specialized domains)
- **Interactive profile manager**: `add_profile.sh` script for easy discovery and addition of profiles
- **Profile examples library**: `profiles.yaml` with complete definitions organized by category

**New Configuration Architecture:**
```yaml
# Team-level config.yaml supports unlimited profiles
profiles:
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

**Profile Categories Available:**
- **Standard**: minimal, analysis, modeling, publishing (rocker-based, ~800MB-3GB)
- **Specialized**: bioinformatics, geospatial (domain-specific, ~2-2.5GB)
- **Alpine**: ultra-lightweight profiles for CI/CD (~200-600MB)
- **R-hub**: CRAN-compatible testing environments (Ubuntu, Fedora, Windows)

**Interactive Profile Management:**
```bash
# Discover and add profiles interactively
./add_profile.sh

# Menu shows categorized profiles with size estimates:
# LIGHTWEIGHT ALPINE VARIANTS
#  7) alpine_minimal       ~200MB  - Ultra-lightweight CI/CD
#  8) alpine_analysis      ~400MB  - Lightweight data analysis
# R-HUB TESTING ENVIRONMENTS  
# 10) rhub_ubuntu          ~1GB    - CRAN-compatible testing

# Automatically copies YAML to config.yaml with enabled: true
```

**Two-Level Configuration System:**
- **User config** (`~/.zzcollab/config.yaml`): Personal preferences and profile library
- **Team config** (project's `config.yaml`): Which profiles actually get built as Docker images

**Legacy vs Modern System:**
```bash
# Legacy approach (overrides config.yaml)
zzcollab -i -p png1 -B r-ver        # Creates: png1core-shell:latest only

# Modern approach (uses config.yaml)  
zzcollab -i -p png1                  # Creates: minimal + analysis profiles (default)
zzcollab -i -p png1 --profiles-config config.yaml  # Explicit config usage
```

**Key Innovation**: Teams can now create specialized environments (bioinformatics with Bioconductor, geospatial with sf/terra, HPC with parallel processing, CI/CD with Alpine Linux) instead of being limited to generic r-ver/rstudio/verse profiles.

### Enhanced validate_package_environment.R Script (formerly check_renv_for_commit.R)
The dependency validation script has been significantly improved and renamed to better reflect its comprehensive functionality:

**New Features:**
- **Multi-repository validation**: CRAN, Bioconductor, and GitHub package detection
- **Build mode integration**: Adapts validation rules based on zzcollab build modes
- **Enhanced package extraction**: Handles wrapped calls, conditional loading, roxygen imports
- **Robust error handling**: Structured exit codes (0=success, 1=critical issues, 2=config error)
- **Backup/restore**: Automatic renv.lock rollback on snapshot failure
- **zzcollab integration**: Uses zzcollab logging and respects system configuration
- **Base package filtering**: Automatically excludes R base packages from CRAN validation
- **Network resilience**: Graceful handling of CRAN API failures

**Usage Examples:**
```bash
# Build mode aware validation
Rscript validate_package_environment.R --build-mode fast --fix --fail-on-issues

# Environment variable detection
ZZCOLLAB_BUILD_MODE=comprehensive Rscript validate_package_environment.R --fix

# Enhanced edge case handling for complex package patterns
Rscript validate_package_environment.R --strict-imports --fix --fail-on-issues
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
- **14+ profile showcase**: Interactive profile selection with use case recommendations
- **Container-based development**: Clear enter-container → work → exit-container → commit patterns
- **R package integration**: Proper vignette structure with executable code examples

### R Package Integration (25 Functions)
Complete R interface for CLI functionality with build mode support:
```r
# Team Lead with build modes
init_project(team_name = "mylab", project_name = "study", build_mode = "fast")
init_project(team_name = "mylab", project_name = "paper", build_mode = "standard")

# Team Member with build modes
join_project(team_name = "mylab", project_name = "study", build_mode = "comprehensive")

# Full R workflow support
add_package("tidyverse")
git_commit("Add analysis")
create_pr("New feature")

# Comprehensive help system from R
zzcollab_help()                    # Main help
zzcollab_help("quickstart")        # Quick start guide
zzcollab_help("workflow")          # Daily workflow
zzcollab_help("troubleshooting")   # Common issues
zzcollab_help("config")            # Configuration guide
zzcollab_help("dotfiles")          # Dotfiles setup
zzcollab_help("renv")              # Package management
zzcollab_help("build-modes")       # Build mode selection
zzcollab_help("docker")            # Docker essentials
zzcollab_help("cicd")              # CI/CD and GitHub Actions
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
init_project(project_name = "PROJECT")             # Uses config defaults (team, mode)

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
- **Faster builds**: r-ver (shell-only) builds significantly faster than all profiles
- **Resource efficiency**: Teams often do not need all 3 profiles (shell, rstudio, verse)
- **Selective approach**: Users can explicitly request additional profiles when needed
- **Backward compatibility**: `-B all` still available for teams that want all profiles

**Implementation**:
- `modules/constants.sh:64`: `ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE="r-ver"`
- `modules/help.sh`: Updated help text to reflect new default
- Documentation updated with clarifying comments for examples without explicit `-B`

**Impact**:
```bash
# Old behavior (built all 3 profiles by default):
zzcollab -i -t mylab -p study    # Built shell + rstudio + verse

# New behavior (builds shell-only by default):
zzcollab -i -t mylab -p study    # Builds shell only (faster)
zzcollab -i -t mylab -p study -B all  # Explicit flag for all profiles
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
ARM64 Compatible:
- rocker/r-ver     (Both AMD64 and ARM64)
- rocker/rstudio   (Both AMD64 and ARM64)

AMD64 Only:
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
   # Modify team Dockerfile to use custom image for verse profile
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

## Recent Work Completed (October 2025)

### Profile System Configuration Enhancement (October 2025)
**Renamed build-mode to renv-mode and added Docker profile configuration** - eliminated terminology confusion:

**Issue Identified:**
- Users confused "build-mode" (renv package management) with Docker profiles (Docker environment)
- Configuration system lacked support for Docker profile defaults

**Changes Implemented:**
1. **Renamed build-mode → renv-mode** throughout entire codebase:
   - `modules/config.sh`: All variable names, function names, YAML keys
   - `modules/cli.sh`: Variable names, comments, validation messages
   - `modules/help.sh`: All references in documentation
   - `vignettes/*.Rmd`: All usage examples

2. **Added Docker profile configuration variables**:
   ```yaml
   defaults:
     renv_mode: "standard"     # Renv package management (personal)
     profile_name: ""          # Docker profile (team/shared)
     libs_bundle: ""           # System library bundle
     pkgs_bundle: ""           # R package bundle
   ```

3. **Updated configuration system functions**:
   - `load_config_file()`: Loads profile_name, libs_bundle, pkgs_bundle
   - `apply_config_defaults()`: Applies profile defaults to CLI variables
   - `get_config_value()`: Returns profile configuration values
   - `config_set()`: Supports setting profile_name, libs-bundle, pkgs-bundle
   - `config_list()`: Displays all profile configuration values

4. **Updated default config template**:
   - Added profile settings section with clear comments
   - Separated renv (personal) from Docker profile (team/shared)

**Key Distinction:**
- **renv-mode**: Controls R packages in renv.lock (personal choice, independent)
- **profile-name**: Controls Docker base image and pre-installed packages (team/shared)

**Files Modified:**
- `modules/config.sh`: Complete renv-mode rename + profile config variables
- `modules/cli.sh`: RENV_MODE variable names and validation
- `modules/help.sh`: Documentation updates
- `vignettes/quickstart.Rmd`: Usage examples and config section
- `vignettes/reusable-team-images.Rmd`: All command examples
- `PROFILE_SYSTEM_IMPLEMENTATION.md`: Configuration status update

**User Benefits:**
- Clear terminology eliminates confusion between renv and Docker
- Config system supports full profile customization
- Solo developers can set Docker profile defaults
- Team members can configure preferred profile variants

### Minimal Build Mode Fix (October 2025)
**Complete restoration of -M flag functionality** - fixed validation and package definition issues:

**Issues Resolved:**
1. **CLI Validation Error**: `-M` flag was documented but failed validation with "Unknown option '-M'" error
   - Root cause: `modules/cli.sh:556` excluded "minimal" from valid build modes
   - Fix: Added "minimal" to validation condition and error message

2. **Package Definition Error**: After validation fix, got "Unknown build mode: minimal" from config.sh
   - Root cause: Two functions missing minimal case:
     - `get_docker_packages_for_mode()` (modules/config.sh:746)
     - `get_renv_packages_for_mode()` (modules/config.sh:795)
   - Fix: Added minimal cases returning "renv,remotes,here" (3 packages)

3. **Profile Library Missing**: Config-based profiles failed with "Profile library not found: profiles.yaml"
   - Root cause: `profiles.yaml` not copied to project directory during team initialization
   - Fix: Copy profile library from templates after creating config.yaml (modules/team_init.sh:232-237)

**Complete Build Mode System (4 modes):**
- **Minimal (-M)**: 3 packages (renv, remotes, here) ~30 seconds
- **Fast (-F)**: 9 packages (development essentials) 2-3 minutes
- **Standard (-S)**: 17 packages (balanced) 4-6 minutes [default]
- **Comprehensive (-C)**: 47+ packages (full ecosystem) 15-20 minutes

**Verification:**
- Reinstalled zzcollab with all fixes
- Test suite: PASS 34, FAIL 0, WARN 1, SKIP 1
- All 4 build modes now fully functional

### Automated Data Documentation System and Safety Enhancements (August 2025)

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
- **Variable reference fix**: Corrected undefined `team_variant_name` variable to `variant_name` in `templates/add_profile.sh`
- **Workflow optimization**: Enhanced ShellCheck configuration to focus on functional issues while maintaining code quality

**Documentation Expansion and Quality Improvements:**
- **Comprehensive inline comments**: Enhanced zzcollab.sh with detailed architecture overview and workflow explanations
- **Roxygen2 standardization**: All R functions now have complete roxygen2 documentation with @param, @return, @details, @examples
- **Module documentation**: Critical shell functions documented with architectural context and usage patterns
- **Dependency validation**: Enhanced validate_package_environment.R with comprehensive architectural documentation

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
- **All CI workflows passing**: Both R package validation and ShellCheck analysis execute successfully
- **No critical warnings**: Eliminated all blocking warnings in package documentation and code analysis
- **Professional documentation**: Complete roxygen2 documentation with proper LaTeX formatting
- **Clean dependency management**: All imports properly declared and functional
- **Robust vignette system**: All workflow documentation renders correctly with executable examples

**Key Technical Insights:**
- `.Rbuildignore` patterns can accidentally exclude critical directories - use specific patterns
- `devtools::load_all()` vs `R CMD INSTALL` have different behaviors for package validation
- ShellCheck severity levels allow focusing on functional issues vs. style preferences
- Roxygen2 documentation requires single backslashes for LaTeX commands, not double backslashes
- Vignette chunks with `eval = FALSE` prevent inline R expressions from accessing defined variables
- Unicode characters in R source code must use escape sequences for CRAN compliance

### Vignette System Documentation (October 2025)
**Consolidated vignette structure** - five focused vignettes covering complete ZZCOLLAB functionality:

**Core Vignette Suite:**
- **quickstart.Rmd**: 5-minute fully reproducible analysis with all 5 levels (NEW - October 2025)
- **getting-started.Rmd**: Comprehensive tutorial for new users with step-by-step Palmer Penguins analysis
- **configuration.Rmd**: Advanced configuration system including Docker profiles and package management
- **testing.Rmd**: Comprehensive guide to testing data analysis workflows in R
- **reproducibility-layers.Rmd**: Five-level progressive reproducibility framework
- **Complete workflow coverage**: From quick start through advanced configuration and testing practices
- **Real-world examples**: Palmer Penguins analysis demonstrating reproducible research workflows

**Target Audience Expansion:**
- **R users familiar with RStudio/tidyverse** but unfamiliar with Docker/bash commands
- **Research teams** wanting reproducibility without DevOps complexity
- **Data scientists** focused on analysis rather than infrastructure management
- **Academic labs** needing effective collaboration across different skill levels

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

# Team workflow - effective collaboration
init_project("team-project", team_name = "lab")  # Team lead setup
join_project("lab", "team-project")              # Team members join
start_rstudio()                                   # Identical environments
```

### Five-Level Reproducibility Framework (October 2025)
**Enhanced reproducibility-layers.Rmd vignette** - transformed from 4-level to comprehensive 5-level progressive framework addressing all dimensions of computational reproducibility:

**New Level 4: Unit Testing for Computational Correctness (500+ lines added):**
- **Critical gap addressed**: Environment consistency (Docker) does not guarantee computational correctness
- **Reproducibility crisis motivation**: 50-89% replication failure rate, often due to computational errors
- **Complete test-driven workflow**: Palmer Penguins analysis with data preparation, statistical analysis, and data quality tests
- **Testing best practices**: >90% coverage requirements, edge case handling, common testing mistakes
- **Scientific evidence**: 40% fewer defects with >80% test coverage, 16% reduction in debugging time

**Three Dimensions of Reproducibility Framework:**
- **Environment Reproducibility** (Levels 2-3): Same packages, R version, system libraries
- **Computational Correctness** (Level 4): Code produces analytically sound results ← NEW
- **Automated Verification** (Level 5): Continuous validation that everything works

**Enhanced Decision Framework:**
- **Analytical complexity dimension**: Complex calculations require tests (Level 4)
- **Progressive adoption timeline**: Week 1 → Month 6 migration path
- **Updated cost-benefit analysis**: 5-level decision table by project duration and team size
- **5 practical examples**: All updated with appropriate level recommendations

**Comprehensive Testing Coverage Examples:**
```r
# Data preparation tests (missing values, transformations, edge cases)
test_that("prepare_penguin_data removes missing values", {
  result <- prepare_penguin_data(penguins)
  expect_false(anyNA(result$body_mass_g))
  expect_false(anyNA(result$bill_length_mm))
})

# Statistical analysis tests (model validity, coefficient checks)
test_that("fit_penguin_model coefficients are sensible", {
  model <- fit_penguin_model(test_data)
  expect_gt(coef(model)["bill_length_mm"], 0)  # Positive relationship
})

# Data quality tests (structure validation, plausible ranges)
test_that("body mass measurements are plausible", {
  valid_data <- penguins %>% filter(!is.na(body_mass_g))
  expect_true(all(valid_data$body_mass_g >= 2500))
  expect_true(all(valid_data$body_mass_g <= 6500))
})
```

**Updated Structure:**
- **Level 1**: Basic R Project (manual package management)
- **Level 2**: renv (dependency tracking)
- **Level 3**: renv + Docker (environment isolation)
- **Level 4**: renv + Docker + Unit Testing (computational correctness) ← NEW
- **Level 5**: renv + Docker + Unit Testing + CI/CD (automated validation)

**Key Innovation**: Unit testing is now properly positioned as a reproducibility strategy that validates computational correctness, not just environment consistency. The vignette demonstrates that reproducible environments (Docker) can consistently produce WRONG results if the code has bugs - testing prevents this.

**Total changes**: +703 lines, -44 lines (747 net addition)

### Quick Start Vignette for Complete Reproducibility (October 2025)
**New quickstart.Rmd vignette** - demonstrates creating a fully reproducible analysis with all 5 levels in under 10 minutes:

**Complete Workflow Example:**
- **Analysis task**: Scatter plot of Palmer Penguins bill length vs bill depth
- **Reproducibility levels**: All 5 (renv + Docker + Unit Testing + CI/CD)
- **Deployment**: Private GitHub repository with automated validation
- **Time commitment**: ~8 minutes from start to fully reproducible analysis

**Step-by-Step Instructions:**
1. **Configure ZZCOLLAB** (30s): Set GitHub account and build mode defaults
2. **Create project** (2 min): Initialize with Docker, renv, and CI/CD workflows
3. **Make private** (30s): Set repository visibility using GitHub CLI
4. **Analysis script** (1 min): Create scatter plot function and generate output
5. **Unit tests** (2 min): Add tests for computational correctness (Level 4)
6. **Validate & commit** (1 min): Run tests, validate dependencies, push to GitHub
7. **Verify CI/CD** (30s): Confirm automated validation runs successfully

**Key Features:**
- **All 5 levels demonstrated**: Shows progression from basic project to complete reproducibility
- **Practical example**: Real analysis (bill dimensions scatter plot) not toy example
- **Private repository**: Demonstrates GitHub private repo setup for sensitive research
- **Unit testing emphasis**: Includes Level 4 tests for plot creation, missing data handling, species inclusion
- **CI/CD verification**: Shows how to confirm automated validation works

**Code Examples:**
```r
# Create tested function (Level 4)
create_bill_plot <- function(data = palmerpenguins::penguins) {
  data %>%
    filter(!is.na(bill_length_mm), !is.na(bill_depth_mm)) %>%
    ggplot(aes(x = bill_length_mm, y = bill_depth_mm, color = species)) +
    geom_point(size = 3, alpha = 0.7) +
    labs(title = 'Palmer Penguins: Bill Dimensions') +
    theme_minimal()
}

# Unit tests validate correctness
test_that("create_bill_plot produces valid ggplot", {
  plot <- create_bill_plot()
  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "Palmer Penguins: Bill Dimensions")
})
```

**Troubleshooting Section:**
- GitHub repository creation failures
- Docker build errors
- Test failures with verbose output
- CI/CD workflow debugging

**Next Steps Guidance:**
- Extend analysis with additional plots
- Add statistical models with corresponding tests
- Collaborate by adding team members
- Publish results via automated manuscript rendering

**User Value**: Researchers can follow this vignette to create publication-ready, fully reproducible analyses in minutes, not hours. Demonstrates that professional reproducibility practices are accessible and fast to implement.

### Documentation Tone Standardization (October 2025)
**Comprehensive academic tone conversion** - systematic transformation of all documentation to scholarly standards:

**Documentation Quality Improvements:**
- **357 emojis removed**: Eliminated all decorative emojis from documentation (✅, ❌, 🎯, 📦, 🔬, 🏔️, 🧪)
- **100+ contractions expanded**: Changed "you're" → "you are", "it's" → "it is", "don't" → "do not"
- **45+ hyperbolic terms neutralized**: Replaced "amazing" → "effective", "seamlessly" → "effectively", "perfect" → "consistent"
- **Formatting standardization**: Added blank lines before all bullet lists, wrapped code blocks at column 76

**Files Systematically Updated (30+ files):**
- **README.md**: Removed 24 emojis, expanded contractions, neutralized marketing language
- **ZZCOLLAB_USER_GUIDE.md**: Removed 50+ emojis from section headers and category labels
- **CLAUDE.md**: Removed 30+ emojis from configuration sections
- **docs/*.md (28 files)**: Complete tone conversion across all technical documentation
- **vignettes/*.Rmd (5 files)**: Academic tone compliance while preserving R code blocks

**Implementation Approach:**
- Created systematic sed script (`/tmp/tone_fixes.sed`) with 22 emoji patterns, 15 contraction patterns, 9 hyperbolic term replacements
- Applied automated transformations consistently across entire codebase
- Five focused commits covering all major documentation categories
- Maintained technical accuracy while improving scholarly tone

**Result:** All documentation now adheres to academic and scholarly standards appropriate for research software documentation.

### CRAN Compliance Achievement (October 2025)
**Full CRAN compliance achieved** - resolved all R CMD check issues for publication readiness:

**CRAN Check Results:**
```
✔ 0 errors | 0 warnings | 0 notes
Status: OK
Duration: 1m 27.7s
```

**Issues Resolved:**

1. **Hidden files in vignettes (NOTE)**:
   - Removed `vignettes/.zzvim_r_temp.R` (vim temporary file)
   - Removed `vignettes/.claude/` directory
   - Ensured clean package structure

2. **Non-standard top-level files (NOTE)**:
   - Added `CLAUDE.md` to `.Rbuildignore`
   - Added `Dockerfile.verse-multiarch` to `.Rbuildignore`
   - Added `examples/` directory to `.Rbuildignore`
   - Maintains development files while excluding from package builds

3. **Unused namespace import (NOTE)**:
   - Removed `jsonlite` from DESCRIPTION Imports
   - Package was declared but not actually used in R/ code
   - Cleaned up dependency declarations

**Package Quality Standards:**
- **Complete test coverage**: 34 R package tests pass (FAIL 0 | WARN 0 | SKIP 0 | PASS 34)
- **Clean documentation**: All roxygen2 documentation validates without warnings
- **Proper imports**: All namespace imports declared and used correctly
- **Vignette system**: All vignettes build successfully with knitr
- **CRAN-ready structure**: Package follows all R package development best practices

**Production Status:** The zzcollab R package is now fully CRAN-compliant and ready for submission to the Comprehensive R Archive Network.

**Documentation Quality Achievements:**
- **Complete examples**: Full analysis workflows from project creation to results publication
- **Role-based guidance**: Clear separation of team lead vs team member responsibilities  
- **Troubleshooting sections**: Common issues and R-based solutions
- **Best practices integration**: Professional development patterns without complexity exposure

This expansion makes ZZCOLLAB accessible to the broader R community by eliminating the need to learn Docker/bash while maintaining all reproducibility benefits.

### Professional Help System with Pagination (August 2025)
**Comprehensive help system redesigned** - implementing professional CLI best practices with proper pagination and specialized help sections:

**Smart Pagination Implementation:**
- **Interactive terminals**: Automatically pipes through `less -R` for proper viewing of long help content
- **Script-friendly output**: Direct output when redirected (`zzcollab -h > help.txt`) or when `PAGER=cat`
- **Color preservation**: `-R` flag maintains ANSI color codes in paged output
- **User customizable**: Respects `$PAGER` environment variable for preferred pager

**Specialized Help Sections:**
```bash
zzcollab -h                    # Main help with all options and examples
zzcollab --help-init          # Team initialization specific guidance
zzcollab --help-profiles      # Docker profiles configuration system (NEW)
zzcollab --next-steps         # Development workflow guidance
```

**Comprehensive Variants Documentation (NEW):**
- **Complete profile catalog**: All 14+ profiles with size estimates and descriptions
- **Domain-specific examples**: Bioinformatics, geospatial, Alpine, R-hub testing workflows
- **Configuration structure**: YAML syntax and hierarchy explanation
- **Troubleshooting Q&A**: Common profile configuration issues and solutions
- **Legacy vs modern approaches**: Clear comparison between `-B` flags and `--profiles-config`

**Technical Implementation:**
- **Smart terminal detection**: `[[ ! -t 1 ]]` detects redirected output
- **Professional formatting**: Matches behavior of `git`, `docker`, and man pages
- **Fixed $0 variable issue**: All help text now shows `zzcollab` instead of `$0`
- **Modular help functions**: Each help section properly paginated with consistent patterns

**User Experience Improvements:**
```bash
# Professional paging (97+ lines of help properly displayed)
zzcollab -h                   # Pages through less automatically

# Direct output for scripts/automation
PAGER=cat zzcollab -h         # No paging for scripted usage
zzcollab -h > documentation.txt  # Works correctly for documentation

# Specialized help available
zzcollab --help-profiles      # Comprehensive Docker profiles guide
```

**Benefits:**
- **Professional CLI behavior**: Matches industry standard tools
- **Long content accessible**: 97+ lines properly paginated
- **Script compatible**: Works in both interactive and automated contexts
- **Comprehensive coverage**: Specialized help for complex features
- **User control**: Customizable via environment variables

### Security Assessment Results
**Comprehensive security audit completed** - zzcollab codebase demonstrates excellent security practices:
- **No unsafe cd commands** - All use proper error handling (`|| exit 1`)
- **No unquoted rm operations** - All file operations properly quote variables
- **No unquoted test conditions** - Variables in conditionals safely handled
- **No word splitting vulnerabilities** - Defensive programming throughout
- **Production-ready security posture** - No HIGH RISK vulnerabilities found

### Repository Cleanup and Production Readiness (August 2025)
**Comprehensive cleanup completed** - repository now follows open source best practices for production-ready projects:

**Documentation Structure Improvements:**
- **Proper R package vignettes**: All workflow documentation in `vignettes/` following R package standards
- **Three-vignette structure** (October 2025): `getting-started.Rmd`, `configuration.Rmd`, `testing.Rmd`
- **Consolidated documentation**: Single source of truth for all user workflows, configuration, and testing guidance
- **Deprecated vignettes**: Legacy paradigm-specific vignettes archived in `vignettes/deprecated/`

**Development Artifacts Cleanup:**
- **Safe removal using trash-put**: All development artifacts moved to trash (recoverable if needed)
- **Legacy documentation removed**: Duplicate workflow.md, DATA_ANALYSIS_TESTING_GUIDE.md files
- **Build artifacts cleaned**: zzcollab.Rcheck/, temp_check/, *.tar.gz packages removed
- **Development scripts archived**: md2pdf.sh, minimal_test.sh, navigation_scripts.sh eliminated
- **Generated files cleanup**: All PDF outputs, text files, workflow mini files removed

**Enhanced Git Management:**
- **Improved .gitignore**: Added patterns for development artifacts (*.pdf, *test/, temp_*, *_check/)
- **Future clutter prevention**: Patterns prevent generated files from being committed
- **Professional repository structure**: Clean, focused codebase for contributors

**Production-Ready Benefits:**
- **Faster repository clones**: Reduced size improves developer experience
- **Clear project structure**: Contributors see only production-relevant code
- **Professional appearance**: Mature, well-maintained open source project
- **Maintainable codebase**: Documentation and code properly organized following industry standards

**Key Technical Insights:**
- Used `tp` (trash-put) for safe file deletion with recovery option
- Followed R package standards by moving documentation to proper vignettes/ structure
- Enhanced .gitignore prevents future development artifact accumulation
- Repository structure now optimized for both solo developers and team collaboration

### Critical Bug Fix: Conflict Detection System (September 2025)
**Comprehensive resolution of false positive conflict detection** - fixed timing issues and array handling bugs in the file conflict detection system:

**Issue Identified:**
- Users reported that `.github` directories were being flagged as conflicts immediately after zzcollab created them
- Investigation revealed this was not a timing issue but rather bugs in the conflict detection logic itself

**Root Cause Analysis:**
- **Array handling bug**: `detect_file_conflicts()` function had "unbound variable" error when returning empty conflicts array
- **Excessive debug logging**: Debug statements were cluttering output and causing confusion about the actual workflow timing

**Technical Fixes Applied:**
- **Fixed array handling** (`zzcollab.sh:390-392`): Added safe handling for empty conflicts arrays to prevent "unbound variable" errors:
  ```bash
  # Before: Could cause "unbound variable" error
  printf '%s\n' "${conflicts[@]}"

  # After: Safe handling of empty arrays
  if [[ ${#conflicts[@]} -gt 0 ]]; then
      printf '%s\n' "${conflicts[@]}"
  fi
  ```
- **Enhanced conflict intelligence**: Improved detection logic properly distinguishes between true conflicts and safe coexistence scenarios
- **Cleaned debug output**: Removed excessive logging that was obscuring actual workflow behavior

**Verification Results:**
Comprehensive testing confirmed the fix works correctly across all scenarios:
- **Clean directory**: No false conflict warnings, `.github` created properly
- **Pre-existing `.github`**: Intelligent detection preserves existing files while adding zzcollab workflows
- **File conflicts**: Properly detects and handles actual file conflicts (DESCRIPTION, Makefile, etc.)
- **Directory coexistence**: Recognizes that `.github/workflows` can contain multiple workflow files
- **No errors**: Eliminated "unbound variable" bash errors
- **Test suite**: All 34 R package tests pass, dependency validation successful

**Key Technical Insight:**
The original issue was not about timing - conflict detection was running at the correct time. The problem was:
1. Bash array handling errors causing script failures
2. Conflict detection logic that needed to be smarter about distinguishing true conflicts from safe coexistence scenarios

**User Experience Improvements:**
- **Clear conflict reporting**: Users now see only actual conflicts, not false positives
- **Safe file preservation**: Existing user files are preserved while zzcollab adds its functionality
- **Predictable behavior**: Consistent conflict detection across all usage scenarios
- **Robust error handling**: No more script failures due to array handling bugs

This fix ensures reliable conflict detection that protects user data while enabling smooth zzcollab setup workflows.

## Documentation Resources

ZZCOLLAB provides comprehensive documentation at multiple levels:

### User Documentation

- **ZZCOLLAB_USER_GUIDE.md**: Comprehensive user guide (v3.1) with all essential topics
  - Architecture overview and core components
  - Unified research compendium documentation
  - Advanced configuration system with examples
  - Docker profile system and customization
  - Data documentation system and workflow
  - Solo and team collaboration workflows
  - Recent enhancements and platform-specific notes

### Technical Guides (docs/)

**Definitive System Guides**:

- **BUILD_MODES.md** (22K): Complete build mode system documentation
  - Three-tiered build mode architecture (Fast/Standard/Comprehensive)
  - Package specifications and selection criteria
  - Build mode decision framework
  - Performance characteristics and optimization
  - Custom build mode definition

- **TESTING_GUIDE.md** (26K): Comprehensive testing framework
  - Three-layer testing strategy (Unit/Integration/System)
  - testthat patterns and best practices
  - Test coverage requirements (>90%)
  - Continuous integration testing

- **CONFIGURATION.md** (22K): Multi-layered configuration system
  - Four-level precedence hierarchy
  - Complete YAML configuration examples
  - Configuration commands and R interface
  - Environment variable documentation
  - Advanced customization patterns

- **VARIANTS.md** (20K): Docker profile system guide
  - Single source of truth architecture
  - Complete catalog of 14+ Docker profiles
  - Profile categories and specifications
  - Custom profile definition
  - Platform considerations (ARM64 compatibility)

**Research Motivation Documents**:

- **UNIT_TESTING_MOTIVATION_DATA_ANALYSIS.md** (39K): Scientific justification for testing in research
- **CICD_MOTIVATION_DATA_ANALYSIS.md** (21K): Evidence-based CI/CD rationale
- **RENV_MOTIVATION_DATA_ANALYSIS.md** (23K): Dependency management motivation
- **DOCKER_MOTIVATION_DATA_ANALYSIS.md** (33K): Container-based research rationale

**Architecture Documentation**:

- **IMPROVEMENTS_SUMMARY.md** (8.2K): Code quality improvements and refactoring
- **MODULE_DEPENDENCIES.md** (3K): Module dependency mapping
- **R_PACKAGE_INTEGRATION_SUMMARY.md** (6.4K): R package integration details

### Documentation Cross-References

When working on zzcollab, refer users to:

- Build mode questions → `docs/BUILD_MODES.md`
- Testing implementation → `docs/TESTING_GUIDE.md`
- Configuration setup → `docs/CONFIGURATION.md`
- Profile customization → `docs/VARIANTS.md`
- General usage → `ZZCOLLAB_USER_GUIDE.md`
- Architecture details → `CLAUDE.md` (this file)

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