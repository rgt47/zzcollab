# Run this in R to set up renv
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}
renv::init(settings = list(snapshot.type = "explicit"))

# Install minimal required packages for rrtools functionality
install.packages(c(
  # Package development essentials
  "devtools", "usethis", "roxygen2", "testthat",
  
  # Documentation and reporting
  "knitr", "rmarkdown",
  
  # Package management
  "renv"
))

# Take snapshot of the environment
renv::snapshot()