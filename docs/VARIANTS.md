# Docker Profile System Guide

## Overview

ZZCOLLAB provides three built-in Docker profiles through a single
source of truth architecture that eliminates configuration
duplication while enabling unlimited customization. This guide
documents the profile system design, available profiles, and
implementation patterns for research computing environments.
Specialized research environments (for example LaTeX publishing,
Shiny applications, machine learning, genomics, or geospatial work)
are supported by selecting a custom base image rather than a
dedicated profile; see the Specialized Environments section below.

## Profile System Architecture

### Single Source of Truth Design

The profile system is defined in one place:

**Profile Bundles** (`templates/bundles.yaml`):

- Contains the definitions for the three built-in profiles
- Maintained as the single authoritative source
- Composes each profile from a base image, a system-library bundle,
  and an R-package bundle

Any environment beyond the three built-in profiles is obtained by
passing a base image to `zzcollab docker --base-image <image>` and
installing the required packages through `renv`; see the Specialized
Environments section.

### Benefits

1. **Single Definition**: The three profiles are defined in one
   location (`templates/bundles.yaml`)
2. **Easy Discovery**: Profile listing via `zzcollab list`
3. **Open Customization**: Any base image can be supplied with
   `zzcollab docker --base-image <image>`

## Profile Categories

The three built-in profiles are: `minimal`, `analysis`, and
`rstudio`. Any of these may be supplied directly to the
`zzcollab` quickstart (for example `zzcollab analysis`) or selected
with `zzcollab -r <profile>` / `zzcollab --profile <profile>`.

### Standard Research Environments

Production-ready environments for general research computing.

**minimal** (~650MB)

- **Base Image**: `rocker/r-ver`
- **Description**: Essential R packages for package development
- **Key Packages**: renv, devtools, usethis, tinytest, roxygen2
- **Use Cases**: Package development, CI/CD testing, minimal
  overhead projects
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev

**analysis** (~1.2GB)

- **Base Image**: `rocker/tidyverse`
- **Description**: Data analysis with tidyverse ecosystem
- **Key Packages**: renv, devtools, tidyverse, here
- **Use Cases**: Exploratory data analysis, standard data
  manipulation, visualization
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev

**rstudio** (~980MB)

- **Base Image**: `rocker/rstudio`
- **Description**: RStudio Server for interactive development
- **Key Packages**: renv, devtools, usethis, tinytest, roxygen2
- **Use Cases**: Browser-based RStudio sessions (`make
  docker-rstudio`), interactive analysis and teaching
- **System Dependencies**: libxml2-dev, libcurl4-openssl-dev,
  libssl-dev

### Specialized Environments

ZZCOLLAB ships only the three profiles above. Specialized
environments -- LaTeX/Quarto publishing, Shiny applications, machine
learning, genomics, geospatial analysis, and similar -- are supported
by selecting a domain-specific base image with
`zzcollab docker --base-image <image>` rather than a dedicated
profile. Domain R packages are then installed and pinned through
`renv` exactly as for any other project.

**LaTeX / Quarto publishing**

- **Approach**: build on the `rocker/verse` base image, which bundles
  texlive and Quarto
- **Command**:
  ```bash
  zzcollab docker --base-image rocker/verse
  ```
- **Packages**: install quarto, bookdown, blogdown, distill,
  flexdashboard, and DT inside the container, then capture them with
  `renv::snapshot()`
- **Note**: AMD64 only, see ARM64 section for alternatives

**Shiny applications**

- **Approach**: build on the `rocker/shiny` base image
- **Command**:
  ```bash
  zzcollab docker --base-image rocker/shiny
  ```
- **Packages**: install shiny, shinydashboard, shinyWidgets, plotly,
  and bslib inside the container, then capture them with
  `renv::snapshot()`
- **Note**: AMD64 only, see ARM64 section for alternatives

**Machine learning / statistical modeling**

- **Approach**: start from the `analysis` profile (or build on
  `rocker/r-ver`) and add ML packages via renv
- **Command**:
  ```bash
  zzcollab analysis
  ```
- **Packages**: install tidymodels, xgboost, randomForest, glmnet,
  and caret inside the container, then capture them with
  `renv::snapshot()`

**Genomics / Bioinformatics**

- **Approach**: build on a Bioconductor base image
- **Command**:
  ```bash
  zzcollab docker --base-image bioconductor/bioconductor_docker
  ```
- **Packages**: install BiocManager, DESeq2, edgeR, limma,
  GenomicRanges, and related packages inside the container, then
  capture them with `renv::snapshot()`
- **Documentation**: https://bioconductor.org/

**Geospatial**

