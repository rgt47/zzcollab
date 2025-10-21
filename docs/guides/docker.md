# Docker Essentials

---

## What Is Docker? (For Non-Technical Users)

Docker creates "containers" - isolated environments that run on your computer.

Think of it like this:
- **Your computer** = apartment building
- **Container** = individual apartment
- Each apartment has its own furniture (software, packages)
- Apartments don't interfere with each other
- You can have many apartments in one building

### Why this matters for research

- **Reproducibility** - Same environment on every computer
- **Isolation** - Projects don't conflict with each other
- **Shareability** - Team gets identical environments
- **Cleanliness** - Delete project, container gone (no leftover junk)

---

## Key Docker Concepts (Simplified)

### 1. DOCKER IMAGE (the blueprint)

**What**: Recipe for creating a container
**Like**: Blueprint for an apartment
**Contains**: Operating system, R, packages, your dotfiles
**Created once**: When you run zzcollab command
**Stored on**: Your computer (or Docker Hub for teams)

**Example**:
```
myteam/projectcore-rstudio:latest
└─ Team name: myteam
└─ Project: projectcore
└─ Variant: rstudio
└─ Version: latest
```

### 2. DOCKER CONTAINER (the running instance)

**What**: Running environment from an image
**Like**: Actual apartment built from blueprint
**Contains**: Your active R session, running code
**Created**: Each time you run "make docker-rstudio"
**Destroyed**: When you press Ctrl+C
**Your files**: SAVED if in `/home/analyst/project` (mounted!)

**Key insight**: Container is temporary, files in mounted directory persist!

### 3. DOCKER VOLUME (file sharing)

**What**: Bridge between container and your computer
**Like**: Window between apartments
**Allows**: Files sync automatically both ways
**Used for**: Your project directory

**Example**:
```
~/projects/myproject ←→ /home/analyst/project
(Your computer)         (Inside container)
```

Changes in either location appear in both!

### 4. DOCKERFILE (build instructions)

**What**: Text file with instructions to build image
**Like**: Recipe for setting up an apartment
**Contains**: Install R, add packages, copy dotfiles
**You rarely edit**: zzcollab generates this for you

---

## The Docker Workflow (What Actually Happens)

### Step 1: Build Image (happens once)

**You run**:
```bash
zzcollab -p myproject
```

**Behind scenes**:
1. Generate Dockerfile
2. Download base R image
3. Install packages
4. Copy dotfiles
5. Create image: `myname/myprojectcore-rstudio:latest`

This takes time (~5-10 minutes), but only happens once!

### Step 2: Start Container (daily workflow)

**You run**:
```bash
make docker-rstudio
```

**Behind scenes**:
1. Create container from image
2. Mount your project directory
3. Start RStudio Server
4. Open browser to localhost:8787

This is fast (~5 seconds)!

### Step 3: Work in Container

**You**: Use RStudio normally

**Behind scenes**:
- R running inside container
- Files saved to `/home/analyst/project`
- Automatically synced to your computer
- Everything works like normal RStudio!

### Step 4: Stop Container

**You**: Close browser, press Ctrl+C in terminal

**Behind scenes**:
- Container stops
- Container deleted
- Files preserved (in mounted directory)
- Image remains for next time

### Step 5: Resume Next Day

**You**:
```bash
make docker-rstudio
```

**Behind scenes**:
- New container created from same image
- Same packages, same environment
- Files exactly where you left them!

---

## Docker Commands You'll Use

Don't worry - zzcollab handles most Docker commands for you! You mainly use make targets.

### Common Daily Commands

```bash
make docker-rstudio    # Start RStudio container
make docker-zsh        # Start command-line container
# Ctrl+C               # Stop container (in terminal)
```

### Diagnostic Commands

```bash
docker ps              # Show running containers
docker images          # Show available images
docker --version       # Check Docker installed
```

### Troubleshooting Commands

```bash
docker stop <id>       # Stop specific container
docker rm <id>         # Remove stopped container
docker logs <id>       # See container error messages
docker system prune    # Clean up unused images/containers
```

---

## Understanding "docker ps"

When you run:
```bash
docker ps
```

**Output example**:
```
CONTAINER ID   IMAGE                              PORTS                    NAMES
abc123def456   myteam/projcore-rstudio:latest    0.0.0.0:8787->8787/tcp   proj-rstudio
```

**What this means**:
- **CONTAINER ID**: `abc123def456` (unique identifier)
- **IMAGE**: Which blueprint was used
- **PORTS**: `0.0.0.0:8787->8787/tcp` (localhost:8787 access)
- **NAMES**: `proj-rstudio` (friendly name)

**If output is empty**: No containers running!

---

## File Persistence - Critical Concept

### Files That PERSIST (saved forever)

