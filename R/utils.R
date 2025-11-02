# ZZCOLLAB R Interface Functions
# Provides R functions to interact with zzcollab Docker infrastructure

#' Null-coalescing operator
#'
#' @name grapes-or-or-grapes
#' @rdname grapes-or-or-grapes
#' @param lhs Left-hand side
#' @param rhs Right-hand side
#' @return lhs if not NULL, else rhs
#' @export
`%||%` <- function(lhs, rhs) {
  if (!is.null(lhs)) lhs else rhs
}

#' Validate Docker repository name format
#'
#' @param name Character string to validate
#' @param param_name Name of parameter for error messages
#' @return TRUE if valid, stops with error if invalid
#' @keywords internal
validate_docker_name <- function(name, param_name) {
  # Check type
  if (!is.character(name) || length(name) != 1) {
    stop(param_name, " must be a single character string", call. = FALSE)
  }

  # Check for empty string
  if (nchar(name) == 0) {
    stop(param_name, " cannot be empty", call. = FALSE)
  }

  # Docker repository name rules:
  # - Lowercase letters, numbers, dots, underscores, hyphens
  # - Cannot start with dot or hyphen
  # - Max 255 characters
  if (grepl("^[.-]", name)) {
    stop(param_name, " cannot start with a dot or hyphen", call. = FALSE)
  }

  if (grepl("[^a-z0-9._-]", name)) {
    stop(param_name, " must contain only lowercase letters, numbers, dots, underscores, and hyphens",
         call. = FALSE)
  }

  if (nchar(name) > 255) {
    stop(param_name, " must be 255 characters or less", call. = FALSE)
  }

  return(TRUE)
}

#' Validate and normalize file path
#'
#' @param path Character string path
#' @param param_name Name of parameter for error messages
#' @param must_exist Logical, whether path must exist
#' @return Normalized path
#' @keywords internal
validate_path <- function(path, param_name, must_exist = FALSE) {
  if (is.null(path)) {
    return(NULL)
  }

  if (!is.character(path) || length(path) != 1) {
    stop(param_name, " must be a single character string", call. = FALSE)
  }

  # Normalize path
  path <- normalizePath(path, mustWork = FALSE)

  if (must_exist && !file.exists(path)) {
    stop(param_name, " does not exist: ", path, call. = FALSE)
  }

  return(path)
}

