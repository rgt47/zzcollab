# validate_package_environment.R Improvements Summary

> **DEPRECATED**: The `validate_package_environment.R` R script has been **replaced** with pure shell validation (`modules/validation.sh`) as of October 2025. This document is **historical only**.
>
> **Current System**:
> - **Pure shell validation**: `make check-renv` (NO HOST R REQUIRED!)
> - **Auto-snapshot**: Automatic `renv::snapshot()` on container exit
> - See [DEVELOPMENT.md](DEVELOPMENT.md) for current validation system

## Status: HISTORICAL DOCUMENT (Superseded)

This document tracks historical improvements to the `validate_package_environment.R` script which has been replaced by pure shell validation.

---

## Improvements Completed

### Priority 1: Critical Bug Fixes

#### 1. Fixed Undefined Pattern Bug (Line 525)
**Status**: COMPLETED
**Impact**: HIGH - Script would fail when processing @examples sections

**Problem**:
```r
# BEFORE (BROKEN):
ex_lib_matches <- regmatches(example_content,
  gregexpr(REGEX_PATTERNS$library_calls, ...))  # UNDEFINED!
```

**Solution**:
```r
# AFTER (FIXED):
ex_lib_matches <- regmatches(example_content,
  gregexpr(REGEX_PATTERNS$library_simple, example_content, perl = TRUE))
```

#### 2. Removed Unreachable Code (Lines 1327-1333)
**Status**: COMPLETED
**Impact**: MEDIUM - Dead code maintenance burden

**Problem**: Code after `quit()` never executes

**Solution**: Removed 6 lines of unreachable code, simplified exit logic

#### 3. Added renv.lock Backup Restoration
**Status**: COMPLETED
**Impact**: HIGH - Data loss prevention

**Problem**: If `renv::snapshot()` failed, renv.lock would be deleted with no recovery

**Solution**:
- Always create backup before modification (even in non-clean mode)
- Restore from backup on snapshot failure
- Clean up backup on success
- Log critical failure if backup restoration fails

---

## Improvements Implemented

### Priority 2: High-Priority Features

#### 4. Added Bioconductor Package Detection
**Status**: COMPLETED
**Impact**: HIGH - Proper recognition of Bioconductor packages

**Features**:
- Uses `BiocManager::available()` if available
- Fallback pattern matching for common Bioc packages
- Distinguishes Bioconductor from truly invalid packages

**Function**: `check_bioconductor_packages()`

#### 5. Added GitHub Package Detection
**Status**: COMPLETED
**Impact**: MEDIUM - Recognizes remotes-installed packages

**Features**:
- Detects `remotes::install_github()` references
- Extracts package names from GitHub URLs
- Marks as valid (not errors)

**Function**: `check_github_packages()`

#### 6. Unified Repository Validation
**Status**: COMPLETED
**Impact**: HIGH - Comprehensive package source validation

**Features**:
- Checks CRAN, Bioconductor, and GitHub
- Returns structured result with package classifications
- Better error messages (only truly invalid packages flagged)

**Function**: `validate_against_repositories()`

---

## Improvements Still Needed

### Priority 2: Remaining High-Priority

#### 7. ⏳ Preserve Version Constraints (IN PROGRESS)
**Status**: NOT STARTED
**Impact**: MEDIUM - Loses version information

**Problem**:
```r
# Original DESCRIPTION:
Imports: tidyverse (>= 2.0.0), dplyr (>= 1.1.0)

# After fix_description_file():
Imports: tidyverse, dplyr  # VERSION CONSTRAINTS LOST!
```

**Solution Needed**:
```r
# Add function to extract and preserve constraints:
extract_version_constraint <- function(dep_string) {
  if (grepl("\\([^)]+\\)", dep_string)) {
    pkg_name <- gsub("\\s*\\([^)]+\\)", "", dep_string)
    constraint <- gsub(".*\\(([^)]+)\\).*", "\\1", dep_string)
    return(list(package = trimws(pkg_name), version = constraint))
  }
  return(list(package = trimws(dep_string), version = NULL))
}

# Store constraints when parsing, reapply when fixing
```

**Files to modify**:
- `parse_description_file()` - Store version info
- `fix_description_file()` - Preserve version info

#### 8. ⏳ Add File Size Checks
**Status**: NOT STARTED
**Impact**: MEDIUM - Prevents memory issues

