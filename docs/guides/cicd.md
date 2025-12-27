# CI/CD and GitHub Actions

---

## What Is CI/CD? (For Researchers)

**CI/CD** = Continuous Integration / Continuous Delivery

Fancy term for: "Automatically test your code every time you push to GitHub"

Think of it like this:
- You write code on your computer
- Push to GitHub
- GitHub automatically runs tests
- You get email if something broke
- Catches problems before collaborators see them!

### Why this matters for research

- **Automatic validation** - Ensures code runs on fresh computer
- **Catches bugs early** - Before they cause problems
- **Reproducibility check** - Proves analysis actually works
- **Professional practice** - Shows thoroughness in research

---

## How CI/CD Works with ZZCOLLAB

### The Workflow

**You (on your computer)**:
1. Write analysis code
2. Run tests locally: `make docker-test`
3. Commit to git
4. Push to GitHub

**GitHub Actions (automatically)**:
1. Detects your push
2. Creates fresh Docker container
3. Installs all packages from renv.lock
4. Runs your tests
5. Sends you results (✅ pass or ❌ fail)

**You (get notified)**:
- Green checkmark = All tests passed!
- Red X = Something broke (fix it!)

---

## GitHub Actions Workflows

zzcollab creates these automatic workflows:

### 1. R Package Check (r-package-check.yml)

**When**: Every push to GitHub

**What it does**:
- Runs R CMD check
- Validates package structure
- Runs testthat tests
- Checks documentation

**Triggers on**:
- push to main branch
- pull requests

**Time**: ~5-10 minutes

### 2. Environment Validation (validate-environment.yml)

**When**: Every push to GitHub

**What it does**:
- Validates renv.lock completeness
- Checks for missing packages
- Verifies R environment options

**Triggers on**:
- push to any branch
- pull requests

**Time**: ~2-3 minutes

### 3. Render Paper (render-paper.yml) [if using analysis/report/]

**When**: Every push to GitHub

**What it does**:
- Renders `analysis/report/report.Rmd`
- Generates HTML/PDF output
- Uploads as artifact

**Triggers on**:
- push to main branch

**Time**: ~5-15 minutes (depends on analysis complexity)

---

## Viewing GitHub Actions Results

### On GitHub website

**Step 1**: Go to your repository
```
https://github.com/yourusername/yourproject
```

**Step 2**: Click "Actions" tab
- (Between "Pull requests" and "Projects")

**Step 3**: See workflow runs
- Green checkmark = Passed
- Red X = Failed
- Yellow dot = Running

**Step 4**: Click run to see details
- See each step's output
- Find error messages
- Download artifacts (rendered reports)

### In your terminal

Using gh CLI:
```bash
gh run list                    # Show recent runs
gh run view                    # View latest run details
gh run watch                   # Watch run in real-time
```

---

## Understanding Workflow Files

**Location**: `.github/workflows/`

**Example**: `r-package-check.yml`

```yaml
name: R Package Check

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2
      - name: Install dependencies
        run: renv::restore()
      - name: Run tests
        run: devtools::test()
```

**What this means**:
- `on: push` → Runs automatically on git push
- `runs-on: ubuntu-latest` → Uses Ubuntu Linux
- `steps:` → Sequential actions to take
- `renv::restore()` → Install packages from renv.lock
- `devtools::test()` → Run all tests

---

## Common CI/CD Workflows

### Workflow 1: Normal Development (All Tests Pass)

```bash
# On your computer:
vim analysis/scripts/new_analysis.R
make docker-test         # Tests pass locally
git add .
git commit -m "Add new analysis"
git push

# GitHub Actions (automatic):
  [Running tests...]
  ✅ All checks passed!

# You receive:
  Email notification: "All checks passed"
```

### Workflow 2: Broken Test (Caught by CI/CD!)

```bash
# On your computer:
vim R/analysis_function.R  # Introduce bug
git add .
git commit -m "Update function"
git push                   # Forgot to test!

# GitHub Actions (automatic):
  [Running tests...]
  ❌ Test failed: test-analysis.R line 42

# You receive:
  Email notification: "Action failed"

# Fix it:
git pull
make docker-test          # Reproduce failure
vim R/analysis_function.R # Fix bug
make docker-test          # Tests pass now
git add .
git commit -m "Fix bug"
git push

# GitHub Actions:
  ✅ All checks passed!
```

### Workflow 3: Pull Request Review

```bash
# Team member creates pull request
# GitHub Actions runs automatically
# Reviewer sees: ✅ All checks passed
# Safe to merge!
```

### Workflow 4: Reproducibility Validation

```bash
# Push final analysis
# GitHub Actions creates fresh environment
# Installs packages from renv.lock
# Runs analysis from scratch
# ✅ Success = Truly reproducible!
```

---

## Customizing CI/CD Workflows

**Add custom validation**:

`.github/workflows/custom-validation.yml`

```yaml
name: Custom Analysis Validation

on:
  push:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2

      - name: Restore packages
        run: |
          install.packages("renv")
          renv::restore()

      - name: Run data validation
        run: Rscript analysis/scripts/validate_data.R

      - name: Run analysis
        run: Rscript analysis/scripts/run_analysis.R

      - name: Check outputs
        run: |
          if [ ! -f "analysis/figures/plot.png" ]; then
            echo "Missing plot.png!"
            exit 1
          fi
```

---

## Troubleshooting CI/CD Failures

### Issue 1: "Tests pass locally but fail on GitHub"

**Common causes**:

1. **Missing package in renv.lock**
   - Solution: `renv::snapshot()`, commit, push

2. **Hardcoded paths** (e.g., `/Users/yourname/...`)
   - Solution: Use `here::here()` for paths

3. **System dependency missing**
   - Solution: Add to workflow file (`apt-get install ...`)

