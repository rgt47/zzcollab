# Build Modes Guide

## Overview

ZZCOLLAB implements a three-tiered build mode system that balances
installation speed, package availability, and development flexibility.
This guide provides comprehensive documentation of build mode
architecture, package selection criteria, and appropriate usage
scenarios.

## Build Mode Philosophy

Build modes represent distinct optimization strategies for different
research contexts:

- **Fast Mode**: Optimized for rapid iteration and continuous
  integration environments
- **Standard Mode**: Balanced configuration suitable for most research
  workflows
- **Comprehensive Mode**: Complete ecosystem for complex analytical
  requirements

Each mode defines package sets at two installation layers:
Docker image packages (base layer) and renv-managed packages
(project-specific layer).

## Build Mode Specifications

### Fast Mode

**Command Line Flags**: `-F`, `--fast`

**Design Rationale**: Minimal viable environment enabling rapid
project initialization and testing. Prioritizes build speed over
feature completeness.

**Docker Layer Packages (9 packages)**:

```
Core Infrastructure:
- renv          # Dependency management
- remotes       # Package installation from various sources
- here          # Path management
- usethis       # Project setup utilities

Development Tools:
- devtools      # Package development workflow
- testthat      # Unit testing framework
- knitr         # Dynamic document generation
- rmarkdown     # Document rendering
- targets       # Pipeline management
```

**renv Layer Packages**: Same as Docker layer (9 packages)

**Typical Build Time**: 2-3 minutes

**Use Cases**:

- Continuous integration pipelines requiring rapid feedback
- Initial project exploration and prototyping
- Teaching environments with limited installation time
- Resource-constrained computational environments
- Projects with specialized package requirements managed
  independently

**Limitations**:

- No data manipulation tools included
- No visualization capabilities
- Requires manual installation of domain-specific packages
- Not suitable for immediate data analysis work

### Standard Mode

**Command Line Flags**: `-S`, `--standard` (default)

**Design Rationale**: Balanced environment providing essential data
science tools while maintaining reasonable build times. Represents
the recommended configuration for most research projects.

**Docker Layer Packages (17 packages)**:

```
Fast Mode Packages (9):
- renv, remotes, here, usethis, devtools, testthat, knitr,
  rmarkdown, targets

Data Manipulation:
- dplyr         # Data transformation
- tidyr         # Data tidying
- ggplot2       # Visualization

Research Tools:
- palmerpenguins  # Example datasets
- broom         # Model output tidying
- janitor       # Data cleaning utilities
- DT            # Interactive tables
- conflicted    # Function conflict resolution
```

**renv Layer Packages**: Same as Docker layer (17 packages)

**Typical Build Time**: 4-6 minutes

**Use Cases**:

- Standard data analysis projects
- Exploratory data analysis workflows
- Research projects requiring tidyverse ecosystem
- Teaching environments with adequate setup time
- Projects requiring immediate data manipulation capabilities

**Capabilities**:

- Complete data wrangling functionality
- Publication-quality visualization
- Interactive data tables
- Example datasets for testing and demonstration
- Conflict management for common function name collisions

### Comprehensive Mode

**Command Line Flags**: `-C`, `--comprehensive`

**Design Rationale**: Complete analytical ecosystem supporting
advanced statistical methods, machine learning, interactive
applications, and specialized domains. Prioritizes feature
completeness over build speed.

**Docker Layer Packages (47+ packages)**:

```
Standard Mode Packages (17):
- All packages from Standard Mode

Advanced Statistical Modeling:
- tidymodels    # Machine learning framework
- survival      # Survival analysis
- lme4          # Mixed effects models
- glmnet        # Regularized regression

Interactive Applications:
- shiny         # Web applications
- plotly        # Interactive plots
- flexdashboard # Dashboard framework

Document Generation:
- quarto        # Next-generation publishing
- bookdown      # Long-form documents
- distill       # Scientific articles

Specialized Data Types:
- lubridate     # Date-time manipulation
- stringr       # String manipulation
- forcats       # Factor manipulation

Database Connectivity:
- DBI           # Database interface
- RSQLite       # SQLite database
- dbplyr        # Database backend for dplyr

Parallel Processing:
- future        # Asynchronous computation
- furrr         # Parallel purrr operations

Additional packages for spatial analysis, time series,
Bayesian methods, and specialized domains
```

