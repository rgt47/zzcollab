# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

ZZCOLLAB is a research collaboration framework that creates Docker-based reproducible research environments. The system consists of:

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
  - **DEVELOPMENT.md**: Developer commands and workflows
  - **DOCKER_ARCHITECTURE.md**: Docker technical details and custom images
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

### Five Pillars of Reproducibility

ZZCOLLAB ensures complete reproducibility through five version-controlled components that represent the necessary and sufficient elements for independent reproduction:

1. **Dockerfile** - Computational environment foundation
   - R version (e.g., 4.4.0)
   - System dependencies (GDAL, PROJ, libcurl, etc.)
   - Base image specification (rocker/verse, bioconductor, etc.)
   - **Environment variables** (LANG, LC_ALL, TZ, OMP_NUM_THREADS)
     - Locale settings affect string sorting, number formatting, factor ordering
     - Timezone eliminates daylight saving complications
     - Thread control ensures deterministic parallel execution
     - Silent effects require explicit specification

2. **renv.lock** - Exact R package versions (source of truth)
   - Every package with exact version
   - Complete dependency tree
   - CRAN/Bioconductor/GitHub sources
   - Contains packages from ALL team members (union model)

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

5. **Research Data** - Empirical foundation
   - Raw data (`analysis/data/raw_data/`) - original, unmodified, read-only
   - Derived data (`analysis/data/derived_data/`) - processed, analysis-ready
   - Data documentation (`data/README.md`) - data dictionary, provenance, processing lineage
   - Quality assurance - validation checks, known issues, outlier documentation

**Necessity and Sufficiency**: All five pillars are required for complete reproducibility:
- **Dockerfile** alone is insufficient (which packages? which code? which data?)
- **renv.lock** alone is insufficient (which R version? which data? which analysis?)
- **Source code** alone is insufficient (which packages? which environment? which data?)
- **Data** alone is insufficient (which processing? which environment? which packages?)
- **.Rprofile** alone is insufficient (provides session config but no analysis)

Only the complete set enables independent reproduction. Given these five components, any researcher can execute identical analyses and produce identical results.

**Key Design Principle**: Docker images provide foundation and performance (pre-installed base packages), but `renv.lock` is the source of truth for R package reproducibility. `.Rprofile` ensures consistent R session behavior. Environment variables prevent silent locale/timezone differences. Data provides the empirical observations. Anyone can reproduce analysis from ANY compatible Docker base by running `renv::restore()` with the committed `renv.lock` file.

**For comprehensive reproducibility documentation**, see `docs/COLLABORATIVE_REPRODUCIBILITY.md` which provides detailed explanation of the five-pillar model, environment variable impacts, union-based dependency management, and validation mechanisms.

## Unified Research Compendium Structure

ZZCOLLAB follows the unified research compendium framework proposed by Marwick, Boettiger, and Mullen (2018), providing a single flexible structure that supports the entire research lifecycle from data collection through analysis, manuscript writing, and package publication.

### Directory Structure

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
1. **Data Analysis** (Day 1): Place raw data, create scripts, generate figures
2. **Manuscript Writing** (Week 2): Add `analysis/paper/paper.Rmd`
3. **Function Extraction** (Month 1): Move reusable code to `R/` directory
4. **Package Distribution** (Month 3): Add documentation and vignettes

**Key Principle**: Research evolves organically. No upfront paradigm choice. No migration friction.

### Quick Start Examples

**Command Line**:
```bash
# Solo Developer
zzcollab -d ~/dotfiles

# Team Lead
zzcollab -t mylab -p study -d ~/dotfiles
make docker-build && make docker-push-team && git add . && git commit -m "Initial project setup" && git push -u origin main

# Team Member
git clone https://github.com/mylab/study.git && cd study
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh
```

**R Interface**:
```r
library(zzcollab)

# Solo Developer
init_project("my-research")

# Team Lead
init_project(team_name = "mylab", project_name = "study", build_mode = "standard")

# Team Member
join_project(team_name = "mylab", project_name = "study")
```

## Configuration System

ZZCOLLAB features a powerful multi-layered configuration system. *For comprehensive details, see [Configuration Guide](docs/CONFIGURATION.md)*

