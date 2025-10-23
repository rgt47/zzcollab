ARG R_VERSION=latest
FROM rgt47/r-pluspackages:latest

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
RUN mkdir -p /usr/local/share/fonts/nerd-fonts && \
    cd /usr/local/share/fonts/nerd-fonts && \
    # JetBrains Mono Nerd Font
    curl -fLo "JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip && \
    unzip -q JetBrainsMono.zip && rm JetBrainsMono.zip && \
    # Fira Code Nerd Font
    curl -fLo "FiraCode.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip && \
    unzip -q FiraCode.zip && rm FiraCode.zip && \
    # Hack Nerd Font
    curl -fLo "Hack.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip && \
    unzip -q Hack.zip && rm Hack.zip && \
    # DejaVu Sans Mono Nerd Font
    curl -fLo "DejaVuSansMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/DejaVuSansMono.zip && \
    unzip -q DejaVuSansMono.zip && rm DejaVuSansMono.zip && \
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

# Install zsh plugins (skip if already exist)
RUN mkdir -p /home/${USERNAME}/.zsh && \
    (git clone https://github.com/zsh-users/zsh-autosuggestions \
     /home/${USERNAME}/.zsh/zsh-autosuggestions || \
     echo "zsh-autosuggestions already exists") && \
    (git clone https://github.com/zsh-users/zsh-syntax-highlighting \
     /home/${USERNAME}/.zsh/zsh-syntax-highlighting || \
     echo "zsh-syntax-highlighting already exists")

# Install vim-plug
RUN curl -fLo /home/${USERNAME}/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

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