**renv Layer Packages**: Same as Docker layer (47+ packages)

**Typical Build Time**: 10-15 minutes

**Use Cases**:

- Complex analytical projects requiring diverse methods
- Machine learning and predictive modeling
- Interactive dashboard development
- Long-form document and book preparation
- Projects requiring database connectivity
- Parallel and distributed computing requirements
- Specialized domain analysis (spatial, temporal, Bayesian)

**Capabilities**:

- Complete tidyverse and tidymodels ecosystems
- Advanced statistical and machine learning methods
- Interactive web applications and dashboards
- Multiple document formats and publishing systems
- Database integration and large dataset handling
- Parallel processing for computational efficiency

## Package Selection Criteria

### Inclusion Principles

Packages are selected for build modes based on systematic evaluation:

1. **Usage Frequency**: Analysis of package download statistics and
   research software surveys
2. **Dependency Efficiency**: Evaluation of dependency trees to
   minimize redundancy
3. **Paradigm Alignment**: Compatibility with analysis, manuscript,
   and package paradigms
4. **Maintenance Status**: Active development and CRAN compliance
5. **Documentation Quality**: Comprehensive documentation and
   vignettes

### Fast Mode Selection Criteria

- Zero data analysis dependencies
- Essential for package development workflow
- Required for reproducible research infrastructure
- Minimal dependency trees
- Rapid installation characteristics

### Standard Mode Selection Criteria

- Core tidyverse packages for data manipulation
- Essential visualization capabilities
- Common data cleaning utilities
- Example datasets for testing
- Packages with high usage in introductory data science

### Comprehensive Mode Selection Criteria

- Advanced statistical methods beyond base R
- Specialized domain packages (survival, mixed models)
- Interactive visualization and application frameworks
- Database connectivity and data engineering tools
- Parallel processing capabilities
- Publishing systems for multiple output formats

## Build Mode Selection Guide

### Decision Framework

```
Question 1: What is the primary project purpose?

  → CI/CD testing and validation
    → Fast Mode

  → Standard data analysis and visualization
    → Standard Mode

  → Advanced modeling, machine learning, or specialized methods
    → Comprehensive Mode


Question 2: What are the time constraints?

  → Minimal setup time required (< 5 minutes)
    → Fast Mode

  → Moderate setup time acceptable (5-10 minutes)
    → Standard Mode

  → Extended setup time acceptable (> 10 minutes)
    → Comprehensive Mode


Question 3: What is the computational environment?

  → Resource-constrained (limited RAM, slow network)
    → Fast Mode

  → Standard computational resources
    → Standard Mode

  → High-performance computing environment
    → Comprehensive Mode
```

### Paradigm-Specific Recommendations

**Analysis Paradigm**:

- Default: Standard Mode
- Upgrade to Comprehensive if requiring tidymodels, shiny, or
  advanced statistics
- Fast Mode generally insufficient for data analysis work

**Manuscript Paradigm**:

- Default: Standard Mode
- Upgrade to Comprehensive if requiring bookdown, quarto, or
  specialized document formats
- Fast Mode sufficient only for package development without analysis

**Package Paradigm**:

- Default: Fast Mode for pure package development
- Standard Mode if package includes vignettes with data analysis
- Comprehensive Mode if package implements advanced statistical
  methods

## Implementation Details

### Command Line Interface

**Team Initialization**:

```bash
# Fast mode
zzcollab -i -t mylab -p study -F -d ~/dotfiles

# Standard mode (default)
zzcollab -i -t mylab -p study -S -d ~/dotfiles
zzcollab -i -t mylab -p study -d ~/dotfiles

# Comprehensive mode
zzcollab -i -t mylab -p study -C -d ~/dotfiles
```

**Team Member Joining**:

```bash
# Fast mode
zzcollab -t mylab -p study -I shell -F -d ~/dotfiles

# Standard mode (default)
zzcollab -t mylab -p study -I shell -S -d ~/dotfiles
zzcollab -t mylab -p study -I shell -d ~/dotfiles

# Comprehensive mode
zzcollab -t mylab -p study -I shell -C -d ~/dotfiles
```

**Environment Variable Detection**:

```bash
# Set build mode via environment variable
export ZZCOLLAB_BUILD_MODE=fast
zzcollab -i -t mylab -p study -d ~/dotfiles

export ZZCOLLAB_BUILD_MODE=comprehensive
zzcollab -t mylab -p study -I shell -d ~/dotfiles
```

