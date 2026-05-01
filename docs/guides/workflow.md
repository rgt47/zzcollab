# 🔄 Daily Development Workflow

**Related Guides**:
- 🐳 [Docker Guide](docker.md) - Understanding Docker concepts and commands
- 📦 [Package Management](renv.md) - Managing R packages with renv
- 🔧 [Troubleshooting](troubleshooting.md) - Fix common workflow issues
- ⚙️ [Configuration](config.md) - Customize your setup

---

## Understanding the Workflow

**Key Concept**: You work in TWO places:
1. **HOST** (your regular computer) - for git, file management
2. **CONTAINER** (isolated R environment) - for R analysis, RStudio

Think of the container as a "virtual computer" that has R perfectly configured.

> 📖 **New to Docker?** See the [Docker Guide](docker.md) for a beginner-friendly explanation.

---

## Complete Daily Workflow

### Morning: Starting Your Work Session

**💻 HOST (Terminal)**:
```bash
cd ~/projects/my-analysis
make docker-rstudio
```

**🐳 CONTAINER (Browser)**:
- Browser opens at `localhost:8787`
- **Login**: Set password when starting container (see Security section below)
  - Start with: `docker run -e PASSWORD=yourpassword ...` (via Makefile)
  - Or disable auth: `docker run -e RSTUDIO_AUTH=none ...` (local use only)
- You're now in RStudio running in Docker

### During the Day: Doing Your Analysis

**🐳 CONTAINER (RStudio)**:
- Write R code
- Create visualizations
- Knit R Markdown documents
- Install packages: `install.packages("packagename")`
- Dependencies auto-captured when you exit (no manual snapshot needed)

**💻 HOST (Your Computer)**:
- Files automatically sync!
- Check in Finder/Explorer: changes appear immediately
- Can edit with your favorite editor if you prefer

### Evening: Ending Your Work Session

**🐳 CONTAINER (Browser)**:
- Save all files in RStudio
- Close browser tab

**💻 HOST (Terminal)**:
- Press `Ctrl+C` to stop container
- Everything is saved!

### Next Day: Resuming Work

**💻 HOST (Terminal)**:
```bash
cd ~/projects/my-analysis
make docker-rstudio
```

**🐳 CONTAINER (Browser)**:
- Exactly where you left off!
- All files, packages, settings restored

---

## Host vs Container: What to Do Where

### Do on HOST (💻 your computer)

**✅ Git operations**:
```bash
git add .
git commit -m "Add analysis"
git push
```

**✅ File organization**:
```bash
mkdir analysis/scripts/chapter2
cp data.csv analysis/data/raw_data/
```

**✅ Start/stop containers**:
```bash
make docker-rstudio
make r
Ctrl+C  # to stop
```

**✅ View files in Finder/Explorer**:
- Just browse to your project folder

### Do in CONTAINER (🐳 Docker)

**✅ R analysis work**:
- Write R scripts
- Create plots
- Statistical modeling
- Data transformation

**✅ Package management**:
```r
install.packages("tidyverse")  # Auto-captured on container exit
renv::restore()                # Restore packages from renv.lock
```
Note: `renv::snapshot()` runs automatically when you exit the container.

**✅ R Markdown**:
- Create .Rmd files
- Knit to HTML/PDF
- Generate reports

**✅ Testing**:
```r
devtools::test()
devtools::check()
```

---

## Common Workflow Patterns

### Pattern 1: Quick Analysis Session

```bash
# Morning
cd ~/projects/homework2
make docker-rstudio
# ... work for 2 hours in RStudio ...
# Close browser, Ctrl+C in terminal
```

### Pattern 2: Multiple Edit Cycles

```bash
# Start container
make docker-rstudio

# In RStudio:
# Edit script1.R → Run → See results
# Edit script1.R → Run → See results
# Edit script1.R → Run → See results

# When done:
# Close browser, Ctrl+C
```

### Pattern 3: Long-Running Analysis

```bash
# Start container
make docker-rstudio

# In RStudio, run long analysis:
source("analysis/scripts/big_model.R")

# Leave it running, do other things
# Come back later, results ready!

# Save results, close browser, Ctrl+C
```

### Pattern 4: Git Workflow

```bash
# Do analysis work (in container)
make docker-rstudio
# ... create analysis.R, plots.png ...
# Close browser, Ctrl+C

# Commit work (on host)
git add analysis/scripts/analysis.R
git add analysis/figures/plots.png
git commit -m "Add customer analysis"
git push
```

### Pattern 5: Package Installation

```r
# In RStudio (container):
install.packages("forecast")  # Install new package
# No need to run renv::snapshot() - it runs automatically on exit!
```

Then on host:
```bash
# Close container (Ctrl+C) - renv.lock is auto-updated
git add renv.lock
git commit -m "Add forecast package"
```

---

## File Persistence - What Gets Saved?

### ✅ ALWAYS SAVED (in mounted /project directory)

- All files in `/home/analyst/project/`
- R scripts (.R, .Rmd)
- Data files
- Generated plots
- renv.lock (package versions)
- Git repository