#' Safe system call with error handling
#'
#' Wrapper around system() with comprehensive error handling via tryCatch.
#' Provides consistent error messages and behavior across all zzcollab functions.
#'
#' @param command Character string command to execute
#' @param intern Logical, capture output (default: FALSE)
#' @param ignore.stdout Logical, suppress stdout (default: FALSE)
#' @param ignore.stderr Logical, suppress stderr (default: FALSE)
#' @param error_msg Custom error message prefix (optional)
#' @return For intern=FALSE: exit status (0 for success)
#'         For intern=TRUE: character vector of output
#' @keywords internal
safe_system <- function(command, intern = FALSE, ignore.stdout = FALSE,
                        ignore.stderr = FALSE, error_msg = NULL) {
  tryCatch({
    result <- system(command, intern = intern,
                    ignore.stdout = ignore.stdout,
                    ignore.stderr = ignore.stderr)

    # Check exit status for non-intern calls
    if (!intern) {
      if (result != 0) {
        msg <- if (!is.null(error_msg)) {
          paste0(error_msg, " (exit code: ", result, ")")
        } else {
          paste0("Command failed with exit code ", result, ": ", command)
        }
        warning(msg, call. = FALSE)
      }
    }

    return(result)

  }, error = function(e) {
    msg <- if (!is.null(error_msg)) {
      paste0(error_msg, ": ", conditionMessage(e))
    } else {
      paste0("System command error: ", conditionMessage(e))
    }
    stop(msg, call. = FALSE)
  })
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
    test_result <- safe_system(paste(zzcollab_path, "--config list"),
                               ignore.stdout = TRUE, ignore.stderr = TRUE,
                               error_msg = "Failed to test zzcollab config support")
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
      test_result <- safe_system(paste(path, "--config list"),
                                 ignore.stdout = TRUE, ignore.stderr = TRUE,
                                 error_msg = "Failed to test zzcollab config support")
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
  result <- safe_system("docker ps --filter 'label=zzcollab' --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'",
                       intern = TRUE,
                       error_msg = "Failed to query Docker containers")

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
  result <- safe_system(paste("make", target), intern = TRUE,
                       error_msg = paste("Failed to execute make target:", target))

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
  result <- safe_system("docker images --filter 'label=zzcollab.team' --format '{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}'",
                       intern = TRUE,
                       error_msg = "Failed to query Docker images")

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
#'   dotfiles_nodots = FALSE
#' )
#'
#' # Using configuration defaults (recommended workflow)
#' # First, set up your defaults
#' set_config("team_name", "mylab")
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
                         dotfiles_nodots = NULL) {

  # Validate ALL explicitly-provided parameters FIRST (before getting config defaults)
  # This allows tests to validate error messages without needing zzcollab script
  if (is.null(project_name)) {
    stop("project_name is required", call. = FALSE)
  }
  validate_docker_name(project_name, "project_name")

  if (!is.null(team_name)) {
    validate_docker_name(team_name, "team_name")
  }

  if (!is.null(github_account)) {
    validate_docker_name(github_account, "github_account")
  }

  # Now apply config defaults for missing parameters
  team_name <- team_name %||% get_config_default("team_name")
  github_account <- github_account %||% get_config_default("github_account") %||% team_name
  dotfiles_path <- dotfiles_path %||% get_config_default("dotfiles_dir")
  dotfiles_nodots <- dotfiles_nodots %||% (get_config_default("dotfiles_nodot", "false") == "true")

  # Validate team_name is set (either passed or from config)
  if (is.null(team_name)) {
    stop("team_name is required. Set via parameter or config: set_config('team_name', 'myteam')",
         call. = FALSE)
  }

  # Validate and normalize paths
  dotfiles_path <- validate_path(dotfiles_path, "dotfiles_path", must_exist = FALSE)

  # Validate logical parameters
  if (!is.null(dotfiles_nodots) && !is.logical(dotfiles_nodots)) {
    stop("dotfiles_nodots must be TRUE or FALSE", call. = FALSE)
  }
  
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  # Build command with team and project flags
  cmd <- paste(zzcollab_path, "-t", team_name, "-p", project_name)
  
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

  message("Running: ", cmd)
  result <- safe_system(cmd, error_msg = "Failed to initialize project")
  return(result == 0)
}

