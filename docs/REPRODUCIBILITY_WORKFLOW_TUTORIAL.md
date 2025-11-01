# ZZCOLLAB Reproducibility Workflow Tutorial

**Purpose**: Hands-on tutorial demonstrating ZZCOLLAB's reproducibility and validation systems through a complete analysis workflow.

**What You'll Learn**:
- Docker-based reproducible environments
- Dynamic package management with auto-snapshot
- Shell-based validation (no host R required)
- Team collaboration workflow
- CI/CD integration

**Time Required**: 30-45 minutes

---

## Part 1: Solo Developer Workflow (15 minutes)

### Step 1: Initial Setup (5 minutes)

```bash
# Create a new research project
mkdir penguin-analysis && cd penguin-analysis

# Initialize ZZCOLLAB with analysis profile
zzcollab -r analysis -d ~/dotfiles

# Verify what was created
ls -la
```

**Expected Output**:
```
.
├── .zzcollab/
│   ├── manifest.json          # Tracks all created files
│   └── uninstall.sh           # Cleanup script
├── analysis/
│   ├── data/
│   │   ├── raw_data/          # Put original data here
│   │   ├── derived_data/      # Processed data goes here
│   │   └── README.md          # Data documentation template
│   ├── paper/                 # Manuscript development
│   ├── figures/               # Generated plots
│   ├── tables/                # Generated tables
│   └── scripts/               # Analysis scripts (empty - you create)
├── R/                         # Reusable functions
├── tests/testthat/            # Unit tests
├── DESCRIPTION                # Package metadata
├── Dockerfile                 # Computational environment
├── Makefile                   # Development commands
├── renv.lock                  # Package versions (initial state)
└── ZZCOLLAB_USER_GUIDE.md     # Symlink to docs/
```

**Validation Check**:
```bash
# Verify Docker profile in DESCRIPTION
grep "^Docker-Profile:" DESCRIPTION
# Should show: Docker-Profile: analysis

# Check initial renv.lock
jq '.R.Version' renv.lock
# Should show R version (e.g., "4.4.0")
```

### Step 2: Download Sample Data (2 minutes)

```bash
# Download Palmer Penguins data
curl -o analysis/data/raw_data/penguins.csv \
  https://raw.githubusercontent.com/allisonhorst/palmerpenguins/master/inst/extdata/penguins.csv

# Verify download
head -n 5 analysis/data/raw_data/penguins.csv
```

**Expected Output**:
```
species,island,bill_length_mm,bill_depth_mm,flipper_length_mm,body_mass_g,sex,year
Adelie,Torgersen,39.1,18.7,181,3750,male,2007
Adelie,Torgersen,39.5,17.4,186,3800,female,2007
...
```

### Step 3: Enter Container and Add Packages (3 minutes)

```bash
# Build Docker image (first time only, ~5-10 minutes)
make docker-build

# Enter container with Zsh shell
make docker-zsh
```

**Inside Container**:
```r
# R session automatically starts
# Current packages in renv.lock
renv::status()

# Add packages dynamically (no pre-configuration needed!)
install.packages("dplyr")
install.packages("ggplot2")
install.packages("readr")

# Verify packages are available
library(dplyr)
library(ggplot2)
library(readr)

# Exit container (auto-snapshot triggers)
quit(save = "no")
```

When you type `exit` or quit R, the container entrypoint automatically:
1. Runs `renv::snapshot()` to update `renv.lock`
2. Adjusts timestamps for RSPM binary availability
3. Validates package consistency (pure shell, no host R!)

**Validation Check** (back on host):
```bash
# Verify packages were added to renv.lock (automatic!)
jq '.Packages | keys | .[]' renv.lock | grep -E "(dplyr|ggplot2|readr)"

# Should show:
# "dplyr"
# "ggplot2"
# "readr"
# ... plus their dependencies

# Run shell-based validation (NO HOST R REQUIRED!)
make check-renv

# Should show:
# ✓ Package validation passed
# ✓ All packages in DESCRIPTION exist in renv.lock
```

### Step 4: Write Analysis Code (3 minutes)

```bash
# Re-enter container
make docker-zsh
```

