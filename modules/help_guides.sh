#!/bin/bash
##############################################################################
# ZZCOLLAB PRACTICAL GUIDES MODULE
##############################################################################
#
# PURPOSE: Practical how-to guides and workflows
#          - Quick start for individual researchers
#          - Daily workflow guidance
#          - Troubleshooting common issues
#          - Docker essentials
#          - Package management (renv) guide
#
# DEPENDENCIES: core.sh (logging)
#
# TRACKING: No file creation - pure documentation
##############################################################################

# Validate required modules are loaded
require_module "core"

#=============================================================================
# SOLO STUDENT QUICK START
#=============================================================================

# Already included in help.sh - keeping reference here for completeness

#=============================================================================
# DAILY WORKFLOW GUIDE
#=============================================================================

# Function: show_workflow_help
# Purpose: Daily development workflow for students/beginners
show_workflow_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_workflow_help_content
    else
        show_workflow_help_content | "${PAGER:-less}" -R
    fi
}

show_workflow_help_content() {
    cat << 'EOF'
🔄 DAILY DEVELOPMENT WORKFLOW

═══════════════════════════════════════════════════════════════════════════
UNDERSTANDING THE WORKFLOW
═══════════════════════════════════════════════════════════════════════════

Key Concept: You work in TWO places:
1. HOST (your regular computer) - for git, file management
2. CONTAINER (isolated R environment) - for R analysis, RStudio

Think of the container as a "virtual computer" that has R perfectly configured.

═══════════════════════════════════════════════════════════════════════════
COMPLETE DAILY WORKFLOW
═══════════════════════════════════════════════════════════════════════════

Morning: Starting Your Work Session
──────────────────────────────────────────────────────────────────────────
💻 HOST (Terminal):
   cd ~/projects/my-analysis
   make docker-rstudio

🐳 CONTAINER (Browser):
   • Browser opens at localhost:8787
   • Login: analyst / analyst
   • You're now in RStudio running in Docker

During the Day: Doing Your Analysis
──────────────────────────────────────────────────────────────────────────
🐳 CONTAINER (RStudio):
   • Write R code
   • Create visualizations
   • Knit R Markdown documents
   • Install packages: install.packages("packagename")
   • Update dependencies: renv::snapshot()

💻 HOST (Your Computer):
   • Files automatically sync!
   • Check in Finder/Explorer: changes appear immediately
   • Can edit with your favorite editor if you prefer

Evening: Ending Your Work Session
──────────────────────────────────────────────────────────────────────────
🐳 CONTAINER (Browser):
   • Save all files in RStudio
   • Close browser tab

💻 HOST (Terminal):
   • Press Ctrl+C to stop container
   • Everything is saved!

Next Day: Resuming Work
──────────────────────────────────────────────────────────────────────────
💻 HOST (Terminal):
   cd ~/projects/my-analysis
   make docker-rstudio

🐳 CONTAINER (Browser):
   • Exactly where you left off!
   • All files, packages, settings restored

═══════════════════════════════════════════════════════════════════════════
HOST VS CONTAINER: WHAT TO DO WHERE
═══════════════════════════════════════════════════════════════════════════

Do on HOST (💻 your computer):
──────────────────────────────────────────────────────────────────────────
✅ Git operations:
   git add .
   git commit -m "Add analysis"
   git push

✅ File organization:
   mkdir analysis/scripts/chapter2
   cp data.csv analysis/data/raw_data/

✅ Start/stop containers:
   make docker-rstudio
   make docker-zsh
   Ctrl+C (to stop)

✅ View files in Finder/Explorer
   Just browse to your project folder

Do in CONTAINER (🐳 Docker):
──────────────────────────────────────────────────────────────────────────
✅ R analysis work:
   • Write R scripts
   • Create plots
   • Statistical modeling
   • Data transformation

✅ Package management:
   install.packages("tidyverse")
   renv::snapshot()
   renv::restore()

✅ R Markdown:
   • Create .Rmd files
   • Knit to HTML/PDF
   • Generate reports

✅ Testing:
   devtools::test()
   devtools::check()

═══════════════════════════════════════════════════════════════════════════
COMMON WORKFLOW PATTERNS
═══════════════════════════════════════════════════════════════════════════

Pattern 1: Quick Analysis Session
──────────────────────────────────────────────────────────────────────────
# Morning
cd ~/projects/homework2
make docker-rstudio
# ... work for 2 hours in RStudio ...
# Close browser, Ctrl+C in terminal

Pattern 2: Multiple Edit Cycles
──────────────────────────────────────────────────────────────────────────
# Start container
make docker-rstudio

# In RStudio:
# Edit script1.R → Run → See results
# Edit script1.R → Run → See results
# Edit script1.R → Run → See results

# When done:
# Close browser, Ctrl+C

Pattern 3: Long-Running Analysis
──────────────────────────────────────────────────────────────────────────
# Start container
make docker-rstudio

# In RStudio, run long analysis:
source("analysis/scripts/big_model.R")

# Leave it running, do other things
# Come back later, results ready!

# Save results, close browser, Ctrl+C

Pattern 4: Git Workflow
──────────────────────────────────────────────────────────────────────────
# Do analysis work (in container)
make docker-rstudio
# ... create analysis.R, plots.png ...
# Close browser, Ctrl+C

# Commit work (on host)
git add analysis/scripts/analysis.R
git add analysis/figures/plots.png
git commit -m "Add customer analysis"
git push

Pattern 5: Package Installation
──────────────────────────────────────────────────────────────────────────
# In RStudio (container):
install.packages("forecast")  # Install new package
renv::snapshot()              # Record in renv.lock

# Close container, Ctrl+C

# On host:
git add renv.lock
git commit -m "Add forecast package"

═══════════════════════════════════════════════════════════════════════════
FILE PERSISTENCE - WHAT GETS SAVED?
═══════════════════════════════════════════════════════════════════════════

✅ ALWAYS SAVED (in mounted /project directory):
──────────────────────────────────────────────────────────────────────────
• All files in /home/analyst/project/
• R scripts (.R, .Rmd)
• Data files
• Generated plots
• renv.lock (package versions)
• Git repository

❌ NOT SAVED (outside mounted directory):
──────────────────────────────────────────────────────────────────────────
• Files in /home/analyst/ (not in /project)
• System packages installed with apt-get
• Changes to container system files
• RStudio preferences (use dotfiles for this!)

💡 SOLUTION: Always work in /home/analyst/project
   RStudio starts there automatically - you're safe!

═══════════════════════════════════════════════════════════════════════════
TYPICAL PROJECT LIFECYCLE
═══════════════════════════════════════════════════════════════════════════

Week 1: Project Start
──────────────────────────────────────────────────────────────────────────
Day 1 (Monday):
  mkdir ~/projects/final-project && cd ~/projects/final-project
  zzcollab -p final-project
  make docker-rstudio
  # Set up project structure in RStudio
  # Ctrl+C when done

Day 2 (Tuesday):
  cd ~/projects/final-project
  make docker-rstudio
  # Import data, initial exploration
  # Ctrl+C when done

Day 3-5 (Wed-Fri):
  cd ~/projects/final-project
  make docker-rstudio
  # Data cleaning, analysis
  # Ctrl+C each day

Week 2: Analysis Development
──────────────────────────────────────────────────────────────────────────
Daily routine:
  cd ~/projects/final-project
  make docker-rstudio
  # Develop analysis, create visualizations
  # Ctrl+C when done

Periodic git commits:
  git add .
  git commit -m "Progress update"
  git push

Week 3-4: Report Writing
──────────────────────────────────────────────────────────────────────────
Daily routine:
  cd ~/projects/final-project
  make docker-rstudio
  # Write R Markdown report
  # Knit to see results
  # Ctrl+C when done

Final submission:
  # In RStudio: Knit final report
  # Ctrl+C
  git add final_report.html
  git commit -m "Final submission"
  git push

═══════════════════════════════════════════════════════════════════════════
COMMON WORKFLOW QUESTIONS
═══════════════════════════════════════════════════════════════════════════

Q: "Do I need to run 'zzcollab' every time I work on my project?"
A: NO! Only once per project.
   Daily workflow: cd project && make docker-rstudio

Q: "Can I edit files on my computer instead of in RStudio?"
A: YES! Files sync both ways.
   Edit in VSCode/Sublime on host → See changes in RStudio
   Edit in RStudio → See changes on host

Q: "What if I close the terminal accidentally?"
A: No problem!
   Open new terminal: cd project && make docker-rstudio
   Everything restored!

Q: "Can I work on multiple projects simultaneously?"
A: YES! Open separate terminals for each:
   Terminal 1: cd project1 && make docker-rstudio  # Port 8787
   Terminal 2: cd project2 && make docker-rstudio  # ERROR - port in use!

   Use different ports:
   Terminal 2: docker run -p 8788:8787 ... (advanced)
   Or: Work on one at a time (easier)

Q: "How do I know if the container is running?"
A: Check terminal:
   • Container running = terminal shows logs, can't type commands
   • Container stopped = you see the prompt ($)

Q: "What happens if my computer crashes?"
A: As long as you saved in RStudio, files are safe!
   Restart: cd project && make docker-rstudio

Q: "Can I access my container from another computer?"
A: Not easily. RStudio is on localhost (this computer only).
   For remote access, need port forwarding (advanced)

Q: "Should I commit renv.lock to git?"
A: YES! This ensures reproducibility.
   renv.lock records exact package versions.

═══════════════════════════════════════════════════════════════════════════
WORKFLOW TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

Issue: "My changes disappeared!"
──────────────────────────────────────────────────────────────────────────
Cause: Worked outside /home/analyst/project
Solution:
  • Always work in /home/analyst/project
  • RStudio starts there by default
  • If you cd elsewhere, files won't persist

Issue: "Can't connect to RStudio"
──────────────────────────────────────────────────────────────────────────
Check:
  1. Is container running? (terminal shows logs)
  2. Correct URL? http://localhost:8787
  3. Port conflict? (Try: make docker-rstudio again)

Issue: "Package disappeared after restart"
──────────────────────────────────────────────────────────────────────────
Cause: Installed package but didn't run renv::snapshot()
Solution:
  install.packages("packagename")
  renv::snapshot()  # Don't forget this!

Issue: "Git won't commit"
──────────────────────────────────────────────────────────────────────────
Cause: Trying git commands in container
Solution:
  • Exit container (Ctrl+C)
  • Run git on host (your terminal)

═══════════════════════════════════════════════════════════════════════════
ADVANCED WORKFLOW PATTERNS
═══════════════════════════════════════════════════════════════════════════

Use command-line instead of RStudio:
──────────────────────────────────────────────────────────────────────────
make docker-zsh
# Interactive shell in container
# Run R scripts: Rscript analysis.R
# exit when done

Run specific R commands:
──────────────────────────────────────────────────────────────────────────
make docker-r
# Opens R console
# Run commands
# q() to quit

Run tests:
──────────────────────────────────────────────────────────────────────────
make docker-test
# Runs all testthat tests
# See results in terminal

Render documents:
──────────────────────────────────────────────────────────────────────────
make docker-render
# Renders all R Markdown documents
# Outputs in analysis/figures/

═══════════════════════════════════════════════════════════════════════════
WORKFLOW BEST PRACTICES
═══════════════════════════════════════════════════════════════════════════

1. One container at a time (easier to manage)
2. Always Ctrl+C to cleanly stop containers
3. Run renv::snapshot() after installing packages
4. Commit to git frequently (don't lose work!)
5. Use meaningful commit messages
6. Keep raw data in analysis/data/raw_data/ (never modify!)
7. Generated files in analysis/figures/ or derived_data/
8. Scripts in analysis/scripts/
9. Functions in R/ if you extract reusable code
10. Test your analysis from scratch occasionally (true reproducibility!)

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help-solo               # Solo student quick start
  zzcollab --help-troubleshooting    # Fix common problems
  zzcollab --help-renv               # Package management
EOF
}

#=============================================================================
# TROUBLESHOOTING GUIDE
#=============================================================================

# Function: show_troubleshooting_help
# Purpose: Common issues and solutions
show_troubleshooting_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_troubleshooting_help_content
    else
        show_troubleshooting_help_content | "${PAGER:-less}" -R
    fi
}