**Location**: `/home/analyst/project` (inside container)
**Maps to**: `~/projects/myproject` (on your computer)

**Examples**:
- `analysis/scripts/analysis.R`
- `analysis/data/raw_data/data.csv`
- `analysis/figures/plot.png`
- `renv.lock`
- `.git/` directory

**Why**: This directory is "mounted" (connected to host)

### Files That DON'T PERSIST (lost when container stops)

**Location**: Anywhere else in container

**Examples**:
- `/home/analyst/test.R` (not in `/project`!)
- `/tmp/temporary.csv`
- System files

**Why**: These are inside container only, not mounted

### GOLDEN RULE

**Always work in `/home/analyst/project`!**

RStudio starts there automatically - you're safe by default!

---

## Docker Lifecycle Scenarios

### Scenario 1: Normal Daily Workflow

**Day 1**:
```bash
make docker-rstudio
# Create analysis.R, save
# Ctrl+C
```

**Day 2**:
```bash
make docker-rstudio
# analysis.R still there!
# Continue working
```

**Why**: Files in `/project` mounted to host, persist between containers

### Scenario 2: Accidental Terminal Close

```bash
make docker-rstudio
# Terminal crashes or closes accidentally
# Oh no!

# Solution:
# Open new terminal
cd myproject
make docker-rstudio
# Everything restored!
```

**Why**: Files on host, container can be recreated

### Scenario 3: Computer Restart

```bash
# Computer crashes/restarts
# Containers stopped

# After restart:
cd myproject
make docker-rstudio
# Back to work!
```

**Why**: Images persist, containers recreated fresh

### Scenario 4: Deleting Container by Mistake

```bash
docker rm <container-id>
# Oops, deleted container!

# No problem:
make docker-rstudio
# New container, same files!
```

**Why**: Container temporary, files and image safe

### Scenario 5: Deleting Image (more serious!)

```bash
docker rmi myteam/projcore-rstudio:latest
# Deleted image!

# Solution: Rebuild
zzcollab -p myproject
# Rebuilds image (takes time)
# Files still safe
```

**Why**: Image can be rebuilt from Dockerfile + project files

---

## Docker Resource Usage

Docker uses computer resources:
- **Disk space**: Images can be large (1-3 GB each)
- **Memory**: Running containers use RAM
- **CPU**: Analysis uses processing power

### Managing Resources

**Check disk usage**:
```bash
docker system df
# Shows images, containers, volumes size
```

**Clean up unused resources**:
```bash
docker system prune
# Removes stopped containers, unused images
# Frees disk space
```

**Adjust Docker Desktop resources**:
- **macOS/Windows**: Docker Desktop → Settings → Resources
  - Increase memory (8GB recommended)
  - Increase CPU cores (4+ recommended)

---

## Common Docker Questions

**Q: "Do I need to learn Docker to use zzcollab?"**
A: No! zzcollab handles Docker for you. Just use make commands.

**Q: "What if I close the terminal running the container?"**
A: Container stops. Restart with `make docker-rstudio`. Files safe!

**Q: "Can I run multiple containers at once?"**
A: Yes, but they need different ports. Usually better to work on one project at a time.

**Q: "How do I update packages in a container?"**
A: Install packages normally in R, then `renv::snapshot()`

**Q: "What happens to packages when container stops?"**
A: Packages in image persist. Packages installed via `install.packages()` lost unless snapshot!

**Q: "Can I access files from outside the container?"**
A: Yes! Files in `~/projects/myproject` visible on your computer and in container.

**Q: "What if I accidentally save file outside /project?"**
A: File lost when container stops. Always use `/home/analyst/project`!

**Q: "How do I know if container is running?"**
A: Terminal shows logs (not prompt). Or: `docker ps`

**Q: "Can I use RStudio Desktop instead of container?"**
A: You can, but defeats reproducibility purpose. Container ensures same environment.

**Q: "Is my data safe in containers?"**
A: Yes, if in mounted `/project` directory. Backed up like any other file.

---

## Troubleshooting Docker Issues

### Issue: "Docker daemon not running"

**Solution**:
- **macOS**: Open Docker Desktop application
- **Windows**: Start Docker Desktop
- **Linux**: `sudo systemctl start docker`

**Verify**:
```bash
docker ps  # Should work without error
```

### Issue: "Port 8787 already in use"

**Cause**: Another RStudio container running

**Solutions**:

**1. Find and stop it**:
```bash
docker ps
docker stop <container-id>
```

**2. Use different port** (advanced):
```bash
# Edit Makefile, change 8787 to 8788
```

### Issue: "Cannot connect to localhost:8787"

**Check**:
1. Container running? `docker ps`
2. Try different browser
3. Try `http://127.0.0.1:8787` instead
4. Firewall blocking? Disable temporarily

