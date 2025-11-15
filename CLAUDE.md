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
- **Dynamic package management**: Packages added via `install.packages()` as needed, auto-captured on exit
- **Unified systems**: Single tracking, validation, and logging systems across all modules
- **Single source of truth**: Profile definitions in `bundles.yaml` eliminate duplication
- **14+ Docker profiles**: From lightweight Alpine (~200MB) to full-featured environments (~3.5GB)
- **Two-layer architecture**: Docker profiles (shared/team) + dynamic renv packages (personal/independent)

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

# Solo Developer with profile
zzcollab -r analysis -d ~/dotfiles

# Team Lead
zzcollab -t mylab -p study -r analysis -d ~/dotfiles
make docker-build && make docker-push-team && git add . && git commit -m "Initial project setup" && git push -u origin main

# Team Member
git clone https://github.com/mylab/study.git && cd study
zzcollab -u -d ~/dotfiles
make docker-sh
```

**R Interface**:
```r
library(zzcollab)

# Solo Developer
init_project("my-research")

# Team Lead
init_project(team_name = "mylab", project_name = "study")

# Team Member
join_project(team_name = "mylab", project_name = "study")
```

## CLI Flags and Conventions

ZZCOLLAB follows strict Unix CLI conventions with comprehensive short flag support for improved ergonomics.

### Short Flag Philosophy

**Lowercase by default**: All short flags use lowercase letters following Unix conventions
**Uppercase for variants**: Uppercase flags (`-D`, `-G`, `-P`) indicate semantic variants of their lowercase counterparts

### Complete Short Flag Reference

| Short | Long Flag          | Purpose                    | Usage Example           |
|-------|--------------------|----------------------------|-------------------------|
| `-a`  | `--tag`            | Docker image tag           | `zzcollab -a v2.1`      |
| `-b`  | `--base-image`     | Custom Docker base         | `zzcollab -b rocker/r-ver` |
| `-c`  | `--config`         | Configuration management   | `zzcollab -c init`      |
| `-d`  | `--dotfiles`       | Copy dotfiles (with dots)  | `zzcollab -d ~/dotfiles` |
| `-D`  | `--dotfiles-nodot` | Copy dotfiles (no dots)    | `zzcollab -D ~/dotfiles` |
| `-f`  | `--dockerfile`     | Custom Dockerfile path     | `zzcollab -f custom.df` |
| `-g`  | `--github-account` | GitHub account name        | `zzcollab -g myaccount` |
| `-G`  | `--github`         | Create GitHub repo         | `zzcollab -G`           |
| `-h`  | `--help`           | Show help                  | `zzcollab -h`           |
| `-k`  | `--pkgs`           | Package bundle             | `zzcollab -k tidyverse` |
| `-l`  | `--libs`           | Library bundle             | `zzcollab -l geospatial` |
| `-n`  | `--no-docker`      | Skip Docker build          | `zzcollab -n`           |
| `-p`  | `--project-name`   | Project name               | `zzcollab -p study`     |
| `-P`  | `--prepare-dockerfile` | Prepare without build  | `zzcollab -P`           |
| `-q`  | `--quiet`          | Quiet mode (errors only)   | `zzcollab -q`           |
| `-r`  | `--profile-name`   | Docker profile selection   | `zzcollab -r analysis`  |
| `-t`  | `--team`           | Team name                  | `zzcollab -t mylab`     |
| `-u`  | `--use-team-image` | Pull team Docker image     | `zzcollab -u`           |
| `-v`  | `--verbose`        | Verbose output             | `zzcollab -v`           |
| `-vv` | `--debug`          | Debug output + log file    | `zzcollab -vv`          |
| `-w`  | `--log-file`       | Enable log file            | `zzcollab -w`           |
| `-x`  | `--with-examples`  | Include example files      | `zzcollab -x`           |
| `-y`  | `--yes`            | Skip confirmations         | `zzcollab -y`           |

### Usage Comparison

**Before (verbose)**:
```bash
zzcollab --team mylab --project-name study --profile-name analysis --use-team-image --dotfiles ~/dotfiles
```

**After (concise)**:
```bash
zzcollab -t mylab -p study -r analysis -u -d ~/dotfiles
```

**Custom composition**:
```bash
# Verbose
zzcollab --base-image rocker/r-ver --libs geospatial --pkgs tidyverse

# Concise
zzcollab -b rocker/r-ver -l geospatial -k tidyverse
```

**With examples**:
```bash
# Clean workspace (default)
zzcollab -p myproject

