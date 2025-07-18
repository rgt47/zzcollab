# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

ZZCOLLAB is a research collaboration framework that creates Docker-based reproducible research environments. The system consists of:

### Core Components
- **Main executable**: `zzcollab.sh` - Primary framework script (439 lines, 64% reduction from original)
- **Modular shell system**: `modules/` directory contains core functionality
- **Docker-first workflow**: All development happens in containers
- **R package structure**: Standard R package with testthat for testing
- **Template system**: `templates/` for project scaffolding

### Key Architecture Patterns
- **Modular design**: Shell scripts in `modules/` (core.sh, cli.sh, docker.sh, structure.sh, etc.)
- **Docker inheritance**: Team base images → personal development images
- **Automated CI/CD**: GitHub Actions for R package validation and image builds
- **Test-driven development**: Unit tests in `tests/testthat/`, integration tests expected
- **Environment monitoring**: Critical R options tracking with `check_rprofile_options.R`
- **Simplified CLI**: 3 clear build modes with shortcuts (-F, -S, -C) replacing 8+ complex flags
- **Unified systems**: Single tracking, validation, and logging systems across all modules

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

# NEW: Simplified build modes (recommended approach)
# Fast mode: minimal Docker + lightweight packages (fastest setup)
zzcollab -i -t TEAM -p PROJECT -F -d ~/dotfiles

# Standard mode: balanced Docker + standard packages (default, recommended)
zzcollab -i -t TEAM -p PROJECT -S -d ~/dotfiles

# Comprehensive mode: extended Docker + full packages (kitchen sink)
zzcollab -i -t TEAM -p PROJECT -C -d ~/dotfiles

# Legacy: Fast setup with minimal packages (deprecated - use -F instead)
zzcollab -i -t TEAM -p PROJECT -m -d ~/dotfiles


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

# NEW: Simplified build modes (recommended)
zzcollab -i -t TEAM -p PROJECT -F -d ~/dotfiles     # Fast mode
zzcollab -i -t TEAM -p PROJECT -S -d ~/dotfiles     # Standard mode (default)
zzcollab -i -t TEAM -p PROJECT -C -d ~/dotfiles     # Comprehensive mode

# Legacy (deprecated): zzcollab -i -t TEAM -p PROJECT -m -d ~/dotfiles

# Developer 2+ (Team Members) - Command Line
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT
zzcollab -t TEAM -p PROJECT -I shell [-d ~/dotfiles]

# Note: Build modes comparison:
# Fast (-F): Minimal Docker + lightweight packages (fastest builds, 5 packages)
# Standard (-S): Balanced Docker + standard packages (recommended, 27 packages)
# Comprehensive (-C): Extended Docker + full packages (kitchen sink, 39+ packages)
```

### Simplified Build Modes (NEW)

ZZCOLLAB now uses a simplified 3-mode system that replaces the previous complex flag combinations. This provides clear, intuitive choices for users:

#### Build Modes:
- **Fast (-F)**: Minimal Docker + lightweight packages (fastest builds, 5 packages)
- **Standard (-S)**: Balanced Docker + standard packages (recommended, 27 packages)  
- **Comprehensive (-C)**: Extended Docker + full packages (kitchen sink, 39+ packages)

#### Legacy Compatibility:
The old flags (`-m`, `-x`, `--minimal-docker`, etc.) still work but show deprecation warnings. Users are encouraged to migrate to the new simplified modes.

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