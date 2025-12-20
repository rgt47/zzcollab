# syntax=docker/dockerfile:1.4
#=================================================================
# ZZCOLLAB Custom Profile Dockerfile (GENERATED)
#=================================================================
# This Dockerfile is GENERATED from user specifications
# DO NOT edit manually - regenerate with zzcollab command
#
# Generated: 2025-11-01 21:50:02 UTC
# Base image: rocker/r-ver:4.5.1
# System libraries: minimal
# R packages: minimal
#
# Build: DOCKER_BUILDKIT=1 docker build \
#          -t myteam/project:custom .
#=================================================================

ARG BASE_IMAGE=rocker/r-ver
ARG R_VERSION=4.5.1
ARG USERNAME=analyst
ARG TEAM_NAME=myteam
ARG PROJECT_NAME=project
ARG TARGETPLATFORM

#=================================================================
# STAGE 1: BUILDER
#=================================================================
FROM rocker/r-ver:4.5.1 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETPLATFORM

# Platform compatibility check
RUN if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        case "rocker/r-ver" in \
            *verse*|*geospatial*|*shiny*) \
                echo "WARNING: rocker/r-ver may have limited ARM64 support" >&2; \
                ;; \
        esac; \
    fi

# Install build dependencies with cache mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates && \
    # r2u repository for binary R packages
    wget -q -O- https://eddelbuettel.github.io/r2u/assets/\
dirk_eddelbuettel_key.asc | \
        tee -a /etc/apt/trusted.gpg.d/cranapt_key.asc && \
    echo "deb [arch=amd64,arm64] \
https://r2u.stat.illinois.edu/ubuntu noble main" > \
        /etc/apt/sources.list.d/cranapt.list && \
    apt-get update && \
    # Core build dependencies (always needed)
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        pkg-config \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libgit2-dev \
        libssh2-1-dev \
        libfontconfig1-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libfreetype6-dev \
        libpng-dev \
        libjpeg-dev

# Custom system dependencies (generated from bundles.yaml)
# Libraries: minimal
# No additional build dependencies for minimal profile

# Configure repositories: RSPM with binary packages
# Use a known good date (2024-10-26) to ensure packages are available
WORKDIR /build
COPY renv.lock* ./

RUN UBUNTU_CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME) && \
    echo "# RSPM snapshot date: 2024-10-26 (${UBUNTU_CODENAME})" \
        >> /usr/local/lib/R/etc/Rprofile.site && \
    echo "options(repos = c(" \
        "CRAN = 'https://packagemanager.posit.co/cran/__linux__/${UBUNTU_CODENAME}/2024-10-26'))" \
        >> /usr/local/lib/R/etc/Rprofile.site && \
    echo "options(HTTPUserAgent = sprintf('R/%s R (%s)', getRversion(), paste(getRversion(), R.version\$platform, R.version\$arch, R.version\$os)))" \
        >> /usr/local/lib/R/etc/Rprofile.site

# Install custom R packages (generated from bundles.yaml)
# Packages: minimal
RUN --mount=type=cache,target=/tmp/R-cache \
    R -e "install.packages(c('renv','devtools','usethis','testthat','roxygen2'))"

# Restore renv packages
COPY DESCRIPTION setup_renv.R* ./
RUN if [ -f renv.lock ]; then R -e "renv::restore()"; fi

#=================================================================
# STAGE 2: RUNTIME
#=================================================================
FROM rocker/r-ver:4.5.1

ARG USERNAME=analyst
ARG TEAM_NAME=myteam
ARG PROJECT_NAME=project
ARG DEBIAN_FRONTEND=noninteractive

# Copy R libraries and configuration from builder
COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library
COPY --from=builder /usr/local/lib/R/etc/Rprofile.site /usr/local/lib/R/etc/Rprofile.site

# Install runtime dependencies (NOT -dev versions)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Core runtime libraries
        libcurl4 \
        libssl3 \
        libxml2 \
        libgit2-1.7 \
        libssh2-1 \
        libfontconfig1 \
        libharfbuzz0b \
        libfribidi0 \
        libfreetype6 \
        libpng16-16 \
        libjpeg8 \
        # Development tools
        git \
        vim \
        zsh \
        tmux \
        curl \
        wget \
        sudo \
        procps

# Custom runtime libraries (generated from bundles.yaml)
# Libraries: minimal
# No additional runtime dependencies for minimal profile

# Node.js for vim plugins
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs

# Install external dependencies in parallel
RUN --mount=type=cache,target=/tmp/downloads \
    set -ex && \
    # ZSH plugins
    ZSH_AUTOSUGGESTIONS_VERSION=v0.7.1 && \
    ZSH_SYNTAX_VERSION=0.8.0 && \
    mkdir -p /tmp/.zsh && \
    git clone --depth 1 --branch ${ZSH_AUTOSUGGESTIONS_VERSION} \
        https://github.com/zsh-users/zsh-autosuggestions /tmp/.zsh/zsh-autosuggestions & \
    git clone --depth 1 --branch ${ZSH_SYNTAX_VERSION} \
        https://github.com/zsh-users/zsh-syntax-highlighting /tmp/.zsh/zsh-syntax-highlighting & \
    # vim-plug
    VIM_PLUG_VERSION=0.14.0 && \
    mkdir -p /tmp/.vim/autoload && \
    curl -fLo /tmp/.vim/autoload/plug.vim \
        https://raw.githubusercontent.com/junegunn/vim-plug/${VIM_PLUG_VERSION}/plug.vim & \
    wait

# Create user and set up environment
RUN useradd --create-home --shell /bin/zsh ${USERNAME} && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    mkdir -p /home/${USERNAME}/project && \
    mv /tmp/.zsh /home/${USERNAME}/.zsh && \
    mv /tmp/.vim /home/${USERNAME}/.vim && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} && \
    chown -R ${USERNAME}:${USERNAME} /usr/local/lib/R/site-library

# Set password using BuildKit secrets or auto-generate
RUN --mount=type=secret,id=password \
    if [ -f /run/secrets/password ]; then \
        echo "${USERNAME}:$(cat /run/secrets/password)" | chpasswd; \
    else \
        PASSWORD=$(openssl rand -base64 12) && \
        echo "${USERNAME}:${PASSWORD}" | chpasswd && \
        echo "=============================================" && \
        echo "Generated password: ${PASSWORD}" && \
        echo "User: ${USERNAME}" && \
        echo "Save this password!" && \
        echo "=============================================="; \
    fi

# Switch to user
USER ${USERNAME}
WORKDIR /home/${USERNAME}/project

# Copy project files
COPY --chown=${USERNAME}:${USERNAME} . .

# Install research compendium
RUN R -e "install.packages('.', repos = NULL, type = 'source', dependencies = TRUE)"

# Metadata
LABEL org.opencontainers.image.title="ZZCOLLAB Custom Environment" \
      org.opencontainers.image.description="Custom profile: minimal + minimal" \
      org.opencontainers.image.vendor="ZZCOLLAB" \
      org.opencontainers.image.authors="myteam" \
      org.opencontainers.image.source="https://github.com/myteam/project" \
      zzcollab.profile="custom" \
      zzcollab.base="rocker/r-ver:4.5.1" \
      zzcollab.libraries="minimal" \
      zzcollab.packages="minimal"

# Copy and configure ZZCOLLAB entrypoint for auto-snapshot on exit
COPY zzcollab-entrypoint.sh /usr/local/bin/zzcollab-entrypoint.sh
RUN chmod +x /usr/local/bin/zzcollab-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/zzcollab-entrypoint.sh"]
CMD ["/bin/zsh"]
