# ZZCOLLAB R Interface Functions
# Provides R functions to interact with zzcollab Docker infrastructure

#' Check Docker container status
#'
#' @return Character vector with container status information
#' @export
zzcollab_status <- function() {
  result <- system("docker ps --filter 'label=zzcollab' --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'", 
                   intern = TRUE)
  if (length(result) == 0) {
    message("No zzcollab containers running")
    return(character(0))
  }
  return(result)
}

#' Trigger Docker image rebuild
#'
#' @param target Build target (default: "docker-build")
#' @return Logical indicating success
#' @export
zzcollab_rebuild <- function(target = "docker-build") {
  if (!file.exists("Makefile")) {
    stop("No Makefile found. Are you in a zzcollab project directory?")
  }
  
  result <- system(paste("make", target), intern = TRUE)
  return(attr(result, "status") %||% 0 == 0)
}

#' List available team Docker images
#'
#' @return Data frame with image information
#' @export
zzcollab_team_images <- function() {
  result <- system("docker images --filter 'label=zzcollab.team' --format '{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}'", 
                   intern = TRUE)
  
  if (length(result) == 0) {
    message("No zzcollab team images found")
    return(data.frame())
  }
  
  # Parse the tab-separated output
  lines <- strsplit(result, "\t")
  df <- data.frame(
    repository = sapply(lines, `[`, 1),
    tag = sapply(lines, `[`, 2),
    size = sapply(lines, `[`, 3),
    created = sapply(lines, `[`, 4),
    stringsAsFactors = FALSE
  )
  return(df)
}

#' Initialize zzcollab project (R interface)
#'
#' @param team_name Docker Hub team/organization name
#' @param project_name Project name
#' @param github_account GitHub account (defaults to team_name)
#' @param dotfiles_path Path to dotfiles directory
#' @param dotfiles_nodots Logical, if TRUE dotfiles need dots added
#' @return Logical indicating success
#' @export
zzcollab_init_project <- function(team_name, project_name, 
                                  github_account = NULL, 
                                  dotfiles_path = NULL,
                                  dotfiles_nodots = FALSE) {
  
  # Build command
  cmd <- paste("zzcollab-init-team --team-name", team_name, "--project-name", project_name)
  
  if (!is.null(github_account)) {
    cmd <- paste(cmd, "--github-account", github_account)
  }
  
  if (!is.null(dotfiles_path)) {
    if (dotfiles_nodots) {
      cmd <- paste(cmd, "--dotfiles-nodots", shQuote(dotfiles_path))
    } else {
      cmd <- paste(cmd, "--dotfiles", shQuote(dotfiles_path))
    }
  }
  
  message("Running: ", cmd)
  result <- system(cmd)
  return(result == 0)
}

#' Add R package to renv
#'
#' @param packages Character vector of package names
#' @param update_snapshot Logical, update renv.lock after installation
#' @return Logical indicating success
#' @export
zzcollab_add_package <- function(packages, update_snapshot = TRUE) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    stop("renv package is required for this function")
  }
  
  # Install packages
  for (pkg in packages) {
    message("Installing package: ", pkg)
    install.packages(pkg)
  }
  
  # Update snapshot if requested
  if (update_snapshot) {
    message("Updating renv.lock...")
    renv::snapshot()
  }
  
  return(TRUE)
}

#' Sync environment across team
#'
#' @return Logical indicating success
#' @export
zzcollab_sync_env <- function() {
  if (!requireNamespace("renv", quietly = TRUE)) {
    stop("renv package is required for this function")
  }
  
  if (!file.exists("renv.lock")) {
    stop("No renv.lock file found. Are you in a zzcollab project directory?")
  }
  
  message("Restoring environment from renv.lock...")
  renv::restore()
  
  # Check if we need to rebuild Docker image
  result <- system("make docker-check-renv", intern = TRUE)
  if (attr(result, "status") %||% 0 != 0) {
    message("Environment sync may require Docker image rebuild")
    message("Run zzcollab_rebuild() or 'make docker-build' to update Docker environment")
  }
  
  return(TRUE)
}

#' Execute analysis script in container
#'
#' @param script_path Path to R script
#' @param container_cmd Container command (default: "docker-r")
#' @return Logical indicating success
#' @export
zzcollab_run_script <- function(script_path, container_cmd = "docker-r") {
  if (!file.exists(script_path)) {
    stop("Script file not found: ", script_path)
  }
  
  if (!file.exists("Makefile")) {
    stop("No Makefile found. Are you in a zzcollab project directory?")
  }
  
  # Execute script in container
  cmd <- paste("make", container_cmd, "ARGS='-e \"source(\\\"", script_path, "\\\")\"'")
  message("Running script in container: ", script_path)
  result <- system(cmd)
  return(result == 0)
}

#' Render analysis reports
#'
#' @param report_path Path to R Markdown file (optional)
#' @return Logical indicating success
#' @export
zzcollab_render_report <- function(report_path = NULL) {
  if (!file.exists("Makefile")) {
    stop("No Makefile found. Are you in a zzcollab project directory?")
  }
  
  if (!is.null(report_path)) {
    # Render specific report
    if (!file.exists(report_path)) {
      stop("Report file not found: ", report_path)
    }
    cmd <- paste("make docker-render REPORT=", shQuote(report_path))
  } else {
    # Use default make target
    cmd <- "make docker-render"
  }
  
  message("Rendering report in container...")
  result <- system(cmd)
  return(result == 0)
}

#' Check reproducibility
#'
#' @return Logical indicating if environment is reproducible
#' @export
zzcollab_validate_repro <- function() {
  scripts_to_check <- c(
    "scripts/99_reproducibility_check.R",
    "check_renv_for_commit.R",
    "check_rprofile_options.R"
  )
  
  all_passed <- TRUE
  
  for (script in scripts_to_check) {
    if (file.exists(script)) {
      message("Running reproducibility check: ", script)
      result <- system(paste("Rscript", script), intern = TRUE)
      if (attr(result, "status") %||% 0 != 0) {
        message("FAILED: ", script)
        all_passed <- FALSE
      } else {
        message("PASSED: ", script)
      }
    }
  }
  
  # Check renv status
  if (requireNamespace("renv", quietly = TRUE)) {
    if (!renv::status()$synchronized) {
      message("WARNING: renv environment is not synchronized")
      all_passed <- FALSE
    }
  }
  
  if (all_passed) {
    message("✅ All reproducibility checks passed")
  } else {
    message("❌ Some reproducibility checks failed")
  }
  
  return(all_passed)
}