show_troubleshooting_help_content() {
    cat << 'EOF'
🔧 TROUBLESHOOTING GUIDE

This guide covers the most common issues and their solutions.

═══════════════════════════════════════════════════════════════════════════
TOP 10 COMMON ISSUES
═══════════════════════════════════════════════════════════════════════════

1. Docker Not Running
2. Port Already in Use
3. Image Not Found
4. Permission Denied
5. Changes Disappeared
6. Package Installation Failed
7. RStudio Won't Connect
8. GitHub Authentication Failed
9. renv Issues
10. Build Takes Too Long

═══════════════════════════════════════════════════════════════════════════
ISSUE 1: Docker Not Running
═══════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
  Cannot connect to the Docker daemon
  Is the docker daemon running?

CAUSE: Docker Desktop not started

SOLUTIONS:
  macOS: Open Docker Desktop from Applications
  Windows: Start Docker Desktop from Start Menu
  Linux: sudo systemctl start docker

VERIFY:
  docker ps
  # Should show running containers or empty list (not error)

═══════════════════════════════════════════════════════════════════════════
ISSUE 2: Port Already in Use (localhost:8787)
═══════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
  Bind for 0.0.0.0:8787 failed: port is already allocated

CAUSE: Another RStudio container using port 8787

SOLUTIONS:
  Option 1: Stop the other container
    docker ps                    # Find container ID
    docker stop <container-id>   # Stop it
    make docker-rstudio          # Try again

  Option 2: Find which project is using the port
    docker ps --format "{{.Names}}: {{.Ports}}"
    # Shows which project owns port 8787
    cd /path/to/that/project
    Ctrl+C in that terminal

  Option 3: Use different port (advanced)
    # Edit Makefile, change 8787 to 8788

═══════════════════════════════════════════════════════════════════════════
ISSUE 3: Image Not Found
═══════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
  Unable to find image 'myteam/projectcore-rstudio:latest' locally
  Error response from daemon: pull access denied

CAUSE: Team image not built or wrong team name

SOLUTIONS:
  For solo researchers:
    # Make sure you ran zzcollab in this project
    zzcollab -p projectname

  For team members:
    # Team lead needs to build and push images first
    # Or: Team image name doesn't match
    # Check DESCRIPTION file for correct team name

  Rebuild image:
    cd /path/to/project
    make docker-build

═══════════════════════════════════════════════════════════════════════════
ISSUE 4: Permission Denied
═══════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
  Permission denied while trying to connect to Docker daemon
  Got permission denied while trying to connect to the Docker daemon socket

CAUSE: User not in docker group (Linux)

SOLUTIONS:
  Linux:
    sudo usermod -aG docker $USER
    # Log out and back in

  macOS/Windows:
    # Usually not an issue
    # Restart Docker Desktop

  File permission issues:
    # Check project directory ownership
    ls -la
    # Should be owned by you, not root

═══════════════════════════════════════════════════════════════════════════
ISSUE 5: My Changes Disappeared!
═══════════════════════════════════════════════════════════════════════════

CAUSE: Worked outside /home/analyst/project directory

EXPLANATION:
  Only files in /home/analyst/project persist
  Files elsewhere in container are lost when container stops

SOLUTIONS:
  Prevention:
    • Always work in /home/analyst/project
    • RStudio starts there automatically
    • Don't cd to other directories

  Recovery (if happened):
    • Sorry, files outside mounted directory are lost
    • Lesson learned: stay in /project!

  Verify you're in right place:
    In RStudio: getwd()
    # Should show: /home/analyst/project

═══════════════════════════════════════════════════════════════════════════
ISSUE 6: Package Installation Failed
═══════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
  Installation of package 'X' had non-zero exit status

COMMON CAUSES & SOLUTIONS:

Cause: Missing system dependencies
  Solution:
    # Some packages need system libraries
    # Example: sf package needs gdal, geos
    # Contact zzcollab maintainer or use different build mode

Cause: CRAN server down
  Solution:
    # Try different mirror
    install.packages("packagename",
                     repos = "https://cloud.r-project.org")

Cause: Package not on CRAN
  Solution:
    # Install from GitHub
    remotes::install_github("user/package")

Cause: Package requires newer R version
  Solution:
    # Check package requirements
    # May need to use older package version
    remotes::install_version("packagename", version = "1.0.0")

═══════════════════════════════════════════════════════════════════════════
ISSUE 7: RStudio Won't Connect (localhost:8787)
═══════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
  This site can't be reached
  localhost refused to connect

DIAGNOSTIC STEPS:

1. Is container running?
   # Terminal should show logs, not prompt
   # If you see $ prompt, container stopped

2. Is it RStudio container?
   make docker-rstudio
   # NOT: make docker-zsh or make docker-r

3. Check container status:
   docker ps
   # Should see container with port 0.0.0.0:8787->8787

4. Try different browser:
   # Chrome, Firefox, Safari
   # Some browsers cache connection failures

5. Check firewall:
   # Firewall might block localhost
   # Try: http://127.0.0.1:8787

SOLUTIONS:
  Restart container:
    Ctrl+C in terminal
    make docker-rstudio

  Check port:
    lsof -i :8787  # macOS/Linux
    # Shows what's using port 8787

═══════════════════════════════════════════════════════════════════════════
ISSUE 8: GitHub Authentication Failed
═══════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
  fatal: Authentication failed
  gh: command not found

CAUSE: GitHub CLI not installed or not authenticated

SOLUTIONS:
  Install gh:
    macOS:   brew install gh
    Linux:   sudo apt install gh
    Windows: winget install GitHub.cli

  Authenticate:
    gh auth login
    # Follow prompts, choose HTTPS
    # Use web browser for easiest setup

  Verify:
    gh auth status
    # Should show: ✓ Logged in to github.com

  Alternative (no -G flag):
    # Skip automatic GitHub repo creation
    zzcollab -p project  # No -G flag
    # Create repo manually later

═══════════════════════════════════════════════════════════════════════════
ISSUE 9: renv Problems
═══════════════════════════════════════════════════════════════════════════

ERROR: "renv is not installed"
  Solution:
    install.packages("renv")

ERROR: "renv.lock is out of sync"
  Solution:
    renv::status()    # See what's wrong
    renv::snapshot()  # Update lockfile

ERROR: "Package versions don't match"
  Solution:
    renv::restore()   # Restore from lockfile

ERROR: "renv cache is corrupted"
  Solution:
    # Delete cache, reinstall
    renv::purge("packagename")
    install.packages("packagename")

Common workflow:
  install.packages("newpackage")  # Install
  renv::snapshot()                # Record
  # Commit renv.lock to git

═══════════════════════════════════════════════════════════════════════════
ISSUE 10: Build Takes Too Long
═══════════════════════════════════════════════════════════════════════════

PROBLEM: Docker build taking 15-20 minutes

SOLUTIONS:
  Use faster build mode:
    zzcollab --config set build-mode "fast"
    # 9 packages, ~3 minutes

  Or: Minimal mode:
    zzcollab --config set build-mode "minimal"
    # 3 packages, ~30 seconds
    # Install additional packages as needed

  Reuse team base image:
    # See: zzcollab --help-quickstart
    # Create one comprehensive base image
    # Reuse for all projects (~30 seconds each)

  Check Docker resources:
    # Docker Desktop → Settings → Resources
    # Increase CPU/Memory allocation

═══════════════════════════════════════════════════════════════════════════
ADDITIONAL COMMON ISSUES
═══════════════════════════════════════════════════════════════════════════

Issue: "make: command not found"
──────────────────────────────────────────────────────────────────────────
Install make:
  macOS:   xcode-select --install
  Linux:   sudo apt install build-essential
  Windows: Use WSL2 or install make for Windows

Issue: "Container exits immediately"
──────────────────────────────────────────────────────────────────────────
Check logs:
  docker logs <container-name>
  # Shows why container failed

Common cause: Syntax error in Dockerfile
  # Check Dockerfile for typos

Issue: "zzcollab: command not found"
──────────────────────────────────────────────────────────────────────────
zzcollab not in PATH:
  # Add to ~/.bashrc or ~/.zshrc:
  export PATH="$HOME/bin:$PATH"

  # Or use full path:
  ~/bin/zzcollab

Issue: "Different results on different computers"
──────────────────────────────────────────────────────────────────────────
This is the problem zzcollab solves!

Likely cause: Different package versions
Solution:
  # Ensure renv.lock is committed
  git add renv.lock
  git commit -m "Lock package versions"

  # On other computer:
  git pull
  make docker-rstudio
  # In RStudio:
  renv::restore()

═══════════════════════════════════════════════════════════════════════════
DIAGNOSTIC COMMANDS
═══════════════════════════════════════════════════════════════════════════

Check Docker status:
  docker --version              # Docker installed?
  docker ps                     # Running containers
  docker images                 # Available images
  docker system df              # Disk usage

Check zzcollab project:
  ls -la                        # Project files present?
  cat DESCRIPTION               # Check team/project name
  cat renv.lock | head          # Package versions

Check R environment:
  # In R console:
  .libPaths()                   # Where packages installed
  installed.packages()[,1]      # What's installed
  renv::status()                # renv state

Network diagnostics:
  ping -c 3 cloud.r-project.org  # Can reach CRAN?
  curl -I https://github.com     # GitHub accessible?

═══════════════════════════════════════════════════════════════════════════
GETTING HELP
═══════════════════════════════════════════════════════════════════════════

If issue persists:

1. Check zzcollab documentation:
   zzcollab --help
   zzcollab --help-workflow
   zzcollab --help-docker
   zzcollab --help-renv

2. Search GitHub issues:
   https://github.com/rgt47/zzcollab/issues

3. Ask for help (include this info):
   • Operating system (macOS/Linux/Windows)
   • Docker version: docker --version
   • zzcollab command you ran
   • Complete error message
   • Output of: docker ps

4. Create GitHub issue:
   https://github.com/rgt47/zzcollab/issues/new

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help              # General help
  zzcollab --help-docker       # Docker essentials
  zzcollab --help-workflow     # Daily workflow
  zzcollab --help-renv         # Package management
EOF
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

#=============================================================================
# CONFIGURATION SYSTEM GUIDE
#=============================================================================

# Function: show_config_help
# Purpose: Configuration system comprehensive guide
show_config_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_config_help_content
    else
        show_config_help_content | "${PAGER:-less}" -R
    fi
}