### R Interface

```r
library(zzcollab)

# Team initialization with build modes
init_project(
  team_name = "mylab",
  project_name = "study",
  build_mode = "fast",           # or "standard" or "comprehensive"
  dotfiles_path = "~/dotfiles"
)

# Team member joining with build modes
join_project(
  team_name = "mylab",
  project_name = "study",
  interface = "shell",
  build_mode = "comprehensive",
  dotfiles_path = "~/dotfiles"
)
```

### Configuration File Specification

Build modes can be customized through configuration files:

**User Configuration** (`~/.zzcollab/config.yaml`):

```yaml
defaults:
  build_mode: "standard"

build_modes:
  fast:
    description: "Minimal development environment"
    docker_packages: [renv, remotes, here, usethis, devtools,
                      testthat, knitr, rmarkdown, targets]
    renv_packages: [renv, remotes, here, usethis, devtools,
                    testthat, knitr, rmarkdown, targets]

  standard:
    description: "Balanced research workflow"
    docker_packages: [renv, remotes, here, usethis, devtools,
                      testthat, knitr, rmarkdown, targets, dplyr,
                      ggplot2, tidyr, palmerpenguins, broom,
                      janitor, DT, conflicted]
    renv_packages: [renv, remotes, here, usethis, devtools,
                    testthat, knitr, rmarkdown, targets, dplyr,
                    ggplot2, tidyr, palmerpenguins, broom,
                    janitor, DT, conflicted]

  comprehensive:
    description: "Complete analytical ecosystem"
    docker_packages: [renv, remotes, here, usethis, devtools,
                      testthat, knitr, rmarkdown, targets, dplyr,
                      ggplot2, tidyr, palmerpenguins, broom,
                      janitor, DT, conflicted, tidymodels, shiny,
                      plotly, quarto, flexdashboard, survival,
                      lme4, DBI, RSQLite, future, furrr, lubridate,
                      stringr, forcats, bookdown, distill]
    renv_packages: [renv, remotes, here, usethis, devtools,
                    testthat, knitr, rmarkdown, targets, dplyr,
                    ggplot2, tidyr, palmerpenguins, broom,
                    janitor, DT, conflicted, tidymodels, shiny,
                    plotly, quarto, flexdashboard, survival,
                    lme4, DBI, RSQLite, future, furrr, lubridate,
                    stringr, forcats, bookdown, distill]

  custom_minimal:
    description: "Custom configuration for specific workflow"
    docker_packages: [renv, devtools, testthat]
    renv_packages: [renv, devtools, testthat, tidyverse, targets]
```

## Build Mode Architecture

### Two-Layer Package Installation

ZZCOLLAB employs a two-layer package installation strategy:

**Layer 1: Docker Image Packages**

- Installed during Docker image build process
- Cached in Docker layers for rapid container startup
- Shared across all project instances using the image
- Modifications require Docker image rebuild
- Defined in Dockerfile.teamcore

**Layer 2: renv-Managed Packages**

- Installed via renv during first project setup
- Project-specific package versions
- Isolated dependency management
- Modifications update renv.lock file
- Enables reproducibility without Docker rebuild

### Package Synchronization

Build modes maintain identical package sets across both layers to
ensure consistency:

```
Docker Layer:           renv Layer:
┌──────────────┐       ┌──────────────┐
│ renv         │       │ renv         │
│ devtools     │       │ devtools     │
│ tidyverse    │  ═══  │ tidyverse    │
│ ...          │       │ ...          │
└──────────────┘       └──────────────┘
```

This synchronization ensures that:

1. Docker containers have immediate package availability
2. renv provides version control and reproducibility
3. Package additions are tracked through renv.lock
4. Team members can restore exact package versions

### Build Mode Detection

The system detects build mode through hierarchical precedence:

1. **Command-line flag**: `-F`, `-S`, or `-C`
2. **Environment variable**: `ZZCOLLAB_BUILD_MODE`
3. **Configuration file**: `build_mode` in config.yaml
4. **System default**: Standard mode

## Dependency Validation

### check_renv_for_commit.R Integration

The dependency validation system adapts to build mode:

**Fast Mode Validation**:

```bash
Rscript check_renv_for_commit.R --build-mode fast \
  --fail-on-issues
```

- Validates essential infrastructure packages
- Warns about missing development tools
- Minimal external package requirements

