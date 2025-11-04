# GUI Profile Guide

**Running Graphical Applications in Docker Containers**

Version 1.0 | Updated: 2025-10-21

---

## Overview

The **GUI profile** enables running graphical applications inside Docker containers with X11 forwarding. This allows you to use GUI-based tools like terminal emulators (kitty), web browsers (Firefox), text editors (gedit), and R graphical applications (rgl 3D plots, interactive Shiny apps) directly from within your reproducible research environment.

## What's Included

### System Libraries
- **X11 Server**: Core X Window System for graphical display
- **OpenGL**: 3D graphics support (libgl1-mesa, libglu1-mesa)
- **Cairo**: Advanced 2D graphics library
- **Fonts**: DejaVu and Liberation font families for proper text rendering
- **Authentication**: X11 authentication tools (xauth)

### GUI Applications
- **kitty**: Modern, GPU-accelerated terminal emulator
- **Firefox ESR**: Web browser for viewing HTML reports and Shiny apps
- **gedit**: Simple text editor
- **x11-apps**: X11 testing utilities (xeyes, xclock, xlogo)

### R Packages
- **rgl**: Interactive 3D plots and visualizations
- **plotly**: Interactive web-based graphics
- **shiny**: Web application framework
- **Cairo**: High-quality graphics output
- **svglite**: SVG graphics device
- **tidyverse**: Complete data analysis toolkit

## Prerequisites

### macOS
1. **Install XQuartz**:
   ```bash
   brew install --cask xquartz
   ```

2. **Configure XQuartz**:
   - Launch XQuartz (Applications → Utilities → XQuartz)
   - Open Preferences (⌘,)
   - Go to "Security" tab
   - ✅ Enable "Allow connections from network clients"
   - Restart XQuartz

3. **Allow localhost connections**:
   ```bash
   xhost +localhost
   ```

### Linux
1. **X11 is usually pre-installed**. Verify with:
   ```bash
   echo $DISPLAY
   # Should output something like :0 or :1
   ```

2. **If not installed**, install X11:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install xorg x11-apps

   # Fedora/RHEL
   sudo dnf install xorg-x11-server-Xorg x11-apps
   ```

3. **Allow Docker connections**:
   ```bash
   xhost +local:docker
   ```

### Windows
1. **Install VcXsrv** or **Xming**:
   - VcXsrv: https://sourceforge.net/projects/vcxsrv/
   - Xming: https://sourceforge.net/projects/xming/

2. **Launch X server** with:
   - Display number: 0
   - "Disable access control" checked (for testing)

3. **Set DISPLAY variable** in PowerShell:
   ```powershell
   $env:DISPLAY="host.docker.internal:0"
   ```

## Quick Start

### 1. Create Project with GUI Profile

```bash
# Solo developer with GUI profile
zzcollab -r gui

# Team collaboration with GUI profile
zzcollab -t myteam -p myproject -r gui
```

### 2. Build Docker Image

```bash
make docker-build
```

This will create a Docker image with all GUI libraries and applications pre-installed.

### 3. Launch GUI-Enabled Container

#### macOS
```bash
# Ensure XQuartz is running and configured
xhost +localhost

# Launch container with GUI support
make docker-zsh-gui
```

#### Linux
```bash
# Allow Docker to connect to X server
xhost +local:docker

# Launch container with GUI support
make docker-zsh-gui
```

#### Windows
```bash
# Ensure VcXsrv/Xming is running
# Launch container
docker run --rm -it -v $(pwd):/home/analyst/project \
  -e DISPLAY=host.docker.internal:0 your-image-name /bin/zsh
```

### 4. Test GUI Functionality

Inside the container:

```bash
# Test basic X11 connectivity
xeyes &
xclock &

# Launch kitty terminal
kitty &

# Launch Firefox
firefox &

# Test R graphics
R
```

In R:
```r
# Test interactive 3D graphics
library(rgl)
x <- sort(rnorm(1000))
y <- rnorm(1000)
z <- rnorm(1000) + atan2(x, y)
plot3d(x, y, z, col = rainbow(1000))

# Test interactive plotly
library(plotly)
plot_ly(data = iris, x = ~Sepal.Length, y = ~Petal.Length,
        color = ~Species, type = "scatter", mode = "markers")
```

## Usage Examples

### Interactive R Graphics

```r
# 3D scatter plot with rgl
library(rgl)
library(palmerpenguins)