show_config_help_content() {
    cat << 'EOF'
⚙️ CONFIGURATION SYSTEM GUIDE

Stop typing the same flags repeatedly! Configure zzcollab once, use everywhere.

═══════════════════════════════════════════════════════════════════════════
WHY USE CONFIGURATION?
═══════════════════════════════════════════════════════════════════════════

WITHOUT CONFIG (repetitive):
  zzcollab -t myname -p project1 -S -d ~/dotfiles
  zzcollab -t myname -p project2 -S -d ~/dotfiles
  zzcollab -t myname -p project3 -S -d ~/dotfiles
  # Typing "myname" and "~/dotfiles" every time!

WITH CONFIG (simple):
  zzcollab --config set team-name "myname"
  zzcollab --config set dotfiles-dir "~/dotfiles"
  zzcollab --config set build-mode "standard"

  # Then just:
  zzcollab -p project1
  zzcollab -p project2
  zzcollab -p project3

═══════════════════════════════════════════════════════════════════════════
QUICK START: ESSENTIAL CONFIGURATION
═══════════════════════════════════════════════════════════════════════════

One-time setup (3 commands):

  zzcollab --config set team-name "yourname"
  zzcollab --config set build-mode "standard"
  zzcollab --config set dotfiles-dir "~/dotfiles"

That's it! Now all future projects use these defaults.

═══════════════════════════════════════════════════════════════════════════
CONFIGURATION COMMANDS
═══════════════════════════════════════════════════════════════════════════

Initialize configuration file:
  zzcollab --config init

Set a value:
  zzcollab --config set SETTING VALUE

Get a value:
  zzcollab --config get SETTING

List all settings:
  zzcollab --config list

Reset to defaults:
  zzcollab --config reset

Validate configuration:
  zzcollab --config validate

═══════════════════════════════════════════════════════════════════════════
ALL CONFIGURABLE SETTINGS
═══════════════════════════════════════════════════════════════════════════

Team/Project Settings:
  team-name          Your namespace for Docker images
  project-name       Default project name (rarely used)
  github-account     GitHub username (defaults to team-name)

Build Settings:
  build-mode         minimal, fast, standard, comprehensive
  
Dotfiles Settings:
  dotfiles-dir       Path to dotfiles directory (e.g., ~/dotfiles)
  dotfiles-nodot     Use if files don't have leading dots

Automation Settings:
  auto-github        Automatically create GitHub repos (true/false)
  skip-confirmation  Skip confirmation prompts (true/false)

═══════════════════════════════════════════════════════════════════════════
CONFIGURATION FILE LOCATIONS
═══════════════════════════════════════════════════════════════════════════

zzcollab uses a 4-level hierarchy (highest priority first):

1. PROJECT CONFIG (highest priority)
   Location: ./zzcollab.yaml (in project directory)
   Purpose: Team-specific settings
   Use for: Shared team configuration

2. USER CONFIG
   Location: ~/.zzcollab/config.yaml
   Purpose: Personal defaults across all projects
   Use for: Your name, dotfiles path, preferences

3. SYSTEM CONFIG
   Location: /etc/zzcollab/config.yaml  
   Purpose: Organization-wide defaults
   Use for: Lab/institution standards

4. BUILT-IN DEFAULTS (lowest priority)
   Location: Hardcoded in zzcollab
   Purpose: Sensible fallbacks

Example: If you set team-name in user config (~/.zzcollab/config.yaml),
it applies to all projects UNLESS a project has its own zzcollab.yaml.

═══════════════════════════════════════════════════════════════════════════
COMPLETE CONFIGURATION EXAMPLES
═══════════════════════════════════════════════════════════════════════════

Example 1: Solo Researcher (Minimal Setup)
──────────────────────────────────────────────────────────────────────────
zzcollab --config set team-name "jsmith"
zzcollab --config set build-mode "standard"

# Optional but recommended:
zzcollab --config set dotfiles-dir "~/dotfiles"

Example 2: Solo Researcher (Complete Setup)
──────────────────────────────────────────────────────────────────────────
zzcollab --config set team-name "jsmith"
zzcollab --config set github-account "jsmith"
zzcollab --config set build-mode "fast"
zzcollab --config set dotfiles-dir "~/dotfiles"
zzcollab --config set auto-github false

Example 3: Team Member
──────────────────────────────────────────────────────────────────────────
zzcollab --config set team-name "labteam"
zzcollab --config set github-account "jsmith"
zzcollab --config set build-mode "standard"
zzcollab --config set dotfiles-dir "~/dotfiles"

# Now joining team projects is simple:
zzcollab -t labteam -p study -I rstudio
# Uses your dotfiles automatically!

Example 4: Minimal Build for Speed
──────────────────────────────────────────────────────────────────────────
zzcollab --config set team-name "myname"
zzcollab --config set build-mode "minimal"

# Projects build in ~30 seconds
# Install additional packages as needed

═══════════════════════════════════════════════════════════════════════════
CONFIGURATION FILE FORMAT (YAML)
═══════════════════════════════════════════════════════════════════════════

Location: ~/.zzcollab/config.yaml

Example complete configuration:

defaults:
  team_name: "jsmith"
  github_account: "jsmith"
  build_mode: "standard"
  dotfiles_dir: "~/dotfiles"
  dotfiles_nodot: false
  auto_github: false
  skip_confirmation: false

# You can edit this file directly or use zzcollab --config commands

═══════════════════════════════════════════════════════════════════════════
COMMON CONFIGURATION WORKFLOWS
═══════════════════════════════════════════════════════════════════════════

Workflow 1: First-Time Setup
──────────────────────────────────────────────────────────────────────────
# Initialize config file
zzcollab --config init

# Set your essentials
zzcollab --config set team-name "yourname"
zzcollab --config set build-mode "standard"

# Verify
zzcollab --config list

# Create first project (uses config!)
zzcollab -p myproject

Workflow 2: Check Current Settings
──────────────────────────────────────────────────────────────────────────
# See all settings
zzcollab --config list

# Check specific setting
zzcollab --config get team-name
zzcollab --config get build-mode

Workflow 3: Change Build Mode
──────────────────────────────────────────────────────────────────────────
# Switch from standard to fast
zzcollab --config set build-mode "fast"

# Applies to all NEW projects
# Existing projects unaffected

Workflow 4: Reset Everything
──────────────────────────────────────────────────────────────────────────
# Start over with defaults
zzcollab --config reset

# Reconfigure
zzcollab --config set team-name "newname"

═══════════════════════════════════════════════════════════════════════════
COMMAND-LINE FLAGS VS CONFIGURATION
═══════════════════════════════════════════════════════════════════════════

Command-line flags OVERRIDE configuration:

Configuration says:
  team-name: "jsmith"
  build-mode: "standard"

Command:
  zzcollab -t different -p project -F

Result:
  Uses team="different" (flag overrides config)
  Uses build mode="fast" (-F overrides config)
  This project only! Config unchanged.

═══════════════════════════════════════════════════════════════════════════
CONFIGURATION BEST PRACTICES
═══════════════════════════════════════════════════════════════════════════

1. Set configuration ONCE at the beginning
   zzcollab --config set team-name "yourname"

2. Use consistent team-name across projects
   Don't: Different names per project
   Do: One name for all your projects

3. Set dotfiles-dir if you have dotfiles
   Saves typing -d ~/dotfiles every time

4. Choose build-mode based on your needs:
   • minimal - Ultra-fast, add packages later
   • fast - Quick development (recommended for learning)
   • standard - Most workflows (recommended for research)
   • comprehensive - Everything included

5. Don't set auto-github to true unless you want repos for EVERYTHING
   Better: Use -G flag when you want GitHub repo

6. Keep ~/.zzcollab/config.yaml backed up
   Simple: Store in dotfiles repo

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING CONFIGURATION
═══════════════════════════════════════════════════════════════════════════

Issue: "Configuration not being used"
──────────────────────────────────────────────────────────────────────────
Check:
  zzcollab --config list
  # Shows what's actually set

Verify file exists:
  cat ~/.zzcollab/config.yaml

Re-initialize if needed:
  zzcollab --config init

Issue: "Can't find config file"
──────────────────────────────────────────────────────────────────────────
Create it:
  zzcollab --config init

Check permissions:
  ls -la ~/.zzcollab/
  # Should be readable/writable by you

Issue: "Configuration seems corrupted"
──────────────────────────────────────────────────────────────────────────
Validate syntax:
  zzcollab --config validate

Reset and start over:
  zzcollab --config reset
  zzcollab --config set team-name "yourname"

Issue: "Settings not persisting"
──────────────────────────────────────────────────────────────────────────
Check file location:
  echo ~/.zzcollab/config.yaml
  # Should be in your home directory

Ensure yq is installed:
  which yq
  # Required for config management

Install if missing:
  brew install yq  # macOS
  snap install yq  # Linux

═══════════════════════════════════════════════════════════════════════════
ADVANCED: PROJECT-LEVEL CONFIGURATION
═══════════════════════════════════════════════════════════════════════════

Create project-specific config (for teams):

Location: myproject/zzcollab.yaml

Example team configuration:

team:
  name: "labteam"
  project: "study"
  description: "Cancer genomics analysis"

variants:
  minimal:
    enabled: true
  analysis:
    enabled: true
  bioinformatics:
    enabled: true

build:
  use_config_variants: true
  docker:
    platform: "auto"

This overrides user config for THIS PROJECT ONLY.

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE
═══════════════════════════════════════════════════════════════════════════

Essential commands:
  zzcollab --config init                      # Create config file
  zzcollab --config set team-name "name"      # Set your name
  zzcollab --config set build-mode "standard" # Set build mode
  zzcollab --config list                      # See all settings
  zzcollab --config get team-name             # Get one setting

Files:
  ~/.zzcollab/config.yaml    # Your personal config
  ./zzcollab.yaml            # Project-specific config

Hierarchy (high to low priority):
  1. Command-line flags
  2. Project config (./zzcollab.yaml)
  3. User config (~/.zzcollab/config.yaml)
  4. System config (/etc/zzcollab/config.yaml)
  5. Built-in defaults

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help              # General help
  zzcollab --help-quickstart   # Getting started
  zzcollab --help-variants     # Docker variants config
EOF
}


# Dotfiles Help
# Purpose: Comprehensive guide to dotfiles setup and management
show_dotfiles_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_dotfiles_help_content
    else
        show_dotfiles_help_content | "${PAGER:-less}" -R
    fi
}

