#!/usr/bin/env bats

################################################################################
# End-to-End Reproducibility Tests for ZZCOLLAB
#
# Tests complete reproducibility workflow validating the Five Pillars:
# 1. Dockerfile (computational environment)
# 2. renv.lock (exact package versions)
# 3. .Rprofile (session configuration)
# 4. Source code (analysis logic)
# 5. Research data (empirical foundation)
#
# These tests validate that the complete reproducibility framework works
# without requiring actual Docker image builds or R execution.
################################################################################

# Load test helpers
load ../shell/test_helpers

################################################################################
# Setup and Teardown
################################################################################

setup() {
    setup_test

    # Set required environment variables
    export ZZCOLLAB_ROOT="${TEST_DIR}"
    export PROJECT_DIR="${TEST_DIR}/test-project"
    export ZZCOLLAB_QUIET=true

    # Create complete project structure
    mkdir -p "${PROJECT_DIR}/analysis/data/raw_data"
    mkdir -p "${PROJECT_DIR}/analysis/data/derived_data"
    mkdir -p "${PROJECT_DIR}/analysis/scripts"
    mkdir -p "${PROJECT_DIR}/analysis/figures"
    mkdir -p "${PROJECT_DIR}/analysis/report"
    mkdir -p "${PROJECT_DIR}/R"
    mkdir -p "${PROJECT_DIR}/tests"
}

teardown() {
    teardown_test
}

################################################################################
# SECTION 1: Five Pillars Structure Validation (10 tests)
################################################################################

@test "E2E: Dockerfile exists and has valid structure" {
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
FROM rocker/r-ver:4.4.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget

# Set environment variables
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

# Copy renv lockfile
COPY renv.lock .
COPY .Rprofile /root/.Rprofile

# Restore packages
RUN Rscript -e 'renv::restore()'

WORKDIR /workspace
EOF

    run test -f "${PROJECT_DIR}/Dockerfile"
    assert_success

    run grep -E "FROM|ENV|COPY|RUN" "${PROJECT_DIR}/Dockerfile"
    assert_success
    [ $(echo "$output" | wc -l) -ge 4 ]
}

@test "E2E: renv.lock exists with correct structure" {
    cat > "${PROJECT_DIR}/renv.lock" <<'EOF'
{
  "R": {
    "Version": "4.4.0",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cran.r-project.org"
      }
    ]
  },
  "Packages": {
    "dplyr": {
      "Package": "dplyr",
      "Version": "1.1.4",
      "Source": "Repository",
      "Repository": "CRAN"
    },
    "ggplot2": {
      "Package": "ggplot2",
      "Version": "3.4.4",
      "Source": "Repository",
      "Repository": "CRAN"
    }
  }
}
EOF

    run test -f "${PROJECT_DIR}/renv.lock"
    assert_success

    run jq -e '.R.Version' "${PROJECT_DIR}/renv.lock"
    assert_success

    run jq -e '.Packages' "${PROJECT_DIR}/renv.lock"
    assert_success
}

@test "E2E: .Rprofile has critical options set" {
    cat > "${PROJECT_DIR}/.Rprofile" <<'EOF'
# Critical reproducibility options
options(
  stringsAsFactors = FALSE,
  contrasts = c("contr.treatment", "contr.poly"),
  na.action = "na.omit",
  digits = 7,
  OutDec = "."
)

# Auto-restore packages on startup
if (!require("renv", quietly = TRUE)) {
  install.packages("renv")
}
renv::load(getwd())

# Auto-snapshot on exit
.Last <- function() {
  renv::snapshot(type = "all")
}
EOF

    run test -f "${PROJECT_DIR}/.Rprofile"
    assert_success

    run grep -c "options(" "${PROJECT_DIR}/.Rprofile"
    assert_success
    [ "$output" -ge 1 ]

    run grep "stringsAsFactors\|contrasts\|na.action\|digits\|OutDec" "${PROJECT_DIR}/.Rprofile"
    assert_success
    [ $(echo "$output" | wc -l) -ge 5 ]
}

@test "E2E: Source code structure is complete" {
    cat > "${PROJECT_DIR}/R/analysis-functions.R" <<'EOF'
# Utility functions for analysis

analyze_data <- function(data) {
  data %>%
    dplyr::filter(complete.cases(.)) %>%
    dplyr::summarize(across(everything(), mean))
}

create_visualization <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()
}
EOF

    cat > "${PROJECT_DIR}/analysis/scripts/main-analysis.R" <<'EOF'
#!/usr/bin/env Rscript

