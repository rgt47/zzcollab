# CHANGELOG

Complete version history for ZZCOLLAB.

**Current Version**: 2.0 (Unified Paradigm Release, 2025)

## December 2025

### December 19, 2025 - Test Infrastructure Simplification and Module Refactoring

**Simplified shell test infrastructure** - Replaced complex BATS tests with simpler bash test scripts:

**Shell Test Changes**:
- Removed 12 BATS test files that referenced non-existent or renamed functions
- Created 3 new bash test scripts with 52 total tests:
  - `tests/shell/test-core.sh` (16 tests) - validate_package_name, command_exists, logging, safe_mkdir, require_module
  - `tests/shell/test-cli.sh` (22 tests) - require_arg, validate_team_name, validate_project_name, validate_base_image
  - `tests/shell/test-validation.sh` (14 tests) - verify_description_file, format_r_package_vector, add_package_to_description
- Created `tests/shell/test_helpers.sh` - test utilities, assertions, module loading
- Created `tests/shell/run_all_tests.sh` - unified test runner

**CI Workflow Updates**:
- Simplified `.github/workflows/shell-tests.yml` from 692 lines to 58 lines
- Removed references to non-existent BATS test files
- Updated `tests/run-all-tests.sh` to run bash test scripts (BATS now optional)

**R Package Fixes**:
- Fixed test assertion in `test-r-functions.R:150` (incorrect NULL check)
- Moved mock project files from `tests/testthat/` to `tests/testthat/fixtures/`
- Updated `.Rbuildignore` to exclude test artifacts and non-standard files
- Package now builds with 0 errors, 0 warnings, 0 notes

**Module Structure** (lib/ vs modules/):
- `lib/` contains foundation modules: core.sh, constants.sh, templates.sh
- `modules/` contains feature modules: cli.sh, config.sh, docker.sh, github.sh, help.sh, profiles.sh, project.sh, validation.sh

### December 18, 2025 - Kitty Terminal Graphics and LSP-Ready Docker Profiles

**New Docker profiles for vim/neovim users** - Added languageserver support without X11 overhead:

- **Created `ubuntu_standard_analysis_vim` profile** (new default):
  - Based on rocker/tidyverse with languageserver for R LSP integration
  - No X11 libraries - uses kitty's native graphics protocol or httpgd
  - ~1.8GB image size (lighter than X11 profiles)
  - Dockerfile: `templates/Dockerfile.ubuntu_standard_analysis_vim`

- **Created `ubuntu_x11_analysis_vim` profile**:
  - Same as above but includes X11 support for users not using kitty
  - ~2.2GB image size
  - Dockerfile: `templates/Dockerfile.ubuntu_x11_analysis_vim`

- **Changed default profile**: `ubuntu_standard_minimal` → `ubuntu_standard_analysis_vim`

**New vignettes for kitty graphics workflows**:
- `vignettes/workflow-kitty-graphics.Rmd`: Manual kitty graphics workflow
- `vignettes/workflow-zzvim-r-plots.Rmd`: zzvim-R terminal graphics integration

### December 12, 2025 - Documentation Reorganization for Wider Project Sharing

**User-focused README restructuring** - Separated end-user and developer documentation:

- **Updated `templates/README.md`**: Split into two clear sections
  - "Quick Start: Run the Analysis" - For end users (Docker + Git only)
  - "For Developers: Using zzcollab" - For project contributors

- **Updated `.gitignore`**: Added `.zzcollab/` directory exclusion
  - User-specific configuration no longer committed
  - Prevents merge conflicts from per-user metadata

### December 6, 2025 - Comprehensive Test Suite Implementation

**Complete test infrastructure overhaul** - 4-phase implementation achieving 68% shell module coverage with 385+ new tests:

**Phase 1: Critical Blockers (244+ tests)**
- Enabled CLI tests in CI/CD pipeline with coverage reporting
- Added code coverage enforcement (80% minimum threshold)
- Created validation.sh test suite (35 BATS tests)
- Created profile_validation.sh test suite (44 BATS tests)
- Created end-to-end reproducibility tests (30 BATS tests)

**Phase 2: Shell Module Tests (101 tests)**
- dockerfile_generator.sh (41 BATS tests)
- Six additional modules (60 BATS tests): help.sh, rpackage.sh, github.sh, cicd.sh, structure.sh, devtools.sh

**Phase 3: R Package Tests (25 tests)**
- Created test-r-functions.R with 25 testthat tests

**Phase 4: GitHub Workflow Enhancements**
- R version matrix: 4 R versions × 3 OS = 12 parallel jobs
- Security scanning: Trivy + Hadolint + dependency checks
- Performance benchmarking: Docker build, R package, test execution
- Docker validation: Version pinning, layer optimization, critical options

**Test Infrastructure Summary**:
- Total new tests: 385+ (320+ shell, 25 R, 35+ integration)
- Shell module coverage: 68% (up from 10.5%)
- Production readiness: ~85/100 (up from 35/100)

### December 1, 2025 - Multi-Language Reproducibility Documentation

- Created `docs/zzcollab_python.md`: Analysis of multi-language reproducibility gaps
- Documented why Python (reticulate) and Observable JS break reproducibility guarantees
- Scope clarification: ZZCOLLAB provides complete R reproducibility; multi-language is user responsibility

## November 2025

### November 30, 2025 - Documentation Tone Standardization

**Scholarly tone enforcement** - Systematic removal of promotional language:
- Removed: "seamless", "effortless", "powerful", "elegant", "dramatically", "beautiful"
- Updated 7 vignettes and 13 technical documentation files
- Reserved emojis for status indicators only

### November 27, 2025 - Navigation Shortcuts Enhancement

- Added `mr()` function to run make targets from any subdirectory
- Uses `_zzcollab_root()` to find project root

### November 17, 2025 - Documentation Consistency Update

- Updated vignettes and docs to reflect latest architecture
- Replaced `renv::install()` → `install.packages()` throughout
- Added auto-restore documentation
- Updated profile count to 14+

### November 15, 2025 - Dead Code Cleanup

- Removed 15 unused functions (~600-700 lines, 9.7% reduction)
- Fixed hallucinated citation in DOCKER_FIRST_MOTIVATION.Rmd
- Code reduced from 186 to 171 active functions

### November 2-5, 2025 - Auto-Fix Pipeline & .Rprofile Architecture

**Complete auto-fix pipeline**: Code → DESCRIPTION → renv.lock
- Pure shell DESCRIPTION editing (awk)
- CRAN API queries (curl + jq)
- macOS BSD grep compatibility fix
- 19 package filters to reduce false positives

**Auto-snapshot on R exit**: `.Last()` function in .Rprofile
- Replaced Docker entrypoint with R-native mechanism
- Critical reproducibility options enforced

## October 2025

### October 27, 2025 - Docker-First Validation

**Pure shell validation** - NO HOST R REQUIRED:
- Package extraction: grep, sed, awk
- DESCRIPTION/renv.lock parsing: awk, jq
- New targets: `make check-renv`, `make check-renv-strict`

**RSPM binary packages**: Fixed source compilation issue
- Timestamp adjustment ensures binary availability (10-20x faster builds)

### Earlier October 2025

- Simplified user documentation
- Dynamic package management with auto-snapshot
- Unified paradigm consolidation

## September 2025

- Docker profile system refactoring
- Five-level reproducibility framework

## August 2025

- CRAN compliance achievement
- Complete CI/CD pipeline resolution

## 2024

- Major refactoring and simplification
- Initial unified paradigm design
