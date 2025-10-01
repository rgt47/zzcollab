# Reproducible computational environment for {{PROJECT_NAME}}
# Based on Rocker Project: https://rocker-project.org/

FROM rocker/verse:4.4.0

# Set working directory
WORKDIR /project

# Install system dependencies (if needed)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy renv files for package management
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# Restore R packages using renv
RUN R -e "renv::restore()"

# Copy project files
COPY . /project

# Default command: start R
CMD ["R"]
