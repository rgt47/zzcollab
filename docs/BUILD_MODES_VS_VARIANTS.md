# Build Modes vs Profiles: Understanding the Two-Layer System

## The Key Distinction

Build modes and profiles serve different purposes in the zzcollab workflow. Understanding when and how each is used is essential for efficient development.

## Build Modes vs Variants - Different Purposes

### Build Modes (-M, -F, -S, -C)
**Purpose**: Control which R packages get installed **during project development**

These affect the **project-specific packages** installed via `renv`:

- `-M` (Minimal): 3 packages - renv, remotes, here
- `-F` (Fast): 9 packages - adds devtools, testthat, knitr, rmarkdown, targets
- `-S` (Standard): 17 packages - adds tidyverse core (dplyr, ggplot2, tidyr, etc.)
- `-C` (Comprehensive): 47+ packages - adds tidymodels, shiny, databases, everything

**When used**: During full project setup (NOT during `-i` team initialization)

### Variants (minimal, analysis, modeling, etc.)
**Purpose**: Control which **base Docker image** and **pre-installed packages** the team uses

These affect the **Docker image** that gets built and pushed to Docker Hub:

- `minimal`: rocker/r-ver + 5 dev packages (renv, devtools, usethis, testthat, roxygen2)
- `analysis`: rocker/tidyverse + 8 analysis packages (janitor, scales, patchwork, gt, DT)
- `modeling`: rocker/tidyverse + ML packages (tidymodels, xgboost, randomForest)

**When used**: During team initialization (`zzcollab -i`)

## The Relationship: A Two-Layer System

They work together in a **two-layer architecture**:

```
Layer 1 (Variants): Base Docker image with pre-installed packages
    ↓
Layer 2 (Build Modes): Additional project-specific packages via renv
```

## Complete Workflow Example

### Team Lead - Team Initialization:
```bash
# Build mode is stored but NOT used during -i
zzcollab -i -p my-project -M

# What actually happens:
# 1. Build mode "minimal" is saved to config
# 2. Variants from config.yaml are built (minimal + analysis)
# 3. Docker images pushed to Docker Hub
# 4. Build mode (-M) is NOT applied yet
```

### Team Member - Full Project Setup:
```bash
cd my-project

# Now build mode DOES matter
zzcollab -I analysis -M  # Use analysis profile + minimal build mode

# What happens:
# 1. Pulls rgt47/my-project_core-analysis (profile with tidyverse)
# 2. Runs renv::install() with MINIMAL packages (3 packages)
# 3. Final environment = tidyverse (from profile) + 3 packages (from build mode)
```

## Why This Two-Layer Design?

**Efficiency**:
- Variants are **shared** across team (built once, used by everyone)
- Build modes are **per-developer** (each developer picks their package set)

**Flexibility**:
- Team provides base environments (profiles)
- Developers customize for their work (build modes)

## Practical Scenarios

### Scenario 1: Data Scientist
```bash
# Use analysis profile (has tidyverse) + comprehensive mode (get all tools)
zzcollab -t team -p project -I analysis -C

# Final environment:
# - From profile: tidyverse, ggplot2, dplyr (already in Docker)
# - From build mode: tidymodels, shiny, databases (installed via renv)
```

### Scenario 2: Package Developer
```bash
# Use minimal profile (lightweight) + minimal mode (bare essentials)
zzcollab -t team -p project -I minimal -M

# Final environment:
# - From profile: devtools, testthat (already in Docker)
# - From build mode: renv, remotes, here (installed via renv)
# - Ultra-lightweight, fast
```

### Scenario 3: Mixed Team
```bash
# Team lead builds both profiles
zzcollab -i -p project -M  # Profiles: minimal + analysis

# Developer 1 (package dev): minimal profile + minimal mode
zzcollab -t team -p project -I minimal -M

# Developer 2 (data analysis): analysis profile + standard mode
zzcollab -t team -p project -I analysis -S

# Same codebase, different environments!
```

## Key Insight

**Variants** = What the **team** provides (Docker images on Docker Hub)
**Build Modes** = What **you** add to your local environment (renv packages)

The profile gives you a starting point, the build mode customizes from there.

## Docker Variants Explained

Docker profiles in zzcollab are **different pre-configured Docker environments** for different types of research work. Each profile has:
- Different base Docker image
- Different set of R packages pre-installed
- Different system libraries
- Different size/build time tradeoffs

Think of profiles as "flavors" of your research environment, optimized for different tasks.

### The Two Default Variants

**1. minimal** (~800MB, ~40 seconds to build)
- Base: `rocker/r-ver` (plain R, no extras)
- Packages: renv, devtools, usethis, testthat, roxygen2
- Purpose: Package development, testing, CI/CD
- When to use: Building R packages, running tests, lightweight work

**2. analysis** (~1.2GB, ~30 seconds to build)
- Base: `rocker/tidyverse` (R + tidyverse pre-installed)
- Packages: renv, devtools, here, janitor, scales, patchwork, gt, DT
- Purpose: Data analysis, visualization, reporting
- When to use: Data science work, creating reports, exploratory analysis

### Why Multiple Variants?

Different research tasks need different tools:

```bash
# Package development - use minimal
docker run rgt47/penguins-bills_core-minimal

# Data analysis - use analysis
docker run rgt47/penguins-bills_core-analysis
```

### All Available Variants (14+)

**Standard Research** (6 profiles):
- `minimal` - Essential R packages only
- `analysis` - Tidyverse + data tools (DEFAULT, enabled)
- `modeling` - Machine learning (tidymodels, xgboost)
- `publishing` - LaTeX, Quarto, bookdown for papers
- `shiny` - Interactive web apps
- `shiny_verse` - Shiny + tidyverse + publishing

