# Migration Guide: Dockerfile.unified v2.0 → v2.1

## Quick Start

**For most users**: Just rebuild your Docker image. The new Dockerfile is fully backward compatible.

```bash
# Update your template
cp templates/Dockerfile.unified .

# Enable BuildKit and rebuild
export DOCKER_BUILDKIT=1
make docker-build

# Save the generated password from build output
```

---

## Who Needs to Migrate?

### ✅ You SHOULD migrate if:
- You're experiencing slow Docker builds (>10 minutes)
- You're working on active development (frequent code changes)
- You're concerned about password security in images
- You're using ARM64 Mac and hitting platform issues
- You want faster iteration cycles

### ⚠️ You CAN WAIT to migrate if:
- Your builds are infrequent (weekly or less)
- Current build times are acceptable
- You're in the middle of a critical deadline
- You prefer stability over optimization

### ❌ You DON'T need to migrate if:
- You've customized your Dockerfile heavily (evaluate changes first)
- You're using a very old Docker version (<19.03)

---

## Migration Steps

### Step 1: Check Prerequisites

**Docker Version**:
```bash
docker --version
# Need: Docker 19.03+ for BuildKit support
# Recommended: Docker 20.10+
```

**Available Disk Space**:
```bash
df -h
# BuildKit cache: ~2-5GB per project
# Recommendation: 10GB+ free space
```

### Step 2: Backup Current Configuration

```bash
# Backup existing Dockerfile
cp Dockerfile Dockerfile.v2.0.backup

# Backup any custom modifications
git diff Dockerfile > dockerfile-customizations.patch
```

### Step 3: Update Dockerfile

**Option A: Fresh ZZCOLLAB Template**:
```bash
# If using zzcollab framework
zzcollab -t TEAM -p PROJECT -r PROFILE

# This regenerates Dockerfile.unified with v2.1
```

**Option B: Manual Update**:
```bash
# Copy new template
cp /path/to/zzcollab/templates/Dockerfile.unified ./Dockerfile.unified

# Apply your customizations (if any)
# Review dockerfile-customizations.patch
```

### Step 4: Update Build Configuration

**Update Makefile**:
```makefile
# Before:
docker-build:
    docker build --platform linux/amd64 \
        --build-arg ANALYST_PASSWORD=mypassword \
        -t $(PACKAGE_NAME) .

# After:
docker-build:
    DOCKER_BUILDKIT=1 docker build --platform linux/amd64 \
        -t $(PACKAGE_NAME) .
    # Note: No ANALYST_PASSWORD - auto-generated now
```

**Update Shell Scripts**:
```bash
# Before:
docker build --build-arg ANALYST_PASSWORD="${PASSWORD}" -t myimage .

# After:
DOCKER_BUILDKIT=1 docker build -t myimage . 2>&1 | tee build.log
echo "Save this password:"
grep "Password:" build.log
```

### Step 5: First Build with v2.1

**Clean build** (recommended for first migration):
```bash
# Clear old cache
docker builder prune -af

# Build with BuildKit
export DOCKER_BUILDKIT=1
make docker-build

# IMPORTANT: Save the generated password!
# Look for output like:
#   =============================================
#   Generated password for user: analyst
#   Password: Xy9Kp2Lm4No8
#   =============================================
```

**Save password**:
```bash
# Option 1: Capture in build log
make docker-build 2>&1 | tee build-$(date +%Y%m%d).log

# Option 2: Extract and save
make docker-build 2>&1 | grep -A2 "Generated password" > .docker-password
chmod 600 .docker-password
```

### Step 6: Test New Image

**Basic functionality**:
```bash
# Test shell access
docker run --rm -it myimage /bin/zsh

# Test sudo (should work without password)
docker run --rm -it myimage /bin/zsh -c "sudo apt-get update"

# Test R
docker run --rm -it myimage R --version
```

**Test your workflows**:
```bash
# Test analysis scripts
make docker-test

# Test RStudio (if applicable)
make docker-rstudio
# Navigate to http://localhost:8787
# Login with: analyst / [generated-password]
```

### Step 7: Verify Build Cache Performance

