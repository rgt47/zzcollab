# Team Collaboration Workflow Guide

**Official documentation for team-based research projects using ZZCOLLAB**

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [Team Lead Workflow](#team-lead-workflow)
3. [Team Member Workflow](#team-member-workflow)
4. [Daily Workflows](#daily-workflows)
5. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Team Lead (First Time Setup)
```bash
# 1. Create project directory
mkdir study-project && cd study-project

# 2. Initialize with full setup (init + renv + docker)
zzc analysis                     # Full setup with analysis profile
zzc github                       # Create private GitHub repo

# 3. Build and push Docker image (installs packages from renv.lock)
make docker-build
make docker-push-team            # Optional but efficient for team

# 4. Commit and push to GitHub
git add . && git commit -m "Initial team project setup" && git push
```

### Team Member (Joining Project)
```bash
# 1. Clone the repository
git clone https://github.com/myteam/study.git && cd study

# 2. Pull team's Docker image (fast: 1-3 min)
zzcollab --use-team-image

# Alternative: Build from Dockerfile (always works: 5-15 min)
# make docker-build

# 3. Start development
make r
```

---

## Team Lead Workflow

### Initial Setup

The team lead establishes the computational foundation that all team members will use.

#### Step 1: Configure Team Settings (Optional)

```bash
# Set default team configuration (one-time setup)
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set github-account "myteam"
```

#### Step 2: Create Project

```bash
# Navigate to workspace
cd ~/projects

# Create and initialize project
mkdir study-project && cd study-project
zzc analysis                     # Full setup (init + renv + docker)
zzc github                       # Create private GitHub repo

# View available profiles
zzc help profiles
```

**What this creates:**
- R package structure
- Docker configuration (Dockerfile)
- Team base image configuration
- GitHub Actions workflows
- Analysis directory structure
- renv.lock for package management

#### Step 3: Build Team Docker Image

```bash
# Build the Docker image
make docker-build

# This creates: myteam/study:latest
```

**Important**: Team Docker image contains:
- R version (locked)
- System dependencies (locked)
- Base R packages (from profile)
- Development tools
- Environment configuration

#### Step 4: Push to Docker Hub

```bash
# Login to Docker Hub (if needed)
docker login

# Push team image
make docker-push-team

# Image now available at: myteam/study:latest
```

#### Step 5: Initialize Git Repository

```bash
# Initialize git (if not already done)
git init
git add .
git commit -m "Initial team project setup"

# Create GitHub repository and push
gh repo create myteam/study --public --source=. --push
```

#### Step 6: Notify Team Members

Share with team:
1. Repository URL: `https://github.com/myteam/study`
2. Docker Hub image: `myteam/study:latest`
3. Team name: `myteam`
4. Project name: `study`

---

## Team Member Workflow

### Initial Setup

Team members pull the pre-built Docker image instead of building locally.

#### Step 1: Clone Repository

```bash
# Clone the team repository
git clone https://github.com/myteam/study.git
cd study
```

#### Step 2: Pull Team Docker Image

```bash
# Option A: Pull team image (fast: 1-3 min)
zzcollab --use-team-image

# Option B: Build from Dockerfile (always works: 5-15 min)
make docker-build
```

**What `--use-team-image` does:**
- Pulls from Docker Hub (faster than building)
- Uses team's pre-built image with packages installed
- Skips local Docker build

**Note**: DockerHub is optional but efficient. Building from Dockerfile
produces an identical environment if team image is not available.

#### Step 3: Start Development

```bash
# Enter Docker environment
make r

# Inside container:
# - All team packages available
# - Consistent environment
# - Add personal packages as needed
```

### Adding Personal Packages

Team members can add packages independently:

```bash
# Inside Docker container
install.packages("ggplot2")
install.packages("dplyr")

# Exit container - auto-snapshot saves to renv.lock
exit

# Commit changes
git add renv.lock
git commit -m "Add ggplot2 and dplyr packages"
git push
```

**Important**:
- Docker image = team foundation (shared, locked)
- renv.lock = union of all packages (collaborative, grows)
- Team members add packages independently
- Lead does NOT need to rebuild Docker image

---

## Daily Workflows

### Team Lead

#### Updating Docker Foundation

Only needed when:
- Changing R version
- Adding system dependencies
- Changing base image

```bash
# Update Dockerfile or profile
vim Dockerfile  # or update --profile-name

# Rebuild and push
make docker-build
make docker-push-team

# Notify team to pull new image
git add Dockerfile
git commit -m "Update Docker foundation: add GDAL support"
git push
```

#### Reviewing Team Contributions

```bash
# Pull latest changes
git pull

# Review renv.lock changes
git log -p renv.lock

# Restore environment
make r
renv::restore()
```

### Team Members

#### Standard Development Workflow

```bash
# 1. Pull latest changes
git pull

# 2. Restore packages
make r
renv::restore()

# 3. Work on analysis
# ... make changes ...

# 4. Add any new packages needed
install.packages("newpackage")
# Auto-snapshot on exit

# 5. Commit and push
exit
git add .
git commit -m "Add analysis for aim 2"
git push
```

#### Syncing with Team Updates

```bash
# Pull team changes
git pull

# Check if Docker image updated
git log --oneline Dockerfile

# If Dockerfile changed, pull new image
docker pull myteam/study:latest

# Restore packages
make r
renv::restore()
```

---

## Foundation vs. Packages

Understanding the two-layer system:

### Layer 1: Docker Image (Team Foundation)
**Controlled by**: Team lead
**Contains**: R version, system libraries, base packages
**Frequency**: Rarely changes (weeks/months)
**Sharing**: Docker Hub

```bash
# Lead updates:
make docker-build && make docker-push-team

# Members sync:
docker pull myteam/study:latest
```

### Layer 2: R Packages (Personal Choice)
**Controlled by**: Each team member
**Contains**: Analysis-specific packages
**Frequency**: Changes often (daily)
**Sharing**: renv.lock in git

```bash
# Anyone can add:
install.packages("tidyverse")
exit  # Auto-snapshot on exit
git add renv.lock DESCRIPTION
git commit -m "Add tidyverse"
git push

# Everyone syncs:
git pull
make r  # Auto-restore installs new packages on R startup
```

**Key Principle**: Docker provides speed and consistency. renv provides flexibility and reproducibility.

---

## Configuration Flags

### Team Lead Commands

```bash
# Standard project setup (recommended)
mkdir PROJECT && cd PROJECT
zzc analysis                     # Full setup (init + renv + docker)
zzc github                       # Create private GitHub repo

# With custom profile
zzc bioinformatics               # Full setup with bioinformatics profile
zzc geospatial                   # Full setup with geospatial profile
```

### Team Member Commands

```bash
# Clone and use team image (fast: 1-3 min)
git clone https://github.com/TEAM/PROJECT.git && cd PROJECT
zzcollab --use-team-image

# Build locally (always works: 5-15 min)
make docker-build
```

### Automation Flags

```bash
# For CI/CD pipelines (skip file conflict prompts)
zzcollab --force analysis

# Combine with other flags
zzcollab --use-team-image --force
```

**When to use `--force`**:
- CI/CD workflows (GitHub Actions, GitLab CI, etc.)
- Automated testing environments
- Container build pipelines
- Any non-interactive context where prompts would fail

**Security note**: Only use `--force` in trusted automation contexts. It will overwrite existing files without confirmation.

---

## Troubleshooting

### "Dockerfile already exists"

**Problem**: Trying to change profile after project is initialized

**Solution**:
```bash
# In existing project, switch profile:
zzc NEW_PROFILE                  # Smart detection: regenerates Dockerfile
make docker-build && make docker-push-team
```

### "Docker image pull failed"

**Problem**: Team image not pushed or authentication issue

**Solution**:
```bash
# Verify image exists
docker search myteam/study

# Login to Docker Hub
docker login

# Pull manually
docker pull myteam/study:latest
```

### "Package installation failed in renv::restore()"

**Problem**: Package dependencies missing from Docker image

**Solution**:
```bash
# Temporary: Install in container
make r
install.packages("problematic-package")

# Permanent: Ask lead to update Docker image
# Lead adds system dependency to Dockerfile
```

### "Merge conflicts in renv.lock"

**Problem**: Two team members added different packages

**Solution**:
```bash
# Accept both changes (union model)
git pull
# Manually merge renv.lock keeping all packages
renv::restore()  # Install all packages
```

---

## Best Practices

### For Team Leads

1. **Minimize Docker Changes**: Only rebuild for system dependencies
2. **Document Foundation**: Clearly communicate Docker image contents
3. **Test Before Pushing**: Ensure Docker image works before sharing
4. **Version Images**: Use tags for major changes: `myteam/study:v2.0`
5. **Communication**: Notify team when foundation changes

### For Team Members

1. **Pull Before Push**: Always `git pull` before starting work
2. **Snapshot Regularly**: Run `renv::snapshot()` after adding packages
3. **Don't Build Locally**: Use `--use-team-image` for consistency
4. **Test Packages**: Ensure packages work before committing renv.lock
5. **Communicate**: Mention major package additions in commits

### For Everyone

1. **Commit Messages**: Be descriptive about changes
2. **Pull Requests**: Use PRs for major analysis changes
3. **Documentation**: Update docs when adding features
4. **Testing**: Run tests before pushing (`make test`)
5. **Reproducibility**: Verify analyses run in clean environment

---

## Migration from Solo to Team

Converting an existing solo project to team collaboration:

```bash
# 1. Navigate to existing project
cd my-solo-project

# 2. Re-initialize with team settings
zzcollab -t myteam -p study

# 3. Build and push team image
make docker-build
make docker-push-team

# 4. Commit and push
git add .
git commit -m "Convert to team collaboration project"
git push -u origin main
```

---

## Related Documentation

- [Configuration Guide](CONFIGURATION.md) - Multi-level config system
- [Docker Architecture](DOCKER_ARCHITECTURE.md) - Docker technical details
- [Profile System](VARIANTS.md) - Available Docker profiles
- [Development Guide](DEVELOPMENT.md) - Daily development commands

---

**Last Updated**: October 2025
**ZZCOLLAB Version**: 2.0+
