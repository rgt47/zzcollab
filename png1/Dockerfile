ARG BASE_IMAGE=rocker/r-ver
ARG R_VERSION=latest
FROM rocker/r-ver:latest

# Build arguments for package selection
# Profile system: LIBS_BUNDLE and PKGS_BUNDLE are set by --profile-name
ARG LIBS_BUNDLE=minimal
ARG PKGS_BUNDLE=minimal
ARG TEAM_NAME=rgt47
ARG PROJECT_NAME=r-project
ARG ADDITIONAL_PACKAGES=""
ARG USERNAME=analyst

# Install system dependencies (common to all profiles)
#
# NOTE: rocker/r-ver base image already includes:
#   - Runtime libraries: libcurl4, zlib1g, libblas, liblapack
#   - Build tools: g++, gfortran, make
#   - But REMOVES development headers after building R
#
# This layer adds:
#   - Development headers (removed by rocker after R build)
#   - ZZCOLLAB framework tools (vim, tmux, zsh, etc.)
#   - Graphics libraries for R plotting
#
# Profile-specific deps (git, curl, wget, pandoc, etc.) are handled
# by bundle-specific installation from bundles.yaml below.
#
RUN apt-get update && \
    apt-get install -y \
    # Build tools (gcc, libc6-dev not in rocker)
    build-essential \
    # Development headers (removed by rocker after R build)
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    # Graphics libraries for R plotting (ggplot2, base graphics)
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    # Git integration for R packages
    libgit2-dev \
    # ZZCOLLAB framework tools
    vim \
    zsh \
    ssh \
    tree \
    ripgrep \
    eza \
    man-db \
    kitty \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install bundle-specific system dependencies
# Command generated from bundles.yaml (single source of truth)
# Bundle: minimal
RUN apt-get update && apt-get install -y git curl wget  && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for coc.nvim and other vim plugins)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# Install TinyTeX only for publishing profiles
# - Minimal, analysis, modeling profiles: NO (users can add manually)
# - Publishing profile: YES (requires PDF output)
# - Base images with LaTeX (verse, tidyverse): SKIP (already included)
RUN if [ "minimal" = "publishing" ] || [ "minimal" = "publishing" ]; then \
        if ! echo "rocker/r-ver" | grep -E "(verse|tidyverse)" >/dev/null; then \
            R -e "install.packages('tinytex')" && \
            R -e "tinytex::install_tinytex()" && \
            /root/.TinyTeX/bin/*/tlmgr path add; \
        fi; \
    fi

# Add metadata labels
LABEL maintainer="${TEAM_NAME}"
LABEL project="${PROJECT_NAME}"
LABEL libs.bundle="minimal"
LABEL pkgs.bundle="minimal"
LABEL org.opencontainers.image.title="ZZCOLLAB Docker Image"
LABEL org.opencontainers.image.description="R environment with \
      minimal libraries and minimal packages"
LABEL org.opencontainers.image.vendor="ZZCOLLAB"

# Create non-root user with zsh as default shell
# Always create the user since we reference it throughout the Dockerfile
RUN useradd --create-home --shell /bin/zsh analyst || \
    echo "User analyst already exists"

# Set password for analyst user (required for RStudio Server authentication and sudo)
RUN echo "analyst:analyst" | chpasswd

# Add analyst to sudo group for administrative tasks
RUN usermod -aG sudo analyst

# Install R packages based on selected profile
# Command generated from bundles.yaml (single source of truth)
# Bundle: minimal
RUN R -e "install.packages(c('renv, devtools, usethis, testthat, roxygen2'), repos = c(CRAN = 'https://cloud.r-project.org'))"

# Give user write permission to R library directory
RUN chown -R analyst:analyst /usr/local/lib/R/site-library

# Set working directory and ensure user owns it
WORKDIR /home/analyst/project
RUN chown -R analyst:analyst /home/analyst/project

# Copy project files first (for better Docker layer caching)
COPY --chown=analyst:analyst DESCRIPTION .
COPY --chown=analyst:analyst renv.lock* ./
COPY --chown=analyst:analyst .Rprofile* ./
COPY --chown=analyst:analyst setup_renv.R* ./

# Switch to non-root user for R package installation
USER analyst

# Copy dotfiles (consolidated with wildcards)
# Note: .zshrc copied directly from dotfiles directory (no filtering)
COPY --chown=analyst:analyst .vimrc* .gitconfig* \
     .zshrc* .inputrc* .bashrc* .profile* .aliases* .functions* .exports* \
     .editorconfig* .ctags* .ackrc* .ripgreprc* /home/analyst/

# Install zsh plugins
RUN mkdir -p /home/analyst/.zsh && \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
     /home/analyst/.zsh/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
     /home/analyst/.zsh/zsh-syntax-highlighting

# Install vim-plug
RUN curl -fLo /home/analyst/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Install vim plugins (suppress interactive mode)
RUN vim +PlugInstall +qall || true

# Copy rest of project
COPY --chown=analyst:analyst . .

# Install the research compendium as a package (analyst has write
# permissions)
# Use standard R installation approach that works with any R setup
RUN R -e "install.packages('.', repos = NULL, type = 'source', \
           dependencies = TRUE)"

# Set default shell and working directory
WORKDIR /home/analyst/project
CMD ["/bin/zsh"]