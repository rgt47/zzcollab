# ZZCOLLAB R Interface Functions
# Provides R functions to interact with zzcollab Docker infrastructure

#' Null-coalescing operator
#'
#' @param lhs Left-hand side
#' @param rhs Right-hand side
#' @return lhs if not NULL, else rhs
#' @export
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

#' Check Docker container status for zzcollab projects
#'
#' This function checks for running Docker containers that have the 'zzcollab' label.
#' It's useful for monitoring your development environment and seeing which containers
#' are currently active for your research projects.
#'
#' @return Character vector with container status information in table format.
#'   Each element contains: container name, status, and Docker image.
#'   Returns empty character vector if no zzcollab containers are running.
#'   
#' @details 
#' The function uses Docker's filtering capabilities to find containers with the
#' 'zzcollab' label. This label is automatically added to containers created by
#' the zzcollab framework.
#' 
#' @examples
#' \dontrun{
#' # Check if any zzcollab containers are running
#' container_status <- status()
#' if (length(container_status) > 0) {
#'   cat("Running containers:\n")
#'   print(container_status)
#' } else {
#'   cat("No zzcollab containers currently running\n")
#' }
#' }
#' 
#' @seealso 
#' \code{\link{rebuild}} for rebuilding Docker images
#' \code{\link{team_images}} for listing available team images
#' 
#' @export
status <- function() {
  # Use Docker CLI to list containers with zzcollab label
  # --filter: only show containers with 'label=zzcollab'
  # --format: custom table format showing name, status, and image
  result <- system("docker ps --filter 'label=zzcollab' --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'", 
                   intern = TRUE)
  
  # If no containers found, inform user and return empty vector
  if (length(result) == 0) {
    message("No zzcollab containers running")
    return(character(0))
  }
  
  return(result)
}

#' Trigger Docker image rebuild for zzcollab projects
#'
#' Rebuilds Docker images for your zzcollab project using the project's Makefile.
#' This is useful when you've made changes to dependencies, Dockerfile, or need
#' to incorporate updates from team base images.
#'
#' @param target Character string specifying the Make target to run.
#'   Default is "docker-build" which rebuilds the main project image.
#'   Other useful targets include:
#'   - "docker-build": Rebuild main Docker image
#'   - "docker-test": Rebuild and run tests
#'   - "docker-check": Rebuild and run package checks
#'   - "docker-clean": Clean up Docker images and containers
#'
#' @return Logical value indicating success (TRUE) or failure (FALSE) of the build.
#'   The function returns TRUE if the make command exits with status 0,
#'   FALSE otherwise.
#'
#' @details
#' This function requires a Makefile to be present in the current working directory,
#' which is automatically created by zzcollab project initialization. The function
#' uses the system's make command to execute the specified target.
#'
#' Common use cases:
#' - After adding new R packages to your project
#' - When team base images have been updated
#' - After modifying Dockerfile or dependency files
#' - When containers are behaving unexpectedly
#'
#' @examples
#' \dontrun{
#' # Rebuild the main Docker image
#' if (rebuild()) {
#'   message("Docker image rebuilt successfully")
#' } else {
#'   message("Docker build failed - check console output")
#' }
#' 
#' # Rebuild and run tests
#' rebuild("docker-test")
#' 
#' # Clean up and rebuild
#' rebuild("docker-clean")
#' rebuild("docker-build")
#' }
#'
#' @seealso
#' \code{\link{status}} for checking container status
#' \code{\link{sync_env}} for syncing R package environment
#'
#' @export
rebuild <- function(target = "docker-build") {
  # Check if we're in a zzcollab project directory by looking for Makefile
  # The Makefile is created during project initialization and contains Docker targets
  if (!file.exists("Makefile")) {
    stop("No Makefile found. Are you in a zzcollab project directory?")
  }
  
  # Execute the make command with specified target
  # intern = TRUE captures output, attr(result, "status") contains exit code
  result <- system(paste("make", target), intern = TRUE)
  
  # Return TRUE if command succeeded (exit code 0), FALSE otherwise
  # The %||% operator provides fallback value if status attribute is NULL
  return(attr(result, "status") %||% 0 == 0)
}

