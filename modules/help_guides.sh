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
# MODULE VALIDATION AND LOADING
#=============================================================================
