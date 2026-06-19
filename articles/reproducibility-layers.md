# Layered Approach to Reproducibility

## Introduction

Reproducibility in computational research exists on a spectrum. This
guide presents a progressive, five-level approach to reproducibility
using ZZCOLLAB, allowing researchers to adopt tools incrementally based
on project needs and collaboration requirements.

Each level adds specific guarantees about reproducibility while
introducing additional complexity. Understanding the tradeoffs enables
informed decisions about appropriate reproducibility investments for
different research contexts.

### The Five Levels

1.  **Level 1: Basic R Project** - Manual package management
2.  **Level 2: renv** - Automated dependency tracking
3.  **Level 3: renv + Docker** - Complete environment isolation
4.  **Level 4: renv + Docker + Unit Testing** - Computational
    correctness
5.  **Level 5: renv + Docker + Unit Testing + CI/CD** - Automated
    validation

## Level 1: Basic R Project

### What This Provides

A standard R project structure with manual package management. Packages
are installed in the user’s global R library using
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html).

### Project Structure

    my-project/
    ├── .Rproj
    ├── R/
    │   └── functions.R
    ├── data/
    │   └── raw_data/
    ├── scripts/
    │   └── 01_analysis.R
    └── README.md

### Setup

``` r

# Create project in RStudio: File > New Project > New Directory > New Project
# Or from command line:
dir.create("my-project")
setwd("my-project")
dir.create(c("R", "data/raw_data", "scripts"))
```

### Typical Workflow

``` r

# Install packages globally
install.packages("dplyr")
install.packages("ggplot2")

# Load packages in scripts
library(dplyr)
library(ggplot2)

# Perform analysis
data %>%
  filter(condition) %>%
  ggplot(aes(x, y)) + geom_point()
```

### Pros

- **Simple**: No additional tools or concepts to learn
- **Fast setup**: Start coding immediately
- **Flexible**: Easy to experiment with new packages
- **Low overhead**: No configuration files to maintain
- **Standard workflow**: Familiar to most R users

### Cons

