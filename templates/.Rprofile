# ==========================================
# ZZCOLLAB .Rprofile - Reproducibility Layer
# ==========================================
# This file is version-controlled and affects analysis reproducibility.
# Changes to critical options should be reviewed by the team.

# Activate renv (set project-local library paths)
# renv is pre-installed in Docker system library
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# ==========================================
# Critical Reproducibility Options
# See: docs/COLLABORATIVE_REPRODUCIBILITY.md Pillar 3
# ==========================================
# These options affect computational results and should not be modified
# without team review. Changes are monitored by check_rprofile_options.R

options(
  # Character vector treatment in data.frames
  # FALSE ensures characters stay as characters (R >= 4.0.0 default)
  stringsAsFactors = FALSE,

  # Statistical contrasts for factor variables in models
  # Treatment contrasts for unordered factors, polynomial for ordered
  contrasts = c("contr.treatment", "contr.poly"),

  # Missing data handling in modeling functions
  # na.omit removes rows with any NA values
  na.action = "na.omit",

  # Numeric precision in printed output
  # 7 significant digits (R default)
  digits = 7,

  # Decimal separator for output
  # Period (US standard) ensures consistency across locales
  OutDec = ".",

  # CRAN mirror for package installation
  repos = c(CRAN = "https://cloud.r-project.org")
)

# ==========================================
# Auto-Snapshot on R Exit
# ==========================================
# Automatically updates renv.lock when exiting R session
# This captures any packages installed during the session

.Last <- function() {
  # Check if auto-snapshot is enabled (default: true)
  auto_snapshot <- Sys.getenv("ZZCOLLAB_AUTO_SNAPSHOT", "true")

  if (tolower(auto_snapshot) %in% c("true", "t", "1")) {
    # Check if we're in an renv project
    if (file.exists("renv.lock") && file.exists("renv/activate.R")) {
      message("\n📸 Auto-snapshot: Updating renv.lock...")

      snapshot_result <- tryCatch({
        # Snapshot with prompt disabled (non-interactive)
        # Uses default snapshot type (captures all installed packages)
        renv::snapshot(prompt = FALSE)
        TRUE
      }, error = function(e) {
        warning("Auto-snapshot failed: ", conditionMessage(e), call. = FALSE)
        FALSE
      })

      if (snapshot_result) {
        message("✅ renv.lock updated successfully")
        message("   Commit changes: git add renv.lock && git commit -m 'Update packages'")
      }
    }
  }

  # Call any user-defined .Last function from .Rprofile.local
  if (exists(".Last.user", mode = "function", envir = .GlobalEnv)) {
    tryCatch(
      .Last.user(),
      error = function(e) warning("User .Last failed: ", conditionMessage(e))
    )
  }
}

# ==========================================
# Personal/Team Customizations (Optional)
# ==========================================
# Load personal settings from git-ignored file
# This allows team members to have personal preferences without
# affecting version-controlled reproducibility settings

if (file.exists(".Rprofile.local")) {
  tryCatch(
    source(".Rprofile.local"),
    error = function(e) {
      warning(".Rprofile.local failed to load: ", conditionMessage(e))
    }
  )
}

# ==========================================
# Development Tools (Interactive Sessions Only)
# ==========================================
# Auto-load common development packages in interactive sessions
# These do not affect reproducibility of analysis scripts

if (interactive()) {
  suppressMessages({
    if (requireNamespace("devtools", quietly = TRUE)) library(devtools)
    if (requireNamespace("usethis", quietly = TRUE)) library(usethis)
  })
}