### ❌ NOT SAVED (outside mounted directory)

- Files in `/home/analyst/` (not in /project)
- System packages installed with apt-get
- Changes to container system files
- RStudio preferences

**💡 SOLUTION**: Always work in `/home/analyst/project`
RStudio starts there automatically - you're safe!

---

## Typical Project Lifecycle

### Week 1: Project Start

**Day 1 (Monday)**:
```bash
mkdir ~/projects/final-project && cd ~/projects/final-project
zzcollab -p final-project
make docker-rstudio
# Set up project structure in RStudio
# Ctrl+C when done
```

**Day 2 (Tuesday)**:
```bash
cd ~/projects/final-project
make docker-rstudio
# Import data, initial exploration
# Ctrl+C when done
```

**Day 3-5 (Wed-Fri)**:
```bash
cd ~/projects/final-project
make docker-rstudio
# Data cleaning, analysis
# Ctrl+C each day
```

### Week 2: Analysis Development

**Daily routine**:
```bash
cd ~/projects/final-project
make docker-rstudio
# Develop analysis, create visualizations
# Ctrl+C when done
```

**Periodic git commits**:
```bash
git add .
git commit -m "Progress update"
git push
```

### Week 3-4: Report Writing

**Daily routine**:
```bash
cd ~/projects/final-project
make docker-rstudio
# Write R Markdown report
# Knit to see results
# Ctrl+C when done
```

**Final submission**:
```bash
# In RStudio: Knit final report
# Ctrl+C
git add final_report.html
git commit -m "Final submission"
git push
```

---

## Real-World Example: Complete Analysis Workflow

This example shows a complete workflow for analyzing the Palmer Penguins dataset, from project setup to final report.

### Day 1: Project Setup

**💻 HOST (Terminal)**:
```bash
# Create project
mkdir ~/projects/penguin-analysis && cd ~/projects/penguin-analysis
zzcollab --project-name penguins --r-version 4.4.0
git init
git add .
git commit -m "Initial project setup with zzcollab"

# Start container
make docker-rstudio
```

**🐳 CONTAINER (RStudio - localhost:8787)**:
```r
# Install packages
install.packages(c("palmerpenguins", "tidyverse", "ggplot2"))
renv::snapshot()  # Save package versions

# Create analysis script
dir.create("analysis/scripts", recursive = TRUE)
```

**💻 HOST (Terminal)**:
```bash
# Ctrl+C to stop container
git add renv.lock
git commit -m "Add analysis packages"
```

### Day 2: Data Exploration

**💻 HOST**: `cd ~/projects/penguin-analysis && make docker-rstudio`

**🐳 CONTAINER (RStudio)**:

Create `analysis/scripts/01_explore.R`:
```r
library(palmerpenguins)
library(tidyverse)

# Load data
data(penguins)

# Explore
summary(penguins)
glimpse(penguins)

# Basic visualization
ggplot(penguins, aes(x = bill_length_mm, y = bill_depth_mm, color = species)) +
  geom_point() +
  theme_minimal()

ggsave("analysis/figures/species_comparison.png", width = 8, height = 6)
```

**💻 HOST**:
```bash
# Ctrl+C
git add analysis/scripts/01_explore.R analysis/figures/species_comparison.png
git commit -m "Add exploratory analysis"
git push
```

### Day 3: Statistical Analysis

**🐳 CONTAINER (RStudio)**:

Create `analysis/scripts/02_analysis.R`:
```r
library(tidyverse)
library(palmerpenguins)

# Statistical test
model <- lm(body_mass_g ~ bill_length_mm + species, data = penguins)
summary(model)

# Save results
results <- broom::tidy(model)
write_csv(results, "analysis/results/model_results.csv")
```

**💻 HOST**:
```bash
git add analysis/
git commit -m "Add statistical analysis"
```

### Day 4: Final Report

**🐳 CONTAINER (RStudio)**:

Create `analysis/report/analysis_report.Rmd`:
```r
---
title: "Palmer Penguins Analysis"
output: html_document
---

## Introduction
Analysis of penguin morphology across three species...

## Methods
`{r}
library(palmerpenguins)
data(penguins)
`

## Results
`{r}
ggplot(penguins, aes(x = species, y = body_mass_g)) +
  geom_boxplot()
`

## Conclusion
Our analysis shows significant differences...
```

Knit to HTML in RStudio.

**💻 HOST**:
```bash
git add analysis/report/
git commit -m "Add final report"
git push
```

### Team Member Reproduces Analysis

**Team member (different computer)**:
```bash
# Clone repository
git clone https://github.com/username/penguin-analysis.git
cd penguin-analysis

# Run zzcollab (reads existing renv.lock for R version)
zzcollab

# Start container
make docker-rstudio
```

**🐳 CONTAINER (RStudio)**:
```r
# Restore exact package versions
renv::restore()  # Installs exact versions from renv.lock

# Knit report - produces identical results!
```

### Key Takeaways