**Debug**:
```bash
# Run in fresh container locally:
docker run --rm -v $(pwd):/project rocker/r-ver:latest \
  bash -c "cd /project && Rscript -e 'renv::restore(); devtools::test()'"
```

### Issue 2: "renv::restore() fails"

**Causes**:
- Package not on CRAN anymore
- Package needs system dependencies
- renv.lock corrupted

**Solutions**:

**Add system dependencies to workflow**:
```yaml
- name: Install system dependencies
  run: sudo apt-get install -y libcurl4-openssl-dev libssl-dev
```

**Or specify CRAN repository explicitly**:
```yaml
- name: Restore packages
  run: |
    options(repos = c(CRAN = "https://cloud.r-project.org"))
    renv::restore()
```

### Issue 3: "Workflow takes too long (>30 minutes)"

**Optimizations**:

**1. Cache packages**:
```yaml
- uses: actions/cache@v3
  with:
    path: ~/.local/share/renv
    key: renv-${{ hashFiles('renv.lock') }}
```

**2. Use lightweight Docker profile for CI** (e.g., alpine_minimal ~200MB for faster builds)

**3. Split into separate workflows** (test vs. full analysis)

### Issue 4: "Workflow not running"

**Check**:
1. File in `.github/workflows/` directory?
2. YAML syntax correct? (use yamllint.com)
3. GitHub Actions enabled? (Settings → Actions)
4. Pushing to correct branch? (check `on: push: branches:`)

### Issue 5: "Can't reproduce failure locally"

**Solution**: Test in container with same OS

```bash
# GitHub uses Ubuntu, test with:
docker run --rm -it -v $(pwd):/project rocker/r-ver:latest bash
cd /project
Rscript -e "renv::restore()"
Rscript -e "devtools::test()"
```

---

## CI/CD Best Practices

### 1. Test locally before pushing

```bash
make docker-test
# Catches problems before CI/CD
```

### 2. Keep renv.lock up to date

```r
install.packages("newpkg")
renv::snapshot()
```

```bash
git add renv.lock
# Ensures CI/CD has all packages
```

### 3. Use meaningful commit messages

```bash
git commit -m "Add penguin analysis"
# Easier to identify which commit broke tests
```

### 4. Review CI/CD output regularly

- Check green checkmarks on GitHub
- Read failure messages carefully

### 5. Don't disable CI/CD when tests fail

- Fix the tests instead!
- Tests are there for a reason

### 6. Use branch protection rules

- GitHub → Settings → Branches
- Require tests to pass before merging

### 7. Monitor workflow run times

- Optimize if >10 minutes regularly

### 8. Keep workflows simple

- Complex workflows hard to debug

---

## Advanced: Scheduled Workflows

Run tests periodically (e.g., weekly):

```yaml
name: Weekly Reproducibility Check

on:
  schedule:
    - cron: '0 0 * * 0'  # Every Sunday at midnight
  workflow_dispatch:      # Manual trigger

jobs:
  reproduce:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2
      - name: Full reproducibility test
        run: |
          renv::restore()
          source("analysis/scripts/full_analysis.R")
```

**Why useful**:
- Catches package updates that break code
- Verifies long-term reproducibility
- Peace of mind for published research

---

## GitHub Actions Badges

Add status badges to README.md:

```markdown
[![R Package Check](https://github.com/user/repo/workflows/R%20Package%20Check/badge.svg)](https://github.com/user/repo/actions)
```

**Shows**: Build status directly in README
**Result**: ✅ Passing or ❌ Failing badge

Professional look for your research repository!

---

## Common Questions

**Q: "Do I have to use CI/CD?"**
A: No, but highly recommended! Catches reproducibility issues early.

**Q: "Does CI/CD cost money?"**
A: Free for public repositories. 2000 minutes/month free for private.

**Q: "What if I don't want to use GitHub Actions?"**
A: Can use GitLab CI, Travis CI, CircleCI. GitHub Actions easiest with zzcollab.

**Q: "Can I run workflows manually?"**
A: Yes! Add `workflow_dispatch:` to trigger section, then use website or:
```bash
gh workflow run workflow-name.yml
```

**Q: "What happens if workflow fails?"**
A: You get email. Fix code, push again. Workflow reruns automatically.

**Q: "Can I test workflows without pushing?"**
A: Use "act" tool (github.com/nektos/act) to run workflows locally.

**Q: "How do I see workflow logs?"**
A: GitHub → Actions tab → Click workflow run → Expand steps

**Q: "Can collaborators see workflow results?"**
A: Yes, if they have repo access.

**Q: "What if workflow fails but I can't fix it right now?"**
A: Create issue on GitHub to track. Fix when you can. Don't ignore!

---

## Quick Reference

### Workflow Files

```
.github/workflows/r-package-check.yml     # Package validation
.github/workflows/validate-environment.yml # renv validation
.github/workflows/render-paper.yml        # Paper rendering
```

### View Results

- GitHub → Repository → Actions tab
- `gh run list` (CLI)
- `gh run view` (CLI details)

### Local Testing

```bash
make docker-test        # Run tests locally
docker run ...          # Test in fresh container
```

### Common Issues

- Tests pass locally, fail CI → Missing renv.lock entry
- renv::restore() fails → System dependencies
- Workflow not running → Check .github/workflows/ location

### Best Practices

1. Test locally first
2. Keep renv.lock updated
3. Review CI/CD output
4. Fix failures promptly
5. Use branch protection

---

## See Also

- `zzcollab --help` - General help
- `zzcollab --help-github` - GitHub integration
- `zzcollab --help-troubleshooting` - Common issues
- `zzcollab --help-renv` - Package management

**GitHub Actions Documentation**:
https://docs.github.com/en/actions
