# Troubleshooting Guide

This guide covers the most common issues and their solutions.

---

## Top 10 Common Issues

1. Docker Not Running
2. Port Already in Use
3. Image Not Found
4. Permission Denied
5. Changes Disappeared
6. Package Installation Failed
7. RStudio Won't Connect
8. GitHub Authentication Failed
9. renv Issues
10. Build Takes Too Long

---

## Issue 1: Docker Not Running

**ERROR MESSAGE**:
```
Cannot connect to the Docker daemon
Is the docker daemon running?
```

**CAUSE**: Docker Desktop not started

**SOLUTIONS**:
- **macOS**: Open Docker Desktop from Applications
- **Windows**: Start Docker Desktop from Start Menu
- **Linux**: `sudo systemctl start docker`

**VERIFY**:
```bash
docker ps
# Should show running containers or empty list (not error)
```

---

## Issue 2: Port Already in Use (localhost:8787)

**ERROR MESSAGE**:
```
Bind for 0.0.0.0:8787 failed: port is already allocated
```

**CAUSE**: Another RStudio container using port 8787

**SOLUTIONS**:

**Option 1**: Stop the other container
```bash
docker ps                    # Find container ID
docker stop <container-id>   # Stop it
make docker-rstudio          # Try again
```

**Option 2**: Find which project is using the port
```bash
docker ps --format "{{.Names}}: {{.Ports}}"
# Shows which project owns port 8787
cd /path/to/that/project
# Ctrl+C in that terminal
```

**Option 3**: Use different port (advanced)
```bash
# Edit Makefile, change 8787 to 8788
```

---

## Issue 3: Image Not Found

**ERROR MESSAGE**:
```
Unable to find image 'myteam/projectcore-rstudio:latest' locally
Error response from daemon: pull access denied
```

**CAUSE**: Team image not built or wrong team name

**SOLUTIONS**:

**For solo researchers**:
```bash
# Make sure you ran zzcollab in this project
zzcollab -p projectname
```

**For team members**:
```bash
# Team lead needs to build and push images first
# Or: Team image name doesn't match
# Check DESCRIPTION file for correct team name
```

**Rebuild image**:
```bash
cd /path/to/project
make docker-build
```

---

## Issue 4: Permission Denied

**ERROR MESSAGE**:
```
Permission denied while trying to connect to Docker daemon
Got permission denied while trying to connect to the Docker daemon socket
```

**CAUSE**: User not in docker group (Linux)

**SOLUTIONS**:

**Linux**:
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**macOS/Windows**:
```bash
# Usually not an issue
# Restart Docker Desktop
```

**File permission issues**:
```bash
# Check project directory ownership
ls -la
# Should be owned by you, not root
```

---

## Issue 5: My Changes Disappeared!

**CAUSE**: Worked outside `/home/analyst/project` directory

**EXPLANATION**:
- Only files in `/home/analyst/project` persist
- Files elsewhere in container are lost when container stops

**SOLUTIONS**:

**Prevention**:
- Always work in `/home/analyst/project`
- RStudio starts there automatically
- Don't cd to other directories

**Recovery** (if happened):
- Sorry, files outside mounted directory are lost
- Lesson learned: stay in `/project`!

**Verify you're in right place**:
```r
# In RStudio:
getwd()
# Should show: /home/analyst/project
```

---

## Issue 6: Package Installation Failed

**ERROR MESSAGE**:
```
Installation of package 'X' had non-zero exit status
```

**COMMON CAUSES & SOLUTIONS**:

### Cause: Missing system dependencies

**Solution**:
```r
# Some packages need system libraries
# Example: sf package needs GDAL, GEOS, PROJ

# Option 1: Use specialized Docker profile
# zzcollab --profile-name geospatial  # For sf, terra, raster

# Option 2: Ask team lead to add system libraries to Docker image

# Option 3: Use alternative package without system dependencies
```

### Cause: CRAN server down

**Solution**:
```r
# Try different mirror
install.packages("packagename",
                 repos = "https://cloud.r-project.org")
```

### Cause: Package not on CRAN

**Solution**:
```r
# Install from GitHub
remotes::install_github("user/package")
```

### Cause: Package requires newer R version

**Solution**:
```r
# Check package requirements
# May need to use older package version
remotes::install_version("packagename", version = "1.0.0")
```

---

## Issue 7: RStudio Won't Connect (localhost:8787)

**ERROR MESSAGE**:
```
This site can't be reached
localhost refused to connect
```

**DIAGNOSTIC STEPS**:

1. **Is container running?**
   - Terminal should show logs, not prompt
   - If you see `$` prompt, container stopped

2. **Is it RStudio container?**
   ```bash
   make docker-rstudio
   # NOT: make r or make docker-r
   ```

3. **Check container status**:
   ```bash
   docker ps
   # Should see container with port 0.0.0.0:8787->8787
   ```

4. **Try different browser**:
   - Chrome, Firefox, Safari
   - Some browsers cache connection failures

5. **Check firewall**:
   - Firewall might block localhost
   - Try: `http://127.0.0.1:8787`

