# rrtools Framework User Guide v2.0

## Table of Contents
1. [What is rrtools?](#what-is-rrtools)
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
13. [R Interface Functions](#r-interface-functions)
14. [Common Tasks](#common-tasks)
15. [Collaboration](#collaboration)
16. [Troubleshooting](#troubleshooting)

## What is rrtools?

**rrtools** is a framework for creating **research compendia** - self-contained, reproducible research projects that combine:
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
# 1. Get rrtools.sh (one-time setup)
curl -fsSL https://raw.githubusercontent.com/your-org/rrtools/main/rrtools.sh -o rrtools.sh
chmod +x rrtools.sh

# 2. Create your project
cd your-project-directory
./rrtools.sh

# 3. Start developing immediately
make docker-rstudio  # → http://localhost:8787
# OR
make docker-r        # → R console in container
```

## Installation & Distribution

### One-Time Installation
```bash
# Install globally
curl -fsSL https://raw.githubusercontent.com/your-org/rrtools/main/install.sh | bash

# Then use anywhere
cd my-project
rrtools.sh
```

### Self-Replicating Strategy
rrtools.sh **copies itself** to each project automatically:
- Project creator runs `rrtools.sh` once
- Script copies itself to `./rrtools.sh` in the project
- When pushed to Git, collaborators get the script automatically
- No separate installation needed for team members

### Collaboration Workflow
```bash
# Collaborator workflow
git clone https://github.com/team/research-project
cd research-project
./rrtools.sh  # Script is already there!
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
./rrtools.sh
```

### Command-Line Options
```bash
./rrtools.sh [OPTIONS]

OPTIONS:
  --no-docker    Skip Docker image build during setup
  --help, -h     Show help message

EXAMPLES:
  ./rrtools.sh                                    # Full setup with Docker
  ./rrtools.sh --no-docker                       # Setup without Docker build
  RRTOOLS_AUTHOR_NAME="Jane Doe" ./rrtools.sh    # Custom author
```

### Safety Features
- **Input validation**: Package names sanitized and validated
- **Error handling**: Comprehensive error checking with graceful fallbacks
- **Backup creation**: Automatic backups before file overwrites
- **Docker validation**: Checks Docker availability before use
- **Permission checking**: Verifies write permissions before starting

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
./rrtools.sh                    # Creates structure + builds Docker image
```

#### Daily Development Cycle
```bash
# 1. Start development environment
make docker-rstudio            # → RStudio at http://localhost:8787
# OR
make docker-r                  # → R console
# OR  
make docker-bash               # → Shell access

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
Initialize a new zzcollab project from within R. **Note**: This is the R interface to `zzcollab-init-team` and should only be used by **Developer 1 (team lead)** to create the initial team infrastructure.

```r
# Developer 1: Complete team setup (creates team images + GitHub repo)
init_project(
  team_name = "rgt47", 
  project_name = "myproject"
)

# With dotfiles that already have dots
init_project(
  team_name = "rgt47",
  project_name = "myproject", 
  dotfiles_path = "~/dotfiles"
)

# With dotfiles that need dots added
init_project(
  team_name = "rgt47",
  project_name = "myproject",
  dotfiles_path = "~/Dropbox/dotfiles",
  dotfiles_nodots = TRUE
)
```

#### `join_project()`
Join an existing zzcollab project (for **Developers 2+**).

```r
# Join existing project with shell interface
join_project(
  team_name = "rgt47",
  project_name = "myproject", 
  interface = "shell",
  dotfiles_path = "~/dotfiles"
)

# Join with RStudio interface
join_project(
  team_name = "rgt47",
  project_name = "myproject",
  interface = "rstudio",
  dotfiles_path = "~/dotfiles"
)
```

**Command line alternative** for Developers 2+:
```bash
git clone https://github.com/rgt47/myproject.git
cd myproject
zzcollab --team rgt47 --project-name myproject --interface shell --dotfiles ~/dotfiles
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
render_report("analysis/paper/manuscript.Rmd")
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

### Example R Workflows

#### **Developer 1 (Team Lead) Workflow:**

```r
# Load zzcollab functions
library(zzcollab)

# 1. Initialize new team project (creates team infrastructure)
init_project(
  team_name = "mylab",
  project_name = "study2024",
  dotfiles_path = "~/dotfiles"
)

# Change to project directory
setwd("study2024")

# 2. Add required packages
add_package(c(
  "tidyverse", "brms", "targets", 
  "rmarkdown", "here"
))

# 3. Check environment status
status()
team_images()

# 4. Run analysis pipeline
run_script("scripts/01_data_import.R")
run_script("scripts/02_data_analysis.R") 
run_script("scripts/03_visualization.R")

# 5. Render final report
render_report("analysis/paper/paper.Rmd")

# 6. Validate reproducibility
validate_repro()

# 7. Sync environment for team
sync_env()
```

#### **Developers 2+ (Team Members) Workflow:**

```r
# Load zzcollab functions 
library(zzcollab)

# 1. Join the project (after cloning the repo)
join_project(
  team_name = "mylab",
  project_name = "study2024",
  interface = "shell",
  dotfiles_path = "~/dotfiles"
)

# 2. Sync with team environment
sync_env()

# 3. Add any additional packages needed for your analysis
add_package("specific_package_for_my_analysis")

# 4. Check team status
status()
team_images()

# 5. Run your analysis pipeline
run_script("scripts/my_analysis.R")

# 6. Render reports
render_report("analysis/my_section.Rmd")

# 7. Validate reproducibility before submitting PR
validate_repro()
```

### Integration with RStudio

These functions work seamlessly in RStudio:

```r
# Quick project setup from RStudio console (Developer 1)
init_project("myteam", "newproject")

# Join existing project (Developers 2+)  
join_project("myteam", "existingproject", "rstudio")

# Add packages interactively
add_package("package_name")

# Run scripts with progress in RStudio
run_script("my_analysis.R")

# Check status during development
status()
```

### Benefits of R Interface

- **Native R workflow**: No need to switch between R and terminal
- **RStudio integration**: Works seamlessly in RStudio environment  
- **Error handling**: R-style error messages and debugging
- **Return values**: Functions return logical values for programmatic use
- **Documentation**: Full R help system with `?status`
- **Type safety**: R parameter validation and type checking

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