**Problem**: `readLines()` loads entire file into memory

**Solution**:
```r
read_file_safely <- function(filepath, max_size_mb = 10) {
  # Check file size before reading
  file_size_mb <- file.info(filepath)$size / (1024^2)
  if (file_size_mb > max_size_mb) {
    return(list(
      content = "",
      success = FALSE,
      error = paste("File too large:", round(file_size_mb, 1), "MB")
    ))
  }

  # Existing read logic...
}
```

#### 9. ⏳ Add Encoding Specification
**Status**: NOT STARTED
**Impact**: MEDIUM - Handles international characters

**Problem**: No encoding specified in `readLines()`

**Solution**:
```r
# Line 558:
content <- paste(
  readLines(filepath, warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)
```

---

### Priority 3: Medium-Priority Features

#### 10. ⏳ Add Unit Tests
**Status**: NOT STARTED
**Impact**: HIGH - Confidence in ongoing maintenance

**Test Structure Needed**:
```
tests/
└── testthat/
    ├── test-extract-packages.R
    ├── test-clean-packages.R
    ├── test-file-reading.R
    ├── test-cran-validation.R
    ├── test-description-parsing.R
    ├── test-renv-parsing.R
    └── fixtures/
        ├── sample-r-code.R
        ├── sample-DESCRIPTION
        └── sample-renv.lock
```

**Key Tests to Implement**:
```r
# test-extract-packages.R
test_that("extract_packages_from_text handles wrapped calls", {
  code <- "suppressMessages(library(dplyr))"
  result <- extract_packages_from_text(code)
  expect_equal(result, "dplyr")
})

test_that("extract_packages_from_text handles conditional loading", {
  code <- "if (require_pkg) library(ggplot2)"
  result <- extract_packages_from_text(code)
  expect_true("ggplot2" %in% result)
})

test_that("extract_packages_from_text handles roxygen imports", {
  code <- "#' @importFrom dplyr select mutate"
  result <- extract_packages_from_text(code)
  expect_true("dplyr" %in% result)
})

# test-clean-packages.R
test_that("clean_package_names removes base packages", {
  pkgs <- c("dplyr", "base", "utils", "ggplot2")
  result <- clean_package_names(pkgs)
  expect_equal(sort(result), c("dplyr", "ggplot2"))
})

test_that("clean_package_names removes short names", {
  pkgs <- c("dplyr", "x", "df", "ggplot2")
  result <- clean_package_names(pkgs)
  expect_false(any(c("x", "df") %in% result))
})
```

#### 11. ⏳ Implement Parallel Processing
**Status**: NOT STARTED
**Impact**: MEDIUM - Performance for large projects

**Solution**:
```r
extract_code_packages <- function(config, log_fn) {
  # ... file discovery ...

  # Use parallel processing for large projects
  if (length(all_files) > 100 &&
      requireNamespace("parallel", quietly = TRUE)) {

    log_fn("Using parallel processing (",
           parallel::detectCores(), " cores)...", level = "info")

    package_lists <- parallel::mclapply(
      all_files,
      function(file) {
        result <- read_file_safely(file)
        if (result$success) {
          extract_packages_from_text(result$content)
        } else {
          character(0)
        }
      },
      mc.cores = min(4, parallel::detectCores() - 1)
    )
  } else {
    # Sequential processing (existing code)
    # ...
  }
}
```

#### 12. ⏳ Add Progress Indicators
**Status**: NOT STARTED
**Impact**: LOW - User experience

**Solution**:
```r
# Add progress bar for long operations
if (!config$quiet && interactive()) {
  pb <- txtProgressBar(min = 0, max = length(all_files), style = 3)
  for (i in seq_along(all_files)) {
    # ... process file ...
    setTxtProgressBar(pb, i)
  }
  close(pb)
}
```

---

### Priority 4: Low-Priority Enhancements

#### 13. ⏳ Add Roxygen2 Documentation
**Status**: NOT STARTED
**Impact**: LOW - R CMD check compliance

