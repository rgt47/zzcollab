# Docker Profile System Guide

## Overview

ZZCOLLAB provides eight built-in Docker profiles through a single
source of truth architecture that eliminates configuration
duplication while enabling unlimited customization. This guide
documents the profile system design, available profiles, and
implementation patterns for research computing environments.
Specialized research domains (for example genomics or geospatial
work) are supported by selecting a custom base image rather than a
dedicated profile; see the Specialized Domains section below.

## Profile System Architecture

### Single Source of Truth Design

The profile system implements a library-reference pattern:

**Master Library** (`templates/profiles.yaml`):

- Contains complete definitions for all available profiles
- Maintained as single authoritative source
- Updated independently from team configurations
- Provides the eight pre-configured environments

**Team Configuration** (`config.yaml`):

- References profiles by name from library
- Enables/disables specific profiles for project
- Optionally overrides specific parameters
- Eliminates duplicate profile definitions

### Benefits

1. **Elimination of Duplication**: Profile definitions maintained
   in one location
2. **Simplified Maintenance**: Updates propagate to all projects
   automatically
3. **Easy Discovery**: Profile listing via `zzcollab list`
4. **Backward Compatibility**: Legacy full definitions still
   supported
5. **Unlimited Customization**: Teams can define completely custom
   profiles

## Profile Categories

The eight built-in profiles are: `minimal`, `analysis`,
`analysis_pdf`, `modeling`, `publishing`, `rstudio`, `shiny`, and
`manuscript-package`. Any of these may be supplied directly to the
`zzcollab` quickstart (for example `zzcollab analysis`) or selected
with `zzcollab -r <profile>` / `zzcollab --profile <profile>`.

### Standard Research Environments

Production-ready environments for general research computing.

**minimal** (~800MB)

- **Base Image**: `rocker/r-ver:latest`
- **Description**: Essential R packages for package development
- **Key Packages**: renv, devtools, usethis, testthat, roxygen2
- **Use Cases**: Package development, CI/CD testing, minimal
  overhead projects
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev

**analysis** (~1.2GB)

- **Base Image**: `rocker/tidyverse:latest`
- **Description**: Data analysis with tidyverse ecosystem
- **Key Packages**: renv, devtools, here, janitor, scales,
  patchwork, gt, DT
- **Use Cases**: Exploratory data analysis, standard data
  manipulation, visualization
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev

**modeling** (~1.5GB)

- **Base Image**: `rocker/r-ver:latest`
- **Description**: Machine learning and statistical modeling
- **Key Packages**: renv, tidyverse, tidymodels, xgboost,
  randomForest, glmnet, caret, MASS, mlr3
- **Use Cases**: Predictive modeling, machine learning pipelines,
  statistical analysis
- **System Dependencies**: libxml2-dev, libssl-dev, libgsl-dev,
  libblas-dev, liblapack-dev, build-essential, gfortran

**publishing** (~3GB)

- **Base Image**: `rocker/verse:latest`
- **Description**: Document publishing with LaTeX, Quarto, and RStudio Server
- **Supported File Formats**: .R, .Rmd, .Rnw (Sweave), .qmd (Quarto)
- **Key System Tools**: Quarto CLI (v1.6.33), pandoc, texlive-full (complete LaTeX)
- **Key R Packages**: renv, devtools, quarto, bookdown, blogdown,
  distill, flexdashboard, shiny, DT, plotly
- **Use Cases**:
  - Academic papers (.Rnw with LaTeX)
  - Quarto documents (.qmd for R/Python/JS mixing)
  - Books (bookdown)
  - Blogs (blogdown)
  - Interactive dashboards
  - Manuscripts with reproducible analysis
- **System Dependencies**: Quarto CLI, pandoc, texlive-full, libxml2-dev,
  libcurl4-openssl-dev, libssl-dev, libv8-dev