show_dotfiles_help_content() {
    cat << 'EOF'
📁 DOTFILES SETUP GUIDE

═══════════════════════════════════════════════════════════════════════════
WHAT ARE DOTFILES?
═══════════════════════════════════════════════════════════════════════════

Dotfiles are configuration files that customize your development environment:
• .zshrc     - Zsh shell configuration (aliases, prompts, functions)
• .vimrc     - Vim editor settings
• .gitconfig - Git configuration (username, email, aliases)
• .Rprofile  - R startup configuration

Key Concept: zzcollab copies YOUR dotfiles into Docker containers so your
            development environment feels familiar and consistent.

═══════════════════════════════════════════════════════════════════════════
WHY USE DOTFILES WITH ZZCOLLAB?
═══════════════════════════════════════════════════════════════════════════

WITHOUT DOTFILES (generic environment):
  • Generic shell prompt
  • No custom aliases or functions
  • Default Vim configuration
  • Must reconfigure Git every time

WITH DOTFILES (personalized environment):
  • Your custom prompt with Git status
  • All your favorite aliases work
  • Your Vim settings preserved
  • Git configured automatically

Example: Your .zshrc might have:
  alias ll='ls -lah'
  alias gs='git status'
  alias gc='git commit'
  
These work in ALL your zzcollab containers automatically!

═══════════════════════════════════════════════════════════════════════════
THE TWO DOTFILES FLAGS
═══════════════════════════════════════════════════════════════════════════

-d, --dotfiles-dir PATH
  Copy dotfiles that ALREADY HAVE DOTS in their names

  Example directory structure:
    ~/dotfiles/
    ├── .zshrc        ← Has dot already
    ├── .vimrc        ← Has dot already
    └── .gitconfig    ← Has dot already

  Usage:
    zzcollab -d ~/dotfiles
    # Copies: .zshrc → /home/analyst/.zshrc
    #         .vimrc → /home/analyst/.vimrc

-D, --dotfiles-nodot PATH
  Copy dotfiles WITHOUT DOTS and ADD dots when copying

  Example directory structure:
    ~/dotfiles/
    ├── zshrc         ← No dot (version control friendly)
    ├── vimrc         ← No dot
    └── gitconfig     ← No dot

  Usage:
    zzcollab -D ~/dotfiles
    # Copies: zshrc → /home/analyst/.zshrc
    #         vimrc → /home/analyst/.vimrc

WHICH ONE SHOULD I USE?

Most people use -D (no-dot format) because:
  ✅ Files visible in file browsers (don't hide)
  ✅ Easier to version control on GitHub
  ✅ Less confusion with hidden files

But -d works great if you already have dotfiles with dots!

═══════════════════════════════════════════════════════════════════════════
COMMON DOTFILES TO INCLUDE
═══════════════════════════════════════════════════════════════════════════

Essential Dotfiles:

1. .zshrc (Zsh configuration)
   What to include:
   • Custom prompt
   • Useful aliases
   • Environment variables
   • Shell functions

   Example minimal .zshrc:
     # Custom prompt
     PROMPT='%F{blue}%~%f %# '
     
     # Useful aliases
     alias ll='ls -lah'
     alias ..='cd ..'
     alias gst='git status'
     alias gco='git checkout'
     
     # R-specific helpers
     alias R='R --no-save --no-restore'

2. .gitconfig (Git configuration)
   What to include:
   • Your name and email
   • Useful Git aliases
   • Default branch settings

   Example:
     [user]
         name = Your Name
         email = your.email@example.com
     [alias]
         st = status
         co = checkout
         ci = commit
         br = branch
     [init]
         defaultBranch = main

3. .vimrc (Vim configuration)
   What to include:
   • Syntax highlighting
   • Tab settings
   • Line numbers

   Example minimal .vimrc:
     syntax on
     set number
     set tabstop=4
     set shiftwidth=4
     set expandtab

4. .Rprofile (R configuration)
   What to include:
   • CRAN mirror
   • Library paths
   • Custom options

   Example:
     options(
       repos = c(CRAN = "https://cran.rstudio.com/"),
       stringsAsFactors = FALSE,
       max.print = 100
     )

Optional but Useful:

5. .tmux.conf (tmux terminal multiplexer)
6. .bashrc (if you use bash instead of zsh)
7. .inputrc (readline configuration)

═══════════════════════════════════════════════════════════════════════════
SETTING UP YOUR DOTFILES DIRECTORY
═══════════════════════════════════════════════════════════════════════════

First Time Setup:

Step 1: Create dotfiles directory
  mkdir ~/dotfiles
  cd ~/dotfiles

Step 2: Add your configuration files (no-dot format recommended)
  # Create basic zshrc
  cat > zshrc << 'EOZ'
  # Custom prompt
  PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '
  
  # Useful aliases
  alias ll='ls -lah'
  alias gst='git status'
  EOZ
  
  # Create basic gitconfig
  cat > gitconfig << 'EOG'
  [user]
      name = YOUR_NAME
      email = YOUR_EMAIL
  [alias]
      st = status
      co = checkout
  EOG

Step 3: Version control your dotfiles (optional but recommended)
  cd ~/dotfiles
  git init
  git add .
  git commit -m "Initial dotfiles"
  git remote add origin https://github.com/yourusername/dotfiles.git
  git push -u origin main

Step 4: Configure zzcollab to use them
  zzcollab --config set dotfiles-dir "~/dotfiles"
  zzcollab --config set dotfiles-nodot true

Step 5: Test with new project
  zzcollab -p test-project
  make docker-zsh
  # Check if your aliases and prompt work!

═══════════════════════════════════════════════════════════════════════════
CONFIGURATION FILE APPROACH
═══════════════════════════════════════════════════════════════════════════

Set Once, Use Forever:

# Set your dotfiles configuration
zzcollab --config set dotfiles-dir "~/dotfiles"
zzcollab --config set dotfiles-nodot true

# Now all future projects automatically use your dotfiles
zzcollab -p project1   # Uses ~/dotfiles automatically
zzcollab -p project2   # Uses ~/dotfiles automatically

Check Current Configuration:
  zzcollab --config get dotfiles-dir
  zzcollab --config get dotfiles-nodot

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

ISSUE 1: "My aliases don't work in the container!"

DIAGNOSIS:
  # Check if dotfiles were copied
  docker run --rm TEAM/PROJECTcore-shell:latest ls -la /home/analyst/
  # Look for .zshrc, .vimrc, etc.

COMMON CAUSES:
  ❌ Forgot -d or -D flag when building
  ❌ Wrong path to dotfiles directory
  ❌ Dotfiles directory empty

SOLUTION:
  # Rebuild with correct dotfiles flag
  zzcollab -t TEAM -p PROJECT -d ~/dotfiles

ISSUE 2: "Which flag do I use? -d or -D?"

EASY TEST:
  ls ~/dotfiles/
  
  If you see:  .zshrc  .vimrc  .gitconfig  → Use -d
  If you see:   zshrc   vimrc   gitconfig  → Use -D

ISSUE 3: "Dotfiles work in zsh but not in RStudio"

EXPLANATION:
  RStudio doesn't load .zshrc (it's not a shell)
  
SOLUTION:
  Put R-specific configuration in .Rprofile instead
  
  Example .Rprofile for RStudio:
    options(repos = c(CRAN = "https://cran.rstudio.com/"))
    setHook("rstudio.sessionInit", function(newSession) {
      if (newSession && is.null(rstudioapi::getActiveProject()))
        setwd("/home/analyst/project")
    }, action = "append")

ISSUE 4: "My dotfiles have sensitive information!"

BEST PRACTICE:
  1. Create separate dotfiles for zzcollab (no secrets)
     ~/dotfiles-zzcollab/
  
  2. Use environment variables instead of hardcoded values
     # In .zshrc
     export GITHUB_TOKEN="${GITHUB_TOKEN}"  # Read from environment
  
  3. Never commit API keys or passwords to version control
  
  4. Use .gitignore if you must have local-only secrets
     # In ~/dotfiles/.gitignore
     gitconfig-local
     secrets.env

ISSUE 5: "Dotfiles work locally but not for team members"

EXPLANATION:
  Dotfiles baked into team Docker images contain YOUR settings
  
SOLUTION:
  # Team lead: Use minimal/generic dotfiles for team images
  # Team members: Use their own dotfiles when joining
  
  Team lead builds images:
    zzcollab -i -t TEAM -p PROJECT -d ~/dotfiles-minimal
  
  Team member joins with their dotfiles:
    zzcollab -t TEAM -p PROJECT -I shell -d ~/my-dotfiles

ISSUE 6: "Changes to dotfiles don't appear in container"

CAUSE:
  Dotfiles copied during IMAGE BUILD, not container start
  
SOLUTION:
  Must rebuild Docker image to pick up dotfile changes:
    cd ~/projects/my-project
    zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles  # Rebuild

  Alternative: Mount dotfiles for testing (advanced)
    docker run -v ~/dotfiles/zshrc:/home/analyst/.zshrc ...

═══════════════════════════════════════════════════════════════════════════
ADVANCED: SHARING DOTFILES WITH YOUR TEAM
═══════════════════════════════════════════════════════════════════════════

Strategy: Version-Controlled Team Dotfiles

1. Create team dotfiles repository
   mkdir ~/team-dotfiles
   cd ~/team-dotfiles
   # Add standard configuration for your lab/team
   git init
   git remote add origin https://github.com/yourteam/dotfiles.git
   git push -u origin main

2. Team members clone the dotfiles
   git clone https://github.com/yourteam/dotfiles.git ~/team-dotfiles
   zzcollab --config set dotfiles-dir "~/team-dotfiles"

3. Everyone gets consistent environment
   # Same aliases, same prompt, same Git config!

4. Update team dotfiles as needed
   cd ~/team-dotfiles
   git pull  # Get latest team standards
   # Rebuild your images to pick up changes

═══════════════════════════════════════════════════════════════════════════
EXAMPLE: COMPREHENSIVE RESEARCH DOTFILES
═══════════════════════════════════════════════════════════════════════════

Here's a complete example for data science researchers:

~/dotfiles/zshrc:
  # Research-focused Zsh configuration
  
  # Custom prompt with Git branch
  autoload -Uz vcs_info
  precmd() { vcs_info }
  setopt prompt_subst
  PROMPT='%F{cyan}[%~]%f %F{yellow}${vcs_info_msg_0_}%f
  %# '
  
  # R and RStudio helpers
  alias R='R --no-save --no-restore'
  alias Rstudio='rstudio &'
  alias rcheck='R CMD check --as-cran'
  
  # Git shortcuts
  alias gst='git status'
  alias gco='git checkout'
  alias gaa='git add -A'
  alias gcm='git commit -m'
  alias gp='git push'
  
  # Project navigation
  alias proj='cd /home/analyst/project'
  alias data='cd /home/analyst/project/data'
  alias scripts='cd /home/analyst/project/scripts'
  
  # Docker helpers (for use on host)
  alias dps='docker ps'
  alias dlog='docker logs -f'

~/dotfiles/Rprofile:
  # R environment configuration for research
  
  # Set CRAN mirror
  options(repos = c(CRAN = "https://cran.rstudio.com/"))
  
  # Research-friendly defaults
  options(
    stringsAsFactors = FALSE,
    max.print = 100,
    scipen = 10,  # Prefer fixed over scientific notation
    warn = 1      # Show warnings as they occur
  )
  
  # Automatically load common packages (optional)
  if (interactive()) {
    suppressMessages({
      library(here)
      library(usethis)
    })
    message("✅ Loaded: here, usethis")
  }
  
  # Set working directory in RStudio
  setHook("rstudio.sessionInit", function(newSession) {
    if (newSession && is.null(rstudioapi::getActiveProject()))
      setwd("/home/analyst/project")
  }, action = "append")

~/dotfiles/gitconfig:
  [user]
      name = Your Name
      email = you@example.com
  
  [core]
      editor = vim
      autocrlf = input
  
  [alias]
      st = status
      co = checkout
      br = branch
      ci = commit
      unstage = reset HEAD --
      last = log -1 HEAD
      visual = log --graph --oneline --all
  
  [init]
      defaultBranch = main
  
  [pull]
      rebase = false

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help              # General help
  zzcollab --help-quickstart   # Getting started
  zzcollab --help-workflow     # Daily development workflow
  zzcollab --help-config       # Configuration system
EOF
}


# renv Help
# Purpose: Package management guide
show_renv_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_renv_help_content
    else
        show_renv_help_content | "${PAGER:-less}" -R
    fi
}

