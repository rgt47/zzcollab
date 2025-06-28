FROM rocker/r-ver:${R_VERSION}

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
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# Install TinyTeX
RUN R -e "install.packages('tinytex')" && \
    R -e "tinytex::install_tinytex()" && \
    /root/.TinyTeX/bin/*/tlmgr path add

# Create non-root user with zsh as default shell
ARG USERNAME=analyst
RUN useradd --create-home --shell /bin/zsh ${USERNAME}

# Install essential R packages (remotes is much faster than devtools)
RUN R -e "install.packages(c('renv', 'remotes'), repos = c(CRAN = 'https://cloud.r-project.org'))"

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

# Install the research compendium as a package (analyst has write permissions)
RUN R -e "remotes::install_local('.', dependencies = TRUE)"

# Set default shell and working directory
WORKDIR /home/${USERNAME}/project
CMD ["/bin/zsh"]