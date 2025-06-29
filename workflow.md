# Developer Collaboration Workflow Sequence

Based on my review of the user guide, here are the specific workflows for developer collaboration using vim as the IDE:

## **🐳 Pre-Collaboration: Docker Image Setup**

### **📦 Developer 1 (Team Lead): Build and Publish Base Image**
```bash
# 1. Set up initial project and build optimized team image
mkdir research-project
cd research-project
zzrrtools --dotfiles ~/dotfiles

# 2. Install all anticipated R packages for the project
make docker-rstudio                # Start development environment
# In RStudio or R console:
# install.packages(c("tidyverse", "lme4", "ggplot2", "brms", "targets"))
# install.packages(c("visdat", "naniar", "skimr", "janitor"))  # Data validation
# renv::snapshot()                 # Lock all packages
# exit()

# 3. Build optimized team Docker image with all packages pre-installed
make docker-build                 # Rebuild with all packages
docker tag $(cat .project-name):latest ghcr.io/[TEAM]/$(cat .project-name):latest

# 4. Push team image to container registry
echo $GITHUB_TOKEN | docker login ghcr.io -u [TEAM-USERNAME] --password-stdin
docker push ghcr.io/[TEAM]/$(cat .project-name):latest

# 5. Update docker-compose.yml to use team image
vim docker-compose.yml
# Change: image: ${PKG_NAME}:latest
# To:     image: ghcr.io/[TEAM]/${PKG_NAME}:latest

# 6. Commit the team-ready environment
git init
git add .
git commit -m "🎉 Initial team setup with pre-built Docker image

- Complete zzrrtools research compendium
- All anticipated R packages pre-installed in Docker image
- Team image published to ghcr.io/[TEAM]/$(cat .project-name):latest
- Ready for team collaboration"

git remote add origin https://github.com/[TEAM]/project.git
git push -u origin main
```

### **🚀 Benefits of Pre-Built Team Image:**
- **⚡ Faster onboarding**: New developers get started in minutes, not hours
- **🔒 Environment consistency**: Everyone uses identical package versions
- **💾 Bandwidth efficiency**: ~500MB pull vs ~2GB+ rebuild
- **🛠️ CI/CD optimization**: Faster automated testing with pre-built dependencies
- **📦 Package management**: Centralized control over research environment
- **🔄 Version control**: Tag images for different analysis phases

## **Developer Collaboration Workflow Sequence**

### **🧑‍💻 Developer 1 (Initial Development Work)**
```bash
# Project setup already completed in pre-collaboration phase
cd research-project

# 1. Start development work in containerized vim environment
make docker-zsh                 # → Enhanced zsh shell with personal dotfiles

# 2. Add any additional packages for initial analysis
# (In zsh container with vim IDE)
R                               # Start R session
# Most packages already installed in team image
# install.packages("additional_package") # Only if needed
# renv::snapshot()              # Update if packages added
# quit()                        # Exit R

# 3. Test-driven development workflow using vim
# First, learn testing patterns
Rscript scripts/00_testing_guide.R   # → Review testing instructions

# Create package functions with tests
vim R/analysis_functions.R           # Create package functions
# Write R functions with vim + plugins

vim tests/testthat/test-analysis_functions.R  # Write tests for functions
# Write unit tests for each function:
# test_that("function_name works correctly", {
#   result <- my_function(test_data)
#   expect_equal(nrow(result), expected_value)
#   expect_true(all(result$column > 0))
# })

# Test the functions
R                                    # Start R session
# devtools::load_all()               # Load package functions
# devtools::test()                   # Run tests to verify functions work
# quit()                             # Exit R

vim scripts/01_data_import.R         # Create analysis scripts  
# Write data import code
# Note: scripts/ directory includes templates for:
# - 02_data_validation.R (data quality checks)
# - 00_setup_parallel.R (high-performance computing)
# - 00_database_setup.R (database connections)
# - 99_reproducibility_check.R (validation)
# - 00_testing_guide.R (testing instructions)

vim tests/integration/test-data_import.R  # Create integration tests
# Write integration tests for analysis scripts:
# test_that("data import script runs without errors", {
#   expect_no_error(source(here("scripts", "01_data_import.R")))
# })

vim analysis/paper/paper.Rmd        # Start research paper
# Write analysis and methods in R Markdown

# Test paper rendering
R                                   # Start R session
# rmarkdown::render("analysis/paper/paper.Rmd")  # Test paper compiles
# quit()                            # Exit R

# 4. Quality assurance and commit
exit                            # Exit container
make docker-check-renv-fix      # Validate dependencies
make docker-test                # Run package tests
make docker-render              # Test paper rendering
# Rscript scripts/99_reproducibility_check.R  # Optional: Check reproducibility

# 5. Commit changes with CI/CD trigger
git add .
git commit -m "Add initial analysis and dependencies"
git push                        # → Triggers GitHub Actions validation
```