- **Design Note**: All system dependencies (including Quarto CLI version)
  are version-controlled in the Dockerfile. Users should NOT install
  system tools at runtime. To modify, edit the Dockerfile and rebuild.
- **Note**: AMD64 only, see ARM64 section for alternatives

**shiny** (~1.8GB)

- **Base Image**: `rocker/shiny:latest`
- **Description**: Interactive web applications and dashboards
- **Key Packages**: renv, shiny, shinydashboard, shinyjs, plotly,
  DT, tidyverse
- **Use Cases**: Interactive dashboards, web applications, data
  exploration tools
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev

**analysis_pdf** (~3GB)

- **Base Image**: `rocker/verse:latest`
- **Description**: Data analysis with PDF report rendering
- **Key Packages**: renv, tidyverse, rmarkdown, knitr, tinytex
- **Use Cases**: Exploratory analysis that produces PDF output,
  reproducible reports combining analysis and typeset documents
- **System Dependencies**: texlive, libxml2-dev,
  libcurl4-openssl-dev, libssl-dev
- **Note**: AMD64 only, see ARM64 section for alternatives

**rstudio** (~1.5GB)

- **Base Image**: `rocker/rstudio:latest`
- **Description**: RStudio Server for interactive development
- **Key Packages**: renv, devtools, usethis, tidyverse
- **Use Cases**: Browser-based RStudio sessions (`make
  docker-rstudio`), interactive analysis and teaching
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev

**manuscript-package** (~3GB)

- **Base Image**: `rocker/verse:latest`
- **Description**: Manuscript writing combined with R package
  development
- **Key Packages**: renv, devtools, testthat, roxygen2, quarto,
  bookdown, rmarkdown
- **Use Cases**: Research compendia that ship both an R package
  and a typeset manuscript, reproducible papers under package
  structure
- **System Dependencies**: Quarto CLI, pandoc, texlive,
  libxml2-dev, libcurl4-openssl-dev, libssl-dev
- **Note**: AMD64 only, see ARM64 section for alternatives

### Specialized Domains

ZZCOLLAB does not ship dedicated profiles for individual research
fields such as genomics or geospatial analysis. Instead, start from
one of the eight built-in profiles and supply a domain-specific base
image with `zzcollab docker --base-image <image>`. Domain R packages
are then installed and pinned through `renv` exactly as for any other
project.

**Genomics / Bioinformatics**

- **Approach**: `zzcollab modeling`, then build on a Bioconductor
  base image
- **Command**:
  ```bash
  zzcollab docker --base-image bioconductor/bioconductor_docker
  ```
- **Packages**: install BiocManager, DESeq2, edgeR, limma,
  GenomicRanges, and related packages inside the container, then
  capture them with `renv::snapshot()`
- **Documentation**: https://bioconductor.org/

**Geospatial**

- **Approach**: `zzcollab modeling`, then build on a geospatial
  base image
- **Command**:
  ```bash
  zzcollab docker --base-image rocker/geospatial
  ```
- **Packages**: install sf, terra, leaflet, mapview, and tmap
  inside the container, then capture them with `renv::snapshot()`
- **Documentation**: https://r-spatial.org/

## Profile Usage

### Listing Available Profiles

Use the built-in `list` command to display the available profiles:

```bash
# List the built-in profiles
zzcollab list

# Built-in profiles:
#   minimal             ~800MB  - Essential R packages
#   analysis            ~1.2GB  - Tidyverse + data analysis
#   analysis_pdf        ~3GB    - Tidyverse + PDF rendering
#   modeling            ~1.5GB  - Machine learning
#   publishing          ~3GB    - LaTeX, Quarto, bookdown
#   rstudio             ~1.5GB  - RStudio Server
#   shiny               ~1.8GB  - Interactive web apps
#   manuscript-package  ~3GB    - Manuscript + R package
```

Select a profile when creating the project, for example
`zzcollab analysis`, `zzcollab -r modeling`, or
`zzcollab --profile publishing`.