### Issue: "Out of disk space"

**Clean up**:
```bash
docker system prune -a
# Removes all unused images and containers
# Frees significant space
```

### Issue: "Container exits immediately"

**Check logs**:
```bash
docker ps -a              # Show all containers (including stopped)
docker logs <container-id>  # See error message
```

**Common causes**:
- Port conflict
- Permission issues
- Corrupted image (rebuild: `zzcollab -p project`)

### Issue: "Changes not appearing in container"

**Verify mount**:
```bash
# In container:
ls /home/analyst/project
# Should show your files

# If empty, mount failed
# Restart container: Ctrl+C, make docker-rstudio
```

### Issue: "Docker eating all my RAM/CPU"

**Solutions**:
1. Stop unused containers: `docker ps`, `docker stop <id>`
2. Limit resources: Docker Desktop → Settings → Resources
3. Close resource-heavy applications while analyzing

---

## Docker Best Practices

1. **Always work in `/home/analyst/project`**
   - RStudio starts there - don't cd elsewhere!

2. **Stop containers when done**
   - `Ctrl+C` in terminal - frees resources

3. **Don't run too many containers simultaneously**
   - Work on one project at a time

4. **Periodically clean up**
   - `docker system prune` every month or so

5. **Commit files regularly**
   - Container stops? No problem if committed to git!

6. **Don't store secrets in images**
   - Use environment variables instead

7. **Rebuild images occasionally**
   - When updating zzcollab or changing build modes

8. **Use Docker Desktop dashboard**
   - Visual way to manage containers and images

---

## Advanced: Understanding Docker Build

When zzcollab builds a Docker image:

**Step 1**: `FROM rocker/rstudio`
- Download base R + RStudio image

**Step 2**: `RUN apt-get install ...`
- Install system dependencies (git, curl, etc.)

**Step 3**: `RUN install2.r ...`
- Install R packages

**Step 4**: `COPY dotfiles ...`
- Add your personal configuration

**Step 5**: `USER analyst`
- Set up non-root user

This creates an image ready for your research!

---

## Advanced: Alpine Linux Profiles

ZZCOLLAB supports ultra-lightweight Alpine Linux profiles for minimal container sizes (~200MB vs ~3GB for standard profiles).

### Available Alpine Profiles

- **alpine_minimal** - Bare-bones Alpine Linux environment
- **alpine_analysis** - Alpine with common analysis libraries

### Important Limitations

**⚠️ Alpine profiles require third-party base images**

Alpine profiles use `velaco/alpine-r` instead of official Rocker images because:
- Rocker project does not provide official Alpine builds
- Alpine uses `apk` package manager instead of `apt-get`
- Package availability differs from Debian/Ubuntu

### When to Use Alpine

**✅ Good for**:
- Minimal compute environments (HPC, cloud)
- Container size constraints
- Simple R scripts without many dependencies

**❌ Not recommended for**:
- Complex geospatial workflows (GDAL/PROJ harder to install)
- Bioinformatics (many packages assume Debian)
- RStudio Server (works but less tested)
- First-time Docker users

### Usage Example

```bash
# Create Alpine-based project
zzcollab --profile-name alpine_minimal --r-version 4.4.0

# Build image (may take longer due to package compilation)
make docker-build

# Enter container
make docker-zsh
```

### Troubleshooting Alpine

**Package installation fails**:
- Many R packages compile from source on Alpine
- Build times are longer
- Some packages may not work

**Missing system dependencies**:
- Use `apk add <package>` instead of `apt-get`
- Package names differ from Debian (e.g., `python3` vs `python`)

**For most users**: Stick with standard profiles unless you have specific size constraints.

---

## Quick Reference

### Essential Concepts

- **Image** = Blueprint (permanent)
- **Container** = Running instance (temporary)
- **Volume** = File sharing host ↔ container
- **Mount** = `~/projects/myproject` ↔ `/home/analyst/project`

### Daily Commands

```bash
make docker-rstudio     # Start RStudio
# Ctrl+C                # Stop container
docker ps               # Show running containers
```

### Troubleshooting

```bash
docker ps               # List containers
docker images           # List images
docker logs <id>        # See errors
docker system prune     # Clean up
```

### File Persistence

- ✅ `/home/analyst/project` → SAVED
- ❌ Anywhere else → LOST

### Key Files

- `Dockerfile` - Build instructions
- `Makefile` - make commands
- `docker-compose.yml` - (not used by default)

---

## See Also

- [Workflow Guide](workflow.md) - Daily development workflow using Docker
- [Troubleshooting Guide](troubleshooting.md) - Fix Docker-related issues
- [Configuration Guide](config.md) - Configure Docker profiles and settings
- [CI/CD Guide](cicd.md) - Automating Docker builds in GitHub Actions
