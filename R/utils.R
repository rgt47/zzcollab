# ZZCOLLAB R Interface Functions
# Provides R functions to interact with zzcollab Docker infrastructure

#' Null-coalescing operator
#'
#' @param lhs Left-hand side
#' @param rhs Right-hand side
#' @return lhs if not NULL, else rhs
#' @keywords internal
`%||%` <- function(lhs, rhs) {
  if (!is.null(lhs)) lhs else rhs
}

#' Find zzcollab script
#'
#' @return Path to zzcollab script
#' @keywords internal
find_zzcollab_script <- function() {
  # First priority: Check if we're in the zzcollab source directory
  if (file.exists("zzcollab.sh")) {
    return("./zzcollab.sh")
  }
  
  # Second priority: Check if zzcollab is in PATH (but only if it supports config)
  zzcollab_path <- Sys.which("zzcollab")
  if (zzcollab_path != "") {
    # Test if this version supports config commands
    test_result <- system(paste(zzcollab_path, "config list"), 
                         ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (test_result == 0) {
      return("zzcollab")
    }
  }
  
  # Third priority: Check common installation locations
  possible_paths <- c(
    file.path(Sys.getenv("HOME"), "bin", "zzcollab"),
    "/usr/local/bin/zzcollab",
    "/usr/bin/zzcollab"
  )
  
  for (path in possible_paths) {
    if (file.exists(path)) {
      # Test if this version supports config commands
      test_result <- system(paste(path, "config list"), 
                           ignore.stdout = TRUE, ignore.stderr = TRUE)
      if (test_result == 0) {
        return(path)
      }
    }
  }
  
  stop("zzcollab script with config support not found. Please use zzcollab from source directory or install updated version.")
}

#' Check Docker container status
#'
#' @return Character vector with container status information
#' @export
status <- function() {
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
rebuild <- function(target = "docker-build") {
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
team_images <- function() {
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
#' @param team_name Docker Hub team/organization name (uses config default if NULL)
#' @param project_name Project name
#' @param github_account GitHub account (uses config default or team_name if NULL)
#' @param dotfiles_path Path to dotfiles directory (uses config default if NULL)
#' @param dotfiles_nodots Logical, if TRUE dotfiles need dots added (uses config default)
#' @param build_mode Build mode: "fast", "standard", or "comprehensive" (uses config default)
#' @return Logical indicating success
#' @export
init_project <- function(team_name = NULL, project_name = NULL, 
                         github_account = NULL, 
                         dotfiles_path = NULL,
                         dotfiles_nodots = NULL,
                         build_mode = NULL) {
  
  # Apply config defaults for missing parameters
  team_name <- team_name %||% get_config_default("team_name")
  github_account <- github_account %||% get_config_default("github_account") %||% team_name
  dotfiles_path <- dotfiles_path %||% get_config_default("dotfiles_dir")
  build_mode <- build_mode %||% get_config_default("build_mode", "standard")
  dotfiles_nodots <- dotfiles_nodots %||% (get_config_default("dotfiles_nodot", "false") == "true")
  
  # Validate required parameters
  if (is.null(team_name)) {
    stop("team_name is required. Set via parameter or config: set_config('team_name', 'myteam')")
  }
  if (is.null(project_name)) {
    stop("project_name is required")
  }
  
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  # Build command with --init flag
  cmd <- paste(zzcollab_path, "--init --team-name", team_name, "--project-name", project_name)
  
  if (!is.null(github_account)) {
    cmd <- paste(cmd, "--github-account", github_account)
  }
  
  if (!is.null(dotfiles_path)) {
    if (dotfiles_nodots) {
      cmd <- paste(cmd, "--dotfiles-nodot", shQuote(dotfiles_path))
    } else {
      cmd <- paste(cmd, "--dotfiles", shQuote(dotfiles_path))
    }
  }
  
  # Add build mode flag
  if (build_mode == "fast") {
    cmd <- paste(cmd, "-F")
  } else if (build_mode == "comprehensive") {
    cmd <- paste(cmd, "-C")
  } else {
    cmd <- paste(cmd, "-S")
  }
  
  message("Running: ", cmd)
  result <- system(cmd)
  return(result == 0)
}

#' Join existing zzcollab project (R interface for Developers 2+)
#'
#' @param team_name Team name (Docker Hub organization) (uses config default if NULL)
#' @param project_name Project name
#' @param interface Interface type: "shell", "rstudio", or "verse" (default: "shell")
#' @param dotfiles_path Path to dotfiles directory (uses config default if NULL)
#' @param dotfiles_nodots Logical, if TRUE dotfiles need dots added (uses config default)
#' @param build_mode Build mode: "fast", "standard", or "comprehensive" (uses config default)
#' @return Logical indicating success
#' @export
join_project <- function(team_name = NULL, project_name = NULL, interface = "shell",
                         dotfiles_path = NULL, dotfiles_nodots = NULL,
                         build_mode = NULL) {
  
  # Apply config defaults for missing parameters
  team_name <- team_name %||% get_config_default("team_name")
  dotfiles_path <- dotfiles_path %||% get_config_default("dotfiles_dir")
  build_mode <- build_mode %||% get_config_default("build_mode", "standard")
  dotfiles_nodots <- dotfiles_nodots %||% (get_config_default("dotfiles_nodot", "false") == "true")
  
  # Validate required parameters
  if (is.null(team_name)) {
    stop("team_name is required. Set via parameter or config: set_config('team_name', 'myteam')")
  }
  if (is.null(project_name)) {
    stop("project_name is required")
  }
  
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  # Build command with new user-friendly interface
  cmd <- paste(zzcollab_path, "--team", team_name, "--project-name", project_name, "--interface", interface)
  
  if (!is.null(dotfiles_path)) {
    if (dotfiles_nodots) {
      cmd <- paste(cmd, "--dotfiles-nodot", shQuote(dotfiles_path))
    } else {
      cmd <- paste(cmd, "--dotfiles", shQuote(dotfiles_path))
    }
  }
  
  # Add build mode flag
  if (build_mode == "fast") {
    cmd <- paste(cmd, "-F")
  } else if (build_mode == "comprehensive") {
    cmd <- paste(cmd, "-C")
  } else {
    cmd <- paste(cmd, "-S")
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
add_package <- function(packages, update_snapshot = TRUE) {
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
sync_env <- function() {
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
    message("Run rebuild() or 'make docker-build' to update Docker environment")
  }
  
  return(TRUE)
}

#' Execute analysis script in container
#'
#' @param script_path Path to R script
#' @param container_cmd Container command (default: "docker-r")
#' @return Logical indicating success
#' @export
run_script <- function(script_path, container_cmd = "docker-r") {
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
render_report <- function(report_path = NULL) {
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
validate_repro <- function() {
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

#' Create and push git commit
#'
#' @param message Commit message
#' @param add_all Logical, add all files (default: TRUE)
#' @return Logical indicating success
#' @export
git_commit <- function(message, add_all = TRUE) {
  if (add_all) {
    result1 <- system("git add .")
    if (result1 != 0) {
      stop("Failed to add files to git")
    }
  }
  
  # Create commit with proper formatting
  commit_cmd <- sprintf('git commit -m "%s"', message)
  result2 <- system(commit_cmd)
  
  if (result2 == 0) {
    message("✅ Commit created: ", message)
    return(TRUE)
  } else {
    message("❌ Commit failed")
    return(FALSE)
  }
}

#' Push commits to GitHub
#'
#' @param branch Branch name (default: current branch)
#' @return Logical indicating success  
#' @export
git_push <- function(branch = NULL) {
  if (is.null(branch)) {
    cmd <- "git push"
  } else {
    cmd <- paste("git push origin", branch)
  }
  
  result <- system(cmd)
  
  if (result == 0) {
    message("✅ Successfully pushed to GitHub")
    return(TRUE)
  } else {
    message("❌ Push failed")
    return(FALSE)
  }
}

#' Create GitHub pull request
#'
#' @param title Pull request title
#' @param body Pull request body (optional)
#' @param base Base branch (default: "main")
#' @return Logical indicating success
#' @export
create_pr <- function(title, body = NULL, base = "main") {
  if (!nzchar(system.file(package = "gh"))) {
    # Check if gh CLI is available
    if (system("which gh", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0) {
      stop("GitHub CLI (gh) is required. Install with: brew install gh")
    }
  }
  
  cmd <- paste("gh pr create --title", shQuote(title), "--base", base)
  
  if (!is.null(body)) {
    cmd <- paste(cmd, "--body", shQuote(body))
  }
  
  result <- system(cmd)
  
  if (result == 0) {
    message("✅ Pull request created successfully")
    return(TRUE)
  } else {
    message("❌ Failed to create pull request")
    return(FALSE)
  }
}

#' Check git status
#'
#' @return Character vector with git status output
#' @export
git_status <- function() {
  result <- system("git status --porcelain", intern = TRUE)
  
  if (length(result) == 0) {
    message("✅ Working directory clean")
    return(character(0))
  } else {
    message("📝 Changes detected:")
    print(result)
    return(result)
  }
}

#' Create feature branch
#'
#' @param branch_name Name of the new branch
#' @return Logical indicating success
#' @export
create_branch <- function(branch_name) {
  # Ensure we're on main and up to date
  system("git checkout main", ignore.stdout = TRUE)
  system("git pull", ignore.stdout = TRUE)
  
  # Create and checkout new branch
  result <- system(paste("git checkout -b", branch_name))
  
  if (result == 0) {
    message("✅ Created and switched to branch: ", branch_name)
    return(TRUE)
  } else {
    message("❌ Failed to create branch: ", branch_name)
    return(FALSE)
  }
}

#' Setup zzcollab project (standard setup, non-init mode)
#'
#' @param dotfiles_path Path to dotfiles directory (uses config default if NULL)
#' @param dotfiles_nodots Logical, if TRUE dotfiles need dots added (uses config default)
#' @param build_mode Build mode: "fast", "standard", or "comprehensive" (uses config default)
#' @param base_image Base Docker image to use (optional)
#' @return Logical indicating success
#' @export
setup_project <- function(dotfiles_path = NULL, dotfiles_nodots = NULL,
                         build_mode = NULL, base_image = NULL) {
  
  # Apply config defaults for missing parameters
  dotfiles_path <- dotfiles_path %||% get_config_default("dotfiles_dir")
  build_mode <- build_mode %||% get_config_default("build_mode", "standard")
  dotfiles_nodots <- dotfiles_nodots %||% (get_config_default("dotfiles_nodot", "false") == "true")
  
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  # Build command (no --init flag)
  cmd <- zzcollab_path
  
  if (!is.null(dotfiles_path)) {
    if (dotfiles_nodots) {
      cmd <- paste(cmd, "--dotfiles-nodot", shQuote(dotfiles_path))
    } else {
      cmd <- paste(cmd, "--dotfiles", shQuote(dotfiles_path))
    }
  }
  
  if (!is.null(base_image)) {
    cmd <- paste(cmd, "--base-image", base_image)
  }
  
  # Add build mode flag
  if (build_mode == "fast") {
    cmd <- paste(cmd, "-F")
  } else if (build_mode == "comprehensive") {
    cmd <- paste(cmd, "-C")
  } else {
    cmd <- paste(cmd, "-S")
  }
  
  message("Running: ", cmd)
  result <- system(cmd)
  return(result == 0)
}

#' Get zzcollab help
#'
#' @param init_help Logical, show initialization help instead of general help
#' @return Character vector with help text
#' @export
zzcollab_help <- function(init_help = FALSE) {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  if (init_help) {
    cmd <- paste(zzcollab_path, "--init --help")
  } else {
    cmd <- paste(zzcollab_path, "--help")
  }
  
  result <- system(cmd, intern = TRUE)
  return(result)
}

#' Get zzcollab next steps
#'
#' @return Character vector with next steps information
#' @export
zzcollab_next_steps <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  cmd <- paste(zzcollab_path, "--next-steps")
  result <- system(cmd, intern = TRUE)
  return(result)
}

#=============================================================================
# CONFIGURATION SYSTEM R INTERFACE
#=============================================================================

#' Get configuration value
#'
#' @param key Configuration key (e.g., "team_name", "build_mode")
#' @return Configuration value or NULL if not set
#' @export
get_config <- function(key) {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  cmd <- paste(zzcollab_path, "config get", key)
  result <- system(cmd, intern = TRUE)
  
  if (length(result) > 0 && !grepl("\\(not set\\)", result[1])) {
    return(result[1])
  } else {
    return(NULL)
  }
}

#' Set configuration value
#'
#' @param key Configuration key
#' @param value Configuration value
#' @return Logical indicating success
#' @export
set_config <- function(key, value) {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  cmd <- paste(zzcollab_path, "config set", key, shQuote(value))
  result <- system(cmd)
  return(result == 0)
}

#' List all configuration values
#'
#' @return Character vector with configuration listing
#' @export
list_config <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  cmd <- paste(zzcollab_path, "config list")
  result <- system(cmd, intern = TRUE)
  return(result)
}

#' Validate configuration files
#'
#' @return Logical indicating if all config files are valid
#' @export
validate_config <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  cmd <- paste(zzcollab_path, "config validate")
  result <- system(cmd)
  return(result == 0)
}

#' Initialize default configuration file
#'
#' @return Logical indicating success
#' @export
init_config <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()
  
  cmd <- paste(zzcollab_path, "config init")
  result <- system(cmd)
  return(result == 0)
}

#' Get configuration-aware default value
#'
#' @param key Configuration key
#' @param default Default value if config not set
#' @return Configuration value or default
#' @keywords internal
get_config_default <- function(key, default = NULL) {
  config_value <- get_config(key)
  if (!is.null(config_value)) {
    return(config_value)
  } else {
    return(default)
  }
}