### **👩‍💻 Developer 2 (Joining Project)**
```bash
# 1. Fork and clone the project (proper collaborative workflow)
# First: Fork https://github.com/[TEAM]/project.git on GitHub to your account
git clone https://github.com/[DEV2-USERNAME]/project.git
cd project

# 2. Set up upstream remote for syncing with team repo
git remote add upstream https://github.com/[TEAM]/project.git
git remote -v  # Verify: origin (your fork), upstream (team repo)

# 3. Use pre-built team Docker image (much faster!)
docker pull ghcr.io/[TEAM]/$(cat .project-name):latest  # Pull team image
# No need to build - all packages already installed!

# 4. Create feature branch for your work
git checkout -b feature/visualization-analysis

# 5. Start development immediately in vim environment
make docker-zsh                 # → Consistent zsh environment with Dev 1

# 6. Sync with latest packages and add new work
# (In zsh container with vim)
R                               # Start R session
# renv::restore()               # Get Dev 1's packages
# install.packages("ggplot2")   # Add new package
# renv::snapshot()              # Update environment
# quit()                        # Exit R

# 7. Test-driven development for visualization functions
vim R/plotting_functions.R      # Add plotting utilities
# Write ggplot2 wrapper functions

vim tests/testthat/test-plotting_functions.R  # Write tests for plotting functions
# Write unit tests for plotting functions:
# test_that("plot_function creates valid ggplot", {
#   p <- my_plot_function(test_data)
#   expect_s3_class(p, "ggplot")
#   expect_true(length(p$layers) > 0)
# })

# Test package functions
R                               # Start R for testing
# devtools::load_all()          # Load package functions
# devtools::test()              # Run all tests including Dev 1's and new tests
# quit()

vim scripts/02_visualization.R  # Create visualization script
# Write code to generate analysis plots

vim tests/integration/test-visualization.R  # Create integration tests
# Write integration tests for visualization scripts:
# test_that("visualization script produces plots", {
#   expect_no_error(source(here("scripts", "02_visualization.R")))
#   expect_true(file.exists(here("analysis", "figures", "plot1.png")))
# })

# 8. Test complete workflow integration
R                               # Start R for comprehensive testing
# devtools::load_all()          # Load package functions
# source("scripts/01_data_import.R")    # Test Dev 1's work
# source("scripts/02_visualization.R") # Test new visualization code
# testthat::test_dir("tests/integration")  # Run integration tests
# quit()

# 9. Quality assurance workflow
exit                           # Exit container
make docker-check-renv-fix     # Update DESCRIPTION with new packages
make docker-test              # Ensure tests still pass

# 10. Create pull request with proper workflow
git add .
git commit -m "Add visualization analysis with ggplot2

- Add plotting_functions.R with ggplot2 wrappers
- Create comprehensive unit tests for plotting functions
- Add integration tests for visualization pipeline
- Update dependencies with ggplot2"

# Push to your fork (origin)
git push origin feature/visualization-analysis

# 11. Create pull request via GitHub CLI or web interface
gh pr create --title "Add visualization analysis with ggplot2" \
             --body "## Summary
- Adds comprehensive plotting utilities with ggplot2
- Includes full test coverage (unit + integration tests)
- Updates package dependencies and documentation

## Testing
- [x] All existing tests pass
- [x] New unit tests for plotting functions
- [x] Integration tests for visualization pipeline
- [x] Package check passes

## Checklist
- [x] Code follows project style guidelines
- [x] Tests written and passing
- [x] Documentation updated
- [x] Dependencies properly tracked in renv" \
             --base main
```

