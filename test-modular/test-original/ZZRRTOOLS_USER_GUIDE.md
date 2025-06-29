# ZZRRTOOLS Research Compendium Framework - User Guide v3.0

## Table of Contents
1. [What is ZZRRTOOLS?](#what-is-zzrrtools)
2. [Getting Started](#getting-started)
3. [Installation & Distribution](#installation--distribution)
4. [Configuration](#configuration)
5. [Directory Structure](#directory-structure)
6. [Navigation Shortcuts](#navigation-shortcuts)
7. [Workflow Overview](#workflow-overview)
8. [Development Environments](#development-environments)
9. [Package Management with renv](#package-management-with-renv)
10. [Docker Environment](#docker-environment)
11. [Build System with Make](#build-system-with-make)
12. [GitHub Actions CI/CD](#github-actions-cicd)
13. [Common Tasks](#common-tasks)
14. [Collaboration](#collaboration)
15. [Troubleshooting](#troubleshooting)

## What is ZZRRTOOLS?

**ZZRRTOOLS** is a framework for creating **research compendia** - self-contained, reproducible research projects that combine:
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

## Getting Started

### Prerequisites
- **Docker** (required for containerized workflow)
- **Git** (recommended for version control)
- **R & RStudio** (optional - can work entirely in Docker)

### Quick Start
```bash
# 1. One-time installation
git clone https://github.com/yourusername/zzrrtools.git
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
git clone https://github.com/yourusername/zzrrtools.git && cd zzrrtools && ./install.sh
```

### Method 2: Manual Installation
```bash
# Clone and create symlink manually
git clone https://github.com/yourusername/zzrrtools.git
cd zzrrtools
ln -s "$(pwd)/zzrrtools.sh" ~/bin/zzrrtools  # Adjust path as needed
```

### Method 3: Direct Download
```bash
# Download and install in one step
curl -fsSL https://raw.githubusercontent.com/yourusername/zzrrtools/main/install.sh | bash
```

### Project Creation Workflow
Each analysis project is **independent and self-contained**:

#### For Each New Analysis Project:
```bash
# Create and enter new project directory
mkdir my-climate-study
cd my-climate-study

# Set up complete research compendium
zzrrtools --dotfiles ~/dotfiles --base-image rgt47/r-pluspackages

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
git clone https://github.com/team/research-project
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
zzrrtools --dotfiles ~/dotfiles --base-image rgt47/r-pluspackages

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
  zzrrtools --base-image rgt47/r-pluspackages        # Use custom base image
  RRTOOLS_AUTHOR_NAME="Jane Doe" zzrrtools           # Custom author
```

### Safety Features
- **Input validation**: Package names sanitized and validated according to R package rules
- **Error handling**: Comprehensive error checking with graceful fallbacks
- **File protection**: Never overwrites existing files (preserves user modifications)
- **Docker validation**: Checks Docker availability before use
- **Permission checking**: Verifies write permissions before starting
- **Template validation**: Ensures all required templates exist before processing

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

### Docker-First Development Workflow

#### Initial Setup (One Time)
```bash
cd your-project
zzrrtools                       # Creates structure + builds Docker image
```

#### Daily Development Cycle
```bash
# 1. Start development environment
make docker-rstudio            # → RStudio at http://localhost:8787
# OR
make docker-r                  # → R console
# OR  
make docker-bash               # → Shell access
# OR
make docker-zsh                # → Zsh shell access

# 2. Do your analysis, install packages as needed
# 3. Exit container when done
exit

# 4. Validate dependencies before committing
make docker-check-renv-fix

# 5. Commit your work
git add .
git commit -m "Analysis update"
git push
```

#### Collaboration Sync
```bash
# When collaborators push changes
git pull                       # Get latest code
make docker-build             # Rebuild environment with new packages
# Continue development...
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

### Simplified Workflows
rrtools provides **streamlined GitHub Actions** for the Docker-first approach:

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
./rrtools.sh                    # Creates structure, copies script
git init
git add .
git commit -m "Initial rrtools setup"
git remote add origin https://github.com/team/project.git
git push -u origin main
```

#### Team Members
```bash
# 1. Clone and setup (one time)
git clone https://github.com/team/project.git
cd project
./rrtools.sh                    # Script already in repo!

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
3. **Check script help**: `./rrtools.sh --help`
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

## Summary

rrtools provides a **complete research environment** with:
- **Docker-first development** (no local R required)
- **Automatic dependency management** with renv
- **Professional collaboration tools** via Git/GitHub
- **Publication-ready workflows** from analysis to manuscript
- **Reproducible environments** across team members
- **Enterprise-grade reliability** with comprehensive error handling

The framework handles the technical complexity so you can **focus on your research**.