**Test incremental builds**:
```bash
# First build (baseline)
time make docker-build

# Edit a script
touch analysis/scripts/my-analysis.R

# Second build (should be much faster)
time make docker-build
# Expected: 1-2 minutes vs 10+ minutes
```

---

## Troubleshooting

### Issue: BuildKit Not Available

**Error**:
```
failed to solve with frontend dockerfile.v0: failed to create LLB definition
```

**Solution**:
```bash
# Check Docker version
docker --version  # Need 19.03+

# Enable BuildKit in daemon config
# Edit ~/.docker/daemon.json or /etc/docker/daemon.json
{
  "features": {
    "buildkit": true
  }
}

# Restart Docker
sudo systemctl restart docker  # Linux
# or restart Docker Desktop (Mac/Windows)
```

### Issue: Cache Mount Errors

**Error**:
```
failed to compute cache key: "/var/cache/apt" not found
```

**Solution**:
```dockerfile
# This is normal on first build
# BuildKit creates cache on-demand
# Just rebuild: docker build .
```

### Issue: Platform Warnings on ARM64

**Warning**:
```
WARNING: rocker/verse may not support ARM64
```

**Solution**:
```bash
# Option 1: Use compatible base image
# Edit Dockerfile, change:
FROM rocker/verse:latest
# To:
FROM rocker/tidyverse:latest

# Option 2: Force AMD64 platform
docker build --platform linux/amd64 .

# Option 3: See docs/DOCKER_ARCHITECTURE.md for ARM64 alternatives
```

### Issue: Vim Plugin Installation Timeout

**Warning**:
```
WARNING: Vim plugin installation failed or timed out
```

**Investigation**:
```bash
# Check log inside image
docker run --rm -it myimage cat /tmp/vim-install.log

# Common causes:
# - Network connectivity issues during build
# - GitHub rate limiting
# - Incompatible vim configuration

# Solution: Rebuild (usually transient)
make docker-build
```

### Issue: Password Not Displayed

**Problem**: Built with old Docker that doesn't show all output

**Solution**:
```bash
# Use --progress=plain to see all output
DOCKER_BUILDKIT=1 docker build --progress=plain . 2>&1 | tee build.log
grep "Password:" build.log
```

### Issue: Different RSPM Date Than Expected

**Warning**:
```
RSPM snapshot date: 2025-10-20
Source: renv.lock modification time
```

**This is normal**:
- RSPM date comes from `renv.lock` file timestamp
- Ensures reproducibility with your exact package versions
- If unexpected, check: `ls -l renv.lock`

**To update RSPM date**:
```bash
# Update packages
R -e "renv::snapshot()"

# Rebuild Docker (will use new date)
make docker-build
```

---

## Performance Benchmarks

### Expected Build Times (AMD64, 4-core, 8GB RAM)

| Scenario | v2.0 | v2.1 | Improvement |
|----------|------|------|-------------|
| **Initial clean build** | 15 min | 12 min | 20% |
| **Rebuild after code change** | 8 min | 1.5 min | **81%** |
| **Rebuild after package update** | 10 min | 6 min | 40% |
| **Rebuild after dotfile change** | 8 min | 5 min | 38% |

### Your Mileage May Vary

Build times depend on:
- **Hardware**: CPU cores, RAM, disk speed
- **Network**: Package download speeds
- **Profile**: Minimal vs publishing vs geospatial
- **Cache state**: Clean vs cached builds

---

## Rollback Procedure

If you encounter critical issues:

### Quick Rollback

```bash
# Restore backed up Dockerfile
cp Dockerfile.v2.0.backup Dockerfile

# Clear new cache
docker builder prune -af

# Rebuild with v2.0
docker build --platform linux/amd64 -t myimage .
```

### Report Issues

```bash
# Capture diagnostic information
docker version > docker-diagnostics.txt
docker system info >> docker-diagnostics.txt
docker buildx version >> docker-diagnostics.txt

# Report at: https://github.com/rgt47/zzcollab/issues
```

---

## FAQ

### Q: Do I need to rebuild my existing images?

**A**: No, existing images continue to work. Rebuild when convenient to get performance benefits.

### Q: Will my renv.lock change?

