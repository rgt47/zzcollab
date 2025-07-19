# ZZCOLLAB Framework User Guide v3.0

## Table of Contents
1. [What is ZZCOLLAB?](#what-is-zzcollab)
2. [Getting Started](#getting-started)
3. [Installation & Distribution](#installation--distribution)
4. [Team Collaboration Setup](#team-collaboration-setup)
5. [Directory Structure](#directory-structure)
6. [Navigation Shortcuts](#navigation-shortcuts)
7. [Development Environments](#development-environments)
8. [Package Management with renv](#package-management-with-renv)
9. [Docker Environment](#docker-environment)
10. [Build System with Make](#build-system-with-make)
11. [GitHub Actions CI/CD](#github-actions-cicd)
12. [R Interface Functions](#r-interface-functions)
13. [Team Collaboration Workflows](#team-collaboration-workflows)
14. [Common Tasks](#common-tasks)
15. [Troubleshooting](#troubleshooting)

## What is ZZCOLLAB?

**ZZCOLLAB** is a framework for creating **research compendia** with **enterprise-grade team collaboration** - self-contained, reproducible research projects that combine:
- R package structure for code organization
- Data management and documentation
- Analysis scripts and notebooks
- Manuscript preparation
- Docker containerization for reproducibility
- **Automated team collaboration workflows**
- **Zero-friction package management**
- **Professional Git/GitHub integration**

### Key Benefits
- **Team Collaboration**: Automated workflows for multiple developers
- **Reproducibility**: Anyone can recreate your analysis
- **Organization**: Clear structure for all project components
- **Publication**: Direct path from analysis to manuscript
- **Portability**: Works across different computing environments
- **Docker-first**: No local R installation required
- **Automated CI/CD**: Professional development workflows

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

# 2. Create team project (automated)
cd ~/projects                   # Your preferred projects directory
zzcollab -i -t mylab -p study2024 -d ~/dotfiles

# Fast setup with minimal packages for quick development (8 vs 27 packages)
zzcollab -i -t mylab -p study2024 -F -d ~/dotfiles

# Comprehensive setup with full package ecosystem (27+ packages)
zzcollab -i -t mylab -p study2024 -C -d ~/dotfiles


# Alternative: Auto-detect project name from directory
mkdir study2024 && cd study2024
zzcollab -i -t mylab -d ~/dotfiles

# Auto-detect with fast build mode
mkdir study2024 && cd study2024
zzcollab -i -t mylab -F -d ~/dotfiles

# Auto-detect with comprehensive build mode
mkdir study2024 && cd study2024
zzcollab -i -t mylab -C -d ~/dotfiles


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
# zzcollab -t mylab -p study2024 -I shell -C -d ~/dotfiles  # Comprehensive mode

# 3. Start developing immediately
make docker-zsh                # → Same environment as team lead
```

## Installation & Distribution

### One-Time Installation
```bash
# Clone and install globally
git clone https://github.com/your-org/zzcollab.git
cd zzcollab
./install.sh                   # Installs zzcollab and zzcollab --init to ~/bin

# Verify installation
which zzcollab                 # Should show ~/bin/zzcollab
which zzcollab --init       # Should show ~/bin/zzcollab --init
```

### Self-Replicating Team Strategy
ZZCOLLAB uses **automated team distribution**:
- Team lead runs `zzcollab --init` once
- Creates private GitHub repository with full project structure
- Team members clone and get everything automatically
- No separate installation needed for team members

### Team Collaboration Workflow
```bash
# Team member workflow
git clone https://github.com/mylab/study2024.git  # Private repo
cd study2024
zzcollab --team mylab --project-name study2024 --interface shell --dotfiles ~/dotfiles
```

## Team Collaboration Setup

### Developer 1 (Team Lead): Complete Project Initialization

#### Automated Approach (Recommended)
**Choose between command-line or R interface:**

**Option A: Command-Line Interface**
```bash
# Complete automated setup - replaces 10+ manual Docker and git commands
zzcollab -i -t mylab -p study2024 -d ~/dotfiles

# Fast setup with minimal packages for quick development (8 vs 27 packages)
zzcollab -i -t mylab -p study2024 -F -d ~/dotfiles

# Comprehensive setup with full package ecosystem (27+ packages)
zzcollab -i -t mylab -p study2024 -C -d ~/dotfiles


# OR auto-detect project name from current directory
mkdir study2024 && cd study2024
zzcollab -i -t mylab -d ~/dotfiles

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
- ✅ Creates project directory with complete R package structure
- ✅ Sets up customizable Dockerfile.teamcore for team's packages
- ✅ Builds shell and RStudio core images (multi-platform)
- ✅ Tags and pushes images to Docker Hub (public for reproducibility)
- ✅ Initializes zzcollab project with team base image
- ✅ Creates private GitHub repository
- ✅ Sets up initial commit with proper structure
- ✅ Configures automated CI/CD for team image management

### Developers 2+ (Team Members): Join Existing Project

**Choose between command-line or R interface:**

**Option A: Command-Line Interface**
```bash
# 1. Clone team repository (must be added as collaborator first)
git clone https://github.com/mylab/study2024.git
cd study2024

# 2. Join project with automated environment setup
zzcollab -t mylab -p study2024 -I shell -d ~/dotfiles
# OR for RStudio interface:
# zzcollab -t mylab -p study2024 -I rstudio -d ~/dotfiles
# Note: --project-name can be omitted if current directory name matches project

# 3. Start development immediately
make docker-zsh                # Shell interface with vim/tmux
# OR
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
zzcollab supports three build modes optimized for different use cases:

| Mode | Flag | Packages | Build Time | Use Case |
|------|------|----------|------------|----------|
| **Fast** | `-F` | ~8 packages | Fast | Quick development, CI/CD |
| **Standard** | `-S` (default) | ~15 packages | Medium | Balanced workflows |
| **Comprehensive** | `-C` | ~27 packages | Slow | Full feature environments |

```bash
# Build mode examples
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
ZZCOLLAB includes **enterprise-grade automated package management**:

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
Rscript check_renv_for_commit.R --fix --strict-imports --fail-on-issues

# With explicit build mode override
Rscript check_renv_for_commit.R --fix --build-mode fast --fail-on-issues

# Using environment variable for build mode detection
ZZCOLLAB_BUILD_MODE=comprehensive Rscript check_renv_for_commit.R --fix --fail-on-issues
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

### Multi-Service Architecture
Docker Compose provides **multiple specialized environments**:

| Service | Purpose | Access |
|---------|---------|---------|
| `zsh` | Enhanced shell development | `make docker-zsh` |
| `rstudio` | GUI development | http://localhost:8787 |
| `r-session` | R console | `make docker-r` |
| `bash` | Shell access | `make docker-bash` |
| `research` | Paper rendering | `make docker-render` |
| `test` | Package testing | `make docker-test` |
| `check` | Package validation | `make docker-check` |

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

# Development environments
make docker-zsh                 # Enhanced zsh with dotfiles (recommended)
make docker-rstudio             # RStudio GUI
make docker-r                   # R console
make docker-bash                # Shell

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

ZZCOLLAB includes sophisticated automated Docker image management that eliminates manual container maintenance while ensuring perfect environment consistency across research teams.

#### Complete GitHub Actions Workflow

The system automatically detects package changes, rebuilds Docker images, and notifies team members through a comprehensive GitHub Actions workflow:

**Key Features:**
- **Intelligent change detection**: Monitors `renv.lock`, `DESCRIPTION`, `Dockerfile`, `docker-compose.yml`
- **Multi-platform support**: AMD64 and ARM64 architectures
- **Advanced caching**: GitHub Actions cache with BuildKit optimization
- **Comprehensive tagging**: `latest`, `r4.3.0`, `abc1234`, `2024-01-15` tags
- **Automated configuration**: Updates docker-compose.yml references
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
      - 'docker-compose.yml'  # Service configuration changes
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
# ✅ GitHub Actions detects renv.lock changes
# ✅ Rebuilds image with tidymodels
# ✅ Pushes to mylab/study2024:latest on Docker Hub
# ✅ Updates docker-compose.yml
# ✅ Notifies team via commit comment
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
  - Dependency validation with `check_renv_for_commit.R --strict-imports`

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
  message("✅ Project is fully reproducible")
} else {
  message("❌ Reproducibility issues detected")
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

### Benefits of R Interface

- **Native R workflow**: No need to switch between R and terminal
- **RStudio integration**: Works seamlessly in RStudio environment
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

### Professional Collaboration Features

#### Automated Quality Assurance on Every Push
- ✅ **R Package Validation**: R CMD check with dependency validation
- ✅ **Comprehensive Testing Suite**: Unit tests, integration tests, and data validation
- ✅ **Paper Rendering**: Automated PDF generation and artifact upload
- ✅ **Multi-platform Testing**: Ensures compatibility across environments
- ✅ **Dependency Sync**: renv validation and DESCRIPTION file updates

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

---

## Summary

ZZCOLLAB provides a **complete research collaboration platform** with:

- **Enterprise-grade team collaboration** with automated workflows
- **Docker-first development** (no local R required)
- **Automatic dependency management** with renv and intelligent scanning
- **Professional collaboration tools** via Git/GitHub with CI/CD
- **Publication-ready workflows** from analysis to manuscript
- **Reproducible environments** across team members
- **Zero-friction package management** with automated team image updates
- **Comprehensive R interface** for R-centric workflows
- **Professional testing infrastructure** with unit and integration tests
- **Flexible initialization options** with minimal (8 packages) or full (27 packages) modes

### Automation Benefits

| Traditional Workflow | Automated ZZCOLLAB Workflow |
|----------------------|------------------------------|
| Manual image rebuilds | ✅ **Automatic rebuilds on package changes** |
| Inconsistent environments | ✅ **Guaranteed environment consistency** |
| 30-60 min setup per developer | ✅ **3-5 min setup with pre-built images** |
| Manual dependency management | ✅ **Automated dependency tracking** |
| Docker expertise required | ✅ **Zero Docker knowledge needed** |
| Build failures block development | ✅ **Centralized, tested builds** |
| Slow initialization (5-10 min) | ✅ **Fast minimal setup (2-3 min with --minimal)** |

### Developer Experience
- **Researchers focus on research** - not DevOps
- **Onboarding new team members** takes minutes, not hours
- **Package management** happens transparently
- **Environment drift** is impossible
- **Collaboration friction** eliminated entirely

The framework handles the technical complexity so you can **focus on your research** while maintaining **enterprise-grade collaboration standards** and **perfect reproducibility** across your entire research team.