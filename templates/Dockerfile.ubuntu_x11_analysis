# syntax=docker/dockerfile:1.4
#======================================================================
# ZZCOLLAB Ubuntu X11 Analysis Profile
#======================================================================
# Profile: ubuntu_x11_analysis (~2.0GB)
# Purpose: Data analysis with tidyverse ecosystem and X11 support
# Base: rocker/tidyverse (R + tidyverse + RStudio Server)
# Packages: tidyverse, renv, devtools, here, janitor, scales, patchwork,
#           gt, DT, skimr, DataExplorer (binaries from r2u)
#
# Build: DOCKER_BUILDKIT=1 docker build \
#          -f Dockerfile.ubuntu_x11_analysis \
#          -t myteam/project:ubuntu-x11-analysis .
# Run: Requires XQuartz (macOS) or X11 (Linux). Use 'docker run -e DISPLAY'
#======================================================================

ARG R_VERSION=latest
ARG RENV_VERSION=1.1.5
ARG USERNAME=analyst
ARG TEAM_NAME=zzcollab
ARG PROJECT_NAME=project

FROM rocker/tidyverse:${R_VERSION}

ARG RENV_VERSION=1.1.5
ARG USERNAME=analyst
ARG TEAM_NAME=zzcollab
ARG PROJECT_NAME=project
ARG DEBIAN_FRONTEND=noninteractive

# Reproducibility-critical environment variables (Pillar 1)
# ZZCOLLAB_CONTAINER enables renv workflow in .Rprofile
# RENV_CONFIG_REPOS_OVERRIDE forces renv to use Posit PM binaries (ignores lockfile repos)
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    OMP_NUM_THREADS=1 \
    RENV_PATHS_CACHE=/home/analyst/.cache/R/renv \
    RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/latest" \
    ZZCOLLAB_CONTAINER=true

# Install runtime dependencies for X11 (pinned to Ubuntu Noble 24.04)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        xauth \
        libx11-6 \
        libxt6 \
        libcairo2 \
        libfontconfig1=2.15.0-1.1ubuntu2 \
        libfreetype6=2.13.2+dfsg-1build3 \
        libpng16-16t64=1.6.43-5build1 \
        libjpeg8=8c-2ubuntu11 \
        libicu74 \
        pandoc \
        curl

# Configure R to use Posit Package Manager (pre-compiled Ubuntu binaries)
RUN echo "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/noble/latest'))" \
        >> /usr/local/lib/R/etc/Rprofile.site

# Install base analysis packages from CRAN
# Note: These are "base packages" included in the profile for convenience.
# Project-specific packages are managed via renv and renv.lock.
RUN --mount=type=cache,target=/tmp/R-cache/${R_VERSION} \
    R -e "install.packages(c('renv', 'here', 'janitor', \
        'scales', 'patchwork', 'gt', 'DT', 'skimr', 'DataExplorer'))"

# Create non-root user and set up environment
RUN useradd --create-home --shell /bin/bash ${USERNAME} && \
    chown -R ${USERNAME}:${USERNAME} /usr/local/lib/R/site-library && \
    mkdir -p /home/${USERNAME}/.cache/R/renv && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.cache

# Switch to non-root user
USER ${USERNAME}

# WORKDIR automatically creates directory with correct ownership
WORKDIR /home/${USERNAME}/project

# Health check: Verify R is functional
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=2 \
    CMD R --quiet --slave -e "quit(status = 0)" || exit 1

# Note: Project files mounted at runtime via -v $(pwd):/home/analyst/project
# This keeps image reusable across projects. Run renv::restore() in first session.
# .Rprofile is accessed from the mounted volume for auto-snapshot functionality.

CMD ["R", "--quiet"]