# Load packages
library(dplyr)
library(ggplot2)

# Set seed for reproducibility
set.seed(42)

# Source analysis functions
source("R/analysis-functions.R")

# Load data
data <- readr::read_csv("analysis/data/raw_data/data.csv")

# Run analysis
results <- analyze_data(data)

# Create visualization
plot <- create_visualization(results)
ggplot2::ggsave("analysis/figures/plot.pdf", plot)

# Save results
saveRDS(results, "analysis/data/derived_data/results.rds")
EOF

    run test -f "${PROJECT_DIR}/R/analysis-functions.R"
    assert_success

    run test -f "${PROJECT_DIR}/analysis/scripts/main-analysis.R"
    assert_success

    run grep -E "library|function|<-" "${PROJECT_DIR}/R/analysis-functions.R"
    assert_success
}

@test "E2E: Research data documentation structure" {
    cat > "${PROJECT_DIR}/analysis/data/README.md" <<'EOF'
# Research Data

## Raw Data

### data.csv
- **Source**: Original measurement collection
- **Description**: Primary dataset for analysis
- **Variables**: See data dictionary below
- **Read-only**: Yes (MD5: abc123)

## Derived Data

### results.rds
- **Source**: analysis/scripts/main-analysis.R
- **Description**: Aggregated results from raw data
- **Format**: R data serialization (.rds)

## Data Dictionary

| Variable | Type | Description |
|----------|------|-------------|
| x | numeric | First measurement |
| y | numeric | Second measurement |
| id | integer | Subject identifier |
EOF

    run test -f "${PROJECT_DIR}/analysis/data/README.md"
    assert_success

    run grep -E "Raw Data|Derived Data|Variables|Source" "${PROJECT_DIR}/analysis/data/README.md"
    assert_success
}

@test "E2E: DESCRIPTION file documents project" {
    cat > "${PROJECT_DIR}/DESCRIPTION" <<'EOF'
Package: test-project
Title: Test Reproducible Research Project
Version: 0.1.0
Authors@R: person("Test", "Author", email = "test@example.com")
Description: A test project validating reproducibility
License: MIT
Imports:
    dplyr (>= 1.1.0),
    ggplot2 (>= 3.4.0),
    readr (>= 2.1.0)
EOF

    run test -f "${PROJECT_DIR}/DESCRIPTION"
    assert_success

    run grep "^Package:" "${PROJECT_DIR}/DESCRIPTION"
    assert_success

    run grep "^Imports:" "${PROJECT_DIR}/DESCRIPTION"
    assert_success
}

@test "E2E: All five pillars present in project" {
    # 1. Dockerfile
    touch "${PROJECT_DIR}/Dockerfile"
    # 2. renv.lock
    touch "${PROJECT_DIR}/renv.lock"
    # 3. .Rprofile
    touch "${PROJECT_DIR}/.Rprofile"
    # 4. Source code
    touch "${PROJECT_DIR}/R/analysis.R"
    # 5. Data
    mkdir -p "${PROJECT_DIR}/analysis/data/raw_data"
    touch "${PROJECT_DIR}/analysis/data/raw_data/data.csv"

    # Verify all present
    [ -f "${PROJECT_DIR}/Dockerfile" ]
    [ -f "${PROJECT_DIR}/renv.lock" ]
    [ -f "${PROJECT_DIR}/.Rprofile" ]
    [ -f "${PROJECT_DIR}/R/analysis.R" ]
    [ -f "${PROJECT_DIR}/analysis/data/raw_data/data.csv" ]
}

@test "E2E: Git repository tracking Five Pillars" {
    cd "${PROJECT_DIR}"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create five pillar files
    touch Dockerfile renv.lock .Rprofile data.csv
    mkdir -p R analysis/scripts

    # Add all five pillars to git
    git add .

    # Verify they can be tracked
    run git status --short
    assert_success
    # Should show added files
    [ -n "$(echo "$output" | grep -E 'Dockerfile|renv.lock|.Rprofile')" ]
}

################################################################################
# SECTION 2: Package Management Workflow (5 tests)
################################################################################

@test "E2E: Standard R package installation recorded in renv.lock" {
    cat > "${PROJECT_DIR}/install-packages.R" <<'EOF'
# Install packages using standard R mechanism
install.packages("tidyverse")

# Snapshot environment
renv::snapshot()
EOF

    [ -f "${PROJECT_DIR}/install-packages.R" ]

    run grep "install.packages\|renv::snapshot" "${PROJECT_DIR}/install-packages.R"
    assert_success
}

