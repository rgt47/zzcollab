# Reproducible Blog Post Development with ZZCOLLAB

## Introduction

This vignette demonstrates how to create **reproducible blog posts**
using ZZCOLLAB, following the unified research compendium framework
(Marwick et al. 2018). Each blog post becomes a self-contained
reproducible project that readers can clone and execute independently.

**Key Philosophy**: Blog posts containing data analysis should be **as
reproducible as academic papers**. Each post directory is a complete
ZZCOLLAB project with Docker, renv, and the five pillars of
reproducibility. The blog post itself lives in `analysis/report/`,
consistent with the manuscript workflow.

> **Key terms in this vignette.** New to the vocabulary? These are the
> terms this guide uses; each is defined again on first use. Full
> definitions are in
> [`vignette('glossary')`](https://rgt47.github.io/zzcollab/articles/glossary.md).
>
> - **Research compendium**: a single version-controlled unit bundling
>   data, code, environment, and documentation, here one per blog post.
> - **Five Pillars**: the five artifacts treated as jointly sufficient
>   for reproducibility: `Dockerfile`, `renv.lock`, `.Rprofile`, source
>   code, and research data.
> - **Docker / container / Dockerfile**: a tool that packages software
>   with its environment, a running instance of it, and the recipe that
>   builds it.
> - **Base image**: the starting Docker image a project builds on, here
>   `rocker/verse` for Quarto and LaTeX.
> - **renv / `renv.lock`**: per-project isolated package library and the
>   JSON lockfile pinning exact package versions.
> - **make target**: a named `Makefile` command (e.g.
>   `make docker-render-qmd`) wrapping a container operation.
> - **Raw vs derived data**: immutable original files versus the
>   processed, analysis-ready datasets generated from them.

### What You Will Learn

- Structuring blog posts as reproducible research compendia
- Authoring the post as `analysis/report/index.qmd` within the
  compendium
- Organizing media assets (images, audio, video)
- Rendering Quarto posts inside Docker with `make docker-render-qmd`
- Managing dependencies with renv for exact reproducibility

### Prerequisites

- Docker installed and running
- ZZCOLLAB installed (`./install.sh`)
- A base image with Quarto (the `rocker/verse` base provides Quarto and
  LaTeX; see Step 1)
- Git configured with credentials

## The Blog Post as Research Compendium

### Structure Overview

Each blog post follows the unified compendium structure. The post itself
lives at `analysis/report/index.qmd`, consistent with the manuscript
workflow, and renders in place with `make docker-render-qmd`:

    posts/palmer_penguins_part1/
    ├── Dockerfile                                # Computational environment
    ├── renv.lock                                 # Exact package versions
    ├── .Rprofile                                 # R session configuration
    ├── DESCRIPTION                               # Project metadata
    ├── Makefile                                  # Build commands
    ├── README.md                                 # Reader instructions
    │
    ├── analysis/
    │   ├── report/
    │   │   └── index.qmd                         # Blog post content (Quarto)
    │   │
    │   ├── scripts/                              # Numbered analysis pipeline
    │   │   ├── 01_prepare_data.R
    │   │   ├── 02_fit_models.R
    │   │   └── 03_generate_figures.R
    │   │
    │   ├── figures/                              # R-generated plots
    │   │   ├── eda-overview.png
    │   │   └── model-diagnostics.png
    │   │
    │   ├── media/                                # Static media assets
    │   │   ├── images/                           # Hero images, photos
    │   │   │   ├── README.md                     # Source/license info
    │   │   │   └── penguin-hero.jpg
    │   │   ├── audio/                            # Podcasts, narration
    │   │   │   └── episode-summary.mp3
    │   │   └── video/                            # Demos, tutorials
    │   │       └── analysis-walkthrough.mp4
    │   │
    │   └── data/
    │       ├── raw_data/                         # Original data (read-only)
    │       │   └── README.md
    │       └── derived_data/                     # Processed data, models
    │           ├── penguins_clean.csv
    │           └── simple_model.rds
    │
    └── R/                                        # Reusable functions (optional)
        └── utils.R

### Paths Are Relative to the Post

The post and its assets live together under `analysis/`, so figures,
media, and data are referenced with paths relative to
`analysis/report/index.qmd`. Quarto renders the document in place;
`make docker-render-qmd` runs `quarto render analysis/report/index.qmd`
inside the container.

**Benefits**:

1.  **No symlinks to maintain**: One canonical location for the post and
    assets
2.  **Intuitive paths**: Reference assets relative to `analysis/report/`
3.  **Reproducible render**: `make docker-render-qmd` builds in the
    container
4.  **rrtools consistency**: Content lives in `analysis/report/`

### Directory Purposes

| Directory | Contents | Generated By |
|----|----|----|
| `analysis/figures/` | R-generated plots | `analysis/scripts/` |
| `analysis/media/images/` | Static images (hero, photos) | Manual/external |
| `analysis/media/audio/` | Audio files (podcasts) | External tools |
| `analysis/media/video/` | Video files (demos) | External tools |
| `analysis/data/raw_data/` | Source data (read-only) | External/downloaded |
| `analysis/data/derived_data/` | Processed data, models | `analysis/scripts/` |

## Step-by-Step: Creating a Reproducible Blog Post

### Step 1: Initialize Post as ZZCOLLAB Project

``` bash
cd ~/prj/qblog/posts

# Create post directory
mkdir palmer_penguins_part1 && cd palmer_penguins_part1

# Initialize with the rocker/verse base image, which provides Quarto and
# LaTeX (needed for PDF output). For HTML-only posts, the default analysis
# profile is sufficient.
zzcollab docker --base-image rocker/verse
```

### Step 2: Prepare the Post Directories

Create the media directories and the Quarto post file inside the
compendium:

``` bash
# Media directories for static assets
mkdir -p analysis/media/images analysis/media/audio analysis/media/video

# The Quarto post lives alongside the manuscript
touch analysis/report/index.qmd
```

The post is authored at `analysis/report/index.qmd` and rendered with
`make docker-render-qmd`, which runs
`quarto render analysis/report/index.qmd` inside the container. No
symlinks are required.

### Step 3: Add Static Media Assets

``` bash
# Hero image for blog listing
cp ~/assets/penguin-hero.jpg analysis/media/images/

# Supporting photos
cp ~/assets/palmer-station.jpg analysis/media/images/

# Document sources (important for attribution)
cat > analysis/media/images/README.md << 'EOF'
# Image Sources

## penguin-hero.jpg
- Source: Unsplash
- Photographer: John Doe
- License: Unsplash License
- URL: https://unsplash.com/photos/xxxxx

## palmer-station.jpg
- Source: Palmer LTER
- License: CC BY 4.0
EOF
```

### Step 4: Edit Blog Post

Author the post at `analysis/report/index.qmd`. Asset paths are relative
to that file, so they begin with `../` to reach `analysis/figures/`,
`analysis/media/`, and `analysis/data/`:

```` markdown
---
title: "Palmer Penguins Analysis (Part 1): EDA and Simple Regression"
subtitle: "Getting acquainted with our Antarctic friends"
author: "Your Name"
date: "2025-01-15"
categories: [R Programming, Data Science, Palmer Penguins]
description: "Exploratory data analysis and simple regression modeling"
image: "../media/images/penguin-hero.jpg"
execute:
  echo: true
  warning: false
  message: false
format:
  html:
    code-fold: false
---

![Palmer Station, Antarctica](../media/images/palmer-station.jpg){.img-fluid}

# Introduction

Welcome to our exploration of the Palmer penguins dataset!


``` r
library(tidyverse)

# Load pre-computed results (generated by analysis/scripts/)
penguins_clean <- read_csv("../data/derived_data/penguins_clean.csv")
model_results <- read_csv("../data/derived_data/model_coefficients.csv")
```

# Exploratory Data Analysis

Our analysis reveals distinct patterns across species:

![Species distribution and morphometric relationships](../figures/eda-overview.png)

# Model Results


``` r
simple_model <- readRDS("../data/derived_data/simple_model.rds")
summary(simple_model)
```

![Model diagnostic plots](../figures/model-diagnostics.png)

# Video Walkthrough

```{=html}
<video width="100%" controls>
  <source src="../media/video/analysis-walkthrough.mp4" type="video/mp4">
</video>
```

# Reproducibility

This post is a reproducible research compendium:

```bash
git clone <repo> && cd posts/palmer_penguins_part1
make docker-build && make docker-render-qmd
```


``` r
sessionInfo()
```
````

**Note**: Asset paths use `../` because they are resolved relative to
`analysis/report/index.qmd`.

### Step 5: Create Analysis Scripts

#### Script 1: Data Preparation

Create `analysis/scripts/01_prepare_data.R`:

``` r

# 01_prepare_data.R
# Purpose: Prepare penguin data for analysis

library(palmerpenguins)
library(tidyverse)

penguins_clean <- penguins %>%
  drop_na() %>%
  mutate(log_body_mass = log(body_mass_g))

write_csv(penguins_clean, "analysis/data/derived_data/penguins_clean.csv")

cat("Prepared", nrow(penguins_clean), "observations\n")
```

#### Script 2: Fit Models

Create `analysis/scripts/02_fit_models.R`:

``` r

# 02_fit_models.R
# Purpose: Fit regression models

library(tidyverse)
library(broom)

penguins_clean <- read_csv("analysis/data/derived_data/penguins_clean.csv")

simple_model <- lm(body_mass_g ~ flipper_length_mm, data = penguins_clean)

write_csv(tidy(simple_model, conf.int = TRUE),
          "analysis/data/derived_data/model_coefficients.csv")
saveRDS(simple_model, "analysis/data/derived_data/simple_model.rds")

cat("R-squared:", round(summary(simple_model)$r.squared, 3), "\n")
```

#### Script 3: Generate Figures

Create `analysis/scripts/03_generate_figures.R`:

``` r

# 03_generate_figures.R
# Purpose: Generate publication-quality figures

library(tidyverse)

penguins_clean <- read_csv("analysis/data/derived_data/penguins_clean.csv")
simple_model <- readRDS("analysis/data/derived_data/simple_model.rds")

penguin_colors <- c("Adelie" = "#FF6B6B",
                    "Chinstrap" = "#9B59B6",
                    "Gentoo" = "#2E86AB")

# EDA overview
p1 <- ggplot(penguins_clean,
             aes(x = flipper_length_mm, y = body_mass_g, color = species)) +
  geom_point(alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE) +
  scale_color_manual(values = penguin_colors) +
  theme_minimal() +
  labs(title = "Flipper Length vs Body Mass")

ggsave("analysis/figures/eda-overview.png", p1,
       width = 8, height = 5, dpi = 300)

# Model diagnostics
png("analysis/figures/model-diagnostics.png",
    width = 10, height = 8, res = 300, units = "in")
par(mfrow = c(2, 2))
plot(simple_model)
dev.off()

cat("Figures saved to analysis/figures/\n")
```

### Step 6: Develop in Container

``` bash
# Build Docker image
make docker-build

# Enter container
make r

# Install required packages
R
> install.packages(c("palmerpenguins", "tidyverse", "broom"))
> q()  # Auto-snapshot on exit captures packages

# Run analysis pipeline
Rscript analysis/scripts/01_prepare_data.R
Rscript analysis/scripts/02_fit_models.R
Rscript analysis/scripts/03_generate_figures.R

# Render the Quarto post
quarto render analysis/report/index.qmd

# Exit container
exit
```

Alternatively, render from the host with the framework target, which
runs `quarto render analysis/report/index.qmd` inside the container:

``` bash
make docker-render-qmd
```

### Step 7: Optional Project Targets for the Pipeline

The framework provides `make docker-render-qmd` for rendering. If you
want a single command that also runs the analysis pipeline first, you
can add your own project target. The following are user-added targets,
not framework provided:

``` makefile
.PHONY: post-analysis post-render

# Run analysis pipeline (user-added convenience target)
post-analysis:
    Rscript analysis/scripts/01_prepare_data.R
    Rscript analysis/scripts/02_fit_models.R
    Rscript analysis/scripts/03_generate_figures.R

# Run pipeline then render via the framework target
post-render: post-analysis
    $(MAKE) docker-render-qmd
```

## Integration with Parent Blog

### Parent Blog \_quarto.yml

Your existing Quarto blog configuration works unchanged:

``` yaml
project:
  type: website
  render:
    - "*.qmd"
    - "posts/*/analysis/report/index.qmd"   # Post lives in the compendium
    - "!posts/*/analysis/scripts/"
    - "!posts/*/R/"
```

### Rendering Workflow

#### Option 1: Render Posts Individually

``` bash
# Each post renders in its own container (full reproducibility)
cd posts/palmer_penguins_part1
make docker-render-qmd

cd ../palmer_penguins_part2
make docker-render-qmd

# Build parent blog
cd ../..
quarto render
```

#### Option 2: Batch Render Script

Create `render_all_posts.sh` at blog root:

``` bash
#!/bin/bash
set -e

for post in posts/*/; do
    if [ -f "$post/Makefile" ] && [ -f "$post/Dockerfile" ]; then
        echo "=== Rendering: $post ==="
        (cd "$post" && make docker-build && make docker-render-qmd)
    fi
done

echo "=== Building site ==="
quarto render
```

## Media Asset Guidelines

### Generated Figures (`analysis/figures/`)

- Created by R scripts in `analysis/scripts/`
- Fully reproducible from code
- PNG format, 300 DPI recommended
- Naming: `eda-overview.png`, `model-diagnostics.png`

### Static Images (`analysis/media/images/`)

- Hero images for blog listing
- Photos, screenshots, diagrams
- **Document sources** in `README.md`:

``` markdown
# Image Sources

## penguin-hero.jpg
- Source: Unsplash
- Photographer: Derek Oyen
- License: Unsplash License
- URL: https://unsplash.com/photos/xxxxx
```

### Audio (`analysis/media/audio/`)

- Podcast episodes
- Audio summaries
- Formats: MP3, WAV, OGG

### Video (`analysis/media/video/`)

- Analysis walkthroughs
- Tutorial screencasts
- Formats: MP4, WebM

### Git LFS for Large Files

``` bash
git lfs install
git lfs track "analysis/media/video/*.mp4"
git lfs track "analysis/media/audio/*.mp3"
git add .gitattributes
```

## Version Control

### .gitignore

``` gitignore
# Rendered output (regenerated from source)
*.html
*_files/

# R artifacts
.Rhistory
.RData
.Rproj.user/

# OS files
.DS_Store
```

### Complete Commit

``` bash
git add .
git commit -m "Add Palmer Penguins Part 1: Reproducible blog post

Structure:
- analysis/report/index.qmd: Blog post content
- analysis/scripts/: Analysis pipeline (3 scripts)
- analysis/figures/: Generated plots
- analysis/media/: Static images, audio, video

Reproduce:
  make docker-build && make docker-render-qmd"
```

## Reader Instructions (README.md)

``` markdown
# Palmer Penguins Part 1: EDA and Simple Regression

This blog post is a **reproducible research compendium**.

## Quick Start

```bash
git clone https://github.com/yourusername/qblog.git
cd qblog/posts/palmer_penguins_part1

make docker-build
make docker-render-qmd

open analysis/report/index.html
```

### Requirements

- Docker
- Make

### Structure

    ├── analysis/
    │   ├── report/index.qmd   # Blog post (Quarto)
    │   ├── scripts/           # Analysis pipeline
    │   ├── figures/           # Generated plots
    │   ├── media/             # Static assets
    │   └── data/              # Raw and derived data
    ├── Dockerfile             # Computational environment
    └── renv.lock              # R package versions

### Reproducibility

All figures are generated by scripts in `analysis/scripts/`. Run the
pipeline, then render with `make docker-render-qmd`.


    # Best Practices Summary

    ## Structure

    - **Blog post in `analysis/report/index.qmd`** - Consistent with rrtools
    - **Assets under `analysis/`** - Referenced with `../` relative paths
    - **Numbered scripts** - Clear execution order
    - **Separate figures from media** - Generated vs static

    ## Paths in index.qmd

    Reference assets relative to `analysis/report/index.qmd`:

    ```markdown
    ![Plot](../figures/plot.png)           # analysis/figures/
    ![Hero](../media/images/hero.jpg)      # analysis/media/images/

### Reproducibility

- **Docker + renv.lock** - Frozen environment
- **Scripts generate, post presents** - Separation of concerns
- **README with instructions** - Clear reproduction steps
- **Git LFS for large media** - Video, audio files

### Workflow

``` bash
make docker-build         # Build environment
make r                    # Interactive development
make docker-render-qmd    # Render the Quarto post
```

## Self-Contained Project Guidelines

### Why Self-Containment Matters

Each blog post should be a truly **self-contained** reproducible
project. This means:

1.  **No external dependencies** on parent project paths
2.  **All assets included** in the post directory
3.  **Can be cloned independently** and rendered without the parent blog
4.  **Images live in `analysis/media/`** not referenced from elsewhere

### Image Placement: The Critical Detail

**DO ✅**: Copy/store images inside the post’s `analysis/media/images/`
directory

``` bash
# Copy hero image INTO the post
cp ~/assets/penguin-hero.jpg posts/my_post/analysis/media/images/

# Reference it relative to analysis/report/index.qmd
![Hero image](../media/images/penguin-hero.jpg){.img-fluid}
```

**DON’T**: Reference images from parent project paths

``` bash
# AVOID: This breaks if post is cloned independently
![Hero image](../../../images/posts/penguin-hero.jpg){.img-fluid}
```

### Verifying Self-Containment

Test that your blog post is truly self-contained:

``` bash
# Clone just the post directory (simulating independent use)
git clone --sparse https://github.com/yourrepo qblog
cd qblog
git sparse-checkout set posts/my_post
cd posts/my_post

# Try to render; should work without parent project
make docker-build
make docker-render-qmd

# If images render correctly, the post is self-contained
open analysis/report/index.html
```

### Media Directory Checklist

Before publishing your blog post, verify:

- All images are in `analysis/media/images/`
- `analysis/media/images/README.md` documents all image sources
- All image paths use `../media/images/filename` (relative to the post)
- Large media files (video, audio) use Git LFS tracking
- Post renders successfully: `make docker-render-qmd`
- Post is self-contained: can clone just this directory and render

### Example: Complete Self-Contained Post

    posts/my_analysis/
    ├── analysis/report/
    │   └── index.qmd                               # Blog post (Quarto)
    │
    ├── analysis/media/
    │   └── images/
    │       ├── README.md                           # Image sources/licenses
    │       ├── hero-image.jpg                      # Stored here (12 MB)
    │       └── supporting-photo.jpg                # Stored here
    │
    ├── analysis/figures/                           # Generated by scripts
    │   ├── eda-plot.png
    │   └── model-diagnostics.png
    │
    ├── analysis/data/                              # Raw and derived data
    │
    ├── Dockerfile                                  # Complete environment
    ├── renv.lock                                   # Exact packages
    ├── DESCRIPTION
    ├── Makefile
    └── README.md

In `analysis/report/index.qmd`:

``` markdown
---
title: "My Analysis"
image: "../media/images/hero-image.jpg"  # Relative to the post
---

![Hero](../media/images/hero-image.jpg){.img-fluid}  # Relative reference
```

## References

Marwick, Ben, Carl Boettiger, and Lincoln Mullen. 2018. “Packaging Data
Analytical Work Reproducibly Using R (and Friends).” *The American
Statistician* 72 (1): 80–88.
<https://doi.org/10.1080/00031305.2017.1375986>.