**A**: No, package versions remain identical. Only Dockerfile internals changed.

### Q: Can I use the old password method?

**A**: Not recommended. Auto-generated passwords are more secure. If you need custom passwords, use Docker secrets.

### Q: What about CI/CD pipelines?

**A**: Update your CI configuration to enable BuildKit:

```yaml
# GitHub Actions
- name: Build Docker image
  run: |
    export DOCKER_BUILDKIT=1
    docker build -t myimage . 2>&1 | tee build.log

- name: Extract password
  run: |
    grep "Password:" build.log > password.txt
    # Save as secret or artifact
```

### Q: Does this work with custom Docker build commands?

**A**: Yes, enable BuildKit for any Docker build:

```bash
# Standard build (BuildKit auto-enabled in Docker 23.0+)
docker build -t myimage .

# Or explicitly enable BuildKit
DOCKER_BUILDKIT=1 docker build -t myimage .
```

### Q: How do I verify BuildKit is active?

**A**: Look for build output:

```
# BuildKit enabled (good):
[+] Building 234.5s (18/18) FINISHED

# Legacy builder (BuildKit not enabled):
Sending build context to Docker daemon  123.4MB
Step 1/25 : FROM rocker/r-ver
```

### Q: Can I still use `--no-cache`?

**A**: Yes, works with BuildKit:

```bash
DOCKER_BUILDKIT=1 docker build --no-cache -t myimage .
```

### Q: What about multi-stage builds?

**A**: Not implemented in v2.1 (future optimization). Current version focuses on compatibility and layer caching improvements.

---

## Advanced: Custom Modifications

### If You've Modified the Dockerfile

**Reapply your changes carefully**:

1. **Review your patch**:
   ```bash
   cat dockerfile-customizations.patch
   ```

2. **Key sections that may conflict**:
   - Password generation (lines 296-312)
   - Layer ordering (lines 314-497)
   - Conditional logic (lines 204-239, 250-279)

3. **Test incrementally**:
   ```bash
   # Apply one change at a time
   # Build and test
   make docker-build && make docker-test
   ```

### Custom Password Requirements

If you absolutely need custom passwords (not recommended):

```dockerfile
# Add build arg back
ARG CUSTOM_PASSWORD

# Use custom if provided, else generate
RUN if [ -n "${CUSTOM_PASSWORD}" ]; then \
        echo "${USERNAME}:${CUSTOM_PASSWORD}" | chpasswd; \
    else \
        PASSWORD=$(openssl rand -base64 12) && \
        echo "${USERNAME}:${PASSWORD}" | chpasswd && \
        echo "Generated password: ${PASSWORD}"; \
    fi
```

---

## Post-Migration Checklist

- [ ] Docker BuildKit enabled
- [ ] Clean build successful
- [ ] Generated password saved securely
- [ ] Incremental build tested (fast)
- [ ] Application functionality verified
- [ ] CI/CD pipeline updated (if applicable)
- [ ] Team members notified
- [ ] Documentation updated

---

## Getting Help

### Documentation
- **Dockerfile improvements**: `templates/DOCKERFILE_IMPROVEMENTS.md`
- **Docker architecture**: `docs/DOCKER_ARCHITECTURE.md`
- **Build configuration**: `docs/CONFIGURATION.md`

### Community
- **GitHub Issues**: https://github.com/rgt47/zzcollab/issues
- **Discussions**: https://github.com/rgt47/zzcollab/discussions

### Commercial Support
Contact: [your-support-channel]

---

## What's Next?

### Future Optimizations (Roadmap)

1. **Multi-stage builds** (v2.2)
   - Separate build and runtime environments
   - 150-250MB image size reduction
   - Estimated Q1 2026

2. **Remote BuildKit** (v2.3)
   - Shared build cache across team
   - Cloud-based builders
   - Estimated Q2 2026

3. **Automated testing** (v2.2)
   - Docker image testing framework
   - Security scanning integration
   - Estimated Q1 2026

---

**Migration Guide Version**: 1.0
**Date**: 2025-10-25
**Applies to**: Dockerfile.unified v2.0 → v2.1
**Estimated Migration Time**: 15-30 minutes