#' List available zzcollab team Docker images
#'
#' Retrieves information about team Docker images that have been created for
#' zzcollab projects. Team images are base images that contain pre-installed
#' packages and configurations shared across team members.
#'
#' @return Data frame with columns:
#'   - \code{repository}: Docker repository name (e.g., "myteam/projectcore")
#'   - \code{tag}: Image tag (e.g., "latest", "v1.0.0")
#'   - \code{size}: Image size (e.g., "2.5GB")
#'   - \code{created}: Creation timestamp
#'   Returns empty data frame if no team images are found.
#'
#' @details
#' This function searches for Docker images with the 'zzcollab.team' label,
#' which is automatically applied to team base images created during project
#' initialization. Team images are typically named following the pattern:
#' teamname/projectnamecore-variant:tag
#'
#' Team images serve as the foundation for individual development environments,
#' ensuring all team members work with identical package versions and system
#' configurations.
#'
#' @examples
#' \dontrun{
#' # List all available team images
#' images <- team_images()
#' if (nrow(images) > 0) {
#'   print(images)
#' } else {
#'   cat("No team images available\n")
#' }
#' 
#' # Check for specific team's images
#' images <- team_images()
#' myteam_images <- images[grepl("myteam", images$repository), ]
#' print(myteam_images)
#' }
#'
#' @seealso
#' \code{\link{init_project}} for creating team images
#' \code{\link{status}} for checking running containers
#'
#' @export
team_images <- function() {
  # Query Docker for images with zzcollab.team label
  # This label is applied during team image creation
  # Format output as tab-separated values for easy parsing
  result <- system("docker images --filter 'label=zzcollab.team' --format '{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}'", 
                   intern = TRUE)
  
  # Handle case where no team images exist
  if (length(result) == 0) {
    message("No zzcollab team images found")
    return(data.frame())
  }
  
  # Parse the tab-separated output into a structured data frame
  # Each line contains: repository, tag, size, created_date
  lines <- strsplit(result, "\t")
  df <- data.frame(
    repository = sapply(lines, `[`, 1),  # Extract first column (repository)
    tag = sapply(lines, `[`, 2),         # Extract second column (tag)
    size = sapply(lines, `[`, 3),        # Extract third column (size)
    created = sapply(lines, `[`, 4),     # Extract fourth column (created)
    stringsAsFactors = FALSE             # Keep as character vectors
  )
  return(df)
}

#' Initialize a new zzcollab team project
#'
#' Creates a complete team research collaboration infrastructure including Docker
#' base images, GitHub repository, and project structure. This function is the
#' R interface to the \code{zzcollab --init} command and should be used by
#' team leads to set up new collaborative research projects.
#'
#' @param team_name Character string specifying the Docker Hub team/organization name.
#'   This becomes part of the Docker image names (e.g., "myteam/projectcore").
#'   If NULL, uses value from configuration file via \code{get_config("team_name")}.
#'   
#' @param project_name Character string specifying the project name.
#'   Used for Docker image names, GitHub repository, and directory names.
#'   Must be a valid Docker repository name (lowercase, no spaces).
#'   
#' @param github_account Character string specifying GitHub account for repository creation.
#'   If NULL, uses config default or falls back to \code{team_name}.
#'   Used with GitHub CLI to create private repositories.
#'   
#' @param dotfiles_path Character string specifying path to dotfiles directory.
#'   These files (.vimrc, .zshrc, etc.) are copied into Docker images for
#'   personalized development environments. If NULL, uses config default.
#'   
#' @param dotfiles_nodots Logical indicating whether dotfiles need leading dots added.
#'   Set to TRUE if your dotfiles are named without leading dots (e.g., "vimrc"
#'   instead of ".vimrc"). If NULL, uses config default.
#'   
#' @param build_mode Character string specifying package installation mode:
#'   - "fast": Minimal packages (~8) for quick setup and CI/CD
#'   - "standard": Balanced package set (~15) for typical research workflows
#'   - "comprehensive": Full ecosystem (~27+) for complex analyses
#'   If NULL, uses config default or "standard".
#'
#' @return Logical value indicating success (TRUE) or failure (FALSE) of the
#'   initialization process. The function creates multiple components, so
#'   partial failures may occur.
#'
#' @details
#' This function orchestrates the complete team project setup process:
#' 
#' 1. **Team Docker Images**: Creates and pushes base images to Docker Hub
#' 2. **Project Structure**: Generates R package structure with analysis templates
#' 3. **GitHub Repository**: Creates private repository with CI/CD workflows
#' 4. **Configuration Files**: Sets up Dockerfile, Makefile, and config files
#' 5. **Documentation**: Generates user guides and README files
#' 
#' The function integrates with the zzcollab configuration system, allowing
#' team leads to set default values once and reuse them across projects.
#' 
#' **Prerequisites:**
#' - Docker installed and running
#' - Docker Hub account for image hosting
#' - GitHub CLI authenticated (for repository creation)
#' - zzcollab installed in PATH or source directory
#'
#' **Team Workflow:**
#' - Team Lead: Runs \code{init_project()} once per project
#' - Team Members: Use \code{join_project()} to join existing projects
#'
#' @examples
#' \dontrun{
#' # Basic team project initialization
#' success <- init_project(
#'   team_name = "mylab",
#'   project_name = "covid-study"
#' )
#' 
#' # Full specification with all parameters
#' success <- init_project(
#'   team_name = "datascience",
#'   project_name = "market-analysis", 
#'   github_account = "myuniversity",
#'   dotfiles_path = "~/dotfiles",
#'   dotfiles_nodots = FALSE,
#'   build_mode = "comprehensive"
#' )
#' 
#' # Using configuration defaults (recommended workflow)
#' # First, set up your defaults
#' set_config("team_name", "mylab")
#' set_config("build_mode", "standard")
#' set_config("dotfiles_dir", "~/dotfiles")
#' 
#' # Then initialize projects easily
#' init_project(project_name = "new-study")
#' }
#'
#' @seealso
#' \code{\link{join_project}} for team members joining existing projects
#' \code{\link{set_config}} for setting up configuration defaults
#' \code{\link{team_images}} for listing created team images
#'
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