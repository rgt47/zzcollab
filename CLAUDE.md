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

# CI/CD validation (matches GitHub Actions)
Rscript check_renv_for_commit.R --quiet --fail-on-issues  # Dependency validation
Rscript check_rprofile_options.R                          # R options monitoring
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

## Testing Strategy

### R Package Tests
- **Unit tests**: `tests/testthat/test-*.R` for package functions
- **Integration tests**: Test complete analysis pipelines
- **CI validation**: GitHub Actions runs R CMD check + renv validation

### Critical Monitoring
- **R options tracking**: `check_rprofile_options.R` monitors analysis-critical settings
- **Dependency sync**: `check_renv_for_commit.R` ensures renv.lock consistency
- **Automated validation**: CI fails if critical changes detected

## Development Workflow

### Local Development
1. Use `make docker-zsh` for shell-based development with vim
2. Use `make docker-rstudio` for web-based RStudio interface
3. All package functions go in `R/` directory
4. Analysis scripts go in `scripts/` directory (template-guided)
5. Tests are mandatory for all functions and analysis steps

### Team Collaboration
1. **Team lead**: Runs `zzcollab --init` to create base images and project
2. **Team members**: Clone private repo and build personal development images
3. **Automated workflow**: CI/CD rebuilds team images when dependencies change
4. **Collaboration**: Single-repository workflow with pull requests and automated testing
5. **Documentation**: Complete workflow documented in `workflow.md`

### Docker Image Strategy
- **Team core images**: Public on Docker Hub (software only, no data)
- **Personal development images**: Local only (includes dotfiles)
- **Automated rebuilds**: GitHub Actions triggers on renv.lock changes
- **Multi-platform**: Supports AMD64 and ARM64 architectures

## Project Structure Conventions

### Standard Layout
```
├── R/                     # Package functions (exported to analysis)
├── analysis/             # Research outputs
│   ├── report/          # Main research report (report.Rmd → report.pdf)
│   ├── figures/         # Generated plots
│   ├── tables/          # Statistical tables
│   └── templates/       # Analysis templates
├── scripts/             # Analysis scripts (numbered sequence)
├── tests/               # Package tests (testthat framework)
│   ├── testthat/        # Unit tests for R functions
│   └── integration/     # Integration tests for analysis scripts
├── data/                # Data management
│   ├── raw_data/        # Original datasets
│   ├── derived_data/    # Processed datasets
│   ├── metadata/        # Data documentation
│   └── validation/      # Data quality checks
├── modules/             # Shell framework components (zzcollab only)
├── templates/           # Project scaffolding (zzcollab only)
└── Navigation scripts (optional: navigation_scripts.sh creates a, n, p, etc.)
```

### Key Files
- **install.sh**: Installation script that copies main executable to ~/bin
- **zzcollab.sh**: Main framework executable with integrated team initialization
- **R/utils.R**: R interface functions for complete R-centric workflow
- **workflow.md**: Complete team collaboration documentation (command-line + R interfaces)
- **ZZCOLLAB_USER_GUIDE.md**: Comprehensive user guide with R workflow examples
- **Dockerfile**: Container definition for development environment
- **docker-compose.yml**: Service configuration (auto-updated by CI)
- **renv.lock**: R dependency lockfile (triggers image rebuilds)
- **DESCRIPTION**: R package metadata
- **Makefile**: Development automation commands

## R Interface Functions

ZZCOLLAB provides a comprehensive R interface (`R/utils.R`) that allows developers to manage the entire research workflow from within R:

### Project Management Functions
- **`init_project()`**: Initialize new team project (Developer 1 only)
- **`join_project()`**: Join existing team project (Developers 2+)
- **`add_package()`**: Add R packages with automatic renv integration
- **`sync_env()`**: Synchronize R environment across team members

### Docker Environment Functions  
- **`status()`**: Check running zzcollab containers
- **`rebuild()`**: Trigger Docker image rebuild
- **`team_images()`**: List available team Docker images

### Analysis Workflow Functions
- **`run_script()`**: Execute R scripts in containers
- **`render_report()`**: Render analysis reports (analysis/report/report.Rmd)
- **`validate_repro()`**: Check project reproducibility

### Git and GitHub Integration Functions
- **`git_status()`**: Check git status from R
- **`create_branch()`**: Create feature branches
- **`git_commit()`**: Create commits with all changes
- **`git_push()`**: Push commits to GitHub  
- **`create_pr()`**: Create GitHub pull requests (key collaboration tool)

### R-Centric Development Workflow
1. **Setup Phase**: Use `init_project()` or `join_project()` 
2. **Development Phase**: Exit to containerized environment
3. **Analysis Phase**: All git operations from R using above functions
4. **Collaboration**: Use `create_pr()` to contribute back to main repository

## Automation Features

### Consolidated Team Initialization
- **Purpose**: Automates entire Developer 1 setup workflow
- **Replaces**: 10+ manual Docker and git commands
- **Creates**: Team core images, project structure, private GitHub repo
- **Usage**: `zzcollab --init --team-name TEAM --project-name PROJECT`
- **Benefits**: Reduces setup time from hours to minutes