### **🧑‍💻 Developer 1 (Continuing Work - After PR Review)**
```bash
# 1. Review and merge Developer 2's pull request
# On GitHub: Review PR, approve, and merge to main branch

# 2. Sync with Developer 2's merged changes
git checkout main               # Switch to main branch
git pull upstream main          # Get latest changes from team repo
git push origin main            # Update your fork's main branch

# 3. Update team Docker image if new packages were added
# Check if Dev 2 added new packages to renv.lock
if git diff HEAD~1 renv.lock | grep -q "Package"; then
  echo "New packages detected - updating team image"
  make docker-build             # Rebuild with new packages
  docker tag $(cat .project-name):latest ghcr.io/[TEAM]/$(cat .project-name):latest
  docker push ghcr.io/[TEAM]/$(cat .project-name):latest
else
  echo "No new packages - using existing team image"
  docker pull ghcr.io/[TEAM]/$(cat .project-name):latest
fi

# 4. Validate environment consistency
make docker-check-renv-fix     # Ensure all dependencies are properly tracked

# 5. Create new feature branch for advanced modeling
git checkout -b feature/advanced-models

# 6. Continue development with updated environment
make docker-zsh                # → Environment now includes Dev 2's packages

# 7. Add more analysis work using vim
# (In zsh container with vim)
R                              # Start R session
# renv::restore()              # Ensure all packages from Dev 2 are available
# devtools::load_all()         # Load updated package with new functions
# quit()

# 8. Test-driven advanced analysis development
vim R/modeling_functions.R     # Add statistical modeling functions
# Write multilevel model functions

vim tests/testthat/test-modeling_functions.R  # Write tests for modeling functions
# Write unit tests for statistical models:
# test_that("multilevel_model function works", {
#   model <- fit_multilevel_model(test_data)
#   expect_s3_class(model, "lmerMod")
#   expect_true(length(fixef(model)) > 0)
# })

# Test new modeling functions
R                              # Start R for testing
# devtools::load_all()         # Load all functions including new ones
# devtools::test()             # Run all tests (Dev 1, Dev 2, and new tests)
# quit()

vim scripts/03_advanced_models.R  # Create modeling script
# Write analysis using both Dev 1 and Dev 2's functions

vim tests/integration/test-complete_pipeline.R  # Create comprehensive integration tests
# Write end-to-end pipeline tests:
# test_that("complete analysis pipeline works", {
#   expect_no_error(source(here("scripts", "01_data_import.R")))
#   expect_no_error(source(here("scripts", "02_visualization.R")))
#   expect_no_error(source(here("scripts", "03_advanced_models.R")))
# })

# 7. Test complete integration of all developers' work
R                              # Comprehensive integration testing
# devtools::load_all()         # Load all functions
# testthat::test_dir("tests/testthat")      # Run all unit tests
# testthat::test_dir("tests/integration")  # Run all integration tests
# source("scripts/01_data_import.R")       # Dev 1's work
# source("scripts/02_visualization.R")     # Dev 2's work  
# source("scripts/03_advanced_models.R")   # New integration
# quit()

# 8. Update research paper with testing
vim analysis/paper/paper.Rmd  # Update manuscript
# Add new results and figures

vim tests/integration/test-paper_rendering.R  # Create paper rendering tests
# Write tests for paper compilation:
# test_that("paper renders successfully", {
#   expect_no_error(rmarkdown::render(here("analysis", "paper", "paper.Rmd")))
#   expect_true(file.exists(here("analysis", "paper", "paper.pdf")))
# })

# Test paper rendering
R                              # Test paper compilation
# rmarkdown::render("analysis/paper/paper.Rmd")  # Verify paper compiles
# testthat::test_dir("tests/integration")         # Run all integration tests
# quit()

# 11. Enhanced collaboration workflow with proper PR
exit                          # Exit container

# 12. Create comprehensive pull request
git add .
git commit -m "Add advanced multilevel modeling with integrated visualization

- Add modeling_functions.R with multilevel model utilities
- Create comprehensive test suite for statistical models
- Add end-to-end pipeline integration tests
- Update research paper with new analysis results
- Test complete workflow integration"

# Push feature branch to your fork
git push origin feature/advanced-models

# 13. Create pull request with detailed review checklist
gh pr create --title "Add advanced multilevel modeling analysis" \
             --body "## Summary
- Integrates visualization functions from previous PR
- Adds multilevel modeling capabilities with lme4
- Includes comprehensive end-to-end testing
- Updates research manuscript with new results

## Analysis Impact Assessment
- [x] All existing functionality preserved
- [x] New models compatible with existing visualization pipeline
- [x] Data validation passes for modeling requirements
- [x] Reproducibility check passes

## Testing Coverage
- [x] Unit tests for all modeling functions
- [x] Integration tests for complete analysis pipeline
- [x] Paper rendering validation with new results
- [x] All existing tests continue to pass

## Reproducibility Validation
- [x] renv.lock updated with new dependencies
- [x] Docker environment builds successfully
- [x] Analysis runs from clean environment
- [x] Results consistent across platforms

## Collaboration Quality
- [x] Code follows established patterns
- [x] Functions integrate cleanly with existing codebase
- [x] Documentation updated for new capabilities
- [x] Commit messages follow conventional format" \
             --base main
```