#' Join an existing zzcollab team project
#'
#' Allows team members (Developers 2+) to join an existing zzcollab project by
#' setting up their local development environment using the team's shared Docker
#' images and project structure. This function is the R interface to team
#' collaboration workflows.
#'
#' @param team_name Character string specifying the Docker Hub team/organization name.
#'   This should match the team name used when the project was initialized.
#'   If NULL, uses value from configuration file via \code{get_config("team_name")}.
#'   
#' @param project_name Character string specifying the project name.
#'   Must match the project name used during initialization.
#'   Used to identify the correct team Docker images and repository.
#'
#' @param dotfiles_path Character string specifying path to personal dotfiles.
#'   These configuration files (.vimrc, .zshrc, etc.) personalize your
#'   development environment within the team's standardized setup.
#'   If NULL, uses config default.
#'   
#' @param dotfiles_nodots Logical indicating whether dotfiles need leading dots added.
#'   Set to TRUE if your dotfiles are stored without leading dots.
#'   If NULL, uses config default.
#'
#' @return Logical value indicating success (TRUE) or failure (FALSE).
#'   The function validates team images exist before proceeding with setup.
#'
#' @details
#' This function is designed for team members joining existing projects.
#' The team lead should have already run \code{init_project()} to create
#' the necessary team infrastructure.
#' 
#' **Setup Process:**
#' 1. **Validation**: Checks that team Docker images exist and are accessible
#' 2. **Project Setup**: Creates local project structure and configuration
#' 3. **Environment**: Configures to use team's Docker image via --use-team-image
#' 4. **Integration**: Configures local tools and personal dotfiles
#'
#' **Prerequisites:**
#' - Team lead has run \code{init_project()} and shared repository access
#' - Docker installed and running locally
#' - Access to team's Docker images (usually public on Docker Hub)
#' - Git repository cloned locally (typically done before calling this function)
#'
#' **Development Workflow:**
#' After joining, start development with \code{make docker-zsh} (shell) or
#' \code{make docker-rstudio} (RStudio Server at http://localhost:8787).
#'
#' @examples
#' \dontrun{
#' # Basic team project joining
#' success <- join_project(
#'   team_name = "mylab",
#'   project_name = "covid-study"
#' )
#'
#' # Join with personal dotfiles
#' join_project(
#'   team_name = "datascience",
#'   project_name = "market-analysis",
#'   dotfiles_path = "~/dotfiles"
#' )
#'
#' # Using configuration defaults (recommended)
#' set_config("team_name", "mylab")
#' set_config("dotfiles_dir", "~/dotfiles")
#'
#' # Then join projects easily
#' join_project(project_name = "new-study")
#'
#' # Complete workflow for team member
#' # 1. Clone repository (outside R)
#' # system("git clone https://github.com/mylab/study.git")
#' # setwd("study")
#'
#' # 2. Join project
#' join_project(team_name = "mylab", project_name = "study")
#'
#' # 3. Start development (outside R)
#' # system("make docker-zsh")  # or make docker-rstudio
#' }
#'
#' @seealso
#' \code{\link{init_project}} for team leads initializing projects
#' \code{\link{set_config}} for setting up configuration defaults
#' \code{\link{team_images}} for checking available team images
#'
#' @export
join_project <- function(team_name = NULL, project_name = NULL,
                         dotfiles_path = NULL, dotfiles_nodots = NULL) {

  # Validate ALL explicitly-provided parameters FIRST (before getting config defaults)
  # This allows tests to validate error messages without needing zzcollab script
  if (is.null(project_name)) {
    stop("project_name is required", call. = FALSE)
  }
  validate_docker_name(project_name, "project_name")

  if (!is.null(team_name)) {
    validate_docker_name(team_name, "team_name")
  }

  # Now apply config defaults for missing parameters
  team_name <- team_name %||% get_config_default("team_name")
  dotfiles_path <- dotfiles_path %||% get_config_default("dotfiles_dir")
  dotfiles_nodots <- dotfiles_nodots %||% (get_config_default("dotfiles_nodot", "false") == "true")

  # Validate team_name is set (either passed or from config)
  if (is.null(team_name)) {
    stop("team_name is required. Set via parameter or config: set_config('team_name', 'myteam')",
         call. = FALSE)
  }

  # Validate and normalize paths
  dotfiles_path <- validate_path(dotfiles_path, "dotfiles_path", must_exist = FALSE)

  # Validate logical parameters
  if (!is.null(dotfiles_nodots) && !is.logical(dotfiles_nodots)) {
    stop("dotfiles_nodots must be TRUE or FALSE", call. = FALSE)
  }

  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  # Build command using --use-team-image flag
  cmd <- paste(zzcollab_path, "-t", team_name, "-p", project_name, "--use-team-image")
  
  if (!is.null(dotfiles_path)) {
    if (dotfiles_nodots) {
      cmd <- paste(cmd, "--dotfiles-nodot", shQuote(dotfiles_path))
    } else {
      cmd <- paste(cmd, "--dotfiles", shQuote(dotfiles_path))
    }
  }

  message("Running: ", cmd)
  result <- safe_system(cmd, error_msg = "Failed to join project")
  return(result == 0)
}

#' Add R package to renv
#'
#' @param packages Character vector of package names
#' @param update_snapshot Logical, update renv.lock after installation
#' @return Logical indicating success
#' @importFrom utils install.packages
#' @export
add_package <- function(packages, update_snapshot = TRUE) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    stop("renv package is required for this function")
  }

  # Install packages
  for (pkg in packages) {
    message("Installing package: ", pkg)
    utils::install.packages(pkg)
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
  result <- safe_system("make docker-check-renv", intern = TRUE,
                       error_msg = "Failed to check renv status")
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
  result <- safe_system(cmd, error_msg = paste("Failed to run script:", script_path))
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
  result <- safe_system(cmd, error_msg = "Failed to render report")
  return(result == 0)
}

