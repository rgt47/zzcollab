# syntax=docker/dockerfile:1.4
#======================================================================
# ZZCOLLAB Ubuntu Standard Publishing Profile
#======================================================================
# Profile: ubuntu_standard_publishing (~2.5GB)
# Purpose: Document publishing with support for .Rmd, .Rnw, and .qmd files
# Base: rocker/verse (R + tidyverse + LaTeX + RStudio Server)
# System Tools: Quarto CLI (explicit version), pandoc, texlive-full (LaTeX)
# R Packages: tidyverse, quarto, bookdown, blogdown, distill, rmarkdown,
#           knitr, flexdashboard, xaringan, renv, devtools (binaries from r2u)
#
# Supported File Formats:
#   .R   - R scripts (any profile)
#   .Rmd - R Markdown documents (any profile with renv)
#   .Rnw - R noweb (Sweave) documents - requires LaTeX (this profile)
#   .qmd - Quarto markdown documents - requires Quarto CLI (this profile)
#
# Design Principle:
#   All system dependencies are version-controlled in the Dockerfile.
#   Users do NOT install system tools at runtime. If additional tools
#   are needed, modify this Dockerfile and rebuild.
#
# Build: DOCKER_BUILDKIT=1 docker build \
#          -f Dockerfile.ubuntu_standard_publishing \
#          -t myteam/project:ubuntu-standard-publishing .
# Note: AMD64 only - ARM64 not natively supported by rocker/verse
#======================================================================

ARG R_VERSION=latest
ARG USERNAME=analyst
ARG TEAM_NAME=zzcollab
ARG PROJECT_NAME=project
ARG TARGETPLATFORM

# Force AMD64 platform for rocker/verse (ARM64 not natively supported)
FROM --platform=linux/amd64 rocker/verse:${R_VERSION}

ARG USERNAME=analyst
ARG TEAM_NAME=zzcollab
ARG PROJECT_NAME=project
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETPLATFORM

# Reproducibility-critical environment variables (Pillar 1)
# ZZCOLLAB_CONTAINER enables renv workflow in .Rprofile
# RENV_CONFIG_REPOS_OVERRIDE forces renv to use Posit PM binaries (ignores lockfile repos)
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    OMP_NUM_THREADS=1 \
    RENV_PATHS_CACHE=/home/rstudio/.cache/R/renv \
    RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/latest" \
    ZZCOLLAB_CONTAINER=true

# Platform note (verse is AMD64 only, using emulation on ARM64)
RUN if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        echo "NOTE: rocker/verse does not support ARM64 natively" >&2; \
        echo "Running AMD64 image via emulation (slower)" >&2; \
    fi

# Install runtime dependencies (pinned to Ubuntu Noble 24.04)
# Note: Quarto CLI is explicitly installed here to ensure reproducibility
# rocker/verse may include Quarto, but we install explicitly for clarity
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libfontconfig1=2.15.0-1.1ubuntu2 \
        libfreetype6=2.13.2+dfsg-1build3 \
        libpng16-16t64=1.6.43-5build1 \
        libjpeg8=8c-2ubuntu11 \
        libicu74 \
        pandoc \
        curl \
        wget

# Install Quarto CLI explicitly for .qmd document support
# Quarto enables reproducible documents mixing R, Markdown, LaTeX, and Python
# Pinned version for reproducibility (update as new versions are released)
RUN --mount=type=cache,target=/tmp/quarto,sharing=locked \
    set -ex && \
    QUARTO_VERSION="1.6.33" && \
    wget -q "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
        -O /tmp/quarto/quarto.deb && \
    dpkg -i /tmp/quarto/quarto.deb && \
    quarto --version

# Configure R to use Posit Package Manager (pre-compiled Ubuntu binaries)
RUN echo "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/noble/latest'))" \
        >> /usr/local/lib/R/etc/Rprofile.site

# Install base publishing packages from CRAN
# Note: These are "base packages" included in the profile for convenience.
# Project-specific packages are managed via renv and renv.lock.
RUN --mount=type=cache,target=/tmp/R-cache/${R_VERSION} \
    R -e "install.packages(c('renv', 'quarto', \
        'bookdown', 'blogdown', 'distill', 'rmarkdown', 'knitr', \
        'flexdashboard', 'xaringan'))"

# Set up renv cache directory (rocker/verse runs as root, /init handles user switching)
# The default user 'rstudio' is created by rocker/verse base image
RUN mkdir -p /home/rstudio/.cache/R/renv && \
    chown -R rstudio:rstudio /home/rstudio/.cache

# Set working directory (will be owned by mapped user at runtime)
WORKDIR /home/rstudio/project

# Health check: Verify R is functional
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=2 \
    CMD R --quiet --slave -e "quit(status = 0)" || exit 1

# Note: Project files mounted at runtime via -v $(pwd):/home/rstudio/project
# This keeps image reusable across projects. Run renv::restore() in first session.
# .Rprofile is accessed from the mounted volume for auto-snapshot functionality.
# For RStudio Server: Use CMD ["/init"] or run with 'docker run -p 8787:8787 ... /init'
# Default RStudio credentials: rstudio/rstudio (set by rocker/verse base image)

CMD ["R", "--quiet"]
