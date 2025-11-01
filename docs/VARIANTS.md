# Docker Profile System Guide

## Overview

ZZCOLLAB provides 14+ specialized Docker profiles through a single
source of truth architecture that eliminates configuration
duplication while enabling unlimited customization. This guide
documents the profile system design, available profiles, and
implementation patterns for research computing environments.

## Profile System Architecture

### Single Source of Truth Design

The profile system implements a library-reference pattern:

**Master Library** (`templates/profiles.yaml`):

- Contains complete definitions for all available profiles
- Maintained as single authoritative source
- Updated independently from team configurations
- Provides 14+ pre-configured environments

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
3. **Easy Discovery**: Interactive profile browser
   (`add_profile.sh`)
4. **Backward Compatibility**: Legacy full definitions still
   supported
5. **Unlimited Customization**: Teams can define completely custom
   profiles

## Profile Categories

### Standard Research Environments (6 Profiles)

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
- **Description**: Document publishing with LaTeX and Quarto
- **Key Packages**: renv, devtools, quarto, bookdown, blogdown,
  distill, flexdashboard, shiny, DT, plotly
- **Use Cases**: Academic papers, books, blogs, interactive
  documents
- **System Dependencies**: pandoc, texlive-full, libxml2-dev,
  libcurl4-openssl-dev, libssl-dev, libv8-dev
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

**shiny_verse** (~3.5GB)

- **Base Image**: `rocker/shiny-verse:latest`
- **Description**: Shiny applications with tidyverse and
  publishing
- **Key Packages**: All shiny packages plus tidyverse, rmarkdown,
  bookdown
- **Use Cases**: Complex dashboards with document generation,
  integrated applications
- **System Dependencies**: Complete tidyverse and shiny
  dependencies

### Specialized Domains (2 Profiles)

Domain-specific environments for specialized research fields.

**bioinformatics** (~2GB)

- **Base Image**: `bioconductor/bioconductor_docker:latest`
- **Description**: Bioinformatics analysis with Bioconductor
- **Key Packages**: renv, BiocManager, DESeq2, edgeR, limma,
  GenomicRanges, Biostrings, rtracklayer
- **Use Cases**: Genomics, transcriptomics, sequence analysis,
  differential expression
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev, zlib1g-dev, libbz2-dev, liblzma-dev
- **Documentation**: https://bioconductor.org/

**geospatial** (~2.5GB)

- **Base Image**: `rocker/geospatial:latest`
- **Description**: Geospatial analysis with sf, terra, and
  mapping
- **Key Packages**: renv, sf, terra, leaflet, mapview, tmap
- **Use Cases**: Spatial data analysis, mapping, GIS operations,
  remote sensing
- **System Dependencies**: gdal-bin, proj-bin, libgeos-dev,
  libproj-dev, libgdal-dev, libudunits2-dev, netcdf-bin,
  libxml2-dev
- **Documentation**: https://r-spatial.org/

### Lightweight Alpine Profiles (3 Profiles)

Ultra-lightweight environments for resource-constrained scenarios.

**alpine_minimal** (~200MB)

- **Base Image**: `velaco/alpine-r:latest`
- **Description**: Minimal Alpine Linux with R for CI/CD
- **Key Packages**: renv, devtools, testthat
- **Use Cases**: Continuous integration, automated testing,
  resource-limited environments
- **System Dependencies**: git, make, gcc, g++, musl-dev,
  linux-headers, curl, curl-dev, openssl-dev, libxml2-dev
- **Size Comparison**: ~200MB vs ~1GB for rocker images (5x
  smaller)

**alpine_analysis** (~400MB)

- **Base Image**: `velaco/alpine-r:latest`
- **Description**: Lightweight Alpine with core data analysis
- **Key Packages**: renv, dplyr, ggplot2, readr, tidyr, here,
  janitor, devtools
- **Use Cases**: Lightweight data analysis, containerized
  workflows, edge computing
- **System Dependencies**: git, make, gcc, g++, gfortran,
  musl-dev, linux-headers, curl, curl-dev, openssl-dev,
  libxml2-dev
- **Size Comparison**: ~400MB vs ~1.2GB for rocker/tidyverse

**hpc_alpine** (~600MB)

- **Base Image**: `velaco/alpine-r:latest`
- **Description**: HPC-focused with parallel processing
- **Key Packages**: renv, future, furrr, doParallel, foreach,
  parallel, Rmpi
- **Use Cases**: High-performance computing, parallel processing,
  cluster computing
- **System Dependencies**: openmpi, openmpi-dev, git, make, gcc,
  g++, gfortran
- **Features**: MPI support, parallel backends, cluster
  integration

### R-Hub Testing Environments (3 Profiles)

CRAN-compatible testing environments for package validation.

**rhub_ubuntu** (~1GB)

- **Base Image**: `rhub/ubuntu-gcc:latest`
- **Description**: Ubuntu testing environment matching CRAN
- **Key Packages**: renv, devtools, testthat, rcmdcheck
- **Use Cases**: CRAN submission preparation, Linux compatibility
  testing
- **R Version**: Multiple R versions available (R-release,
  R-devel)
- **Documentation**: https://r-hub.github.io/rhub/

**rhub_fedora** (~1.2GB)

- **Base Image**: `rhub/fedora-clang-devel:latest`
- **Description**: Fedora with R-devel for forward compatibility
- **Key Packages**: renv, devtools, testthat, rcmdcheck
- **Use Cases**: Testing against R-devel, compiler compatibility
  testing