1. **One-time setup**: `zzcollab` runs once per project
2. **Daily pattern**: `make docker-rstudio` → work → Ctrl+C → git commit
3. **Package management**: `install.packages()` → `renv::snapshot()` → git commit
4. **File persistence**: Everything in `/home/analyst/project` is saved
5. **Reproducibility**: `renv.lock` ensures identical environments

---

## Common Workflow Questions

**Q: "Do I need to run 'zzcollab' every time I work on my project?"**
A: NO! Only once per project.
Daily workflow: `cd project && make docker-rstudio`

**Q: "Can I edit files on my computer instead of in RStudio?"**
A: YES! Files sync both ways.
Edit in VSCode/Sublime on host → See changes in RStudio
Edit in RStudio → See changes on host

**Q: "What if I close the terminal accidentally?"**
A: No problem!
Open new terminal: `cd project && make docker-rstudio`
Everything restored!

**Q: "Can I work on multiple projects simultaneously?"**
A: YES! Open separate terminals for each:
```bash
Terminal 1: cd project1 && make docker-rstudio  # Port 8787
Terminal 2: cd project2 && make docker-rstudio  # ERROR - port in use!
```
Use different ports (advanced) or work on one at a time (easier)

**Q: "How do I know if the container is running?"**
A: Check terminal:
- Container running = terminal shows logs, can't type commands
- Container stopped = you see the prompt ($)

**Q: "What happens if my computer crashes?"**
A: As long as you saved in RStudio, files are safe!
Restart: `cd project && make docker-rstudio`

**Q: "Can I access my container from another computer?"**
A: Not easily. RStudio is on localhost (this computer only).
For remote access, need port forwarding (advanced)

**Q: "Should I commit renv.lock to git?"**
A: YES! This ensures reproducibility.
renv.lock records exact package versions.

---

## Workflow Troubleshooting

### Issue: "My changes disappeared!"

**Cause**: Worked outside `/home/analyst/project`

**Solution**:
- Always work in `/home/analyst/project`
- RStudio starts there by default
- If you cd elsewhere, files won't persist

### Issue: "Can't connect to RStudio"

**Check**:
1. Is container running? (terminal shows logs)
2. Correct URL? `http://localhost:8787`
3. Port conflict? (Try: `make docker-rstudio` again)

### Issue: "Package disappeared after restart"

**Cause**: Installed package but didn't run `renv::snapshot()`

**Solution**:
```r
install.packages("packagename")
renv::snapshot()  # Don't forget this!
```

### Issue: "Git won't commit"

**Cause**: Trying git commands in container

**Solution**:
- Exit container (Ctrl+C)
- Run git on host (your terminal)

---

## Advanced Workflow Patterns

### Use command-line instead of RStudio

```bash
make r
# Interactive shell in container
# Run R scripts: Rscript analysis.R
# exit when done
```

### Run specific R commands

```bash
make docker-r
# Opens R console
# Run commands
# q() to quit
```

### Run tests

```bash
make docker-test
# Runs all testthat tests
# See results in terminal
```

### Render documents

```bash
make docker-render
# Renders all R Markdown documents
# Outputs in analysis/figures/
```

---

## Workflow Best Practices

1. One container at a time (easier to manage)
2. Always Ctrl+C to cleanly stop containers
3. Run `renv::snapshot()` after installing packages
4. Commit to git frequently (don't lose work!)
5. Use meaningful commit messages
6. Keep raw data in `analysis/data/raw_data/` (never modify!)
7. Generated files in `analysis/figures/` or `derived_data/`
8. Scripts in `analysis/scripts/`
9. Functions in `R/` if you extract reusable code
10. Test your analysis from scratch occasionally (true reproducibility!)

---

## Security: RStudio Authentication

**IMPORTANT**: ZZCOLLAB containers do not set default passwords for security.

### Setting Up RStudio Access

**Option 1: Set password via environment variable** (Recommended)
```bash
# Modify Makefile or run directly:
docker run -e PASSWORD=your_secure_password -p 8787:8787 your-image
```

**Option 2: Disable authentication** (Local development only)
```bash
docker run -e RSTUDIO_AUTH=none -p 8787:8787 your-image
```

**Option 3: Set password in running container**
```bash
docker exec -it container_name bash
echo "analyst:your_password" | chpasswd
exit
```

### Security Best Practices

- ✅ Use strong passwords if running on shared systems
- ✅ Never expose RStudio to the internet without HTTPS and authentication
- ✅ Containers are for local development, not production deployment
- ✅ Keep containers updated by rebuilding with latest base images

For more details, see README.md "Security Considerations" section.

---

## See Also

- [Troubleshooting Guide](troubleshooting.md) - Fix common workflow issues
- [Package Management](renv.md) - Managing R packages with renv
- [Docker Guide](docker.md) - Understanding Docker concepts
- [Configuration Guide](config.md) - Customize your zzcollab setup
- [CI/CD Guide](cicd.md) - Automate testing and deployment
- README.md - Security considerations and overview