show_renv_help_content() {
    cat << 'EOF'
📦 PACKAGE MANAGEMENT WITH RENV

═══════════════════════════════════════════════════════════════════════════
WHAT IS RENV?
═══════════════════════════════════════════════════════════════════════════

renv is R's package management system that ensures reproducibility.

Key Concept: renv records exact package versions in renv.lock
             → Share renv.lock with collaborators
             → Everyone gets IDENTICAL packages
             → Analysis runs the same on all computers

Think of it like a "shopping list" for R packages:
  • renv.lock = exact list of packages and versions
  • renv::restore() = "go shopping" and install everything
  • renv::snapshot() = "update the list" with new packages

═══════════════════════════════════════════════════════════════════════════
WHY USE RENV?
═══════════════════════════════════════════════════════════════════════════

WITHOUT RENV (danger!):
  You: install.packages("tidyverse")  # Gets tidyverse 2.0.0
  Collaborator: install.packages("tidyverse")  # Gets tidyverse 2.1.0
  → Different results!
  → "Works on my machine" problem
  → Not reproducible

WITH RENV (safe):
  You: install.packages("tidyverse") + renv::snapshot()
  Collaborator: renv::restore()
  → Exact same tidyverse 2.0.0
  → Identical results
  → Perfect reproducibility!

═══════════════════════════════════════════════════════════════════════════
THE THREE ESSENTIAL RENV COMMANDS
═══════════════════════════════════════════════════════════════════════════

1. install.packages("packagename")
   Purpose: Install a new R package
   When: Whenever you need a new package
   
2. renv::snapshot()
   Purpose: Record current packages in renv.lock
   When: After installing new packages
   Result: Updates renv.lock file
   
3. renv::restore()
   Purpose: Install packages from renv.lock
   When: Joining project or syncing with team
   Result: Installs exact versions from renv.lock

That's it! These three commands handle 95% of package management.

═══════════════════════════════════════════════════════════════════════════
COMPLETE RENV WORKFLOW
═══════════════════════════════════════════════════════════════════════════

Scenario 1: Adding a New Package
──────────────────────────────────────────────────────────────────────────
# In RStudio (container):
install.packages("ggplot2")    # Install the package
library(ggplot2)               # Test that it works
renv::snapshot()               # Record in renv.lock

# On host:
git add renv.lock
git commit -m "Add ggplot2 package"
git push

Scenario 2: Joining a Team Project
──────────────────────────────────────────────────────────────────────────
# Clone project
git clone https://github.com/team/project.git
cd project

# Start container
zzcollab -t team -p project -I rstudio
make docker-rstudio

# In RStudio:
renv::restore()  # Install all packages from renv.lock
# Choose 1: Restore (most common choice)

Scenario 3: Updating Packages
──────────────────────────────────────────────────────────────────────────
# In RStudio:
install.packages("dplyr")  # Updates to latest version
renv::snapshot()           # Record new version

# Commit changes
git add renv.lock
git commit -m "Update dplyr to fix bug"

Scenario 4: Checking Package Status
──────────────────────────────────────────────────────────────────────────
# In RStudio:
renv::status()
# Shows:
# - Packages in code but not in renv.lock
# - Packages in renv.lock but not installed
# - Version mismatches

═══════════════════════════════════════════════════════════════════════════
RENV FILES EXPLAINED
═══════════════════════════════════════════════════════════════════════════

Your project has these renv-related files:

renv.lock (MOST IMPORTANT)
  What: JSON file listing exact package versions
  When to commit: Always! (crucial for reproducibility)
  Example contents:
    {
      "R": {"Version": "4.3.1"},
      "Packages": {
        "ggplot2": {
          "Package": "ggplot2",
          "Version": "3.4.2",
          "Source": "CRAN"
        }
      }
    }

renv/ directory
  What: Package cache and library
  When to commit: Never! (add to .gitignore)
  Purpose: Stores installed packages locally

.Rprofile
  What: Activates renv when R starts
  When to commit: Yes
  Content: source("renv/activate.R")

═══════════════════════════════════════════════════════════════════════════
COMMON RENV WORKFLOWS
═══════════════════════════════════════════════════════════════════════════

Daily Development Workflow:
──────────────────────────────────────────────────────────────────────────
1. Start RStudio: make docker-rstudio
2. Write code using existing packages
3. Need new package?
   install.packages("packagename")
   renv::snapshot()
4. Close RStudio: Ctrl+C
5. Commit: git add renv.lock && git commit -m "Add package"

Collaboration Workflow (Team Member):
──────────────────────────────────────────────────────────────────────────
1. Pull latest code: git pull
2. Check for package changes: git diff renv.lock
3. If renv.lock changed:
   make docker-rstudio
   renv::restore()  # Sync packages with team
4. Continue work with synced packages

Package Exploration Workflow:
──────────────────────────────────────────────────────────────────────────
# Try a package without committing:
install.packages("experimentalPkg")
library(experimentalPkg)
# Try it out...

# Don't like it? Don't snapshot!
# Just restart R - package won't be in renv.lock

# Like it? Snapshot to keep:
renv::snapshot()

═══════════════════════════════════════════════════════════════════════════
RENV TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

ISSUE 1: "Package 'X' is not available"
──────────────────────────────────────────────────────────────────────────
CAUSE: Package not on CRAN or name misspelled

SOLUTIONS:
  Check spelling: install.packages("ggplot2") not "ggplt2"
  
  Package on GitHub:
    remotes::install_github("username/packagename")
    renv::snapshot()
  
  Package on Bioconductor:
    BiocManager::install("packagename")
    renv::snapshot()

ISSUE 2: "Package installation failed (non-zero exit)"
──────────────────────────────────────────────────────────────────────────
CAUSE: Missing system dependencies

SOLUTION:
  # Package needs system libraries (e.g., sf needs gdal)
  # Options:
  # 1. Use different build mode (comprehensive includes more)
  # 2. Ask team lead to add to Docker image
  # 3. Use alternative package

ISSUE 3: "renv.lock is out of sync"
──────────────────────────────────────────────────────────────────────────
Check status:
  renv::status()
  # Shows what's different

Fix by syncing:
  renv::snapshot()  # If you want to keep current packages
  # OR
  renv::restore()   # If you want renv.lock versions

ISSUE 4: "Package works for me but not teammate"
──────────────────────────────────────────────────────────────────────────
CAUSE: Forgot to snapshot after installing

SOLUTION:
  You (who installed package):
    renv::snapshot()
    git add renv.lock
    git commit -m "Add missing package"
    git push
  
  Teammate:
    git pull
    renv::restore()

ISSUE 5: "renv::restore() taking forever"
──────────────────────────────────────────────────────────────────────────
CAUSE: Installing many packages from source

SOLUTION:
  # Just wait - first time is slow
  # Subsequent restores are faster (uses cache)
  
  # Progress indicator:
  renv::restore()
  # Shows: Installing package [1/50] ...

ISSUE 6: "Error: renv not installed"
──────────────────────────────────────────────────────────────────────────
RARE - renv included in zzcollab by default

SOLUTION:
  install.packages("renv")
  renv::init()

ISSUE 7: "Cache is corrupted"
──────────────────────────────────────────────────────────────────────────
Purge and reinstall:
  renv::purge("packagename")
  install.packages("packagename")
  renv::snapshot()

═══════════════════════════════════════════════════════════════════════════
ADVANCED RENV COMMANDS
═══════════════════════════════════════════════════════════════════════════

Check what's changed:
  renv::status()
  # Shows packages in code but not in renv.lock
  # Shows packages in renv.lock but not installed

Install specific version:
  remotes::install_version("ggplot2", version = "3.3.6")
  renv::snapshot()

Remove package:
  remove.packages("packagename")
  renv::snapshot()  # Update renv.lock

Update all packages:
  renv::update()
  # Updates all packages to latest versions
  # Use carefully! May break code.

Rollback to previous state:
  git checkout HEAD~1 renv.lock  # Previous version
  renv::restore()                # Install old versions

Clean unused packages:
  renv::clean()
  # Removes packages not in renv.lock

═══════════════════════════════════════════════════════════════════════════
UNDERSTANDING RENV.LOCK
═══════════════════════════════════════════════════════════════════════════

Example renv.lock content:

{
  "R": {
    "Version": "4.3.1",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cran.rstudio.com"
      }
    ]
  },
  "Packages": {
    "ggplot2": {
      "Package": "ggplot2",
      "Version": "3.4.2",
      "Source": "Repository",
      "Repository": "CRAN",
      "Hash": "abc123def456"
    },
    "dplyr": {
      "Package": "dplyr",
      "Version": "1.1.2",
      "Source": "Repository", 
      "Repository": "CRAN",
      "Hash": "xyz789"
    }
  }
}

Key fields:
  • R Version: Which R version was used
  • Package: Package name
  • Version: Exact version number
  • Source: Where package came from (CRAN, GitHub, etc.)
  • Hash: Checksum to verify package contents

═══════════════════════════════════════════════════════════════════════════
RENV BEST PRACTICES
═══════════════════════════════════════════════════════════════════════════

1. Always snapshot after installing packages
   install.packages("packagename")
   renv::snapshot()  # Don't forget!

2. Commit renv.lock to git (crucial!)
   git add renv.lock
   git commit -m "Add/update packages"

3. Run renv::status() regularly
   # Catches packages you forgot to snapshot

4. Restore after pulling team changes
   git pull
   # If renv.lock changed:
   renv::restore()

5. Don't commit renv/ directory
   # Already in .gitignore, keep it that way!

6. Use renv::snapshot() strategically
   # After adding package
   # After updating package
   # Before sharing with team
   # Before submitting final analysis

7. Test with renv::restore() occasionally
   # Ensures renv.lock is complete
   # Verifies reproducibility

8. Document package purposes
   # In code comments, explain why you need each package

═══════════════════════════════════════════════════════════════════════════
RENV + ZZCOLLAB INTEGRATION
═══════════════════════════════════════════════════════════════════════════

zzcollab build modes control initial packages:

MINIMAL mode (3 packages):
  • renv, here, usethis
  • Add all analysis packages via install.packages()

FAST mode (9 packages):
  • renv, here, usethis, devtools, testthat
  • knitr, rmarkdown, targets, palmerpenguins
  • Add additional packages as needed

STANDARD mode (17 packages):
  • Fast packages + tidyverse core
  • Most workflows covered
  • Occasionally add specialized packages

COMPREHENSIVE mode (47+ packages):
  • Includes most common packages
  • Rarely need to add more

Key insight: Build mode affects Docker image
           → renv.lock records project-specific additions
           → renv.lock + Docker image = perfect reproducibility!

═══════════════════════════════════════════════════════════════════════════
COMMON QUESTIONS
═══════════════════════════════════════════════════════════════════════════

Q: "When should I run renv::snapshot()?"
A: After install.packages(), before committing to git.

Q: "When should I run renv::restore()?"
A: After git pull if renv.lock changed, or when joining project.

Q: "Do I need to install renv?"
A: No, included in all zzcollab Docker images.

Q: "Can I use install.packages() without renv::snapshot()?"
A: Yes, but package won't be recorded - lost when container restarts!

Q: "What if I accidentally installed wrong package?"
A: Don't snapshot! Restart R and package is forgotten.

Q: "Should I commit renv/ directory?"
A: NO! Only commit renv.lock (.gitignore handles this).

Q: "Can I manually edit renv.lock?"
A: Don't! Use renv::snapshot() and renv::restore() instead.

Q: "What if renv.lock conflicts in git merge?"
A: Resolve conflict, then run renv::restore() to sync.

Q: "How do I share experimental package without affecting team?"
A: Use feature branch, install+snapshot there, merge when stable.

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE
═══════════════════════════════════════════════════════════════════════════

Essential commands:
  install.packages("pkg")  # Install package
  renv::snapshot()         # Record in renv.lock
  renv::restore()          # Install from renv.lock
  renv::status()           # Check sync status

Files:
  renv.lock               # Package versions (COMMIT THIS!)
  renv/                   # Package cache (DON'T COMMIT)
  .Rprofile               # Activates renv (COMMIT THIS)

Workflow:
  1. install.packages("packagename")
  2. Test that it works
  3. renv::snapshot()
  4. git add renv.lock
  5. git commit -m "Add package"
  6. git push

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help              # General help
  zzcollab --help-workflow     # Daily development workflow
  zzcollab --help-troubleshooting  # Fix common problems
EOF
}


# Build Modes Help  
# Purpose: Build mode selection guide
show_build_modes_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_build_modes_help_content
    else
        show_build_modes_help_content | "${PAGER:-less}" -R
    fi
}

