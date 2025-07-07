# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

ZZCOLLAB is a research collaboration framework that creates Docker-based reproducible research environments. The system consists of:

### Core Components
- **Main executable**: `zzcollab.sh` - Primary framework script
- **Team automation**: `zzcollab-init-team` - Automated team setup script
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
```

### Installation and Setup
```bash
# One-time zzcollab installation
./install.sh                    # Installs zzcollab and zzcollab-init-team to ~/bin
export PATH="$HOME/bin:$PATH"   # Add to shell config if needed

# Automated team setup (recommended)
zzcollab-init-team --team-name TEAM --project-name PROJECT [--dotfiles ~/dotfiles]

# Manual project initialization
zzcollab --base-image team/project-core-shell --dotfiles ~/dotfiles
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
1. **Team lead**: Runs `zzcollab-init-team` to create base images and project
2. **Team members**: Clone private repo and build personal development images
3. **Automated workflow**: CI/CD rebuilds team images when dependencies change
4. **Collaboration**: Fork-based workflow with pull requests and automated testing
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
│   ├── paper/           # Manuscript files (paper.Rmd → paper.pdf)
│   ├── figures/         # Generated plots
│   └── tables/          # Statistical tables
├── scripts/             # Analysis scripts (numbered sequence)
├── tests/               # Package tests (testthat framework)
├── modules/             # Shell framework components
├── templates/           # Project scaffolding
└── Symbolic links (a→analysis, n→analysis, p→paper, etc.)
```

### Key Files
- **install.sh**: Installation script that copies both main executables to ~/bin
- **zzcollab.sh**: Main framework executable
- **zzcollab-init-team**: Automated team setup script  
- **workflow.md**: Complete team collaboration documentation
- **Dockerfile**: Container definition for development environment
- **docker-compose.yml**: Service configuration (auto-updated by CI)
- **renv.lock**: R dependency lockfile (triggers image rebuilds)
- **DESCRIPTION**: R package metadata
- **Makefile**: Development automation commands

## Automation Features

### zzcollab-init-team Script
- **Purpose**: Automates entire Developer 1 setup workflow
- **Replaces**: 10+ manual Docker and git commands
- **Creates**: Team core images, project structure, private GitHub repo
- **Usage**: `zzcollab-init-team --team-name TEAM --project-name PROJECT`
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