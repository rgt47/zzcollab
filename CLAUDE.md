# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

ZZCOLLAB is a research collaboration framework that creates Docker-based reproducible research environments. The system consists of:

### Core Components
- **Main executable**: `zzcollab.sh` - Primary framework script with integrated team initialization
- **Modular shell system**: `modules/` directory contains core functionality
- **Docker-first workflow**: All development happens in containers
- **R package structure**: Standard R package with testthat for testing
- **Template system**: `templates/` for project scaffolding

### Key Architecture Patterns
- **Modular design**: Shell scripts in `modules/` (core.sh, docker.sh, structure.sh, etc.)
- **Docker inheritance**: Team base images → personal development images
- **Automated CI/CD**: GitHub Actions for R package validation and image builds
- **Test-driven development**: Unit tests in `tests/testthat/`, integration tests expected
- **Environment monitoring**: Critical R options tracking with `check_rprofile_options.R`
- **CLI best practices**: One-letter flags for all major options (-i, -t, -p, -m, -d)

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

# CI/CD validation (matches GitHub Actions container workflows)
Rscript check_renv_for_commit.R --quiet --fail-on-issues  # Dependency validation
Rscript check_rprofile_options.R                          # R options monitoring

# Container-based CI commands (used in GitHub Actions)
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript check_renv_for_commit.R --quiet --fail-on-issues
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning')"
```

### Docker Development Environments
```bash
make docker-zsh            # Zsh shell with dotfiles (recommended)
make docker-rstudio        # RStudio Server at localhost:8787
make docker-r              # R console only
make docker-bash           # Bash shell
```

### Dependency Management
```bash
make check-renv            # Check renv status
make check-renv-fix        # Update renv.lock
make docker-check-renv     # Validate in container
Rscript check_renv_for_commit.R --quiet --fail-on-issues  # CI validation
Rscript check_renv_for_commit.R --fix --fail-on-issues    # Auto-fix missing packages
```

### Installation and Setup
```bash
# One-time zzcollab installation
./install.sh                    # Installs zzcollab to ~/bin
export PATH="$HOME/bin:$PATH"   # Add to shell config if needed
```

### Core Image Building Workflow
```bash
# Automated team setup (recommended) - handles all image building
zzcollab -i -t TEAM -p PROJECT [-d ~/dotfiles]
# OR with long flags: zzcollab --init --team-name TEAM --project-name PROJECT [--dotfiles ~/dotfiles]

# Fast setup with minimal packages and lightweight CI (5 vs 39 packages - faster initialization)
zzcollab -i -t TEAM -p PROJECT -m -d ~/dotfiles

# NEW: Separated Docker and package control (maximum flexibility - 6 combinations)
# Standard Dockerfile + minimal packages (lightweight packages with full Docker environment)
zzcollab -i -t TEAM -p PROJECT --minimal-packages -d ~/dotfiles

# Minimal Dockerfile + standard packages (fastest builds with comprehensive packages)
zzcollab -i -t TEAM -p PROJECT --minimal-docker -d ~/dotfiles

# Extended Dockerfile + minimal packages (comprehensive Docker with lightweight packages)
zzcollab -i -t TEAM -p PROJECT --extra-docker --minimal-packages -d ~/dotfiles


# Manual core image building (if needed)
cd /path/to/zzcollab
cp templates/Dockerfile.pluspackages ./Dockerfile.teamcore

# Build shell variant
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/r-ver \
    --build-arg TEAM_NAME="TEAM" \
    --build-arg PROJECT_NAME="PROJECT" \
    -t "TEAM/PROJECTcore-shell:v1.0.0" .

# Build RStudio variant
docker build -f Dockerfile.teamcore \
    --build-arg BASE_IMAGE=rocker/rstudio \
    --build-arg TEAM_NAME="TEAM" \
    --build-arg PROJECT_NAME="PROJECT" \
    -t "TEAM/PROJECTcore-rstudio:v1.0.0" .

# Push to Docker Hub
docker push "TEAM/PROJECTcore-shell:v1.0.0"
docker push "TEAM/PROJECTcore-rstudio:v1.0.0"
```

### Team Collaboration Setup
```bash
# Developer 1 (Team Lead) - Command Line
# Run from your preferred projects directory (e.g., ~/projects, ~/work)
cd ~/projects  # or wherever you keep your projects
zzcollab -i -t TEAM -p PROJECT [-d ~/dotfiles]
# Fast setup with minimal packages and lightweight CI: zzcollab -i -t TEAM -p PROJECT -m [-d ~/dotfiles]

# Developer 2+ (Team Members) - Command Line
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT
zzcollab -t TEAM -p PROJECT -I shell [-d ~/dotfiles]

# Note: Full mode includes 27 packages pre-installed, minimal mode has 8 essential packages
# Full: usethis, pkgdown, rcmdcheck, broom, lme4, survival, car, skimr, visdat, etc.
# Minimal: renv, remotes, devtools, usethis, here, conflicted, rmarkdown, knitr
```

### Separated Docker and Package Control (NEW)

ZZCOLLAB now supports independent control of Docker environments and R package sets for maximum flexibility. This provides 6 possible combinations instead of the previous 3.

#### Available Flags:
- `--minimal-docker`: Use Dockerfile.minimal (fastest builds, no R packages pre-installed)
- `--extra-docker`: Use Dockerfile.pluspackages (comprehensive package set pre-installed)
- `--minimal-packages`: Use DESCRIPTION.minimal (lightweight packages - 5 vs 39 packages)

#### All 6 Combinations:
```bash
# 1. Standard Dockerfile + Standard DESCRIPTION (default)
zzcollab -i -t TEAM -p PROJECT -d ~/dotfiles

# 2. Standard Dockerfile + Minimal DESCRIPTION (lightweight packages with full Docker)
zzcollab -i -t TEAM -p PROJECT --minimal-packages -d ~/dotfiles

# 3. Minimal Dockerfile + Standard DESCRIPTION (fastest builds with comprehensive packages)
zzcollab -i -t TEAM -p PROJECT --minimal-docker -d ~/dotfiles

# 4. Minimal Dockerfile + Minimal DESCRIPTION (fastest builds + lightweight packages)
zzcollab -i -t TEAM -p PROJECT --minimal-docker --minimal-packages -d ~/dotfiles

# 5. Extended Dockerfile + Standard DESCRIPTION (comprehensive Docker with full packages)
zzcollab -i -t TEAM -p PROJECT --extra-docker -d ~/dotfiles

# 6. Extended Dockerfile + Minimal DESCRIPTION (comprehensive Docker + lightweight packages)
zzcollab -i -t TEAM -p PROJECT --extra-docker --minimal-packages -d ~/dotfiles
```

#### Legacy Compatibility:
The existing `-m` flag is preserved and continues to work as before (minimal packages + minimal CI).

### R-Centric Workflow (Alternative)
```r
# Developer 1 (Team Lead) - R Interface
library(zzcollab)
init_project(
  team_name = "TEAM",
  project_name = "PROJECT", 
  dotfiles_path = "~/dotfiles"
)

# Developer 2+ (Team Members) - R Interface
library(zzcollab)
join_project(
  team_name = "TEAM",
  project_name = "PROJECT",
  interface = "shell",  # or "rstudio"
  dotfiles_path = "~/dotfiles"
)
```

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