### Quick Configuration Reference

**Multi-Level Hierarchy** (highest priority first):
1. **Project config** (`./zzcollab.yaml`) - Team-specific settings
2. **User config** (`~/.zzcollab/config.yaml`) - Personal defaults
3. **System config** (`/etc/zzcollab/config.yaml`) - Organization-wide defaults
4. **Built-in defaults** - Fallback values

**Essential Commands**:
```bash
zzcollab --config init                      # Create config file
zzcollab --config set team-name "myteam"    # Set values
zzcollab --config get team-name             # Get values
zzcollab --config list                      # List all configuration
```

**Key Configuration Domains**:
- **Docker Profile Management**: 14+ specialized environments (*see [Variants Guide](docs/VARIANTS.md)*)
- **Package Management**: Build modes (Fast/Standard/Comprehensive) (*see [Build Modes Guide](docs/BUILD_MODES.md)*)
- **Development Settings**: Team collaboration, GitHub integration

## Docker Profile System

ZZCOLLAB supports **14+ specialized Docker profiles** with single source of truth architecture. *For comprehensive details, see [Variants Guide](docs/VARIANTS.md)*

**Profile Categories**:
- **Standard Research** (6): minimal, analysis, modeling, publishing, shiny, shiny_verse
- **Specialized Domains** (2): bioinformatics, geospatial
- **Lightweight Alpine** (3): alpine_minimal, alpine_analysis, hpc_alpine
- **R-Hub Testing** (3): rhub_ubuntu, rhub_fedora, rhub_windows

**Interactive Management**:
```bash
./add_profile.sh          # Browse and add profiles
vim config.yaml           # Edit team profiles
zzcollab -t TEAM -p PROJECT --profiles-config config.yaml
```

## Build Modes

ZZCOLLAB uses a simplified 4-mode system. *For comprehensive details, see [Build Modes Guide](docs/BUILD_MODES.md)*

**Four Build Modes**:
- **Minimal (-M)**: 3 packages, ~30 seconds (renv, remotes, here)
- **Fast (-F)**: 9 packages, 2-3 minutes (development essentials)
- **Standard (-S)**: 17 packages, 4-6 minutes (balanced, default)
- **Comprehensive (-C)**: 47+ packages, 15-20 minutes (full ecosystem)

## Data Documentation System

ZZCOLLAB includes automated data documentation templates following research best practices.

**Automated Templates**:
- `data/README.md`: Comprehensive template with Palmer Penguins example
- `DATA_WORKFLOW_GUIDE.md`: 6-phase data management workflow

**Key Benefits**:
- Standardized documentation with 13 structured sections
- Traceability between raw data, scripts, and derived datasets
- >90% test coverage requirements
- Docker workflow integration

## Development Workflows

*For comprehensive development commands, see [Development Guide](docs/DEVELOPMENT.md)*

### Quick Development Reference

**R Package Development**:
```bash
make test                    # Run R package tests
make docker-test            # Run tests in container
make check                  # R CMD check validation
Rscript validate_package_environment.R --quiet --fail-on-issues
```

**Docker Environments**:
```bash
make docker-zsh            # Zsh shell with dotfiles (recommended)
make docker-rstudio        # RStudio Server at localhost:8787
make docker-verse          # Verse environment with LaTeX
```

**Team Collaboration**:
```bash
# Team Lead
make docker-build          # Build team image
make docker-push-team      # Push to Docker Hub
git add . && git commit -m "Initial project setup" && git push

# Team Member
zzcollab --use-team-image  # Download team's Docker image
make docker-zsh            # Start development
```

## Docker Architecture

*For comprehensive Docker details, see [Docker Architecture Guide](docs/DOCKER_ARCHITECTURE.md)*

### Platform Compatibility Quick Reference

**ARM64 Compatible**: rocker/r-ver, rocker/rstudio
**AMD64 Only**: rocker/verse, rocker/tidyverse, rocker/geospatial, rocker/shiny

**ARM64 Solutions**:
```bash
# Use compatible base images
FROM rocker/rstudio:latest    # ARM64 compatible

# Or build custom ARM64 verse equivalent (see DOCKER_ARCHITECTURE.md)
```