show_build_modes_help_content() {
    cat << 'EOF'
🔧 BUILD MODES GUIDE

═══════════════════════════════════════════════════════════════════════════
WHAT ARE BUILD MODES?
═══════════════════════════════════════════════════════════════════════════

Build modes control which R packages are included in your Docker environment.

Think of it like choosing a computer:
  • MINIMAL = Laptop (lightweight, add software as needed)
  • FAST = Desktop (balanced, common software included)
  • STANDARD = Workstation (comprehensive, ready for most tasks)
  • COMPREHENSIVE = Server (everything included, powerful)

Key Tradeoff: Build time vs included packages
  • Fewer packages = faster builds, install more later
  • More packages = slower builds, everything ready

═══════════════════════════════════════════════════════════════════════════
THE FOUR BUILD MODES
═══════════════════════════════════════════════════════════════════════════

1. MINIMAL MODE (--minimal or -M)
──────────────────────────────────────────────────────────────────────────
Build time: ~30 seconds
Packages: 3 essential packages
Philosophy: Start minimal, add exactly what you need

Included packages:
  • renv - Package management
  • here - Path management  
  • usethis - Development tools

Best for:
  ✅ Learning zzcollab (fastest way to get started)
  ✅ CI/CD environments (speed critical)
  ✅ Exploring R (add packages as you discover needs)
  ✅ Resource-constrained systems

Usage:
  zzcollab -p myproject --minimal
  # Or set as default:
  zzcollab --config set build-mode "minimal"

2. FAST MODE (--fast or -F)
──────────────────────────────────────────────────────────────────────────
Build time: 2-3 minutes
Packages: 9 development packages
Philosophy: Quick start with essential development tools

Included packages:
  Minimal packages (3) PLUS:
  • devtools - Package development
  • testthat - Testing framework
  • knitr - Report generation
  • rmarkdown - Document creation
  • targets - Pipeline management
  • palmerpenguins - Example data

Best for:
  ✅ Quick prototyping
  ✅ Package development
  ✅ Testing and validation
  ✅ Teaching/learning R workflows

Usage:
  zzcollab -p myproject -F
  # Or set as default:
  zzcollab --config set build-mode "fast"

3. STANDARD MODE (--standard or -S) [DEFAULT]
──────────────────────────────────────────────────────────────────────────
Build time: 4-6 minutes
Packages: 17 analysis packages
Philosophy: Balanced - covers most research workflows

Included packages:
  Fast packages (9) PLUS tidyverse core:
  • dplyr - Data manipulation
  • ggplot2 - Data visualization
  • tidyr - Data tidying
  • broom - Model tidying
  • janitor - Data cleaning
  • DT - Interactive tables
  • conflicted - Package conflict management
  • palmerpenguins - Example datasets

Best for:
  ✅ Data analysis (most common use case)
  ✅ Statistical modeling
  ✅ Report generation
  ✅ Research projects
  ✅ Team collaboration (balanced default)

Usage:
  zzcollab -p myproject -S
  # Or use default (no flag needed):
  zzcollab -p myproject

4. COMPREHENSIVE MODE (--comprehensive or -C)
──────────────────────────────────────────────────────────────────────────
Build time: 15-20 minutes
Packages: 47+ analysis packages
Philosophy: Everything included, rarely need to add more

Included packages:
  Standard packages (17) PLUS advanced tools:
  • tidymodels - Machine learning framework
  • shiny - Interactive web apps
  • plotly - Interactive visualizations
  • quarto - Publishing system
  • flexdashboard - Dashboard creation
  • survival - Survival analysis
  • lme4 - Mixed models
  • RSQLite, DBI - Database connections
  • furrr, future - Parallel processing
  • Many more specialized packages

Best for:
  ✅ Advanced analysis environments
  ✅ Machine learning projects
  ✅ Interactive dashboards
  ✅ Publishing workflows
  ✅ Reusable team base images (build once, use everywhere)

Usage:
  zzcollab -p myproject -C
  # Or set as default:
  zzcollab --config set build-mode "comprehensive"

═══════════════════════════════════════════════════════════════════════════
BUILD MODE COMPARISON TABLE
═══════════════════════════════════════════════════════════════════════════

Mode          | Packages | Build Time | Best For
──────────────┼──────────┼────────────┼─────────────────────────────────
MINIMAL (-M)  |    3     |  ~30 sec   | Learning, CI/CD, exploration
FAST (-F)     |    9     |  2-3 min   | Development, testing, teaching
STANDARD (-S) |   17     |  4-6 min   | Data analysis, research (DEFAULT)
COMPREHENSIVE |   47+    | 15-20 min  | Advanced, ML, dashboards, reusable

═══════════════════════════════════════════════════════════════════════════
CHOOSING THE RIGHT BUILD MODE
═══════════════════════════════════════════════════════════════════════════

Decision Tree:

Q1: Do you know exactly what packages you need?
├─ YES → Use MINIMAL, install specific packages later
└─ NO → Continue to Q2

Q2: Are you doing data analysis with tidyverse?
├─ YES → Use STANDARD (recommended for most research)
└─ NO → Continue to Q3

Q3: Do you need machine learning or advanced tools?
├─ YES → Use COMPREHENSIVE
└─ NO → Use FAST (development tools only)

Common Scenarios:

"I'm learning R and zzcollab"
  → MINIMAL
  Install packages as tutorials require them

"I'm analyzing customer data"
  → STANDARD
  Includes tidyverse for data wrangling + visualization

"I'm developing an R package"
  → FAST
  Includes devtools, testthat, but not analysis packages

"I'm building a machine learning model"
  → COMPREHENSIVE
  Includes tidymodels, xgboost, random forests

"I'm creating a Shiny dashboard"
  → COMPREHENSIVE
  Includes shiny, plotly, flexdashboard

"I need speed - building frequently"
  → MINIMAL or FAST
  Faster iteration during development

"I'm creating a team base image"
  → COMPREHENSIVE
  Team members reuse image, build time doesn't matter

═══════════════════════════════════════════════════════════════════════════
PACKAGE LISTS BY MODE
═══════════════════════════════════════════════════════════════════════════

MINIMAL (3 packages):
  renv, here, usethis

FAST (9 packages) = MINIMAL +
  devtools, testthat, knitr, rmarkdown, targets, palmerpenguins

STANDARD (17 packages) = FAST +
  dplyr, ggplot2, tidyr, broom, janitor, DT, conflicted, 
  palmerpenguins

COMPREHENSIVE (47+ packages) = STANDARD +
  tidymodels, parsnip, recipes, workflows, tune, yardstick,
  shiny, shinydashboard, plotly, DT,
  quarto, bookdown, blogdown, flexdashboard,
  survival, lme4, nlme,
  RSQLite, DBI, dbplyr,
  furrr, future, parallel,
  httr, jsonlite, xml2,
  lubridate, stringr, forcats,
  and more...

═══════════════════════════════════════════════════════════════════════════
USAGE EXAMPLES
═══════════════════════════════════════════════════════════════════════════

Set Default Build Mode (recommended):
──────────────────────────────────────────────────────────────────────────
# Set once, applies to all future projects
zzcollab --config set build-mode "standard"

# Now all projects use standard mode automatically:
zzcollab -p project1  # Uses standard
zzcollab -p project2  # Uses standard

Override Default for Specific Project:
──────────────────────────────────────────────────────────────────────────
# Default is standard, but use fast for this project:
zzcollab -p test-project -F

Solo Researcher Quick Start:
──────────────────────────────────────────────────────────────────────────
# Recommended setup for individual researchers:
zzcollab --config set team-name "myname"
zzcollab --config set build-mode "standard"
zzcollab --config set dotfiles-dir "~/dotfiles"

# Create project (uses config defaults):
zzcollab -p analysis

Team Collaboration:
──────────────────────────────────────────────────────────────────────────
# Team lead: Build comprehensive base image once
zzcollab -i -t mylab -p baseimage -C -B rstudio

# Team members: Reuse comprehensive image
zzcollab -t mylab -p study -I rstudio
# Inherits all 47+ packages from baseimage

═══════════════════════════════════════════════════════════════════════════
CHANGING BUILD MODES
═══════════════════════════════════════════════════════════════════════════

Changing Default for Future Projects:
──────────────────────────────────────────────────────────────────────────
# Currently using fast, want standard for new projects:
zzcollab --config set build-mode "standard"

# All NEW projects will use standard
# Existing projects unchanged

Upgrading Existing Project:
──────────────────────────────────────────────────────────────────────────
# Project created with minimal, want comprehensive:
cd myproject
zzcollab -p myproject -C  # Rebuild with comprehensive mode

# Docker image rebuilt with new packages
# Project files unchanged

Adding Individual Packages (preferred approach):
──────────────────────────────────────────────────────────────────────────
# Don't rebuild entire image, just add what you need:
make docker-rstudio
# In RStudio:
install.packages("tidymodels")
renv::snapshot()
# Commit renv.lock

# This is faster than rebuilding with comprehensive mode!

═══════════════════════════════════════════════════════════════════════════
BUILD TIME OPTIMIZATION
═══════════════════════════════════════════════════════════════════════════

Strategy 1: Start Minimal, Add Incrementally
──────────────────────────────────────────────────────────────────────────
# Use minimal mode, install packages as needed:
zzcollab -p project -M        # ~30 seconds
make docker-rstudio
# In RStudio:
install.packages("tidyverse")  # ~2-3 minutes
install.packages("tidymodels") # ~5-7 minutes
renv::snapshot()

Total time: ~8-11 minutes for custom package set
Advantage: Only install what you actually use

Strategy 2: Reusable Team Base Image
──────────────────────────────────────────────────────────────────────────
# Build comprehensive image once (15-20 minutes)
zzcollab -i -t myname -p base -C -B rstudio

# All projects reuse base (~30 seconds each)
mkdir project1 && cd project1
zzcollab -t myname -p project1 -I rstudio  # Fast!

mkdir ../project2 && cd ../project2  
zzcollab -t myname -p project2 -I rstudio  # Fast!

Total time for 3 projects: ~16 minutes
Traditional approach: 45-60 minutes (3 × 15-20 min)
Time saved: 73%!

Strategy 3: Use Configuration
──────────────────────────────────────────────────────────────────────────
# Set preferred mode once:
zzcollab --config set build-mode "fast"

# No need to remember flag for each project:
zzcollab -p project1  # Uses fast automatically
zzcollab -p project2  # Uses fast automatically

═══════════════════════════════════════════════════════════════════════════
COMMON QUESTIONS
═══════════════════════════════════════════════════════════════════════════

Q: "Which mode should I use?"
A: STANDARD for most research. MINIMAL for learning/speed.

Q: "Can I change modes later?"
A: Yes, rebuild project with different mode. Or just install packages.

Q: "Does build mode affect my data or code?"
A: No, only affects which packages are pre-installed in Docker.

Q: "What if I need a package not in comprehensive mode?"
A: Just install it: install.packages("packagename") + renv::snapshot()

Q: "Can different team members use different modes?"
A: Yes, but coordinate on team base image mode for consistency.

Q: "Does mode affect reproducibility?"
A: No! renv.lock ensures reproducibility regardless of build mode.

Q: "Should I use comprehensive for everything?"
A: No - slower builds. Use minimal/fast for quick projects.

Q: "Can I customize package lists?"
A: Yes, via config.yaml. See: zzcollab --help-config

Q: "What about system dependencies (non-R packages)?"
A: Build modes include necessary system libraries for included packages.

Q: "Does mode affect Docker image size?"
A: Yes. Minimal ~800MB, Fast ~1.2GB, Standard ~1.5GB, Comprehensive ~3GB.

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

Issue: "Build is too slow"
──────────────────────────────────────────────────────────────────────────
Solution: Use faster mode or reusable base image strategy
  zzcollab --config set build-mode "minimal"
  # Or see: zzcollab --help-quickstart (reusable image section)

Issue: "Missing packages I need"
──────────────────────────────────────────────────────────────────────────
Solution: Install them individually (faster than rebuilding):
  make docker-rstudio
  install.packages("packagename")
  renv::snapshot()

Issue: "Not sure which mode I'm using"
──────────────────────────────────────────────────────────────────────────
Check configuration:
  zzcollab --config get build-mode

Check project DESCRIPTION file:
  grep "BuildMode" DESCRIPTION

Issue: "Want different mode for one project"
──────────────────────────────────────────────────────────────────────────
Override default with flag:
  zzcollab -p special-project -C  # Use comprehensive this once

Issue: "Team members have different package sets"
──────────────────────────────────────────────────────────────────────────
Coordinate on build mode:
  Team lead: zzcollab -i -t team -p project -S
  Members: zzcollab -t team -p project -I rstudio
  Everyone: renv::restore() to sync additional packages

═══════════════════════════════════════════════════════════════════════════
ADVANCED: CUSTOM BUILD MODES
═══════════════════════════════════════════════════════════════════════════

Create custom package sets in config.yaml:

build_modes:
  bioinformatics:
    description: "Custom bioinformatics workflow"
    docker_packages: [renv, BiocManager, devtools]
    renv_packages: [renv, BiocManager, DESeq2, edgeR, limma]
  
  geospatial:
    description: "Custom GIS workflow"
    docker_packages: [renv, sf, terra, leaflet]
    renv_packages: [renv, sf, terra, leaflet, tmap, rgdal]

Usage:
  zzcollab -p geo-analysis --build-mode geospatial

See: zzcollab --help-config for complete customization guide

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE
═══════════════════════════════════════════════════════════════════════════

Flags:
  -M, --minimal         3 packages, ~30 sec
  -F, --fast            9 packages, 2-3 min
  -S, --standard       17 packages, 4-6 min (DEFAULT)
  -C, --comprehensive  47+ packages, 15-20 min

Configuration:
  zzcollab --config set build-mode "MODE"
  zzcollab --config get build-mode

Override default:
  zzcollab -p project -F  # Use fast this time only

Check current mode:
  grep "BuildMode" DESCRIPTION

Recommendations:
  • Learning → MINIMAL
  • Development → FAST
  • Research/Analysis → STANDARD
  • Machine Learning → COMPREHENSIVE
  • Team base image → COMPREHENSIVE

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help              # General help
  zzcollab --help-config       # Configuration system
  zzcollab --help-quickstart   # Reusable base image strategy
  zzcollab --help-renv         # Package management
EOF
}


# Docker Help
# Purpose: Docker essentials for non-technical users
show_docker_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_docker_help_content
    else
        show_docker_help_content | "${PAGER:-less}" -R
    fi
}

