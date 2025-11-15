# Development Commands

This guide covers all development commands for working with ZZCOLLAB, including R package development, Docker management, testing, and team collaboration workflows.

*For comprehensive testing documentation, see [Testing Guide](TESTING_GUIDE.md)*

## R Package Development

### Native R Development
```bash
# Native R (requires local R installation)
make test                    # Run R package tests
make check                   # R CMD check validation
make document               # Generate documentation
make build                  # Build R package
```

### Docker-based Development
```bash
# Docker-based (works without local R)
make docker-test           # Run tests in container
make docker-check          # Package validation
make docker-document       # Generate docs
make docker-render         # Render analysis reports
```

### CI/CD Validation
```bash
# Pure shell validation (NO HOST R REQUIRED!)
make check-renv            # Full validation + auto-fix (strict mode, default)
make check-renv-no-fix     # Validation only, no auto-add
make check-renv-no-strict  # Standard mode (skip tests/, vignettes/)

# R options monitoring
Rscript check_rprofile_options.R    # Track critical R options changes

# Container-based CI commands (used in GitHub Actions)
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning')"
```

**Pure Shell Validation System** (October-November 2025):
- Uses `modules/validation.sh` - pure shell (curl, jq, awk, grep, sed)
- Extracts packages from code without R (BSD grep compatible)
- **Auto-fixes** Code → DESCRIPTION → renv.lock pipeline
- Parses DESCRIPTION with awk, edits with awk
- Parses/edits renv.lock with jq
- Queries CRAN API (crandb.r-pkg.org) for package metadata
- Smart filtering: 19 filters remove placeholders and false positives
- Works on any system (no R installation required!)
- Automatically runs after all `docker-*` targets exit

## Docker Development Environments

### Development Shells
```bash
make docker-sh             # Shell with dotfiles (recommended)
make docker-rstudio        # RStudio Server at localhost:8787
make docker-verse          # Verse environment with LaTeX (publishing)
make docker-r              # R console only
make docker-bash           # Bash shell
```

**✨ Auto-Snapshot Architecture** (October 2025):

All `docker-*` targets automatically snapshot renv.lock on container exit:

1. **No manual `renv::snapshot()` required!** - Just work and exit
2. **RSPM timestamp optimization** - Adjusts renv.lock timestamp for binary packages (10-20x faster Docker builds)
3. **Pure shell validation** - Validates packages on host without R
4. **Timestamp restoration** - Restores to current time for accurate git history

**Workflow**:
```bash
make r                       # 1. Enter container (entrypoint active)
renv::install("tidyverse")   # 2. Add packages as needed
exit                         # 3. Exit → auto-snapshot + validation!
# renv.lock automatically updated and validated
git add renv.lock && git commit -m "Add tidyverse" && git push
```

**Configuration** (optional):
```bash
# Disable auto-snapshot if needed
docker run -e ZZCOLLAB_AUTO_SNAPSHOT=false ...

# Disable RSPM timestamp adjustment
docker run -e ZZCOLLAB_SNAPSHOT_TIMESTAMP_ADJUST=false ...
```

## Docker Environment Management

### Viewing Available Options
```bash
# View available base images and package bundles
cat bundles.yaml           # View all available profiles and packages
```

### Customizing Docker Environment
```bash
# Customize Docker environment
vim Dockerfile             # Edit base image, R packages, system dependencies

# Build custom Docker image
make docker-build          # Build team/project-specific image
make docker-push-team      # Share with team (for team lead)

# Team members use pre-built image
zzcollab --use-team-image  # Download and use team's Docker image
```

## Dependency Management

### renv Commands
```bash
# Pure shell validation (recommended - no host R required!)
make check-renv            # Full validation + auto-fix (strict mode, default)
make check-renv-no-fix     # Validation only, no auto-add
make check-renv-no-strict  # Standard mode (skip tests/, vignettes/)

# Docker-based validation
make docker-check-renv     # Validate inside container

# Status checking
renv::status()             # Check renv status (inside R session)
```

**Note**: With auto-snapshot architecture, you rarely need to manually run validation commands. The system automatically validates after every container exit.

## Installation and Setup

### ZZCOLLAB Installation
```bash
# One-time zzcollab installation
./install.sh                    # Installs zzcollab to ~/bin
export PATH="$HOME/bin:$PATH"   # Add to shell config if needed
```

## Docker Image Building Workflow

### Team Lead - Build and Share Team Image
```bash
# 1. Create project with team settings
zzcollab -t TEAM -p PROJECT

# 2. Customize Docker environment (optional)
vim Dockerfile              # Modify base image (r-ver, rstudio, verse)
                           # Adjust R packages in bundles.yaml reference
                           # Add system dependencies

# 3. Build team Docker image
make docker-build          # Builds TEAM/PROJECTcore:latest

# 4. Share with team
make docker-push-team      # Push to Docker Hub
```

**Dynamic Package Management**: Packages are added as needed via `renv::install()` inside containers. No pre-configured "modes" - just install what you need!

