# Activate renv for this project
# Skip bootstrap - renv pre-installed in Docker system library
# This prevents renv from downloading/installing at runtime
Sys.setenv(RENV_CONFIG_AUTOLOADER_ENABLED = "FALSE")
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Load common packages for interactive use
if (interactive()) {
  suppressMessages({
    if (requireNamespace("devtools", quietly = TRUE)) library(devtools)
    if (requireNamespace("usethis", quietly = TRUE)) library(usethis)
  })
}