- **No version tracking**: Package versions not recorded
- **Update fragility**:
  [`update.packages()`](https://rdrr.io/r/utils/update.packages.html)
  can break existing code
- **Collaboration friction**: “Works on my machine” problems common
- **Time-dependent failure**: Code may stop working months later due to
  package updates
- **Implicit dependencies**: No record of which packages are actually
  required
- **System-dependent**: Results may differ across operating systems

### When to Use Level 1

Appropriate for:

- Personal exploratory analysis
- Short-lived projects (\< 1 week)
- Learning R and packages
- Quick prototypes not intended for sharing
- Analysis you will not revisit

Not appropriate for:

- Published research
- Team collaboration
- Long-term projects
- Code you’ll share with others

### Reproducibility Failure Example

``` r

# January 2024: Code works
library(dplyr)
data %>% select(x, y) %>% filter(x > 0)  # dplyr 1.1.0

# June 2024: After update.packages()
# dplyr 1.2.0 introduces breaking change
# Code produces different results or fails
```

## Level 2: renv (Dependency Management)

### What This Adds

The `renv` package creates project-specific R libraries and records
exact package versions in a lockfile. Each project has isolated
dependencies independent of the global R library.

### Additional Structure

    my-project/
    ├── .Rproj
    ├── renv/                    # Project-specific package library
    ├── renv.lock               # Exact package versions (auto-generated)
    ├── .Rprofile               # Auto-activates renv (auto-generated)
    ├── R/
    ├── data/
    ├── scripts/
    └── README.md

### Setup

``` r
# Initialize renv in existing project
install.packages("renv")  # One-time global install
renv::init()

# Or create new project with ZZCOLLAB
mkdir my-project && cd my-project
zzc minimal                      # Minimal profile includes renv
```

### Typical Workflow

``` r

# Install packages (now project-specific)
# Both methods work - install.packages() is simpler in ZZCOLLAB Docker containers
install.packages("dplyr")
install.packages("ggplot2")
# For GitHub packages: remotes::install_github("user/package")

# Work normally
library(dplyr)
library(ggplot2)

# Save dependency state
# In ZZCOLLAB Docker containers: snapshot happens automatically on exit!
# Outside Docker: run renv::snapshot() manually

# Collaborator restores exact versions
renv::restore()   # Installs from renv.lock
```

### Pros

- **Version locking**: Exact package versions recorded in renv.lock
- **Project isolation**: Projects do not interfere with each other
- **Collaboration support**: Team members get identical package versions
- **Explicit dependencies**: renv.lock documents all required packages
- **Time resilience**: Project works months/years later with same
  packages
- **Safe updates**: Test updates in isolation before committing
- **Minimal learning curve**: Familiar R workflow with
  [`install.packages()`](https://rdrr.io/r/utils/install.packages.html)

### Cons

- **Additional storage**: Each project stores its own package copies
  (~100-500MB typical)
- **Initial setup time**: First
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
  downloads all packages
- **Snapshot discipline**: Must remember
  [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
  after package changes (automated in ZZCOLLAB Docker containers - see
  Level 3)
- **R version dependency**: Still depends on user’s R version
- **System library dependency**: Still depends on system libraries
  (gdal, geos, etc.)
- **Platform differences**: Windows vs Mac vs Linux can still cause
  issues

### When to Use Level 2

Appropriate for:

- Research projects intended for publication
- Team collaboration (2+ researchers)
- Long-term projects (\> 1 month)
- Code shared publicly
- Reproducible analysis workflows

Still insufficient for:

- Cross-platform guarantees (Windows/Mac/Linux differences)
- System library dependencies (geospatial, databases)
- Complete environment isolation
- Exact R version requirements

### Reproducibility Guarantee

**Guaranteed**: Same R package versions across users/time

**Not guaranteed**: Same R version, same system libraries, same OS

### Example Workflow

``` r
# Day 1: Start project
renv::init()
install.packages("tidyverse")
renv::snapshot()

# Day 30: Add new analysis
install.packages("lme4")
# ... write code ...
renv::snapshot()  # Remember to snapshot!

# Note: With ZZCOLLAB Docker (Level 3), snapshot happens automatically on container exit!

# Year 2: Collaborator joins
git clone project
# In R:
renv::restore()  # Gets exact package versions from Day 30
```

## Level 3: renv + Docker (Complete Environment)

### What This Adds

Docker containers provide complete environment isolation including R
version, system libraries, and operating system. Everything runs in an
identical Linux environment regardless of host operating system.

### Additional Structure

    my-project/
    ├── .Rproj
    ├── renv/
    ├── renv.lock
    ├── Dockerfile              # Environment definition
    ├── docker-compose.yml      # Container orchestration
    ├── .dockerignore           # Files to exclude from container
    ├── Makefile                # Convenient Docker commands
    ├── R/
    ├── data/
    ├── scripts/
    └── README.md

### Setup

``` bash
# Create project with Docker environment
mkdir my-project && cd my-project
zzc minimal                      # Full setup (init + renv + docker)

# Or add Docker to existing renv project
# (requires manual Dockerfile creation)
```

### Typical Workflow

``` bash
# Start development environment
make r

# Now inside container (identical Linux environment)
R
> install.packages("tidyverse")  # Standard R command works!
> # ... work normally ...
> quit()

# Exit container - AUTO-SNAPSHOT HAPPENS AUTOMATICALLY!
exit

# Auto-snapshot architecture (October 2025)
# - renv::snapshot() runs automatically on container exit
# - No manual snapshot command required!
# - renv.lock automatically updated and validated (via zzrenvcheck)

# Collaborator gets identical environment
git clone project
make r  # Builds identical container
```

### Pros

- **Complete isolation**: R version, packages, system libraries all
  controlled
- **Cross-platform consistency**: Same environment on Windows/Mac/Linux
- **System dependency management**: GDAL, GEOS, database drivers
  included
- **Reproducible system state**: Dockerfile version-controls entire
  environment
- **Development/production parity**: Same environment locally and on
  servers
- **Easy collaboration**: “Pull and run” - no local R installation
  needed
- **Multiple R versions**: Different projects can use different R
  versions

### Cons

- **Storage overhead**: Docker images 800MB-3GB per project
- **Learning curve**: Docker concepts (images, containers, volumes)
- **Initial setup time**: Building Docker image (2-20 minutes depending
  on mode)
- **Resource usage**: Docker daemon must run in background
- **File permission complexity**: User IDs can cause permission issues
- **Slower package installation**: First install in container takes
  longer
- **Platform limitations**: ARM64 (Apple Silicon) vs AMD64 compatibility
  issues

### When to Use Level 3

Appropriate for:

- Cross-platform collaboration (Windows/Mac/Linux teams)
- Projects with system dependencies (geospatial, databases)
- Research requiring exact R version specification
- Complex environment dependencies
- Production deployment of analysis pipelines
- Long-term archival (10+ years)

Overkill for:

- Solo projects on single platform
- Simple analysis with few dependencies
- Short-term exploratory work

### Reproducibility Guarantee

**Guaranteed**: Same R version, same packages, same system libraries,
same OS

**Not guaranteed**: Code correctness, analytical validity, absence of
bugs

### The Critical Gap: Environment vs Correctness

Docker ensures everyone runs code in an **identical environment**, but
does not ensure the **code produces correct results**. This is the
reproducibility paradox:

``` r

# Everyone gets the same WRONG answer in Docker
calculate_mean <- function(x) {
  sum(x)  # BUG: forgot to divide by length
}

# Reproducible? Yes - same environment, same (wrong) result
# Correct? No - analytical error
```

Level 3 guarantees **consistency** but not **correctness**. Level 4
addresses this gap.

### Example Workflow

``` bash
# Team lead creates environment with a geospatial base image
mkdir climate-study && cd climate-study
zzc analysis                     # Full setup; ML packages added via renv
zzcollab docker --base-image rocker/geospatial  # Add geospatial base image
zzc github                       # Create private GitHub repo

# Environment provides:
# - R version: latest stable
# - System libraries: gdal, geos, proj
# - Base packages: tidyverse, sf, terra, raster

# Build and share team image (installs packages from renv.lock)
make docker-build
make docker-push-team            # Optional but efficient for team

# Team member joins
git clone https://github.com/mylab/climate-study
cd climate-study
make docker-build               # Build from project Dockerfile
make r

# Inside container - everyone has same environment
R --version  # Same R version for all
sf::sf_extSoftVersion()  # Same GDAL version for all
```

### Docker Profiles

ZZCOLLAB provides predefined Docker profiles to balance image size and
capabilities:

``` bash
# Minimal: Essential R development (~650MB)
zzc minimal

# Analysis: Data analysis with tidyverse (~1.2GB) [RECOMMENDED]
# Statistical and machine learning packages are added via renv
zzc analysis

# RStudio Server in the browser
zzc rstudio

# Manuscript and report rendering (LaTeX/Quarto via the rocker/verse base image)
zzcollab docker --base-image rocker/verse

# Specialized domains (e.g. GIS, genomics) use a custom base image:
zzcollab docker --base-image rocker/geospatial

# List all available profiles
zzc help profiles
```

## Level 4: renv + Docker + Unit Testing (Computational Correctness)

### What This Adds

Unit testing validates that your code produces **correct results**, not
just **consistent results**. While Docker ensures the same environment,
tests ensure the analysis is analytically sound, free from logical
errors, and robust to edge cases.

### The Reproducibility Crisis Connection

Research demonstrates that 50-89% of published studies fail replication
attempts, often due to **computational errors that testing would
catch**:

- Off-by-one errors in data indexing
- Incorrect statistical calculations
- Silent data quality issues (missing values, outliers)
- Function side effects and state dependencies
- Edge cases not handled in data processing

Unit testing transforms implicit assumptions into **explicit, validated
specifications**.

### Additional Structure

    my-project/
    ├── .Rproj
    ├── renv/
    ├── renv.lock
    ├── Dockerfile
    ├── docker-compose.yml
    ├── inst/                           # Test suite (NEW)
    │   └── tinytest/
    │       ├── test-data-preparation.R # Data processing tests
    │       ├── test-analysis.R         # Statistical tests
    │       └── test-visualization.R    # Plot validation tests
    ├── tests/
    │   └── tinytest.R                  # tinytest driver
    ├── Makefile
    ├── R/
    │   └── data_functions.R           # Tested functions
    ├── data/
    ├── scripts/
    │   └── 01_analysis.R              # Uses tested functions
    └── README.md

### Setup

``` bash
# Create project with Docker environment (analysis profile recommended)
mkdir my-project && cd my-project
zzc analysis                     # Full setup (init + renv + docker)
zzc github                       # Create private GitHub repo (optional)

# tinytest infrastructure is created by zzcollab: tests/tinytest.R drives
# the suite, and test files live in inst/tinytest/. No usethis::use_testthat()
# is needed.
```

### Typical Workflow

``` bash
# Start development environment
make r

# Inside container: Test-Driven Development cycle
# 1. Write the test first in inst/tinytest/test-data-preparation.R.
#    tinytest uses bare top-level expectations (no test_that wrapper):

# inst/tinytest/test-data-preparation.R
library(palmerpenguins)
result <- prepare_data(penguins)
expect_false(anyNA(result$body_mass_g))

# 2. Run the test (fails - function does not exist yet)
#    make docker-test

# 3. Implement the function in R/data_functions.R to make it pass:
# R/data_functions.R
prepare_data <- function(data) {
  data |>
    dplyr::filter(!is.na(body_mass_g))
}

# 4. Run the test again (passes), then refactor with confidence
#    make docker-test
exit

# Validate in clean environment
make docker-test
```

### Pros

- **Validates correctness**: Ensures code produces analytically sound
  results
- **Catches regressions**: New changes do not break existing
  functionality
- **Documents behavior**: Tests serve as executable specifications
- **Enables refactoring**: Change implementation with confidence
- **Finds edge cases**: Forces consideration of boundary conditions
- **Improves design**: Testable code tends to be better structured
- **Team confidence**: Collaborators trust tested code
- **Research integrity**: Prevents computational errors from reaching
  publication

### Cons

- **Time investment**: Writing tests takes 20-40% additional development
  time
- **Learning curve**: tinytest syntax and testing patterns
- **Maintenance burden**: Tests must be updated when requirements change
- **False security**: Tests only validate what you test
- **Incomplete coverage**: Difficult to test some statistical properties
- **Over-testing risk**: Testing trivial code wastes time

### When to Use Level 4

Appropriate for:

- Research intended for publication
- Complex data processing pipelines
- Statistical analysis with non-trivial calculations
- Reusable analytical functions
- Projects with multiple data sources
- Analysis that will be extended or modified
- Collaboration where trust in correctness is critical

Not appropriate for:

- Quick exploratory analysis
- One-time data visualizations
- Simple descriptive statistics
- Code you will never revisit

### Reproducibility Guarantee

**Guaranteed**: Code correctness validated through executable
specifications

**Validated**: Data processing logic, statistical calculations, edge
case handling

**Not guaranteed**: Tests run automatically on every change (requires
Level 5)

### Test-Driven Data Analysis Workflow

#### Example: Palmer Penguins Analysis

**Scenario**: Analyze relationship between bill length and body mass
with log transformation.

##### Step 1: Write Tests for Data Preparation

``` r

# inst/tinytest/test-data-preparation.R
library(palmerpenguins)

# prepare_penguin_data removes missing values
result <- prepare_penguin_data(penguins)
expect_false(anyNA(result$body_mass_g))
expect_false(anyNA(result$bill_length_mm))

# prepare_penguin_data creates a correct log transformation
expect_true('log_body_mass_g' %in% names(result))
expect_equal(result$log_body_mass_g, log(result$body_mass_g))

# prepare_penguin_data handles edge cases
expect_equal(nrow(prepare_penguin_data(penguins[0, ])), 0L)
all_na <- penguins
all_na$body_mass_g <- NA
expect_equal(nrow(prepare_penguin_data(all_na)), 0L)
```

##### Step 2: Implement Function to Pass Tests

``` r

# R/data_functions.R

#' Prepare penguin data for analysis
#'
#' Removes missing values and creates log-transformed body mass variable.
#'
#' @param data Data frame with penguin measurements
#' @return Data frame with complete cases and log_body_mass_g variable
#' @export
prepare_penguin_data <- function(data) {
  data %>%
    filter(!is.na(body_mass_g), !is.na(bill_length_mm)) %>%
    mutate(log_body_mass_g = log(body_mass_g))
}
```

##### Step 3: Write Tests for Statistical Analysis

``` r

# inst/tinytest/test-analysis.R
test_data <- prepare_penguin_data(penguins)
model <- fit_penguin_model(test_data)

# fit_penguin_model returns a valid lm object
expect_inherits(model, 'lm')
expect_true('bill_length_mm' %in% names(coef(model)))
expect_true(summary(model)$r.squared > 0)

# Coefficients are sensible: larger bills imply larger penguins
expect_true(coef(model)['bill_length_mm'] > 0)
```

##### Step 4: Implement Analysis Function

``` r

# R/analysis_functions.R

#' Fit linear model of log body mass vs bill length
#'
#' @param data Prepared penguin data
#' @return Linear model object
#' @export
fit_penguin_model <- function(data) {
  lm(log_body_mass_g ~ bill_length_mm, data = data)
}
```

##### Step 5: Write Tests for Data Quality

``` r

# inst/tinytest/test-data-quality.R

# Penguin data has the expected structure
required_cols <- c('species', 'island', 'bill_length_mm',
                   'bill_depth_mm', 'body_mass_g')
expect_true(all(required_cols %in% names(penguins)))
expect_true(nrow(penguins) > 300)
expect_true(all(penguins$species %in%
                  c('Adelie', 'Chinstrap', 'Gentoo')))

# Body mass measurements are plausible (2500g to 6500g, all positive)
valid_data <- penguins[!is.na(penguins$body_mass_g), ]
expect_true(all(valid_data$body_mass_g >= 2500))
expect_true(all(valid_data$body_mass_g <= 6500))
expect_true(all(valid_data$body_mass_g > 0))
```

### Test Coverage Requirements

Professional research code should achieve **\>90% test coverage** for
analytical functions:

``` r

# Check test coverage
library(covr)
coverage <- package_coverage()
percent_coverage(coverage)
# [1] 94.2%

# Generate coverage report
report(coverage)
```

**Coverage Guidelines**:

- **100% coverage**: Core statistical calculations, data transformations
- **\>90% coverage**: Data preparation functions, analysis pipelines
- **\>75% coverage**: Visualization functions, reporting code
- **Not required**: Interactive exploration scripts, one-off analyses

### Testing Best Practices for Research

These examples use tinytest, the framework ZZCOLLAB projects ship with.
Expectations are written as bare top-level calls; there is no
`test_that()` wrapper.

#### Test Data Transformations

``` r

# outlier removal preserves data integrity
test_data <- data.frame(x = c(1, 2, 100, 3, 4))  # 100 is an outlier
result <- remove_outliers(test_data, 'x', threshold = 3)
expect_equal(nrow(result), 4L)
expect_true(all(c(1, 2, 3, 4) %in% result$x))
```

#### Test Statistical Calculations

``` r

# standard error calculation is correct
x <- c(1, 2, 3, 4, 5)
expect_equal(calculate_se(x), sd(x) / sqrt(length(x)))
```

#### Test Edge Cases

``` r

# analysis handles edge cases gracefully

# Single observation
expect_error(fit_model(data.frame(x = 1, y = 2)),
             pattern = 'Insufficient data')

# No variance
expect_warning(fit_model(data.frame(x = c(1, 1, 1), y = c(2, 3, 4))),
               pattern = 'No variance in predictor')

# Perfect correlation
result <- fit_model(data.frame(x = 1:10, y = 1:10))
expect_equal(summary(result)$r.squared, 1.0)
```

### Scientific Motivation for Testing

#### The Cost of Computational Errors

Research by Stodden et al. (2018) found:

- **70% of researchers** have tried and failed to reproduce another
  scientist’s experiments
- **50% have failed** to reproduce their own experiments
- **Computational errors** are a leading cause of replication failures

#### Real-World Testing Impact

A study of GitHub projects (Mockus, 2010) demonstrated:

- Projects with **\>80% test coverage** had **40% fewer defects**
- Test-driven development reduced debugging time by **16%**
- Tested code had **24% higher change success rate**

#### Testing Prevents Silent Failures

``` r

# Without tests: Silent error propagates
analyze_data <- function(data) {
  # BUG: Uses sd() instead of var() for variance
  variance <- sd(data$x)  # WRONG

  # Analysis appears to work but results are incorrect
  result <- mean(data$x) / variance
  return(result)
}

# With tests: error caught immediately
# This expectation fails, exposing the bug
x <- c(1, 2, 3, 4, 5)
expect_equal(calculate_variance(x), var(x))  # FAILS
```

### Common Testing Mistakes

#### Testing Too Little

``` r

# Insufficient test: only tests type, not correctness
result <- my_function(data)
expect_true(is.data.frame(result))

# Better test: specific expected behavior
test_data <- data.frame(x = c(1, 2, 3), y = c(4, 5, 6))
result <- my_function(test_data)
expect_equal(result$x_squared, c(1, 4, 9))
expect_equal(result$y_doubled, c(8, 10, 12))
expect_equal(nrow(result), 3L)
```

#### Testing Implementation Instead of Behavior

``` r

# Wrong: tests implementation details (breaks if you refactor to base R)
expect_true(exists('filter', envir = environment(my_function)))

# Right: tests behavior (passes regardless of implementation)
result <- my_function(data.frame(x = c(1, NA, 3)))
expect_false(anyNA(result))
```

#### Not Testing Edge Cases

``` r

# Incomplete testing: normal case only
expect_equal(calculate_mean(c(1, 2, 3)), 2)

# Complete testing includes edge cases
expect_equal(calculate_mean(c(1, 2, 3)), 2)        # Normal case
expect_equal(calculate_mean(5), 5)                 # Single value
expect_true(is.nan(calculate_mean(numeric(0))))    # Empty vector
expect_equal(calculate_mean(c(1, NA, 3), na.rm = TRUE), 2)  # Missing
```

### Migration from Level 3

Adding tests to existing Docker project:

``` bash
# The tinytest scaffolding (tests/tinytest.R) already exists in a zzcollab
# project. Add test files under inst/tinytest/, then run the suite.

# Create a test file for an existing function:
#   inst/tinytest/test-my_function.R
# Write tests for critical functions, focusing on data preparation
# and statistical calculations.

# Run the suite and check coverage
make docker-test
make r
# Inside the container, optionally check coverage:
# covr::package_coverage()
exit

# Commit the tests
git add inst/tinytest/ DESCRIPTION
git commit -m "Add unit tests"
```

### When Testing Is Not Worth It

Testing has costs. Skip testing for:

- **One-time exploratory scripts** that will not be reused
- **Simple visualizations** with no calculations
- **Wrapper functions** that only call other tested functions
- **Interactive analysis** you will not share

Focus testing effort on:

- **Data processing pipelines** with complex logic
- **Statistical calculations** beyond simple base R functions
- **Functions used across multiple analyses**
- **Code that will be shared or published**

## Level 5: renv + Docker + Unit Testing + CI/CD (Automated Validation)

### What This Adds

Continuous Integration/Continuous Deployment (CI/CD) automatically
validates that your code works in a clean environment on every commit.
GitHub Actions (or similar) run tests, checks, and builds to catch
errors early.

### Additional Structure

    my-project/
    ├── .Rproj
    ├── renv/
    ├── renv.lock
    ├── Dockerfile
    ├── docker-compose.yml
    ├── .github/
    │   └── workflows/
    │       ├── r-package.yml           # R package validation
    │       └── render-paper.yml        # Manuscript rendering
    ├── inst/
    │   └── tinytest/
    │       └── test-analysis.R         # Automated tests
    ├── tests/
    │   └── tinytest.R                  # tinytest driver
    ├── Makefile
    ├── R/
    ├── data/
    ├── scripts/
    └── README.md

### Setup

``` bash
# Create project with CI/CD workflows
mkdir my-project && cd my-project
zzc analysis                     # Full setup (init + renv + docker)
zzc github                       # Create private GitHub repo with CI/CD

# GitHub Actions workflows automatically created
```

### Typical Workflow

``` bash
# Develop locally
make r
# ... work in container ...
exit  # Auto-snapshot runs on exit!

# Validate before committing (make check-renv runs zzrenvcheck)
make check-renv
make docker-test

# Commit and push
git add .
git commit -m "Add climate model analysis"
git push

# GitHub Actions automatically:
# 1. Builds Docker container from scratch
# 2. Validates package dependencies (zzrenvcheck via make check-renv)
# 3. Runs R CMD check
# 4. Executes test suite
# 5. Renders manuscripts
# 6. Reports failures via email
```

### Pros

- **Automated validation**: Every commit tested automatically
- **Clean environment testing**: Catches “works on my machine” problems
- **Team notification**: Everyone notified when code breaks
- **Prevents regressions**: Tests ensure new code does not break old
  code
- **Documentation validation**: Ensures examples in documentation work
- **Deployment automation**: Can auto-deploy working versions
- **Confidence in main branch**: Main branch always in working state
- **Newcomer safety**: Contributors cannot accidentally break the
  project

### Cons

- **Setup complexity**: GitHub Actions YAML syntax learning curve
- **Build time overhead**: Full validation takes 5-20 minutes per commit
- **GitHub dependency**: Requires GitHub (or GitLab, etc.)
- **Resource limits**: Free tier has monthly minute limits
- **Debugging difficulty**: CI failures can be harder to debug than
  local errors
- **Over-testing risk**: Running tests on trivial commits wastes
  resources
- **Notification fatigue**: Failed builds generate email notifications

### When to Use Level 4

Appropriate for:

- Team projects (3+ collaborators)
- Open source packages intended for CRAN
- Production analysis pipelines
- Research with frequent updates
- Projects with complex test suites
- Collaborative papers with multiple authors

Overkill for:

- Solo exploratory analysis
- Stable projects with infrequent changes
- Simple scripts without tests

### Reproducibility Guarantee

**Guaranteed**: Automated validation runs on every commit

**Validated**: Package dependencies, test suite, documentation examples,
clean environment builds

**Complete Stack**: Environment consistency (Docker) + computational
correctness (tests) + automated verification (CI/CD)

### GitHub Actions Workflows

ZZCOLLAB creates two standard workflows:

#### r-package.yml (Core Validation)

``` yaml
# Runs on: every push, every pull request
# Validates:
#   - Package dependencies synchronized (zzrenvcheck via make check-renv)
#   - R CMD check passes
#   - Test suite passes
#   - Project structure valid
```

#### render-paper.yml (Manuscript)

``` yaml
# Runs on: every push to main branch
# Produces:
#   - Rendered manuscript PDF/HTML
#   - Uploaded as artifact
#   - Available for download
```

### Example Workflow

``` bash
# Day 1: Setup with CI/CD
mkdir paper2024 && cd paper2024
zzc analysis                     # Full setup (init + renv + docker)
zzc github                       # Create private GitHub repo with CI/CD

# Automatically created GitHub repo with Actions enabled

# Day 5: Add analysis code
make r
# ... develop code ...
# ... write tests in inst/tinytest/ ...
exit  # Auto-snapshot runs automatically!

# Validate locally first (make check-renv runs zzrenvcheck)
make check-renv
make docker-test

# Commit and push
git add .
git commit -m "Add primary analysis"
git push

# GitHub Actions runs automatically:
# - Builds Docker container
# - Validates dependencies (zzrenvcheck via make check-renv)
# - Runs all tests
# - Success: green checkmark on commit
# - Failure: email notification with logs

# Day 30: Collaborator contributes
# Opens pull request
# GitHub Actions validates their code before merge
# Maintainer reviews with confidence tests passed
```

### CI/CD Best Practices

**Write tests incrementally**:

``` r

# inst/tinytest/test-data-preparation.R
raw <- data.frame(x = c(1, NA, 3), y = c(4, 5, 6))
result <- prepare_data(raw)
expect_equal(nrow(result), 2L)
expect_false(anyNA(result))
```

**Validate dependencies before committing**:

``` bash
# Confirm all packages used in code are declared (zzrenvcheck)
make check-renv

# This prevents CI failures due to missing packages
```

**Use descriptive commit messages**:

``` bash
# Good: Helps understand CI failure context
git commit -m "Add bootstrapping to uncertainty analysis"

# Bad: Unclear what CI is testing
git commit -m "Update code"
```

## Choosing the Right Level

### Decision Framework

#### Solo Researcher, Exploratory Phase

**Recommendation**: Level 1 or Level 2

- Level 1 if analysis is temporary (\< 1 week)
- Level 2 if you might return to this analysis

#### Solo Researcher, Publication-Bound

**Recommendation**: Level 2 or Level 3

- Level 2 if Windows/Mac-only collaboration
- Level 3 if cross-platform or system dependencies

#### Small Team (2-4 people), Same Platform

**Recommendation**: Level 2

- renv ensures package consistency
- Docker overhead not justified for same-platform teams

#### Small Team (2-4 people), Mixed Platforms

**Recommendation**: Level 3 or Level 4

- Level 3 if analysis is straightforward with few calculations
- Level 4 if complex data processing or statistical methods

#### Large Team (5+ people)

**Recommendation**: Level 5

- Automated testing prevents integration problems
- CI/CD essential for coordinating multiple contributors
- Unit tests document expected behavior for new contributors

#### Package Development for CRAN

**Recommendation**: Level 5

- R CMD check must pass on multiple platforms
- Automated testing required for maintenance
- CI/CD validates every contribution before merge

### Cost-Benefit by Project Duration

| Project Duration | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 |
|------------------|---------|---------|---------|---------|---------|
| \< 1 week        | ✓       | ~       | ✗       | ✗       | ✗       |
| 1 week - 1 month | ~       | ✓       | ~       | ✗       | ✗       |
| 1-6 months       | ✗       | ✓       | ✓       | ~       | ✗       |
| 6+ months        | ✗       | ~       | ✓       | ✓       | ~       |
| Multi-year       | ✗       | ✗       | ✓       | ✓       | ✓       |
| Team (5+ people) | ✗       | ✗       | ~       | ✓       | ✓       |

✓ = Recommended, ~ = Consider, ✗ = Not recommended

### Migration Path

Projects can migrate progressively:

    Level 1 → Level 2:
      renv::init()  # 5 minutes

    Level 2 → Level 3:
      zzc minimal                    # Quick minimal setup
      zzc analysis                   # Or full analysis environment

    Level 3 → Level 4:
      # tinytest scaffolding already exists (tests/tinytest.R)
      # Add test files under inst/tinytest/ for critical functions
      # 1-2 days for a comprehensive test suite

    Level 4 → Level 5:
      zzc github                     # Adds GitHub workflows (or already done)

No need to commit to Level 5 immediately - start at Level 2, add Docker
when needed for cross-platform work, add tests when analysis complexity
grows, add CI/CD when team grows.

## Practical Examples

### Example 1: Solo Exploratory Analysis

**Scenario**: Testing a new statistical method on small dataset.

**Duration**: 2 days

**Recommended Level**: Level 1

**Rationale**: Quick iteration more important than reproducibility. If
method shows promise, migrate to Level 2 for thorough analysis.

``` r

# Just use global packages
install.packages("bootstrap")
library(bootstrap)

# Analyze and move on
```

### Example 2: Master’s Thesis Analysis

**Scenario**: Student analyzing dataset for thesis. Will share code with
advisor. May extend analysis for publication.

**Duration**: 3-6 months

**Recommended Level**: Level 2

**Rationale**: Need to ensure advisor can reproduce results. Long enough
that packages might update during analysis.

``` r

# Initialize renv
renv::init()
install.packages("tidyverse")
install.packages("lme4")

# Analysis code...

# Snapshot before sharing with advisor
renv::snapshot()

# Advisor runs:
renv::restore()  # Gets exact package versions
```

### Example 3: Multi-Site Climate Study

**Scenario**: Three universities collaborating on climate analysis.
Different platforms (Windows, Mac, Linux). Complex geospatial
dependencies. Custom spatial interpolation algorithms.

**Duration**: 2 years

**Recommended Level**: Level 4

**Rationale**: Cross-platform team requires Docker. Complex custom
algorithms require unit tests to ensure correctness. Geospatial packages
(sf, terra) have complex system dependencies.

``` bash
# Team lead setup with a geospatial base image
mkdir precipitation && cd precipitation
zzc analysis                     # Full setup; ML packages added via renv
zzcollab docker --base-image rocker/geospatial  # Add geospatial base image
zzc github                       # Create private GitHub repo

# Build and share team image (installs packages from renv.lock)
make docker-build
make docker-push-team            # Optional but efficient for team

# Add tests under inst/tinytest/ (tinytest scaffolding already present):
# - Tests for spatial interpolation algorithms
# - Tests for data quality validation
make docker-test

# Team members (any platform)
git clone https://github.com/climate-team/precipitation
cd precipitation
make docker-build               # Build from project Dockerfile
make r  # Identical environment on all platforms

# Inside container - everyone has same GDAL, GEOS versions
# Tests validate spatial algorithms work correctly
```

### Example 4: Open Source R Package

**Scenario**: Developing R package for CRAN submission. Contributors
from around world. Must pass R CMD check on Windows/Mac/Linux.

**Duration**: Ongoing

**Recommended Level**: Level 5

**Rationale**: Multiple contributors require automated testing. CRAN
submission requires validation on multiple platforms. CI/CD ensures
every contribution passes checks before merge.

``` bash
# Package maintainer setup
mkdir mypackage && cd mypackage
zzc analysis                     # Full setup (init + renv + docker)
zzc github                       # Create private GitHub repo with CI/CD

# Testing and CI/CD included automatically
# Every contributor push triggers:
# - R CMD check on Ubuntu
# - Test suite execution (unit tests)
# - Documentation validation
# - Dependency checking

# Pull requests show CI status
# Maintainer only merges if CI passes
```

### Example 5: Weekly Reporting Pipeline

**Scenario**: Automated weekly report generation from database. Runs on
server. Code rarely changes but must always work. Report includes
statistical summaries and data quality checks.

**Duration**: Ongoing

**Recommended Level**: Level 4

**Rationale**: Production deployment requires Docker. Statistical
calculations and data quality checks should be tested to prevent silent
errors in automated reports. CI/CD (Level 5) optional if code changes
infrequently.

``` bash
# Setup with Docker for production (minimal profile sufficient for reporting)
mkdir weekly-report && cd weekly-report
zzc minimal                      # Full setup with minimal profile

# Add tests for report calculations under inst/tinytest/:
# - Statistical summaries (means, medians, etc.)
# - Data quality checks (missing data, outliers)
# - Report formatting functions
make docker-test

# Deploy to server
docker build -t weekly-report .
docker run -v /data:/data weekly-report Rscript generate_report.R

# Optional: Add CI/CD (Level 5) if code complexity grows or team expands
zzc github                       # Creates GitHub repo with CI/CD workflows
```

## Technical Details

### renv Isolation Mechanism

renv creates a project-specific library by:

1.  **Installing packages to `renv/library/`** instead of global library
2.  **Recording versions in `renv.lock`** (JSON format)
3.  **Activating via `.Rprofile`** which sets
    [`.libPaths()`](https://rdrr.io/r/base/libPaths.html)

``` r

# Before renv::init()
.libPaths()
# [1] "/usr/local/lib/R/site-library"  # Global library

# After renv::init()
.libPaths()
# [1] "/project/renv/library/R-4.3/x86_64-pc-linux-gnu"  # Project library
# [2] "/usr/local/lib/R/site-library"                    # Fallback
```

### Docker Isolation Mechanism

Docker creates isolated environment by:

1.  **Base image** (rocker/r-ver:4.3.1) - specific R version
2.  **System libraries** (GDAL, GEOS, etc.) installed via apt-get
3.  **R packages** installed via Dockerfile instructions
4.  **Project files** mounted as volume

``` dockerfile
FROM rocker/r-ver:4.3.1
RUN apt-get update && apt-get install -y libgdal-dev
RUN R -e "install.packages('renv')"
WORKDIR /project
```

Container runs as isolated process with own filesystem, but project
directory is mounted for live editing.

### CI/CD Validation Mechanism

GitHub Actions validates by:

1.  **Checking out code** from repository
2.  **Building Docker container** from Dockerfile
3.  **Running validation scripts** in container
4.  **Reporting results** via GitHub interface

``` yaml
# .github/workflows/r-package.yml
jobs:
  check:
    runs-on: ubuntu-latest
    container: rocker/tidyverse:latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate dependencies (zzrenvcheck)
        run: make check-renv
```

## Common Pitfalls

### Level 2 Pitfalls (renv)

**Forgetting
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)**
(Note: Automated in ZZCOLLAB Docker!):

``` r
# Wrong workflow (manual renv without Docker)
install.packages("new-package")
# ... use package in code ...
git commit  # renv.lock not updated!

# Collaborator runs:
renv::restore()  # Doesn't get new-package
# Code fails with "package not found"

# Correct workflow (manual renv)
install.packages("new-package")
renv::snapshot()  # Update renv.lock
git add renv.lock
git commit

# ZZCOLLAB Docker auto-snapshot (October 2025):
# With ZZCOLLAB Docker containers, snapshot happens automatically on exit!
make r
install.packages("new-package")  # Standard R command works in Docker
exit  # Auto-snapshot runs automatically - no manual command needed!
git add renv.lock && git commit
```

**Package installation methods** (both work in ZZCOLLAB Docker
containers):

``` r

# Standard R command (recommended in ZZCOLLAB Docker containers)
install.packages("dplyr")  # Auto-captured in renv.lock on exit

# For GitHub packages
install.packages("remotes")
remotes::install_github("user/package")
```

**Note**: In ZZCOLLAB Docker containers,
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
works correctly because packages are automatically captured in renv.lock
when you exit the container.

### Level 3 Pitfalls (Docker)

**File permission issues**:

``` bash
# Inside container (running as root)
touch output.csv

# Outside container (your user)
rm output.csv  # Permission denied!

# Solution: Container should run as non-root user (zzcollab does this)
```

**Forgetting to exit container before git operations**:

``` bash
# Wrong
make r
git commit  # Runs inside container

# Right
make r
# ... work ...
exit  # Exit container first
git commit  # Run on host
```

**Editing files outside container**:

Files edited on host (Mac/Windows) are visible in container, but some
editors create temp files that can cause issues. Best practice: edit on
host, run in container.

### Level 4 Pitfalls (Unit Testing)

**Not testing edge cases**:

``` r

# Inadequate test: only checks the return type
result <- prepare_data(penguins)
expect_true(is.data.frame(result))

# Better test includes edge cases
expect_equal(nrow(prepare_data(penguins)), 333L)       # Normal case
expect_equal(nrow(prepare_data(penguins[0, ])), 0L)    # Empty data
all_na <- penguins
all_na$body_mass_g <- NA
expect_equal(nrow(prepare_data(all_na)), 0L)           # All missing
```

**Testing implementation details instead of behavior**:

``` r

# Wrong: tests how the function is implemented (breaks under refactoring)
expect_true(grepl('filter', deparse(body(prepare_data))))

# Right: tests what the function does (works regardless of implementation)
result <- prepare_data(penguins)
expect_false(anyNA(result$body_mass_g))
```

**Forgetting to run tests before committing**:

``` bash
# Wrong workflow
git commit -m "Update analysis"
make docker-test  # Fails - should have tested first

# Right workflow
make docker-test  # Test first
git commit -m "Update analysis"
```

### Level 5 Pitfalls (CI/CD)

**Not testing locally before pushing**:

``` bash
# Wrong workflow
git commit -m "Fix analysis"
git push  # CI fails, must fix and push again

# Right workflow (make check-renv runs zzrenvcheck)
make check-renv
make docker-test
git commit -m "Fix analysis"
git push  # CI passes
```

**Ignoring CI failures**:

CI failures must be fixed immediately. Ignoring them leads to: - Broken
main branch - Inability to merge pull requests - Loss of confidence in
tests

## Summary

Reproducibility is not binary - it exists on a spectrum. ZZCOLLAB
provides five levels of increasing reproducibility guarantees:

1.  **Level 1** (Manual): Quick start, no guarantees
2.  **Level 2** (renv): Package version guarantees
3.  **Level 3** (renv + Docker): Complete environment guarantees
4.  **Level 4** (renv + Docker + Unit Testing): Computational
    correctness guarantees
5.  **Level 5** (renv + Docker + Unit Testing + CI/CD): Automated
    validation guarantees

### The Three Dimensions of Reproducibility

Each level addresses a different dimension:

- **Environment Reproducibility** (Levels 2-3): Same packages, same R
  version, same system libraries
- **Computational Correctness** (Level 4): Code produces analytically
  sound results
- **Automated Verification** (Level 5): Continuous validation that
  everything still works

### Choosing Your Level

Choose the level appropriate for your project’s:

- **Duration**: Longer projects need more reproducibility
- **Team size**: Larger teams need more validation
- **Platform diversity**: Mixed platforms require Docker
- **Analytical complexity**: Complex calculations require tests
- **Publication requirements**: Published research needs high
  reproducibility
- **Maintenance needs**: Long-term projects need automated checks

### Progressive Adoption

Start simple and migrate incrementally as needs evolve:

- **Week 1**: Level 1 for exploration
- **Month 1**: Add Level 2 (renv) when committing to project
- **Month 2**: Add Level 3 (Docker) when collaborating cross-platform
- **Month 3**: Add Level 4 (Testing) when analysis complexity grows
- **Month 6**: Add Level 5 (CI/CD) when team expands

The goal is reproducibility without unnecessary complexity. Each level
adds value, but also adds overhead. Match the reproducibility investment
to the project requirements.
