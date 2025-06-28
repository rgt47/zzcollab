FROM rocker/verse:${R_VERSION}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    ssh \
    curl \
    wget \
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
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with zsh as default shell
ARG USERNAME=analyst
RUN useradd --create-home --shell /bin/zsh ${USERNAME}

# Install renv
RUN R -e "install.packages('renv', repos = c(CRAN = 'https://cloud.r-project.org'))"

# Set working directory
WORKDIR /home/${USERNAME}/project

# Copy project files first (for better Docker layer caching)
COPY --chown=${USERNAME}:${USERNAME} DESCRIPTION .
COPY --chown=${USERNAME}:${USERNAME} renv.lock* ./
COPY --chown=${USERNAME}:${USERNAME} .Rprofile* ./
COPY --chown=${USERNAME}:${USERNAME} setup_renv.R* ./

# Configure renv library path
ENV RENV_PATHS_LIBRARY renv/library

# Switch to non-root user for R package installation
USER ${USERNAME}

# Restore R packages from lockfile (if exists)
RUN R -e "if (file.exists('renv.lock')) renv::restore() else cat('No renv.lock found, skipping restore\\n')"

# Copy dotfiles (consolidated with wildcards)
COPY --chown=${USERNAME}:${USERNAME} .vimrc* .tmux.conf* .gitconfig* .inputrc* .bashrc* .profile* .aliases* .functions* .exports* .editorconfig* .ctags* .ackrc* .ripgreprc* /home/${USERNAME}/
COPY --chown=${USERNAME}:${USERNAME} .zshrc_docker /home/${USERNAME}/.zshrc

# Install zsh plugins
RUN mkdir -p /home/${USERNAME}/.zsh && \
    git clone https://github.com/zsh-users/zsh-autosuggestions /home/${USERNAME}/.zsh/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting /home/${USERNAME}/.zsh/zsh-syntax-highlighting

# Install vim-plug
RUN curl -fLo /home/${USERNAME}/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Install vim plugins (suppress interactive mode)
RUN vim +PlugInstall +qall || true

# Copy rest of project
COPY --chown=${USERNAME}:${USERNAME} . .

# Install the research compendium as a package
RUN R -e "devtools::install('.', dependencies = TRUE)"

# Set default shell and working directory
WORKDIR /home/${USERNAME}/project
CMD ["/bin/zsh"]