# Include example files for learning
zzcollab -p myproject -x

# Add examples to existing project later
cd myproject
zzcollab --add-examples

# Set as default preference
zzcollab -c set with-examples true
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
zzcollab -c init                      # Create config file
zzcollab -c set team-name "myteam"    # Set values
zzcollab -c get team-name             # Get values
zzcollab -c list                      # List all configuration
```

**Key Configuration Domains**:
- **Docker Profile Management**: 14+ specialized environments (*see [Variants Guide](docs/VARIANTS.md)*)
- **Package Management**: Dynamic via `install.packages()`, auto-captured on container exit
- **Development Settings**: Team collaboration, dotfiles integration

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
zzcollab -t TEAM -p PROJECT -r PROFILE
```

## Package Management

ZZCOLLAB uses dynamic package management with **automatic snapshot-on-exit** architecture.

**Auto-Snapshot Architecture** (NEW):
- **No manual `renv::snapshot()` required**: Automatically runs on R exit via .Last() function
- **.Rprofile integration**: `.Last()` function in .Rprofile handles snapshot on R exit
- **RSPM timestamp optimization**: Temporarily adjusts renv.lock timestamp to "7 days ago" for binary package availability
  - Docker builds use binaries (10-20x faster) instead of compiling from source
  - Timestamp restored to "now" after validation (accurate git history)
- **Host validation without R**: Pure shell validation via `modules/validation.sh`

**Workflow** (Simplified):
```bash
make r                            # 1. Enter container → starts R directly
install.packages("tidyverse")    # 2. Add packages (standard R command)
# For GitHub: install.packages("remotes") then remotes::install_github("user/package")
q()                               # 3. Exit R → .Last() runs auto-snapshot + validation
# renv.lock automatically updated and validated!
git add renv.lock && git commit -m "Add tidyverse" && git push
```