show_docker_help_content() {
    cat << 'EOF'
🐳 DOCKER ESSENTIALS

═══════════════════════════════════════════════════════════════════════════
WHAT IS DOCKER? (FOR NON-TECHNICAL USERS)
═══════════════════════════════════════════════════════════════════════════

Docker creates "containers" - isolated environments that run on your computer.

Think of it like this:
  • Your computer = apartment building
  • Container = individual apartment
  • Each apartment has its own furniture (software, packages)
  • Apartments don't interfere with each other
  • You can have many apartments in one building

Why this matters for research:
  ✅ Reproducibility - Same environment on every computer
  ✅ Isolation - Projects don't conflict with each other
  ✅ Shareability - Team gets identical environments
  ✅ Cleanliness - Delete project, container gone (no leftover junk)

═══════════════════════════════════════════════════════════════════════════
KEY DOCKER CONCEPTS (SIMPLIFIED)
═══════════════════════════════════════════════════════════════════════════

1. DOCKER IMAGE (the blueprint)
──────────────────────────────────────────────────────────────────────────
What: Recipe for creating a container
Like: Blueprint for an apartment
Contains: Operating system, R, packages, your dotfiles
Created once: When you run zzcollab command
Stored on: Your computer (or Docker Hub for teams)

Example:
  myteam/projectcore-rstudio:latest
  └─ Team name: myteam
  └─ Project: projectcore
  └─ Variant: rstudio
  └─ Version: latest

2. DOCKER CONTAINER (the running instance)
──────────────────────────────────────────────────────────────────────────
What: Running environment from an image
Like: Actual apartment built from blueprint
Contains: Your active R session, running code
Created: Each time you run "make docker-rstudio"
Destroyed: When you press Ctrl+C
Your files: SAVED if in /home/analyst/project (mounted!)

Key insight: Container is temporary, files in mounted directory persist!

3. DOCKER VOLUME (file sharing)
──────────────────────────────────────────────────────────────────────────
What: Bridge between container and your computer
Like: Window between apartments
Allows: Files sync automatically both ways
Used for: Your project directory

Example:
  ~/projects/myproject ←→ /home/analyst/project
  (Your computer)         (Inside container)

Changes in either location appear in both!

4. DOCKERFILE (build instructions)
──────────────────────────────────────────────────────────────────────────
What: Text file with instructions to build image
Like: Recipe for setting up an apartment
Contains: Install R, add packages, copy dotfiles
You rarely edit: zzcollab generates this for you

═══════════════════════════════════════════════════════════════════════════
THE DOCKER WORKFLOW (WHAT ACTUALLY HAPPENS)
═══════════════════════════════════════════════════════════════════════════

Step 1: Build Image (happens once)
──────────────────────────────────────────────────────────────────────────
You run: zzcollab -p myproject
Behind scenes:
  1. Generate Dockerfile
  2. Download base R image
  3. Install packages
  4. Copy dotfiles
  5. Create image: myname/myprojectcore-rstudio:latest

This takes time (~5-10 minutes), but only happens once!

Step 2: Start Container (daily workflow)
──────────────────────────────────────────────────────────────────────────
You run: make docker-rstudio
Behind scenes:
  1. Create container from image
  2. Mount your project directory  
  3. Start RStudio Server
  4. Open browser to localhost:8787

This is fast (~5 seconds)!

Step 3: Work in Container
──────────────────────────────────────────────────────────────────────────
You: Use RStudio normally
Behind scenes:
  • R running inside container
  • Files saved to /home/analyst/project
  • Automatically synced to your computer
  • Everything works like normal RStudio!

Step 4: Stop Container
──────────────────────────────────────────────────────────────────────────
You: Close browser, press Ctrl+C in terminal
Behind scenes:
  • Container stops
  • Container deleted
  • Files preserved (in mounted directory)
  • Image remains for next time

Step 5: Resume Next Day
──────────────────────────────────────────────────────────────────────────
You: make docker-rstudio
Behind scenes:
  • New container created from same image
  • Same packages, same environment
  • Files exactly where you left them!

═══════════════════════════════════════════════════════════════════════════
DOCKER COMMANDS YOU'LL USE
═══════════════════════════════════════════════════════════════════════════

Don't worry - zzcollab handles most Docker commands for you!
You mainly use make targets.

Common Daily Commands:
──────────────────────────────────────────────────────────────────────────
make docker-rstudio    # Start RStudio container
make docker-zsh        # Start command-line container
Ctrl+C                 # Stop container (in terminal)

Diagnostic Commands:
──────────────────────────────────────────────────────────────────────────
docker ps              # Show running containers
docker images          # Show available images
docker --version       # Check Docker installed

Troubleshooting Commands:
──────────────────────────────────────────────────────────────────────────
docker stop <id>       # Stop specific container
docker rm <id>         # Remove stopped container
docker logs <id>       # See container error messages
docker system prune    # Clean up unused images/containers

═══════════════════════════════════════════════════════════════════════════
UNDERSTANDING "DOCKER PS"
═══════════════════════════════════════════════════════════════════════════

When you run: docker ps

Output example:
CONTAINER ID   IMAGE                              PORTS                    NAMES
abc123def456   myteam/projcore-rstudio:latest    0.0.0.0:8787->8787/tcp   proj-rstudio

What this means:
  • CONTAINER ID: abc123def456 (unique identifier)
  • IMAGE: Which blueprint was used
  • PORTS: 0.0.0.0:8787->8787/tcp (localhost:8787 access)
  • NAMES: proj-rstudio (friendly name)

If output is empty: No containers running!

═══════════════════════════════════════════════════════════════════════════
FILE PERSISTENCE - CRITICAL CONCEPT
═══════════════════════════════════════════════════════════════════════════

✅ FILES THAT PERSIST (saved forever):
──────────────────────────────────────────────────────────────────────────
Location: /home/analyst/project (inside container)
Maps to: ~/projects/myproject (on your computer)

Examples:
  • analysis/scripts/analysis.R
  • analysis/data/raw_data/data.csv
  • analysis/figures/plot.png
  • renv.lock
  • .git/ directory

Why: This directory is "mounted" (connected to host)

❌ FILES THAT DON'T PERSIST (lost when container stops):
──────────────────────────────────────────────────────────────────────────
Location: Anywhere else in container
Examples:
  • /home/analyst/test.R (not in /project!)
  • /tmp/temporary.csv
  • System files

Why: These are inside container only, not mounted

💡 GOLDEN RULE: Always work in /home/analyst/project!
   RStudio starts there automatically - you're safe by default!

═══════════════════════════════════════════════════════════════════════════
DOCKER LIFECYCLE SCENARIOS
═══════════════════════════════════════════════════════════════════════════

Scenario 1: Normal Daily Workflow
──────────────────────────────────────────────────────────────────────────
Day 1:
  make docker-rstudio
  # Create analysis.R, save
  Ctrl+C

Day 2:
  make docker-rstudio
  # analysis.R still there!
  # Continue working

Why: Files in /project mounted to host, persist between containers

Scenario 2: Accidental Terminal Close
──────────────────────────────────────────────────────────────────────────
  make docker-rstudio
  # Terminal crashes or closes accidentally
  # Oh no!
  
  # Solution:
  Open new terminal
  cd myproject
  make docker-rstudio
  # Everything restored!

Why: Files on host, container can be recreated

Scenario 3: Computer Restart
──────────────────────────────────────────────────────────────────────────
  # Computer crashes/restarts
  # Containers stopped
  
  # After restart:
  cd myproject
  make docker-rstudio
  # Back to work!

Why: Images persist, containers recreated fresh

Scenario 4: Deleting Container by Mistake
──────────────────────────────────────────────────────────────────────────
  docker rm <container-id>
  # Oops, deleted container!
  
  # No problem:
  make docker-rstudio
  # New container, same files!

Why: Container temporary, files and image safe

Scenario 5: Deleting Image (more serious!)
──────────────────────────────────────────────────────────────────────────
  docker rmi myteam/projcore-rstudio:latest
  # Deleted image!
  
  # Solution: Rebuild
  zzcollab -p myproject
  # Rebuilds image (takes time)
  # Files still safe

Why: Image can be rebuilt from Dockerfile + project files

═══════════════════════════════════════════════════════════════════════════
DOCKER RESOURCE USAGE
═══════════════════════════════════════════════════════════════════════════

Docker uses computer resources:
  • Disk space: Images can be large (1-3 GB each)
  • Memory: Running containers use RAM
  • CPU: Analysis uses processing power

Managing Resources:
──────────────────────────────────────────────────────────────────────────
Check disk usage:
  docker system df
  # Shows images, containers, volumes size

Clean up unused resources:
  docker system prune
  # Removes stopped containers, unused images
  # Frees disk space

Adjust Docker Desktop resources:
  macOS/Windows: Docker Desktop → Settings → Resources
  • Increase memory (8GB recommended)
  • Increase CPU cores (4+ recommended)

═══════════════════════════════════════════════════════════════════════════
COMMON DOCKER QUESTIONS
═══════════════════════════════════════════════════════════════════════════

Q: "Do I need to learn Docker to use zzcollab?"
A: No! zzcollab handles Docker for you. Just use make commands.

Q: "What if I close the terminal running the container?"
A: Container stops. Restart with make docker-rstudio. Files safe!

Q: "Can I run multiple containers at once?"
A: Yes, but they need different ports. Usually better to work on one project at a time.

Q: "How do I update packages in a container?"
A: Install packages normally in R, then renv::snapshot()

Q: "What happens to packages when container stops?"
A: Packages in image persist. Packages installed via install.packages() lost unless snapshot!

Q: "Can I access files from outside the container?"
A: Yes! Files in ~/projects/myproject visible on your computer and in container.

Q: "What if I accidentally save file outside /project?"
A: File lost when container stops. Always use /home/analyst/project!

Q: "How do I know if container is running?"
A: Terminal shows logs (not prompt). Or: docker ps

Q: "Can I use RStudio Desktop instead of container?"
A: You can, but defeats reproducibility purpose. Container ensures same environment.

Q: "Is my data safe in containers?"
A: Yes, if in mounted /project directory. Backed up like any other file.

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING DOCKER ISSUES
═══════════════════════════════════════════════════════════════════════════

Issue: "Docker daemon not running"
──────────────────────────────────────────────────────────────────────────
Solution:
  macOS: Open Docker Desktop application
  Windows: Start Docker Desktop
  Linux: sudo systemctl start docker

Verify: docker ps (should work without error)

Issue: "Port 8787 already in use"
──────────────────────────────────────────────────────────────────────────
Cause: Another RStudio container running

Solutions:
  1. Find and stop it:
     docker ps
     docker stop <container-id>
  
  2. Use different port (advanced):
     # Edit Makefile, change 8787 to 8788

Issue: "Cannot connect to localhost:8787"
──────────────────────────────────────────────────────────────────────────
Check:
  1. Container running? docker ps
  2. Try different browser
  3. Try http://127.0.0.1:8787 instead
  4. Firewall blocking? Disable temporarily

Issue: "Out of disk space"
──────────────────────────────────────────────────────────────────────────
Clean up:
  docker system prune -a
  # Removes all unused images and containers
  # Frees significant space

Issue: "Container exits immediately"
──────────────────────────────────────────────────────────────────────────
Check logs:
  docker ps -a              # Show all containers (including stopped)
  docker logs <container-id>  # See error message

Common causes:
  • Port conflict
  • Permission issues
  • Corrupted image (rebuild: zzcollab -p project)

Issue: "Changes not appearing in container"
──────────────────────────────────────────────────────────────────────────
Verify mount:
  # In container:
  ls /home/analyst/project
  # Should show your files
  
  # If empty, mount failed
  # Restart container: Ctrl+C, make docker-rstudio

Issue: "Docker eating all my RAM/CPU"
──────────────────────────────────────────────────────────────────────────
Solutions:
  1. Stop unused containers: docker ps, docker stop <id>
  2. Limit resources: Docker Desktop → Settings → Resources
  3. Close resource-heavy applications while analyzing

═══════════════════════════════════════════════════════════════════════════
DOCKER BEST PRACTICES
═══════════════════════════════════════════════════════════════════════════

1. Always work in /home/analyst/project
   RStudio starts there - don't cd elsewhere!

2. Stop containers when done
   Ctrl+C in terminal - frees resources

3. Don't run too many containers simultaneously
   Work on one project at a time

4. Periodically clean up
   docker system prune every month or so

5. Commit files regularly
   Container stops? No problem if committed to git!

6. Don't store secrets in images
   Use environment variables instead

7. Rebuild images occasionally
   When updating zzcollab or changing build modes

8. Use Docker Desktop dashboard
   Visual way to manage containers and images

═══════════════════════════════════════════════════════════════════════════
ADVANCED: UNDERSTANDING DOCKER BUILD
═══════════════════════════════════════════════════════════════════════════

When zzcollab builds a Docker image:

Step 1: FROM rocker/rstudio
  Download base R + RStudio image

Step 2: RUN apt-get install ...
  Install system dependencies (git, curl, etc.)

Step 3: RUN install2.r ...
  Install R packages

Step 4: COPY dotfiles ...
  Add your personal configuration

Step 5: USER analyst
  Set up non-root user

This creates an image ready for your research!

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE
═══════════════════════════════════════════════════════════════════════════

Essential Concepts:
  • Image = Blueprint (permanent)
  • Container = Running instance (temporary)
  • Volume = File sharing host ↔ container
  • Mount = ~/projects/myproject ↔ /home/analyst/project

Daily Commands:
  make docker-rstudio     # Start RStudio
  Ctrl+C                  # Stop container
  docker ps               # Show running containers

Troubleshooting:
  docker ps               # List containers
  docker images           # List images
  docker logs <id>        # See errors
  docker system prune     # Clean up

File Persistence:
  ✅ /home/analyst/project → SAVED
  ❌ Anywhere else → LOST

Key Files:
  Dockerfile              # Build instructions
  Makefile                # make commands
  docker-compose.yml      # (not used by default)

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help              # General help
  zzcollab --help-workflow     # Daily development workflow
  zzcollab --help-troubleshooting  # Common issues
  zzcollab --help-quickstart   # Getting started
EOF
}