- **R Version**: R-devel (development version)
- **Compiler**: Clang for stricter checking

**rhub_windows** (~1.5GB)

- **Base Image**: `rhub/windows-x86_64:latest`
- **Description**: Windows compatibility testing
- **Key Packages**: renv, devtools, testthat, rcmdcheck
- **Use Cases**: Windows-specific testing, cross-platform
  validation
- **R Version**: R-release for Windows
- **Note**: Requires Docker Windows containers support

## Profile Usage

### Interactive Profile Selection

**add_profile.sh Script**:

```bash
# Launch interactive profile browser
./add_profile.sh

# Displays categorized menu:
=======================================================
ZZCOLLAB DOCKER PROFILE LIBRARY
=======================================================

STANDARD RESEARCH ENVIRONMENTS
  1) minimal          ~800MB  - Essential R packages
  2) analysis         ~1.2GB  - Tidyverse + data analysis
  3) modeling         ~1.5GB  - Machine learning
  4) publishing       ~3GB    - LaTeX, Quarto, bookdown
  5) shiny            ~1.8GB  - Interactive web apps
  6) shiny_verse      ~3.5GB  - Shiny + tidyverse

SPECIALIZED DOMAINS
  7) bioinformatics   ~2GB    - Bioconductor genomics
  8) geospatial       ~2.5GB  - sf, terra, mapping

LIGHTWEIGHT ALPINE PROFILES
  9) alpine_minimal   ~200MB  - Ultra-lightweight CI/CD
 10) alpine_analysis  ~400MB  - Lightweight analysis
 11) hpc_alpine       ~600MB  - Parallel processing

R-HUB TESTING ENVIRONMENTS
 12) rhub_ubuntu      ~1GB    - CRAN Ubuntu testing
 13) rhub_fedora      ~1.2GB  - R-devel testing
 14) rhub_windows     ~1.5GB  - Windows compatibility

Enter profile numbers (space-separated): 1 2 9
```

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

  # CI/CD testing
  alpine_minimal:
    enabled: true             # ~200MB

  # Disabled profiles (available but not built)
  modeling:
    enabled: false            # ~1.5GB

  publishing:
    enabled: false            # ~3GB

  bioinformatics:
    enabled: false            # ~2GB

  geospatial:
    enabled: false            # ~2.5GB

#=========================================================
# BUILD CONFIGURATION
#=========================================================

build:
  # Use profiles defined in this config
  use_config_profiles: true

  # Reference the profile library
  profile_library: "profiles.yaml"

  # Docker build settings
  docker:
    platform: "auto"          # auto, linux/amd64, linux/arm64
    no_cache: false
    parallel_builds: true
```

### Command Line Usage

**Team Initialization**:

```bash
# Create project with default profiles
mkdir study && cd study
zzcollab -t lab -p study
make docker-build
make docker-push-team

# Create project with config-defined profiles
mkdir study && cd study
zzcollab -t lab -p study --profiles-config config.yaml
make docker-build
make docker-push-team

# Note: Use --profiles-config to build multiple specialized environments
# For team collaboration, push team image to Docker Hub
```

**Profile Addition**:

```bash
# Add profile to existing project
cd study
./add_profile.sh

# Build specific profile
zzcollab -V modeling

# Build all enabled profiles
zzcollab --profiles-config config.yaml
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
    ↓
Layer 5: User Configuration (dotfiles)
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
   mkdir study && cd study
   zzcollab -t lab -p study
   # Customize config.yaml to enable only ARM64-compatible profiles
   # (minimal, analysis, modeling - exclude verse, geospatial)
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
- Bioinformatics → **bioinformatics**
- Geospatial → **geospatial**
- Interactive apps → **shiny**

**Question 2: What are the resource constraints?**

- Unlimited resources → Standard profiles
- Limited disk space → Alpine profiles
- CI/CD environment → alpine_minimal

**Question 3: What is the team structure?**

- Solo developer → 1-2 profiles (minimal + analysis)
- Small team (2-5) → 2-3 profiles (minimal + analysis + specialty)
- Large team (5+) → 3+ profiles (full spectrum)

### Paradigm-Specific Recommendations

**Analysis Paradigm**:

- Required: analysis
- Optional: modeling (if ML), shiny (if dashboards)
- Testing: alpine_minimal

**Manuscript Paradigm**:

- Required: publishing
- Optional: analysis (if reproducing analysis)
- Testing: alpine_minimal

**Package Paradigm**:

- Required: minimal
- Optional: analysis (if vignettes use data analysis)
- Testing: alpine_minimal, rhub_ubuntu

## Profile Maintenance

### Updating Profile Definitions

**Library Updates** (maintainer only):

```bash
# Edit master library
vim templates/profiles.yaml

# Validate changes
./add_profile.sh --validate

# Commit to repository
git add templates/profiles.yaml
git commit -m "Update profile definitions"
```

**Team Configuration Updates**:

```bash
# Team members pull latest changes
git pull

# Rebuild with updated definitions
zzcollab --profiles-config config.yaml
```

### Version Control

Track profile configuration changes:

```bash
# Version tag for major changes
git tag -a profiles-v2.0 -m "Add GPU and spatial profiles"

# Reference specific version
git checkout profiles-v2.0
zzcollab --profiles-config config.yaml
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
3. **Alpine Profiles**: Use for space-constrained scenarios

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

**Solution**: Check spelling, use `./add_profile.sh` to browse
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
./add_profile.sh --list

# Validate profile configuration
./add_profile.sh --validate

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
2. Use Alpine for CI/CD pipelines
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