### Automated Docker Image Management
- **Triggers**: Changes to renv.lock, DESCRIPTION, Dockerfile
- **Builds**: Multi-platform Docker images (AMD64, ARM64)
- **Publishes**: Updated images to Docker Hub automatically
- **Notifies**: Team members via GitHub commit comments
- **Documentation**: Complete workflow in `.github/workflows/update-team-image.yml`

### Zero-Friction Collaboration
- **Setup**: Single command team initialization
- **Development**: Automated environment consistency
- **Testing**: Comprehensive CI/CD with quality gates
- **Documentation**: Self-updating with automation status

## Important Development Notes

### Package Name Evolution
- **Former name**: zzrrtools → **Current name**: zzcollab
- Focus shifted from generic tools to research collaboration framework
- All branding and references updated to zzcollab

### Security Model
- **Private GitHub repos**: Protect unpublished research
- **Public Docker images**: Enable reproducible methodology sharing
- **No sensitive data**: Images contain only software packages and configurations

### Environment Consistency
- Docker-first development ensures identical environments across team
- Automated image management eliminates manual Docker operations
- renv.lock changes automatically trigger team image rebuilds
- Critical R options are monitored to prevent silent analysis changes

## CI/CD Pipeline

### Automated Quality Checks
- **R package validation**: R CMD check with dependency validation
- **Comprehensive testing**: Unit tests, integration tests, data validation
- **Critical monitoring**: R options tracking prevents silent analysis changes
- **Dependency sync**: renv validation ensures lockfile consistency
- **Multi-platform builds**: AMD64 and ARM64 Docker images

### Enterprise-Grade Team Image Management
- **Intelligent detection**: Monitors renv.lock, DESCRIPTION, Dockerfile changes
- **Automated rebuilds**: Multi-platform Docker images on package changes
- **Registry publishing**: Pushes updated images to Docker Hub automatically
- **Configuration updates**: Auto-updates docker-compose.yml references
- **Team notifications**: GitHub commit comments with usage instructions
- **Zero manual intervention**: Complete hands-off Docker image lifecycle

### Professional Collaboration Tools
- **Pull request templates**: Analysis impact assessment, reproducibility checklist
- **Issue templates**: Bug reports with environment details, feature requests
- **Automated workflows**: Fork-based collaboration with comprehensive testing
- **Documentation**: Self-updating workflow.md with automation status

## Recent Framework Improvements (2025)

### Script Consolidation (January 2025)
- **Consolidated initialization**: Merged `zzcollab-init-team` functionality into main `zzcollab.sh` script
- **Unified interface**: Single `--init` flag handles complete team setup workflow
- **Simplified installation**: Only one script to install and maintain
- **Improved UX**: Consistent command structure and error handling
- **Enhanced workflow**: Optional `--prepare-dockerfile` flag for customization workflow

### Package Ecosystem Refinement (January 2025)
- **Removed database packages**: Dropped DBI and RSQLite from default template for leaner core
- **Removed tutorial packages**: Removed tidytuesdayR and palmerpenguins to focus on core analysis tools
- **Maintained core functionality**: Kept essential packages for data analysis, visualization, and reporting
- **Updated documentation**: Modified workflow.md and external documentation to reflect package changes
- **Current package count**: 27 packages optimized for research workflows

### Enhanced CI/CD Templates
- **GitHub Actions optimization**: Fixed YAML syntax errors, removed problematic parameters
- **Dependency management**: Replaced setup-renv@v2 with setup-r-dependencies@v2 for better compatibility
- **Error handling**: Removed error-on parameter causing parsing failures
- **Caching improvements**: Added proper cache-version and timeout settings
- **Template validation**: All workflows now pass CI from project creation

### R Script Bug Fixes
- **check_renv_for_commit.R**: Fixed logical operator errors in configuration validation
- **Improved error handling**: Resolved `config && config` invalid type errors
- **Better flag parsing**: Proper use of `config$field` instead of bare `config` references
- **Enhanced CI reliability**: Script now runs without bootstrap errors in GitHub Actions
- **Auto-fix capability**: Added `--fix` flag documentation for automatic DESCRIPTION updates

### Expanded Package Ecosystem
- **Core development tools**: usethis, pkgdown, rcmdcheck for package development
- **Statistical analysis**: broom, lme4, survival, car for common research scenarios
- **Data quality tools**: skimr, visdat, naniar for data exploration and cleaning
- **Reproducibility stack**: targets, here, conflicted for workflow management
- **Reporting ecosystem**: rmarkdown, bookdown, knitr, DT for publication-ready outputs
- **Data connectivity**: jsonlite for diverse data sources
- **Pre-installed in Docker images**: 27 packages (vs 13 previously) for faster development

### Template Robustness
- **Minimal R package structure**: Removed template artifacts that confused users
- **Comprehensive .Rbuildignore**: Prevents project files from breaking R package builds
- **Clean test templates**: Simple package loading tests instead of complex examples
- **Better error messages**: Improved user experience during setup and development

