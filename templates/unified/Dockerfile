# Reproducible computational environment for {{PROJECT_NAME}}
# Based on Rocker Project: https://rocker-project.org/

FROM rocker/verse:4.4.0

# Set environment variables for reproducibility
# Locale settings affect sorting, number formatting, and string operations
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
# Timezone for consistent date/time operations
ENV TZ=UTC
# Single-threaded operations for reproducible parallel processing
# (Adjust OMP_NUM_THREADS if intentionally using parallelization)
ENV OMP_NUM_THREADS=1

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
