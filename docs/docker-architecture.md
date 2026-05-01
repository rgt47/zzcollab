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
make r
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

## Docker Manifest Cache and Platform Resolution

This section addresses a persistent issue that affects users on Apple Silicon
Macs when building Docker images with rocker base images. Understanding this
problem requires knowledge of several interconnected components: CPU
architectures, Docker's manifest system, the rocker project's image publishing
practices, and R's release cycle.

### Background: The Multi-Architecture Problem

#### CPU Architectures in the R Ecosystem

Two CPU architectures dominate modern computing:

- **AMD64 (x86_64)**: Intel and AMD processors, traditional Macs, most Linux
  servers, CI/CD systems (GitHub Actions, GitLab CI)
- **ARM64 (aarch64)**: Apple Silicon (M1/M2/M3/M4), Raspberry Pi, AWS Graviton,
  some cloud instances

Docker containers are architecture-specific. A container built for AMD64 cannot
run natively on ARM64 and vice versa. Docker Desktop on Apple Silicon provides
**emulation** via Rosetta 2, allowing AMD64 containers to run on ARM64 hardware,
but this requires explicit platform specification.

#### The Rocker Project and R Versions

The [Rocker Project](https://rocker-project.org/) maintains official Docker
images for R. These images follow R's release cycle:

- **R releases annually** in April (x.y.0), with patch releases as needed
- **Rocker builds images** for each R version, but not all images support all
  architectures
- **Architecture support varies by image**:

```
Image             AMD64    ARM64    Notes
─────────────────────────────────────────────────────────────────────
rocker/r-ver       ✓        ✓      Base R only
rocker/rstudio     ✓        ✓      RStudio Server included
rocker/tidyverse   ✓        ✗      Tidyverse packages (AMD64 only)
rocker/verse       ✓        ✗      Publishing tools (AMD64 only)
rocker/shiny       ✓        ✗      Shiny Server (AMD64 only)
rocker/geospatial  ✓        ✗      Spatial packages (AMD64 only)
```

The limitation exists because RStudio Server and Shiny Server binaries are only
available for AMD64. The rocker team cannot build ARM64 versions of images that
depend on these binaries.

#### Docker Manifests and Multi-Platform Images

Docker uses a **manifest** system to support multiple architectures under a
single image tag. When you pull `rocker/tidyverse:4.4.3`, Docker:

1. Fetches the manifest list from Docker Hub
2. Identifies your platform (e.g., `linux/arm64`)
3. Pulls the appropriate architecture-specific image

For multi-platform images, the manifest contains entries for each supported
architecture. For single-platform images (like `rocker/tidyverse`), the manifest
contains only AMD64.

### The Manifest Cache Problem

#### What Happens

Docker Desktop maintains a local cache of image manifests to speed up builds.
This cache can become **stale** or **corrupted**, causing builds to fail even
when the image exists on Docker Hub.

**Typical error message**:

```
ERROR: failed to resolve source metadata for
docker.io/rocker/tidyverse:4.4.3: no match for platform in manifest: not found
```

This error is misleading. The image exists, and it does support AMD64. The
problem is that Docker's local manifest cache is out of sync with Docker Hub.

#### Why This Happens

Several factors contribute to manifest cache staleness:

1. **New R versions**: When R 4.5.0 releases, rocker publishes new images. Your
   local cache may have stale metadata from when those tags did not exist.

2. **Rocker republishes images**: The rocker team sometimes updates images
   (security patches, base image updates) without changing the tag. Your cache
   may reference an old digest.

3. **Docker Desktop updates**: Version changes can invalidate or corrupt the
   manifest cache.

4. **Network interruptions**: Partial manifest fetches can leave the cache in an
   inconsistent state.

5. **BuildKit caching**: Docker BuildKit (enabled by default) maintains its own
   metadata cache separate from the Docker daemon's cache.

#### The Apple Silicon Dimension

This problem disproportionately affects Apple Silicon users because:

1. **Explicit platform required**: When building AMD64 images on ARM64,
   you must specify `--platform linux/amd64`. This triggers a different code
   path in Docker's manifest resolution.

2. **Emulation layer**: The Rosetta 2 emulation adds complexity to the
   container runtime, and manifest resolution must account for this.

3. **Cache key differences**: The manifest cache key includes platform
   information. A cache entry for `rocker/tidyverse:4.4.3` on native ARM64
   differs from the cache entry for the same image with explicit AMD64 platform.

4. **Default platform confusion**: Docker Desktop's default platform setting
   can conflict with explicit `--platform` flags in Dockerfiles or build
   commands.

### Solutions

#### Immediate Fix: Manual Pre-Pull

When a build fails with manifest errors, manually pull the image:

```bash
docker pull --platform linux/amd64 rocker/tidyverse:4.4.3
make docker-build
```

This forces Docker to fetch fresh metadata from Docker Hub and update the local
cache. The subsequent build will find the cached image.

#### Automatic Fix: ZZCOLLAB Makefile

The ZZCOLLAB Makefile template includes automatic pre-pull for `docker-build`
and `docker-rebuild` targets:

```makefile
BASE_IMAGE := $(shell grep '^ARG BASE_IMAGE=' Dockerfile | head -1 | cut -d= -f2)

docker-build:
    @docker pull --platform linux/amd64 $(BASE_IMAGE):$(R_VERSION) || true
    DOCKER_BUILDKIT=1 docker build --platform linux/amd64 ...
```

The `|| true` ensures the build continues even if the pull fails (e.g., offline
mode with cached images). This approach:

- Refreshes the manifest cache before every build
- Adds minimal overhead (manifest checks are fast for cached images)
- Works transparently without user intervention

#### Cache Cleanup

For persistent issues, clear Docker's caches:

```bash
# Clear BuildKit build cache (most common fix)
docker builder prune -f

# Clear all unused Docker data (more aggressive)
docker system prune -f

# Nuclear option: reset Docker Desktop completely
# Docker Desktop → Troubleshoot → Reset to factory defaults
```

#### Verify Image Availability

Before assuming a cache problem, verify the image exists:

```bash
# Check manifest directly from Docker Hub
docker manifest inspect rocker/tidyverse:4.4.3

# Expected output shows platform support:
# {
#   "manifests": [
#     {
#       "platform": {
#         "architecture": "amd64",
#         "os": "linux"
#       }
#     }
#   ]
# }
```

If `manifest inspect` succeeds but `docker build` fails, the problem is
definitely a local cache issue.

### Timing and R Release Cycles

Understanding when manifest problems are most likely helps with planning:

#### High-Risk Periods

1. **April each year**: R x.y.0 releases. Rocker images for new R versions
   appear over the following days/weeks. Early adopters may encounter missing
   images or incomplete manifests.

2. **Days after patch releases**: R x.y.z patch releases (typically 2-3 per
   year) trigger new rocker builds. There may be a lag between R release and
   rocker image availability.

3. **After Docker Desktop updates**: Major Docker Desktop releases can affect
   manifest caching behavior.

#### Safe Practices

1. **Use stable R versions**: Prefer R x.y.2 or x.y.3 over x.y.0. These have
   been available longer and have more stable rocker images.

2. **Pin specific versions**: Use `rocker/tidyverse:4.4.3` rather than
   `rocker/tidyverse:latest`. This makes builds reproducible and avoids
   surprises when new versions publish.

3. **Test before team rollout**: When updating R versions for a team project,
   one team member should verify the build works before updating the shared
   Dockerfile.

### Diagnostic Commands

When troubleshooting manifest issues, these commands provide useful information:

```bash
# Check what Docker thinks your platform is
docker version --format '{{.Server.Os}}/{{.Server.Arch}}'

# List local images and their platforms
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}"

# Inspect a specific image's platform
docker inspect rocker/tidyverse:4.4.3 --format '{{.Os}}/{{.Architecture}}'

# Check Docker Desktop settings (macOS)
cat ~/Library/Group\ Containers/group.com.docker/settings.json | \
  grep -E "(defaultPlatform|useVirtualizationFramework)"

# View BuildKit cache entries
docker buildx du

# Check if Rosetta is being used (macOS)
sysctl sysctl.proc_translated
```

### Platform-Specific Configuration

#### Docker Desktop Settings (macOS)

For Apple Silicon Macs, these Docker Desktop settings affect manifest handling:

1. **Use Rosetta for x86_64/amd64 emulation** (recommended: ON)
   - Settings → General → Use Rosetta for x86/amd64 emulation
   - Improves AMD64 container performance significantly

2. **Use containerd for pulling and storing images** (recommended: ON for new
   installs)
   - Settings → General → Use containerd for pulling and storing images
   - Different manifest caching behavior than legacy storage

3. **Virtual Machine options**
   - Settings → Resources → Advanced
   - More memory improves build performance for large images

#### Environment Variables

These environment variables affect Docker build behavior:

```bash
# Force BuildKit (usually default, but explicit is safer)
export DOCKER_BUILDKIT=1

# Set default platform for builds
export DOCKER_DEFAULT_PLATFORM=linux/amd64

# Disable BuildKit inline cache (can help with cache issues)
export BUILDKIT_INLINE_CACHE=0
```

### CI/CD Considerations

GitHub Actions and other CI/CD platforms typically run on AMD64 Linux, so
manifest issues are rare in CI. However, developers may encounter issues locally
that do not reproduce in CI:

```yaml
# .github/workflows/docker.yml
jobs:
  build:
    runs-on: ubuntu-latest  # AMD64, no manifest issues
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: make docker-build
```

If CI builds succeed but local builds fail, the problem is almost certainly a
local manifest cache issue. Use the solutions described above.

### Summary

The Docker manifest cache problem on Apple Silicon stems from the interaction
of:

- **Architecture emulation**: Running AMD64 containers on ARM64 hardware
- **Manifest caching**: Docker's local cache of image metadata
- **Rocker's publishing**: Limited ARM64 support for R images
- **R's release cycle**: New versions create new images that may not be cached

The ZZCOLLAB Makefile mitigates this automatically with pre-pull steps. For
manual intervention, `docker pull --platform linux/amd64 <image>` before
building resolves most issues. Understanding the underlying causes helps
diagnose edge cases and plan for R version upgrades.

## Related Documentation

- **Development Commands**: [Development Guide](DEVELOPMENT.md)
- **Docker Profiles**: [Variants Guide](VARIANTS.md) - 14+ specialized environments
- **Package Management**: [Package Management Guide](guides/renv.md) - Dynamic renv workflow
- **Configuration**: [Configuration Guide](CONFIGURATION.md)
