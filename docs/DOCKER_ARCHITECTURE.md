# Docker Image Architecture and Custom Images

This guide covers Docker architecture considerations for ZZCOLLAB, including platform compatibility, custom image building, and ARM64 support.

## Architecture Support Matrix

### ARM64 Compatibility

**Problem**: rocker/verse only supports AMD64 architecture, causing build failures on Apple Silicon (ARM64).

**Architecture Support Matrix**:
```
ARM64 Compatible:
- rocker/r-ver     (Both AMD64 and ARM64)
- rocker/rstudio   (Both AMD64 and ARM64)

AMD64 Only:
- rocker/verse     (Publishing workflow with LaTeX)
- rocker/tidyverse (AMD64 only)
- rocker/geospatial (AMD64 only)
- rocker/shiny     (AMD64 only)
```

## Solutions for ARM64 Users

### 1. Use Compatible Base Images

```bash
# Edit Dockerfile and change base image:
FROM rocker/rstudio:latest    # ARM64 compatible
# Avoid: FROM rocker/verse:latest (AMD64 only)

make docker-build
```

### 2. Build Custom ARM64 Verse Equivalent

Create a custom Dockerfile that combines verse functionality with ARM64 support:

```dockerfile
# Dockerfile.verse-arm64 - ARM64 compatible verse + shiny image
FROM rocker/tidyverse:latest

# Install system dependencies (from official rocker install_verse.sh)
RUN apt-get update && apt-get install -y \
    cmake \
    default-jdk \
    fonts-roboto \
    ghostscript \
    hugo \
    less \
    libglpk-dev \
    libgmp3-dev \
    libfribidi-dev \
    libharfbuzz-dev \
    libmagick++-dev \
    qpdf \
    texinfo \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install R packages (official verse packages)
RUN install2.r --error --skipinstalled --ncpus -1 \
    blogdown \
    bookdown \
    distill \
    rticles \
    rmdshower \
    rJava \
    xaringan \
    redland \
    tinytex \
    && rm -rf /tmp/downloaded_packages

# Add Shiny support (not in official verse)
RUN install2.r --error --skipinstalled --ncpus -1 \
    shiny \
    shinydashboard \
    DT \
    && rm -rf /tmp/downloaded_packages

# Install TinyTeX for LaTeX support
RUN R -e "tinytex::install_tinytex()"
```

### 3. Build and Deploy Custom Image

```bash
# Build ARM64 compatible verse+shiny image
docker build -f Dockerfile.verse-arm64 -t rgt47/verse-arm64:latest .

# Test locally
docker run --rm -p 8787:8787 rgt47/verse-arm64:latest

# Push to Docker Hub (free for public images)
docker login
docker push rgt47/verse-arm64:latest
```

### 4. Use in ZZCOLLAB Workflows

```bash
# Modify team Dockerfile to use custom image
# Edit Dockerfile and change FROM line:
FROM rgt47/verse-arm64:latest

# Build and use
make docker-build
make docker-zsh
```

## Key Insights

### Docker Hub Storage

- **Public Docker Hub storage is free** - no cost for hosting custom ARM64 images
- Public images can be pulled by anyone without authentication
- Private images require Docker Hub subscription

### Rocker Image Ecosystem

- **rocker/verse** = rocker/tidyverse + publishing tools (bookdown, blogdown, LaTeX)
- **rocker/rstudio does NOT include Shiny** by default
- **Custom images can combine** verse + shiny functionality for complete publishing workflow

### Image Composition

**Base rocker images hierarchy**:
```
rocker/r-ver          # R + system dependencies (smallest)
  ↓
rocker/rstudio        # + RStudio Server
  ↓
rocker/tidyverse      # + tidyverse packages
  ↓
rocker/verse          # + publishing tools (LaTeX, bookdown, blogdown)
```

**Specialized rocker images**:
```
rocker/shiny          # Shiny Server (separate branch)
rocker/geospatial     # sf, terra, leaflet mapping tools
```

## Multi-Architecture Image Building

### Using Docker Buildx

For teams supporting both ARM64 and AMD64:

```bash
# Create buildx builder
docker buildx create --name multiarch --use

# Build for both architectures
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myteam/projectcore:latest \
  --push \
  .
```

### Platform-Specific Builds

```bash
# Build for specific platform
docker build --platform linux/amd64 -t myteam/projectcore:amd64 .
docker build --platform linux/arm64 -t myteam/projectcore:arm64 .

# Tag and push
docker push myteam/projectcore:amd64
docker push myteam/projectcore:arm64

# Create manifest (allows automatic selection)
docker manifest create myteam/projectcore:latest \
  myteam/projectcore:amd64 \
  myteam/projectcore:arm64

docker manifest push myteam/projectcore:latest
```

## Custom Image Best Practices

### Layer Caching

Optimize Dockerfile layer order for efficient caching:

```dockerfile
# 1. Base image (changes rarely)
FROM rocker/rstudio:latest

# 2. System dependencies (change occasionally)
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    libproj-dev \
    && rm -rf /var/lib/apt/lists/*

# 3. R packages from CRAN (change occasionally)
RUN install2.r --error --skipinstalled \
    tidyverse \
    tidymodels \
    && rm -rf /tmp/downloaded_packages

# 4. Project-specific setup (changes frequently)
COPY renv.lock /home/rstudio/project/
WORKDIR /home/rstudio/project
RUN R -e "renv::restore()"
```

### Image Size Optimization

```dockerfile
# Combine RUN commands to reduce layers
RUN apt-get update && apt-get install -y \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*  # Clean up in same layer

# Use --no-install-recommends for apt-get
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Remove build dependencies after use
RUN apt-get update && apt-get install -y \
    build-essential \
    && R -e "install.packages('Rcpp')" \
    && apt-get remove -y build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
```

### Security Considerations

```dockerfile
# Use specific image tags, not :latest
FROM rocker/rstudio:4.4.0

# Create non-root user for security
RUN useradd -m -s /bin/bash analyst
USER analyst

# Set working directory with proper permissions
WORKDIR /home/analyst/project
```

## Troubleshooting

### Platform Mismatch Errors

```bash
# Error: exec format error
# Solution: Build for correct platform
docker build --platform linux/amd64 .

# Or use emulation (slower)
docker run --platform linux/amd64 rocker/verse:latest
```

### Large Image Sizes

```bash
# Check image size
docker images | grep projectcore

# Analyze layers
docker history myteam/projectcore:latest

# Solutions:
# 1. Combine RUN commands
# 2. Clean package manager caches
# 3. Use multi-stage builds
# 4. Remove build dependencies after use
```

### Build Cache Issues

```bash
# Clear build cache
docker builder prune

# Build without cache
docker build --no-cache .

# Use BuildKit for better caching
export DOCKER_BUILDKIT=1
docker build .
```

## Related Documentation

- **Build Modes**: [Build Modes Guide](BUILD_MODES.md)
- **Development Commands**: [Development Guide](DEVELOPMENT.md)
- **Docker Profiles**: [Variants Guide](VARIANTS.md)
- **Configuration**: [Configuration Guide](CONFIGURATION.md)
