# Activate renv for this project
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Set R options
options(stringsAsFactors = FALSE)
options(contrasts = c("contr.treatment", "contr.poly"))
options(na.action = "na.omit")
options(digits = 7)
options(OutDec = ".")

# Load common packages for interactive use
if (interactive()) {
  suppressMessages({
    if (requireNamespace("devtools", quietly = TRUE)) library(devtools)
    if (requireNamespace("usethis", quietly = TRUE)) library(usethis)
  })
}