## Solo Developer Workflow

ZZCOLLAB provides streamlined workflow for solo developers with professional-grade reproducibility.

### Quick Start
```bash
# 1. One-time setup
git clone https://github.com/rgt47/zzcollab.git && cd zzcollab && ./install.sh
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"

# 2. Create project
zzcollab -p penguin-analysis -d ~/dotfiles --github

# 3. Daily development
make docker-zsh     # Enter container
# ... work inside container ...
exit                # Exit container
make docker-test && git add . && git commit -m "Add analysis" && git push
```

### Transition to Team
```bash
# Convert solo project to team collaboration
zzcollab -t yourname -p penguin-analysis -d ~/dotfiles
make docker-build && make docker-push-team
git add . && git commit -m "Convert to team collaboration" && git push
```

## R Package Integration

Complete R interface with 25 functions:

**Configuration**: init_config(), set_config(), get_config(), list_config()
**Projects**: init_project(), join_project(), setup_project()
**Docker**: status(), rebuild(), team_images()
**Packages**: add_package(), sync_env()
**Analysis**: run_script(), render_report(), validate_repro()
**Git**: git_status(), git_commit(), git_push(), create_pr(), create_branch()

**Help System**:
```r
zzcollab_help()                    # Main help
zzcollab_help("quickstart")        # Quick start
zzcollab_help("workflow")          # Daily workflow
zzcollab_help("build-modes")       # Build mode selection
```

## Version History

*For complete version history and changelog, see [CHANGELOG.md](CHANGELOG.md)*

**Current Version**: 2.0 (Unified Paradigm Release, 2025)

**Recent Major Changes**:
- Unified paradigm consolidation (October 2025)
- Docker profile system refactoring (September 2025)
- Five-level reproducibility framework (October 2025)
- CRAN compliance achievement (October 2025)
- Complete CI/CD pipeline resolution (August 2025)
- Major refactoring and simplification (2024)

## Documentation Resources

ZZCOLLAB provides comprehensive documentation at multiple levels:

### User Documentation

- **ZZCOLLAB_USER_GUIDE.md**: Comprehensive user guide (v3.1)
  - Architecture overview and core components
  - Unified research compendium documentation
  - Configuration system with examples
  - Docker profile system and customization
  - Solo and team collaboration workflows

### Technical Guides (docs/)

**Definitive System Guides**:
- **BUILD_MODES.md** (22K): Build mode system documentation
- **TESTING_GUIDE.md** (26K): Testing framework and best practices
- **CONFIGURATION.md** (22K): Multi-layered configuration system
- **VARIANTS.md** (20K): Docker profile system guide
- **DEVELOPMENT.md** (10K): Developer commands and workflows
- **DOCKER_ARCHITECTURE.md** (8K): Docker technical details and custom images

**Research Motivation Documents**:
- **UNIT_TESTING_MOTIVATION_DATA_ANALYSIS.md** (39K): Scientific justification for testing
- **CICD_MOTIVATION_DATA_ANALYSIS.md** (21K): Evidence-based CI/CD rationale
- **RENV_MOTIVATION_DATA_ANALYSIS.md** (23K): Dependency management motivation
- **DOCKER_MOTIVATION_DATA_ANALYSIS.md** (33K): Container-based research rationale

**Architecture Documentation**:
- **IMPROVEMENTS_SUMMARY.md** (8.2K): Code quality improvements
- **MODULE_DEPENDENCIES.md** (3K): Module dependency mapping
- **R_PACKAGE_INTEGRATION_SUMMARY.md** (6.4K): R package integration details

**Version History**:
- **CHANGELOG.md**: Complete version history and all enhancements

### Documentation Cross-References

When working on zzcollab, refer users to:
- Build mode questions → `docs/BUILD_MODES.md`
- Testing implementation → `docs/TESTING_GUIDE.md`
- Configuration setup → `docs/CONFIGURATION.md`
- Profile customization → `docs/VARIANTS.md`
- Developer commands → `docs/DEVELOPMENT.md`
- Docker architecture → `docs/DOCKER_ARCHITECTURE.md`
- Version history → `CHANGELOG.md`
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