### Manual Configuration

**config.yaml Structure**:

```yaml
#=========================================================
# DOCKER PROFILES
#=========================================================

profiles:
  # Essential development
  minimal:
    enabled: true             # ~800MB

  # Primary analysis environment
  analysis:
    enabled: true             # ~1.2GB

  # Interactive RStudio Server
  rstudio:
    enabled: true             # ~1.5GB

  # Disabled profiles (available but not built)
  modeling:
    enabled: false            # ~1.5GB

  publishing:
    enabled: false            # ~3GB

  analysis_pdf:
    enabled: false            # ~3GB

  manuscript-package:
    enabled: false            # ~3GB

#=========================================================
# BUILD CONFIGURATION
#=========================================================

build:
  # Use profiles defined in this config
  use_config_profiles: true

  # Reference the profile library
  profile_library: "profiles.yaml"
```

### Command Line Usage

**Team Initialization**:

```bash
# Set the team Docker Hub account once
zzcollab config set dockerhub-account lab

# Create project with default profiles
# (project name is the working directory)
mkdir study && cd study
zzcollab analysis
make docker-build
make docker-push-team

# For team collaboration, push team image to Docker Hub
```

**Adding a Profile to an Existing Project**:

```bash
# Edit config.yaml to enable an additional profile, then rebuild
cd study
zzcollab list          # review the available profiles

# Rebuild Docker image after enabling a profile
make docker-build
```

## Custom Profile Definition

### Complete Custom Profile

Define entirely new profiles in config.yaml:

```yaml
profiles:
  custom_gpu:
    base_image: "nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04"
    description: "GPU-accelerated machine learning"
    packages:
      - renv
      - keras
      - tensorflow
      - torch
      - xgboost
    system_deps:
      - libcudnn8
      - python3
      - python3-pip
    enabled: true
    category: "custom"
    size: "~3.5GB"
    notes: "Requires NVIDIA GPU and Docker GPU support"

  custom_spatial:
    base_image: "rocker/geospatial:latest"
    description: "Extended geospatial with specialized packages"
    packages:
      - renv
      - sf
      - terra
      - stars
      - gstat
      - spatstat
      - mapview
      - leaflet
      - tmap
    system_deps:
      - gdal-bin
      - proj-bin
      - libgeos-dev
      - libproj-dev
      - libgdal-dev
      - libudunits2-dev
    enabled: true
    category: "custom"
    size: "~2.8GB"
```

### Extending Existing Profiles

Override specific parameters from library profiles:

```yaml
profiles:
  analysis:
    enabled: true
    # Add additional packages to analysis profile
    additional_packages:
      - arrow
      - pins
      - vetiver

  modeling:
    enabled: true
    # Override base image
    base_image: "rocker/ml-verse:latest"
    # Add GPU support
    system_deps:
      - nvidia-cuda-toolkit
```

## Profile Architecture

### Docker Image Layers

Profiles follow a layered architecture:

```
Layer 1: Base Image (rocker/r-ver, etc.)
    ↓
Layer 2: System Dependencies (apt packages)
    ↓
Layer 3: R Package Installation (install2.r)
    ↓
Layer 4: Development Tools (vim, git, etc.)
```

### Build Process

Profile building follows this sequence:

1. **Configuration Loading**: Read profile definition from library
2. **Base Image Pull**: Download specified base image
3. **System Dependencies**: Install apt/apk packages
4. **R Package Installation**: Install specified R packages
5. **Layer Caching**: Cache each layer for faster rebuilds
6. **Image Tagging**: Tag with version and profile name
7. **Registry Push**: Push to Docker Hub (optional)

### Package Installation Methods

Profiles support multiple R package installation methods:

**install2.r** (preferred):

```dockerfile
RUN install2.r --error --skipinstalled --ncpus -1 \
    renv devtools tidyverse \
    && rm -rf /tmp/downloaded_packages
```