**Specialized Domains** (2 profiles):
- `bioinformatics` - Bioconductor genomics packages
- `geospatial` - sf, terra, leaflet mapping

**Lightweight Alpine** (3 profiles):
- `alpine_minimal` - Ultra-small (~200MB) for CI/CD
- `alpine_analysis` - Data analysis in tiny container (~400MB)
- `hpc_alpine` - High-performance parallel computing (~600MB)

**R-Hub Testing** (3 profiles):
- `rhub_ubuntu` - CRAN-compatible testing
- `rhub_fedora` - R-devel testing
- `rhub_windows` - Windows compatibility

### How Variants Work

1. **Template defines profiles**: `profiles.yaml` has full specifications
2. **Project config enables profiles**: `config.yaml` sets which ones to build
3. **Team initialization builds enabled profiles**: `zzcollab -i` builds all enabled
4. **Team members choose profile**: `zzcollab -I analysis` uses analysis profile

### Practical Example

```bash
# Team lead builds two profiles
zzcollab -i -p my-project  # Builds minimal + analysis (defaults)

# Developer 1: package development
zzcollab -t team -p my-project -I minimal
make docker-zsh  # lightweight environment

# Developer 2: data analysis
zzcollab -t team -p my-project -I analysis
make docker-zsh  # tidyverse environment
```

Each developer gets the exact tools they need without bloat!

## Is Package Installation Smart About Duplicates?

Yes! The system is designed to avoid redundant package installations. Here's how it works:

### How Duplicate Prevention Works

#### Docker Layer (Variants)
Packages installed in the Docker image via `install2.r` are **already available** in R's library path. They don't need reinstalling.

#### renv Layer (Build Modes)
When you run `renv::install()` with build mode packages:
- renv checks if package is already installed
- If found in system library → **skips installation**
- If not found → installs to project-specific renv library

### Example: Analysis Variant + Standard Build Mode

**Analysis profile has:**
- tidyverse (includes dplyr, ggplot2, tidyr, etc.)
- janitor, scales, patchwork, gt, DT

**Standard build mode wants:**
- dplyr, ggplot2, tidyr (from tidyverse)
- palmerpenguins, broom, janitor, DT, conflicted

**What actually gets installed:**
```r
# renv sees these are already available from Docker:
# - dplyr ✓ (from tidyverse in profile)
# - ggplot2 ✓ (from tidyverse in profile)
# - tidyr ✓ (from tidyverse in profile)
# - janitor ✓ (from profile)
# - DT ✓ (from profile)

# renv only installs:
# - palmerpenguins (NEW)
# - broom (NEW)
# - conflicted (NEW)
```

### The Smart Detection

The system lists packages to install, but renv itself is smart about checking what's already there. Here's how it works:

1. **Variant packages** are installed to system library (`/usr/local/lib/R/site-library`)
2. **Build mode packages** are requested for renv to install
3. **renv checks** if package exists before installing

### Current Behavior

**Good news**: renv's `install()` is smart enough to skip already-installed packages, so there's no **duplicate installation**.

**Room for improvement**: The package lists could be **pre-filtered** to explicitly exclude profile packages, making the process faster and cleaner.

**In practice**: The overlap doesn't cause major issues because:
- renv checks before installing (fast)
- System libraries are reused (no duplication)
- Only truly missing packages get installed

So the system is smart enough to avoid reinstallation, though not yet optimized to avoid even checking for packages that are guaranteed to be in the profile.

## Why Two Images Built by Default?

When you run `zzcollab -i -p penguins-bills`, the system looks at the project's `config.yaml` (NOT your user config at `~/.zzcollab/config.yaml`).

The project-level `config.yaml` is automatically created during team initialization and has two profiles enabled by default:

```yaml
# Created by zzcollab team initialization
profiles:
  minimal:
    enabled: true    # Essential development environment (~800MB)

  analysis:
    enabled: true    # Tidyverse analysis environment (~1.2GB)
```

This is why two images were built. The template for this file is in `templates/config.yaml` and includes:

```yaml
profiles:

  #---------------------------------------------------------------------------
  # DEFAULT VARIANTS (Enabled by default for new teams)
  #---------------------------------------------------------------------------

  minimal:
    enabled: true    # Essential development environment (~800MB)
    # Full definition in profiles.yaml

  analysis:
    enabled: true    # Tidyverse analysis environment (~1.2GB)
    # Full definition in profiles.yaml
```

### Why These Defaults?

Having both `minimal` and `analysis` enabled gives teams flexibility:
- Use `minimal` for package development and testing (lightweight, faster)
- Use `analysis` for data science work (has tidyverse + visualization tools)

### How to Change Defaults

If you only want one profile, you have two options:

**Option 1: Edit project config.yaml before building**
```bash
zzcollab -i -p my-project  # Creates project directory with config.yaml
cd my-project
vim config.yaml  # Set analysis enabled: false
cd ..
# Then re-run initialization (or manually build profiles)
```

**Option 2: Use legacy -B flag (bypasses config.yaml)**
```bash
zzcollab -i -p my-project -B r-ver  # Builds only shell profile
```

### The Workflow

1. `zzcollab -i -p penguins-bills` creates a `penguins-bills/config.yaml`
2. That config has `minimal: enabled: true` and `analysis: enabled: true` by default
3. Both profiles get built and pushed to Docker Hub
4. Team members can choose which profile to use: `zzcollab -I minimal` or `zzcollab -I analysis`

This design allows teams to provide multiple environment options without requiring each team member to build their own Docker images.