- **Approach**: build on a geospatial base image
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
#   minimal             ~650MB  - Essential R packages
#   analysis            ~1.2GB  - Tidyverse + data analysis
#   rstudio             ~980MB  - RStudio Server
```

Select a profile when creating the project, for example
`zzcollab analysis`, `zzcollab -r minimal`, or
`zzcollab --profile rstudio`.

### Selecting the Default Profile

The active profile is recorded as `profile-name` in the
configuration hierarchy. Set it once and the quickstart and Docker
commands honour it:

```bash
# Record the default profile for the user
zzcollab config set profile-name analysis

# Inspect the current value
zzcollab config get profile-name
```

A `--profile <name>` (or `-r <name>`) flag on the command line
overrides the configured default for a single invocation.

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

**Switching the Profile of an Existing Project**:

```bash
cd study
zzcollab list                          # review the available profiles
zzcollab docker --profile rstudio      # regenerate the Dockerfile

# Rebuild the Docker image after switching profiles
make docker-build
```

## Beyond the Built-in Profiles

For any environment outside the three built-in profiles, supply a
domain-specific base image with `zzcollab docker --base-image
<image>` and install the required packages through `renv`. The
project then captures those packages in `renv.lock`, so the
environment remains reproducible without a dedicated profile.

```bash
# GPU-accelerated machine learning
zzcollab docker --base-image \
  nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Extended geospatial work
zzcollab docker --base-image rocker/geospatial
```

After selecting the base image, install packages inside the
container and snapshot them:

```r
renv::install(c('sf', 'terra', 'stars', 'gstat', 'tmap'))
renv::snapshot()
```

System libraries required by those packages are derived
automatically when the Dockerfile is generated, so they do not need
to be enumerated by hand.

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
   # The built-in profiles (minimal, analysis, rstudio) run on ARM64.
   # For verse-based environments (rocker/verse) supplied via
   # --base-image, see the AMD64 build alternatives below.
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

3. Pin the platform at build time. On Apple Silicon, AMD64-only
   base images run under emulation when the platform is forced:
   ```bash
   # Build a verse-based image for AMD64 on ARM64 hardware
   zzcollab docker --base-image rocker/verse
   docker build --platform linux/amd64 -t lab/study:latest .
   ```

### Multi-Platform Builds

Build for multiple architectures with `docker buildx`:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t lab/study:latest .
```

## Profile Selection Guide

### Decision Framework

**Question 1: What is the primary analysis type?**

- General data analysis → **analysis**
- Interactive RStudio development → **rstudio**
- Minimal / package development / CI → **minimal**
- Machine learning → **analysis**, add ML packages via renv
- Document writing → **analysis** with the rocker/verse base image
  (`zzcollab docker --base-image rocker/verse`)
- Analysis with PDF output → **analysis** with the rocker/verse base
  image (`zzcollab docker --base-image rocker/verse`)
- Bioinformatics → **analysis** with a Bioconductor base image
  (`zzcollab docker --base-image bioconductor/bioconductor_docker`)
- Geospatial → **analysis** with a geospatial base image
  (`zzcollab docker --base-image rocker/geospatial`)
- Interactive apps → the rocker/shiny base image
  (`zzcollab docker --base-image rocker/shiny`)
- Manuscript plus R package → **analysis** with the rocker/verse base
  image (`zzcollab docker --base-image rocker/verse`)

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
- Optional: analysis plus the rocker/shiny base image (if dashboards);
  ML packages added via renv
- Testing: minimal

**Manuscript Paradigm**:

- Required: analysis with the rocker/verse base image
  (`zzcollab docker --base-image rocker/verse`)
- Optional: analysis (if reproducing analysis)
- Testing: minimal

**Package Paradigm**:

- Required: minimal
- Optional: analysis (if vignettes use data analysis)
- Testing: minimal

## Profile Maintenance

### Updating Profile Definitions

The three built-in profiles are defined in
`templates/bundles.yaml`. Maintainers edit that file to adjust the
base image, system-library bundle, or R-package bundle of a profile:

```bash
# Edit the profile bundles
vim templates/bundles.yaml

# Confirm the file parses as valid YAML
zzcollab config validate

# Commit to the repository
git add templates/bundles.yaml
git commit -m "Update profile definitions"
```

After pulling updated definitions, collaborators rebuild the image:

```bash
git pull
make docker-build
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

### Specialized Environments

1. Start from the closest built-in profile, then supply a base image
   with `--base-image` only when necessary
2. Document the base image choice and package selections in the
   project
3. Capture every added package with `renv::snapshot()` so the
   environment remains reproducible
4. Commit the updated `renv.lock` alongside the Dockerfile

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
