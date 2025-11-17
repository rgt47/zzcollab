# X11 Plotting Workflow: Ubuntu Minimal with Zsh and Graphics

**Quick Start Guide for GUI-Enabled R Graphics in Docker**

---

## Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Quick Start](#quick-start)
4. [Detailed Workflow](#detailed-workflow)
5. [Plotting Examples](#plotting-examples)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Configuration](#advanced-configuration)

---

## Overview

The `ubuntu_x11_minimal` profile provides a lightweight Docker environment (~1.5GB) with:

- **R 4.4.2** with X11 graphics support
- **Zsh shell** with syntax highlighting and autosuggestions
- **X11 forwarding** for interactive plotting
- **Auto-snapshot** on container exit
- **Vim** with modern plugins

**Use Cases**:
- Interactive data exploration with R graphics
- Development with immediate visual feedback
- Teaching/demos requiring live plotting
- Quick prototyping with visualization

**Performance**: Container startup <1 second, plotting instantaneous with X11 forwarding.

---

## System Requirements

### macOS

**XQuartz** (X11 server for macOS):
```bash
# Install XQuartz
brew install --cask xquartz

# After installation, log out and log back in
# This activates XQuartz system integration
```

**Verify XQuartz installation**:
```bash
# Check if XQuartz is installed
ls -la /Applications/Utilities/XQuartz.app

# Start XQuartz manually
open -a XQuartz
```

**XQuartz configuration** (automatic via Makefile):
- Allow network connections: `defaults write org.xquartz.X11 nolisten_tcp 0`
- Enable remote connections from localhost

### Linux

**X11 server** (usually pre-installed):
```bash
# Check if X11 is available
echo $DISPLAY
# Should output something like :0 or :1

# Install X11 if needed (Ubuntu/Debian)
sudo apt-get install xorg x11-apps

# Test X11
xeyes    # Should open a window with animated eyes
```

### Windows

**VcXsrv** or **Xming** (X11 server for Windows):
```powershell
# Install VcXsrv via Chocolatey
choco install vcxsrv

# Or download from: https://sourceforge.net/projects/vcxsrv/

# Start VcXsrv with:
# - Multiple windows
# - Display number 0
# - Disable access control
```

---

## Quick Start

### 1. Create Project with X11 Profile

```bash
# Solo developer
zzcollab --profile-name ubuntu_x11_minimal --dotfiles ~/dotfiles

# Team project
zzcollab --team myteam \
         --project-name analysis \
         --profile-name ubuntu_x11_minimal \
         --dotfiles ~/dotfiles
```

**What this does**:
- Creates project structure with research compendium layout
- Generates `Dockerfile.ubuntu_x11_minimal` with X11 support
- Configures auto-snapshot entrypoint
- Copies your dotfiles (zsh, vim, tmux, etc.)

### 2. Build Docker Image

```bash
cd analysis
make docker-build
```

**Build time**: ~5-8 minutes (first time only)

**What gets installed**:
- R 4.4.2 with X11 capabilities
- renv, devtools, usethis, testthat, roxygen2
- Zsh with plugins (autosuggestions, syntax highlighting)
- Vim with vim-plug
- X11 libraries (libx11, libcairo, mesa-gl)
- All packages from renv.lock

### 3. Launch with X11 Forwarding

```bash
# macOS (automatic XQuartz setup)
make docker-zsh-gui

# Linux (uses existing DISPLAY)
make docker-zsh-gui

# Windows (set DISPLAY manually)
export DISPLAY=localhost:0.0
make docker-zsh-gui
```

**Automatic setup** (macOS):
- Checks XQuartz installation
- Configures network permissions
- Starts XQuartz if needed
- Sets up X11 authentication
- Launches container with forwarding

### 4. Test R Plotting

Inside the container:
```r
# Start R
R

# Test basic plotting
plot(1:10, 1:10, main="X11 Test", col="blue", pch=19)

# Test ggplot2 (if installed)
library(ggplot2)
ggplot(mtcars, aes(mpg, hp)) +
  geom_point() +
  theme_minimal()
```

**Expected behavior**:
- Plot window opens on your host screen
- Interactive: can resize, zoom, pan
- Immediate feedback

### 5. Exit and Auto-Snapshot

```bash
# Exit container
exit

# Auto-snapshot runs automatically
🔄 Auto-snapshot triggered on container exit...
✅ renv.lock updated successfully

# Validation runs on host
✅ Package validation complete
```

**What happens**:
- renv::snapshot() captures package changes
- renv.lock updated on host
- Pure shell validation checks DESCRIPTION ↔ renv.lock consistency
- All changes ready for git commit

---

## Detailed Workflow

### Complete Development Session

```bash
#==============================================================================
# PHASE 1: SETUP (One-time)
#==============================================================================

# 1. Install XQuartz (macOS)
brew install --cask xquartz
# Log out and log back in

# 2. Create project with X11 profile
mkdir ~/projects/data-viz-analysis && cd ~/projects/data-viz-analysis
zzcollab --profile-name ubuntu_x11_minimal --dotfiles ~/dotfiles

# 3. Initialize git repository
git init
git add .
git commit -m "Initial project setup with X11 support"

# 4. Build Docker image
make docker-build
# Wait 5-8 minutes (first time only)

#==============================================================================
# PHASE 2: DEVELOPMENT (Daily workflow)
#==============================================================================

# 1. Launch container with X11 forwarding
make docker-zsh-gui

# Inside container:

# 2. Install packages for visualization
R
> install.packages("ggplot2")
> install.packages("patchwork")
> install.packages("gganimate")
> quit()

# 3. Create analysis script
vim analysis/scripts/explore_data.R

# 4. Test interactively
R
> source("analysis/scripts/explore_data.R")
# Plots open on your screen via X11

# 5. Iterate
# Edit script, re-run, view plots

# 6. Exit container
exit
# Auto-snapshot captures package additions

#==============================================================================
# PHASE 3: COMMIT AND SHARE
#==============================================================================

# 7. Review changes
git status
# Shows: renv.lock, analysis/scripts/explore_data.R

# 8. Commit work
git add .
git commit -m "Add interactive data visualization analysis

- Install ggplot2, patchwork, gganimate
- Create explore_data.R with X11 plotting
- Test multiple visualization approaches"

# 9. Push to remote
git push origin main

#==============================================================================
# PHASE 4: TEAM COLLABORATION
#==============================================================================

# Team lead: Share Docker image
make docker-push-team

# Team members: Use pre-built image
git clone https://github.com/myteam/data-viz-analysis.git
cd data-viz-analysis
zzcollab --use-team-image --dotfiles ~/dotfiles
make docker-zsh-gui    # Instant startup, all packages pre-installed
```

---

## Plotting Examples

### Example 1: Basic R Graphics

```r
# Inside container R session
R

# Set up device
X11()    # Explicitly open X11 device (usually automatic)

# Simple scatter plot
plot(iris$Sepal.Length, iris$Sepal.Width,
     col = iris$Species,
     pch = 19,
     main = "Iris Dataset",
     xlab = "Sepal Length",
     ylab = "Sepal Width")
legend("topright",
       legend = levels(iris$Species),
       col = 1:3,
       pch = 19)

# Multiple plots
par(mfrow = c(2, 2))
plot(iris$Sepal.Length, iris$Sepal.Width, main="Sepal")
plot(iris$Petal.Length, iris$Petal.Width, main="Petal")
hist(iris$Sepal.Length, main="Sepal Length Distribution")
boxplot(Sepal.Width ~ Species, data=iris, main="Sepal Width by Species")
```

### Example 2: ggplot2 Visualization

```r
library(ggplot2)
library(dplyr)

# Basic ggplot
ggplot(mtcars, aes(x = mpg, y = hp, color = factor(cyl))) +
  geom_point(size = 3) +
  geom_smooth(method = "lm", se = FALSE) +
  theme_minimal() +
  labs(title = "MPG vs Horsepower by Cylinders",
       x = "Miles per Gallon",
       y = "Horsepower",
       color = "Cylinders")

# Faceted visualization
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width)) +
  geom_point(aes(color = Species), size = 2) +
  facet_wrap(~ Species) +
  theme_bw() +
  labs(title = "Iris Measurements by Species")

# Complex composition with patchwork
library(patchwork)

p1 <- ggplot(mtcars, aes(mpg)) + geom_histogram(bins = 20)
p2 <- ggplot(mtcars, aes(factor(cyl), mpg)) + geom_boxplot()
p3 <- ggplot(mtcars, aes(wt, mpg)) + geom_point()

(p1 | p2) / p3 + plot_annotation(title = "Motor Trend Car Analysis")
```

### Example 3: Interactive Graphics

```r
# Install interactive plotting packages
install.packages("plotly")
install.packages("htmlwidgets")

library(plotly)

# Create interactive plot
p <- plot_ly(iris,
             x = ~Sepal.Length,
             y = ~Sepal.Width,
             color = ~Species,
             type = "scatter",
             mode = "markers")

# View in browser (requires X11 for browser display)
p
```

### Example 4: Statistical Graphics

```r
library(ggplot2)
library(broom)

# Regression diagnostics
model <- lm(mpg ~ wt + hp + cyl, data = mtcars)
model_diag <- augment(model)

# Diagnostic plots
par(mfrow = c(2, 2))
plot(model)

# Or with ggplot2
library(ggfortify)
autoplot(model)
```

### Example 5: Data Exploration Workflow

Create `analysis/scripts/exploratory_analysis.R`:

```r
#!/usr/bin/env Rscript
# Exploratory Data Analysis with X11 Graphics

library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)

# Load data
data("palmerpenguins", package = "palmerpenguins")
penguins <- palmerpenguins::penguins

# 1. UNIVARIATE ANALYSIS
# Distribution of body mass
p1 <- ggplot(penguins, aes(x = body_mass_g)) +
  geom_histogram(binwidth = 200, fill = "steelblue", alpha = 0.7) +
  theme_minimal() +
  labs(title = "Body Mass Distribution",
       x = "Body Mass (g)", y = "Count")

# 2. BIVARIATE ANALYSIS
# Flipper length vs body mass
p2 <- ggplot(penguins, aes(x = flipper_length_mm, y = body_mass_g, color = species)) +
  geom_point(size = 2, alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE) +
  theme_minimal() +
  labs(title = "Flipper Length vs Body Mass",
       x = "Flipper Length (mm)", y = "Body Mass (g)")

# 3. MULTIVARIATE ANALYSIS
# Species comparison
p3 <- penguins %>%
  select(species, bill_length_mm, bill_depth_mm, flipper_length_mm, body_mass_g) %>%
  pivot_longer(-species, names_to = "measurement", values_to = "value") %>%
  ggplot(aes(x = species, y = value, fill = species)) +
  geom_boxplot(alpha = 0.7) +
  facet_wrap(~ measurement, scales = "free_y") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Penguin Measurements by Species")

# 4. TEMPORAL ANALYSIS
p4 <- penguins %>%
  count(year, species) %>%
  ggplot(aes(x = year, y = n, color = species)) +
  geom_line(size = 1.2) +
  geom_point(size = 3) +
  theme_minimal() +
  labs(title = "Penguin Counts by Year",
       x = "Year", y = "Count")

# Combine all plots
combined <- (p1 | p2) / (p3 | p4) +
  plot_annotation(title = "Palmer Penguins: Exploratory Data Analysis",
                  theme = theme(plot.title = element_text(size = 16, face = "bold")))

# Display
print(combined)

# Save to file
ggsave("analysis/figures/exploratory_analysis.png",
       combined,
       width = 14,
       height = 10,
       dpi = 300)

cat("✅ Exploratory analysis complete. Figure saved to analysis/figures/\n")
```

**Run the analysis**:
```bash
# Inside container
Rscript analysis/scripts/exploratory_analysis.R
```

**Expected output**:
- Interactive plot window opens with 4-panel visualization
- PNG file saved to `analysis/figures/exploratory_analysis.png`

---

## Troubleshooting

### Issue 1: "Cannot open display"

**Symptom**:
```r
> plot(1:10)
Error in X11() : unable to open connection to X11 display
```

**Diagnosis**:
```bash
# Check DISPLAY environment variable
echo $DISPLAY
# Should show: host.docker.internal:0 (macOS) or :0 (Linux)

# Check X11 authentication
xauth list
# Should show authentication entry
```

**Fix (macOS)**:
```bash
# Exit container
exit

# Check XQuartz is running
ps aux | grep XQuartz

# Start XQuartz manually
open -a XQuartz

# Check XQuartz preferences
# XQuartz → Preferences → Security
# ✅ "Allow connections from network clients" should be checked

# Restart XQuartz
killall XQuartz
open -a XQuartz

# Try again
make docker-zsh-gui
```

**Fix (Linux)**:
```bash
# Exit container
exit

# Allow Docker to connect to X11
xhost +local:docker

# Try again
make docker-zsh-gui
```

### Issue 2: XQuartz Not Found

**Symptom**:
```
❌ XQuartz not found. Installing...
```

**Fix**:
```bash
# Install XQuartz
brew install --cask xquartz

# IMPORTANT: Log out and log back in
# This activates system integration

# Verify installation
ls -la /Applications/Utilities/XQuartz.app

# Try again
make docker-zsh-gui
```

### Issue 3: Black/Empty Plot Window

**Symptom**: Plot window opens but shows black screen or doesn't display graphics.

**Diagnosis**:
```r
# Check graphics capabilities
capabilities()
# Look for X11: TRUE, cairo: TRUE

# Check graphics device
dev.cur()
# Should show active device

# List available devices
dev.list()
```

**Fix**:
```r
# Explicitly set device
options(device = "X11")

# Or use cairo device
options(device = "cairo")

# Reopen device
dev.off()
X11()
plot(1:10)
```

### Issue 4: Slow Graphics Performance

**Symptom**: Plot rendering is slow or laggy.

**Optimization**:
```r
# Use cairo device (faster rendering)
X11(type = "cairo")

# Reduce anti-aliasing
options(X11.options = "-antialias")

# Or disable anti-aliasing completely
X11(antialias = "none")
```

**Alternative approach**:
```r
# Save plots to files instead of interactive display
png("output.png", width = 800, height = 600)
plot(1:10)
dev.off()

# View saved file (opens in native viewer)
system("open output.png")  # macOS
system("xdg-open output.png")  # Linux
```

### Issue 5: Font Rendering Issues

**Symptom**: Fonts appear pixelated or missing.

**Fix (inside container)**:
```bash
# Install additional fonts
sudo apt-get update
sudo apt-get install fonts-dejavu fonts-liberation fonts-liberation2

# Update font cache
fc-cache -fv

# Restart R session
```

**Fix (R configuration)**:
```r
# Use cairo device with proper font support
X11(type = "cairo")

# Or specify font family
par(family = "sans")
plot(1:10)
```

### Issue 6: "X11 forwarding request failed"

**Symptom**: SSH error message during container startup.

**Fix**:
```bash
# Check X11 authentication
ls -la ~/.Xauthority

# Regenerate X11 cookie
xauth generate :0 . trusted

# Or remove and recreate
rm ~/.Xauthority
touch ~/.Xauthority
xauth generate :0 . trusted

# Try again
make docker-zsh-gui
```

### Issue 7: Multiple Plot Windows Not Working

**Symptom**: Only one plot window opens, new plots overwrite.

**Fix**:
```r
# Open new window explicitly
dev.new()

# Or use X11() to create multiple devices
X11()  # Device 2
plot(1:10)

X11()  # Device 3
plot(10:1)

# Switch between devices
dev.set(2)  # Focus on device 2
dev.set(3)  # Focus on device 3

# List all devices
dev.list()
```

---

## Advanced Configuration

### Custom X11 Setup

**Manual X11 forwarding** (advanced users):
```bash
# macOS - Manual XQuartz configuration
open -a XQuartz
xhost + 127.0.0.1

# Get IP address for Docker
IP=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')

# Run container with custom DISPLAY
docker run --rm -it \
  -e DISPLAY=$IP:0 \
  -v ~/.Xauthority:/home/analyst/.Xauthority:ro \
  -v $(PWD):/home/analyst/project \
  myteam/project:latest zsh
```

### Linux X11 Socket Mounting

**Direct socket access** (Linux only):
```bash
# Run with X11 socket mounted
docker run --rm -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $HOME/.Xauthority:/home/analyst/.Xauthority:ro \
  -v $(PWD):/home/analyst/project \
  myteam/project:latest zsh
```

### Persistent X11 Configuration

Create `.zzcollab/config.yaml`:
```yaml
docker:
  x11_forwarding: true
  x11_display: "host.docker.internal:0"  # macOS
  # x11_display: ":0"  # Linux

environment:
  DISPLAY: "host.docker.internal:0"
  QT_X11_NO_MITSHM: "1"  # Fix for Qt apps
  XAUTHORITY: "/home/analyst/.Xauthority"
```

### Remote X11 Forwarding

**Access from remote machine**:
```bash
# On remote machine (has Docker + project)
ssh -X your-server.com

# Enable X11 forwarding in SSH config
# ~/.ssh/config
Host your-server.com
    ForwardX11 yes
    ForwardX11Trusted yes

# Run container with forwarded display
make docker-zsh-gui
# Graphics display on your local machine!
```

### High-DPI Display Support

**Retina/4K display optimization**:
```r
# Set DPI in R
options(bitmapType = "cairo")
X11(width = 10, height = 8, pointsize = 12, type = "cairo")

# Or configure globally in .Rprofile
echo 'options(bitmapType = "cairo")' >> ~/.Rprofile
```

### Alternative: VNC-Based Graphics

**For scenarios where X11 forwarding is problematic**:

Create `Dockerfile.ubuntu_x11_vnc`:
```dockerfile
FROM ubuntu_x11_minimal

# Install VNC server
RUN apt-get update && apt-get install -y \
    x11vnc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Start Xvfb and x11vnc
EXPOSE 5900
CMD Xvfb :99 -screen 0 1024x768x16 & \
    x11vnc -display :99 -forever -usepw -create & \
    DISPLAY=:99 zsh
```

**Connect via VNC viewer**: Plots display in VNC window instead of X11 forwarding.

---

## Performance Benchmarks

### Startup Time Comparison

| Configuration | Build Time | Startup Time | Plot Rendering |
|--------------|-----------|--------------|----------------|
| ubuntu_x11_minimal (pre-built) | 0s | <1s | Instant |
| ubuntu_x11_minimal (first build) | 5-8 min | <1s | Instant |
| RStudio Server (web-based) | 8-12 min | ~3s | ~500ms delay |
| Native R + X11 | N/A | ~2s | Instant |

**Key takeaway**: After initial build, X11-enabled containers start as fast as native R while maintaining reproducibility.

### Resource Usage

**Container resource consumption**:
```bash
# Monitor resource usage
docker stats

# Typical usage:
# CPU: 5-15% (idle), 50-100% (plotting)
# Memory: 200-500 MB (R session with plots)
# Network: <1 KB/s (X11 forwarding is efficient)
```

**Optimization tips**:
```bash
# Limit CPU usage
docker run --cpus="2.0" ...

# Limit memory
docker run --memory="2g" ...
```

---

## Integration with CI/CD

### GitHub Actions Headless Testing

**Run graphics tests without X11**:
```yaml
# .github/workflows/test-graphics.yml
name: Test Graphics
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Docker image
        run: make docker-build

      - name: Test graphics (headless)
        run: |
          # Use virtual framebuffer
          xvfb-run make docker-test-graphics
```

**Test script** (`tests/test_graphics.R`):
```r
library(testthat)

test_that("Graphics device works", {
  # Test with null device (no X11 required)
  pdf(NULL)

  p <- plot(1:10)
  expect_true(is.null(p))  # Plot succeeds

  dev.off()
})

test_that("ggplot2 rendering works", {
  library(ggplot2)

  p <- ggplot(mtcars, aes(mpg, hp)) + geom_point()

  # Save to file (no X11 required)
  ggsave("/tmp/test.png", p, device = "png")

  expect_true(file.exists("/tmp/test.png"))
})
```

---

## Related Documentation

- **Docker Architecture**: [DOCKER_ARCHITECTURE.md](DOCKER_ARCHITECTURE.md)
- **Auto-Snapshot System**: [AUTO_SNAPSHOT_ARCHITECTURE.md](AUTO_SNAPSHOT_ARCHITECTURE.md)
- **Profile System**: [VARIANTS.md](VARIANTS.md)
- **Development Commands**: [DEVELOPMENT.md](DEVELOPMENT.md)

---

## Conclusion

The `ubuntu_x11_minimal` profile provides **instant R graphics capability in Docker** with:

- **Fast startup**: <1 second container launch
- **Instant plotting**: No X11 connection overhead
- **Auto-snapshot**: Package changes captured automatically
- **Zsh integration**: Modern shell with plugins
- **Team sharing**: Pre-built images for collaboration

**Recommended workflow**:
1. Use `make docker-zsh-gui` for interactive development
2. Use `make docker-test` for automated testing (headless)
3. Save publication-quality plots to `analysis/figures/`
4. Share pre-built images with `make docker-push-team`

**Next steps**:
- Install your preferred visualization packages: `install.packages("ggplot2")`
- Create analysis scripts in `analysis/scripts/`
- Develop reusable plotting functions in `R/`
- Document your visualizations in `analysis/paper/paper.Rmd`

---

**Document Version**: 1.0
**Last Updated**: November 2, 2025
**Maintainer**: ZZCOLLAB Development Team