**Inside Container**:
```bash
# Navigate to scripts directory (using new one-letter commands!)
s  # Jumps to analysis/scripts/ from anywhere

# Create analysis script
cat > 01_exploratory_analysis.R << 'EOF'
#!/usr/bin/env Rscript
##############################################################################
# Palmer Penguins Exploratory Analysis
# Purpose: Explore penguin morphology by species
##############################################################################

library(readr)
library(dplyr)
library(ggplot2)

# Set random seed for reproducibility
set.seed(20231027)

# Read data
penguins <- read_csv("../data/raw_data/penguins.csv",
                     show_col_types = FALSE)

# Summary statistics by species
summary_stats <- penguins %>%
  group_by(species) %>%
  summarise(
    n = n(),
    mean_bill_length = mean(bill_length_mm, na.rm = TRUE),
    sd_bill_length = sd(bill_length_mm, na.rm = TRUE),
    mean_flipper_length = mean(flipper_length_mm, na.rm = TRUE),
    sd_flipper_length = sd(flipper_length_mm, na.rm = TRUE)
  )

print(summary_stats)

# Create visualization
p <- ggplot(penguins, aes(x = bill_length_mm, y = flipper_length_mm,
                          color = species)) +
  geom_point(size = 3, alpha = 0.7) +
  theme_minimal() +
  labs(
    title = "Palmer Penguins: Bill Length vs Flipper Length",
    x = "Bill Length (mm)",
    y = "Flipper Length (mm)",
    color = "Species"
  )

# Save plot
f  # Jump to figures directory
ggsave("penguin_morphology.png", p, width = 8, height = 6, dpi = 300)

cat("✓ Analysis complete! Plot saved to analysis/figures/penguin_morphology.png\n")
EOF

# Make script executable
chmod +x 01_exploratory_analysis.R

# Run analysis
Rscript 01_exploratory_analysis.R
```

**Expected Output**:
```
# A tibble: 3 × 6
  species       n mean_bill_length sd_bill_length mean_flipper_length sd_flipper_length
  <chr>     <int>            <dbl>          <dbl>               <dbl>             <dbl>
1 Adelie      152             38.8           2.66                190.              6.54
2 Chinstrap    68             48.8           3.34                196.              7.13
3 Gentoo      124             47.5           3.08                217.              6.48
✓ Analysis complete! Plot saved to analysis/figures/penguin_morphology.png
```

**Verify Output**:
```bash
# Check figure was created
f  # Jump to figures directory
ls -lh penguin_morphology.png

# Exit container (auto-snapshot!)
exit
```

### Step 5: Host-Based Validation (2 minutes)

**Back on Host** (no R required!):
```bash
# Automatic validation ran on container exit, but let's verify manually
make check-renv

# Verify all project files exist
ls analysis/scripts/01_exploratory_analysis.R
ls analysis/figures/penguin_morphology.png

# Check git status
git status

# You should see:
# - renv.lock (modified - packages added)
# - analysis/scripts/01_exploratory_analysis.R (new)
# - analysis/figures/penguin_morphology.png (new)
# - analysis/data/raw_data/penguins.csv (new)
```

### Step 6: Version Control (1 minute)

```bash
# Add data documentation
echo "# Palmer Penguins Dataset

Source: https://github.com/allisonhorst/palmerpenguins
Downloaded: $(date +%Y-%m-%d)

## Variables
- species: Penguin species (Adelie, Chinstrap, Gentoo)
- island: Island in Palmer Archipelago (Biscoe, Dream, Torgersen)
- bill_length_mm: Bill length in mm
- bill_depth_mm: Bill depth in mm
- flipper_length_mm: Flipper length in mm
- body_mass_g: Body mass in grams
- sex: Penguin sex (male, female)
- year: Study year
" > analysis/data/README.md

# Commit everything
git add .
git commit -m "Add Palmer Penguins exploratory analysis

- Download Palmer Penguins dataset
- Add dplyr, ggplot2, readr packages (auto-snapshot)
- Create exploratory analysis script
- Generate bill vs flipper length visualization
- Document data sources and variables

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to GitHub
git push
```

---

## Part 2: Team Collaboration Workflow (10 minutes)

### Team Lead: Share Environment (3 minutes)

```bash
# Convert solo project to team collaboration
zzcollab -t mylab -p penguin-analysis -r analysis

# Build team Docker image
make docker-build

# Push to Docker Hub (requires docker login)
make docker-push-team

# Push code to GitHub
git add .
git commit -m "Configure team collaboration setup"
git push
```

### Team Member: Join Project (5 minutes)

**On Team Member's Machine**:
```bash
# Clone repository
git clone https://github.com/mylab/penguin-analysis.git
cd penguin-analysis

# Join project (pulls team Docker image)
zzcollab -u -d ~/dotfiles

# Verify Docker image was pulled
docker images | grep mylab/penguin-analysis

# Enter container (same environment as team lead!)
make docker-zsh
```

**Inside Container (Team Member)**:
```r
# All packages already available (from renv.lock)
renv::status()
# Should show: "No issues found -- the project is in a consistent state."

library(dplyr)
library(ggplot2)
library(readr)

# Navigate to scripts
s

# Verify can run existing analysis
Rscript 01_exploratory_analysis.R
# Should produce identical output!

# Add new package for statistical modeling
install.packages("broom")

# Exit (auto-snapshot)
quit(save = "no")
```