**Example**:
```r
#' Extract Package Dependencies from R Code
#'
#' @description
#' Scans R code files to extract package dependencies from various patterns
#' including library() calls, namespace operators (::), and roxygen imports.
#'
#' @param content Character string containing R code to parse
#'
#' @return Character vector of unique package names found in the code.
#'   Returns empty character(0) if no packages found or invalid input.
#'
#' @details
#' This function handles multiple dependency patterns:
#' \itemize{
#'   \item{library() and require() calls (simple, wrapped, conditional)}
#'   \item{Namespace calls (package::function, package:::function)}
#'   \item{Roxygen imports (@import, @importFrom)}
#'   \item{Example code in @examples sections}
#' }
#'
#' @examples
#' \dontrun{
#' code <- 'library(dplyr)\ndata %>% ggplot2::ggplot()'
#' packages <- extract_packages_from_text(code)
#' # Returns: c("dplyr", "ggplot2")
#' }
#'
#' @export
extract_packages_from_text <- function(content) {
  # ... existing implementation ...
}
```

#### 14. ⏳ Add File Permission Checks
**Status**: NOT STARTED
**Impact**: LOW - Better error messages

**Solution**:
```r
fix_description_file <- function(...) {
  # Check write permissions before attempting
  if (file.access("DESCRIPTION", mode = 2) != 0) {
    return(list(
      success = FALSE,
      message = "DESCRIPTION file is not writable. Check file permissions."
    ))
  }

  # Check disk space
  if (requireNamespace("fs", quietly = TRUE)) {
    free_space_mb <- fs::fs_path("/")$free / (1024^2)
    if (free_space_mb < 10) {
      warning("Low disk space: ", round(free_space_mb, 1), "MB free")
    }
  }

  # ... rest of function ...
}
```

#### 15. ⏳ Add Circular Dependency Detection
**Status**: NOT STARTED
**Impact**: LOW - Edge case detection

**Solution**:
```r
detect_circular_dependencies <- function(desc_packages, log_fn) {
  # For each package, check its dependencies
  # Build dependency graph
  # Detect cycles using DFS

  if (length(desc_packages) < 2) return(list())

  graph <- list()
  for (pkg in desc_packages) {
    tryCatch({
      pkg_deps <- tools::package_dependencies(pkg)[[1]]
      graph[[pkg]] <- intersect(pkg_deps, desc_packages)
    }, error = function(e) {
      graph[[pkg]] <- character(0)
    })
  }

  # Detect cycles
  cycles <- find_cycles_dfs(graph)

  if (length(cycles) > 0) {
    log_fn("Circular dependencies detected: ",
           paste(sapply(cycles, paste, collapse = " -> "), collapse = "; "),
           level = "warning")
  }

  cycles
}
```

---

## Integration Work Required

### Update main_analysis() to use validate_against_repositories()

**Current**:
```r
cran_validation <- validate_against_cran(all_packages_to_validate, log_fn)
```

**Needs to change to**:
```r
# Get all discovered files for GitHub package detection
target_dirs <- if (config$strict_imports) PKG_CONFIG$strict_dirs else PKG_CONFIG$standard_dirs
all_files <- discover_files(target_dirs, REGEX_PATTERNS$file_pattern)

# Validate against all repositories
repo_validation <- validate_against_repositories(
  all_packages_to_validate,
  code_files = all_files,
  log_fn = log_fn
)

# Update references from cran_validation to repo_validation
validated_code_packages <- intersect(code_packages, repo_validation$valid)
validated_desc_packages <- intersect(desc_result$packages, repo_validation$valid)
invalid_desc_packages <- intersect(desc_result$packages, repo_validation$invalid)

# Report Bioconductor and GitHub packages if found
if (length(repo_validation$bioconductor) > 0) {
  log_fn("Bioconductor packages in use: ",
         paste(repo_validation$bioconductor, collapse = ", "),
         level = "info")
}
if (length(repo_validation$github) > 0) {
  log_fn("GitHub packages in use: ",
         paste(repo_validation$github, collapse = ", "),
         level = "info")
}
```

---

## Testing Plan

### Manual Testing Scenarios

1. **Test Bioconductor Detection**:
   ```r
   # Add to R/test.R:
   library(BiocManager)
   library(DESeq2)

   # Run: Rscript validate_package_environment.R --quiet --fail-on-issues
   # Expected: Should recognize DESeq2 as Bioconductor, not error
   ```