# Create interactive 3D visualization
with(penguins, {
  plot3d(bill_length_mm, bill_depth_mm, body_mass_g,
         col = as.numeric(species),
         size = 5,
         type = "s",
         xlab = "Bill Length (mm)",
         ylab = "Bill Depth (mm)",
         zlab = "Body Mass (g)")
})

# Add legend
legend3d("topright", legend = levels(penguins$species),
         col = 1:3, pch = 16)
```

### Shiny App Development

```r
library(shiny)

# Create simple interactive app
ui <- fluidPage(
  titlePanel("Interactive Penguin Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("species", "Species:",
                  choices = c("Adelie", "Chinstrap", "Gentoo"))
    ),
    mainPanel(
      plotOutput("plot")
    )
  )
)

server <- function(input, output) {
  output$plot <- renderPlot({
    library(palmerpenguins)
    subset_data <- subset(penguins, species == input$species)
    plot(subset_data$bill_length_mm, subset_data$bill_depth_mm,
         main = paste(input$species, "Penguins"),
         xlab = "Bill Length (mm)", ylab = "Bill Depth (mm)")
  })
}

shinyApp(ui = ui, server = server)
```

### Viewing HTML Reports

```bash
# Generate HTML report in R
R -e "rmarkdown::render('analysis/paper/paper.Rmd')"

# View in Firefox
firefox analysis/paper/paper.html &
```

## Advanced Configuration

### Custom Display Settings

```bash
# Use different display number
docker run --rm -it -v $(pwd):/home/analyst/project \
  -e DISPLAY=:1 \
  your-image-name /bin/zsh

# High DPI displays
docker run --rm -it -v $(pwd):/home/analyst/project \
  -e DISPLAY=host.docker.internal:0 \
  -e GDK_SCALE=2 -e GDK_DPI_SCALE=0.5 \
  your-image-name /bin/zsh
```

### GPU Acceleration (Linux)

For better graphics performance on Linux with NVIDIA GPUs:

```bash
docker run --rm -it -v $(pwd):/home/analyst/project \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --gpus all \
  your-image-name /bin/zsh
```

### Persistent X11 Authentication

Create a `.docker_gui` script:

```bash
#!/bin/bash
# Save as ~/.docker_gui
xhost +localhost
export DISPLAY=:0
echo "✅ X11 forwarding enabled"
```

Source before using GUI containers:
```bash
source ~/.docker_gui
make docker-zsh-gui
```

## Troubleshooting

### "Cannot open display" Error

**Symptoms**: Applications fail with `Error: Can't open display: :0`

**Solutions**:

1. **Verify X server is running**:
   ```bash
   # macOS
   ps aux | grep XQuartz

   # Linux
   ps aux | grep X
   ```

2. **Check DISPLAY variable**:
   ```bash
   # Inside container
   echo $DISPLAY
   # Should show: host.docker.internal:0 (macOS) or :0 (Linux)
   ```

3. **Re-run xhost**:
   ```bash
   # macOS
   xhost +localhost

   # Linux
   xhost +local:docker
   ```

4. **Restart XQuartz** (macOS):
   - Quit XQuartz completely (⌘Q)
   - Relaunch from Applications
   - Run `xhost +localhost` again

### Slow Graphics Performance

**Solutions**:

1. **Reduce graphics quality**:
   ```r
   # In R, reduce anti-aliasing
   options(rgl.useNULL = FALSE)
   options(device = "x11")
   ```

2. **Use Linux with GPU** instead of macOS (native X11 is faster)

3. **Close unused GUI applications** inside container

### Font Rendering Issues

**Solutions**:

1. **Install additional fonts**:
   ```bash
   # Inside container
   sudo apt-get update
   sudo apt-get install fonts-noto fonts-roboto
   ```

2. **Rebuild font cache**:
   ```bash
   fc-cache -f -v
   ```

### XQuartz Connection Refused (macOS)

**Symptoms**: `X11 connection rejected because of wrong authentication`

**Solutions**:

1. **Check XQuartz Security settings**:
   - XQuartz → Preferences → Security
   - ✅ "Allow connections from network clients"

2. **Regenerate X authority**:
   ```bash
   rm ~/.Xauthority
   # Restart XQuartz
   ```

3. **Use IP address instead of hostname**:
   ```bash
   docker run --rm -it -v $(pwd):/home/analyst/project \
     -e DISPLAY=$(ifconfig en0 | grep inet | awk '{print $2}'):0 \
     your-image-name /bin/zsh
   ```

## Performance Comparison

