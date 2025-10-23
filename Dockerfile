ARG R_VERSION=latest
FROM rgt47/r-pluspackages:latest

# NOTE: R_VERSION ARG defined above for future flexibility
# Currently hardcoded to rgt47/r-pluspackages:latest for stability
# To use ARG: FROM rgt47/r-pluspackages:${R_VERSION}

# Ensure we're running as root for system package installation
USER root

# Install system dependencies
# EFFICIENCY: --no-install-recommends reduces image size by ~100-200MB
#   by skipping suggested packages that aren't strictly required
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ssh \
    curl \
    wget \
    unzip \
    vim \
    tmux \
    zsh \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    man-db \
    pandoc \
    # X11 terminal emulators (work with XQuartz on macOS)
    xfce4-terminal \
    terminator \
    xterm \
    # Popular monospaced fonts for terminal and coding
    fonts-jetbrains-mono \
    fonts-firacode \
    fonts-hack \
    fonts-dejavu \
    fonts-liberation-mono \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for coc.nvim and other vim plugins)
# EFFICIENCY: Clean up apt lists to reduce layer size (~50MB savings)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Nerd Fonts (required for vim-airline and other plugins with icons)
# SAFETY: Pinned to v3.3.0 release (latest stable as of 2025-10-23)
#   - Using 'latest' in URL is security risk (no version control)
#   - Specific version ensures reproducible builds
#   - Update version when you want newer fonts
# EFFICIENCY: Only extract .ttf files, exclude unnecessary files (Windows, OTF variants)
#   - Saves ~100MB per font by excluding .otf and extra metadata
RUN NERD_FONT_VERSION=v3.3.0 && \
    mkdir -p /usr/local/share/fonts/nerd-fonts && \
    cd /usr/local/share/fonts/nerd-fonts && \
    # JetBrains Mono Nerd Font
    curl -fLo "JetBrainsMono.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip" && \
    unzip -q -j JetBrainsMono.zip "*.ttf" && rm JetBrainsMono.zip && \
    # Fira Code Nerd Font
    curl -fLo "FiraCode.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/FiraCode.zip" && \
    unzip -q -j FiraCode.zip "*.ttf" && rm FiraCode.zip && \
    # Hack Nerd Font
    curl -fLo "Hack.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/Hack.zip" && \
    unzip -q -j Hack.zip "*.ttf" && rm Hack.zip && \
    # DejaVu Sans Mono Nerd Font
    curl -fLo "DejaVuSansMono.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/DejaVuSansMono.zip" && \
    unzip -q -j DejaVuSansMono.zip "*.ttf" && rm DejaVuSansMono.zip && \
    # Update font cache
    fc-cache -fv

# Install Claude CLI (Anthropic's AI assistant)
RUN npm install -g @anthropic-ai/claude