### **🔄 Key Collaboration Features (Professional Git Workflow + Test-Driven Development)**

#### **Automated Quality Assurance on Every Push:**
- ✅ **R Package Validation**: R CMD check with dependency validation
- ✅ **Comprehensive Testing Suite**: Unit tests, integration tests, and data validation
- ✅ **Paper Rendering**: Automated PDF generation and artifact upload
- ✅ **Multi-platform Testing**: Ensures compatibility across environments
- ✅ **Dependency Sync**: renv validation and DESCRIPTION file updates

#### **Test-Driven Development Workflow:**
- **Unit Tests**: Every R function has corresponding tests in `tests/testthat/`
- **Integration Tests**: Analysis scripts tested end-to-end in `tests/integration/`
- **Data Validation**: Automated data quality checks using `scripts/02_data_validation.R`
- **Reproducibility Testing**: Environment validation with `scripts/99_reproducibility_check.R`
- **Paper Testing**: Manuscript rendering validation for each commit

#### **Enhanced GitHub Templates:**
- **Pull Request Template**: Analysis impact assessment, reproducibility checklist
- **Issue Templates**: Bug reports with environment details, feature requests with research use cases
- **Collaboration Guidelines**: Research-specific workflow standards

#### **Professional Git Workflow:**
```bash
# Fork-based collaboration with pull requests:
git clone https://github.com/[YOUR-USERNAME]/project.git  # Clone your fork
git remote add upstream https://github.com/[TEAM]/project.git  # Add team repo
git checkout -b feature/your-analysis    # Create feature branch
# ... do development work with tests ...
git push origin feature/your-analysis   # Push to your fork
gh pr create --title "Add analysis" --body "..."  # Create pull request

# Synchronization after PR merges:
git checkout main             # Switch to main branch  
git pull upstream main        # Get latest from team repo
make docker-build            # Rebuild with updated dependencies
make docker-zsh              # → Identical vim/zsh environment across team
```

#### **Data Management Collaboration:**
```bash
# Structured data workflow for teams:
data/
├── raw_data/                 # Dev 1 adds original datasets
├── derived_data/             # Dev 2 adds processed data  
├── metadata/                 # Both document data sources
└── validation/               # Automated quality reports
```