| Platform | Graphics Performance | Setup Complexity | Recommended For |
|----------|---------------------|------------------|-----------------|
| **Linux** | ⭐⭐⭐⭐⭐ (Native X11) | ⭐⭐⭐⭐⭐ (Simple) | Production use |
| **macOS** | ⭐⭐⭐ (XQuartz overhead) | ⭐⭐⭐ (Moderate) | Development |
| **Windows** | ⭐⭐ (VcXsrv/Xming) | ⭐⭐ (Complex) | Testing only |

## Security Considerations

### X11 Security Risks

⚠️ **Warning**: Running `xhost +` disables X11 access control and allows any application to connect to your X server. This is convenient for development but has security implications.

**Recommended Secure Workflow**:

1. **Use xhost with specific hosts**:
   ```bash
   # Instead of: xhost +
   # Use:
   xhost +localhost  # macOS
   xhost +local:docker  # Linux
   ```

2. **Disable access after use**:
   ```bash
   # When done with GUI containers
   xhost -localhost  # macOS
   xhost -local:docker  # Linux
   ```

3. **Use SSH X11 forwarding** for remote servers:
   ```bash
   ssh -X user@server
   # Then run Docker containers normally
   ```

## Integration with zzcollab Workflows

### Daily Development Workflow

```bash
# 1. Start day - enable X11
xhost +localhost

# 2. Enter GUI-enabled container
make docker-zsh-gui

# 3. Work with interactive graphics
R
# ... run analyses with rgl, plotly, etc. ...
quit()

# 4. View generated reports
firefox analysis/paper/paper.html &

# 5. Exit container
exit

# 6. End day - disable X11 (optional)
xhost -localhost
```

### Team Collaboration

```bash
# Team Lead: Create GUI-enabled team image
zzcollab -t myteam -p viz-project -r gui
make docker-build
make docker-push-team
git add . && git commit -m "Add GUI-enabled environment" && git push

# Team Member: Use team's GUI image
git clone https://github.com/myteam/viz-project.git
cd viz-project
zzcollab -u
make docker-zsh-gui
```

### CI/CD Integration

GUI applications typically cannot run in CI/CD (no display server). For headless rendering:

```yaml
# .github/workflows/render-plots.yml
- name: Render plots headless
  run: |
    docker run --rm -v $PWD:/project \
      -e DISPLAY=:99 \
      myimage \
      Xvfb :99 -screen 0 1024x768x24 & \
      R -e "rgl::rgl.snapshot('plot.png')"
```

## Alternative: RStudio Server (No X11 Required)

If you only need R graphics (not standalone GUI apps), RStudio Server provides web-based graphics without X11:

```bash
make docker-rstudio
# Open http://localhost:8787
# Username: analyst, Password: analyst
```

RStudio Server provides:
- ✅ Interactive plots (base, ggplot2, plotly)
- ✅ 3D graphics with rgl (webGL export)
- ✅ Shiny app development
- ✅ Works on all platforms without X11
- ❌ No standalone GUI apps (firefox, kitty, etc.)

## References

- **XQuartz**: https://www.xquartz.org/
- **X11 Forwarding**: https://wiki.archlinux.org/title/OpenSSH#X11_forwarding
- **Docker + X11**: https://cuneyt.aliustaoglu.biz/en/running-gui-applications-in-docker-on-windows-linux-mac-hosts/
- **rgl Package**: https://dmurdoch.github.io/rgl/
- **Plotly for R**: https://plotly.com/r/

## FAQ

**Q: Can I run GPU-accelerated graphics?**
A: Yes, on Linux with NVIDIA GPUs. Use `--gpus all` flag. Not supported on macOS/Windows.

**Q: Why is XQuartz so slow on macOS?**
A: XQuartz runs X11 in emulation mode. For better performance, use Linux or RStudio Server.

**Q: Can I use Wayland instead of X11?**
A: Not yet. Docker GUI support currently requires X11. Wayland support is experimental.

**Q: Does this work with Windows WSL2?**
A: Yes, with WSLg (Windows 11+). WSL2 on Windows 11 includes built-in X11 server support.

**Q: How much larger is the GUI image?**
A: ~1GB additional size due to X11 libraries, fonts, and GUI applications.

## Next Steps

- **Explore Interactive Visualizations**: See `docs/guides/visualization.md`
- **Shiny App Development**: See `docs/guides/shiny.md`
- **3D Graphics with rgl**: See `vignettes/advanced-graphics.Rmd`
- **General Docker Guide**: See `docs/DOCKER_ARCHITECTURE.md`

---

**Need Help?** Open an issue at https://github.com/rgt47/zzcollab/issues
