# README.md Updates Required for Unified Paradigm

This document outlines changes needed to the main README.md to reflect the unified paradigm consolidation.

## Critical Changes Required

### 1. Features Section (Lines 13-30)
**Replace**:
```markdown
- **Three Research Paradigms** optimized for different research lifecycles
  - **Analysis Paradigm**: Data science projects with 6 professional templates
  - **Manuscript Paradigm**: Academic writing with 8+ research compendium templates
  - **Package Paradigm**: R package development with 9 CRAN-ready templates
```

**With**:
```markdown
- **Unified Research Paradigm** based on Marwick et al. (2018) research compendium framework
  - Single structure supporting entire research lifecycle (data → analysis → paper → package)
  - Marwick/rrtools compatible directory layout
  - Comprehensive tutorial library (in framework repo, not installed with projects)
```

### 2. Research Paradigm System Section (Lines 52-87)
**REMOVE ENTIRE SECTION** - Replace with:

```markdown
## Research Compendium Structure

zzcollab follows the research compendium framework proposed by Marwick, Boettiger, and Mullen (2018), providing a standardized structure for reproducible research projects.

### Directory Structure

```
project/
├── analysis/
│   ├── data/
│   │   ├── raw_data/         # Original, unmodified data
│   │   └── derived_data/     # Processed, analysis-ready data
│   ├── paper/
│   │   ├── paper.Rmd         # Manuscript
│   │   └── references.bib
│   ├── figures/              # Generated visualizations
│   └── scripts/              # Analysis code
├── R/                        # Reusable functions (add as needed)
├── tests/                    # Unit tests (add as needed)
├── Dockerfile                # Computational environment
└── renv.lock                 # Package versions
```

### Use Cases

**All research workflows supported**:
- **Data Analysis**: Use `analysis/scripts/` and `figures/`
- **Manuscript Writing**: Use `analysis/paper/paper.Rmd`
- **Package Development**: Use `R/`, `man/`, `tests/`
- **Complete Compendium**: Use all directories for full reproducibility

**Progressive disclosure**: Start with data analysis, add manuscript when writing, extract functions to R/ when reusing code. No migration required as research evolves.

### Learning Resources

Tutorial examples and complete projects available at:
https://github.com/rgt47/zzcollab/tree/main/examples

- Step-by-step tutorials for EDA, modeling, validation
- Complete example research compendia
- Reusable code patterns
```

### 3. Paradigm Selection Section (Lines 77-87)
**REMOVE** - No longer applicable with unified paradigm

### 4. R Interface Implementation (Lines 89-149)
**Update examples**:

```markdown
## R Interface Implementation

### Configuration Setup (One-time)

```r
library(zzcollab)

# Set up your defaults once
set_config("team_name", "myteam")
set_config("build_mode", "standard")
set_config("dotfiles_dir", "~/dotfiles")
set_config("github_account", "myusername")

# View your configuration
list_config()
```

### Initialize a New Research Compendium

```r
# Using config defaults (recommended)
init_project(project_name = "myproject")

# Or with explicit parameters
init_project(
  team_name = "myteam",
  project_name = "myproject",
  build_mode = "standard",
  dotfiles_path = "~/dotfiles"
)
```

### Join an Existing Project

```r
# Using config defaults
join_project(project_name = "myproject")

# Or with explicit parameters
join_project(
  team_name = "myteam",
  project_name = "myproject",
  build_mode = "standard"
)
```
```

### 5. Build Modes Section (Lines 151-165)
**UPDATE** - Remove paradigm-specific packages language:

```markdown
## Build Modes

zzcollab supports three build modes to optimize for different use cases:

| Mode | Description | Docker Size | Package Count | Key Packages | Build Time |
|------|-------------|-------------|---------------|--------------|------------|
| **Fast** (`-F`) | Minimal setup | Small | 9 packages | renv, here, devtools, testthat, knitr, rmarkdown | Fast |
| **Standard** (`-S`) | Balanced (default) | Medium | 17 packages | + dplyr, ggplot2, tidyr, palmerpenguins, broom, janitor | Medium |
| **Comprehensive** (`-C`) | Full-featured | Large | 47 packages | + tidymodels, shiny, plotly, quarto, flexdashboard | Slow |

All packages work effectively whether you are doing data analysis, writing manuscripts, or developing packages.
```

### 6. Configuration System (Lines 167-207)
**UPDATE paradigm references**:

```markdown
### Customizable Settings
- **Team settings**: `team_name`, `github_account`
- **Build settings**: `build_mode`, `dotfiles_dir`, `dotfiles_nodot`
- **Automation**: `auto_github`, `skip_confirmation`
- **Custom package lists**: Override default packages for each build mode
```

Remove: "paradigm-specific packages" bullets

### 7. Example R Workflow (Lines 244-273)
**UPDATE** - Remove paradigm parameter:

```r
# 0. One-time setup (configure your defaults)
set_config("team_name", "datascience")
set_config("build_mode", "standard")
set_config("dotfiles_dir", "~/dotfiles")

# 1. Initialize project (uses config defaults)
init_project(project_name = "covid-analysis")

# 2. Add required packages
add_package(c("tidyverse", "lubridate", "plotly"))

# 3. Create feature branch
create_branch("feature/exploratory-analysis")

# 4. Run analysis
run_script("analysis/scripts/exploratory_analysis.R")  # Updated path

# 5. Render report
render_report("analysis/paper/paper.Rmd")  # Updated path

# 6. Validate reproducibility
validate_repro()

# 7. Commit and push
git_commit("Add COVID-19 exploratory analysis")
git_push()
```

### 8. Usage Section (Lines 291-303)
**UPDATE** - Use unified structure:

```bash
# Create project directory
mkdir my-analysis
cd my-analysis

# Set up research compendium
zzcollab --dotfiles ~/dotfiles

# Start development environment
make docker-rstudio  # → http://localhost:8787 (user: analyst, pass: analyst)
```

### 9. Project Structure Section (Lines 321-343)
**REPLACE** with unified structure:

```
your-project/
├── analysis/              # Research workspace
│   ├── data/
│   │   ├── raw_data/     # Original, unmodified data
│   │   └── derived_data/ # Processed data
│   ├── paper/
│   │   ├── paper.Rmd     # Manuscript
│   │   └── references.bib
│   ├── figures/          # Generated visualizations
│   └── scripts/          # Analysis code
├── R/                    # Reusable functions
├── tests/                # Unit tests
├── .github/workflows/    # CI/CD automation
├── DESCRIPTION           # Project metadata
├── Dockerfile            # Computational environment
├── Makefile              # Automation commands
└── README.md
```

### 10. Command Line Options (Lines 345-390)
**REMOVE paradigm flags**:

Remove these lines:
```
  --paradigm TYPE      Research paradigm (analysis, manuscript, package)
```

### 11. Examples Section
**UPDATE** to remove paradigm references:

```bash
EXAMPLES:
  # Configuration setup
  zzcollab config init
  zzcollab config set team_name "myteam"
  zzcollab config set build_mode "fast"

  # Basic usage (uses config defaults)
  zzcollab --fast
  zzcollab --dotfiles ~/dotfiles

  # Team collaboration
  zzcollab -i -t myteam -p study -B rstudio
  zzcollab -t myteam -p study -I rstudio
```

### 12. Documentation Section (Lines 437-443)
**UPDATE** links:

```markdown
## Documentation

- [Unified Paradigm Guide](docs/UNIFIED_PARADIGM_GUIDE.md) - Complete framework documentation
- [Marwick Comparison](docs/MARWICK_COMPARISON_ANALYSIS.md) - Research compendium alignment
- [Tutorial Examples](examples/) - Step-by-step learning resources
- [Command Reference](#command-line-options) - All available options
- [CI/CD Guide](docs/CICD_GUIDE.md) - GitHub Actions patterns
```

### 13. Add New Section After Documentation

```markdown
## Tutorial Examples

Comprehensive tutorial examples and code patterns available at:
https://github.com/rgt47/zzcollab/tree/main/examples

**Available Resources**:
- **Tutorials**: Step-by-step workflows for EDA, modeling, validation, dashboards, reporting
- **Complete Projects**: Full example research compendia demonstrating end-to-end workflows
- **Code Patterns**: Reusable patterns for data validation, model evaluation, reproducible plots

These examples live in the zzcollab repository (not installed with projects) as learning resources you can reference when needed.
```

### 14. Acknowledgments Section (Lines 553-559)
**ADD** Marwick citation:

```markdown
## Acknowledgments

- [Ben Marwick et al.](https://doi.org/10.1080/00031305.2017.1375986) - Research compendium framework
- [rrtools](https://github.com/benmarwick/rrtools) - Original research compendium implementation
- [Rocker Project](https://rocker-project.org/) - Docker images for R
- [renv](https://rstudio.github.io/renv/) - R dependency management
- R Community
```

---

## Summary of Changes

**Major removals**:
- Three-paradigm system description
- Paradigm selection examples
- Paradigm-specific package lists
- --paradigm command-line flag

**Major additions**:
- Unified research compendium structure
- Marwick et al. (2018) attribution
- Link to examples/ directory
- Progressive disclosure philosophy
- Research lifecycle support explanation

**Philosophy shift**:
- **Old**: "Choose your paradigm upfront"
- **New**: "One structure for entire research lifecycle"

---

## Implementation Checklist

- [ ] Update Features section (remove three paradigms)
- [ ] Replace paradigm system with unified structure explanation
- [ ] Update all code examples (remove paradigm parameter)
- [ ] Update directory structure diagrams
- [ ] Add links to examples/ directory
- [ ] Remove --paradigm from command-line options
- [ ] Update R interface examples
- [ ] Add Marwick et al. citation to acknowledgments
- [ ] Update documentation links
- [ ] Add tutorial examples section