**Standard Mode Validation**:

```bash
Rscript check_renv_for_commit.R --build-mode standard \
  --fail-on-issues
```

- Validates tidyverse core packages
- Checks data manipulation dependencies
- Ensures visualization capabilities

**Comprehensive Mode Validation**:

```bash
Rscript check_renv_for_commit.R --build-mode comprehensive \
  --fail-on-issues
```

- Validates full package ecosystem
- Checks specialized domain packages
- Ensures database connectivity
- Validates parallel processing dependencies

**Environment Variable Detection**:

```bash
ZZCOLLAB_BUILD_MODE=fast Rscript check_renv_for_commit.R \
  --fail-on-issues
```

### Validation Rules

Build mode affects validation behavior:

1. **Package Extraction**: Scans R/, scripts/, analysis/, tests/,
   vignettes/, inst/ for library() and require() calls
2. **DESCRIPTION Validation**: Ensures all used packages are
   declared in Imports or Suggests
3. **renv.lock Synchronization**: Verifies renv.lock matches
   DESCRIPTION and actual usage
4. **Build Mode Compatibility**: Warns if detected packages exceed
   build mode capabilities
5. **CRAN Validation**: Confirms all packages exist on CRAN
   (excluding base packages)

## Team Collaboration Considerations

### Build Mode Consistency

Teams should establish build mode conventions:

**Recommended Practice**: All team members use the same build mode
as the team lead to ensure environment consistency.

**Mixed Mode Support**: Team members can use different modes, but
must ensure their mode includes all packages required by shared
code.

**Example Scenario**:

```bash
# Team Lead: Comprehensive mode for advanced analysis
zzcollab -i -t lab -p analysis -C

# Team Member 1: Comprehensive mode (recommended)
zzcollab -t lab -p analysis -I shell -C

# Team Member 2: Standard mode (possible but risky)
zzcollab -t lab -p analysis -I shell -S
# Risk: May lack packages if analysis uses tidymodels
```

### Package Addition Workflow

When adding packages beyond build mode defaults:

1. Install package in development environment:
   ```r
   install.packages("newpackage")
   ```

2. Update renv snapshot:
   ```r
   renv::snapshot()
   ```

3. Validate dependencies:
   ```bash
   make docker-check-renv-fix
   ```

4. Commit and push changes:
   ```bash
   git add renv.lock DESCRIPTION
   git commit -m "Add newpackage for analysis"
   git push
   ```

5. GitHub Actions rebuilds team image with new package

6. Team members synchronize:
   ```bash
   git pull
   docker pull lab/analysis:latest
   ```

## Performance Characteristics

### Build Time Analysis

Empirical measurements on standard hardware (2023 MacBook Pro,
M2 chip, 16GB RAM):

| Build Mode     | Docker Build | renv Restore | Total Time |
|----------------|--------------|--------------|------------|
| Fast           | 2.1 min      | 0.4 min      | 2.5 min    |
| Standard       | 4.3 min      | 1.2 min      | 5.5 min    |
| Comprehensive  | 11.8 min     | 2.7 min      | 14.5 min   |

Build times vary based on:

- Network bandwidth for package downloads
- CPU performance for compilation
- Docker layer caching effectiveness
- Number of package dependencies

### Storage Requirements

Approximate Docker image sizes:

| Build Mode     | Compressed   | Uncompressed |
|----------------|--------------|--------------|
| Fast           | 850 MB       | 2.1 GB       |
| Standard       | 1.2 GB       | 3.2 GB       |
| Comprehensive  | 2.8 GB       | 7.5 GB       |

Storage considerations:

- Docker images are cached locally
- Multiple images for different projects consume cumulative storage
- Regular cleanup with `docker system prune` recommended
- Team images stored on Docker Hub (no local storage cost)

## Custom Build Modes

### Defining Custom Modes

Users can define specialized build modes in configuration files:

```yaml
build_modes:
  bioinformatics:
    description: "Bioinformatics analysis environment"
    docker_packages: [renv, devtools, tidyverse, BiocManager,
                      Biostrings, GenomicRanges, DESeq2]
    renv_packages: [renv, devtools, tidyverse, BiocManager,
                    Biostrings, GenomicRanges, DESeq2, edgeR,
                    limma]

  geospatial:
    description: "Geospatial analysis environment"
    docker_packages: [renv, devtools, tidyverse, sf, terra,
                      leaflet, tmap]
    renv_packages: [renv, devtools, tidyverse, sf, terra,
                    leaflet, tmap, raster, rgdal]

  timeseries:
    description: "Time series analysis environment"
    docker_packages: [renv, devtools, tidyverse, forecast, tsibble,
                      fable]
    renv_packages: [renv, devtools, tidyverse, forecast, tsibble,
                    fable, prophet, zoo]
```