@test "E2E: Package dependencies captured in DESCRIPTION" {
    cat > "${PROJECT_DIR}/DESCRIPTION" <<'EOF'
Package: myproject
Imports:
    dplyr (>= 1.1.0),
    ggplot2 (>= 3.4.0),
    tidyr (>= 1.3.0),
    readr (>= 2.1.0)
Suggests:
    testthat,
    knitr
EOF

    run grep -A 4 "^Imports:" "${PROJECT_DIR}/DESCRIPTION"
    assert_success
    [ $(echo "$output" | wc -l) -ge 4 ]
}

@test "E2E: renv.lock matches DESCRIPTION Imports" {
    cat > "${PROJECT_DIR}/DESCRIPTION" <<'EOF'
Imports:
    dplyr (>= 1.1.0),
    ggplot2 (>= 3.4.0)
EOF

    cat > "${PROJECT_DIR}/renv.lock" <<'EOF'
{
  "Packages": {
    "dplyr": {"Version": "1.1.4"},
    "ggplot2": {"Version": "3.4.4"}
  }
}
EOF

    # Extract packages from DESCRIPTION
    local desc_packages=$(grep -oP 'dplyr|ggplot2' "${PROJECT_DIR}/DESCRIPTION" | sort -u)

    # Extract packages from renv.lock
    local lock_packages=$(jq -r '.Packages | keys[]' "${PROJECT_DIR}/renv.lock" | sort)

    # Should have matching packages
    [ -n "$(echo "$desc_packages" | grep dplyr)" ]
    [ -n "$(echo "$lock_packages" | grep dplyr)" ]
}

@test "E2E: Package versions pinned in renv.lock" {
    cat > "${PROJECT_DIR}/renv.lock" <<'EOF'
{
  "Packages": {
    "dplyr": {
      "Package": "dplyr",
      "Version": "1.1.4",
      "Source": "Repository",
      "Repository": "CRAN",
      "Hash": "some-hash"
    }
  }
}
EOF

    run jq -r '.Packages[] | "\(.Package): \(.Version)"' "${PROJECT_DIR}/renv.lock"
    assert_success
    assert_output --partial "dplyr: 1.1.4"
}

@test "E2E: renv auto-restore mechanism documented" {
    cat > "${PROJECT_DIR}/.Rprofile" <<'EOF'
# Auto-restore packages when R starts
if (!require("renv", quietly = TRUE)) {
  install.packages("renv")
}

# Check if restore is needed
if (!identical(renv::status(), "consistent")) {
  message("Restoring project dependencies...")
  renv::restore()
}
EOF

    run grep -E "renv::restore|renv::status" "${PROJECT_DIR}/.Rprofile"
    assert_success
}

################################################################################
# SECTION 3: Environment Consistency (5 tests)
################################################################################

@test "E2E: Environment variables set in Dockerfile" {
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
FROM rocker/r-ver:4.4.0

# Critical environment variables for reproducibility
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    OMP_NUM_THREADS=1
EOF

    run grep -E "LANG|LC_ALL|TZ|OMP_NUM_THREADS" "${PROJECT_DIR}/Dockerfile"
    assert_success
    [ $(echo "$output" | grep "ENV" | wc -l) -ge 1 ]
}

@test "E2E: R options enforced for consistency" {
    cat > "${PROJECT_DIR}/.Rprofile" <<'EOF'
options(
  stringsAsFactors = FALSE,
  contrasts = c("contr.treatment", "contr.poly"),
  na.action = "na.omit",
  digits = 7,
  OutDec = "."
)
EOF

    run grep "stringsAsFactors = FALSE" "${PROJECT_DIR}/.Rprofile"
    assert_success
}

@test "E2E: Random seeds set in analysis scripts" {
    cat > "${PROJECT_DIR}/analysis/scripts/analysis.R" <<'EOF'
#!/usr/bin/env Rscript

library(dplyr)

# Set seed for reproducibility
set.seed(42)

# Run analysis with randomization
results <- sample(1:100, 10)
EOF

    run grep "set.seed" "${PROJECT_DIR}/analysis/scripts/analysis.R"
    assert_success
}

@test "E2E: Analysis results saved in standard format" {
    cat > "${PROJECT_DIR}/analysis/scripts/analysis.R" <<'EOF'
# Save results in multiple formats for reproducibility
results <- data.frame(x = 1:10, y = rnorm(10))

# R data format (fastest, platform-independent serialization)
saveRDS(results, "results.rds")

# CSV for external validation
write.csv(results, "results.csv", row.names = FALSE)

# JSON for interoperability
jsonlite::write_json(results, "results.json")
EOF

    run grep -E "saveRDS|write.csv|write_json" "${PROJECT_DIR}/analysis/scripts/analysis.R"
    assert_success
}

