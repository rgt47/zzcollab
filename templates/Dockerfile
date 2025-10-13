ARG BASE_IMAGE=rocker/r-ver
ARG R_VERSION=latest
FROM ${BASE_IMAGE}:${R_VERSION}

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
# Note: pandoc removed (install manually if needed for PDF output)

# Install Node.js (required for coc.nvim and other vim plugins)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# Install Claude CLI (Anthropic's AI assistant)
RUN npm install -g @anthropic-ai/claude

# Note: TinyTeX not installed by default
# For PDF output, install manually or use publishing profile:
#   renv::install("tinytex")
#   tinytex::install_tinytex()

# Create non-root user with zsh as default shell (skip if using custom
# base image)
ARG USERNAME=analyst
RUN if [ "${BASE_IMAGE}" = "rocker/r-ver" ]; then \
        useradd --create-home --shell /bin/zsh ${USERNAME}; \
    fi

# Set password for analyst user (required for RStudio Server authentication)
# Note: rocker/rstudio already has analyst user, just needs password set
RUN echo "${USERNAME}:${USERNAME}" | chpasswd

# Install essential R packages (skip if using custom base image that
# already has them)
RUN if [ "${BASE_IMAGE}" = "rocker/r-ver" ]; then \
        R -e "install.packages(c('renv', 'remotes'), \
             repos = c(CRAN = 'https://cloud.r-project.org'))"; \
    fi

# Give analyst user write permission to R library directory (skip if
# using custom base image)
RUN if [ "${BASE_IMAGE}" = "rocker/r-ver" ]; then \
        chown -R ${USERNAME}:${USERNAME} /usr/local/lib/R/site-library; \
    fi

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
     .editorconfig* .ctags* .ackrc* .ripgreprc* .zshrc* /home/${USERNAME}/

# Install zsh plugins
RUN mkdir -p /home/${USERNAME}/.zsh && \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
     /home/${USERNAME}/.zsh/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
     /home/${USERNAME}/.zsh/zsh-syntax-highlighting

# Install vim-plug
RUN curl -fLo /home/${USERNAME}/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Install vim plugins (suppress interactive mode)
RUN vim +PlugInstall +qall || true

# Copy rest of project
COPY --chown=${USERNAME}:${USERNAME} . .

# Install the research compendium as a package (analyst has write
# permissions)
# Use standard R installation approach that works with any R setup
RUN R -e "install.packages('.', repos = NULL, type = 'source', \
           dependencies = TRUE)"

# Set default shell and working directory
WORKDIR /home/${USERNAME}/project
CMD ["/bin/zsh"]