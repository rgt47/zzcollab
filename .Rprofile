options(repos = c(CRAN = "https://cloud.r-project.org"))
q <- function(save="no", ...) quit(save=save, ...)

# Package installation behavior (non-interactive)
# Prevents prompts during install.packages()
options(
install.packages.check.source = "no",
install.packages.compile.from.source = "never",

# Parallel installation (faster package installs)
  Ncpus = parallel::detectCores()
)