**SOLUTIONS**:

**Restart container**:
```bash
# Ctrl+C in terminal
make docker-rstudio
```

**Check port**:
```bash
lsof -i :8787  # macOS/Linux
# Shows what's using port 8787
```

---

## Issue 8: GitHub Authentication Failed

**ERROR MESSAGE**:
```
fatal: Authentication failed
gh: command not found
```

**CAUSE**: GitHub CLI not installed or not authenticated

**SOLUTIONS**:

**Install gh**:
```bash
macOS:   brew install gh
Linux:   sudo apt install gh
Windows: winget install GitHub.cli
```

**Authenticate**:
```bash
gh auth login
# Follow prompts, choose HTTPS
# Use web browser for easiest setup
```

**Verify**:
```bash
gh auth status
# Should show: ✓ Logged in to github.com
```

**Alternative** (no -G flag):
```bash
# Skip automatic GitHub repo creation
zzcollab -p project  # No -G flag
# Create repo manually later
```

---

## Issue 9: renv Problems

### ERROR: "renv is not installed"

**Solution**:
```r
install.packages("renv")
```

### ERROR: "renv.lock is out of sync"

**Solution**:
```r
renv::status()    # See what's wrong
renv::snapshot()  # Update lockfile
```

### ERROR: "Package versions don't match"

**Solution**:
```r
renv::restore()   # Restore from lockfile
```

### ERROR: "renv cache is corrupted"

**Solution**:
```r
# Delete cache, reinstall
renv::purge("packagename")
install.packages("packagename")
```

**Common workflow**:
```r
install.packages("newpackage")  # Install
renv::snapshot()                # Record
# Commit renv.lock to git
```

---

## Issue 10: Build Takes Too Long

**PROBLEM**: Docker build taking 15-20 minutes

**SOLUTIONS**:

**Use lighter Docker profile**:
```bash
zzcollab --config set profile-name "minimal"
# Minimal pre-installed packages
# Add more packages dynamically with renv::install()
```

**Or: Analysis profile** (recommended):
```bash
zzcollab --config set profile-name "analysis"
# Includes tidyverse and common analysis packages
# Install additional packages as needed with renv::install()
```

**Reuse team base image**:
```bash
# See: zzcollab --help-quickstart
# Create one comprehensive base image
# Reuse for all projects (~30 seconds each)
```

**Check Docker resources**:
```bash
# Docker Desktop → Settings → Resources
# Increase CPU/Memory allocation
```

---

## Additional Common Issues

### Issue: "make: command not found"

**Install make**:
```bash
macOS:   xcode-select --install
Linux:   sudo apt install build-essential
Windows: Use WSL2 or install make for Windows
```

### Issue: "Container exits immediately"

**Check logs**:
```bash
docker logs <container-name>
# Shows why container failed
```

**Common cause**: Syntax error in Dockerfile
```bash
# Check Dockerfile for typos
```

### Issue: "zzcollab: command not found"

**zzcollab not in PATH**:
```bash
# Add to ~/.bashrc or ~/.zshrc:
export PATH="$HOME/bin:$PATH"

# Or use full path:
~/bin/zzcollab
```

### Issue: "Different results on different computers"

This is the problem zzcollab solves!

**Likely cause**: Different package versions

**Solution**:
```bash
# Ensure renv.lock is committed
git add renv.lock
git commit -m "Lock package versions"

# On other computer:
git pull
make docker-rstudio
# In RStudio:
renv::restore()
```

---

## Diagnostic Commands

### Check Docker status

```bash
docker --version              # Docker installed?
docker ps                     # Running containers
docker images                 # Available images
docker system df              # Disk usage
```

### Check zzcollab project

```bash
ls -la                        # Project files present?
cat DESCRIPTION               # Check team/project name
cat renv.lock | head          # Package versions
```

### Check R environment

```r
# In R console:
.libPaths()                   # Where packages installed
installed.packages()[,1]      # What's installed
renv::status()                # renv state
```

### Network diagnostics

```bash
ping -c 3 cloud.r-project.org  # Can reach CRAN?
curl -I https://github.com     # GitHub accessible?
```

---

## Getting Help

If issue persists:

1. **Check zzcollab documentation**:
   ```bash
   zzcollab --help
   zzcollab --help-workflow
   zzcollab --help-docker
   zzcollab --help-renv
   ```

2. **Search GitHub issues**:
   https://github.com/rgt47/zzcollab/issues

3. **Ask for help** (include this info):
   - Operating system (macOS/Linux/Windows)
   - Docker version: `docker --version`
   - zzcollab command you ran
   - Complete error message
   - Output of: `docker ps`

4. **Create GitHub issue**:
   https://github.com/rgt47/zzcollab/issues/new

---

## See Also

- [Docker Guide](docker.md) - Understanding Docker concepts and commands
- [Workflow Guide](workflow.md) - Daily development workflow
- [Package Management](renv.md) - Managing R packages with renv
- [Configuration Guide](config.md) - Customize your zzcollab setup
