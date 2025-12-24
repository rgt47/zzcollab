# ZZCOLLAB Workflow Type System

## Overview

ZZCOLLAB now features an **automatic CI/CD workflow installation system** that selects the appropriate GitHub Actions workflow based on your project's Docker profile.

Each profile declares a `workflow_type` that determines which CI/CD workflow will be installed. This eliminates manual workflow setup and keeps CI/CD maintenance simple and consistent.

---

## Workflow Types

### 1. **package-dev** (R Package Development)
**Profiles:** `ubuntu_standard_minimal`, `alpine_standard_minimal`

**Purpose:** R package development and CRAN submission

**Workflow:** `r-package-dev.yml`

**Steps:**
- Build Docker image
- Restore packages from renv.lock
- Validate package dependencies
- Run unit tests
- Run `R CMD check` (CRAN validation)
- Build vignettes and documentation
- Report results

**When to use:**
- Building an R package for distribution
- Preparing for CRAN submission
- Package with unit tests

### 2. **analysis** (Data Analysis)
**Profiles:** `ubuntu_standard_analysis`, `ubuntu_x11_minimal`, `ubuntu_x11_analysis`, `alpine_standard_analysis`, `alpine_x11_*`

**Purpose:** Data analysis, exploratory work, script-based projects

**Workflow:** `r-package-analysis.yml`