**Team Member Commits Changes**:
```bash
# Verify broom was added to renv.lock
jq '.Packages.broom' renv.lock

# Validation passed automatically on exit
make check-renv

# Commit and push
git add renv.lock
git commit -m "Add broom package for statistical modeling"
git push
```

### Team Lead: Pull Updates (2 minutes)

**Back on Team Lead's Machine**:
```bash
# Pull team member's changes
git pull

# Verify new package in renv.lock
jq '.Packages.broom' renv.lock

# Enter container and restore
make docker-zsh
```

**Inside Container**:
```r
# Restore new packages added by team member
renv::restore()

# Verify broom is now available
library(broom)

exit
```

---

## Part 3: Testing Reproducibility (10 minutes)

### Test 1: Clean Slate Rebuild (5 minutes)

```bash
# Simulate new collaborator joining project
cd ..
mkdir test-reproducibility && cd test-reproducibility

# Clone the repository
git clone https://github.com/mylab/penguin-analysis.git .

# Pull team Docker image
zzcollab -u

# Enter container
make docker-zsh
```

**Inside Container**:
```r
# Restore exact package versions
renv::restore()

# Run analysis
setwd("analysis/scripts")
source("01_exploratory_analysis.R")

# Verify output matches original
# (Should produce identical plot!)

exit
```

**Compare Results**:
```bash
# Compare with original (should be identical)
diff analysis/figures/penguin_morphology.png \
     ../penguin-analysis/analysis/figures/penguin_morphology.png

# No output = files are identical ✓
```

### Test 2: Package Validation (2 minutes)

```bash
# Test strict validation mode (scans tests/, vignettes/)
make check-renv-strict

# Intentionally break consistency
echo 'library(nonexistent)' >> analysis/scripts/test.R

# Run validation (should fail!)
make check-renv

# Should show error:
# ✗ Package validation failed
# Missing packages: nonexistent

# Fix it
rm analysis/scripts/test.R

# Re-validate (should pass)
make check-renv
# ✓ Package validation passed
```

### Test 3: CI/CD Validation (3 minutes)

```bash
# Check GitHub Actions workflow
cat .github/workflows/r-package-check.yml
```

**Key CI/CD Features**:
- Runs on every push and pull request
- Tests R package structure
- Validates DESCRIPTION ↔ renv.lock consistency
- Runs unit tests in Docker container
- Builds Docker image
- Ensures reproducibility

**Trigger CI/CD**:
```bash
# Make a small change
echo "# Test CI/CD" >> README.md

git add README.md
git commit -m "Test CI/CD pipeline"
git push

# Check GitHub Actions
# https://github.com/mylab/penguin-analysis/actions
# Should see workflow running and passing ✓
```

---

## Part 4: Advanced Validation (5 minutes)

### Test Auto-Snapshot Behavior

```bash
# Enter container
make docker-zsh
```

**Inside Container**:
```r
# Check current renv.lock timestamp
system("jq '.R.Repositories[0].Name' ../renv.lock")

# Add a package
install.packages("tidyr")

# Exit (auto-snapshot triggers)
quit(save = "no")
```

**On Host - Verify Auto-Snapshot**:
```bash
# Verify tidyr was added automatically
git diff renv.lock | grep tidyr

# Check validation ran automatically
# (Should have seen validation output on container exit)

# Verify RSPM timestamp adjustment worked
# (renv.lock should have recent timestamp, ensuring binaries available)
jq '.R.Repositories[0].URL' renv.lock
# Should show RSPM snapshot date
```

### Test Navigation Functions

```bash
# Enter container
make docker-zsh
```

**Inside Container**:
```bash
# Start in project root
pwd
# /home/analyst/project

# Jump to analysis directory
a
pwd
# /home/analyst/project/analysis

# Jump to scripts
s
pwd
# /home/analyst/project/analysis/scripts

# Jump to figures
f
pwd
# /home/analyst/project/analysis/figures

# Jump to data
d
pwd
# /home/analyst/project/analysis/data

# Jump back to analysis
a
pwd
# /home/analyst/project/analysis

# Works from any subdirectory!
cd raw_data
s  # Jumps to scripts from raw_data
pwd
# /home/analyst/project/analysis/scripts

exit
```

### Test Validation Without Host R

```bash
# Verify you DON'T need R on host
which R
# If not found: perfect! Validation still works

# Run pure shell validation
modules/validation.sh

# Should show:
# ✓ Validation completed successfully
# ✓ All packages in code exist in DESCRIPTION
# ✓ All Imports/Depends exist in renv.lock

# This proves: NO HOST R REQUIRED for entire workflow!
```

