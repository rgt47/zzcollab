# ZZCOLLAB Workflow Type System - Implementation Summary

## What Was Changed

### 1. **profiles.yaml** - Added `workflow_type` field to all profiles

Each profile now declares which CI/CD workflow it uses:

```yaml
ubuntu_x11_analysis:
  base_image: "rocker/tidyverse:latest"
  workflow_type: "blog"           # ← NEW FIELD
  packages:
    - "renv"
    # ...
```

**Profiles Updated:**
- ✅ `ubuntu_standard_minimal` → `package-dev`
- ✅ `ubuntu_standard_analysis` → `analysis`
- ✅ `ubuntu_standard_publishing` → `blog`
- ✅ `ubuntu_shiny_minimal` → `shiny`
- ✅ `ubuntu_shiny_analysis` → `shiny`
- ✅ `ubuntu_x11_minimal` → `analysis`
- ✅ `ubuntu_x11_analysis` → `blog`
- ✅ `alpine_standard_minimal` → `package-dev`
- ✅ `alpine_standard_analysis` → `analysis`
- ✅ `alpine_x11_minimal` → `analysis`
- ✅ `alpine_x11_analysis` → `analysis`

### 2. **config.yaml** - Added workflow type documentation

Updated the `DOCKER PROFILES CONFIGURATION` section with comprehensive guidance on workflow types:

```yaml
# WORKFLOW TYPE MAPPING (Automatic CI/CD Setup):
# Each profile declares a workflow_type that determines which GitHub Actions
# workflow will be installed...
#
#   workflow_type: "blog"        → r-package-blog.yml
#     Use for: Blog posts, tutorials, Quarto reports
#     Includes: validation, tests, scripts, Quarto rendering, artifact upload
```

### 3. **Created install-workflows.sh** - Automatic workflow installer

New script at: `templates/scripts/install-workflows.sh`

**Functionality:**
- Reads `config.yaml` to find enabled profiles
- Looks up `workflow_type` in `profiles.yaml`
- Copies appropriate workflow to `.github/workflows/r-package.yml`
- Removes legacy `render-paper.yml`
- Supports `--dry-run` and `--verbose` modes

**Usage:**
```bash
./scripts/install-workflows.sh
./scripts/install-workflows.sh --dry-run --verbose
```

### 4. **Created WORKFLOW_TYPE_SYSTEM.md** - Complete documentation

Comprehensive guide covering:
- Overview of the 4 workflow types
- When to use each type
- Installation instructions
- Profile-to-workflow mapping table
- Configuration details
- Troubleshooting
- Advanced custom profiles

---

## Workflow Types Defined

### 1. **package-dev**
For: R package development, CRAN submission
Workflow: `r-package-dev.yml`
Steps: Docker build → packages → validate → tests → R CMD check

### 2. **analysis**
For: Data analysis, scripts, exploratory work
Workflow: `r-package-analysis.yml`
Steps: Docker build → packages → validate → tests → scripts → verify outputs

### 3. **blog** ⭐ (Used by all 60 qblog posts)
For: Blog posts, tutorials, Quarto reports
Workflow: `r-package-blog.yml`
Steps: Docker build → packages → validate → tests → scripts → **render Quarto** → upload artifact

### 4. **shiny**
For: Shiny web applications
Workflow: `r-package-shiny.yml`
Steps: Docker build → packages → validate → tests → validate app structure

---

## For Your 60 Blog Posts

**Status:** ✅ Ready to integrate

**Current Configuration:**
- Profile: `ubuntu_x11_analysis`
- Workflow Type: `blog`
- Dockerfile: Already distributed ✅
- Workflow: Already distributed ✅
- Render-paper.yml: Already deleted ✅

**To Complete Integration:**

1. **One-time zzcollab update** (in main zzcollab repo):
   ```bash
   cd ~/Dropbox/prj/d07/zzcollab
   git add templates/profiles.yaml templates/config.yaml templates/scripts/install-workflows.sh
   git add WORKFLOW_TYPE_SYSTEM.md IMPLEMENTATION_SUMMARY.md
   git commit -m "Add automatic workflow type system"
   git push
   ```

2. **Future New Posts:**
   ```bash
   # When initializing a new blog post:
   cd new_post/
   ../../scripts/install-workflows.sh  # Automatic!
   ```

---

## Architecture Overview

```
zzcollab/ (main repo)
├── templates/
│   ├── profiles.yaml
│   │   ├── ubuntu_x11_analysis
│   │   │   ├── base_image: rocker/tidyverse
│   │   │   └── workflow_type: "blog"    ← Declares which workflow
│   │   ├── [10 other profiles...]
│   │
│   ├── config.yaml
│   │   └── [NEW] Workflow type documentation
│   │
│   ├── scripts/
│   │   └── install-workflows.sh         ← NEW! Automatic installer
│   │
│   └── workflows/
│       ├── r-package-blog.yml           ← Blog posts + Quarto rendering
│       ├── r-package-analysis.yml       ← Data analysis scripts
│       ├── r-package-dev.yml            ← R package development
│       └── r-package-shiny.yml          ← Shiny apps

blog_post_repo/
├── Dockerfile (points to ubuntu_x11_analysis)
├── renv.lock (unique to this post)
├── .github/workflows/
│   └── r-package.yml (auto-installed as r-package-blog.yml)
└── ...
```

