# ZZRRTOOLS Research Compendium Framework - User Guide v4.0

## Table of Contents
1. [What is ZZRRTOOLS?](#what-is-zzrrtools)
2. [Getting Started](#getting-started)
3. [Installation & Distribution](#installation--distribution)
4. [Configuration](#configuration)
5. [Modular Architecture](#modular-architecture)
6. [Uninstall and Cleanup](#uninstall-and-cleanup)
7. [Enhanced Research Compendium Features](#enhanced-research-compendium-features)
8. [Directory Structure](#directory-structure)
9. [Navigation Shortcuts](#navigation-shortcuts)
10. [Workflow Overview](#workflow-overview)
11. [Development Environments](#development-environments)
12. [Package Management with renv](#package-management-with-renv)
13. [Docker Environment](#docker-environment)
14. [Build System with Make](#build-system-with-make)
15. [GitHub Actions CI/CD](#github-actions-cicd)
16. [Enhanced Research Examples](#enhanced-research-examples)
17. [Common Tasks](#common-tasks)
18. [Collaboration](#collaboration)
19. [Troubleshooting](#troubleshooting)
20. [Version History](#version-history)
21. [Architecture Information](#architecture-information)

## What is ZZRRTOOLS?

**ZZRRTOOLS** is a modular framework for creating **research compendia** - self-contained, reproducible research projects that combine:
- R package structure for code organization
- Data management and documentation
- Analysis scripts and notebooks
- Manuscript preparation
- Docker containerization for reproducibility
- Version control integration

### Key Benefits
- **Reproducibility**: Anyone can recreate your analysis
- **Organization**: Clear structure for all project components
- **Collaboration**: Standards for team-based research
- **Publication**: Direct path from analysis to manuscript
- **Portability**: Works across different computing environments
- **Docker-first**: No local R installation required
- **Modular Design**: 8 focused modules for maintainability
- **Uninstall Capability**: Complete cleanup with manifest tracking

## Getting Started

### Prerequisites
- **Docker** (required for containerized workflow)
- **Git** (recommended for version control)
- **R & RStudio** (optional - can work entirely in Docker)

### Quick Start
```bash
# 1. One-time installation (replace [YOUR-USERNAME] with actual GitHub username)
git clone https://github.com/[YOUR-USERNAME]/zzrrtools.git
cd zzrrtools
./install.sh

# 2. Create new analysis project
mkdir my-penguin-analysis
cd my-penguin-analysis
zzrrtools --dotfiles ~/dotfiles

# 3. Start developing immediately
make docker-rstudio  # → http://localhost:8787
# OR
make docker-r        # → R console in container
```

## Installation & Distribution

### Method 1: Automatic Installation (Recommended)
```bash
# One-line install
git clone https://github.com/[YOUR-USERNAME]/zzrrtools.git && cd zzrrtools && ./install.sh
```

### Method 2: Manual Installation
```bash
# Clone and create symlink manually
git clone https://github.com/[YOUR-USERNAME]/zzrrtools.git
cd zzrrtools
ln -s "$(pwd)/zzrrtools.sh" ~/bin/zzrrtools  # Adjust path as needed
```

### Method 3: Direct Download
```bash
# Download and install in one step
curl -fsSL https://raw.githubusercontent.com/[YOUR-USERNAME]/zzrrtools/main/install.sh | bash
```

### Project Creation Workflow
Each analysis project is **independent and self-contained**:

#### For Each New Analysis Project:
```bash
# Create and enter new project directory
mkdir my-climate-study
cd my-climate-study

# Set up complete research compendium
zzrrtools --dotfiles ~/dotfiles --base-image rocker/tidyverse

# Initialize git (work locally first)
git init
git add .
git commit -m "🎉 Initial research compendium setup"

# When ready to share, create GitHub repo
gh repo create my-climate-study --public
git push -u origin main
```

### Team Collaboration Workflow
```bash
# Team member joins existing project
git clone https://github.com/[TEAM]/research-project
cd research-project

# Project structure is already set up - start working immediately!
make docker-rstudio
```

### Git Integration Patterns

#### Local-First Workflow (Recommended)
Perfect for exploratory analysis and private development:

```bash
# 1. Create local project
mkdir penguin-behavioral-analysis
cd penguin-behavioral-analysis

# 2. Set up research compendium
zzrrtools --dotfiles ~/dotfiles --base-image rocker/tidyverse

# 3. Initialize git and work locally
git init
git add .
git commit -m "🎉 Initial research compendium setup"

# 4. Do analysis work, make commits
# ... edit files, run analysis ...
git add .
git commit -m "Add data exploration and initial plots"

# 5. When ready to share, create GitHub repo
gh repo create penguin-behavioral-analysis --public
git remote add origin https://github.com/username/penguin-behavioral-analysis.git
git push -u origin main
```

#### GitHub-First Workflow
For projects you know will be collaborative from the start:

```bash
# 1. Create GitHub repo first
gh repo create my-research-project --public --clone

# 2. Enter the directory and set up
cd my-research-project
zzrrtools --dotfiles ~/dotfiles

# 3. Commit and push
git add .
git commit -m "🎉 Initial research compendium setup"
git push
```

## Configuration

### Environment Variables
Customize rrtools behavior with environment variables:

```bash
# Author information
export RRTOOLS_AUTHOR_NAME="Jane Smith"
export RRTOOLS_AUTHOR_EMAIL="jane@university.edu"
export RRTOOLS_INSTITUTE="MIT"
export RRTOOLS_INSTITUTE_FULL="Massachusetts Institute of Technology"

# File locations
export RRTOOLS_BASE_PATH="/path/to/rrtools/files"

# Then run
zzrrtools
```

### Command-Line Options
```bash
zzrrtools [OPTIONS]

OPTIONS:
  --no-docker          Skip Docker image build during setup
  --dotfiles DIR       Copy dotfiles from specified directory (with leading dots)
  --dotfiles-nodot DIR Copy dotfiles from directory (without leading dots)
  --base-image NAME    Use custom Docker base image (default: rocker/r-ver)
  --next-steps         Show development workflow and next steps
  --help, -h           Show help message

EXAMPLES:
  zzrrtools                                           # Full setup with Docker
  zzrrtools --no-docker                              # Setup without Docker build
  zzrrtools --dotfiles ~/dotfiles                    # Include personal dotfiles
  zzrrtools --dotfiles-nodot ~/dotfiles              # Dotfiles without leading dots
  zzrrtools --base-image rocker/tidyverse            # Use tidyverse base image
  RRTOOLS_AUTHOR_NAME="Jane Doe" zzrrtools           # Custom author
```

### Modular Implementation Details

ZZRRTOOLS now uses a **modular architecture** that automatically:

1. **Loads 8 modules** in dependency order during setup
2. **Creates manifest tracking** for complete uninstall capability  
3. **Validates each module** before proceeding with setup
4. **Shows module summaries** with detailed feature descriptions
5. **Installs uninstall script** for easy cleanup

The modular design provides enhanced maintainability while preserving 100% backward compatibility with existing workflows.

### Safety Features
- **Input validation**: Package names sanitized and validated according to R package rules
- **Error handling**: Comprehensive error checking with graceful fallbacks
- **File protection**: Never overwrites existing files (preserves user modifications)
- **Docker validation**: Checks Docker availability before use
- **Permission checking**: Verifies write permissions before starting
- **Template validation**: Ensures all required templates exist before processing

## Modular Architecture

ZZRRTOOLS v4.0 features a **modular architecture** with 8 focused modules that provide maintainability and flexibility:

### Core Modules

#### 1. **Core Module** (`modules/core.sh`)
- **Purpose**: Foundation utilities and logging
- **Features**:
  - Package name validation with R naming rules
  - Comprehensive logging system (`log_info`, `log_warn`, `log_error`, `log_success`)
  - Command existence checking
  - Error handling and validation functions

#### 2. **Templates Module** (`modules/templates.sh`)
- **Purpose**: Template processing and file creation
- **Features**:
  - Variable substitution in template files
  - Safe file creation (never overwrites existing files)
  - Manifest tracking for uninstall capability
  - Template validation and error handling

#### 3. **Structure Module** (`modules/structure.sh`)
- **Purpose**: Directory structure and navigation
- **Features**:
  - Creates 18 directories for complete research compendium
  - Generates 10 symbolic links for quick navigation
  - Comprehensive structure validation
  - Detailed logging of created items

#### 4. **R Package Module** (`modules/rpackage.sh`)
- **Purpose**: R package development framework
- **Features**:
  - DESCRIPTION, NAMESPACE, and LICENSE files
  - R function templates with roxygen2 documentation
  - RStudio project configuration
  - testthat testing framework setup
  - renv package management integration

#### 5. **Docker Module** (`modules/docker.sh`)
- **Purpose**: Container integration and builds
- **Features**:
  - Multi-service Docker Compose configuration
  - Platform-aware builds (ARM64/AMD64 compatibility)
  - R version detection from renv.lock
  - Container optimization and caching
  - Development shell configuration

#### 6. **Analysis Module** (`modules/analysis.sh`)
- **Purpose**: Research analysis framework
- **Features**:
  - R Markdown paper template with academic structure
  - Bibliography management with BibTeX
  - Citation styles (CSL) for academic journals
  - Analysis templates and examples
  - Figure and table creation workflows

#### 7. **CI/CD Module** (`modules/cicd.sh`)
- **Purpose**: Continuous integration and deployment
- **Features**:
  - GitHub Actions workflows for R package validation
  - Automated paper rendering and artifact upload
  - Issue and pull request templates
  - Multi-platform testing support
  - Quality assurance automation

#### 8. **DevTools Module** (`modules/devtools.sh`)
- **Purpose**: Development tools and configuration
- **Features**:
  - Comprehensive Makefile for build automation
  - Git ignore patterns for R projects
  - R session configuration (.Rprofile)
  - Personal dotfiles integration
  - Development helper scripts

### Module Loading System

```bash
# Modules are loaded in dependency order:
1. core.sh          # Foundation (required by all others)
2. templates.sh     # Template processing (depends on core)
3. structure.sh     # Directory creation (depends on core)
4. rpackage.sh      # R package setup (depends on core, templates)
5. docker.sh        # Container setup (depends on core, templates)
6. analysis.sh      # Analysis framework (depends on core, templates)
7. cicd.sh          # CI/CD workflows (depends on core, templates)
8. devtools.sh      # Development tools (depends on core, templates)
```

### Module Benefits

- **Maintainability**: Each module focuses on specific functionality
- **Testability**: Modules can be tested independently
- **Flexibility**: Individual modules can be modified without affecting others
- **Clarity**: Clear separation of concerns and dependencies
- **Extensibility**: New modules can be added easily
- **Debugging**: Issues can be traced to specific modules

## Uninstall and Cleanup

ZZRRTOOLS v4.0 includes **comprehensive uninstall capability** with manifest tracking:

### Automatic Manifest Creation

Every zzrrtools setup creates a manifest file that tracks all created items:

```bash
# JSON manifest (if jq is available)
.zzrrtools_manifest.json

# Text manifest (fallback)
.zzrrtools_manifest.txt
```

### Manifest Contents

The manifest tracks:
- **Directories**: All 18 created directories
- **Files**: Core package files, configuration files
- **Template Files**: All files created from templates
- **Symbolic Links**: All 10 navigation shortcuts
- **Dotfiles**: Personal configuration files copied
- **Metadata**: Creation timestamp, package name, options used

### Uninstall Script

Each project includes an automatic uninstall script:

```bash
# Dry run (preview what would be removed)
./zzrrtools-uninstall.sh --dry-run

# Interactive removal with confirmations
./zzrrtools-uninstall.sh

# Force removal without prompts
./zzrrtools-uninstall.sh --force

# Show uninstall help
./zzrrtools-uninstall.sh --help
```

### Safety Features

- **Dry run mode**: Preview removals before execution
- **Interactive confirmations**: Prompts for each category
- **Git repository detection**: Warns if project is git-managed
- **Backup recommendations**: Suggests backing up before removal
- **Selective removal**: Choose which categories to remove
- **Progress tracking**: Shows detailed removal progress

### Uninstall Categories

The uninstall script organizes removals by category:

1. **Symbolic Links**: Navigation shortcuts (a, n, f, t, s, m, e, o, c, p)
2. **Template Files**: Generated from templates with variable substitution
3. **Core Files**: Package structure files (DESCRIPTION, NAMESPACE, etc.)
4. **Dotfiles**: Personal configuration files
5. **Directories**: All created directories (only if empty)
6. **Manifest**: The tracking files themselves

### Example Uninstall Session

```bash
$ ./zzrrtools-uninstall.sh
ℹ️  === ZZRRTOOLS UNINSTALL ===
ℹ️  Package: myproject
ℹ️  Created: 2025-06-29T05:12:40Z
ℹ️  Items to remove:
ℹ️    - Directories: 18
ℹ️    - Files: 15
ℹ️    - Symlinks: 10

⚠️  WARNING: This will remove all zzrrtools-created files
📁 Project appears to be git-managed
💡 Consider backing up your work first

? Remove symbolic links? (y/N) y
✅ Removed 10 symbolic links

? Remove template files? (y/N) y
✅ Removed 8 template files

? Remove core package files? (y/N) y
✅ Removed 7 core files

? Remove directories? (y/N) y
✅ Removed 15 empty directories

✅ Uninstall completed successfully!
```

## Enhanced Research Compendium Features

This section describes the advanced research capabilities integrated into ZZRRTOOLS v4.0. These features were originally planned as separate rrtools_plus enhancements but have been seamlessly integrated into the modular architecture described in the previous section.

ZZRRTOOLS v4.0 integrates advanced research compendium capabilities that were planned for the rrtools_plus enhancement:

### ✅ **Fully Integrated Features**

#### **Advanced Collaboration Infrastructure**
- **GitHub Templates**: Complete collaboration framework from the CI/CD module
- **Pull Request Templates**: Research-specific checklists including analysis impact assessment
- **Issue Templates**: Bug reports with environment information and feature requests with use cases
- **Team Workflows**: Standardized contribution guidelines for research teams

#### **Quality Assurance & Reproducibility**
- **Automated CI/CD**: GitHub Actions workflows for continuous validation
- **Package Validation**: Automated R CMD check, dependency validation, test execution
- **Reproducibility Checks**: Automated paper rendering and artifact generation
- **Multi-platform Testing**: Ensures code works across different environments

#### **Professional Development Tools**
- **Comprehensive Makefile**: Build automation for both native and Docker workflows
- **Container Integration**: Production-ready Docker environment with multi-service support
- **Development Environment**: Integrated RStudio Server, shell access, and development tools

### ⚡ **Enhanced Data Management**

#### **Comprehensive Data Structure**
The integrated data management framework provides:

```
data/
├── raw_data/           # Original, unmodified datasets
├── derived_data/       # Processed, analysis-ready data  
├── metadata/           # Data dictionaries and documentation
└── validation/         # Data quality reports and checks
```

#### **Data Management Features**
- **Structured Organization**: Separate spaces for raw, derived, and metadata
- **Quality Tracking**: Dedicated validation directory for data quality reports
- **Documentation Support**: Metadata directory for data dictionaries and provenance
- **Version Control Integration**: Git-friendly structure with appropriate ignore patterns

### 📚 **Academic Publishing Integration**

#### **Research Paper Framework**
- **R Markdown Templates**: Complete academic paper structure with proper sections
- **Citation Management**: BibTeX integration with citation style files (CSL)
- **Bibliography Support**: Automated reference formatting for academic journals
- **Cross-references**: Support for figures, tables, and equation referencing

#### **Publication Workflow**
- **Automated Rendering**: GitHub Actions automatically render papers on changes
- **Multiple Formats**: Support for PDF, HTML, and Word outputs
- **Academic Standards**: Proper formatting for peer-reviewed publications
- **Artifact Management**: Automatic paper uploads and version tracking

### 🔧 **Development Excellence**

#### **Package Development Integration**
- **Professional Structure**: Complete R package framework with documentation
- **Testing Infrastructure**: testthat framework with example tests
- **Documentation System**: roxygen2 integration for function documentation
- **Dependency Management**: renv for reproducible package environments

#### **Container-First Development**
- **Docker Integration**: Production-ready containerized development environment
- **Platform Compatibility**: ARM64/AMD64 support with automatic platform detection
- **Service Orchestration**: Multi-service Docker Compose configuration
- **Development Tools**: Integrated shell configurations and dotfiles support

### 📋 **Current Capabilities vs. Original rrtools_plus Vision**

| Feature Category | Implementation Status | Available Now |
|------------------|----------------------|---------------|
| **Collaboration Infrastructure** | ✅ Complete | GitHub templates, PR workflows, issue management |
| **Quality Assurance & CI/CD** | ✅ Complete | Automated testing, validation, reproducibility checks |
| **Advanced Data Management** | 🟡 Structure Complete | Directory organization, validation framework |
| **Academic Publishing** | 🟡 Core Features | Paper templates, citations, automated rendering |
| **Development Tools** | ✅ Complete | Makefile, Docker, package development |
| **Ethics & Legal Documentation** | 🔄 Planned | IRB templates, data sharing agreements |

### 🚀 **Future Enhancements**

Features planned for future releases:
- **Ethics Documentation**: IRB templates and data sharing agreement frameworks
- **Data Validation Automation**: Automated data quality checking and reporting
- **Journal-Specific Templates**: Publication templates for specific academic journals
- **Legal Compliance**: GDPR and data privacy documentation templates

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
│   └── validation/            # Data quality reports
├── analysis/                   # Research analysis components
│   ├── paper/                 # Manuscript files
│   ├── figures/               # Generated plots and figures
│   ├── tables/                # Generated tables
│   └── templates/             # Document templates
├── tests/                      # Unit tests for R functions
├── vignettes/                  # Package tutorials and examples
├── docs/                       # Project documentation and outputs
├── archive/                    # Moved files and legacy code
├── .github/workflows/          # GitHub Actions CI/CD
└── Key files (DESCRIPTION, Makefile, Docker files, etc.)
```

### What Goes Where?

| Content Type | Location | Purpose |
|--------------|----------|---------|
| **Reusable functions** | `R/` | Functions you want others to use |
| **Function documentation** | `man/` | Auto-generated help files (.Rd) |
| **Analysis scripts** | `scripts/` | Working code, exploratory analysis |
| **Research paper** | `analysis/paper/` | Manuscript and publication files |
| **Generated figures** | `analysis/figures/` | Plots and visualizations |
| **Generated tables** | `analysis/tables/` | Statistical tables |
| **Raw data** | `data/raw_data/` | Original, unmodified datasets |
| **Clean data** | `data/derived_data/` | Processed, analysis-ready data |
| **Data documentation** | `data/metadata/` | Data dictionaries, codebooks |
| **Unit tests** | `tests/` | Tests for your R functions |
| **Tutorials** | `vignettes/` | Package examples and tutorials |

## Navigation Shortcuts

Convenient symbolic links for quick navigation:

```bash
a     # → ./data              (data files)
n     # → ./analysis          (analysis files)  
f     # → ./analysis/figures  (figures)
t     # → ./analysis/tables   (tables)
s     # → ./scripts           (working R scripts)
m     # → ./man               (function documentation)
e     # → ./tests             (tests)
o     # → ./docs              (documentation)
c     # → ./archive           (archived files)
p     # → ./analysis/paper    (research paper)
```

**Usage**: `cd a` to go to data directory, `ls f` to see figures, etc.

## Workflow Overview

### Enhanced Docker-First Development Workflow

#### Initial Setup (One Time)
```bash
cd your-project
zzrrtools                       # Creates complete research compendium with:
                               # - All 8 modules (core, templates, structure, etc.)
                               # - GitHub collaboration templates  
                               # - Automated CI/CD workflows
                               # - Data management structure
                               # - Publication infrastructure
```

#### Enhanced Daily Development Cycle
```bash
# 1. Start development environment
make docker-rstudio            # → RStudio at http://localhost:8787
# OR
make docker-r                  # → R console
# OR  
make docker-bash               # → Shell access
# OR
make docker-zsh                # → Zsh shell access (with personal dotfiles)

# 2. Enhanced workflow with rrtools_plus features:
# - Organize data in data/raw_data/, data/derived_data/
# - Document datasets in data/metadata/
# - Use R package functions for analysis
# - Save outputs to analysis/figures/, analysis/tables/

# 3. Quality assurance (integrated validation)
exit                           # Exit container
make docker-check-renv-fix     # Validate and fix dependencies
make docker-test               # Run package tests  
make docker-render             # Test paper rendering

# 4. Commit triggers automated CI/CD
git add .
git commit -m "Analysis update"
git push                       # → Triggers GitHub Actions:
                              #   - R package validation
                              #   - Automated paper rendering
                              #   - Dependency checks
```

#### 📊 **Data Management Workflow** (rrtools_plus Integration)
```bash
# 1. Data intake and organization
cp ~/Downloads/survey_data.csv data/raw_data/
cp ~/Downloads/reference.csv data/external_data/

# 2. Data documentation (enhanced templates)
# Edit data/metadata/data_dictionary.md with variable descriptions
# Document data provenance and collection methods
# Create data validation scripts in data/validation/

# 3. Data processing pipeline
# scripts/01_data_cleaning.R     → Clean raw data
# scripts/02_data_validation.R   → Quality checks  
# scripts/03_analysis.R          → Main analysis
# Save processed data to data/derived_data/
```

#### 🔬 **Publication Workflow** (Enhanced Academic Integration)
```bash
# 1. Research paper development
# Edit analysis/paper/paper.Rmd with analysis and results
# Add citations to analysis/paper/references.bib
# Include figures with proper cross-references

# 2. Automated rendering and validation
make docker-render             # Local paper generation
git push                       # → Triggers automated paper rendering
                              # → GitHub Actions creates downloadable PDF

# 3. Access rendered papers
# Visit GitHub → Actions tab → Latest workflow → Artifacts
# Download automatically generated PDF
```

#### 🤝 **Team Collaboration** (Complete rrtools_plus Implementation)
```bash
# 1. Enhanced GitHub templates automatically created:
# - .github/pull_request_template.md (analysis impact assessment)
# - .github/ISSUE_TEMPLATE/bug_report.md (environment details)
# - .github/ISSUE_TEMPLATE/feature_request.md (research use cases)

# 2. Automated quality assurance on every push:
# - R package validation (R CMD check)
# - Multi-platform testing 
# - Dependency validation with renv
# - Paper rendering and artifact upload

# 3. Professional collaboration workflow:
git pull                       # Get team updates
make docker-build             # Rebuild with new dependencies
# Work with validated, consistent environment
```

### Development Environment Options

| Environment | Command | Use Case |
|-------------|---------|----------|
| **RStudio Server** | `make docker-rstudio` | GUI-based development |
| **R Console** | `make docker-r` | Command-line R work |
| **Bash Shell** | `make docker-bash` | File management, git operations |
| **Zsh Shell** | `make docker-zsh` | Enhanced shell with personal dotfiles |
| **Paper Rendering** | `make docker-render` | Generate manuscript |
| **Package Testing** | `make docker-test` | Run unit tests |

## Package Management with renv

### Automatic Package Management
rrtools includes **automated renv setup**:

1. **Initial setup**: `source("setup_renv.R")` in container
2. **Install packages**: Use normal `install.packages()` or `renv::install()`
3. **Snapshot environment**: `renv::snapshot()` when ready
4. **Validate sync**: `make docker-check-renv-fix` before commits

### renv Validation System
**Automated validation** ensures package consistency:

```bash
# Check if packages are in sync
make check-renv

# Auto-fix any issues  
make check-renv-fix

# Silent check for CI/CD
make check-renv-ci
```

**What it checks**:
- All packages used in code are in DESCRIPTION
- All packages in DESCRIPTION exist on CRAN
- renv.lock is synchronized with DESCRIPTION
- No circular dependencies

### Package Workflow
```bash
# In Docker container:
install.packages("tidymodels")    # Install new package
# Use package in your analysis...
renv::snapshot()                  # Save to renv.lock
exit

# Outside container:
make docker-check-renv-fix        # Validate and update DESCRIPTION
git add .                         # Commit changes
git commit -m "Add tidymodels"
```

## Docker Environment

### Multi-Service Architecture
Docker Compose provides **multiple specialized environments**:

| Service | Purpose | Access |
|---------|---------|---------|
| `rstudio` | GUI development | http://localhost:8787 |
| `r-session` | R console | `make docker-r` |
| `bash` | Shell access | `make docker-bash` |
| `research` | Paper rendering | `make docker-render` |
| `test` | Package testing | `make docker-test` |
| `check` | Package validation | `make docker-check` |

### Docker Features
- **Automatic R version detection** from renv.lock
- **3-phase build process**: Bootstrap → renv init → production image
- **Persistent package cache** for faster rebuilds
- **Developer tools included**: vim, tmux, ripgrep, fzf, etc.
- **Dotfiles support**: Your `.vimrc`, `.zshrc`, etc. copied to container

### Docker Commands
```bash
# Build/rebuild environment
make docker-build

# Development environments  
make docker-rstudio              # RStudio GUI
make docker-r                    # R console
make docker-bash                 # Shell
make docker-zsh                  # Zsh shell

# Automated tasks
make docker-render               # Render paper
make docker-test                 # Run tests
make docker-check               # Validate package
make docker-check-renv          # Check dependencies

# Cleanup
make docker-clean               # Remove images and volumes
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

### Enhanced CI/CD with rrtools_plus Integration
ZZRRTOOLS provides **comprehensive GitHub Actions** with quality assurance and collaboration features:

#### 1. R Package Check (`.github/workflows/r-package.yml`)
- **Triggers**: Push/PR to main/master
- **Purpose**: Validate package structure and dependencies
- **Features**:
  - Native R setup (no Docker in CI)
  - renv synchronization validation
  - Package checks across platforms
  - Dependency validation with `check_renv_for_commit.R`

#### 2. Paper Rendering (`.github/workflows/render-paper.yml`)
- **Triggers**: Manual dispatch, changes to analysis files
- **Purpose**: Generate research paper automatically  
- **Features**:
  - Automatic PDF generation
  - Artifact upload
  - Native R environment (faster than Docker)

### CI/CD Features
- **Dependency validation**: Ensures all packages are properly declared
- **Cross-platform testing**: Ubuntu, macOS, Windows
- **Artifact management**: Automatic PDF upload
- **Fast execution**: Uses native R (not Docker) for speed

### Customization
Workflows are **optimized for local Docker development**:
- No Docker builds in CI (use local Docker instead)
- Focus on validation and paper rendering
- Minimal, fast execution
- Easy to customize for your needs

## Common Tasks

### Starting a New Analysis
```bash
# 1. Start development environment
make docker-rstudio

# 2. Create new analysis script
# In RStudio: File → New File → R Script
# Save as: scripts/01_data_exploration.R

# 3. Install needed packages
install.packages(c("tidyverse", "ggplot2"))

# 4. Write your analysis...

# 5. When done, snapshot environment
renv::snapshot()
```

### Rendering Your Paper
```bash
# Render paper to PDF
make docker-render

# View generated paper
open analysis/paper/paper.pdf
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
make docker-r

# 2. Create function file
# Edit R/my_function.R with your function

# 3. Document the function
devtools::document()

# 4. Test the function
devtools::load_all()
my_function(test_data)

# 5. Add unit tests
# Edit tests/testthat/test-my_function.R

# 6. Run tests
devtools::test()
```

### Managing Dependencies
```bash
# Install new packages
make docker-r
# In R: install.packages("new_package")
# In R: renv::snapshot()
# Exit R

# Validate dependencies
make docker-check-renv-fix

# Commit changes
git add .
git commit -m "Add new_package dependency"
```

## Collaboration

### Team Setup Workflow

#### Project Creator
```bash
# 1. Initial setup
zzrrtools                       # Creates structure, copies script
git init
git add .
git commit -m "Initial rrtools setup"
git remote add origin https://github.com/[TEAM]/project.git
git push -u origin main
```

#### Team Members
```bash
# 1. Clone and setup (one time)
git clone https://github.com/[TEAM]/project.git
cd project
zzrrtools                       # Script already in repo!

# 2. Start developing immediately
make docker-rstudio
```

### Ongoing Collaboration

#### Staying in Sync
```bash
# Daily sync routine
git pull                        # Get latest changes
make docker-build              # Rebuild environment if needed
# Continue development...
```

#### Adding New Packages
```bash
# Developer A adds packages
make docker-r
# install.packages("newpackage")
# renv::snapshot()
# exit
make docker-check-renv-fix      # Update DESCRIPTION
git add . && git commit -m "Add newpackage" && git push

# Developer B syncs
git pull                        # Gets renv.lock and DESCRIPTION updates
make docker-build              # Rebuilds with new packages
```

#### Conflict Resolution
- **renv.lock conflicts**: Use `renv::restore()` then `renv::snapshot()`
- **DESCRIPTION conflicts**: Use `make docker-check-renv-fix`
- **Analysis conflicts**: Standard Git merge resolution

### Team Guidelines
1. **Always run** `make docker-check-renv-fix` before committing
2. **Rebuild environment** after pulling: `make docker-build`
3. **Use semantic commit messages** for package changes
4. **Document new functions** with roxygen2 comments
5. **Add tests** for new functions

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
Solution: Use .dockerignore, clean up large files

# RStudio slow in browser
Solution: Check available RAM, close other containers

# Large repository
Solution: Use .gitignore for data files, Git LFS for large files
```

### Getting Help

1. **Check this guide** for common workflows
2. **Use `make help`** to see available targets
3. **Check script help**: `zzrrtools --help`
4. **Validate environment**: `make docker-check-renv`
5. **Clean and rebuild**: `make docker-clean && make docker-build`

### Advanced Configuration

#### Custom Docker Environment
```bash
# Modify Dockerfile for custom needs
# Rebuild: make docker-build

# Add custom R packages to setup_renv.R
# Rebuild: make docker-build
```

#### Custom Build Targets
```bash
# Add to Makefile:
my-analysis:
	docker run --rm -v $(PWD):/project $(PKG_NAME) Rscript scripts/my_analysis.R

.PHONY: my-analysis
```

#### Environment Variables
```bash
# Set in .env file or shell:
export RRTOOLS_AUTHOR_NAME="Your Name"
export RRTOOLS_AUTHOR_EMAIL="your.email@org.edu"
export RRTOOLS_BASE_PATH="/custom/path"
```

---

## Version History

### v4.0 - Modular Architecture (Current)
- **Modular Design**: 8 focused modules for enhanced maintainability
- **Uninstall Capability**: Complete cleanup with manifest tracking
- **Enhanced Logging**: Detailed progress tracking and module summaries
- **100% Backward Compatibility**: All existing workflows preserved
- **Safety Improvements**: Enhanced validation and error handling

### v3.0 - Previous Monolithic Version
- Single 812-line script implementation
- All functionality preserved in modular v4.0

### Migration from v3.0 to v4.0
- **No user changes required**: Same command-line interface and workflows
- **Enhanced capabilities**: Added uninstall, improved tracking, modular architecture
- **Preservation guarantee**: 100% functionality preservation from v3.0

## Architecture Information

### File Organization
```
zzrrtools/
├── zzrrtools.sh                    # Main entry point (modular v4.0)
├── zzrrtools-original.sh           # Backup of v3.0 monolithic version
├── modules/                        # Modular components
│   ├── core.sh                     # Foundation utilities
│   ├── templates.sh                # Template processing
│   ├── structure.sh                # Directory creation
│   ├── rpackage.sh                 # R package framework
│   ├── docker.sh                   # Container integration
│   ├── analysis.sh                 # Research templates
│   ├── cicd.sh                     # CI/CD workflows
│   └── devtools.sh                 # Development tools
└── templates/                      # All template files
    ├── ZZRRTOOLS_USER_GUIDE.md     # This documentation
    ├── zzrrtools-uninstall.sh      # Uninstall script template
    └── [template files...]
```

## Summary

ZZRRTOOLS v4.0 provides a **complete research environment** with integrated rrtools_plus enhancements:

### **Core Research Infrastructure**
- **Docker-first development** (no local R required)
- **Automatic dependency management** with renv
- **Professional collaboration tools** via Git/GitHub
- **Publication-ready workflows** from analysis to manuscript
- **Reproducible environments** across team members
- **Enterprise-grade reliability** with comprehensive error handling

### **Advanced Research Compendium Features** (rrtools_plus Integration)
- **Enhanced data management** with structured organization and validation frameworks
- **Automated quality assurance** via GitHub Actions CI/CD workflows
- **Professional collaboration** with research-specific templates and workflows
- **Academic publishing integration** with automated paper rendering and citation management
- **Comprehensive documentation** with data dictionaries and provenance tracking
- **Team-ready infrastructure** with issue templates and pull request workflows

### **Technical Excellence**
- **Modular architecture** (8 focused modules) for maintainability and extensibility
- **Complete uninstall capability** with manifest tracking for project cleanup
- **100% backward compatibility** with existing workflows and command-line interface
- **Platform compatibility** with ARM64/AMD64 support and container optimization

The framework integrates advanced research compendium capabilities while handling the technical complexity so you can **focus on your research**.