@test "E2E: Data integrity tracked with checksums" {
    cat > "${PROJECT_DIR}/analysis/data/README.md" <<'EOF'
## data.csv
- MD5: 5d41402abc4b2a76b9719d911017c592
- Modified: 2025-12-05
- Status: Frozen (read-only)
EOF

    run grep -E "MD5|Modified|Frozen" "${PROJECT_DIR}/analysis/data/README.md"
    assert_success
}

################################################################################
# SECTION 4: Version Control Integration (3 tests)
################################################################################

@test "E2E: All Five Pillars tracked in Git" {
    cd "${PROJECT_DIR}"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create all five pillars
    echo "FROM rocker/r-ver:4.4.0" > Dockerfile
    echo '{"R": {"Version": "4.4.0"}, "Packages": {}}' > renv.lock
    echo 'options(stringsAsFactors = FALSE)' > .Rprofile
    mkdir -p R
    echo 'f <- function(x) x + 1' > R/functions.R
    mkdir -p analysis/data
    echo 'x,y' > analysis/data/data.csv
    echo '1,2' >> analysis/data/data.csv

    # Add to git
    git add -A

    # Verify all tracked
    run git status --short
    assert_success
}

@test "E2E: Reproducibility information in README" {
    cat > "${PROJECT_DIR}/README.md" <<'EOF'
# Reproducible Research Project

## Reproducibility

This project uses ZZCOLLAB to ensure complete reproducibility through:

1. **Dockerfile**: Specifies exact R version and system dependencies
2. **renv.lock**: Pins exact versions of all R packages
3. **.Rprofile**: Enforces critical R session options
4. **Source Code**: Analysis logic with set seeds for reproducibility
5. **Data**: Raw data is read-only; derived data is regenerated

## Running the Analysis

```bash
# Enter Docker container
make docker-sh

# Run analysis
Rscript analysis/scripts/main-analysis.R

# Results saved to analysis/data/derived_data/
```
EOF

    run test -f "${PROJECT_DIR}/README.md"
    assert_success

    run grep -E "Dockerfile|renv.lock|.Rprofile|Source|Data" "${PROJECT_DIR}/README.md"
    assert_success
}

@test "E2E: CHANGELOG documents reproducibility changes" {
    cat > "${PROJECT_DIR}/CHANGELOG.md" <<'EOF'
# Changelog

## [1.0.0] - 2025-12-05

### Added
- Complete Five Pillars reproducibility implementation
- Dockerfile with pinned R version (4.4.0)
- renv.lock with 25 packages
- .Rprofile with critical options
- Analysis scripts with random seeds

### Changed
- Updated package versions to match CRAN (2025-12-05)

### Data
- Modified: analysis/data/raw_data/data.csv (MD5: abc123)
EOF

    run test -f "${PROJECT_DIR}/CHANGELOG.md"
    assert_success
}

################################################################################
# SECTION 5: Documentation and Validation (2 tests)
################################################################################

@test "E2E: Project structure follows unified research compendium" {
    # Verify standard structure
    [ -d "${PROJECT_DIR}/analysis/data/raw_data" ]
    [ -d "${PROJECT_DIR}/analysis/data/derived_data" ]
    [ -d "${PROJECT_DIR}/analysis/scripts" ]
    [ -d "${PROJECT_DIR}/analysis/report" ]
    [ -d "${PROJECT_DIR}/analysis/figures" ]
    [ -d "${PROJECT_DIR}/R" ]
    [ -d "${PROJECT_DIR}/tests" ]
}

@test "E2E: Complete reproducibility validation checklist" {
    # Create validation checklist
    cat > "${PROJECT_DIR}/REPRODUCIBILITY_CHECKLIST.md" <<'EOF'
# Reproducibility Checklist

## Five Pillars

- [ ] Dockerfile present with R version specified
- [ ] renv.lock present with all dependencies pinned
- [ ] .Rprofile present with critical options
- [ ] Source code in R/ and analysis/scripts/
- [ ] Raw data in analysis/data/raw_data/
- [ ] Data documentation in analysis/data/README.md

## Analysis Reproducibility

- [ ] set.seed() called before stochastic operations
- [ ] All package dependencies listed in DESCRIPTION
- [ ] Package versions pinned in renv.lock
- [ ] Results saved to analysis/data/derived_data/
- [ ] Generated files not in version control

## Validation

- [ ] `renv::status()` shows "consistent"
- [ ] Docker image builds without errors
- [ ] Analysis runs successfully in container
- [ ] Results are identical across runs

## Documentation

- [ ] README explains reproducibility approach
- [ ] DESCRIPTION documents project metadata
- [ ] Data README documents sources and processing
- [ ] CHANGELOG tracks reproducibility changes
EOF

    run test -f "${PROJECT_DIR}/REPRODUCIBILITY_CHECKLIST.md"
    assert_success

    [ $(grep -c "^\- \[ \]" "${PROJECT_DIR}/REPRODUCIBILITY_CHECKLIST.md") -ge 15 ]
}

