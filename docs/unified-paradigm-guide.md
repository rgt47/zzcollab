# zzcollab Unified Paradigm Guide

**Version**: 2.0 (2025)
**Status**: Current framework design

---

## Executive Summary

The zzcollab **unified paradigm** consolidates the previous three-paradigm system (analysis, manuscript, package) into a single, flexible research compendium structure based on Marwick et al. (2018).

**Key Changes**:
- One structure instead of three separate paradigms
- Matches rrtools conventions exactly
- Tutorial examples moved to zzcollab repo (not installed with projects)
- Minimal CI/CD included by default
- Supports entire research lifecycle: data analysis → manuscript → package

---

## Table of Contents

1. [Motivation for Consolidation](#motivation-for-consolidation)
2. [Structure Overview](#structure-overview)
3. [Comparison to Previous System](#comparison-to-previous-system)
4. [Complete Directory Layout](#complete-directory-layout)
5. [Usage Guide](#usage-guide)
6. [Learning Resources](#learning-resources)
7. [Migration from Three-Paradigm System](#migration-from-three-paradigm-system)
8. [References](#references)

---

## Motivation for Consolidation

### Why Consolidate Three Paradigms into One?

**Problem with three-paradigm system**:
1. **Workflow fragmentation**: Forced users to choose paradigm upfront
2. **Migration pain**: Moving from analysis → manuscript → package required restructuring
3. **rrtools incompatibility**: Directory structures deviated from Marwick's conventions
4. **Premature optimization**: Research does not follow linear paths

**Benefits of unified paradigm**:
1. **Marwick compatibility**: Matches rrtools structure exactly
2. **Research lifecycle support**: One structure handles data analysis, writing, and packaging
3. **No migration needed**: Project evolves organically as research progresses
4. **Clean separation**: Examples/tutorials in zzcollab repo, not every project
5. **Progressive disclosure**: Start minimal, add what you need

### Philosophical Alignment

**Marwick et al. (2018) core principle**:
> "A research compendium packages all digital components of a research project (data, code, documentation, computational environment) in a structured, reproducible format based on R package conventions."

The unified paradigm embraces this fully - one structure for the entire research lifecycle.

---

## Structure Overview

### Minimal Starting Structure

When you create a new project, you get:

```
my_project/
├── .github/workflows/       # CI/CD (minimal, well-documented)
│   ├── README.md
│   └── render-paper.yml
├── analysis/                # Research workspace
│   ├── data/
│   │   ├── raw_data/       # Original data (read-only)
│   │   ├── derived_data/   # Processed data (generated)
│   │   └── README.md
│   ├── paper/
│   │   ├── report.Rmd       # Manuscript
│   │   └── references.bib
│   ├── figures/            # Generated visualizations
│   └── scripts/            # Analysis scripts (EMPTY - you create)
├── R/                      # Reusable functions (add as needed)
├── man/                    # Function documentation (add as needed)
├── tests/                  # Unit tests (add as needed)
├── DESCRIPTION             # Project metadata
├── Dockerfile              # Environment specification
├── renv.lock               # Package versions
├── LICENSE
└── README.md
```

### Key Design Decisions

#### 1. Examples NOT Included
- **Old system**: 23 pre-written template files installed in every project
- **New system**: Examples live in zzcollab repo, referenced via links

#### 2. Empty `analysis/scripts/`
- You write your own analysis code
- Reference [zzcollab examples](https://github.com/rgt47/zzcollab/tree/main/examples) for patterns

#### 3. Minimal CI/CD
- One workflow: render report.Rmd
- Comprehensive README.md explaining customization
- Easy to extend or disable

#### 4. No Separate `tables/` Directory
- Tables are inline in report.Rmd (rendered on the fly) or
- Data files in `derived_data/` or
- Images in `figures/`

---

## Comparison to Previous System

### Three-Paradigm System (Deprecated)

**Old Approach**:
```
analysis/           # Paradigm 1: Data analysis
manuscript/         # Paradigm 2: Academic writing
package/            # Paradigm 3: R package development
```

**Problems**:
- Forced upfront choice
- Different directory structures
- Required migration when research evolved
- 23 template files per project

### Unified Paradigm (Current)

**New Approach**:
```
analysis/           # All research work
  ├── data/         # Data analysis phase
  ├── paper/        # Writing phase
  └── scripts/      # Analysis code
R/                  # Package development phase (if needed)
tests/              # Testing (if needed)
```

**Benefits**:
- One structure throughout research lifecycle
- No migration required
- Clean, Marwick-compatible
- Examples in zzcollab repo, not every project

---

## Complete Directory Layout

### Core Directories (Always Present)

#### `analysis/`
**Purpose**: All research workspace files

- `data/raw_data/` - Original, unmodified data (read-only)
- `data/derived_data/` - Processed, analysis-ready data (generated)
- `paper/` - Manuscript and bibliography
- `figures/` - All generated visualizations
- `scripts/` - Analysis code (user creates)

**Marwick classification**:
- **Read-only**: raw_data/
- **Human-generated**: scripts/, paper/
- **Project-generated**: derived_data/, figures/

#### `R/`
**Purpose**: Reusable functions extracted from analysis

**When to use**:
- Functions used across multiple scripts
- Functions you want to test
- Functions you might share

**Empty initially** - add functions as needed.

#### `tests/`
**Purpose**: Unit tests for functions in R/

**When to use**:
- Testing functions in R/
- Validating data processing
- Regression testing

**Empty initially** - add tests as needed.

### Configuration Files

#### `DESCRIPTION`
R package metadata - even if you are not making a package, this provides:
- Project title and description
- Author information
- Dependencies
- License

#### `Dockerfile`
Computational environment specification:
- Base image (rocker/verse:4.4.0)
- System dependencies
- R package installation (via renv)

#### `renv.lock`
Exact R package versions:
```bash
# Enter container
make r

# Add packages (inside R)
install.packages("tidyverse")

# Exit R - auto-snapshot on exit
q()

# Validate on host (no R required)
make check-renv
```

### Documentation Files

#### Root `README.md`
Project overview:
- Research question
- Quick start instructions
- Structure explanation
- Link to zzcollab examples

#### `analysis/data/README.md`
Data documentation:
- Source and collection methods
- Variable definitions (codebook)
- Processing scripts
- Known issues

#### `.github/workflows/README.md`
CI/CD documentation:
- What workflows do
- How to customize
- Troubleshooting guide

---

## Usage Guide

### Creating a New Project

```bash
# Initialize new research compendium
mkdir my-project && cd my-project
zzcollab

# Build Docker environment
make docker-build

# Enter container and add packages
make r
# Inside R:
install.packages(c("tidyverse", "here", "rmarkdown"))
q()  # Exit - auto-snapshot on exit

# Validate on host
make check-renv
```

### Daily Development Workflow

#### 1. Data Analysis Phase

```bash
# Add raw data
cp ~/Downloads/experiment_data.csv analysis/data/raw_data/

# Create analysis script
vim analysis/scripts/01_data_cleaning.R
```

**Example script** (reference [zzcollab examples](https://github.com/rgt47/zzcollab/tree/main/examples/tutorials) for patterns):
```r
library(here)
library(dplyr)
library(readr)

# Load raw data
raw_data <- read_csv(here("analysis", "data", "raw_data", "experiment_data.csv"))

# Clean and process
clean_data <- raw_data %>%
  filter(!is.na(value)) %>%
  mutate(log_value = log(value))

# Save processed data
write_csv(clean_data, here("analysis", "data", "derived_data", "cleaned_data.csv"))
```

#### 2. Writing Phase

```bash
# Edit manuscript
vim analysis/report/report.Rmd

# Render locally
Rscript -e 'rmarkdown::render("analysis/report/report.Rmd")'

# Commit
git add analysis/report/
git commit -m "Draft introduction and methods"
```

#### 3. Function Extraction Phase

When you have reusable code:

```bash
# Create function file
vim R/data_utils.R
```

```r
#' Clean experimental data
#'
#' @param data Raw data frame
#' @return Cleaned data frame
#' @export
clean_experiment_data <- function(data) {
  data %>%
    filter(!is.na(value)) %>%
    mutate(log_value = log(value))
}
```

```bash
# Create test
vim tests/testthat/test-data_utils.R
```

```r
test_that("clean_experiment_data removes NAs", {
  raw <- data.frame(value = c(1, NA, 3))
  clean <- clean_experiment_data(raw)
  expect_equal(nrow(clean), 2)
})
```

```bash
# Run tests
Rscript -e 'devtools::test()'

# Update manuscript to use function
# In report.Rmd:
# clean_data <- clean_experiment_data(raw_data)
```

### Testing Reproducibility

```bash
# Build Docker environment
docker build -t my-project-env .

# Render paper in container (matches CI)
docker run --rm -v $(pwd):/home/analyst/project -w /home/analyst/project \
  my-project-env Rscript -e 'rmarkdown::render("analysis/report/report.Rmd")'

# Run tests in container
docker run --rm -v $(pwd):/home/analyst/project -w /home/analyst/project \
  my-project-env Rscript -e 'devtools::test()'
```

### Collaboration Workflow

```bash
# Create feature branch
git checkout -b analysis/model-validation

# Do analysis work
vim analysis/scripts/03_model_validation.R

# Commit changes
git add analysis/scripts/03_model_validation.R
git add analysis/figures/validation_plot.png
git commit -m "Add model validation analysis"

# Push and create PR
git push origin analysis/model-validation

# GitHub Actions automatically validates reproducibility
# Reviewer can download rendered PDF from Actions tab
```

---

## Learning Resources

### Where to Find Examples

**All instructional materials live in the zzcollab repository**:

**Tutorials**: https://github.com/rgt47/zzcollab/tree/main/examples/tutorials
- `01_eda_tutorial.R` - Comprehensive EDA workflow (252 lines)
- `02_modeling_tutorial.R` - tidymodels patterns
- `03_validation_tutorial.R` - Cross-validation examples
- `04_dashboard_tutorial.Rmd` - Interactive dashboards
- `05_reporting_tutorial.Rmd` - Parameterized reports

**Complete Projects**: https://github.com/rgt47/zzcollab/tree/main/examples/complete_projects
- Full example research compendia
- End-to-end workflows
- Real analysis patterns

**Code Patterns**: https://github.com/rgt47/zzcollab/tree/main/examples/patterns
- Data validation
- Model evaluation
- Reproducible plots

### How to Use Examples

**DON'T**: Copy template files into your project
**DO**: Read examples, understand patterns, apply to your own work

**Example workflow**:
1. Read `01_eda_tutorial.R` to learn EDA best practices
2. Create your own `analysis/scripts/my_eda.R`
3. Apply patterns you learned to your specific data

---

## Migration from Three-Paradigm System

### For Existing Analysis Paradigm Projects

**Old structure**:
```
data/raw/
data/processed/
analysis/exploratory/
scripts/01_eda.R
```

**Migration to unified**:
```
analysis/data/raw_data/
analysis/data/derived_data/
analysis/scripts/01_eda.R
analysis/figures/
```

**Steps**:
```bash
# Backup first!
cp -r my_project my_project.backup

# Create new structure
mkdir -p analysis/data analysis/scripts analysis/figures analysis/report
mv data/raw analysis/data/raw_data
mv data/processed analysis/data/derived_data
mv scripts/* analysis/scripts/

# Update script paths (using here() helps!)
# Change: read.csv("data/raw/data.csv")
# To: read.csv(here("analysis", "data", "raw_data", "data.csv"))

# Add minimal report.Rmd
cp /path/to/zzcollab/templates/unified/analysis/report/report.Rmd analysis/report/
```

### For Existing Manuscript Paradigm Projects

**Old structure**:
```
manuscript/report.Rmd
analysis/reproduce/
R/
tests/
```

**Migration to unified**:
```
analysis/report/report.Rmd
analysis/scripts/  # reproduction scripts here
R/                 # already compatible!
tests/             # already compatible!
```

**Steps**:
```bash
# Already mostly compatible!
mkdir -p analysis/report analysis/data analysis/figures
mv manuscript/* analysis/report/
mv analysis/reproduce/* analysis/scripts/ 2>/dev/null || true

# R/ and tests/ do not need to move
```

### For Existing Package Paradigm Projects

**Already compatible!** Package paradigm structure matches unified paradigm.

Optional: Add `analysis/` for manuscript if writing paper about the package.

---

## Comparison to rrtools

### Similarities (Marwick Compatible)

Same directory structure:
- `analysis/data/raw_data/` and `derived_data/`
- `analysis/report/`
- `analysis/figures/`
- R package foundation (DESCRIPTION, R/, tests/)

Same principles:
- Computational environment specification (Dockerfile)
- Package version management (renv)
- Read-only / human-generated / project-generated file classification

Same workflow:
- Write analysis → Render paper → Test reproducibility

### Enhancements (zzcollab Additions)

**Docker-first**: Mandatory containerization (rrtools: optional)
**CI/CD by default**: GitHub Actions included (rrtools: user adds)
**Comprehensive documentation**: Detailed README files at every level
**Tutorial library**: Rich examples repository (rrtools: minimal)
**Team collaboration**: Multi-user workflows and base images

### Key Difference: Examples

**rrtools**: Minimal templates, user writes all code
**zzcollab**: Minimal structure + comprehensive example library (in framework repo, not projects)

**Philosophy**: Same (trust researchers), implementation differs (provide learning resources separately)

---

## Frequently Asked Questions

### Q: What happened to the three paradigms?

**A**: Consolidated into one unified structure based on Marwick et al. (2018). One structure now handles the entire research lifecycle instead of forcing upfront paradigm choice.

### Q: Where did all the example scripts go?

**A**: Moved to zzcollab repository at https://github.com/rgt47/zzcollab/tree/main/examples. They're learning resources, not files installed in every project.

### Q: Can I still do data analysis without writing a paper?

**A**: Yes! Just use `analysis/scripts/` and ignore `analysis/report/`. The structure is flexible - use what you need.

### Q: Can I still develop R packages?

**A**: Yes! Use the `R/`, `man/`, and `tests/` directories. The structure already follows R package conventions.

### Q: Can I still write manuscripts?

**A**: Yes! Use `analysis/report/report.Rmd`. The structure is specifically designed for this (Marwick's original purpose).

### Q: Do I have to use Docker?

**A**: Yes, for true reproducibility. But you can develop locally with renv and only use Docker for validation/CI.

### Q: Do I have to use CI/CD?

**A**: No. Delete `.github/` if you do not want automated checks. But it is highly recommended for reproducibility validation.

### Q: What if my research does not fit this structure?

**A**: Adapt! The structure is a starting point. Add directories as needed, just document deviations in your README.

### Q: How do I know what goes in `R/` vs `analysis/scripts/`?

**A**:
- `analysis/scripts/` - Analysis code specific to THIS project
- `R/` - Reusable functions you might test/share/package

Start with everything in `scripts/`, extract to `R/` when you find reusable patterns.

### Q: Should I commit data to git?

**A**:
- **Small data** (<50MB): Yes, commit to `analysis/data/raw_data/`
- **Large data**: Store externally, provide download script
- **Sensitive data**: Never commit, document access procedure

---

## References

**Primary Source**:
- Marwick, B., Boettiger, C., & Mullen, L. (2018). Packaging Data Analytical Work Reproducibly Using R (and Friends). *The American Statistician*, 72(1), 80-88. DOI: [10.1080/00031305.2017.1375986](https://doi.org/10.1080/00031305.2017.1375986)

**zzcollab Documentation**:
- [Marwick Comparison Analysis](./MARWICK_COMPARISON_ANALYSIS.md) - How zzcollab relates to research compendium literature
- [CI/CD Guide](./CICD_GUIDE.md) - Advanced GitHub Actions patterns
- [Configuration Guide](./CONFIGURATION.md) - Multi-level configuration system
- [Development Guide](./DEVELOPMENT.md) - Package management and workflows
- [Variants Guide](./VARIANTS.md) - Docker profile system (14+ profiles)

**Related Resources**:
- [rrtools](https://github.com/benmarwick/rrtools) - Marwick's implementation
- [The Turing Way - Research Compendia](https://book.the-turing-way.org/reproducible-research/compendia) - Community guide
- [Research Compendium Website](https://research-compendium.science/) - Comprehensive resource

---

**Document Version**: 2.0
**Last Updated**: 2025-10-01
**Status**: Current framework design
