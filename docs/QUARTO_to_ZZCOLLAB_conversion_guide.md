# Converting a Standard Quarto Blog Post to a ZZCOLLAB Reproducible Research Compendium

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Understand Current Structure](#step-1-understand-current-structure)
4. [Step 2: Plan Directory Reorganization](#step-2-plan-directory-reorganization)
5. [Step 3: Create ZZCOLLAB Directory Structure](#step-3-create-zzcollab-directory-structure)
6. [Step 4: Migrate Files](#step-4-migrate-files)
7. [Step 5: Create Configuration Files](#step-5-create-configuration-files)
8. [Step 6: Set Up Dual-Symlink System](#step-6-set-up-dual-symlink-system)
9. [Step 7: Update Image and Media Paths](#step-7-update-image-and-media-paths)
10. [Step 8: Initialize Git and Commit](#step-8-initialize-git-and-commit)
11. [Step 9: Verify and Test](#step-9-verify-and-test)
12. [Troubleshooting](#troubleshooting)
13. [Best Practices](#best-practices)

---

## Overview

### What is ZZCOLLAB?

ZZCOLLAB is a research collaboration framework that transforms blog posts and research projects into **reproducible research compendia**. It combines:

- **Docker**: For reproducible computational environments
- **renv**: For frozen R package versions
- **Quarto**: For publishing and rendering
- **Unified Research Compendium**: Following the rrtools framework structure

### Why Convert Your Blog Post?

A standard Quarto blog post is a good start, but converting it to ZZCOLLAB provides:

- **Complete Reproducibility**: Readers can clone, build, and reproduce your blog post exactly
- **Professional Structure**: Organized analysis pipeline with data, scripts, figures, media
- **Automation**: Makefile targets for building, rendering, previewing
- **Version Control**: Git-tracked environment specifications
- **Scalability**: Easy to extend with analysis scripts and derived data
- **Team Collaboration**: Foundation for sharing blog posts as full projects

### This Guide Covers

A complete, detailed walkthrough of converting a standard Quarto blog post to ZZCOLLAB, using the `ls_since_utility` blog post as both:
- A **real working example** of a converted blog post
- A **template** for converting other blog posts

---

## Prerequisites

### Required Tools

- **Docker**: Installed and running
- **Git**: For version control
- **Make**: For build automation (usually pre-installed on macOS/Linux)
- **Shell access**: bash or zsh (for symlink creation)
- **Text editor**: Any editor for modifying files

### Optional but Recommended

- **Quarto**: For local rendering (installation: `brew install quarto`)
- **R**: For local renv management (though Docker makes this optional)

### File Structure Knowledge

Understand these key concepts:
- **Symlinks**: Filesystem links pointing to other locations
- **YAML front matter**: Metadata at top of Quarto documents
- **Docker basics**: Images, Containers, build context
- **Git**: Add, commit, branch operations

---

## Step 1: Understand Current Structure

### Examine Your Existing Blog Post

Before making changes, document what you currently have:

```bash
cd ~/path/to/your/blog/post
tree -L 2  # View directory structure (install: brew install tree)
```

### Expected Current Structure

A typical Quarto blog post might look like:

```
your-blog-post/
├── index.qmd                    # Main blog post
├── README.md                    # Documentation
├── figures/                     # Generated plots (possibly empty)
└── media/                       # Media assets
    ├── images/
    │   ├── hero-image.jpg
    │   └── supporting-image.png
    ├── audio/                   # Possibly empty
    └── video/                   # Possibly empty
```

### Key Characteristics to Note

Document these aspects of your current post:

| Aspect | What to Check |
|--------|---|
| **Blog post file** | Location of main `.qmd` file |
| **Image count** | How many images and where stored |
| **Image references** | How are they referenced in the post (`![](path)`) |
| **Media types** | Any video, audio, or other media |
| **Code examples** | Does the post include executable code |
| **External dependencies** | Does it need specific R packages |
| **Data files** | Any raw or derived data |
| **Generation scripts** | Any scripts that generate outputs |

### Example: Current ls_since_utility Structure

```
ls_since_utility/
├── index.qmd                    (17 KB blog post)
├── README.md                    (4.6 KB project docs)
├── figures/                     (empty)
└── media/                       (22 MB total)
    ├── create_hero.sh          (image generation script)
    ├── ls_since_hero.png        (1.4 MB)
    ├── flat-workspace-office-concept.png (756 KB)
    ├── rob-wingate-*.jpg        (8.5 MB)
    └── technology-unicorn-*.jpg (12 MB)
```

---

## Step 2: Plan Directory Reorganization

### ZZCOLLAB Target Structure

The unified research compendium structure organizes content as follows:

```
your-blog-post/
├── analysis/                    # All research content
│   ├── paper/                   # Blog post manuscript
│   │   ├── index.qmd           # Main blog post (moved here)
│   │   ├── figures/            # Symlink to ../figures
│   │   ├── media/              # Symlink to ../media
│   │   └── data/               # Symlink to ../data
│   ├── figures/                # Generated plots
│   │   └── (empty placeholder for now)
│   ├── media/                  # Static media assets
│   │   ├── images/             # All images moved here
│   │   ├── audio/              # Podcasts, narration
│   │   └── video/              # Demos, tutorials
│   ├── scripts/                # Analysis and generation scripts
│   │   └── (moved scripts here)
│   └── data/                   # Data files
│       ├── raw_data/           # Original data (read-only)
│       └── derived_data/       # Processed outputs
│
├── R/                          # Reusable functions (optional)
│   └── (empty initially)
├── modules/                    # ZZCOLLAB framework
│   └── (symlinks to zzcollab)
├── tests/                      # Testing (optional for blogs)
│   └── testthat/
│
├── Symlinks at Root (Quarto Compatibility)
│   ├── index.qmd → analysis/paper/index.qmd
│   ├── figures → analysis/figures
│   ├── media → analysis/media
│   └── data → analysis/data
│
├── Configuration Files
│   ├── Dockerfile              # Environment spec
│   ├── renv.lock               # Package versions
│   ├── .Rprofile               # R session config
│   ├── DESCRIPTION             # Package metadata
│   ├── NAMESPACE               # Package namespace
│   ├── Makefile                # Build automation
│   ├── .gitignore              # Git exclusions
│   └── LICENSE                 # License file
│
└── Documentation
    ├── README.md               # Project guide
    └── docs/                   # Additional docs
        └── README.md           # Original docs
```

### Mapping the Migration

Create a detailed mapping of where files move:

```
CURRENT → ZZCOLLAB

index.qmd → analysis/paper/index.qmd
README.md → docs/README.md (keep copy at root)
media/*.jpg → analysis/media/images/
media/*.png → analysis/media/images/
media/create_hero.sh → analysis/scripts/
figures/ → analysis/figures/ (keep structure)
```

### Understanding the Dual-Symlink System

The conversion uses a clever dual-symlink system to satisfy two requirements:

**Requirement 1**: Quarto expects `index.qmd` at the post root
- Solution: Symlink `index.qmd` → `analysis/paper/index.qmd`

**Requirement 2**: When editing in `analysis/paper/`, paths should be intuitive
- Solution: Create symlinks inside `analysis/paper/` pointing back out
  - `analysis/paper/figures` → `../figures`
  - `analysis/paper/media` → `../media`
  - `analysis/paper/data` → `../data`

**Result**: Both locations work seamlessly

```
From Quarto's perspective:       From editor's perspective:
index.qmd exists at root         Editing analysis/paper/index.qmd
figures/ exists at root          Can reference figures/, media/, data/
media/ exists at root            directly in markdown
data/ exists at root

Path resolution works in both contexts!
```

---

## Step 3: Create ZZCOLLAB Directory Structure

### Create All Required Directories

```bash
cd /path/to/your/blog/post

# Create the main analysis directory structure
mkdir -p analysis/paper
mkdir -p analysis/figures
mkdir -p analysis/scripts
mkdir -p analysis/data/raw_data
mkdir -p analysis/data/derived_data
mkdir -p analysis/media/images
mkdir -p analysis/media/audio
mkdir -p analysis/media/video

# Create documentation directory
mkdir -p docs

# Create optional R and test directories
mkdir -p R
mkdir -p tests/testthat
```

### Verify Structure Created

```bash
# View the created structure
tree -L 3 analysis/

# Expected output:
# analysis/
# ├── data
# │   ├── derived_data
# │   └── raw_data
# ├── figures
# ├── media
# │   ├── audio
# │   ├── images
# │   └── video
# ├── paper
# └── scripts
```

### Why This Structure?

| Directory | Purpose | Why Needed |
|-----------|---------|-----------|
| `analysis/paper/` | Blog post manuscript | Consistent with rrtools compendium pattern |
| `analysis/figures/` | Generated plots | R scripts output plots here |
| `analysis/media/images/` | Static images | Hero images, photos, diagrams |
| `analysis/media/audio/` | Audio files | Future podcasts or narration |
| `analysis/media/video/` | Video files | Demos or walkthroughs |
| `analysis/scripts/` | Analysis code | Scripts that generate outputs |
| `analysis/data/raw_data/` | Original data | Immutable, read-only source |
| `analysis/data/derived_data/` | Processed data | Output from analysis scripts |

---

## Step 4: Migrate Files

### Step 4.1: Migrate Blog Post

```bash
# Move the main blog post to analysis/paper/
mv index.qmd analysis/paper/index.qmd

# Verify
ls -la analysis/paper/index.qmd
# Output: -rw-r--r-- 1 user staff 17300 Dec 2 17:28 analysis/paper/index.qmd
```

**What you're doing**: Placing the blog post content in the standard location for manuscripts in the unified research compendium pattern.

### Step 4.2: Migrate Media Files

```bash
# Move all image files to analysis/media/images/
# Assuming images are currently in media/ or media/images/

# If images are directly in media/:
mv media/*.jpg media/*.png analysis/media/images/ 2>/dev/null

# If already in media/images/:
mv media/images/* analysis/media/images/

# Verify
ls -la analysis/media/images/
# Should show all image files
```

**Common image file patterns to handle**:
- `.jpg`, `.jpeg` - JPEG photos
- `.png` - PNG images with transparency
- `.gif` - Animated GIFs
- `.webp` - Modern web format
- `.svg` - Vector graphics

### Step 4.3: Migrate Scripts

```bash
# Move any generation or utility scripts
mv media/create_hero.sh analysis/scripts/

# If scripts are executable, ensure permissions
chmod +x analysis/scripts/create_hero.sh

# Verify
ls -la analysis/scripts/
```

**Common script patterns**:
- `create_*.sh` - Generation scripts
- `01_prepare.R`, `02_analyze.R`, etc. - Numbered analysis pipeline

### Step 4.4: Clean Up Old Directories

```bash
# Remove old top-level directories that are now empty
rm -rf media
rm -rf figures

# Remove old rendered artifacts that will be regenerated
rm -f index.pdf
rm -f index.html

# Verify only expected items remain at root
ls -la
```

**Be careful**: Only delete empty directories. If there's content you missed, restore it first.

### Verification Checkpoint

```bash
# Quick verification of migration
echo "=== Checking migration ==="
echo "Blog post:"
ls -lh analysis/paper/index.qmd
echo ""
echo "Media files:"
ls -1 analysis/media/images/ | head -5
echo ""
echo "Scripts:"
ls -1 analysis/scripts/
echo ""
echo "Old dirs removed:"
ls -1 | grep -E "^(media|figures)$" && echo "ERROR: Old dirs still exist" || echo "✓ Clean"
```

---

## Step 5: Create Configuration Files

### Step 5.1: Create DESCRIPTION File

The DESCRIPTION file is R package metadata that documents your project:

```yaml
Package: your-blog-post-name
Title: Blog Post - [Your Blog Post Title]
Version: 0.0.1
Author: Your Name
Maintainer: Your Name <your.email@example.com>
Description: [One-sentence description of your blog post and its topic]
License: GPL-3
Depends:
    R (>= 4.0.0)
Suggests:
    testthat (>= 3.0.0),
    rmarkdown,
    quarto
Encoding: UTF-8
LazyData: true
```

**For the ls_since_utility example**:

```yaml
Package: ls_since_blog
Title: Blog Post - ls_since.sh Utility
Version: 0.0.1
Author: Research Computing Infrastructure
Maintainer: Research Computing Infrastructure <your.email@example.com>
Description: Reproducible blog post about ls_since.sh, an advanced file date filtering utility for research computing.
License: GPL-3
Depends:
    R (>= 4.0.0)
Suggests:
    testthat (>= 3.0.0),
    rmarkdown,
    quarto
Encoding: UTF-8
LazyData: true
```

**Why DESCRIPTION?**
- Documents project metadata
- Lists dependencies (even though this is a blog, it maintains the structure)
- Makes the directory conform to R package standards
- Enables renv management

### Step 5.2: Create NAMESPACE File

The NAMESPACE file is minimal for blog posts (no functions to export):

```r
# Namespace file for your-blog-post package
# This is a blog post project - no functions exported
```

**Why NAMESPACE?**
- Part of R package structure
- Required by build system
- Can be extended if you add reusable R functions later

### Step 5.3: Create Dockerfile

The Dockerfile specifies the computational environment:

```dockerfile
FROM rocker/rstudio:latest

# Install Quarto
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    quarto \
    && rm -rf /var/lib/apt/lists/*

# Copy renv infrastructure
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile

# Activate renv and restore packages on R startup
RUN R --vanilla --slave -e 'renv::restore()'

# Set working directory
WORKDIR /project

# Default command
CMD ["R"]
```

**Key decisions**:

| Element | Choice | Why |
|---------|--------|-----|
| **Base image** | `rocker/rstudio:latest` | Includes R, RStudio, system dependencies |
| **Add Quarto** | Yes, explicit install | Ensures Quarto is available |
| **renv activation** | Yes, auto-restore | Freezes package versions |
| **WORKDIR** | `/project` | Standard mount point |

**Alternative base images**:
- `rocker/r-ver:4.4.0` - Lightweight, specific R version
- `rocker/verse:latest` - Includes LaTeX for PDF rendering
- `rocker/tidyverse:latest` - Pre-includes popular packages

### Step 5.4: Create .Rprofile

The .Rprofile configures R session behavior and enables auto-snapshot:

```r
# Configure R session options for reproducibility
options(
  stringsAsFactors = FALSE,
  contrasts = c("contr.treatment", "contr.poly"),
  na.action = "na.omit",
  digits = 7,
  OutDec = "."
)

# Set locale and timezone for reproducibility
Sys.setenv(LANG = "en_US.UTF-8")
Sys.setenv(LC_ALL = "en_US.UTF-8")
Sys.setlocale("LC_TIME", "en_US.UTF-8")
Sys.setenv(TZ = "UTC")

# Suppress scientific notation for readability
options(scipen = 999)

# Initialize renv
source("renv/activate.R")

# Auto-snapshot on R exit
.Last <- function() {
  if (!is.null(getOption("ZZCOLLAB_AUTO_SNAPSHOT"))) {
    if (getOption("ZZCOLLAB_AUTO_SNAPSHOT")) {
      tryCatch({
        renv::snapshot(prompt = FALSE, type = "implicit")
      }, error = function(e) {
        message("Warning: Could not auto-snapshot renv")
      })
    }
  } else {
    # Default: auto-snapshot enabled
    tryCatch({
      renv::snapshot(prompt = FALSE, type = "implicit")
    }, error = function(e) {
      message("Warning: Could not auto-snapshot renv")
    })
  }
}
```

**What this does**:

| Setting | Purpose |
|---------|---------|
| `stringsAsFactors = FALSE` | Prevents automatic factor conversion |
| `contrasts` | Specifies contrast coding for models |
| `na.action = "na.omit"` | Consistent missing value handling |
| `digits = 7` | Output precision |
| `OutDec = "."` | Decimal separator (not comma) |
| **Locale/TZ** | Ensures consistent date/time handling |
| **renv activation** | Loads frozen package environment |
| **.Last() function** | Auto-snapshots renv when R exits |

### Step 5.5: Create renv.lock

The renv.lock file freezes exact R package versions. For a blog post with no R code, a minimal version:

```json
{
  "R": {
    "Version": "4.4.0",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cloud.r-project.org"
      }
    ]
  },
  "Packages": {
    "renv": {
      "Package": "renv",
      "Version": "1.0.7",
      "Source": "Repository",
      "Repository": "CRAN",
      "Requirements": [],
      "Hash": "abc123..."
    }
  }
}
```

**If your blog includes R code**:
1. Create the file with a baseline version
2. Run `renv::init()` in R to generate full lockfile
3. Install packages with `install.packages()`
4. On exit, `.Rprofile` auto-snapshots the lockfile

### Step 5.6: Create Makefile

The Makefile provides convenient build targets:

```makefile
.PHONY: help docker-build docker-sh docker-rstudio docker-post-render \
         docker-post-preview post-render clean check-renv test

# Variables
DOCKER_IMAGE ?= your-blog-post:latest
DOCKER_BUILDKIT ?= 1
PROJECT_DIR := $(shell pwd)

# Help
help:
	@echo "ZZCOLLAB Blog Post: [Your Blog Title]"
	@echo ""
	@echo "Available targets:"
	@echo "  docker-build          Build Docker image"
	@echo "  docker-sh             Start container with shell access"
	@echo "  docker-rstudio        Start RStudio Server (localhost:8787)"
	@echo "  docker-post-render    Build image, render blog post in container"
	@echo "  docker-post-preview   Start interactive preview (localhost:8080)"
	@echo "  post-render           Render blog post (requires Quarto locally)"
	@echo "  check-renv            Validate renv configuration"
	@echo "  clean                 Remove generated files and Docker images"
	@echo "  help                  Show this help message"

# Docker build target
docker-build:
	docker build -t $(DOCKER_IMAGE) \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-f Dockerfile .
	@echo "Docker image built: $(DOCKER_IMAGE)"

# Interactive shell in container
docker-sh: docker-build
	docker run --rm -it \
		-v "$(PROJECT_DIR):/project" \
		-w /project \
		$(DOCKER_IMAGE) \
		/bin/bash

# RStudio Server in container
docker-rstudio: docker-build
	@echo "Starting RStudio Server at http://localhost:8787"
	docker run --rm -d \
		-p 8787:8787 \
		-e DISABLE_AUTH=true \
		-v "$(PROJECT_DIR):/project" \
		-w /project \
		--name your-post-rstudio \
		$(DOCKER_IMAGE)

# Render blog post in container
docker-post-render: docker-build
	docker run --rm \
		-v "$(PROJECT_DIR):/project" \
		-w /project \
		$(DOCKER_IMAGE) \
		quarto render analysis/paper/index.qmd
	@echo "Blog post rendered"

# Preview blog post in container
docker-post-preview: docker-build
	docker run --rm \
		-p 8080:8080 \
		-v "$(PROJECT_DIR):/project" \
		-w /project \
		$(DOCKER_IMAGE) \
		quarto preview analysis/paper/index.qmd --host 0.0.0.0 --port 8080

# Local render (requires Quarto installed)
post-render:
	quarto render analysis/paper/index.qmd

# Validate renv setup
check-renv:
	@echo "Checking renv configuration..."
	@[ -f "renv.lock" ] && echo "✓ renv.lock found" || echo "✗ renv.lock missing"
	@[ -f ".Rprofile" ] && echo "✓ .Rprofile found" || echo "✗ .Rprofile missing"

# Clean generated files
clean:
	rm -f analysis/paper/index.html
	rm -rf analysis/paper/*_files/
	docker rmi $(DOCKER_IMAGE) 2>/dev/null || true

.DEFAULT_GOAL := help
```

**Key Make targets**:
- `docker-build` - Build reproducible environment
- `docker-sh` - Develop inside container
- `docker-post-render` - Full pipeline in container
- `docker-post-preview` - Live preview at localhost:8080
- `post-render` - Local rendering (needs Quarto)

### Step 5.7: Create .gitignore

The .gitignore prevents committing generated files:

```gitignore
# Quarto rendered output (regenerated from source)
*.html
*_files/
_freeze/

# R artifacts
.Rhistory
.RData
.Rproj.user/
*.Rproj

# renv artifacts
renv/library/
renv/python/

# OS files
.DS_Store
Thumbs.db

# IDE artifacts
.vscode/
.idea/
*.swp

# Docker
.dockerignore

# Temporary files
*.tmp
*.bak

# Large media files (use Git LFS for these)
*.mp4
*.mp3
*.mov

# Do NOT ignore symlinks - they're part of the structure
!index.qmd
!figures
!media
!data
```

**Key patterns**:
- **HTML files**: Regenerated from `.qmd`, don't commit
- **R artifacts**: Session history, RData, etc.
- **renv/library**: Recreated during restore
- **Symlinks**: Keep with `!` patterns

### Step 5.8: Create LICENSE

Choose a license appropriate for your project. For GPL-3:

```
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2025 Your Name

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

**License options**:
- **GPL-3**: For research/open source projects
- **MIT**: Permissive, good for libraries
- **CC-BY-4.0**: For content/writing
- **Apache 2.0**: With patent protection

---

## Step 6: Set Up Dual-Symlink System

### Understanding Symlinks

A symlink is a filesystem shortcut that points to another location:

```bash
# Create symlink: ln -s TARGET LINK
ln -s analysis/figures figures
# Creates: figures → analysis/figures
```

When you access `figures/`, the OS transparently redirects to `analysis/figures/`.

### Step 6.1: Create Root-Level Symlinks

These symlinks make content accessible from the post root (for Quarto):

```bash
cd /path/to/your/blog/post

# Create symlinks from root to analysis/ subdirectories
ln -s analysis/paper/index.qmd index.qmd
ln -s analysis/figures figures
ln -s analysis/media media
ln -s analysis/data data

# Verify symlinks created
ls -la | grep "^l"
```

**Expected output**:
```
lrwxr-xr-x  1 user staff   24 Dec 2 17:48 index.qmd -> analysis/paper/index.qmd
lrwxr-xr-x  1 user staff   16 Dec 2 17:48 figures -> analysis/figures
lrwxr-xr-x  1 user staff   14 Dec 2 17:48 media -> analysis/media
lrwxr-xr-x  1 user staff   13 Dec 2 17:48 data -> analysis/data
```

**Why root symlinks?**
- Quarto expects `index.qmd` at post root
- Image paths like `![](figures/plot.png)` work from root
- Media references work transparently

### Step 6.2: Create analysis/paper Symlinks

These symlinks enable intuitive editing inside the paper directory:

```bash
cd /path/to/your/blog/post/analysis/paper

# Create symlinks from paper/ back to parent analysis/ directories
ln -s ../figures figures
ln -s ../media media
ln -s ../data data

# Verify
ls -la | grep "^l"
```

**Expected output**:
```
lrwxr-xr-x 1 user staff     7 Dec 2 17:48 data -> ../data
lrwxr-xr-x 1 user staff    10 Dec 2 17:48 figures -> ../figures
lrwxr-xr-x 1 user staff     8 Dec 2 17:48 media -> ../media
```

**Why paper symlinks?**
- When editing `analysis/paper/index.qmd`, paths are short and intuitive
- Write `![](figures/plot.png)` instead of `![](../../figures/plot.png)`
- Symlinks resolve transparently

### The Dual-Link Resolution System

```
File access from two locations:

QUARTO (rendering):
  index.qmd (root) → calls ![](media/images/plot.png)
  Resolution: root/media → analysis/media ✓

EDITOR (writing):
  analysis/paper/index.qmd → calls ![](media/images/plot.png)
  Resolution: analysis/paper/media → ../media → analysis/media ✓

Both paths resolve to the same physical location!
```

### Verifying Symlink System

```bash
# Test that symlinks resolve correctly
cd /path/to/your/blog/post

# From root, should access analysis/figures
ls figures/
# Lists content of analysis/figures/

# From analysis/paper, should also access analysis/figures
cd analysis/paper
ls figures/
# Lists same content

cd ../..
echo "Symlink system verified ✓"
```

---

## Step 7: Update Image and Media Paths

### Understanding Path Issues

When images are stored in `analysis/media/images/`, but referenced as `media/filename.png`, Quarto fails to find them during PDF rendering.

**Problem**:
```
Image reference: ![](media/hero.png)
Image location: analysis/media/images/hero.png
Symlink: media → analysis/media
Resolution: media/hero.png → analysis/media/hero.png ✗ (missing images/ subdir)
```

**Solution**: Update all references to include the subdirectory:
```
Updated reference: ![](media/images/hero.png)
Resolution: media/images/hero.png → analysis/media/images/hero.png ✓
```

### Step 7.1: Find All Image References

Use grep to locate all image references in your blog post:

```bash
# Find all markdown image references
grep -n "!\[" analysis/paper/index.qmd

# Find YAML image references
grep -n "image:" analysis/paper/index.qmd

# Find HTML image tags
grep -n "<img" analysis/paper/index.qmd
```

### Step 7.2: Update YAML Image Reference

The YAML front matter typically includes an image for blog listing:

```yaml
# BEFORE
image: "media/ls_since_hero.png"

# AFTER
image: "media/images/ls_since_hero.png"
```

Update in your editor or with sed:

```bash
sed -i 's|image: "media/|image: "media/images/|g' analysis/paper/index.qmd
```

### Step 7.3: Update Markdown Image References

For each image reference in the markdown body:

```markdown
# BEFORE
![Description](media/image.png)

# AFTER
![Description](media/images/image.png)
```

Update all with sed:

```bash
sed -i 's|](media/\([^/]*\.png\)|](media/images/\1|g' analysis/paper/index.qmd
sed -i 's|](media/\([^/]*\.jpg\)|](media/images/\1|g' analysis/paper/index.qmd
sed -i 's|](media/\([^/]*\.jpeg\)|](media/images/\1|g' analysis/paper/index.qmd
```

Or manually, using your editor's find-and-replace:
- Find: `](media/`
- Replace: `](media/images/`

### Step 7.4: Verify Path Updates

```bash
# Check that all paths were updated
echo "=== Checking media paths ==="
grep -n "media/" analysis/paper/index.qmd | head -10

# Should show:
# 15:image: "media/images/ls_since_hero.png"
# 79:![Streamlined...](media/images/ls_since_hero.png)
# etc.
```

### Step 7.5: Handle Other Media Types

If you have audio or video:

```bash
# For audio files
sed -i 's|](media/\([^/]*\.mp3\)|](media/audio/\1|g' analysis/paper/index.qmd

# For video files
sed -i 's|](media/\([^/]*\.mp4\)|](media/video/\1|g' analysis/paper/index.qmd

# For embedded HTML (videos)
sed -i 's|media/\([^/]*\.mp4\)|media/video/\1|g' analysis/paper/index.qmd
```

---

## Step 8: Initialize Git and Commit

### Step 8.1: Initialize Git Repository

```bash
cd /path/to/your/blog/post

# Initialize git
git init

# Configure git user (if not already configured)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Verify
git config --list | grep -E "^user\."
```

### Step 8.2: Stage All Files

```bash
# Add all files to staging area
git add -A

# Review what will be committed
git status

# Should show all new files under "Changes to be committed"
```

### Step 8.3: Create Initial Commit

```bash
git commit -m "Convert blog post to ZZCOLLAB reproducible research compendium

This commit converts the blog post into a professional ZZCOLLAB workspace
with full reproducibility infrastructure.

Structure:
- analysis/paper/index.qmd: Blog post content
- analysis/media/images/: Static media assets
- analysis/scripts/: Analysis and generation scripts
- analysis/figures/: Placeholder for generated plots
- analysis/data/: Placeholder for raw and derived data
- Dual symlink system: Root level for Quarto, analysis/paper for editing

Configuration:
- Dockerfile: Reproducible environment (rocker/rstudio + Quarto)
- renv.lock: Frozen R package versions
- .Rprofile: R session configuration with auto-snapshot
- DESCRIPTION: R package metadata
- Makefile: Build automation targets
- .gitignore: Quarto and R artifact exclusions

Workflow:
Users can now:
1. make docker-build      - Build reproducible environment
2. make docker-post-render - Render blog post in container
3. make docker-post-preview - Start live preview
4. make docker-sh         - Interactive shell for development"
```

### Step 8.4: Verify Initial Commit

```bash
# View commit history
git log --oneline

# View what was committed
git log -1 --stat
```

### Step 8.5: Subsequent Commits (for changes)

After you fix image paths or make other changes:

```bash
# Stage changes
git add analysis/paper/index.qmd

# Commit with descriptive message
git commit -m "Fix image paths to include 'images' subdirectory

Update all image references from 'media/filename' to 'media/images/filename'
to match actual directory structure. This fixes PDF rendering errors."

# View updated log
git log --oneline
```

---

## Step 9: Verify and Test

### Step 9.1: Quick Structure Verification

```bash
# Verify complete directory structure
echo "=== Complete Structure ===" && tree -L 3 analysis/

echo ""
echo "=== Root Symlinks ===" && ls -la | grep "^l"

echo ""
echo "=== Configuration Files ===" && ls -1 | grep -E "^(Dockerfile|Makefile|renv|DESCRIPTION|NAMESPACE|LICENSE|\.gitignore|\.Rprofile)"
```

### Step 9.2: Test Docker Build

```bash
# Build Docker image
make docker-build

# Expected output:
# Sending build context to Docker daemon
# Step 1/5 : FROM rocker/rstudio:latest
# ...
# Successfully tagged your-blog-post:latest
```

### Step 9.3: Test Docker-Based Rendering

```bash
# Render blog post in Docker
make docker-post-render

# Expected output:
# processing file: index.qmd
# output file: index.html
# Blog post rendered
```

### Step 9.4: Test Local Rendering (if Quarto installed)

```bash
# If you have Quarto installed locally
make post-render

# Or directly
quarto render analysis/paper/index.qmd
```

### Step 9.5: Test Interactive Preview

```bash
# Start live preview server
make docker-post-preview

# Visit http://localhost:8080 in your browser
# Press Ctrl+C to stop
```

### Step 9.6: Verify Image Rendering

After rendering, verify images appear correctly:

```bash
# Check for rendered HTML
ls -lh analysis/paper/index.html

# Check that images were properly embedded/referenced
# Open in browser and verify all images display

# For PDF, check if images are embedded
file analysis/paper/index.pdf | grep -i "pdf" && echo "PDF rendered successfully"
```

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Images not found** | "File not found: media/image.png" | Update paths to include `images/` subdirectory |
| **Docker build fails** | "ERROR: failed to pull image" | Check internet, try `docker pull rocker/rstudio:latest` |
| **Port already in use** | "port is already allocated" | Use different port or kill process: `lsof -ti:8080 \| xargs kill` |
| **renv restore fails** | "Error restoring packages" | May be expected for minimal projects, try local render |
| **Quarto not found** | "quarto: command not found" | Install with `brew install quarto` or use `make docker-post-render` |

---

## Troubleshooting

### Issue: "File media/image.png not found" during PDF rendering

**Diagnosis**:
```bash
# Check where the file actually is
find . -name "image.png"
# Output: ./analysis/media/images/image.png

# Check what path is referenced
grep -n "image.png" analysis/paper/index.qmd
# Output: ![](media/image.png)
```

**Solution**: Update to `media/images/image.png`

### Issue: Symlinks not working on Windows

**Cause**: Windows doesn't natively support symlinks without special configuration

**Solutions**:
1. Use Windows Subsystem for Linux (WSL)
2. Enable Developer Mode (Windows 10+) for symlink support
3. Use relative paths directly in `index.qmd`

### Issue: Docker build takes very long

**Cause**: Building from scratch, pulling large images

**Solution**: Subsequent builds will be faster (cached layers). First build can take 10-30 minutes.

### Issue: "Permission denied" when creating symlinks

**Cause**: Insufficient permissions or Dropbox sync lock

**Solution**:
```bash
# Ensure you have write permissions
ls -ld .
# Should show: drwxr-xr-x (or similar with write permission)

# If in Dropbox, ensure sync is complete
# Try again after Dropbox finishes syncing
```

### Issue: Git commands fail with permission errors

**Cause**: File permissions set too restrictively (600)

**Solution**:
```bash
# Fix file permissions
chmod 644 *.qmd *.md *.lock DESCRIPTION NAMESPACE Dockerfile .Rprofile .gitignore
chmod 755 analysis/scripts/*.sh

# Try git add again
git add -A
```

### Issue: Makefile targets not found

**Cause**: Working in different directory than Makefile

**Solution**:
```bash
# Ensure you're in the project root
cd /path/to/your/blog/post
pwd  # Verify you see your project path

# View Makefile targets
make help

# If still not found, check Makefile exists
ls -la Makefile
```

---

## Best Practices

### 1. Directory Organization Philosophy

**Principle**: Separate concerns clearly

```
Principle: Data lives in analysis/data/, content in analysis/paper/,
           scripts in analysis/scripts/, output in analysis/figures/

Result: Clear workflow - scripts read from data, write to figures,
        paper documents everything
```

### 2. Version Control Strategy

**What to commit**:
- ✅ Source code (`.qmd`, `.R`, `.sh`)
- ✅ Configuration (`Dockerfile`, `renv.lock`, `.Rprofile`, `Makefile`)
- ✅ Small images (<1 MB)
- ✅ Documentation (`README.md`, comments)

**What NOT to commit**:
- ❌ Generated HTML/PDF files
- ❌ R artifacts (`.RData`, `.Rhistory`)
- ❌ Large images/media (use Git LFS)
- ❌ Personal config (`.gitconfig` with credentials)

```bash
# Use Git LFS for large media
git lfs install
git lfs track "analysis/media/video/*.mp4"
git lfs track "analysis/media/audio/*.mp3"
git add .gitattributes
```

### 3. Naming Conventions

**For analysis scripts** - Use numbered prefixes:
```
analysis/scripts/
├── 01_prepare_data.R      # Data cleaning
├── 02_fit_models.R         # Model training
└── 03_generate_figures.R   # Visualization
```

**For images** - Use descriptive names:
```
analysis/media/images/
├── hero-image.png          # Good
├── supporting-photo.jpg    # Good
├── img1.png                # Bad - unclear
└── temp.jpg                # Bad - vague
```

### 4. Documentation Standards

**Maintain README.md** at project root:

```markdown
# Your Blog Post Title

## Quick Start
make docker-build && make docker-post-render

## What's Inside
- Blog post: analysis/paper/index.qmd
- Images: analysis/media/images/
- Rendered: analysis/paper/index.html

## Requirements
- Docker
- Make
```

**Document data sources** in `analysis/data/README.md`:

```markdown
# Data Documentation

## Raw Data Sources

### dataset1.csv
- Source: [URL]
- Downloaded: 2025-12-02
- License: CC-BY 4.0
- Size: 5 MB
```

### 5. Image Best Practices

**Optimization**:
```bash
# Compress PNG images
pngquant --speed 1 image.png

# Optimize JPEG images
jpegoptim --max=85 image.jpg

# Convert to modern format
convert image.png image.webp
```

**Responsive sizing**:
```markdown
<!-- Small image: half width -->
![Description](media/images/plot.png){width="50%"}

<!-- Large image: full width -->
![Description](media/images/large.png){width="100%"}

<!-- With custom CSS classes -->
![Description](media/images/plot.png){.img-fluid}
```

### 6. Rendering Strategy

**For development**: Use interactive preview
```bash
make docker-post-preview
# Edit index.qmd in your editor
# Changes appear automatically
```

**For production**: Full render
```bash
make docker-post-render
# Generates clean HTML/PDF
# All paths and images resolved
```

**For verification**: Both formats
```bash
make docker-post-render    # Builds final version
open analysis/paper/index.html
open analysis/paper/index.pdf
```

### 7. Collaboration Workflow

**For solo development**:
```bash
# Edit → test → commit
git add analysis/paper/index.qmd
git commit -m "Update section X with new content"
git push
```

**For team collaboration**:
```bash
# Clone team image (pre-built, consistent environment)
make docker-pull-team

# Make changes
git checkout -b feature/new-section
# ... edit and test ...

# Share changes
git add .
git commit -m "Add new section"
git push origin feature/new-section

# Create pull request for review
```

### 8. Continuous Improvement

**Track improvements in CHANGELOG**:
```markdown
## [0.0.2] - 2025-12-15
### Changed
- Updated image paths for better organization
- Improved rendering pipeline

### Fixed
- Fixed PDF rendering for large images

### Added
- Interactive preview with live reload
```

**Update version in DESCRIPTION**:
```yaml
Version: 0.0.2  # Increment with improvements
```

---

## Summary of Conversion Process

### The Conversion Pipeline

```
Step 1: Analyze current structure
   ↓
Step 2: Plan reorganization
   ↓
Step 3: Create ZZCOLLAB directories
   ↓
Step 4: Migrate files to new locations
   ↓
Step 5: Create configuration files (Dockerfile, renv.lock, etc.)
   ↓
Step 6: Set up dual-symlink system
   ↓
Step 7: Update image/media paths
   ↓
Step 8: Initialize git and commit
   ↓
Step 9: Verify and test rendering
   ↓
✓ Complete! Blog post is now reproducible
```

### Key Outcomes

After following this guide, your blog post will have:

✅ **Reproducible environment** via Docker
✅ **Frozen dependencies** via renv.lock
✅ **Consistent configuration** via .Rprofile
✅ **Automated builds** via Makefile
✅ **Professional structure** following rrtools patterns
✅ **Git version control** with meaningful commits
✅ **Complete documentation** for readers/collaborators

### Next Steps

1. **Share your blog post**:
   - Push to GitHub
   - Provide reproduction instructions in README

2. **Extend with analysis**:
   - Add scripts to `analysis/scripts/`
   - Commit updated `renv.lock`

3. **Create a series**:
   - Use same structure for related posts
   - Share common `modules/` across projects

4. **Automate deployment**:
   - Set up GitHub Actions to render on commit
   - Deploy rendered HTML to GitHub Pages or similar

---

## Appendix: Quick Reference

### Essential Commands

```bash
# Build and render
make docker-build && make docker-post-render

# Development workflow
make docker-post-preview    # Live editing
# Edit analysis/paper/index.qmd
# Ctrl+C when done

# Git workflow
git add -A
git commit -m "Your descriptive message"
git push

# Verification
make check-renv
make docker-build

# Cleanup
make clean
```

### File Locations Reference

| Purpose | Location |
|---------|----------|
| Blog post source | `analysis/paper/index.qmd` |
| Blog post rendered | `analysis/paper/index.html` |
| Images | `analysis/media/images/` |
| Analysis scripts | `analysis/scripts/` |
| Generated plots | `analysis/figures/` |
| Raw data | `analysis/data/raw_data/` |
| Processed data | `analysis/data/derived_data/` |
| Configuration | Root directory |
| Documentation | `docs/` |

---

**Document Version**: 1.0
**Last Updated**: December 2, 2025
**For Questions**: Refer to `/Users/zenn/prj/d07/zzcollab/CLAUDE.md` or `/Users/zenn/prj/d07/zzcollab/vignettes/workflow-blog-development.Rmd`