---

## Key Benefits

✅ **Self-Documenting:** Profile declares its own workflow type

✅ **Automatic Setup:** No manual workflow selection needed

✅ **Maintainable:** One place to update CI/CD logic (templates/workflows/)

✅ **Consistent:** All projects of same type use identical workflow

✅ **Type-Appropriate:** Blog projects don't run R CMD check; packages don't render Quarto

✅ **Scalable:** Adding 100 new blogs is as easy as copying profiles

✅ **Extensible:** Easy to add new workflow types for new project categories

---

## Testing Checklist

- [x] Added `workflow_type` to all 11 profiles in profiles.yaml
- [x] Updated config.yaml documentation
- [x] Created install-workflows.sh script with error handling
- [x] Made script executable
- [x] Script validates config.yaml exists
- [x] Script validates profiles.yaml exists
- [x] Script handles missing workflow templates gracefully
- [x] Script supports --dry-run mode for testing
- [x] Script supports --verbose for debugging
- [x] Script removes legacy render-paper.yml
- [x] Created comprehensive documentation (WORKFLOW_TYPE_SYSTEM.md)
- [x] All 60 qblog posts already have correct setup
  - Dockerfile: ✅ ubuntu_x11_analysis
  - Workflow: ✅ r-package-blog.yml
  - renv.lock: ✅ Unique per post

---

## Files Modified

### In zzcollab/templates/

1. **profiles.yaml**
   - Added `workflow_type:` field to all 11 profiles
   - ✅ Changes integrated

2. **config.yaml**
   - Added "WORKFLOW TYPE MAPPING" section (lines 32-53)
   - Documents all 4 workflow types
   - Explains automatic workflow installation
   - ✅ Changes integrated

### Files Created

1. **templates/scripts/install-workflows.sh**
   - Automatic workflow installer (250+ lines)
   - Reads config.yaml + profiles.yaml
   - Copies appropriate workflow to .github/workflows/
   - Deletes legacy render-paper.yml
   - Supports --dry-run, --verbose flags
   - ✅ Created and tested

2. **WORKFLOW_TYPE_SYSTEM.md**
   - Complete documentation (350+ lines)
   - Usage guide for all 4 workflow types
   - Installation instructions
   - Profile mapping table
   - Troubleshooting section
   - ✅ Created

3. **IMPLEMENTATION_SUMMARY.md** (this file)
   - Overview of changes
   - Architecture diagram
   - Testing checklist
   - Next steps
   - ✅ Created

---

## Next Steps

### Immediate (zzcollab repo)

```bash
cd ~/Dropbox/prj/d07/zzcollab

# Review changes
git status
git diff templates/profiles.yaml  # See workflow_type additions
git diff templates/config.yaml    # See documentation

# Commit to zzcollab
git add templates/profiles.yaml templates/config.yaml
git add templates/scripts/install-workflows.sh
git add WORKFLOW_TYPE_SYSTEM.md IMPLEMENTATION_SUMMARY.md
git commit -m "Add automatic workflow type system

- Each profile declares workflow_type (blog, analysis, package-dev, shiny)
- New install-workflows.sh automates workflow installation
- Comprehensive documentation in WORKFLOW_TYPE_SYSTEM.md
- config.yaml updated with workflow type mapping
- All 11 profiles updated with appropriate workflow_type"
git push
```

### For qblog (blog posts)

All 60 posts are already configured:
- ✅ Dockerfile (ubuntu_x11_analysis)
- ✅ renv.lock (unique per post)
- ✅ .github/workflows/r-package.yml (blog type)
- ✅ render-paper.yml (deleted)

No additional action needed! The system is ready to use.

### For Other Projects

When initializing new ZZCOLLAB projects:

```bash
# 1. Use zzcollab to initialize project with desired profile
zzcollab init --profile ubuntu_x11_analysis myproject

# 2. Install appropriate workflow (automatic)
cd myproject
./scripts/install-workflows.sh

# 3. Done! Workflow is installed based on profile
```

---

## Documentation References

- **Quick Start:** See "Installation" section in WORKFLOW_TYPE_SYSTEM.md
- **Detailed Guide:** Full WORKFLOW_TYPE_SYSTEM.md (this repo)
- **Troubleshooting:** "Troubleshooting" section in WORKFLOW_TYPE_SYSTEM.md
- **For Maintainers:** "For zzcollab Maintainers" section in WORKFLOW_TYPE_SYSTEM.md

---

*Implementation completed: 2025-12-12*

*Part of ZZCOLLAB: Reproducible Research Compendium Framework*

*Enables automatic, type-appropriate CI/CD workflow selection based on Docker profile*
