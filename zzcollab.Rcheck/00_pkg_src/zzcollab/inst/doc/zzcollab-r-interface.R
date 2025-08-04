## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE  # Don't evaluate code chunks by default
)

## ----setup--------------------------------------------------------------------
# library(zzcollab)

## ----init-project-------------------------------------------------------------
# # Initialize a new research project with team collaboration
# init_project(
#   team_name = "myteam",
#   project_name = "myproject",
#   build_mode = "standard",
#   dotfiles_path = "~/dotfiles"
# )

## ----join-project-------------------------------------------------------------
# # Join an existing project
# join_project(
#   team_name = "myteam",
#   project_name = "myproject",
#   interface = "shell",
#   build_mode = "standard"
# )

## ----setup-project------------------------------------------------------------
# # Setup a project in the current directory
# setup_project(
#   build_mode = "standard",
#   dotfiles_path = "~/dotfiles"
# )

## ----build-modes--------------------------------------------------------------
# # Fast mode - minimal setup for quick development
# init_project("team", "project", build_mode = "fast")
# 
# # Standard mode - balanced approach (default)
# init_project("team", "project", build_mode = "standard")
# 
# # Comprehensive mode - full featured environment
# init_project("team", "project", build_mode = "comprehensive")

## ----status-------------------------------------------------------------------
# # Check running zzcollab containers
# status()

## ----rebuild------------------------------------------------------------------
# # Rebuild Docker image after dependency changes
# rebuild()

## ----team-images--------------------------------------------------------------
# # List available team Docker images
# team_images()

## ----add-package--------------------------------------------------------------
# # Add packages to the project
# add_package(c("dplyr", "ggplot2"))

## ----sync-env-----------------------------------------------------------------
# # Sync environment with renv.lock
# sync_env()

## ----run-script---------------------------------------------------------------
# # Execute R script in container
# run_script("analysis/my_analysis.R")

## ----render-report------------------------------------------------------------
# # Render analysis reports
# render_report("analysis/report.Rmd")

## ----validate-repro-----------------------------------------------------------
# # Check if environment is reproducible
# validate_repro()

## ----git-status---------------------------------------------------------------
# # Check git status
# git_status()

## ----create-branch------------------------------------------------------------
# # Create and switch to feature branch
# create_branch("feature/new-analysis")

## ----git-commit---------------------------------------------------------------
# # Commit changes
# git_commit("Add new analysis results")

## ----git-push-----------------------------------------------------------------
# # Push to GitHub
# git_push()

## ----create-pr----------------------------------------------------------------
# # Create pull request
# create_pr(
#   title = "Add new analysis results",
#   body = "This PR adds the results from our latest analysis."
# )

## ----help---------------------------------------------------------------------
# # Get general help
# zzcollab_help()
# 
# # Get initialization help
# zzcollab_help(init_help = TRUE)

## ----next-steps---------------------------------------------------------------
# # Get next steps guidance
# zzcollab_next_steps()

## ----complete-workflow--------------------------------------------------------
# # 1. Initialize project (team leader)
# init_project(
#   team_name = "datascience",
#   project_name = "covid-analysis",
#   build_mode = "standard",
#   dotfiles_path = "~/dotfiles"
# )
# 
# # 2. Add required packages
# add_package(c("tidyverse", "lubridate", "plotly"))
# 
# # 3. Create feature branch
# create_branch("feature/exploratory-analysis")
# 
# # 4. Run analysis
# run_script("scripts/exploratory_analysis.R")
# 
# # 5. Render report
# render_report("analysis/covid_report.Rmd")
# 
# # 6. Validate reproducibility
# if (validate_repro()) {
#   message("✅ Environment is reproducible")
# } else {
#   message("❌ Environment needs attention")
# }
# 
# # 7. Commit and push
# git_commit("Add COVID-19 exploratory analysis")
# git_push()
# 
# # 8. Create pull request
# create_pr(
#   title = "Add COVID-19 Exploratory Analysis",
#   body = "This PR adds exploratory analysis of COVID-19 data with visualizations."
# )

## ----custom-base--------------------------------------------------------------
# # Use custom base image
# setup_project(
#   base_image = "myteam/myproject-base:latest",
#   build_mode = "fast"
# )

## ----team-workflow------------------------------------------------------------
# # Team leader initializes
# init_project("datascience", "covid-analysis", build_mode = "standard")
# 
# # Team members join
# join_project("datascience", "covid-analysis", interface = "rstudio")
# 
# # Everyone can now work with the same environment
# status()  # Check container status
# sync_env()  # Sync with latest dependencies

## ----troubleshooting----------------------------------------------------------
# # Check if zzcollab is available
# try(zzcollab_help())
# 
# # Check Docker status
# status()
# 
# # Validate environment
# validate_repro()