### Using Custom Build Modes

```bash
# Specify custom build mode
zzcollab -i -t lab -p genomics --build-mode bioinformatics

# Or via environment variable
export ZZCOLLAB_BUILD_MODE=geospatial
zzcollab -i -t lab -p mapping
```

### Custom Mode Validation

Custom build modes undergo the same validation as standard modes:

```bash
Rscript check_renv_for_commit.R \
  --build-mode bioinformatics --fail-on-issues
```

## Troubleshooting

### Common Issues

**Issue**: Build mode flag ignored

**Solution**: Check precedence order. Command-line flags override
environment variables and configuration files.

```bash
# Explicitly specify build mode
zzcollab -i -t lab -p study -S -d ~/dotfiles
```

**Issue**: Package missing despite correct build mode

**Solution**: Verify package is included in build mode definition.
Check configuration file or use default definitions.

```bash
# List effective build mode configuration
zzcollab --config list
```

**Issue**: Dependency validation fails

**Solution**: Update renv.lock and DESCRIPTION to match actual
package usage:

```bash
make docker-check-renv-fix
```

**Issue**: Build time exceeds expectations

**Solution**: Verify Docker layer caching is functioning. Clean
dangling images:

```bash
docker system prune -a
```

### Diagnostic Commands

```bash
# Check current build mode setting
zzcollab --config get build_mode

# Validate build mode configuration
zzcollab --config validate

# List all available build modes
zzcollab --config list | grep -A 10 "build_modes:"

# Test build mode detection
ZZCOLLAB_BUILD_MODE=fast zzcollab --version
```

## Best Practices

### General Recommendations

1. **Start Minimal**: Begin with Fast or Standard mode, upgrade as
   requirements emerge
2. **Consistency**: Maintain uniform build mode across team members
3. **Documentation**: Document build mode choice in project README
4. **Validation**: Regularly run dependency validation to ensure
   consistency
5. **Optimization**: Profile build times and adjust mode based on
   CI/CD constraints

### Continuous Integration

For CI/CD pipelines:

```yaml
# .github/workflows/test.yml
env:
  ZZCOLLAB_BUILD_MODE: fast

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup environment
        run: |
          zzcollab -t lab -p study -I shell -F
      - name: Run tests
        run: make docker-test
```

### Development Workflow

Development phase recommendations:

- **Prototyping**: Fast mode for rapid iteration
- **Analysis Development**: Standard mode for data work
- **Production**: Comprehensive mode for final deployments

## Migration Between Build Modes

### Upgrading Build Mode

To upgrade from Fast to Standard or Comprehensive:

```bash
# Rebuild Docker image with new mode
zzcollab -t lab -p study -I shell -S
docker-compose down
docker-compose up --build

# Synchronize renv
make docker-zsh
renv::restore()
```

### Downgrading Build Mode

To downgrade from Comprehensive to Standard or Fast:

1. Audit package usage:
   ```bash
   Rscript check_renv_for_commit.R --strict-imports
   ```

2. Remove packages not in target mode:
   ```r
   renv::remove("package_name")
   renv::snapshot()
   ```

3. Rebuild with target mode:
   ```bash
   zzcollab -t lab -p study -I shell -F
   ```

## References

### Documentation

- ZZCOLLAB User Guide: Comprehensive usage documentation
- Configuration Guide: Advanced configuration options
- Variant System Guide: Docker variant customization

### Technical Specifications

- renv Documentation: https://rstudio.github.io/renv/
- Docker Best Practices: https://docs.docker.com/develop/dev-best-practices/
- R Package Dependencies: https://r-pkgs.org/description.html

### Package Selection Rationale

Build mode package selections are based on:

- CRAN Task Views: https://cran.r-project.org/web/views/
- tidyverse Principles: https://www.tidyverse.org/
- R Journal Publications: https://journal.r-project.org/
- Community Surveys: R Consortium surveys and Stack Overflow trends
