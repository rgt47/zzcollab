# Developing validation.sh as a Standalone R Package

**Date**: November 15, 2025
**Author**: Analysis for zzcollab project
**Status**: Planning Document

---

## Executive Summary

This document outlines a comprehensive plan for developing the zzcollab `validation.sh` module (1,261 lines of sophisticated bash) as a standalone R package. The proposed package, **`zzrenvcheck`**, would validate R package dependencies across code, DESCRIPTION, and renv.lock files, ensuring reproducible environments for R projects.

**Key Innovation**: While the current shell implementation works without R on the host, the R package version will work within R environments while maintaining the same rigorous validation logic, with significant advantages in accessibility, distribution, and integration.

---

## Table of Contents

1. [Background & Motivation](#background--motivation)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Package Architecture](#package-architecture)
4. [Core API Design](#core-api-design)
5. [Implementation Approach](#implementation-approach)
6. [Feature Parity Analysis](#feature-parity-analysis)
7. [Advanced Features](#advanced-features)
8. [Testing Strategy](#testing-strategy)
9. [Documentation Plan](#documentation-plan)
10. [Release Roadmap](#release-roadmap)
11. [Advantages & Trade-offs](#advantages--trade-offs)
12. [Risks & Mitigations](#risks--mitigations)
13. [Next Steps](#next-steps)
14. [Recommendation](#recommendation)

---

## Background & Motivation

### The Problem

Research reproducibility depends on complete dependency documentation. Projects often suffer from:

- **Missing declarations**: Packages used in code but not in DESCRIPTION
- **Orphaned dependencies**: Packages in DESCRIPTION but not in renv.lock
- **Undocumented usage**: Package references scattered throughout code
- **Manual synchronization**: Time-consuming, error-prone workflow

### Current Solution: validation.sh

The zzcollab framework includes a sophisticated validation module (`modules/validation.sh`, 1,261 lines) that:

- Extracts package references from R code using pure shell tools
- Validates consistency across code → DESCRIPTION → renv.lock
- Auto-fixes missing packages by querying CRAN API
- Works entirely on the host without requiring R installation

### Why a Standalone R Package?

1. **Broader Audience**: Not limited to zzcollab users
2. **Easier Distribution**: Standard R package installation
3. **Better Integration**: RStudio addins, R workflows, IDE support
4. **Windows Support**: Shell script limited to macOS/Linux
5. **R Ecosystem Fit**: R developers expect R tools
6. **Community Maintenance**: Easier for R community to contribute

---

## Current Implementation Analysis

### Core Components (validation.sh)

The shell script implements six major subsystems:

#### 1. Package Extraction (Lines 370-414)

**Capabilities**:
- Scans R files for `library(pkg)`, `require(pkg)`, `pkg::function()`
- Extracts roxygen imports: `@importFrom pkg`, `@import pkg`
- Filters commented lines to avoid false positives
- Supports multiple file types: `.R`, `.Rmd`, `.qmd`, `.Rnw`

**Current Implementation**: Pure shell (grep, sed, awk)

**R Equivalent**: AST parsing with `codetools` or regex on `readLines()`

#### 2. Package Cleaning (Lines 452-512)

**Sophisticated Filtering** (19 filters applied):

1. **Length filter**: Minimum 3 characters (removes "my", "an", "if")
2. **Base packages**: utils, stats, graphics, etc.
3. **Placeholder blocklist**: "package", "myproject", "local", "any", "zzcollab"
4. **Pattern-based**: Pronouns (my, your), generic nouns (file, path)
5. **Skip comments**: Lines starting with `#`
6. **Skip documentation**: README.Rmd, examples/, CLAUDE.md
7. **Format validation**: `^[a-zA-Z][a-zA-Z0-9.]*$`
8. **Dot validation**: Cannot start or end with dot

**Current Implementation**: Pure bash string operations

**R Equivalent**: Similar logic with R string operations and regex

#### 3. DESCRIPTION Parsing (Lines 561-603)

**Capabilities**:
- Extracts Imports field from DESCRIPTION
- Handles multi-line continuation (DCF format)
- Removes version constraints: `pkg (>= 1.0.0)` → `pkg`
- Normalizes whitespace

**Current Implementation**: awk parser

**R Equivalent**: `desc` package (r-lib) or built-in `read.dcf()`

#### 4. renv.lock Parsing (Lines 800-816)

**Capabilities**:
- Extracts all package names from renv.lock JSON
- Provides source of truth for locked packages

**Current Implementation**: jq (JSON command-line tool)

**R Equivalent**: `jsonlite::fromJSON()`

#### 5. Auto-Fix Implementation (Lines 131-271)

**Two-Step Process**:

**Step 1: Add to DESCRIPTION** (Lines 131-201)
- Uses awk to modify DESCRIPTION Imports field
- Handles existing Imports and multi-line format
- Maintains proper indentation
- Creates backup before modification

**Step 2: Add to renv.lock** (Lines 212-271)
- Queries CRAN API: `https://crandb.r-pkg.org/{package}`
- Extracts version metadata from JSON response
- Creates package entry with jq
- Adds to renv.lock Packages section

**Current Implementation**: curl (CRAN API) + jq (JSON) + awk (DESCRIPTION)

**R Equivalent**: httr/curl + jsonlite + desc package

#### 6. Validation Logic (Lines 870-1067)

**Multi-Level Validation**:

1. **Code → DESCRIPTION**: Find packages in code but not declared
2. **DESCRIPTION → renv.lock**: Find declared packages not locked
3. **Unused Package Detection**: Find DESCRIPTION packages not used in code

**Auto-Fix Workflow**:
- Reports missing packages
- Optionally adds to DESCRIPTION
- Optionally adds to renv.lock via CRAN API
- Provides clear next steps for manual fixes

**Current Implementation**: Pure bash comparison logic

**R Equivalent**: Pure R comparison with clear reporting via `cli` package

---

## Package Architecture

### Proposed Package Name

**Primary Choice**: `zzrenvcheck`

**Alternatives**: `pkgcheck`, `depcheck`, `renvaudit`

**Rationale**: Clear, descriptive, follows R naming conventions

### Directory Structure

```
zzrenvcheck/
├── DESCRIPTION              # Package metadata
├── NAMESPACE                # Exported functions
├── LICENSE                  # MIT or GPL-3
├── README.md                # Installation and quick start
├── NEWS.md                  # Version history
├── .Rbuildignore            # Files to exclude from build
├── .gitignore               # Git ignore patterns
│
├── R/                       # R source code
│   ├── extract.R            # Package extraction from code
│   ├── clean.R              # Package name validation & filtering
│   ├── parse.R              # DESCRIPTION & renv.lock parsing
│   ├── compare.R            # Validation logic
│   ├── autofix.R            # Auto-fix implementation
│   ├── report.R             # User-facing reporting
│   ├── utils.R              # Helper functions
│   ├── config.R             # Configuration (base pkgs, filters)
│   └── zzrenvcheck-package.R  # Package documentation
│
├── man/                     # Generated documentation
│   ├── check_packages.Rd
│   ├── extract_code_packages.Rd
│   ├── fix_packages.Rd
│   └── ...
│
├── tests/                   # Test suite
│   └── testthat/
│       ├── test-extract.R
│       ├── test-clean.R
│       ├── test-parse.R
│       ├── test-compare.R
│       └── test-autofix.R
│
├── vignettes/               # Long-form documentation
│   ├── getting-started.Rmd
│   ├── workflow-integration.Rmd
│   └── advanced-usage.Rmd
│
└── inst/                    # Additional files
    ├── examples/            # Example projects for testing
    ├── extdata/             # Test fixtures
    └── rstudio/             # RStudio addin configuration
        └── addins.dcf
```

---

## Core API Design

### Primary Functions (User-Facing)

#### 1. Main Validation Function

```r
#' Check Package Dependencies
#'
#' Validates that all R packages used in code are properly declared in
#' DESCRIPTION and locked in renv.lock for reproducibility.
#'
#' @param strict Logical. If TRUE, scans tests/ and vignettes/ directories.
#'   Default: TRUE.
#' @param auto_fix Logical. If TRUE, automatically adds missing packages.
#'   Default: FALSE.
#' @param verbose Logical. If TRUE, lists all issues found. Default: TRUE.
#' @param path Character. Path to project root. Default: current directory.
#'
#' @return Invisibly returns a list with validation results
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic validation
#' check_packages()
#'
#' # Validation with auto-fix
#' check_packages(auto_fix = TRUE)
#'
#' # Non-strict mode (skip tests and vignettes)
#' check_packages(strict = FALSE)
#' }
check_packages <- function(strict = TRUE,
                           auto_fix = FALSE,
                           verbose = TRUE,
                           path = ".") {
  # Implementation
}
```

#### 2. Auto-Fix Function

```r
#' Fix Package Dependencies
#'
#' Automatically adds missing packages to DESCRIPTION and renv.lock.
#' This is a convenience wrapper around check_packages(auto_fix = TRUE).
#'
#' @inheritParams check_packages
#'
#' @return Invisibly returns a list with packages that were added
#' @export
#'
#' @examples
#' \dontrun{
#' # Fix all missing packages
#' fix_packages()
#'
#' # Fix with non-strict mode
#' fix_packages(strict = FALSE)
#' }
fix_packages <- function(strict = TRUE, path = ".") {
  check_packages(strict = strict, auto_fix = TRUE, path = path)
}
```

#### 3. Report Function

```r
#' Report Package Status
#'
#' Reports the current status of package dependencies without making changes.
#' Provides a clear summary of packages in code, DESCRIPTION, and renv.lock.
#'
#' @inheritParams check_packages
#'
#' @return A data frame with package status
#' @export
#'
#' @examples
#' \dontrun{
#' # View package status
#' status <- report_packages()
#' print(status)
#' }
report_packages <- function(strict = FALSE, path = ".") {
  # Implementation returns data frame:
  # - package: character
  # - in_code: logical
  # - in_description: logical
  # - in_renv_lock: logical
  # - status: "ok" | "missing_description" | "missing_lock" | "unused"
}
```

#### 4. Extract Packages Utility

```r
#' Extract Packages from Code
#'
#' Scans R source files for package references. Useful for understanding
#' what packages are actually used in your code.
#'
#' @param dirs Character vector of directory names to scan. Default:
#'   c("R", "scripts", "analysis").
#' @param path Character. Path to project root. Default: current directory.
#'
#' @return Character vector of package names
#' @export
#'
#' @examples
#' \dontrun{
#' # Extract from default directories
#' packages <- extract_code_packages()
#'
#' # Extract from specific directories
#' packages <- extract_code_packages(dirs = c("R", "inst"))
#' }
extract_code_packages <- function(dirs = c("R", "scripts", "analysis"),
                                   path = ".") {
  # Implementation
}
```

#### 5. Clean DESCRIPTION

```r
#' Clean Unused Packages from DESCRIPTION
#'
#' Removes packages from DESCRIPTION Imports that are not used in code.
#' This helps keep DESCRIPTION aligned with actual dependencies.
#'
#' @inheritParams check_packages
#'
#' @return Invisibly returns character vector of removed packages
#' @export
#'
#' @examples
#' \dontrun{
#' # Remove unused packages
#' clean_description()
#'
#' # Strict mode (check all directories)
#' clean_description(strict = TRUE)
#' }
clean_description <- function(strict = TRUE, path = ".") {
  # Implementation
}
```

### Secondary Functions (Developer-Facing)

#### Parse Functions

```r
#' Parse DESCRIPTION Imports
#'
#' Extracts package names from the Imports field of a DESCRIPTION file.
#'
#' @param path Character. Path to project root containing DESCRIPTION.
#'
#' @return Character vector of package names
#' @export
parse_description_imports <- function(path = ".") {
  # Uses desc::desc_get_deps() or read.dcf()
}

#' Parse renv.lock Packages
#'
#' Extracts package names from an renv.lock file.
#'
#' @param path Character. Path to project root containing renv.lock.
#'
#' @return Character vector of package names
#' @export
parse_renv_lock <- function(path = ".") {
  # Uses jsonlite::fromJSON()
}
```

#### Cleaning Functions

```r
#' Clean Package Names
#'
#' Validates and filters package names according to R naming rules
#' and common false positive patterns.
#'
#' @param packages Character vector of raw package names
#'
#' @return Character vector of validated package names
#' @export
clean_package_names <- function(packages) {
  # Implements 19 filters from validation.sh
}
```

#### CRAN API Functions

```r
#' Fetch CRAN Package Information
#'
#' Queries the CRAN API for package metadata.
#'
#' @param package Character. Package name.
#'
#' @return List with package information (Version, Repository, etc.)
#' @export
fetch_cran_info <- function(package) {
  # Queries https://crandb.r-pkg.org/{package}
  # Returns parsed JSON
}
```

#### Auto-Fix Helper Functions

```r
#' Add Package to DESCRIPTION
#'
#' Adds a package to the specified field in DESCRIPTION.
#'
#' @param package Character. Package name.
#' @param field Character. DESCRIPTION field. Default: "Imports".
#' @param path Character. Path to project root.
#'
#' @return Logical indicating success
#' @keywords internal
add_to_description <- function(package, field = "Imports", path = ".") {
  # Uses desc package
}

#' Add Package to renv.lock
#'
#' Adds a package entry to renv.lock.
#'
#' @param package Character. Package name.
#' @param version Character. Package version. If NULL, fetches from CRAN.
#' @param path Character. Path to project root.
#'
#' @return Logical indicating success
#' @keywords internal
add_to_renv_lock <- function(package, version = NULL, path = ".") {
  # Uses jsonlite to modify renv.lock
}
```

---

## Implementation Approach

### Required Dependencies

**Core Dependencies**:

```r
Imports:
    desc,        # DESCRIPTION file manipulation (r-lib)
    jsonlite,    # JSON parsing for renv.lock
    cli,         # Console output formatting
    rlang,       # Error handling and tidyeval
    httr         # CRAN API queries (or curl)
```

**Suggested Dependencies**:

```r
Suggests:
    fs,          # Cross-platform file operations
    withr,       # Safe temporary state changes
    codetools,   # Optional: AST-based detection
    renv,        # Optional: Direct renv integration
    testthat     # Testing framework
```

### Key Implementation Decisions

#### 1. Code Parsing Strategy

**Option A: Regex-based (Recommended for v0.1)**

**Advantages**:
- Fast, simple, well-tested in validation.sh
- Matches current behavior exactly
- No heavy dependencies

**Implementation**:
```r
extract_library_calls <- function(file) {
  lines <- readLines(file, warn = FALSE)

  # Remove comments
  lines <- lines[!grepl("^\\s*#", lines)]

  # Extract library() and require()
  lib_pattern <- "(library|require)\\s*\\(\\s*['\"]?([a-zA-Z][a-zA-Z0-9.]*)['\"]?\\s*\\)"
  lib_matches <- regmatches(lines, gregexpr(lib_pattern, lines, perl = TRUE))

  # Extract namespace calls (pkg::fn)
  ns_pattern <- "([a-zA-Z][a-zA-Z0-9.]*)::"
  ns_matches <- regmatches(lines, gregexpr(ns_pattern, lines, perl = TRUE))

  # Extract roxygen imports
  roxygen_pattern <- "#'\\s*@importFrom\\s+([a-zA-Z0-9.]+)"
  roxygen_matches <- regmatches(lines, gregexpr(roxygen_pattern, lines, perl = TRUE))

  # Combine and clean
  # ...
}
```

**Option B: AST-based (Future Enhancement)**

**Advantages**:
- More robust, handles complex R code
- Catches runtime dependencies
- Can detect conditionally loaded packages

**Implementation**:
```r
extract_with_ast <- function(file) {
  # Parse R code into AST
  expr <- parse(file)

  # Use codetools::findGlobals() to find package references
  # More sophisticated but slower
}
```

**Recommendation**: Start with **regex** (proven approach), add AST as optional "strict_ast" mode in v0.2

#### 2. DESCRIPTION Manipulation

**Use `desc` package** (by Gábor Csárdi, r-lib):

```r
library(desc)

# Read DESCRIPTION
d <- desc::description$new()

# Get dependencies
imports <- d$get_deps()
imports[imports$type == "Imports", "package"]

# Add dependency
d$set_dep("dplyr", type = "Imports")

# Write changes
d$write()
```

**Advantages**:
- Battle-tested in r-lib ecosystem
- Handles DCF format correctly
- Maintains file formatting
- Clear API

#### 3. CRAN API Integration

**Current shell implementation**: `https://crandb.r-pkg.org/{package}`

**R implementation**:

```r
fetch_cran_info <- function(package) {
  url <- paste0("https://crandb.r-pkg.org/", package)

  resp <- httr::GET(url)

  if (httr::http_error(resp)) {
    cli::cli_alert_danger(
      "Package {.pkg {package}} not found on CRAN"
    )
    return(NULL)
  }

  content <- httr::content(resp, as = "text", encoding = "UTF-8")
  jsonlite::fromJSON(content)
}
```

**Error Handling**:
- Package not found → graceful error message
- Network error → retry with backoff
- API rate limiting → cache responses

#### 4. User Interface with `cli`

**Formatted output with colors and symbols**:

```r
library(cli)

# Success messages
cli_alert_success("All packages properly declared")

# Warnings
cli_alert_warning("Found {length(missing)} missing packages")

# Errors
cli_alert_danger("DESCRIPTION file not found")

# Information
cli_alert_info("Auto-fixing dependencies...")

# Progress
cli_progress_bar("Scanning files", total = length(files))
```

**Example validation output**:

```
ℹ Validating package dependencies...
ℹ Scanning for R files in: R, scripts, analysis
✔ Found 15 packages in code
✔ Found 12 packages in DESCRIPTION Imports
✔ Found 12 packages in renv.lock

✖ Found 3 packages used in code but not in DESCRIPTION Imports

  • dplyr
  • ggplot2
  • tidyr

ℹ Auto-fixing: Adding missing packages to DESCRIPTION and renv.lock...
✔ Added dplyr to DESCRIPTION Imports
✔ Added dplyr (1.1.4) to renv.lock
✔ Added ggplot2 to DESCRIPTION Imports
✔ Added ggplot2 (3.4.4) to renv.lock
✔ Added tidyr to DESCRIPTION Imports
✔ Added tidyr (1.3.0) to renv.lock

✔ All missing packages added

Next steps:
  1. Rebuild Docker image: make docker-build
  2. Commit changes: git add DESCRIPTION renv.lock && git commit
```

---

## Feature Parity Analysis

Comparison between `validation.sh` and proposed R package:

| Feature | validation.sh | R Package | Implementation Notes |
|---------|---------------|-----------|---------------------|
| **Package Detection** |
| Extract from `library()` | ✅ | ✅ | Regex on `readLines()` |
| Extract from `require()` | ✅ | ✅ | Same as above |
| Extract from `pkg::fn()` | ✅ | ✅ | Regex for `::` pattern |
| Extract from `@importFrom` | ✅ | ✅ | Roxygen comment parsing |
| Extract from `@import` | ✅ | ✅ | Roxygen comment parsing |
| **Filtering** |
| 19 package filters | ✅ | ✅ | Port blocklists exactly |
| Base package exclusion | ✅ | ✅ | Same BASE_PACKAGES list |
| Placeholder filtering | ✅ | ✅ | Same PLACEHOLDER_PACKAGES |
| Pattern-based filtering | ✅ | ✅ | Generic word detection |
| Length filter (min 3) | ✅ | ✅ | Removes "my", "an", etc. |
| Format validation | ✅ | ✅ | R package naming rules |
| **Parsing** |
| Parse DESCRIPTION | ✅ (awk) | ✅ (desc) | More robust with `desc` |
| Handle multi-line DCF | ✅ | ✅ | `desc` handles natively |
| Remove version constraints | ✅ | ✅ | `desc` API |
| Parse renv.lock | ✅ (jq) | ✅ (jsonlite) | Native R |
| **Auto-Fix** |
| Add to DESCRIPTION | ✅ (awk) | ✅ (desc) | Safer with `desc` |
| Add to renv.lock | ✅ (jq+curl) | ✅ (jsonlite+httr) | Native R |
| Query CRAN API | ✅ (curl) | ✅ (httr) | Native R |
| Atomic file updates | ✅ (temp files) | ✅ (desc + withr) | Safe modification |
| **Validation Modes** |
| Strict mode | ✅ | ✅ | Same logic |
| Standard mode | ✅ | ✅ | Same directories |
| Verbose mode | ✅ | ✅ | Enhanced with `cli` |
| Auto-fix mode | ✅ | ✅ | Same behavior |
| **Cleanup** |
| Remove unused packages | ✅ | ✅ | Same logic |
| Protect renv package | ✅ | ✅ | Same protection |
| **Platform Support** |
| macOS | ✅ | ✅ | Both work |
| Linux | ✅ | ✅ | Both work |
| Windows | ❌ | ✅ | **R package advantage** |
| **Requirements** |
| Works without R | ✅ | ❌ | Shell advantage |
| Requires jq | ✅ | ❌ | R has jsonlite |
| Requires bash | ✅ | ❌ | R is cross-platform |

**Summary**: The R package achieves feature parity with enhanced cross-platform support and better integration, at the cost of requiring R (which most users already have).

---

## Advanced Features

Features beyond current `validation.sh` capabilities:

### 1. Pre-commit Hook Integration

**Automatic validation before commits**:

```r
#' Install Pre-Commit Hook
#'
#' Installs a git pre-commit hook that runs package validation.
#'
#' @param strict Logical. Use strict mode in hook.
#' @param auto_fix Logical. Auto-fix issues in hook.
#' @param path Character. Path to git repository.
#'
#' @export
use_zzrenvcheck_hook <- function(strict = TRUE,
                                auto_fix = FALSE,
                                path = ".") {
  hook_path <- file.path(path, ".git", "hooks", "pre-commit")

  hook_content <- sprintf('#!/bin/sh
Rscript -e "zzrenvcheck::check_packages(strict = %s, auto_fix = %s)"
', strict, auto_fix)

  writeLines(hook_content, hook_path)
  Sys.chmod(hook_path, mode = "0755")

  cli::cli_alert_success("Pre-commit hook installed")
}
```

### 2. CI/CD Integration Templates

**GitHub Actions workflow**:

```r
#' Generate GitHub Actions Workflow
#'
#' Creates a .github/workflows/check-packages.yaml file.
#'
#' @param path Character. Path to repository root.
#'
#' @export
use_github_action <- function(path = ".") {
  workflow <- '
name: Check Package Dependencies

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  check-deps:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2
      - name: Install zzrenvcheck
        run: |
          install.packages("remotes")
          remotes::install_github("username/zzrenvcheck")
        shell: Rscript {0}
      - name: Check dependencies
        run: zzrenvcheck::check_packages(auto_fix = FALSE)
        shell: Rscript {0}
'

  dir.create(file.path(path, ".github", "workflows"),
             recursive = TRUE, showWarnings = FALSE)

  writeLines(workflow,
             file.path(path, ".github", "workflows", "check-packages.yaml"))

  cli::cli_alert_success("GitHub Action created")
}
```

### 3. RStudio Addin

**GUI interface for validation**:

**File**: `inst/rstudio/addins.dcf`
```
Name: Check Package Dependencies
Description: Validate package dependencies across code, DESCRIPTION, and renv.lock
Binding: rstudio_check_packages
Interactive: true
```

**Implementation**:
```r
#' RStudio Addin: Check Packages
#'
#' Interactive RStudio addin for package validation.
#'
#' @keywords internal
rstudio_check_packages <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE)) {
    stop("RStudio required for this addin")
  }

  # Get active project
  proj <- rstudioapi::getActiveProject()

  # Show dialog
  result <- rstudioapi::showQuestion(
    title = "Check Package Dependencies",
    message = "Validate package dependencies?",
    ok = "Check",
    cancel = "Cancel"
  )

  if (!result) return(invisible())

  # Run validation
  check_packages(path = proj, verbose = TRUE)
}
```

### 4. Configuration File Support

**`.zzrenvcheck.yaml` in project root**:

```yaml
# Package validation configuration
strict: true
auto_fix: false

# Directories to scan (default: R, scripts, analysis)
scan_dirs:
  - R
  - scripts
  - analysis
  - src

# Additional directories in strict mode
strict_dirs:
  - tests
  - vignettes

# Directories to exclude
exclude_dirs:
  - deprecated
  - scratch
  - old

# Custom package filters (in addition to defaults)
custom_filters:
  - myproject
  - internal
  - deprecated

# Protected packages (never remove from DESCRIPTION)
protected_packages:
  - renv
  - devtools
```

**Loading configuration**:

```r
load_config <- function(path = ".") {
  config_file <- file.path(path, ".zzrenvcheck.yaml")

  if (file.exists(config_file)) {
    yaml::read_yaml(config_file)
  } else {
    list()  # Use defaults
  }
}
```

### 5. Bioconductor Support

**Query Bioconductor for packages not on CRAN**:

```r
fetch_bioc_info <- function(package) {
  # Try CRAN first
  info <- fetch_cran_info(package)
  if (!is.null(info)) return(info)

  # Try Bioconductor
  url <- paste0(
    "https://bioconductor.org/packages/json/3.18/bioc/packages/",
    package
  )

  resp <- httr::GET(url)

  if (httr::http_error(resp)) {
    return(NULL)
  }

  content <- httr::content(resp, as = "text", encoding = "UTF-8")
  info <- jsonlite::fromJSON(content)

  # Format to match CRAN structure
  list(
    Package = info$Package,
    Version = info$Version,
    Repository = "Bioconductor",
    Source = "Repository"
  )
}
```

### 6. GitHub Package Detection

**Detect and add GitHub packages**:

```r
#' Add GitHub Package
#'
#' Adds a GitHub package to DESCRIPTION and renv.lock.
#'
#' @param repo Character. GitHub repository in format "user/repo".
#' @param ref Character. Git ref (branch, tag, or SHA). Default: "HEAD".
#' @param path Character. Path to project root.
#'
#' @export
add_github_package <- function(repo, ref = "HEAD", path = ".") {
  # Parse user/repo
  parts <- strsplit(repo, "/")[[1]]
  user <- parts[1]
  pkg_repo <- parts[2]

  # Add to DESCRIPTION Remotes field
  d <- desc::description$new(file.path(path, "DESCRIPTION"))

  current_remotes <- d$get_field("Remotes", default = "")
  new_remote <- sprintf("%s@%s", repo, ref)

  if (current_remotes == "") {
    d$set("Remotes", new_remote)
  } else {
    d$set("Remotes", paste(current_remotes, new_remote, sep = ",\n    "))
  }

  d$write()

  cli::cli_alert_success(
    "Added {.pkg {pkg_repo}} from GitHub to DESCRIPTION"
  )
  cli::cli_alert_info(
    "Install with: renv::install('{repo}@{ref}')"
  )
}
```

### 7. Interactive Fixing Mode

**Step-by-step package resolution**:

```r
#' Interactive Package Fixing
#'
#' Interactively resolve missing packages one by one.
#'
#' @inheritParams check_packages
#'
#' @export
fix_packages_interactive <- function(strict = TRUE, path = ".") {
  result <- check_packages(
    strict = strict,
    auto_fix = FALSE,
    path = path
  )

  if (length(result$missing) == 0) {
    cli::cli_alert_success("No missing packages!")
    return(invisible())
  }

  for (pkg in result$missing) {
    cli::cli_h2("Package: {.pkg {pkg}}")

    choice <- utils::menu(
      choices = c(
        "Add to DESCRIPTION and renv.lock",
        "Add to DESCRIPTION only",
        "Skip this package",
        "Abort"
      ),
      title = sprintf("What should we do with %s?", pkg)
    )

    if (choice == 1) {
      add_to_description(pkg, path = path)
      add_to_renv_lock(pkg, path = path)
    } else if (choice == 2) {
      add_to_description(pkg, path = path)
    } else if (choice == 3) {
      next
    } else {
      break
    }
  }
}
```

---

## Testing Strategy

### Unit Tests (testthat Framework)

**Test Organization**:

```
tests/testthat/
├── test-extract.R       # Package extraction tests
├── test-clean.R         # Package name cleaning tests
├── test-parse.R         # DESCRIPTION/renv.lock parsing tests
├── test-compare.R       # Validation logic tests
├── test-autofix.R       # Auto-fix functionality tests
├── test-api.R           # CRAN API interaction tests
├── test-utils.R         # Utility function tests
└── helper-fixtures.R    # Test fixture creation
```

**Example Test File** (`test-extract.R`):

```r
test_that("extract_library_calls finds library() calls", {
  temp_file <- tempfile(fileext = ".R")
  writeLines(c(
    "library(dplyr)",
    "library('ggplot2')",
    'library("tidyr")'
  ), temp_file)

  packages <- extract_code_packages(dirname(temp_file))

  expect_true("dplyr" %in% packages)
  expect_true("ggplot2" %in% packages)
  expect_true("tidyr" %in% packages)

  unlink(temp_file)
})

test_that("extract_namespace_calls finds pkg:: calls", {
  temp_file <- tempfile(fileext = ".R")
  writeLines(c(
    "dplyr::filter(data, x > 0)",
    "result <- ggplot2::ggplot()"
  ), temp_file)

  packages <- extract_code_packages(dirname(temp_file))

  expect_true("dplyr" %in% packages)
  expect_true("ggplot2" %in% packages)

  unlink(temp_file)
})

test_that("extract ignores commented code", {
  temp_file <- tempfile(fileext = ".R")
  writeLines(c(
    "library(dplyr)",
    "# library(ggplot2)",
    "  # library(tidyr)"
  ), temp_file)

  packages <- extract_code_packages(dirname(temp_file))

  expect_true("dplyr" %in% packages)
  expect_false("ggplot2" %in% packages)
  expect_false("tidyr" %in% packages)

  unlink(temp_file)
})
```

**Example Test File** (`test-clean.R`):

```r
test_that("clean_package_names removes base packages", {
  packages <- c("dplyr", "base", "utils", "ggplot2", "stats")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_true("ggplot2" %in% cleaned)
  expect_false("base" %in% cleaned)
  expect_false("utils" %in% cleaned)
  expect_false("stats" %in% cleaned)
})

test_that("clean_package_names removes short names", {
  packages <- c("dplyr", "my", "an", "if", "ggplot2")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_true("ggplot2" %in% cleaned)
  expect_false("my" %in% cleaned)
  expect_false("an" %in% cleaned)
  expect_false("if" %in% cleaned)
})

test_that("clean_package_names validates format", {
  packages <- c("dplyr", ".invalid", "invalid.", "123pkg", "valid.pkg")

  cleaned <- clean_package_names(packages)

  expect_true("dplyr" %in% cleaned)
  expect_true("valid.pkg" %in% cleaned)
  expect_false(".invalid" %in% cleaned)
  expect_false("invalid." %in% cleaned)
  expect_false("123pkg" %in% cleaned)
})
```

### Integration Tests

**Full Workflow Tests**:

```r
test_that("full workflow: code -> DESCRIPTION -> renv.lock", {
  # Create temporary project
  temp_dir <- tempfile()
  dir.create(temp_dir)

  # Create minimal DESCRIPTION
  desc::desc(temp_dir)$
    set("Package", "testpkg")$
    set("Version", "0.1.0")$
    write()

  # Create renv.lock
  renv_lock <- list(
    R = list(Version = "4.4.0"),
    Packages = list()
  )
  jsonlite::write_json(
    renv_lock,
    file.path(temp_dir, "renv.lock"),
    pretty = TRUE,
    auto_unbox = TRUE
  )

  # Create R file with dependencies
  dir.create(file.path(temp_dir, "R"))
  writeLines(
    c("library(dplyr)", "ggplot2::ggplot()"),
    file.path(temp_dir, "R", "analysis.R")
  )

  # Run validation with auto-fix
  result <- check_packages(
    auto_fix = TRUE,
    path = temp_dir
  )

  # Verify DESCRIPTION updated
  imports <- desc::desc(temp_dir)$get_deps()
  import_pkgs <- imports[imports$type == "Imports", "package"]

  expect_true("dplyr" %in% import_pkgs)
  expect_true("ggplot2" %in% import_pkgs)

  # Verify renv.lock updated
  lock <- jsonlite::read_json(file.path(temp_dir, "renv.lock"))

  expect_true("dplyr" %in% names(lock$Packages))
  expect_true("ggplot2" %in% names(lock$Packages))

  # Cleanup
  unlink(temp_dir, recursive = TRUE)
})
```

### Test Fixtures

**Create realistic test projects**:

```
inst/examples/
├── valid_project/           # Everything correct
│   ├── DESCRIPTION
│   ├── renv.lock
│   └── R/
│       └── functions.R
│
├── missing_description/     # Code but no DESCRIPTION packages
│   ├── DESCRIPTION
│   ├── renv.lock
│   └── R/
│       └── analysis.R       # Uses dplyr but not declared
│
├── missing_renv_lock/       # DESCRIPTION but no renv.lock
│   ├── DESCRIPTION          # Has Imports
│   ├── renv.lock            # Missing packages
│   └── R/
│       └── functions.R
│
├── unused_packages/         # DESCRIPTION has unused packages
│   ├── DESCRIPTION          # Imports: dplyr, ggplot2, tidyr
│   ├── renv.lock
│   └── R/
│       └── functions.R      # Only uses dplyr
│
└── complex_project/         # Real-world complexity
    ├── DESCRIPTION
    ├── renv.lock
    ├── R/
    ├── scripts/
    ├── analysis/
    ├── tests/
    └── vignettes/
```

### Mocking CRAN API

**Mock HTTP responses for testing**:

```r
test_that("fetch_cran_info handles API errors", {
  # Mock failed response
  with_mock(
    `httr::GET` = function(...) {
      structure(
        list(status_code = 404),
        class = "response"
      )
    },
    {
      info <- fetch_cran_info("nonexistent_package")
      expect_null(info)
    }
  )
})

test_that("fetch_cran_info parses successful response", {
  # Mock successful response
  with_mock(
    `httr::GET` = function(...) {
      structure(
        list(
          status_code = 200,
          content = charToRaw('{"Package":"dplyr","Version":"1.1.4"}')
        ),
        class = "response"
      )
    },
    `httr::content` = function(resp, ...) {
      '{"Package":"dplyr","Version":"1.1.4"}'
    },
    {
      info <- fetch_cran_info("dplyr")
      expect_equal(info$Package, "dplyr")
      expect_equal(info$Version, "1.1.4")
    }
  )
})
```

### Coverage Target

**Aim for >90% test coverage**:

```r
# Run with coverage
covr::package_coverage()

# Generate HTML report
covr::report()
```

---

## Documentation Plan

### README.md

**Quick Start Guide**:

````markdown
# zzrenvcheck

> Validate R Package Dependencies for Reproducibility

## Overview

`zzrenvcheck` ensures all R packages used in your code are properly declared in `DESCRIPTION` and locked in `renv.lock`, maintaining reproducible environments.

## Installation

```r
# From GitHub
remotes::install_github("username/zzrenvcheck")

# From CRAN (future)
install.packages("zzrenvcheck")
```

## Quick Start

```r
library(zzrenvcheck)

# Check your project
check_packages()

# Auto-fix missing packages
fix_packages()

# View detailed report
report <- report_packages()
```

## Features

- ✅ **Comprehensive Detection**: Finds packages from `library()`, `require()`, `pkg::function()`, and roxygen
- ✅ **Smart Filtering**: 19 filters to avoid false positives
- ✅ **Auto-Fix**: Automatically add missing packages from CRAN
- ✅ **Formatted Output**: Clear, colored console messages
- ✅ **Cross-Platform**: Works on Windows, macOS, and Linux
- ✅ **RStudio Integration**: Addin for GUI workflow

## Workflow

```r
# 1. Write code with package dependencies
library(dplyr)
ggplot2::ggplot(data)

# 2. Validate dependencies
check_packages()

# 3. Fix any issues
fix_packages()

# 4. Commit synchronized files
# git add DESCRIPTION renv.lock
# git commit -m "Sync dependencies"
```

## Documentation

- [Getting Started](vignettes/getting-started.html)
- [Workflow Integration](vignettes/workflow-integration.html)
- [Advanced Usage](vignettes/advanced-usage.html)

## Comparison with validation.sh

`zzrenvcheck` is an R package port of zzcollab's `validation.sh`:

| Feature | validation.sh | zzrenvcheck |
|---------|---------------|-----------|
| Platform | macOS/Linux | All |
| Requires R | No | Yes |
| Distribution | Manual | CRAN/GitHub |
| RStudio Integration | No | Yes |
| Windows Support | No | Yes |

## License

MIT License
````

### Vignettes

#### 1. Getting Started (`vignettes/getting-started.Rmd`)

````markdown
---
title: "Getting Started with zzrenvcheck"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Getting Started with zzrenvcheck}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

## Introduction

Package dependency management is critical for reproducible research...

## Installation

```{r eval=FALSE}
remotes::install_github("username/zzrenvcheck")
```

## Basic Usage

### Checking Dependencies

```{r eval=FALSE}
library(zzrenvcheck)

# Check current project
check_packages()
```

### Understanding Results

The output shows three key metrics:
- Packages found in code
- Packages declared in DESCRIPTION
- Packages locked in renv.lock

### Fixing Issues

```{r eval=FALSE}
# Automatic fix
fix_packages()

# Or manual additions
add_to_description("dplyr")
add_to_renv_lock("dplyr")
```

## Common Scenarios

### Scenario 1: New Package Added

You wrote code using a new package...

### Scenario 2: Cleaning Unused Packages

Over time, DESCRIPTION accumulates unused packages...

### Scenario 3: Team Collaboration

When collaborating, ensure all team members have consistent dependencies...
````

#### 2. Workflow Integration (`vignettes/workflow-integration.Rmd`)

````markdown
---
title: "Workflow Integration"
output: rmarkdown::html_vignette
---

## Pre-Commit Hooks

Validate dependencies before every commit:

```{r eval=FALSE}
use_zzrenvcheck_hook()
```

## CI/CD Integration

### GitHub Actions

```{r eval=FALSE}
use_github_action()
```

### Custom CI

```yaml
- name: Check dependencies
  run: Rscript -e 'zzrenvcheck::check_packages(auto_fix = FALSE)'
```

## RStudio Workflow

Use the Addin menu: Tools → Addins → Check Package Dependencies

## Docker Integration

Run validation before building Docker images...
````

#### 3. Advanced Usage (`vignettes/advanced-usage.Rmd`)

````markdown
---
title: "Advanced Usage"
output: rmarkdown::html_vignette
---

## Configuration Files

Create `.zzrenvcheck.yaml`:

```yaml
strict: true
exclude_dirs:
  - deprecated
```

## GitHub Packages

```{r eval=FALSE}
add_github_package("tidyverse/dplyr", ref = "main")
```

## Bioconductor Support

Automatically detects Bioconductor packages...

## Programmatic Usage

```{r eval=FALSE}
result <- check_packages(auto_fix = FALSE)

if (length(result$missing) > 0) {
  # Custom handling
}
```

## Custom Filters

Add project-specific filters...
````

### Function Documentation (Roxygen2)

**Every function fully documented**:

```r
#' Check Package Dependencies
#'
#' Validates that all R packages used in source code are properly declared
#' in DESCRIPTION and locked in renv.lock for reproducibility.
#'
#' @details
#' This function performs three-level validation:
#' \enumerate{
#'   \item \strong{Code → DESCRIPTION}: Finds packages used in code but not
#'     declared in DESCRIPTION Imports
#'   \item \strong{DESCRIPTION → renv.lock}: Finds declared packages not
#'     locked in renv.lock
#'   \item \strong{Unused packages}: Finds packages in DESCRIPTION but not
#'     used in code (with \code{strict = TRUE})
#' }
#'
#' @param strict Logical. If \code{TRUE} (default), scans all directories
#'   including tests/ and vignettes/. If \code{FALSE}, scans only R/,
#'   scripts/, and analysis/ directories.
#' @param auto_fix Logical. If \code{TRUE}, automatically adds missing
#'   packages to DESCRIPTION and renv.lock by querying CRAN. If \code{FALSE}
#'   (default), only reports issues without making changes.
#' @param verbose Logical. If \code{TRUE} (default), lists all missing
#'   packages. If \code{FALSE}, shows only counts.
#' @param path Character string. Path to project root directory containing
#'   DESCRIPTION and renv.lock files. Default is current directory (\code{"."}).
#'
#' @return Invisibly returns a list with the following components:
#' \describe{
#'   \item{code_packages}{Character vector of packages found in code}
#'   \item{description_packages}{Character vector from DESCRIPTION Imports}
#'   \item{renv_packages}{Character vector from renv.lock}
#'   \item{missing}{Character vector of packages in code but not DESCRIPTION}
#'   \item{unlocked}{Character vector of packages in DESCRIPTION but not renv.lock}
#'   \item{unused}{Character vector of packages in DESCRIPTION but not used}
#'   \item{status}{Character: "pass" or "fail"}
#' }
#'
#' @section Strict Mode:
#' Standard mode scans: R/, scripts/, analysis/
#'
#' Strict mode additionally scans: tests/, vignettes/, inst/
#'
#' Rationale: Test and vignette packages may be in Suggests rather than
#' Imports. Strict mode helps ensure these are properly declared.
#'
#' @section Auto-Fix:
#' When \code{auto_fix = TRUE}, the function:
#' \enumerate{
#'   \item Queries CRAN API for package metadata
#'   \item Adds missing packages to DESCRIPTION Imports
#'   \item Adds missing packages to renv.lock with current CRAN version
#' }
#'
#' Non-CRAN packages (GitHub, Bioconductor) must be added manually.
#'
#' @seealso
#' \code{\link{fix_packages}} for auto-fix convenience wrapper
#'
#' \code{\link{report_packages}} for read-only status report
#'
#' \code{\link{extract_code_packages}} for package extraction only
#'
#' @examples
#' \dontrun{
#' # Basic validation
#' check_packages()
#'
#' # Auto-fix missing packages
#' check_packages(auto_fix = TRUE)
#'
#' # Non-strict mode (skip tests and vignettes)
#' check_packages(strict = FALSE)
#'
#' # Check specific project
#' check_packages(path = "path/to/project")
#'
#' # Get detailed results
#' result <- check_packages()
#' print(result$missing)
#' }
#'
#' @export
check_packages <- function(strict = TRUE,
                           auto_fix = FALSE,
                           verbose = TRUE,
                           path = ".") {
  # Implementation
}
```

---

## Release Roadmap

### Version 0.1.0 (MVP) - Month 1

**Core Functionality**:
- ✅ Package extraction from code (library, require, ::, roxygen)
- ✅ Package name cleaning with 19 filters
- ✅ DESCRIPTION parsing (using `desc` package)
- ✅ renv.lock parsing (using `jsonlite`)
- ✅ Validation logic (code ↔ DESCRIPTION ↔ renv.lock)
- ✅ Auto-fix for CRAN packages
- ✅ Formatted CLI output (using `cli`)

**Testing**:
- ✅ Unit tests for all core functions
- ✅ Integration tests with test fixtures
- ✅ Test coverage >80%

**Documentation**:
- ✅ README with quick start
- ✅ Function documentation (roxygen2)
- ✅ Getting Started vignette
- ✅ Basic examples

**Deliverables**:
- Functional R package
- GitHub repository
- Basic documentation
- Test suite

### Version 0.2.0 (Enhancements) - Month 2

**New Features**:
- ✅ RStudio Addin for GUI workflow
- ✅ Configuration file support (`.zzrenvcheck.yaml`)
- ✅ Bioconductor package support
- ✅ GitHub package detection and handling
- ✅ AST-based parsing as alternative to regex

**Improvements**:
- ✅ Enhanced error messages
- ✅ Performance optimizations
- ✅ Better handling of edge cases

**Documentation**:
- ✅ Workflow Integration vignette
- ✅ Advanced Usage vignette
- ✅ Blog post announcement

**Deliverables**:
- Enhanced feature set
- Comprehensive vignettes
- Community announcement

### Version 0.3.0 (Automation) - Month 3

**Automation Features**:
- ✅ Pre-commit hook installer
- ✅ GitHub Actions template generator
- ✅ Interactive fixing mode
- ✅ Batch project validation

**Enterprise Features**:
- ✅ Custom filter configuration
- ✅ Protected package lists
- ✅ Multi-project reports
- ✅ API for programmatic use

**Testing**:
- ✅ Test coverage >90%
- ✅ Real-world project testing
- ✅ Performance benchmarks

**Documentation**:
- ✅ Complete API reference
- ✅ Case studies
- ✅ Video tutorial

**Deliverables**:
- Enterprise-ready features
- Production-tested
- Comprehensive documentation

### Version 1.0.0 (Stable Release) - Month 4-5

**Preparation**:
- ✅ Battle-tested in 10+ real projects
- ✅ All known bugs fixed
- ✅ Complete documentation review
- ✅ CRAN submission preparation

**CRAN Submission**:
- ✅ Pass R CMD check with no warnings
- ✅ CRAN policy compliance
- ✅ Maintainer contact information
- ✅ Submit to CRAN

**Marketing**:
- ✅ Published paper or preprint
- ✅ Blog post on R-bloggers
- ✅ Social media announcement
- ✅ Conference presentation (useR!, rstudio::conf)

**Deliverables**:
- CRAN package
- Published documentation
- Community adoption
- Academic publication

---

## Advantages & Trade-offs

### R Package Advantages

| Aspect | Shell Script | R Package | Winner |
|--------|--------------|-----------|--------|
| **Distribution** | Manual copy/git clone | `install.packages()` | 📦 R Package |
| **Documentation** | Markdown files | Built-in `?help` system | 📦 R Package |
| **Testing** | Manual bash scripts | `testthat` framework | 📦 R Package |
| **IDE Integration** | None | RStudio addins | 📦 R Package |
| **Cross-Platform** | macOS/Linux | Windows/macOS/Linux | 📦 R Package |
| **User Base** | Shell users | All R users | 📦 R Package |
| **Ecosystem** | External tools | Native R packages | 📦 R Package |
| **Error Messages** | Plain text | Colored, formatted | 📦 R Package |
| **API** | CLI only | Programmatic + CLI | 📦 R Package |
| **Maintenance** | Shell expertise | R developers | 📦 R Package |

### Shell Script Advantages

| Aspect | Shell Script | R Package | Winner |
|--------|--------------|-----------|--------|
| **Host Requirement** | No R needed | Requires R | 🐚 Shell Script |
| **Startup Time** | Instant | R startup overhead | 🐚 Shell Script |
| **Dependencies** | bash, jq, curl | R + packages | 🐚 Shell Script |
| **Simplicity** | Self-contained | Package ecosystem | 🐚 Shell Script |

### Overall Assessment

**R Package wins on**:
- Accessibility and distribution
- Integration with R workflows
- Cross-platform support
- Documentation and testing infrastructure
- Community adoption potential

**Shell Script wins on**:
- Works without R installation
- Faster startup time
- Fewer dependencies

**Recommendation**: Develop both:
1. **R package** as primary tool for R users
2. **Shell script** remains in zzcollab for Docker/CI workflows

---

## Risks & Mitigations

### Risk 1: Performance Degradation

**Concern**: Shell script is very fast; R implementation might be slower

**Impact**: High - User experience critical

**Mitigation**:
- Profile R implementation early
- Optimize hotspots (file I/O, regex)
- Consider Rcpp for performance-critical sections
- Benchmark against validation.sh
- Cache expensive operations (CRAN API)

**Acceptance Criteria**: <2x slowdown vs shell script

### Risk 2: Windows Compatibility Issues

**Concern**: Path handling, file operations differ on Windows

**Impact**: High - Major selling point is Windows support

**Mitigation**:
- Use `fs` package for cross-platform file ops
- Test on Windows from day 1
- Use GitHub Actions Windows runner
- Normalize path separators

**Acceptance Criteria**: All tests pass on Windows

### Risk 3: CRAN API Instability

**Concern**: CRAN API might change or have downtime

**Impact**: Medium - Auto-fix functionality affected

**Mitigation**:
- Graceful error handling
- Cache API responses
- Fallback to manual instructions
- Document alternative APIs (Bioconductor, GitHub)
- Rate limiting to avoid API abuse

**Acceptance Criteria**: Degraded but functional without API

### Risk 4: Package Maintenance Overhead

**Concern**: R package requires ongoing maintenance

**Impact**: Medium - Long-term sustainability

**Mitigation**:
- Comprehensive test suite (catch regressions)
- Clear contribution guidelines
- Semantic versioning
- Deprecation warnings for breaking changes
- Active issue triage

**Acceptance Criteria**: Response to issues within 1 week

### Risk 5: Feature Creep

**Concern**: Scope expands beyond core validation

**Impact**: Medium - Delays release

**Mitigation**:
- Strict MVP definition (v0.1)
- Defer advanced features to v0.2, v0.3
- Clear roadmap
- Community feedback on priorities

**Acceptance Criteria**: v0.1 released within 1 month

### Risk 6: Dependency on Third-Party Packages

**Concern**: `desc`, `jsonlite`, `cli` might have breaking changes

**Impact**: Low - Packages are stable r-lib ecosystem

**Mitigation**:
- Pin minimum versions in DESCRIPTION
- Monitor r-lib package updates
- Comprehensive test suite
- CI runs on multiple R versions

**Acceptance Criteria**: Works with R >= 4.1.0

---

## Next Steps

### Phase 1: Setup (Week 1, Days 1-2)

**Day 1: Repository Setup**
- [ ] Choose final package name (`zzrenvcheck`)
- [ ] Create GitHub repository
- [ ] Initialize R package: `usethis::create_package("zzrenvcheck")`
- [ ] Set up git: `usethis::use_git()`
- [ ] Configure DESCRIPTION metadata
- [ ] Choose license: `usethis::use_mit_license()`
- [ ] Create README: `usethis::use_readme_rmd()`
- [ ] Set up testing: `usethis::use_testthat()`

**Day 2: Project Infrastructure**
- [ ] Set up GitHub Actions: `usethis::use_github_actions()`
- [ ] Configure test coverage: `usethis::use_coverage()`
- [ ] Create package documentation: `usethis::use_package_doc()`
- [ ] Set up development dependencies
- [ ] Create initial project structure

### Phase 2: Core Implementation (Week 1, Days 3-7)

**Day 3-4: Extraction Module**
- [ ] Implement `extract_library_calls()`
- [ ] Implement `extract_require_calls()`
- [ ] Implement `extract_namespace_calls()`
- [ ] Implement `extract_roxygen_imports()`
- [ ] Implement `extract_code_packages()` wrapper
- [ ] Write unit tests for extraction

**Day 5: Cleaning Module**
- [ ] Port BASE_PACKAGES list
- [ ] Port PLACEHOLDER_PACKAGES list
- [ ] Implement 19 filter rules
- [ ] Implement `clean_package_names()`
- [ ] Write unit tests for cleaning

**Day 6: Parsing Module**
- [ ] Implement `parse_description_imports()` using `desc`
- [ ] Implement `parse_renv_lock()` using `jsonlite`
- [ ] Write unit tests for parsing

**Day 7: Integration & Testing**
- [ ] Integration tests with test fixtures
- [ ] Create example projects in `inst/examples/`
- [ ] Test coverage review (target: >80%)

### Phase 3: Validation & Auto-Fix (Week 2)

**Days 8-9: Validation Logic**
- [ ] Implement `compare_packages()` (code ↔ DESCRIPTION)
- [ ] Implement DESCRIPTION ↔ renv.lock comparison
- [ ] Implement unused package detection
- [ ] Write unit tests for validation

**Days 10-11: Auto-Fix Implementation**
- [ ] Implement `fetch_cran_info()` with httr
- [ ] Implement `add_to_description()` using `desc`
- [ ] Implement `add_to_renv_lock()` using `jsonlite`
- [ ] Write unit tests for auto-fix
- [ ] Mock CRAN API for testing

**Days 12-13: User Interface**
- [ ] Implement `check_packages()` main function
- [ ] Implement `fix_packages()` convenience wrapper
- [ ] Implement `report_packages()` status function
- [ ] Add formatted output with `cli`
- [ ] Write integration tests

**Day 14: Polish & Documentation**
- [ ] Function documentation (roxygen2)
- [ ] README with examples
- [ ] Getting Started vignette
- [ ] Error message review

### Phase 4: Testing & Release (Week 3)

**Days 15-16: Testing**
- [ ] Test on Windows (GitHub Actions)
- [ ] Test on macOS (GitHub Actions)
- [ ] Test on Linux (GitHub Actions)
- [ ] Test with multiple R versions
- [ ] Fix any platform-specific issues

**Days 17-18: Documentation**
- [ ] Complete function documentation
- [ ] Workflow Integration vignette
- [ ] Advanced Usage vignette
- [ ] Build package website with `pkgdown`

**Days 19-20: Release Preparation**
- [ ] R CMD check (zero errors, warnings, notes)
- [ ] Spell check: `usethis::use_spell_check()`
- [ ] URL checks: `urlchecker::url_check()`
- [ ] Version bump: `usethis::use_version("0.1.0")`
- [ ] NEWS.md entry
- [ ] Git tag release

**Day 21: Release**
- [ ] GitHub release with notes
- [ ] Blog post announcement
- [ ] Social media (Twitter/Mastodon)
- [ ] Notify zzcollab users

### Phase 5: Enhancement (Month 2)

**Week 4-5: Advanced Features**
- [ ] RStudio Addin implementation
- [ ] Configuration file support
- [ ] Bioconductor integration
- [ ] GitHub package handling

**Week 6-7: Automation**
- [ ] Pre-commit hook installer
- [ ] GitHub Actions template
- [ ] Interactive fixing mode
- [ ] Batch validation

**Week 8: v0.2.0 Release**
- [ ] Complete testing
- [ ] Documentation updates
- [ ] Release v0.2.0
- [ ] Community feedback collection

---

## Recommendation

### Develop as Standalone R Package

I **strongly recommend** developing `zzrenvcheck` as a standalone R package for the following reasons:

#### 1. Broader Impact

- **Not limited to zzcollab users**: Any R project using renv benefits
- **Larger user base**: All R developers vs. just Docker users
- **Community value**: Addresses common pain point in R ecosystem

#### 2. Better User Experience

- **Standard installation**: `install.packages("zzrenvcheck")`
- **Built-in help**: `?check_packages` vs. reading markdown
- **RStudio integration**: Point-and-click workflow
- **Cross-platform**: Works everywhere R works

#### 3. Easier Maintenance

- **R community contribution**: More potential contributors
- **Standard tooling**: testthat, roxygen2, pkgdown
- **Clear API**: Programmatic use + CLI
- **Version management**: Standard R package versioning

#### 4. Ecosystem Integration

- **Native dependencies**: desc, jsonlite, cli
- **R workflows**: Pre-commit hooks, CI/CD
- **Package manager**: CRAN distribution
- **Documentation**: Vignettes, pkgdown sites

### Complementary Approach

**Keep both implementations**:

1. **`zzrenvcheck` R package** - Primary tool for R users
   - Better integration
   - Wider distribution
   - Enhanced features

2. **`validation.sh` shell script** - Remains in zzcollab
   - Docker workflows (no R in container)
   - CI/CD without R installation
   - Fast host-side validation

**Division of Labor**:
- R users → `zzrenvcheck` package
- Docker/CI → `validation.sh` script
- Both share same validation logic

### Success Criteria

**v0.1.0 Success** (3 months):
- [ ] 100+ GitHub stars
- [ ] 10+ real-world project adoptions
- [ ] Featured on R Weekly
- [ ] Zero critical bugs

**v1.0.0 Success** (6 months):
- [ ] CRAN package
- [ ] 500+ GitHub stars
- [ ] 100+ monthly downloads
- [ ] Published paper/preprint
- [ ] Conference presentation

---

## Conclusion

The `validation.sh` module represents sophisticated, battle-tested logic for R package dependency validation. Converting this to a standalone R package (`zzrenvcheck`) would:

1. **Democratize access**: Any R user benefits, not just zzcollab users
2. **Improve usability**: Native R integration beats shell script
3. **Enable growth**: CRAN distribution, RStudio addins, CI/CD
4. **Build community**: R developers can contribute and extend

The investment is justified by:
- Clear user need (reproducibility is critical)
- Proven solution (validation.sh works well)
- Large potential user base (all renv users)
- Differentiated value (no equivalent package exists)

**Recommendation**: Proceed with R package development, starting with MVP (v0.1.0) within 1 month.

---

**Document Version**: 1.0
**Last Updated**: November 15, 2025
**Next Review**: Upon v0.1.0 completion