### CI Debugging Lessons Applied
- **YAML syntax validation**: Proper quoting and parameter formatting
- **Dependency resolution**: Streamlined package installation in CI
- **Build optimization**: Faster CI runs through better caching and dependency management
- **Error prevention**: Template improvements prevent common CI failures

### Terminology Standardization (July 2025)
- **Unified naming convention**: Replaced all "paper" references with "report" throughout codebase
- **Directory structure**: `analysis/paper/` → `analysis/report/` for consistency
- **Template files**: `paper.Rmd` → `report.Rmd` across all templates and documentation
- **Configuration updates**: Updated Makefile, docker-compose.yml, and shell modules
- **Documentation alignment**: All references now use consistent "report" terminology
- **Benefits**: Eliminates confusion between academic papers and research reports

### Repository Cleanup (July 2025)
- **Git history optimization**: Removed accidentally committed R package cache files
- **Size reduction**: Cleaned up binary files and debug symbols from git history
- **Filter-branch cleanup**: Used git filter-branch to remove cache/ and binary/ directories
- **Force push**: Updated remote repository with cleaned history
- **Storage efficiency**: Improved repository performance and reduced clone times

### Module Loading Order Optimization (July 2025)
- **Problem**: Analysis module loaded during startup showed confusing warnings about missing directories
- **Root cause**: Analysis module checked for directories that structure module creates later
- **Solution**: Moved analysis module loading to occur after directory structure creation
- **Loading sequence**: Early modules (core, templates, structure, rpackage, docker, cicd, devtools) → create directories → load analysis module
- **User experience**: Eliminates misleading warnings during initialization process
- **Benefits**: Cleaner initialization output, reduced user confusion, logical dependency order

### check_renv_for_commit.R CI/CD Fixes (July 2025)
- **Problem**: GitHub Actions failing with `Error in config && config : invalid 'x' type in 'x && y'`
- **Root cause**: Boolean logic error where `config` object was used directly instead of checking specific fields
- **Solution**: Fixed all boolean expressions to use `config$field` syntax instead of bare `config` references
- **File improvements**: Added proper final newline to DESCRIPTION file to eliminate warnings
- **CI reliability**: Script now runs without type errors in GitHub Actions environment
- **Benefits**: Stable CI/CD pipeline, cleaner output, reliable dependency validation

### Navigation Scripts Replace Symbolic Links (July 2025)
- **Problem**: One-letter symbolic links (a, n, p, etc.) were causing `devtools::check()` to fail
- **Root cause**: R package builds don't handle symbolic links well in package structure
- **Solution**: Replaced symbolic link creation with `navigation_scripts.sh` generator
- **Implementation**: Creates shell scripts that use `exec "$SHELL"` to navigate directories
- **Usage**: Run `./navigation_scripts.sh` to create navigation shortcuts, then use `./a`, `./n`, etc.
- **Benefits**: Maintains convenient navigation while avoiding R package build conflicts

### Minimal Package Initialization (July 2025)
- **Performance optimization**: Added `--minimal` flag for faster project initialization
- **Package reduction**: Minimal mode installs 8 essential packages vs 27 in full mode
- **Time savings**: Reduces initialization time by ~70% (5-10 minutes → 2-3 minutes)
- **Iterative workflow**: Teams add packages incrementally through normal development process
- **Templates**: Created `Dockerfile.minimal` with core packages: renv, remotes, devtools, usethis, here, conflicted, rmarkdown, knitr
- **Usage**: `zzcollab -i -t mylab -p study -m` (short flags) or `zzcollab --init --team-name mylab --project-name study --minimal`
- **Benefits**: Faster setup for teams who prefer lean base images and iterative package addition

### One-Letter Flag Implementation (July 2025)
- **CLI best practices**: Added comprehensive one-letter flags for all major options
- **Improved UX**: Faster typing and more intuitive command structure following Unix conventions
- **Key mappings**: `-i` (--init), `-t` (--team-name), `-p` (--project-name), `-m` (--minimal), `-d` (--dotfiles)
- **Full compatibility**: All long flags continue to work alongside short flags
- **Mixed usage**: Can combine short and long flags in same command
- **Capital letters**: Used for variants: `-d` vs `-D` (dotfiles-nodot), `-I` (interface), `-P` (prepare-dockerfile)
- **Documentation**: Updated all help text, examples, and documentation with short flag usage
- **Benefits**: Faster team setup commands, better developer experience, industry-standard CLI interface

These improvements ensure new projects created with ZZCOLLAB have:
- ✅ Passing CI from day one
- ✅ Rich package ecosystem pre-installed (27 packages) or minimal setup (8 packages)
- ✅ Modern GitHub Actions best practices
- ✅ Clean, minimal R package structure
- ✅ Robust build and deployment workflows
- ✅ Consistent terminology throughout framework
- ✅ Optimized git history without unnecessary files
- ✅ Clean initialization process without confusing warnings
- ✅ Navigation scripts compatible with R package builds
- ✅ Unix-standard CLI with one-letter flags for improved developer experience
- ✅ Flexible initialization options for different team workflows