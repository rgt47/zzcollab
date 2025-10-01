# Continuous Integration for Research Compendia

This directory contains GitHub Actions workflows that automatically validate
your research compendium's reproducibility.

## Why CI/CD for Research?

Every push to GitHub triggers automated checks that:

1. **Verify environment reproducibility** - Dockerfile builds successfully
2. **Validate analysis execution** - Paper renders without errors
3. **Document computational environment** - Logs R version, packages
4. **Enable collaboration** - Catch breaking changes before merge

Research with automated CI/CD has been shown to have higher reproducibility
rates and easier collaboration compared to manual validation approaches.

## Current Workflows

### 📄 render-paper.yml

**Purpose**: Renders `analysis/paper/paper.Rmd` to verify reproducibility
**Triggers**: Push to main/master, pull requests affecting analysis files
**Runtime**: ~5-10 minutes (depending on analysis complexity)
**Artifacts**: Uploads rendered PDF for download (30-day retention)

**What it does**:
1. Checks out repository code
2. Builds Docker container with your computational environment
3. Restores R packages via renv
4. Renders paper.Rmd to PDF
5. Uploads PDF as downloadable artifact

**When it runs**: Only on changes to:
- `analysis/**` files
- `R/**` functions
- `renv.lock` package versions
- `Dockerfile` environment specification

This smart triggering saves CI minutes and focuses checks on relevant changes.

## How to Use CI Results

### ✅ Green Check (Success)

Your analysis is reproducible! The paper rendered successfully from the code
and data in the repository.

**Download the PDF**:
1. Click the green checkmark
2. Click "Details" next to "render"
3. Scroll to "Artifacts" section
4. Download "rendered-paper" ZIP

### ❌ Red X (Failure)

Something broke. Click the red X to see detailed logs.

**Common issues and solutions**:

#### Missing packages in renv.lock
```r
# In R console
renv::snapshot()  # Update lockfile with current packages

# Commit changes
git add renv.lock
git commit -m "Update package versions"
```

#### Data files not committed
```bash
# Check what files are missing
git status

# Add data files (if small enough for git)
git add analysis/data/
git commit -m "Add analysis data"

# For large files, use external storage with download script
```

#### Code references files outside analysis/
```r
# ❌ Bad: Hardcoded absolute paths
data <- read.csv("/Users/username/data.csv")

# ✅ Good: Relative paths with here()
library(here)
data <- read.csv(here("analysis", "data", "raw_data", "data.csv"))
```

#### Package versions incompatible
```r
# Check which package is failing (from CI logs)
# Update to compatible version
renv::install("packagename@version")
renv::snapshot()
```

## Customizing Workflows

### Disable CI Temporarily

Add to top of `render-paper.yml`:
```yaml
on:
  workflow_dispatch  # Manual trigger only
```

Or comment out entire workflow:
```bash
mv render-paper.yml render-paper.yml.disabled
```

### Add Package Tests

Add step after "Restore R packages":

```yaml
- name: Run unit tests
  run: |
    docker run --rm -v ${{ github.workspace }}:/project -w /project \
      compendium-env Rscript -e 'devtools::test()'
```

### Add R CMD check

For compendia using R package structure:

```yaml
- name: R CMD check
  run: |
    docker run --rm -v ${{ github.workspace }}:/project -w /project \
      compendium-env Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"))'
```

### Render Multiple Documents

```yaml
- name: Render supplementary materials
  run: |
    docker run --rm -v ${{ github.workspace }}:/project -w /project \
      compendium-env Rscript -e 'rmarkdown::render("analysis/supplements/supplement_S1.Rmd")'
```

### Deploy HTML Output to GitHub Pages

```yaml
- name: Deploy to GitHub Pages
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: ./analysis/paper
```

Then enable GitHub Pages in repository settings → Pages → Source: gh-pages branch.

### Cache renv Packages (Faster Builds)

Add before "Restore R packages":

```yaml
- name: Cache renv packages
  uses: actions/cache@v3
  with:
    path: ~/.local/share/renv
    key: ${{ runner.os }}-renv-${{ hashFiles('**/renv.lock') }}
    restore-keys: |
      ${{ runner.os }}-renv-
```

This caches packages between runs, significantly speeding up CI.

### Test on Multiple R Versions

```yaml
strategy:
  matrix:
    r-version: ['4.2', '4.3', '4.4']

steps:
  - name: Build Docker with R ${{ matrix.r-version }}
    run: |
      docker build --build-arg R_VERSION=${{ matrix.r-version }} -t compendium-env .
```

Requires modifying Dockerfile to accept `R_VERSION` argument.

## Troubleshooting

### "Docker image not found"

**Problem**: Dockerfile doesn't exist or fails to build

**Solution**: Test Docker build locally
```bash
docker build -t test-image .
```

Fix any errors, then commit Dockerfile changes.

### "renv::restore() fails"

**Problem**: Package not available from CRAN or repository

**Solutions**:

1. **Package removed from CRAN**:
   ```r
   # Use archived version
   renv::install("https://cran.r-project.org/src/contrib/Archive/pkg/pkg_1.0.0.tar.gz")
   ```

2. **GitHub package**:
   ```r
   # Ensure GitHub source is in renv.lock
   renv::install("username/package")
   ```

3. **Internal package**:
   - Add to Docker image or include in repository

### "File not found" errors in rendering

**Problem**: Paper.Rmd references files not in repository

**Solution**: Verify all dependencies are committed
```bash
# See what's missing
git status

# Check what paper.Rmd loads
grep -E "(read|source|load)" analysis/paper/paper.Rmd

# Add missing files
git add <missing-files>
```

### Slow CI runs (>10 minutes)

**Optimizations**:

1. **Cache renv packages** (see above)
2. **Use smaller base image**: `rocker/r-ver` instead of `rocker/verse`
3. **Minimize analysis in paper.Rmd**:
   - Do heavy computation in scripts → save results
   - Paper.Rmd loads pre-computed results → faster rendering
4. **Limit workflow triggers**: Only run on main branch pushes

### CI passes but local rendering fails

**Problem**: Environment differences between local and CI

**Solution**: Test in Docker container locally
```bash
# Build image
docker build -t local-test .

# Render in container (matches CI environment)
docker run --rm -v $(pwd):/project -w /project \
  local-test Rscript -e 'rmarkdown::render("analysis/paper/paper.Rmd")'
```

## Monitoring CI Usage

GitHub provides:
- **Public repos**: Unlimited CI minutes
- **Private repos**: 2,000 free minutes/month (Pro: 3,000)

Check usage: Repository → Settings → Actions → General → Usage

## Learn More

- **[zzcollab Examples](https://github.com/rgt47/zzcollab/tree/main/examples)** - Tutorial workflows
- **[zzcollab CI/CD Guide](https://github.com/rgt47/zzcollab/docs/CICD_GUIDE.md)** - Advanced patterns
- **[GitHub Actions for R](https://github.com/r-lib/actions)** - R-specific actions
- **[r-lib/actions examples](https://github.com/r-lib/actions/tree/v2/examples)** - Common R workflows

## Disabling CI Entirely

To remove CI/CD from your project:

```bash
# Remove workflows
rm -rf .github/

# Commit changes
git add .github/
git commit -m "Remove CI/CD workflows"
git push
```

You can always re-add workflows later from the zzcollab templates:
```bash
cp -r /path/to/zzcollab/templates/unified/.github .
```

---

**Questions?** Open an issue at https://github.com/rgt47/zzcollab/issues