---

## Validation Checklist

Use this checklist to verify all reproducibility features:

### ✓ Docker Environment
- [ ] Dockerfile generated from profile
- [ ] Image builds successfully
- [ ] Container starts with correct R version
- [ ] All system dependencies available

### ✓ Package Management
- [ ] Packages added via `install.packages()`
- [ ] Auto-snapshot on container exit
- [ ] renv.lock updated automatically
- [ ] RSPM timestamp adjustment works
- [ ] Binary packages used (fast builds)

### ✓ Validation System
- [ ] Shell validation works without host R
- [ ] DESCRIPTION ↔ renv.lock consistency checked
- [ ] Code scanning detects used packages
- [ ] Strict mode scans tests/vignettes

### ✓ Team Collaboration
- [ ] Team Docker image builds
- [ ] Team members can pull image
- [ ] renv.lock restores exact versions
- [ ] Analysis produces identical results

### ✓ CI/CD Integration
- [ ] GitHub Actions workflow created
- [ ] Tests run automatically on push
- [ ] Package validation runs in CI
- [ ] Docker image builds in CI

### ✓ Version Control
- [ ] Five pillars tracked in git:
  - [ ] Dockerfile (environment)
  - [ ] renv.lock (packages)
  - [ ] .Rprofile (R options)
  - [ ] Source code (analysis)
  - [ ] Data (with documentation)

### ✓ Reproducibility
- [ ] Clean rebuild produces identical results
- [ ] Different machines produce same output
- [ ] Six months later: still reproducible

---

## Expected Outcomes

After completing this tutorial, you should have:

1. **Working Project**: Complete research project with real data analysis
2. **Docker Environment**: Reproducible computational environment
3. **Package Management**: Dynamic package addition with auto-snapshot
4. **Validation Proof**: Shell-based validation (no host R needed)
5. **Team Workflow**: Demonstrated collaboration capability
6. **CI/CD Integration**: Automated testing and validation
7. **Reproducibility Evidence**: Identical results from clean rebuild

---

## Troubleshooting

### Issue: Auto-snapshot didn't run

**Symptoms**: Exit container, renv.lock not updated

**Solution**:
```bash
# Check entrypoint is configured
docker inspect <container-id> | jq '.[0].Config.Entrypoint'
# Should show: ["/usr/local/bin/zzcollab-entrypoint.sh"]

# Manually snapshot if needed
make docker-zsh
renv::snapshot()
exit
```

### Issue: Validation fails

**Symptoms**: `make check-renv` shows errors

**Solution**:
```bash
# Check what's wrong
modules/validation.sh

# Common issues:
# 1. Package used in code but not in DESCRIPTION
#    → Add to DESCRIPTION Imports: field

# 2. Package in DESCRIPTION but not in renv.lock
#    → Install in container, auto-snapshot will add it

# 3. Package in neither
#    → Install and add to DESCRIPTION
```

### Issue: Docker build fails

**Symptoms**: `make docker-build` errors

**Solution**:
```bash
# Check Dockerfile syntax
docker build --dry-run -f Dockerfile .

# Common issues:
# 1. RSPM binary unavailable
#    → Adjust renv.lock timestamp (auto-handled by entrypoint)

# 2. System dependency missing
#    → Add to Dockerfile apt-get install section

# 3. ARM64 incompatibility
#    → Use compatible base image (rocker/rstudio vs rocker/verse)
```

---

## Next Steps

**For Your Research**:
1. Replace Palmer Penguins with your data
2. Customize Docker profile for your needs
3. Add domain-specific packages
4. Write your analysis scripts
5. Share with collaborators

**Learn More**:
- **Configuration**: `docs/CONFIGURATION.md`
- **Docker Profiles**: `docs/VARIANTS.md`
- **Testing Guide**: `docs/TESTING_GUIDE.md`
- **Development Commands**: `docs/DEVELOPMENT.md`

**Get Help**:
- **User Guide**: `ZZCOLLAB_USER_GUIDE.md`
- **Issues**: https://github.com/rgt47/zzcollab/issues

---

## Summary

This tutorial demonstrated ZZCOLLAB's complete reproducibility workflow:

- **Docker-First**: All development in containers
- **Auto-Snapshot**: No manual `renv::snapshot()` needed
- **Shell Validation**: No host R required
- **Team Collaboration**: Identical environments for all members
- **Five Pillars**: Dockerfile, renv.lock, .Rprofile, code, data
- **CI/CD Integration**: Automated validation on every commit

**Result**: Complete reproducibility from project creation through team collaboration to long-term preservation.

Happy reproducible researching! 🎉