### Team Member - Use Pre-Built Team Image
```bash
# 1. Clone team project
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT

# 2. Use team's Docker image
zzcollab --use-team-image

# 3. Start development
make docker-sh             # Enter container with team environment
```

### Solo Developer - Build Personal Image
```bash
# 1. Create project (no team)
zzcollab -p PROJECT

# 2. Customize if needed
vim Dockerfile             # Adjust packages, base image

# 3. Build image
make docker-build          # Builds personal Docker image
```

## Team Collaboration Setup

### Developer 1 (Team Lead) - Complete Workflow
```bash
# Step 1: Create project structure with team settings
zzcollab -t TEAM -p PROJECT

# Step 2: Customize Docker environment (optional)
cd PROJECT
vim Dockerfile              # Modify base image: rocker/r-ver, rocker/rstudio, rocker/verse
vim bundles.yaml            # Adjust R package selection if needed

# Step 3: Build team Docker image
make docker-build          # Builds TEAM/PROJECTcore:latest

# Step 4: Share with team
make docker-push-team      # Push to Docker Hub

# Step 5: Commit and push project
git add .
git commit -m "Initial project setup"
git push
```

### Developer 2+ (Team Members) - Join Existing Project
```bash
# Step 1: Clone team project
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT

# Step 2: Use team's pre-built Docker image
zzcollab --use-team-image

# Step 3: Start development environment
make docker-sh             # Enter container (command-line)
# OR
make docker-rstudio        # Start RStudio Server at localhost:8787

# That's it! You are using the exact same environment as the team lead.
```

### Environment Customization (Team Lead)
```bash
# If team needs different packages or base images:
vim Dockerfile             # Change FROM rocker/rstudio to rocker/verse for LaTeX
                          # Modify COPY --from lines to reference different bundles
                          # Add system dependencies with apt-get

# Rebuild and share
make docker-build
make docker-push-team

# Team members update their images:
docker pull TEAM/PROJECTcore:latest
make docker-sh             # Automatically uses updated image
```

### Error Handling
```bash
# If team member cannot pull team image:
# Error: Unable to pull TEAM/PROJECTcore:latest from Docker Hub

# Solutions:
#    1. Ask team lead to verify image was pushed: make docker-push-team
#    2. Check Docker Hub permissions (image must be public or you need access)
#    3. Build image locally if needed: make docker-build
```

## Package Management

### Dynamic Package Installation

ZZCOLLAB uses **dynamic package management** via renv for maximum flexibility:

```bash
# Inside Docker container
make r

# Add packages as needed
renv::install("tidyverse")
renv::install("sf")
renv::install("targets")

# Exit and commit (auto-snapshot happens automatically!)
exit                      # ← Automatic renv::snapshot() + validation
git add renv.lock
git commit -m "Add analysis packages"
```

**✨ No manual `renv::snapshot()` needed!** The auto-snapshot architecture automatically captures package changes when you exit the container.

### Docker Profiles

**Profile System**: Select pre-configured Docker environments optimized for different use cases:

```bash
# Minimal profile (lightweight, ~200MB)
zzcollab --profile-name minimal

# Analysis profile (tidyverse + common packages)
zzcollab --profile-name analysis

# Bioinformatics profile (Bioconductor packages)
zzcollab --profile-name bioinformatics

# Geospatial profile (GDAL, PROJ, sf, terra)
zzcollab --profile-name geospatial
```

*For complete profile documentation, see [Variants Guide](VARIANTS.md)*

### Dockerfile Customization

Team leads can customize the Docker environment:

```dockerfile
# 1. Choose base image (line ~3):
FROM rocker/rstudio:4.4.0     # RStudio Server
# FROM rocker/r-ver:4.4.0     # Shell-only
# FROM rocker/verse:4.4.0     # Publishing with LaTeX

# 2. Add system dependencies (line ~29):
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    libproj-dev

# 3. Install base R packages (line ~106):
RUN ${R_PACKAGES_INSTALL_CMD}
```

### Team Collaboration Workflow

```bash
# Team Lead:
zzcollab -t team -p project --profile-name analysis
make docker-build && make docker-push-team
git add . && git commit -m "Initial setup" && git push

# Team Members:
git clone https://github.com/team/project.git && cd project
zzcollab --use-team-image
make docker-sh
# Add packages as needed with renv::install()
```

## Key Benefits

- **Dynamic flexibility**: Add packages on-demand via renv::install()
- **Docker profiles**: Pre-configured environments for common use cases
- **Full Docker control**: Customize base image and system dependencies
- **Easy sharing**: Team members use --use-team-image
- **Collaborative renv.lock**: Accumulates packages from all contributors

## Related Documentation

- **Testing**: [Testing Guide](TESTING_GUIDE.md)
- **Configuration**: [Configuration Guide](CONFIGURATION.md)
- **Docker Profiles**: [Variants Guide](VARIANTS.md)
- **Auto-Snapshot Architecture**: See "Docker Development Environments" section above