**How It Works**:
- **Standard R commands**: Use familiar `install.packages()` - no renv commands needed for users
- **Docker profiles**: Control base Docker environment and pre-installed packages (team/shared)
- **Dynamic addition**: Team members add packages independently inside containers
- **Automatic snapshot**: Container exit hook runs `renv::snapshot()` (users don't need to call it)
- **Host validation**: Pure shell script validates DESCRIPTION ↔ renv.lock consistency
- **Auto-fix**: Automatically adds missing packages to DESCRIPTION and renv.lock (pure shell, no R!)
- **No host R required**: Entire workflow works without R installed on host machine

**Validation & Auto-Fix** (NEW):
```bash
make check-renv              # Validate + auto-fix (default: strict mode)
make check-renv-no-fix       # Validation only, no auto-add
make check-renv-no-strict    # Skip tests/ and vignettes/
```

**Complete Auto-Fix Pipeline**:
1. **Code → DESCRIPTION**: Detects `library()`, `require()`, `pkg::function()` usage
2. **DESCRIPTION → renv.lock**: Queries CRAN API for package metadata
3. **Pure shell tools**: curl (CRAN API) + jq (JSON) + awk (DESCRIPTION) + grep (extraction)
4. **Smart filtering**: Excludes placeholders, comments, documentation files (19 filters)
5. **Works on macOS/Linux**: BSD grep compatible (no Perl regex)

**Example Auto-Fix**:
```bash
# Add tibble::tibble() to your code
# Run validation
make check-renv

# Output:
# ✅ Added tibble to DESCRIPTION Imports
# ✅ Added tibble (3.3.0) to renv.lock
# ✅ All missing packages added

# Commit changes
git add DESCRIPTION renv.lock && git commit -m "Add tibble package"
```

**Configuration**:
```bash
# Disable auto-snapshot if needed
docker run -e ZZCOLLAB_AUTO_SNAPSHOT=false ...

# Disable RSPM timestamp adjustment
docker run -e ZZCOLLAB_SNAPSHOT_TIMESTAMP_ADJUST=false ...
```

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

**Package Validation (NO HOST R REQUIRED!)**:
```bash
make check-renv            # Full validation + auto-fix (strict mode, default)
make check-renv-no-fix     # Validation only, no auto-add
make check-renv-no-strict  # Standard mode (skip tests/, vignettes/)
```
**Auto-fixes**: Code → DESCRIPTION → renv.lock (pure shell: curl + jq + awk + grep)

**R Package Development**:
```bash
make test                    # Run R package tests
make docker-test            # Run tests in container
make check                  # R CMD check validation
```

**Docker Environments (Auto-snapshot on Exit)**:
```bash
make docker-sh             # Shell with dotfiles (recommended)
make docker-rstudio        # RStudio Server at localhost:8787
make docker-verse          # Verse environment with LaTeX
# All docker-* targets automatically:
#   1. Snapshot renv.lock on container exit
#   2. Validate packages on host (pure shell)
```

**Team Collaboration**:
```bash
# Team Lead
make docker-build          # Build team image
make docker-push-team      # Push to Docker Hub
git add . && git commit -m "Initial project setup" && git push

# Team Member
zzcollab --use-team-image  # Download team's Docker image
make docker-sh             # Start development
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
zzcollab -c init
zzcollab -c set team-name "myteam"
zzcollab -c set dotfiles-dir "~/dotfiles"

# 2. Create project
mkdir penguin-analysis && cd penguin-analysis
zzcollab

# 3. Daily development
make r              # Enter container
# ... work inside container ...
exit                # Exit container
make docker-test && git add . && git commit -m "Add analysis" && git push
```

### Transition to Team
```bash
# Convert solo project to team collaboration
zzcollab -t yourname -p penguin-analysis -r analysis -d ~/dotfiles
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
zzcollab_help("config")            # Configuration guide
```

## Version History

*For complete version history and changelog, see [CHANGELOG.md](CHANGELOG.md)*

**Current Version**: 2.0 (Unified Paradigm Release, 2025)

**Recent Major Changes**:

### November 15, 2025 - Dead Code Cleanup

**Code Quality Improvement**: Systematic removal of unused functions to improve maintainability

- **15 unused functions deleted**: Removed ~600-700 lines of dead code (9.7% reduction)
  - **Validation structure functions (6)**: validate_analysis_structure, validate_cicd_structure, validate_devtools_structure, validate_directory_structure, validate_r_package_structure, validate_with_callback
  - **CLI parsing functions (5)**: parse_base_image_list, parse_profile_list, validate_enum, check_team_image_availability, show_cli_debug
  - **Utility functions (4)**: safe_copy, create_development_scripts, parse_description_suggests (2 instances)
  - Functions were scaffolding that was never integrated into the workflow
  - All deletions verified with no broken references

- **Citation verification**: Fixed hallucinated reference in DOCKER_FIRST_MOTIVATION.Rmd
  - Removed non-existent @ram2019building citation
  - Corrected @nust2020practical metadata (Volume 111, 2021)
  - All 17 citations now verified against scholarly sources

- **Code reduced**: From 186 functions to 171 active functions
  - Improved code clarity and reduced maintenance burden
  - No functionality impacted - all deleted code was unused

### November 2, 2025 - Complete Auto-Fix Pipeline & Package Filtering

**Major Feature Addition**: Full automation of dependency management with intelligent filtering

- **Complete auto-fix pipeline**: Code → DESCRIPTION → renv.lock
  - Detects packages used in code via `library()`, `require()`, `pkg::function()`
  - Automatically adds to DESCRIPTION Imports (pure awk)
  - Automatically adds to renv.lock via CRAN API (curl + jq)
  - Single `make check-renv` command fixes entire dependency chain
  - Files: `modules/validation.sh` (lines 103-243, 871-923)

- **Pure shell DESCRIPTION editing**: NO R required!
  - add_package_to_description() uses awk to modify DESCRIPTION
  - add_package_to_renv_lock() queries crandb.r-pkg.org API
  - Creates proper JSON entries with jq
  - All operations atomic with temp file backups

- **macOS BSD grep compatibility** (CRITICAL FIX)
  - Problem: grep -P (Perl regex) not available on macOS
  - Solution: Replaced with grep -E (extended regex) + BSD patterns
  - Now works on macOS, Linux, CI/CD, all BSD systems
  - Files: `modules/validation.sh` (lines 283-333)

- **Comprehensive package filtering** (19 filters applied)
  - **Blocklist**: "package", "myproject", "local", "any", "zzcollab"
  - **Pattern-based**: Pronouns (my, your), generic nouns (file, path)
  - **Skip comments**: grep -v '^[[:space:]]*#' before extraction
  - **Skip documentation**: README.Rmd, examples/, CLAUDE.md
  - **Length filter**: Minimum 3 characters (removes "my", "an", "if")
  - Result: 84 → 65 packages (19 false positives removed)
  - Files: `modules/validation.sh` (lines 30-51, 302-333, 371-431)

- **Default strict + auto-fix behavior**
  - Changed defaults: strict_mode=true, auto_fix=true
  - Scans all directories including tests/, vignettes/
  - Auto-adds missing packages by default
  - Opt-out flags: --no-strict, --no-fix
  - Files: `modules/validation.sh` (lines 860-927)

**Updated Makefile targets**:
```bash
make check-renv            # Full validation + auto-fix (default)
make check-renv-no-fix     # Validation only
make check-renv-no-strict  # Skip tests/ and vignettes/
```

### November 5, 2025 - .Rprofile-Based Auto-Snapshot & Critical Options

**Major Architectural Simplification**: Replaced Docker entrypoint with R-native .Last() function

- **Auto-snapshot on R exit**: `.Last()` function in .Rprofile
  - Automatically runs `renv::snapshot()` when exiting R session
  - No manual snapshot commands required
  - R-native, reliable mechanism (no shell trap issues)
  - Applies when exiting R in any container
  - Configurable via environment variable (`ZZCOLLAB_AUTO_SNAPSHOT`)
  - Files: `templates/.Rprofile`

- **Critical reproducibility options**: Five options enforced in .Rprofile
  - `stringsAsFactors = FALSE`: Character vectors stay as characters
  - `contrasts = c("contr.treatment", "contr.poly")`: Statistical contrasts for models
  - `na.action = "na.omit"`: Missing data handling
  - `digits = 7`: Numeric precision
  - `OutDec = "."`: Decimal separator consistency
  - Monitored by `check_rprofile_options.R` (Pillar 3 of reproducibility)

- **Removed Docker entrypoint**: Deleted `zzcollab-entrypoint.sh`
  - Entrypoint trap approach was broken (`exec` replaces process)
  - .Last() is R-native and actually works
  - Containers now start R directly (CMD ["R"])
  - Navigation shortcuts remain on host (`navigation_scripts.sh`)

### October 27, 2025 - Docker-First Validation

**Major Architectural Improvement**: Complete elimination of host R dependency for development workflow

- **Pure shell validation** (`modules/validation.sh`): NO HOST R REQUIRED!
  - Package extraction from code: pure shell (grep, sed, awk)
  - DESCRIPTION parsing: pure shell (awk)
  - renv.lock parsing: jq (JSON)
  - Validates DESCRIPTION ↔ renv.lock consistency without R
  - New Makefile targets: `make check-renv`, `make check-renv-strict`
  - Runs automatically after all `docker-*` targets exit
  - Files: `modules/validation.sh`, `templates/Makefile`

- **Developer workflow transformation**:
  - **Before**: Developers needed R on host to run `Rscript validate_package_environment.R`
  - **After**: Entire development cycle works without host R installation
  - Workflow: `make r` → work in R → `q()` → auto-snapshot → auto-validate

**Earlier improvements** (same day):
- **Static template matching**: `select_dockerfile_strategy()` now checks resolved values against static templates
  - Prevents unnecessary custom generation when combination matches a static template
  - Works regardless of whether flags were explicitly provided or defaulted
  - Example: `zzcollab -b rocker/r-ver` now correctly uses static `Dockerfile.minimal`
- **Optional dotfiles**: All dotfiles now use wildcards in COPY commands
  - Docker builds no longer fail if dotfiles are missing
  - Expanded support: bash (`.bash_profile`), fish (`.config/fish`), emacs (`.emacs`, `.emacs.d`)
  - `.gitconfig` now optional (no need to copy personal config with credentials)
- **RSPM binary packages**: Fixed source compilation issue in Docker builds
  - Problem: renv.lock modification date was too recent for RSPM snapshot availability
  - Solution: Adjusted timestamp to ensure binary packages available (10-20x faster builds)
  - Integrated into auto-snapshot entrypoint for automatic timestamp management
  - Files: `modules/dockerfile_generator.sh`, `templates/Dockerfile.base.template`, `templates/Dockerfile.personal.team`, `modules/devtools.sh`, `templates/Makefile`

### Earlier October 2025
- Simplified user documentation - recommend `install.packages()` instead of `renv::install()`
- Dynamic package management with auto-snapshot on container exit
- Unified paradigm consolidation
- Docker profile system refactoring (September 2025)
- Five-level reproducibility framework
- CRAN compliance achievement
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
- Package management → Use `install.packages()` in containers (auto-captured on exit), see Package Management section above
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