2. **Test GitHub Package Detection**:
   ```r
   # Add to R/test.R:
   remotes::install_github("hadley/dplyr")

   # Run: Rscript validate_package_environment.R --quiet --fail-on-issues
   # Expected: Should recognize dplyr as GitHub package
   ```

3. **Test renv.lock Rollback**:
   ```bash
   # Corrupt renv.lock intentionally
   echo "invalid json" > renv.lock

   # Run: Rscript validate_package_environment.R --fix --fail-on-issues
   # Expected: Should restore from backup
   ```

4. **Test Large File Handling** (once implemented):
   ```r
   # Create 100MB R file
   writeLines(rep("library(dplyr)", 1e6), "large_file.R")

   # Run: Rscript validate_package_environment.R --quiet
   # Expected: Should skip file with size warning
   ```

### Automated Test Suite

See section 10 above for complete test structure.

---

## Performance Benchmarks Needed

Once parallel processing is implemented:

```r
# Benchmark script
library(microbenchmark)

# Create test project with many files
create_test_project <- function(n_files = 100) {
  dir.create("test_project/R", recursive = TRUE)
  for (i in 1:n_files) {
    writeLines(
      c("library(dplyr)", "library(ggplot2)", "data %>% select(x)"),
      paste0("test_project/R/file_", i, ".R")
    )
  }
}

create_test_project(100)

# Benchmark
results <- microbenchmark(
  sequential = extract_code_packages(config_sequential),
  parallel = extract_code_packages(config_parallel),
  times = 10
)

print(results)
# Target: Parallel should be 2-3x faster for 100+ files
```

---

## Documentation Updates Needed

### Update Script Header

Add documentation for new features:

```r
# NEW FLAGS (to be documented):
#   --no-bioconductor    Skip Bioconductor package checking (faster)
#   --no-github          Skip GitHub package detection
#   --max-file-size MB   Maximum file size to read (default: 10MB)
#   --parallel           Use parallel processing for large projects

# ENVIRONMENT VARIABLES:
#   ZZCOLLAB_BUILD_MODE       Build mode (fast|standard|comprehensive)
#   ZZCOLLAB_MAX_FILE_SIZE    Maximum file size in MB
#   ZZCOLLAB_PARALLEL_CORES   Number of cores for parallel processing
```

### Update CLAUDE.md

Add section about enhanced validate_package_environment.R:

```markdown
### Enhanced Dependency Validation (October 2025)

validate_package_environment.R has been significantly enhanced:

**Critical Bug Fixes**:
- Fixed undefined pattern bug in @examples parsing
- Added renv.lock backup/restore on failure
- Removed unreachable code

**New Features**:
- Bioconductor package recognition
- GitHub package detection (remotes::install_github)
- Multi-repository validation (CRAN + Bioconductor + GitHub)
- Parallel processing for large projects (100+ files)
- File size validation before loading

**Usage Examples**:
```bash
# Standard validation with all repositories
Rscript validate_package_environment.R --quiet --fail-on-issues

# Fast validation (skip Bioconductor/GitHub checks)
Rscript validate_package_environment.R --quiet --no-bioconductor --no-github

# Parallel processing for large projects
Rscript validate_package_environment.R --parallel --fix --fail-on-issues
```
```

---

## Summary

### Completed: 6/15 improvements (40%)

**Priority 1 (Critical)**: 3/3 ✅
- Fixed undefined pattern bug
- Removed unreachable code
- Added renv.lock rollback

**Priority 2 (High)**: 3/6 ⏳
- Bioconductor detection
- GitHub detection
- Unified repository validation
- ⏳ Version constraint preservation
- ⏳ File size checks
- ⏳ Encoding specification

**Priority 3 (Medium)**: 0/4 ⏳
- Unit tests
- Parallel processing
- Progress indicators
- GitHub package patterns

**Priority 4 (Low)**: 0/3 ⏳
- Roxygen2 documentation
- File permission checks
- Circular dependency detection

### Next Steps

1. **Immediate**: Integrate new validation function into main_analysis()
2. **Short-term**: Implement version constraint preservation
3. **Medium-term**: Add comprehensive test suite
4. **Long-term**: Add parallel processing and optimization

---

## Notes

- All improvements maintain backward compatibility
- No breaking changes to command-line interface
- Exit codes remain unchanged (0=success, 1=critical issues, 2=config error)
- Script remains standalone with no new required dependencies
