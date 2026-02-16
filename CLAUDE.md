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

This codebase values correctness and maintainability over politeness.

## Architecture Overview

ZZCOLLAB is a research collaboration framework that creates Docker-based reproducible research environments.

### Core Components

- **Main executable**: `zzcollab.sh` - Primary framework script
- **Modular shell system**: `modules/` (cli.sh, docker.sh, validation.sh, etc.) and `lib/` (core.sh, constants.sh)
- **Docker-first workflow**: All development happens in containers
- **R package structure**: Standard R package with testthat for testing
- **Template system**: `templates/` for project scaffolding
- **Profile system**: 14+ Docker profiles in `bundles.yaml`

### Documentation Structure

- **ZZCOLLAB_USER_GUIDE.md**: Comprehensive user documentation
- **docs/**: Technical guides
  - **TESTING_GUIDE.md**: Testing framework and best practices
  - **CONFIGURATION.md**: Multi-layered configuration system
  - **VARIANTS.md**: Docker profile system and customization
  - **DEVELOPMENT.md**: Developer commands and workflows
  - **DOCKER_ARCHITECTURE.md**: Docker technical details
  - **COLLABORATIVE_REPRODUCIBILITY.md**: Five Pillars model details
  - **DOCUMENTATION_STRATEGY.md**: Three-tier documentation system
- **CHANGELOG.md**: Complete version history

### Five Pillars of Reproducibility

ZZCOLLAB ensures reproducibility through five version-controlled components:

1. **Dockerfile** - R version, system dependencies, environment variables (LANG, TZ, OMP_NUM_THREADS)
2. **renv.lock** - Exact R package versions (source of truth)
3. **.Rprofile** - Critical R options (`stringsAsFactors`, `contrasts`, `na.action`, `digits`, `OutDec`)
4. **Source Code** - Analysis scripts, functions, reports, tests
5. **Research Data** - Raw data (read-only) and derived data with documentation

All five are required. See `docs/COLLABORATIVE_REPRODUCIBILITY.md` for details.

## Directory Structure

```
project/
├── analysis/
│   ├── data/
│   │   ├── raw_data/         # Original, unmodified data (read-only)
│   │   └── derived_data/     # Processed, analysis-ready data
│   ├── report/               # Manuscript (report.Rmd, references.bib)
│   ├── figures/              # Generated visualizations
│   └── scripts/              # Analysis code
├── R/                        # Reusable functions
├── tests/                    # Unit tests
├── .github/workflows/        # CI/CD automation
├── DESCRIPTION               # Project metadata
├── Dockerfile                # Computational environment
└── renv.lock                 # Package versions
```

## Quick Start Examples

```bash
# Solo Developer
zzcollab -r analysis

# Team Lead
zzcollab -t mylab -p study -r analysis
make docker-build && make docker-push-team

# Team Member
git clone https://github.com/mylab/study.git && cd study
zzcollab -u
make r
```

## CLI Reference

Run `zzcollab --help` for complete flag documentation. Key flags:

| Flag | Purpose |
|------|---------|
| `-t` | Team name |
| `-p` | Project name |
| `-r` | Docker profile (analysis, publishing, bioinformatics, etc.) |
| `-u` | Use team's Docker image |
| `-c` | Configuration management (`-c init`, `-c set key value`) |
| `-x` | Include example files |

## Configuration System

Multi-level hierarchy (highest priority first):
1. Project config (`./zzcollab.yaml`)
2. User config (`~/.zzcollab/config.yaml`)
3. System config (`/etc/zzcollab/config.yaml`)
4. Built-in defaults

```bash
zzcollab -c init                      # Create config
zzcollab -c set team-name "myteam"    # Set value
zzcollab -c list                      # List all
```

See `docs/CONFIGURATION.md` for details.

## Docker Profile System

14+ profiles available. See `docs/VARIANTS.md` for complete list.

**Categories**:
- **Standard**: minimal, analysis, modeling, publishing, shiny
- **Specialized**: bioinformatics, geospatial
- **Lightweight**: alpine_minimal, alpine_analysis, hpc_alpine
- **Testing**: rhub_ubuntu, rhub_fedora, rhub_windows

## Package Management

**Auto-snapshot/restore architecture** - no manual renv commands needed:

```bash
make r                           # Enter container, auto-restore if needed
install.packages("tidyverse")    # Standard R command
q()                              # Exit → auto-snapshot → auto-validate
```

**Host-based validation** (no R required):
```bash
make check-renv                  # Validate + auto-fix
make check-renv-no-fix           # Validation only
make check-system-deps           # Check system dependencies
```

Auto-fix pipeline: Code → DESCRIPTION → renv.lock (pure shell: curl + jq + awk)

## System Dependencies

Module `modules/profiles.sh` maps 80+ R packages to system libraries.

```bash
make check-system-deps           # Detect missing system deps
```

Covered packages: sf, terra, RPostgres, magick, xml2, and more. See module for full list.

## Development Workflows

**Package Development**:
```bash
make test                    # Run R package tests
make docker-test            # Run tests in container
make check                  # R CMD check validation
```

**Docker Environments**:
```bash
make r                     # Interactive R (recommended)
make rstudio               # RStudio Server at localhost:8787
```

**Navigation Shortcuts** (install via `./modules/navigation_scripts.sh --install`):
```bash
mr                         # make r from anywhere in project
mr test                    # make test from anywhere
r                          # Jump to project root
s                          # Jump to analysis/scripts/
```

See `docs/DEVELOPMENT.md` for complete commands.

## Companion Projects

- **zzvim-R** (https://github.com/rgt47/zzvim-R): Vim plugin for R with terminal graphics
- **zzrenvcheck** (https://github.com/rgt47/zzrenvcheck): R package for dependency validation

## R Package Integration

25 functions available. Key ones:

```r
init_project("my-research")                    # Solo project
init_project(team_name = "lab", project_name = "study")  # Team project
zzcollab_help()                                # Help system
```

## Version History

See `CHANGELOG.md` for complete version history.

**Current Version**: 2.0 (Unified Paradigm Release, 2025)

**Recent highlights**:
- December 2025: Test infrastructure simplification, LSP-ready Docker profiles
- November 2025: Auto-fix pipeline, .Rprofile-based auto-snapshot, documentation standardization
- October 2025: Docker-first validation (no host R required)

## Troubleshooting

### renv Initialization Errors

If you see `Error in if (script_config) { : the condition has length > 1`:
- Check renv.lock for consistency
- Run `renv::status()` to diagnose
- Try `renv::restore()` to rebuild environment
