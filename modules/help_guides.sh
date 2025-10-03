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
    show_dotfiles_help_content | smart_pager
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