## **🛠️ Vim IDE Development Environment**

### **Enhanced Vim Setup (via zzrrtools dotfiles)**
The containerized environment includes a fully configured vim IDE with:

#### **Vim Plugin Ecosystem:**
- **vim-plug**: Plugin manager (automatically installed)
- **R Language Support**: Syntax highlighting and R integration
- **File Navigation**: Project file browser and fuzzy finding
- **Git Integration**: Git status and diff visualization
- **Code Completion**: Intelligent autocomplete for R functions

#### **Essential Vim Workflow Commands:**
```bash
# In container vim session:
vim R/analysis.R               # Open R file
:Explore                       # File browser
:split scripts/data.R          # Split window editing
:vsplit analysis/paper.Rmd     # Vertical split for manuscript

# Vim + R integration:
:terminal                      # Open terminal in vim
R                             # Start R session in terminal
# devtools::load_all()         # Load package functions (in R)
# :q                           # Exit R, back to vim

# Git workflow in vim:
:!git status                   # Check git status
:!git add %                    # Add current file
:!git commit -m "Update analysis"  # Commit changes
```

#### **Productive Development Cycle:**
```bash
# 1. Start development environment
make docker-zsh               # → Enhanced zsh with vim

# 2. Multi-file development workflow
vim -p R/functions.R scripts/analysis.R analysis/paper/paper.Rmd
# Opens multiple files in tabs

# 3. Interactive R testing
:terminal                     # Open terminal in vim
R                            # Start R
# devtools::load_all()        # Test functions
# source("scripts/analysis.R") # Test scripts
# quit()                      # Exit R

# 4. File navigation and editing
# gt (next tab), gT (previous tab)
# Ctrl+w+w (switch windows)
# :Explore (file browser)

# 5. Test-driven development cycle from vim
:!make docker-test           # Run all package tests from vim
:!make docker-render         # Render paper from vim
:terminal                    # Open terminal for interactive testing
R                           # Start R in terminal
# devtools::load_all()       # Load package functions
# devtools::test()           # Run specific tests
# testthat::test_dir("tests/integration")  # Run integration tests
# quit()                     # Exit R, back to vim
```

### **Vim + R Development Tips:**

#### **File Organization in Vim:**
```bash
# Open related files simultaneously:
vim -O R/analysis_functions.R scripts/01_analysis.R    # Side by side
vim -o R/plotting.R analysis/figures/                  # Horizontal split
vim -p R/*.R scripts/*.R                               # All R files in tabs
```

#### **Git Integration Workflow:**
```bash
# In vim, check git status frequently:
:!git status                  # See changed files
:!git diff %                  # Diff current file
:!git add %                   # Stage current file
:!git commit -m "Add function"  # Commit from vim

# View git log:
:!git log --oneline -10       # Recent commits
```

#### **Test-Driven R Package Development in Vim:**
```bash
# Test-driven development cycle:
vim tests/testthat/test-new_function.R  # Write test first
vim R/new_function.R                    # Write function to pass test
:!make docker-test                      # Run tests from vim
vim man/new_function.Rd                 # Check documentation
:!make docker-check                     # Package validation

# Open multiple files for TDD:
vim -p R/my_function.R tests/testthat/test-my_function.R  # Side-by-side development
```

#### **Testing Workflow Tips:**
```bash
# Quick testing commands in vim:
:!devtools::test()                      # Run all package tests
:!testthat::test_file("tests/testthat/test-my_function.R")  # Test specific file
:!Rscript scripts/02_data_validation.R # Validate data quality
:!Rscript scripts/99_reproducibility_check.R  # Check reproducibility

# Testing with different data:
:!R -e "testthat::test_dir('tests/integration')"  # Integration tests
:!R -e "source('scripts/01_data_import.R')"       # Test analysis scripts
```

This workflow ensures **perfect reproducibility** across team members while providing **automated quality assurance** and **professional collaboration tools** integrated from the rrtools_plus enhancement framework, all accessible through a powerful vim-based development environment.