**Steps:**
- Build Docker image
- Restore packages from renv.lock
- Validate dependencies
- Run unit tests
- Execute analysis scripts (analysis/scripts/*.R)
- Verify outputs exist
- Summary reporting

**When to use:**
- Data analysis projects with analysis scripts
- Exploratory data science work
- Projects that generate datasets/figures

### 3. **blog** (Blog Posts & Reports)
**Profiles:** `ubuntu_standard_publishing`

**Purpose:** Blog posts, tutorials, Quarto reports

**Workflow:** `r-package-blog.yml`

**Steps:**
- Build Docker image
- Restore packages from renv.lock
- Validate dependencies
- Run unit tests
- Execute analysis scripts
- **Render Quarto report** (main deliverable)
- Verify rendered output exists
- Upload HTML artifact to GitHub
- Success/failure summaries

**When to use:**
- Blog posts with Quarto rendering
- Tutorial documents
- Reports that need to be rendered as HTML/PDF
- Projects with narrative + analysis mix

### 4. **shiny** (Shiny Applications)
**Profiles:** `ubuntu_shiny_minimal`, `ubuntu_shiny_analysis`

**Purpose:** Shiny web applications

**Workflow:** `r-package-shiny.yml`

**Steps:**
- Build Docker image
- Restore packages from renv.lock
- Validate dependencies
- Run unit tests
- Validate Shiny app structure
- Check for common issues
- Summary reporting

**When to use:**
- Interactive Shiny applications
- Web-based dashboards
- Reactive applications

---

## Installation

### Automatic Installation

```bash
# In project root, run:
./scripts/install-workflows.sh

# Or with options:
./scripts/install-workflows.sh --verbose      # Show details
./scripts/install-workflows.sh --dry-run      # See what would happen
```

The script will:
1. Read `config.yaml` to find enabled profiles
2. Look up the `workflow_type` for each profile in `profiles.yaml`
3. Copy the appropriate `r-package-{type}.yml` to `.github/workflows/r-package.yml`
4. Remove `render-paper.yml` if present (legacy)

### Manual Installation

If you prefer to set it up manually:

```bash
# Create workflows directory
mkdir -p .github/workflows

# Copy the workflow for your project type
cp templates/workflows/r-package-blog.yml .github/workflows/r-package.yml

# Remove legacy workflow
rm .github/workflows/render-paper.yml 2>/dev/null || true

# Commit
git add .github/workflows/
git commit -m "Set up ZZCOLLAB CI/CD workflow (blog type)"
git push
```

---

## Profile to Workflow Mapping

| Profile | Workflow Type | Use Case |
|---------|---|---|
| `ubuntu_standard_minimal` | package-dev | R packages |
| `ubuntu_standard_analysis` | analysis | Data analysis |
| `ubuntu_standard_publishing` | blog | Blog posts/reports |
| `ubuntu_shiny_minimal` | shiny | Shiny apps |
| `ubuntu_shiny_analysis` | shiny | Shiny with tidyverse |
| `ubuntu_x11_minimal` | analysis | Analysis with X11 |
| `ubuntu_x11_analysis` | analysis | Analysis with X11 graphics |
| `alpine_standard_minimal` | package-dev | Lightweight packages |
| `alpine_standard_analysis` | analysis | Lightweight analysis |
| `alpine_x11_minimal` | analysis | Lightweight X11 |
| `alpine_x11_analysis` | analysis | Lightweight X11 analysis |

---

## Configuration

### Reading Your Profile

The workflow installer reads `config.yaml`:

```yaml
profiles:
  ubuntu_x11_analysis:
    enabled: true          # ← This profile is used

  ubuntu_standard_publishing:
    enabled: false         # ← This is ignored
```

The enabled profile's `workflow_type` field (in `profiles.yaml`) determines which workflow is installed:

```yaml
# From profiles.yaml
ubuntu_x11_analysis:
  base_image: "rocker/tidyverse:latest"
  workflow_type: "blog"    # ← Install r-package-blog.yml
  packages:
    - "renv"
    # ...
```

### Customizing the Workflow

After installation, you can customize `.github/workflows/r-package.yml`:

- Adjust timeouts
- Add additional build steps
- Modify output artifact retention
- Add notifications/integrations

But keep the overall structure to maintain consistency.

---

## For Your Blog Posts (60 posts)

All blog posts in `/qblog/posts/` use the `ubuntu_x11_analysis` profile, which declares:

```yaml
workflow_type: "blog"
```

Therefore, all 60 posts now have (or should have):

```
.github/workflows/
└── r-package.yml  (r-package-blog.yml)
```

This workflow:
- ✅ Builds Docker image
- ✅ Restores R packages
- ✅ Validates dependencies
- ✅ Runs tests
- ✅ Executes analysis scripts
- ✅ **Renders Quarto report** (blog post)
- ✅ Uploads rendered HTML as artifact
- ✅ Provides detailed success/failure summaries

---

## Advanced: Custom Profiles

You can add custom profiles to `profiles.yaml`:

```yaml
my_custom_profile:
  base_image: "rocker/tidyverse:latest"
  description: "Custom analysis environment"
  workflow_type: "analysis"          # ← Pick appropriate type
  packages:
    - "renv"
    - "custom-package"
  system_deps:
    - "custom-library"
  category: "custom"
  size: "~2GB"
  notes: "Custom profile for special projects"
```

Then enable in `config.yaml`:

```yaml
profiles:
  my_custom_profile:
    enabled: true
```

Run installer:

```bash
./scripts/install-workflows.sh
```

---

## Troubleshooting

### "Workflow template not found"

**Problem:** Script couldn't find the workflow file

**Solution:** Ensure template workflows exist in `templates/workflows/`:
- `r-package-blog.yml`
- `r-package-analysis.yml`
- `r-package-dev.yml`
- `r-package-shiny.yml`

### "No workflow_type found for profile"

**Problem:** Profile in `profiles.yaml` doesn't have `workflow_type` field

**Solution:** Add it manually:
```yaml
my_profile:
  workflow_type: "blog"    # ← Add this
  # ... rest of config
```

### Wrong workflow installed

**Problem:** Installed workflow doesn't match your project type

**Solution:**
1. Check enabled profile in `config.yaml`
2. Verify its `workflow_type` in `profiles.yaml`
3. Run: `./scripts/install-workflows.sh --dry-run --verbose`
4. Fix as needed, then: `./scripts/install-workflows.sh`

---

## Integration with GitHub Actions

When you push to GitHub:

1. GitHub Actions detects `.github/workflows/r-package.yml`
2. Reads `on:` trigger conditions
3. Builds Docker image (or uses cache)
4. Runs workflow steps based on type
5. Reports results in Actions tab
6. If blog type: uploads rendered HTML artifact

You can download artifacts from:
**Actions** → (workflow run) → **Artifacts**

---

## Next Steps

1. **Run installer:** `./scripts/install-workflows.sh`
2. **Review output:** Check `.github/workflows/r-package.yml`
3. **Commit:** `git add .github/workflows/ && git commit -m "..."`
4. **Push:** `git push origin main`
5. **Watch Actions:** GitHub will run the workflow on next push

---

## For zzcollab Maintainers

### Adding a New Workflow Type

1. Create workflow template: `templates/workflows/r-package-{newtype}.yml`
2. Update `profiles.yaml` with new profiles that use it
3. Update `config.yaml` documentation
4. Test with `install-workflows.sh --dry-run`
5. Document in this file

### Workflow Template Structure

Each workflow should:
- Build Docker from Dockerfile
- Restore R packages via renv
- Validate dependencies
- Run tests
- Do type-specific work (render, CMD check, etc.)
- Report success/failure
- Upload artifacts if applicable

---

*Last updated: 2025-12-12*

*Part of ZZCOLLAB: Reproducible Research Compendium Framework*