#' Check reproducibility
#'
#' @return Logical indicating if environment is reproducible
#' @export
validate_repro <- function() {
  scripts_to_check <- c(
    "scripts/99_reproducibility_check.R",
    "validate_package_environment.R",
    "check_rprofile_options.R"
  )
  
  all_passed <- TRUE
  
  for (script in scripts_to_check) {
    if (file.exists(script)) {
      message("Running reproducibility check: ", script)
      result <- safe_system(paste("Rscript", script), intern = TRUE,
                           error_msg = paste("Failed to run reproducibility check:", script))
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
    message("\u2705 All reproducibility checks passed")
  } else {
    message("\u274c Some reproducibility checks failed")
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
    result1 <- safe_system("git add .", error_msg = "Failed to add files to git")
    if (result1 != 0) {
      stop("Failed to add files to git")
    }
  }

  # Create commit with proper formatting
  commit_cmd <- sprintf('git commit -m "%s"', message)
  result2 <- safe_system(commit_cmd, error_msg = "Failed to create git commit")

  if (result2 == 0) {
    message("\u2705 Commit created: ", message)
    return(TRUE)
  } else {
    message("\u274c Commit failed")
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

  result <- safe_system(cmd, error_msg = "Failed to push to GitHub")

  if (result == 0) {
    message("\u2705 Successfully pushed to GitHub")
    return(TRUE)
  } else {
    message("\u274c Push failed")
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
    if (safe_system("which gh", ignore.stdout = TRUE, ignore.stderr = TRUE,
                   error_msg = "GitHub CLI check failed") != 0) {
      stop("GitHub CLI (gh) is required. Install with: brew install gh")
    }
  }

  cmd <- paste("gh pr create --title", shQuote(title), "--base", base)

  if (!is.null(body)) {
    cmd <- paste(cmd, "--body", shQuote(body))
  }

  result <- safe_system(cmd, error_msg = "Failed to create pull request")

  if (result == 0) {
    message("\u2705 Pull request created successfully")
    return(TRUE)
  } else {
    message("\u274c Failed to create pull request")
    return(FALSE)
  }
}

#' Check git status
#'
#' @return Character vector with git status output
#' @export
git_status <- function() {
  result <- safe_system("git status --porcelain", intern = TRUE,
                       error_msg = "Failed to check git status")

  if (length(result) == 0) {
    message("\u2705 Working directory clean")
    return(character(0))
  } else {
    message("\ud83d\udcdd Changes detected:")
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
  safe_system("git checkout main", ignore.stdout = TRUE,
             error_msg = "Failed to checkout main branch")
  safe_system("git pull", ignore.stdout = TRUE,
             error_msg = "Failed to pull latest changes")

  # Create and checkout new branch
  result <- safe_system(paste("git checkout -b", branch_name),
                       error_msg = paste("Failed to create branch:", branch_name))

  if (result == 0) {
    message("\u2705 Created and switched to branch: ", branch_name)
    return(TRUE)
  } else {
    message("\u274c Failed to create branch: ", branch_name)
    return(FALSE)
  }
}

#' Setup zzcollab project (standard setup, non-init mode)
#'
#' @param dotfiles_path Path to dotfiles directory (uses config default if NULL)
#' @param dotfiles_nodots Logical, if TRUE dotfiles need dots added (uses config default)
#' @param base_image Base Docker image to use (optional)
#' @return Logical indicating success
#' @export
setup_project <- function(dotfiles_path = NULL, dotfiles_nodots = NULL,
                         base_image = NULL) {

  # Apply config defaults for missing parameters
  dotfiles_path <- dotfiles_path %||% get_config_default("dotfiles_dir")
  dotfiles_nodots <- dotfiles_nodots %||% (get_config_default("dotfiles_nodot", "false") == "true")

  # Validate and normalize paths
  dotfiles_path <- validate_path(dotfiles_path, "dotfiles_path", must_exist = FALSE)

  # Validate logical parameters
  if (!is.null(dotfiles_nodots) && !is.logical(dotfiles_nodots)) {
    stop("dotfiles_nodots must be TRUE or FALSE", call. = FALSE)
  }

  # Validate base_image if provided
  if (!is.null(base_image)) {
    if (!is.character(base_image) || length(base_image) != 1) {
      stop("base_image must be a single character string", call. = FALSE)
    }
    # Allow Docker image format: owner/image or owner/image:tag
    if (!grepl("^[a-z0-9._-]+/[a-z0-9._-]+(:[a-z0-9._-]+)?$", base_image)) {
      stop("base_image must be in format 'owner/image' or 'owner/image:tag'", call. = FALSE)
    }
  }

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

  message("Running: ", cmd)
  result <- safe_system(cmd, error_msg = "Failed to setup project")
  return(result == 0)
}

#' Get zzcollab help
#'
#' Displays help documentation for zzcollab. Can show general help or specialized
#' help pages covering specific topics like configuration, workflows, Docker, and more.
#'
#' @param topic Character string specifying which help page to display.
#'   Options include:
#'   - NULL or "general": Main help with all command-line options (default)
#'   - "init": Team initialization help
#'   - "quickstart": Individual researcher quick start guide
#'   - "workflow": Daily development workflow
#'   - "troubleshooting": Top 10 common issues and solutions
#'   - "config": Configuration system guide
#'   - "dotfiles": Dotfiles setup and management
#'   - "renv": Package management with renv
#'   - "docker": Docker essentials for researchers
#'   - "cicd": CI/CD and GitHub Actions
#'   - "github": GitHub integration and automation
#'   - "next-steps": Development workflow guidance
#'
#' @return Character vector with help text, or invisible NULL if displayed via pager.
#'   The help text is formatted with ANSI colors for terminal display.
#'
#' @details
#' This function provides access to zzcollab's comprehensive help system directly
#' from R. Each help page is designed to be accessible to researchers without
#' extensive DevOps knowledge, focusing on practical workflows and examples.
#'
#' The help pages are displayed using your system's pager (usually 'less') when
#' running interactively, allowing easy navigation of longer help content.
#'
#' @examples
#' \dontrun{
#' # Display main help
#' zzcollab_help()
#'
#' # Get quick start guide for individual researchers
#' zzcollab_help("quickstart")
#'
#' # Learn about configuration system
#' zzcollab_help("config")
#'
#' # Troubleshooting common issues
#' zzcollab_help("troubleshooting")
#'
#' # Docker basics for researchers
#' zzcollab_help("docker")
#' }
#'
#' @seealso
#' \code{\link{zzcollab_next_steps}} for development workflow guidance
#' \code{\link{list_config}} for viewing current configuration
#'
#' @export
zzcollab_help <- function(topic = NULL) {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  # Valid help topics
  valid_topics <- c("general", "init", "quickstart", "workflow", "troubleshooting",
                    "config", "dotfiles", "renv", "docker", "cicd", "github", "next-steps")

  # Build command with topic argument
  if (is.null(topic) || topic == "general") {
    cmd <- paste(zzcollab_path, "--help")
  } else if (topic == "next-steps") {
    cmd <- paste(zzcollab_path, "--next-steps")
  } else if (topic %in% valid_topics) {
    cmd <- paste(zzcollab_path, "--help", topic)
  } else {
    stop("Unknown help topic: ", topic, "\n",
         "Valid topics: ", paste(valid_topics, collapse = ", "))
  }

  result <- safe_system(cmd, intern = TRUE,
                       error_msg = "Failed to retrieve zzcollab help")
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
  result <- safe_system(cmd, intern = TRUE,
                       error_msg = "Failed to retrieve next steps information")
  return(result)
}

#=============================================================================
# CONFIGURATION SYSTEM R INTERFACE
#=============================================================================

#' Get configuration value from zzcollab configuration system
#'
#' Retrieves configuration values from the zzcollab configuration hierarchy.
#' The system uses a three-tier configuration system with priority order:
#' project-level (./zzcollab.yaml) > user-level (~/.zzcollab/config.yaml) > system-level (/etc/zzcollab/config.yaml).
#'
#' @param key Character string specifying the configuration key to retrieve.
#'   Common keys include:
#'   - "team_name": Docker Hub team/organization name
#'   - "profile_name": Docker profile ("minimal", "analysis", "bioinformatics", "geospatial", etc.)
#'   - "dotfiles_dir": Path to personal dotfiles directory
#'   - "github_account": GitHub account for repository creation
#'   - "dotfiles_nodot": Whether dotfiles need leading dots added ("true"/"false")
#'   
#' @return Character string with the configuration value, or NULL if the key is not set
#'   in any configuration file. Returns the highest priority value if the key exists
#'   in multiple configuration files.
#'   
#' @details
#' The function interfaces with the zzcollab shell script's configuration system,
#' which manages YAML configuration files across project, user, and system levels.
#' This provides consistent configuration management between R and shell interfaces.
#' 
#' Configuration precedence (highest to lowest):
#' 1. Project-level: ./zzcollab.yaml (project-specific overrides)
#' 2. User-level: ~/.zzcollab/config.yaml (personal defaults)
#' 3. System-level: /etc/zzcollab/config.yaml (system-wide defaults)
#'
#' @examples
#' \dontrun{
#' # Get current team name
#' team <- get_config("team_name")
#' if (!is.null(team)) {
#'   cat("Current team:", team, "\n")
#' } else {
#'   cat("No team name configured\n")
#' }
#' 
#' # Check Docker profile setting
#' profile <- get_config("profile_name")
#' cat("Docker profile:", profile %||% "minimal", "\n")
#' 
#' # Get dotfiles directory with fallback
#' dotfiles <- get_config("dotfiles_dir") %||% "~/dotfiles"
#' }
#'
#' @seealso
#' \code{\link{set_config}} for setting configuration values
#' \code{\link{list_config}} for viewing all configuration
#' \code{\link{get_config_default}} for configuration with defaults
#'
#' @export
get_config <- function(key) {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  cmd <- paste(zzcollab_path, "--config get", key)
  result <- safe_system(cmd, intern = TRUE,
                       error_msg = paste("Failed to get config value:", key))

  if (length(result) > 0 && !grepl("\\(not set\\)", result[1])) {
    return(result[1])
  } else {
    return(NULL)
  }
}

#' Set configuration value in zzcollab configuration system
#'
#' Sets or updates configuration values in the zzcollab user-level configuration file.
#' This function writes to ~/.zzcollab/config.yaml, creating the directory and file
#' if they don't exist. Configuration values set here become defaults for future
#' zzcollab operations.
#'
#' @param key Character string specifying the configuration key to set.
#'   Recommended keys include:
#'   - "team_name": Your Docker Hub team/organization name
#'   - "profile_name": Docker profile ("minimal", "analysis", "bioinformatics", "geospatial", etc.)
#'   - "dotfiles_dir": Path to your personal dotfiles directory
#'   - "github_account": Your GitHub account for repository creation
#'   - "dotfiles_nodot": Whether your dotfiles need leading dots ("true"/"false")
#'   
#' @param value Character string specifying the configuration value to set.
#'   The value will be stored as a string in the YAML configuration file.
#'   Boolean values should be passed as "true" or "false" strings.
#'   
#' @return Logical value indicating success (TRUE) or failure (FALSE) of the
#'   configuration operation. Returns FALSE if the zzcollab script cannot be
#'   found or if the configuration write operation fails.
#'   
#' @details
#' This function provides a convenient R interface to the zzcollab configuration
#' system. It's particularly useful for setting up your personal defaults once,
#' then using them across multiple projects without repeatedly specifying the
#' same parameters.
#' 
#' The function creates the ~/.zzcollab directory if it doesn't exist and
#' initializes a default config.yaml file. Values are stored in YAML format
#' for easy editing and cross-platform compatibility.
#' 
#' **Configuration Strategy:**
#' - Set personal defaults once using this function
#' - Use project-specific settings in ./zzcollab.yaml for project overrides
#' - Let the hierarchy system handle precedence automatically
#'
#' @examples
#' \dontrun{
#' # Set up your personal defaults (run once)
#' set_config("team_name", "mylab")
#' set_config("profile_name", "analysis")
#' set_config("dotfiles_dir", "~/dotfiles")
#' set_config("github_account", "myuniversity")
#' 
#' # Check if configuration was successful
#' if (set_config("team_name", "newteam")) {
#'   cat("Team name updated successfully\n")
#' } else {
#'   cat("Failed to update configuration\n")
#' }
#' 
#' # Configure dotfiles preferences
#' set_config("dotfiles_nodot", "false")  # Files already have leading dots
#' }
#'
#' @seealso
#' \code{\link{get_config}} for retrieving configuration values
#' \code{\link{list_config}} for viewing all current configuration
#' \code{\link{init_config}} for initializing default configuration
#'
#' @export
set_config <- function(key, value) {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  cmd <- paste(zzcollab_path, "--config set", key, shQuote(value))
  result <- safe_system(cmd, error_msg = paste("Failed to set config value:", key))
  return(result == 0)
}

#' List all configuration values from zzcollab configuration system
#'
#' Displays all configuration values from the zzcollab configuration hierarchy,
#' showing the effective configuration that would be used for zzcollab operations.
#' This includes values from project, user, and system configuration files with
#' proper precedence resolution.
#'
#' @return Character vector containing the formatted configuration listing.
#'   Each element represents a configuration key-value pair in the format
#'   "key: value". The output shows the effective configuration after resolving
#'   the hierarchy of project > user > system configuration files.
#'   Returns empty character vector if no configuration is found.
#'   
#' @details
#' This function provides a comprehensive view of your zzcollab configuration,
#' making it easy to understand what settings are active and where they come from.
#' It's particularly useful for:
#' 
#' - **Debugging configuration issues**: See exactly what values are being used
#' - **Understanding precedence**: See which configuration level is providing each value
#' - **Setup verification**: Confirm your configuration changes took effect
#' - **Team coordination**: Share configuration examples with team members
#' 
#' The output format is human-readable and suitable for documentation or
#' sharing configuration examples with team members.
#'
#' @examples
#' \dontrun{
#' # View all current configuration
#' config <- list_config()
#' cat("Current zzcollab configuration:\n")
#' cat(paste(config, collapse = "\n"), "\n")
#' 
#' # Check if specific keys are configured
#' config <- list_config()
#' if (any(grepl("team_name:", config))) {
#'   cat("Team name is configured\n")
#' } else {
#'   cat("Team name needs to be set\n")
#' }
#' 
#' # Save configuration for documentation
#' config <- list_config()
#' writeLines(config, "my-zzcollab-config.txt")
#' }
#'
#' @seealso
#' \code{\link{get_config}} for retrieving specific configuration values
#' \code{\link{set_config}} for setting configuration values
#' \code{\link{validate_config}} for validating configuration files
#'
#' @export
list_config <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  cmd <- paste(zzcollab_path, "--config list")
  result <- safe_system(cmd, intern = TRUE,
                       error_msg = "Failed to list configuration")
  return(result)
}

#' Validate zzcollab configuration files
#'
#' Performs comprehensive validation of all zzcollab configuration files in the
#' configuration hierarchy, checking for syntax errors, invalid values, and
#' structural problems. This helps ensure your configuration is valid before
#' running zzcollab operations.
#'
#' @return Logical value indicating whether all configuration files are valid (TRUE)
#'   or if validation errors were found (FALSE). Returns TRUE if all configuration
#'   files that exist are syntactically correct and contain valid values.
#'   Missing configuration files are not considered errors.
#'   
#' @details
#' The validation process checks multiple aspects of configuration files:
#' 
#' **Syntax Validation:**
#' - YAML syntax correctness in all configuration files
#' - Proper key-value structure and indentation
#' - No duplicate keys or invalid characters
#' 
#' **Value Validation:**
#' - Build mode values are one of: "minimal", "fast", "standard", "comprehensive"
#' - Boolean values are properly formatted as "true" or "false"
#' - Path values are syntactically valid (though may not exist)
#' 
#' **File Structure:**
#' - Configuration directory permissions and accessibility
#' - File permissions for reading and writing
#' - Backup file integrity (*.backup files)
#' 
#' This function is particularly useful for:
#' - **Pre-flight checks**: Validate configuration before important operations
#' - **Troubleshooting**: Identify configuration problems causing failures
#' - **Setup verification**: Confirm configuration files are properly structured
#' - **CI/CD pipelines**: Automated validation of configuration in workflows
#'
#' @examples
#' \dontrun{
#' # Validate configuration before important operations
#' if (validate_config()) {
#'   cat("Configuration is valid, proceeding...\n")
#'   init_project(project_name = "my-study")
#' } else {
#'   cat("Configuration has errors, please fix before proceeding\n")
#'   list_config()  # Show current config for debugging
#' }
#' 
#' # Use in automated workflows
#' validate_config() || stop("Invalid zzcollab configuration")
#' 
#' # Validation after making changes
#' set_config("profile_name", "publishing")
#' if (!validate_config()) {
#'   warning("Configuration may have issues")
#' }
#' }
#'
#' @seealso
#' \code{\link{list_config}} for viewing current configuration
#' \code{\link{init_config}} for initializing default configuration
#' \code{\link{set_config}} for setting configuration values
#'
#' @export
validate_config <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  cmd <- paste(zzcollab_path, "--config validate")
  result <- safe_system(cmd, error_msg = "Failed to validate configuration")
  return(result == 0)
}

#' Initialize default zzcollab configuration file
#'
#' Creates a default zzcollab configuration file in the user's home directory
#' (~/.zzcollab/config.yaml) with template values and helpful comments. This
#' function sets up the foundation for personalized zzcollab configuration.
#'
#' @return Logical value indicating success (TRUE) or failure (FALSE) of the
#'   initialization process. Returns TRUE if the configuration directory and
#'   file were created successfully, FALSE if there were permission issues
#'   or other errors during creation.
#' 
#' @details
#' This function creates the complete zzcollab user configuration infrastructure:
#' 
#' **Directory Creation:**
#' - Creates ~/.zzcollab directory if it doesn't exist
#' - Sets appropriate permissions for security
#' - Creates any necessary parent directories
#' 
#' **Configuration File:**
#' - Creates ~/.zzcollab/config.yaml with template structure
#' - Includes helpful comments explaining each configuration option
#' - Sets reasonable default values where appropriate
#' - Uses YAML format for human readability and easy editing
#' 
#' **Template Content Includes:**
#' - team_name: (empty, to be filled by user)
#' - profile_name: "analysis" (balanced default)
#' - dotfiles_dir: (empty, commonly ~/dotfiles)
#' - github_account: (empty, for repository creation)
#' - dotfiles_nodot: "false" (assumes dotfiles have leading dots)
#' 
#' This function is typically run once per system to establish your personal
#' zzcollab configuration. After initialization, use \code{set_config()} to
#' set your specific values.
#'
#' @examples
#' \dontrun{
#' # Initialize configuration (typically run once)
#' if (init_config()) {
#'   cat("Configuration initialized successfully\n")
#'   cat("Edit ~/.zzcollab/config.yaml to set your preferences\n")
#' } else {
#'   cat("Failed to initialize configuration\n")
#' }
#' 
#' # Complete setup workflow
#' init_config()  # Create template
#' set_config("team_name", "mylab")  # Set your values
#' set_config("dotfiles_dir", "~/dotfiles")
#' validate_config()  # Verify everything is correct
#' 
#' # Check if initialization is needed
#' if (is.null(get_config("team_name"))) {
#'   cat("Consider running init_config() to set up defaults\n")
#' }
#' }
#'
#' @seealso
#' \code{\link{set_config}} for setting configuration values after initialization
#' \code{\link{list_config}} for viewing the initialized configuration
#' \code{\link{validate_config}} for validating the configuration file
#'
#' @export
init_config <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  cmd <- paste(zzcollab_path, "--config init")
  result <- safe_system(cmd, error_msg = "Failed to initialize configuration")
  return(result == 0)
}