# CI/CD Help
# Purpose: Continuous integration and GitHub Actions guide  
show_cicd_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_cicd_help_content
    else
        show_cicd_help_content | "${PAGER:-less}" -R
    fi
}

show_cicd_help_content() {
    cat << 'EOF'
🔄 CI/CD AND GITHUB ACTIONS

═══════════════════════════════════════════════════════════════════════════
WHAT IS CI/CD? (FOR RESEARCHERS)
═══════════════════════════════════════════════════════════════════════════

CI/CD = Continuous Integration / Continuous Delivery
Fancy term for: "Automatically test your code every time you push to GitHub"

Think of it like this:
  • You write code on your computer
  • Push to GitHub
  • GitHub automatically runs tests
  • You get email if something broke
  • Catches problems before collaborators see them!

Why this matters for research:
  ✅ Automatic validation - Ensures code runs on fresh computer
  ✅ Catches bugs early - Before they cause problems
  ✅ Reproducibility check - Proves analysis actually works
  ✅ Professional practice - Shows thoroughness in research

═══════════════════════════════════════════════════════════════════════════
HOW CI/CD WORKS WITH ZZCOLLAB
═══════════════════════════════════════════════════════════════════════════

The Workflow:

You (on your computer):
  1. Write analysis code
  2. Run tests locally: make docker-test
  3. Commit to git
  4. Push to GitHub

GitHub Actions (automatically):
  1. Detects your push
  2. Creates fresh Docker container
  3. Installs all packages from renv.lock
  4. Runs your tests
  5. Sends you results (✅ pass or ❌ fail)

You (get notified):
  • Green checkmark = All tests passed!
  • Red X = Something broke (fix it!)

═══════════════════════════════════════════════════════════════════════════
GITHUB ACTIONS WORKFLOWS
═══════════════════════════════════════════════════════════════════════════

zzcollab creates these automatic workflows:

1. R Package Check (r-package-check.yml)
──────────────────────────────────────────────────────────────────────────
When: Every push to GitHub
What it does:
  • Runs R CMD check
  • Validates package structure
  • Runs testthat tests
  • Checks documentation

Triggers on:
  • push to main branch
  • pull requests

Time: ~5-10 minutes

2. Environment Validation (validate-environment.yml)
──────────────────────────────────────────────────────────────────────────
When: Every push to GitHub
What it does:
  • Validates renv.lock completeness
  • Checks for missing packages
  • Verifies R environment options

Triggers on:
  • push to any branch
  • pull requests

Time: ~2-3 minutes

3. Render Paper (render-paper.yml) [if using analysis/paper/]
──────────────────────────────────────────────────────────────────────────
When: Every push to GitHub
What it does:
  • Renders analysis/paper/paper.Rmd
  • Generates HTML/PDF output
  • Uploads as artifact

Triggers on:
  • push to main branch

Time: ~5-15 minutes (depends on analysis complexity)

═══════════════════════════════════════════════════════════════════════════
VIEWING GITHUB ACTIONS RESULTS
═══════════════════════════════════════════════════════════════════════════

On GitHub website:

Step 1: Go to your repository
  https://github.com/yourusername/yourproject

Step 2: Click "Actions" tab
  (Between "Pull requests" and "Projects")

Step 3: See workflow runs
  • Green checkmark = Passed
  • Red X = Failed
  • Yellow dot = Running

Step 4: Click run to see details
  • See each step's output
  • Find error messages
  • Download artifacts (rendered reports)

In your terminal:

Using gh CLI:
  gh run list                    # Show recent runs
  gh run view                    # View latest run details
  gh run watch                   # Watch run in real-time

═══════════════════════════════════════════════════════════════════════════
UNDERSTANDING WORKFLOW FILES
═══════════════════════════════════════════════════════════════════════════

Location: .github/workflows/

Example: r-package-check.yml

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

What this means:
  • on: push → Runs automatically on git push
  • runs-on: ubuntu-latest → Uses Ubuntu Linux
  • steps: → Sequential actions to take
  • renv::restore() → Install packages from renv.lock
  • devtools::test() → Run all tests

═══════════════════════════════════════════════════════════════════════════
COMMON CI/CD WORKFLOWS
═══════════════════════════════════════════════════════════════════════════

Workflow 1: Normal Development (All Tests Pass)
──────────────────────────────────────────────────────────────────────────
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

Workflow 2: Broken Test (Caught by CI/CD!)
──────────────────────────────────────────────────────────────────────────
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

Workflow 3: Pull Request Review
──────────────────────────────────────────────────────────────────────────
# Team member creates pull request
# GitHub Actions runs automatically
# Reviewer sees: ✅ All checks passed
# Safe to merge!

Workflow 4: Reproducibility Validation
──────────────────────────────────────────────────────────────────────────
# Push final analysis
# GitHub Actions creates fresh environment
# Installs packages from renv.lock
# Runs analysis from scratch
# ✅ Success = Truly reproducible!

═══════════════════════════════════════════════════════════════════════════
CUSTOMIZING CI/CD WORKFLOWS
═══════════════════════════════════════════════════════════════════════════

Add custom validation:

.github/workflows/custom-validation.yml

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
        run: Rscript scripts/validate_data.R
      
      - name: Run analysis
        run: Rscript scripts/run_analysis.R
      
      - name: Check outputs
        run: |
          if [ ! -f "analysis/figures/plot.png" ]; then
            echo "Missing plot.png!"
            exit 1
          fi

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING CI/CD FAILURES
═══════════════════════════════════════════════════════════════════════════

Issue 1: "Tests pass locally but fail on GitHub"
──────────────────────────────────────────────────────────────────────────
Common causes:
  1. Missing package in renv.lock
     Solution: renv::snapshot(), commit, push
  
  2. Hardcoded paths (e.g., /Users/yourname/...)
     Solution: Use here::here() for paths
  
  3. System dependency missing
     Solution: Add to workflow file (apt-get install ...)

Debug:
  # Run in fresh container locally:
  docker run --rm -v $(pwd):/project rocker/r-ver:latest \
    bash -c "cd /project && Rscript -e 'renv::restore(); devtools::test()'"

Issue 2: "renv::restore() fails"
──────────────────────────────────────────────────────────────────────────
Causes:
  • Package not on CRAN anymore
  • Package needs system dependencies
  • renv.lock corrupted

Solutions:
  # Add system dependencies to workflow:
  - name: Install system dependencies
    run: sudo apt-get install -y libcurl4-openssl-dev libssl-dev
  
  # Or specify CRAN repository explicitly:
  - name: Restore packages
    run: |
      options(repos = c(CRAN = "https://cloud.r-project.org"))
      renv::restore()

Issue 3: "Workflow takes too long (>30 minutes)"
──────────────────────────────────────────────────────────────────────────
Optimizations:
  1. Cache packages:
     - uses: actions/cache@v3
       with:
         path: ~/.local/share/renv
         key: renv-${{ hashFiles('renv.lock') }}
  
  2. Use minimal build mode for CI
  
  3. Split into separate workflows (test vs. full analysis)

Issue 4: "Workflow not running"
──────────────────────────────────────────────────────────────────────────
Check:
  1. File in .github/workflows/ directory?
  2. YAML syntax correct? (use yamllint.com)
  3. GitHub Actions enabled? (Settings → Actions)
  4. Pushing to correct branch? (check "on: push: branches:")

Issue 5: "Can't reproduce failure locally"
──────────────────────────────────────────────────────────────────────────
Solution: Test in container with same OS
  # GitHub uses Ubuntu, test with:
  docker run --rm -it -v $(pwd):/project rocker/r-ver:latest bash
  cd /project
  Rscript -e "renv::restore()"
  Rscript -e "devtools::test()"

═══════════════════════════════════════════════════════════════════════════
CI/CD BEST PRACTICES
═══════════════════════════════════════════════════════════════════════════

1. Test locally before pushing
   make docker-test
   # Catches problems before CI/CD

2. Keep renv.lock up to date
   install.packages("newpkg")
   renv::snapshot()
   git add renv.lock
   # Ensures CI/CD has all packages

3. Use meaningful commit messages
   git commit -m "Add penguin analysis"
   # Easier to identify which commit broke tests

4. Review CI/CD output regularly
   Check green checkmarks on GitHub
   Read failure messages carefully

5. Don't disable CI/CD when tests fail
   Fix the tests instead!
   Tests are there for a reason

6. Use branch protection rules
   GitHub → Settings → Branches
   Require tests to pass before merging

7. Monitor workflow run times
   Optimize if >10 minutes regularly

8. Keep workflows simple
   Complex workflows hard to debug

═══════════════════════════════════════════════════════════════════════════
ADVANCED: SCHEDULED WORKFLOWS
═══════════════════════════════════════════════════════════════════════════

Run tests periodically (e.g., weekly):

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

Why useful:
  • Catches package updates that break code
  • Verifies long-term reproducibility
  • Peace of mind for published research

═══════════════════════════════════════════════════════════════════════════
GITHUB ACTIONS BADGES
═══════════════════════════════════════════════════════════════════════════

Add status badges to README.md:

[![R Package Check](https://github.com/user/repo/workflows/R%20Package%20Check/badge.svg)](https://github.com/user/repo/actions)

Shows: Build status directly in README
Result: ✅ Passing or ❌ Failing badge

Professional look for your research repository!

═══════════════════════════════════════════════════════════════════════════
COMMON QUESTIONS
═══════════════════════════════════════════════════════════════════════════

Q: "Do I have to use CI/CD?"
A: No, but highly recommended! Catches reproducibility issues early.

Q: "Does CI/CD cost money?"
A: Free for public repositories. 2000 minutes/month free for private.

Q: "What if I don't want to use GitHub Actions?"
A: Can use GitLab CI, Travis CI, CircleCI. GitHub Actions easiest with zzcollab.

Q: "Can I run workflows manually?"
A: Yes! Add "workflow_dispatch:" to trigger section, then use website or:
   gh workflow run workflow-name.yml

Q: "What happens if workflow fails?"
A: You get email. Fix code, push again. Workflow reruns automatically.

Q: "Can I test workflows without pushing?"
A: Use "act" tool (github.com/nektos/act) to run workflows locally.

Q: "How do I see workflow logs?"
A: GitHub → Actions tab → Click workflow run → Expand steps

Q: "Can collaborators see workflow results?"
A: Yes, if they have repo access.

Q: "What if workflow fails but I can't fix it right now?"
A: Create issue on GitHub to track. Fix when you can. Don't ignore!

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE
═══════════════════════════════════════════════════════════════════════════

Workflow Files:
  .github/workflows/r-package-check.yml     # Package validation
  .github/workflows/validate-environment.yml # renv validation
  .github/workflows/render-paper.yml        # Paper rendering

View Results:
  GitHub → Repository → Actions tab
  gh run list             # CLI
  gh run view             # CLI details

Local Testing:
  make docker-test        # Run tests locally
  docker run ...          # Test in fresh container

Common Issues:
  • Tests pass locally, fail CI → Missing renv.lock entry
  • renv::restore() fails → System dependencies
  • Workflow not running → Check .github/workflows/ location

Best Practices:
  1. Test locally first
  2. Keep renv.lock updated
  3. Review CI/CD output
  4. Fix failures promptly
  5. Use branch protection

═══════════════════════════════════════════════════════════════════════════

For more help:
  zzcollab --help              # General help
  zzcollab --help-github       # GitHub integration
  zzcollab --help-troubleshooting  # Common issues
  zzcollab --help-renv         # Package management
  
GitHub Actions Documentation:
  https://docs.github.com/en/actions
EOF
}


#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

# Validate this module loaded correctly
if ! declare -f log_debug >/dev/null 2>&1; then
    echo "Warning: help_guides.sh: log_debug function not available" >&2
else
    log_debug "help_guides.sh: Module loaded successfully"
fi