# Install TinyTeX
RUN R -e "install.packages('tinytex')" && \
    R -e "tinytex::install_tinytex()" && \
    /root/.TinyTeX/bin/*/tlmgr path add

# Create non-root user with zsh as default shell
ARG USERNAME=analyst
RUN useradd --create-home --shell /bin/zsh ${USERNAME}

# Configure Posit Public Package Manager (RSPM) for binary R packages
# EFFICIENCY: RSPM provides pre-compiled binaries for Ubuntu, avoiding compilation
#   - 10-50x faster installation than building from source
#   - Critical for renv::restore() to use binaries instead of compiling
#
# REPRODUCIBILITY: Pinned to specific snapshot date (2025-10-23)
#   - Using 'latest' is a moving target that changes daily/weekly
#   - Snapshot date ensures builds are reproducible months/years later
#   - Update snapshot date when you want newer package versions
#
# SAFETY: RSPM URL must match the Ubuntu version of the base image
#   - This Dockerfile uses rgt47/r-pluspackages:latest (check its OS version)
#   - If base image uses Ubuntu 22.04 (jammy) → jammy/2025-10-23 ✓
#   - If base image uses Ubuntu 20.04 (focal) → focal/2025-10-23
#   - Verify OS with: docker run --rm rgt47/r-pluspackages:latest cat /etc/os-release
RUN echo "options(repos = c(RSPM = 'https://packagemanager.posit.co/cran/__linux__/jammy/2025-10-23', CRAN = 'https://cloud.r-project.org'))" >> /usr/local/lib/R/etc/Rprofile.site

# Install essential R packages (remotes is much faster than devtools)
RUN R -e "install.packages(c('renv', 'remotes'), \
      repos = c(CRAN = 'https://cloud.r-project.org'))"

# Give analyst user write permission to R library directory
RUN chown -R ${USERNAME}:${USERNAME} /usr/local/lib/R/site-library

# Set working directory and ensure user owns it
WORKDIR /home/${USERNAME}/project
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/project

# Copy project files first (for better Docker layer caching)
COPY --chown=${USERNAME}:${USERNAME} DESCRIPTION .
COPY --chown=${USERNAME}:${USERNAME} renv.lock* ./
COPY --chown=${USERNAME}:${USERNAME} .Rprofile* ./
COPY --chown=${USERNAME}:${USERNAME} setup_renv.R* ./

# Switch to non-root user for R package installation
USER ${USERNAME}

# Copy dotfiles (consolidated with wildcards)
COPY --chown=${USERNAME}:${USERNAME} .vimrc* .tmux.conf* .gitconfig* \
     .inputrc* .bashrc* .profile* .aliases* .functions* .exports* \
     .editorconfig* .ctags* .ackrc* .ripgreprc* /home/${USERNAME}/
COPY --chown=${USERNAME}:${USERNAME} .zshrc_docker /home/${USERNAME}/.zshrc

# Install zsh plugins
# EFFICIENCY: Shallow clone (--depth 1) reduces download size by ~90%
#   - Only fetches latest commit instead of full git history
#   - zsh-autosuggestions: ~300KB vs ~3MB (full history)
#   - zsh-syntax-highlighting: ~500KB vs ~5MB (full history)
# SAFETY FIX: Pinned to specific release tags (as of 2025-10-23)
#   - Using HEAD/master can change unexpectedly
#   - Specific tags ensure reproducible builds
#   - Update tags when you want newer plugin features
RUN ZSH_AUTOSUGGESTIONS_VERSION=v0.7.1 && \
    ZSH_SYNTAX_VERSION=0.8.0 && \
    mkdir -p /home/${USERNAME}/.zsh && \
    (git clone --depth 1 --branch ${ZSH_AUTOSUGGESTIONS_VERSION} \
     https://github.com/zsh-users/zsh-autosuggestions \
     /home/${USERNAME}/.zsh/zsh-autosuggestions || \
     echo "zsh-autosuggestions already exists") && \
    (git clone --depth 1 --branch ${ZSH_SYNTAX_VERSION} \
     https://github.com/zsh-users/zsh-syntax-highlighting \
     /home/${USERNAME}/.zsh/zsh-syntax-highlighting || \
     echo "zsh-syntax-highlighting already exists")

# Install vim-plug
# SAFETY FIX: Pinned to v0.14.0 release (latest stable as of 2025-10-23)
#   - Using 'master' branch is security risk (can change unexpectedly)
#   - Specific version ensures reproducible builds
#   - Update version when you want newer vim-plug features
RUN VIM_PLUG_VERSION=0.14.0 && \
    curl -fLo /home/${USERNAME}/.vim/autoload/plug.vim --create-dirs \
    "https://raw.githubusercontent.com/junegunn/vim-plug/${VIM_PLUG_VERSION}/plug.vim"

# Install vim plugins (suppress interactive mode)
RUN vim +PlugInstall +qall || true

# Copy rest of project
COPY --chown=${USERNAME}:${USERNAME} . .

# Restore renv dependencies before installing the package
RUN R -e "renv::restore()"

# Install the research compendium as a package (analyst has write
# permissions)
RUN R -e "remotes::install_local('.', dependencies = TRUE)"

# Set default shell and working directory
WORKDIR /home/${USERNAME}/project
CMD ["/bin/zsh"]