#' Get configuration value with fallback default
#'
#' Retrieves a configuration value from the zzcollab configuration system,
#' returning a specified default value if the configuration key is not set.
#' This function provides a convenient way to handle optional configuration
#' with sensible fallbacks.
#'
#' @param key Character string specifying the configuration key to retrieve.
#'   Should match keys used in the zzcollab configuration system (e.g.,
#'   \"team_name\", \"profile_name\", \"dotfiles_dir\").
#'   
#' @param default Default value to return if the configuration key is not set
#'   or if \code{get_config()} returns NULL. Can be any type, but typically
#'   a character string to match configuration values. Default is NULL.
#'   
#' @return The configuration value if set, otherwise the default value.
#'   The return type matches the type of the configuration value or default.
#'   
#' @details
#' This internal function implements the \"null-coalescing\" pattern commonly
#' used throughout zzcollab for configuration management. It provides a clean
#' way to specify fallback values when configuration keys might not be set.
#' 
#' The function is particularly useful in other zzcollab functions that need
#' to handle optional configuration parameters gracefully. It eliminates the
#' need for repeated NULL checking and provides consistent behavior across
#' the codebase.
#' 
#' **Usage Pattern:**
#' This function is typically used internally by other zzcollab functions
#' to provide sensible defaults when users haven't configured specific values.
#'
#' @examples
#' \dontrun{
#' # Internal usage pattern in zzcollab functions
#' team_name <- get_config_default(\"team_name\", \"defaultteam\")
#' profile_name <- get_config_default(\"profile_name\", \"analysis\")
#' 
#' # Equivalent to using the %||% operator
#' team_name <- get_config(\"team_name\") %||% \"defaultteam\"
#' 
#' # Common usage with multiple fallbacks
#' dotfiles_path <- get_config_default(\"dotfiles_dir\", \"~/dotfiles\")
#' github_account <- get_config_default(\"github_account\", team_name)
#' }
#'
#' @seealso
#' \code{\link{get_config}} for basic configuration retrieval
#' \code{\link{\%||\%}} for the null-coalescing operator used internally
#'
#' @keywords internal
get_config_default <- function(key, default = NULL) {
  config_value <- get_config(key)
  if (!is.null(config_value)) {
    return(config_value)
  } else {
    return(default)
  }
}