**R CMD INSTALL**:

```dockerfile
RUN R CMD INSTALL package_source.tar.gz
```

**BiocManager** (Bioconductor packages):

```dockerfile
RUN R -e "BiocManager::install(c('DESeq2', 'edgeR'))"
```

**GitHub packages**:

```dockerfile
RUN R -e "remotes::install_github('owner/repo')"
```

## Platform Considerations

### ARM64 Compatibility

**Compatible Base Images**:

- rocker/r-ver (ARM64 + AMD64)
- rocker/rstudio (ARM64 + AMD64)
- rocker/tidyverse (ARM64 + AMD64)

**AMD64 Only Base Images**:

- rocker/verse (use custom ARM64 equivalent)
- rocker/geospatial (limited ARM64 support)
- rocker/shiny (AMD64 only)

**ARM64 Solutions**:

1. Use compatible base images:
   ```bash
   zzcollab config set dockerhub-account lab
   mkdir study && cd study
   zzcollab analysis
   # Customize config.yaml to enable only ARM64-compatible profiles
   # (minimal, analysis, modeling, rstudio - exclude verse-based
   # profiles such as publishing, analysis_pdf, manuscript-package)
   make docker-build
   make docker-push-team
   ```

2. Build custom ARM64 images:
   ```dockerfile
   FROM rocker/tidyverse:latest
   # Install verse packages manually for ARM64
   RUN apt-get update && apt-get install -y \
       texlive-full pandoc
   RUN install2.r bookdown blogdown quarto
   ```

3. Use platform-specific configuration:
   ```yaml
   profiles:
     publishing:
       enabled: true
       base_image: "rocker/verse:latest"
       platform: "linux/amd64"  # Force AMD64

     publishing_arm64:
       enabled: true
       base_image: "rocker/tidyverse:latest"
       platform: "linux/arm64"  # ARM64 alternative
   ```

### Multi-Platform Builds

Enable multi-platform builds:

```yaml
build:
  docker:
    platforms:
      - linux/amd64
      - linux/arm64
    buildx: true
```

Command line:

```bash
# Build for multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 \
  -t lab/study:latest .
```

## Profile Selection Guide

### Decision Framework

**Question 1: What is the primary analysis type?**

- General data analysis → **analysis**
- Machine learning → **modeling**
- Document writing → **publishing**
- Analysis with PDF output → **analysis_pdf**
- Interactive RStudio development → **rstudio**
- Bioinformatics → **modeling** with a Bioconductor base image
  (`zzcollab docker --base-image bioconductor/bioconductor_docker`)
- Geospatial → **modeling** with a geospatial base image
  (`zzcollab docker --base-image rocker/geospatial`)
- Interactive apps → **shiny**
- Manuscript plus R package → **manuscript-package**

**Question 2: What are the resource constraints?**

- Unlimited resources → standard profiles
- Limited disk space → start from **minimal**
- CI/CD environment → **minimal**

**Question 3: What is the team structure?**

- Solo developer → 1-2 profiles (minimal + analysis)
- Small team (2-5) → 2-3 profiles (minimal + analysis + specialty)
- Large team (5+) → 3+ profiles (full spectrum)

### Paradigm-Specific Recommendations

**Analysis Paradigm**:

- Required: analysis
- Optional: modeling (if ML), shiny (if dashboards)
- Testing: minimal

**Manuscript Paradigm**:

- Required: publishing
- Optional: analysis (if reproducing analysis)
- Testing: minimal

**Package Paradigm**:

- Required: minimal
- Optional: analysis (if vignettes use data analysis)
- Testing: minimal

## Profile Maintenance

### Updating Profile Definitions

**Library Updates** (maintainer only):

```bash
# Edit master library
vim templates/profiles.yaml

# Validate changes
zzcollab config validate

# Commit to repository
git add templates/profiles.yaml
git commit -m "Update profile definitions"
```

**Team Configuration Updates**:

```bash
# Team members pull latest changes
git pull

# Rebuild with updated definitions
make docker-build
```

### Version Control

Track profile configuration changes:

```bash
# Version tag for major changes
git tag -a profiles-v2.0 -m "Add GPU and spatial profiles"

# Reference specific version
git checkout profiles-v2.0
make docker-build
```

### Deprecation

When profiles become obsolete:

```yaml
profiles:
  old_profile:
    enabled: false
    deprecated: true
    deprecation_message: "Use 'new_profile' instead"
    removal_date: "2025-06-01"
```

## Performance Optimization

### Build Time Optimization

1. **Layer Caching**: Structure Dockerfile for optimal caching
2. **Parallel Builds**: Enable parallel package installation
3. **Pre-built Images**: Use team base images
4. **Selective Profiles**: Only build required profiles

**Example**:

```yaml
build:
  docker:
    parallel_builds: true
    max_parallel: 4
    cache_from:
      - lab/study:latest
```

### Storage Optimization

1. **Multi-stage Builds**: Reduce final image size
2. **Layer Cleanup**: Remove temporary files
3. **Minimal Profile**: Use for space-constrained scenarios

**Example**:

```dockerfile
# Multi-stage build
FROM rocker/r-ver:latest AS builder
RUN install2.r tidyverse
RUN rm -rf /tmp/downloaded_packages

FROM rocker/r-ver:latest
COPY --from=builder /usr/local/lib/R/site-library \
     /usr/local/lib/R/site-library
```

## Troubleshooting

### Common Issues

**Issue**: Profile not found

```
Error: Profile 'modelng' not found in library
```

**Solution**: Check spelling, use `zzcollab list` to browse
available profiles

**Issue**: Base image pull fails

```
Error: Cannot pull nvidia/cuda:11.8.0
```

**Solution**: Verify Docker Hub access, check image name and tag

**Issue**: Package installation fails

```
Error: Package 'BiocManager' not available for R 4.2.0
```

**Solution**: Check package availability for R version, update
base image if needed

**Issue**: System dependency missing

```
Error: libgdal-dev : Depends: libgdal30 but it is not
installable
```

**Solution**: Update system package names for base image OS
version

### Diagnostic Commands

```bash
# List available profiles
zzcollab list

# Validate profile configuration
zzcollab config validate

# Check base image availability
docker pull rocker/r-ver:latest

# Test profile build
docker build -f Dockerfile.profile -t test:latest .

# Inspect image layers
docker history lab/study-analysis:latest
```

## Best Practices

### Profile Selection

1. Start minimal, add profiles as needed
2. Use the minimal profile for CI/CD pipelines
3. Enable only profiles team actively uses
4. Document profile choices in configuration

### Custom Profiles

1. Extend existing profiles rather than creating from scratch
2. Document package selections and rationale
3. Test profiles thoroughly before team deployment
4. Version control custom profile definitions

### Team Collaboration

1. Establish profile conventions early
2. Document which profile for which tasks
3. Coordinate profile additions through team lead
4. Regular profile cleanup and maintenance

## References

### Documentation

- Rocker Project: https://rocker-project.org/
- Docker Hub: https://hub.docker.com/
- Bioconductor Docker: https://www.bioconductor.org/help/docker/
- R-Hub Builder: https://r-hub.github.io/rhub/

### Related Guides

- ZZCOLLAB User Guide: Comprehensive usage documentation
- Configuration Guide (CONFIGURATION.md): Advanced configuration options
- Development Guide (DEVELOPMENT.md): Package management and workflows
- Package Management Guide (guides/renv.md): Dynamic package management with renv

### Technical Specifications

- Dockerfile Reference: https://docs.docker.com/engine/reference/builder/
- Docker Multi-stage Builds:
  https://docs.docker.com/build/building/multi-stage/
- Docker Buildx: https://docs.docker.com/buildx/working-with-buildx/