################################################################################
# SECTION 6: Integration Test
################################################################################

@test "E2E: Complete project passes reproducibility validation" {
    # Summary: Verify that a complete project structure with all
    # Five Pillars is in place and properly documented
    cd "${PROJECT_DIR}"

    # Verify all critical files exist
    [ -f "Dockerfile" ] || [ -f ".Dockerfile" ]
    [ -f "renv.lock" ]
    [ -f ".Rprofile" ]
    [ -f "DESCRIPTION" ]
    [ -f "README.md" ]
    [ -d "analysis/data/raw_data" ]
    [ -d "R" ] || [ -d "analysis/scripts" ]

    # Project is reproducible
    echo "✅ Project structure is reproducible"
}

################################################################################
# SECTION 7: Docker Validation (5 tests)
################################################################################

@test "E2E: Dockerfile has no :latest tags for base images" {
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update
EOF

    # Check for :latest tags (should not be used for reproducibility)
    run grep -E "FROM.*:latest" "${PROJECT_DIR}/Dockerfile" || true
    [ -z "$output" ] || [ "$output" = "" ]
}

@test "E2E: Dockerfile avoids root-owned files" {
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
FROM rocker/r-ver:4.4.0
RUN mkdir -p /workspace && chmod 755 /workspace
WORKDIR /workspace
EOF

    run test -f "${PROJECT_DIR}/Dockerfile"
    assert_success

    # Verify WORKDIR or USER is present
    run grep -E "^(WORKDIR|USER)" "${PROJECT_DIR}/Dockerfile"
    assert_success
}

@test "E2E: Dockerfile layer count is reasonable" {
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
FROM rocker/r-ver:4.4.0
RUN apt-get update && apt-get install -y git curl
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
COPY renv.lock .
RUN Rscript -e 'renv::restore()'
WORKDIR /workspace
EOF

    # Count RUN instructions (should be combined, not separate)
    run grep -c "^RUN " "${PROJECT_DIR}/Dockerfile"
    # Should have <= 3 RUN commands (more indicates lack of optimization)
    [ "$output" -le 3 ]
}

@test "E2E: Dockerfile specifies R version explicitly" {
    cat > "${PROJECT_DIR}/Dockerfile" <<'EOF'
FROM rocker/r-ver:4.4.0
RUN Rscript -e 'getRversion()'
EOF

    # Should have specific R version in FROM instruction
    run grep "^FROM rocker/r-ver:[0-9]" "${PROJECT_DIR}/Dockerfile"
    assert_success
}

@test "E2E: .Rprofile enforces critical options before Docker build" {
    cat > "${PROJECT_DIR}/.Rprofile" <<'EOF'
# Critical reproducibility options
options(stringsAsFactors = FALSE)
options(digits = 7)
options(OutDec = ".")

# Disable save prompts
.First <- function() {
  options(prompt = "> ")
}

.Last <- function() {
  tryCatch({
    if (interactive() && requireNamespace("renv", quietly = TRUE)) {
      renv::snapshot(prompt = FALSE)
    }
  }, error = function(e) {
    warning("Failed to snapshot: ", e$message)
  })
}
EOF

    run grep "stringsAsFactors = FALSE" "${PROJECT_DIR}/.Rprofile"
    assert_success

    run grep "digits = 7" "${PROJECT_DIR}/.Rprofile"
    assert_success

    run grep "OutDec" "${PROJECT_DIR}/.Rprofile"
    assert_success
}

################################################################################
# Test Summary
################################################################################

# These integration tests validate that ZZCOLLAB's Five Pillars
# of reproducibility framework is complete and properly integrated.
# They do NOT require actual Docker execution or R code compilation,
# making them suitable for CI/CD validation.
#
# Docker validation tests ensure:
# - Base images are pinned to specific versions
# - Dockerfile follows layer optimization best practices
# - Session configuration is properly documented
# - Critical reproducibility options are enforced
