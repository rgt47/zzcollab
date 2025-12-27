# X11 Graphics Guide

**Running Graphical R Applications in Docker Containers**

---

## Table of Contents

1. [Overview](#overview)
2. [What's Included](#whats-included)
3. [System Requirements](#system-requirements)
4. [Quick Start](#quick-start)
5. [Detailed Workflow](#detailed-workflow)
6. [Plotting Examples](#plotting-examples)
7. [Advanced Configuration](#advanced-configuration)
8. [Troubleshooting](#troubleshooting)
9. [Performance](#performance)
10. [Security Considerations](#security-considerations)
11. [CI/CD Integration](#cicd-integration)

---

## Overview

ZZCOLLAB provides X11-enabled Docker profiles for running graphical R
applications. This enables:

- Interactive plots that open on your host screen
- 3D visualizations with rgl
- Shiny app development
- GUI tools (browsers, terminals) inside containers

**Available X11 Profiles**:

| Profile | Size | Description |
|---------|------|-------------|
| `ubuntu_x11_minimal` | ~1.5GB | Lightweight with X11 graphics, Zsh, Vim |
| `ubuntu_x11_analysis` | ~2.0GB | Analysis tools + X11 |
| `gui` | ~2.5GB | Full GUI with Firefox, kitty, gedit |

**Use Cases**:
- Interactive data exploration
- Development with immediate visual feedback
- Teaching/demos requiring live plotting
- Shiny app development and testing

---

## What's Included

### System Libraries
- **X11 Server**: Core X Window System for graphical display
- **OpenGL**: 3D graphics support (libgl1-mesa, libglu1-mesa)
- **Cairo**: Advanced 2D graphics library
- **Fonts**: DejaVu and Liberation font families

### GUI Applications (gui profile)
- **kitty**: Modern, GPU-accelerated terminal emulator
- **Firefox ESR**: Web browser for viewing HTML reports and Shiny apps
- **gedit**: Simple text editor
- **x11-apps**: X11 testing utilities (xeyes, xclock)

### R Packages
- **rgl**: Interactive 3D plots and visualizations
- **plotly**: Interactive web-based graphics
- **shiny**: Web application framework
- **Cairo**: High-quality graphics output
- **svglite**: SVG graphics device

---

## System Requirements

### macOS

**1. Install XQuartz**:
```bash
brew install --cask xquartz
```

**2. Log out and log back in** (activates system integration)

**3. Configure XQuartz**:
- Launch XQuartz (Applications → Utilities → XQuartz)
- Open Preferences (⌘,) → Security tab
- Enable "Allow connections from network clients"
- Restart XQuartz

**4. Allow localhost connections**:
```bash
xhost +localhost
```

### Linux

**1. Verify X11** (usually pre-installed):
```bash
echo $DISPLAY
# Should output :0 or :1
```

**2. Install if needed**:
```bash
# Ubuntu/Debian
sudo apt-get install xorg x11-apps

# Fedora/RHEL
sudo dnf install xorg-x11-server-Xorg x11-apps
```

**3. Allow Docker connections**:
```bash
xhost +local:docker
```

### Windows

**1. Install VcXsrv** or **Xming**:
- VcXsrv: https://sourceforge.net/projects/vcxsrv/
- Or: `choco install vcxsrv`

**2. Launch X server** with:
- Display number: 0
- "Disable access control" checked

**3. Set DISPLAY variable**:
```powershell
$env:DISPLAY="host.docker.internal:0"
```

---

## Quick Start

### 1. Create Project with X11 Profile

```bash
# Solo developer
zzcollab --profile-name ubuntu_x11_minimal

# Team project
zzcollab -t myteam -p analysis -r ubuntu_x11_minimal

# Full GUI profile
zzcollab -r gui
```

### 2. Build Docker Image

```bash
make docker-build
# Build time: ~5-8 minutes (first time only)
```

### 3. Launch with X11 Forwarding

```bash
# macOS (automatic XQuartz setup)
make r

# Linux
xhost +local:docker
make r

# Windows
export DISPLAY=localhost:0.0
make r
```

### 4. Test R Plotting

Inside the container:
```r
# Start R
R

# Test basic plotting
plot(1:10, 1:10, main="X11 Test", col="blue", pch=19)

# Test ggplot2
library(ggplot2)
ggplot(mtcars, aes(mpg, hp)) + geom_point() + theme_minimal()
```

**Expected behavior**: Plot window opens on your host screen.

### 5. Exit (Auto-Snapshot)

```bash
exit
# Auto-snapshot captures package changes
# renv.lock updated automatically
```

---

## Detailed Workflow

### Complete Development Session

```bash
# PHASE 1: SETUP (One-time)
brew install --cask xquartz    # macOS only
# Log out and log back in

mkdir ~/projects/data-viz && cd ~/projects/data-viz
zzcollab --profile-name ubuntu_x11_minimal
git init && git add . && git commit -m "Initial setup"
make docker-build

# PHASE 2: DEVELOPMENT (Daily)
make r

# Inside container:
R
> install.packages("ggplot2")
> install.packages("patchwork")
> source("analysis/scripts/explore_data.R")
> quit()
exit

# PHASE 3: COMMIT
git add .
git commit -m "Add visualization analysis"
git push

# PHASE 4: TEAM SHARING
make docker-push-team

# Team members:
git clone https://github.com/myteam/data-viz.git && cd data-viz
zzcollab --use-team-image
make r    # Instant startup, packages pre-installed
```

---

## Plotting Examples

### Basic R Graphics

```r
# Simple scatter plot
plot(iris$Sepal.Length, iris$Sepal.Width,
     col = iris$Species, pch = 19,
     main = "Iris Dataset",
     xlab = "Sepal Length", ylab = "Sepal Width")

# Multiple plots
par(mfrow = c(2, 2))
plot(iris$Sepal.Length, iris$Sepal.Width, main="Sepal")
plot(iris$Petal.Length, iris$Petal.Width, main="Petal")
hist(iris$Sepal.Length, main="Sepal Length Distribution")
boxplot(Sepal.Width ~ Species, data=iris)
```

### ggplot2 Visualization

```r
library(ggplot2)
library(patchwork)

p1 <- ggplot(mtcars, aes(mpg, hp, color = factor(cyl))) +
  geom_point(size = 3) +
  geom_smooth(method = "lm", se = FALSE) +
  theme_minimal()

p2 <- ggplot(mtcars, aes(factor(cyl), mpg)) +
  geom_boxplot()

p1 | p2  # Side by side with patchwork
```

### Interactive 3D Graphics

```r
library(rgl)
library(palmerpenguins)

with(penguins, {
  plot3d(bill_length_mm, bill_depth_mm, body_mass_g,
         col = as.numeric(species), size = 5, type = "s")
})
```

### Shiny App Development

```r
library(shiny)

ui <- fluidPage(
  titlePanel("Interactive Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("species", "Species:", choices = c("Adelie", "Chinstrap", "Gentoo"))
    ),
    mainPanel(plotOutput("plot"))
  )
)

server <- function(input, output) {
  output$plot <- renderPlot({
    subset_data <- subset(palmerpenguins::penguins, species == input$species)
    plot(subset_data$bill_length_mm, subset_data$bill_depth_mm)
  })
}

shinyApp(ui, server)
```

### Viewing HTML Reports

```bash
# Generate HTML report
R -e "rmarkdown::render('analysis/report/report.Rmd')"

# View in Firefox (gui profile)
firefox analysis/report/paper.html &
```

---

## Advanced Configuration

### Custom Display Settings

```bash
# High DPI displays
docker run --rm -it \
  -e DISPLAY=host.docker.internal:0 \
  -e GDK_SCALE=2 -e GDK_DPI_SCALE=0.5 \
  your-image /bin/zsh
```

### GPU Acceleration (Linux)

```bash
docker run --rm -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --gpus all \
  your-image /bin/zsh
```

### Linux X11 Socket Mounting

```bash
docker run --rm -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $HOME/.Xauthority:/home/analyst/.Xauthority:ro \
  -v $(PWD):/home/analyst/project \
  your-image zsh
```

### Persistent X11 Setup Script

Create `~/.docker_gui`:
```bash
#!/bin/bash
xhost +localhost
export DISPLAY=:0
echo "X11 forwarding enabled"
```

Source before using: `source ~/.docker_gui && make r`

### Remote X11 Forwarding

```bash
# SSH with X11 forwarding
ssh -X your-server.com
cd project && make r
# Graphics display on your local machine
```

---

## Troubleshooting

### "Cannot open display" Error

**Symptom**: `Error: unable to open connection to X11 display`

**Fix (macOS)**:
```bash
# Check XQuartz is running
ps aux | grep XQuartz

# Restart XQuartz
killall XQuartz
open -a XQuartz
xhost +localhost

# Retry
make r
```

**Fix (Linux)**:
```bash
xhost +local:docker
make r
```

### XQuartz Not Found

```bash
brew install --cask xquartz
# IMPORTANT: Log out and log back in
```

### Black/Empty Plot Window

```r
# Check graphics capabilities
capabilities()
# Look for X11: TRUE, cairo: TRUE

# Explicitly set device
options(device = "X11")
dev.off()
X11()
plot(1:10)
```

### Slow Graphics Performance

```r
# Use cairo device (faster)
X11(type = "cairo")

# Or disable anti-aliasing
X11(antialias = "none")

# Alternative: save to files
png("output.png", width = 800, height = 600)
plot(1:10)
dev.off()
```

### Font Rendering Issues

```bash
# Inside container
sudo apt-get install fonts-dejavu fonts-liberation
fc-cache -fv
```

### XQuartz Connection Refused

```bash
# Check Security settings
# XQuartz → Preferences → Security → Allow network clients

# Regenerate authority
rm ~/.Xauthority
# Restart XQuartz
```

### Multiple Plot Windows

```r
# Open new windows explicitly
X11()  # Device 2
plot(1:10)

X11()  # Device 3
plot(10:1)

# Switch between devices
dev.set(2)
dev.set(3)
```

---

## Performance

### Platform Comparison

| Platform | Graphics | Setup | Recommended For |
|----------|----------|-------|-----------------|
| **Linux** | Native X11 | Simple | Production |
| **macOS** | XQuartz | Moderate | Development |
| **Windows** | VcXsrv | Complex | Testing only |

### Startup Time

| Configuration | Build | Startup | Plot Rendering |
|--------------|-------|---------|----------------|
| X11 profile (pre-built) | 0s | <1s | Instant |
| X11 profile (first build) | 5-8 min | <1s | Instant |
| RStudio Server | 8-12 min | ~3s | ~500ms delay |

### Resource Usage

```bash
docker stats
# Typical: CPU 5-15% (idle), Memory 200-500 MB
```

---

## Security Considerations

**Warning**: `xhost +` disables X11 access control.

**Recommended Secure Workflow**:

```bash
# Use specific hosts instead of xhost +
xhost +localhost      # macOS
xhost +local:docker   # Linux

# Disable after use
xhost -localhost      # macOS
xhost -local:docker   # Linux
```

---

## CI/CD Integration

### Headless Testing in GitHub Actions

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
        run: xvfb-run make docker-test-graphics
```

### Headless R Test

```r
test_that("ggplot2 rendering works", {
  library(ggplot2)
  p <- ggplot(mtcars, aes(mpg, hp)) + geom_point()
  ggsave("/tmp/test.png", p, device = "png")
  expect_true(file.exists("/tmp/test.png"))
})
```

---

## Alternative: RStudio Server (No X11)

If you only need R graphics (not standalone GUI apps):

```bash
make docker-rstudio
# Open http://localhost:8787
```

RStudio Server provides:
- Interactive plots (base, ggplot2, plotly)
- 3D graphics via webGL
- Shiny app development
- Works on all platforms without X11

---

## Related Documentation

- [variants.md](variants.md) - Docker profile system
- [docker-architecture.md](docker-architecture.md) - Docker technical details
- [development.md](development.md) - Development commands

---

**Last Updated**: December 2025
