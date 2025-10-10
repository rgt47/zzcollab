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
# CI/CD validation (enhanced with build mode awareness)
Rscript validate_package_environment.R --quiet --fail-on-issues  # Dependency validation
Rscript validate_package_environment.R --build-mode fast --quiet --fail-on-issues  # Fast mode validation
ZZCOLLAB_BUILD_MODE=comprehensive Rscript validate_package_environment.R --fix --fail-on-issues  # Environment variable
Rscript check_rprofile_options.R                          # R options monitoring

# Container-based CI commands (used in GitHub Actions)
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript validate_package_environment.R --quiet --fail-on-issues
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning')"
```

## Docker Development Environments

### Development Shells
```bash
make docker-zsh            # Zsh shell with dotfiles (recommended)
make docker-rstudio        # RStudio Server at localhost:8787
make docker-verse          # Verse environment with LaTeX (publishing)
make docker-r              # R console only
make docker-bash           # Bash shell
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
make check-renv            # Check renv status
make check-renv-fix        # Update renv.lock
make docker-check-renv     # Validate in container
Rscript validate_package_environment.R --quiet --fail-on-issues  # CI validation
Rscript validate_package_environment.R --fix --fail-on-issues    # Auto-fix missing packages
Rscript validate_package_environment.R --build-mode fast --fix   # Build mode aware validation
```

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
zzcollab -t TEAM -p PROJECT -d ~/dotfiles

# 2. Customize Docker environment (optional)
vim Dockerfile              # Modify base image (r-ver, rstudio, verse)
                           # Adjust R packages in bundles.yaml reference
                           # Add system dependencies

# 3. Build team Docker image
make docker-build          # Builds TEAM/PROJECTcore:latest

# 4. Share with team
make docker-push-team      # Push to Docker Hub

# Combine with build modes for different package sets:
# Edit Dockerfile to reference different bundle:
# - fast-bundle (9 packages, 2-3 minutes)
# - standard-bundle (17 packages, 4-6 minutes) [default]
# - comprehensive-bundle (47+ packages, 15-20 minutes)
```

### Team Member - Use Pre-Built Team Image
```bash
# 1. Clone team project
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT

# 2. Use team's Docker image
zzcollab --use-team-image -d ~/dotfiles

# 3. Start development
make docker-zsh            # Enter container with team environment
```

### Solo Developer - Build Personal Image
```bash
# 1. Create project (no team)
zzcollab -p PROJECT -d ~/dotfiles

# 2. Customize if needed
vim Dockerfile             # Adjust packages, base image

# 3. Build image
make docker-build          # Builds personal Docker image
```

## Team Collaboration Setup

### Developer 1 (Team Lead) - Complete Workflow
```bash
# Step 1: Create project structure with team settings
zzcollab -t TEAM -p PROJECT -d ~/dotfiles

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
zzcollab --use-team-image -d ~/dotfiles

# Step 3: Start development environment
make docker-zsh            # Enter container (command-line)
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
make docker-zsh            # Automatically uses updated image
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

## Build Modes Reference

### Build Mode Comparison
```bash
# Minimal (-M): Ultra-fast bare essentials (~30 seconds, 3 packages)
#   → renv, remotes, here

# Fast (-F): Development essentials (2-3 minutes, 9 packages)
#   → renv, remotes, here, usethis, devtools, testthat, knitr, rmarkdown, targets

# Standard (-S): Balanced Docker + standard packages (4-6 minutes, 17 packages, default)
#   → + dplyr, ggplot2, tidyr, palmerpenguins, broom, janitor, DT, conflicted

# Comprehensive (-C): Extended Docker + full packages (15-20 minutes, 47 packages)
#   → + tidymodels, shiny, plotly, quarto, flexdashboard, survival, lme4, databases
```

### Dockerfile Customization

#### Bundle System
```bash
# bundles.yaml defines three package collections:
# - fast-bundle: 9 essential packages (2-3 minutes)
# - standard-bundle: 17 balanced packages (4-6 minutes, default)
# - comprehensive-bundle: 47+ full ecosystem (15-20 minutes)
```

#### Customizing Dockerfile
```dockerfile
# Team leads modify Dockerfile to select bundle and base image:

# 1. Choose base image (line ~10):
FROM rocker/rstudio:latest    # RStudio Server
# FROM rocker/r-ver:latest    # Shell-only
# FROM rocker/verse:latest    # Publishing with LaTeX

# 2. Choose package bundle (line ~50):
COPY --from=bundles standard-bundle /   # Default
# COPY --from=bundles fast-bundle /      # Minimal
# COPY --from=bundles comprehensive-bundle /  # Full

# 3. Add custom packages (optional, line ~60):
RUN Rscript -e "install.packages(c('sf', 'terra', 'leaflet'))"

# 4. Add system dependencies (optional, line ~30):
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    libproj-dev
```

### Example Workflow
```bash
# Team Lead:
zzcollab -t team -p project -d ~/dotfiles
vim Dockerfile             # Select bundle, base image, add custom packages
make docker-build
make docker-push-team

# Team Members:
git clone https://github.com/team/project.git
cd project
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh
```

## Key Benefits

- **Single source of truth**: Dockerfile defines entire environment
- **Full Docker control**: Use any base image, add any package
- **Efficient caching**: Multi-stage builds for fast rebuilds
- **Easy sharing**: One command to push, one flag to use team image
- **Transparent**: Team sees exact Dockerfile configuration

## Related Documentation

- **Testing**: [Testing Guide](TESTING_GUIDE.md)
- **Build Modes**: [Build Modes Guide](BUILD_MODES.md)
- **Configuration**: [Configuration Guide](CONFIGURATION.md)
- **Docker Profiles**: [Variants Guide](VARIANTS.md)
