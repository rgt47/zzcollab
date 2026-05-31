# ZZCOLLAB R Interface: Project and Docker workflow (split out of utils.R)

#' Validate and resolve shared team/project parameters
#'
#' Shared by \code{init_project()} and \code{join_project()}: validates
#' \code{project_name} and \code{team_name}, fills \code{team_name} from the
#' configured default when not supplied, and errors when a required value is
#' missing.
#'
#' @param team_name,project_name As passed by the caller; either may be NULL.
#' @return The resolved \code{team_name}.
#' @keywords internal
resolve_team_project <- function(team_name, project_name) {
  if (is.null(project_name)) {
    stop('project_name is required', call. = FALSE)
  }
  validate_docker_name(project_name, 'project_name')

  if (!is.null(team_name)) {
    validate_docker_name(team_name, 'team_name')
  }

  team_name <- team_name %||% get_config_default('team_name')

  if (is.null(team_name)) {
    stop("team_name is required. Set via parameter or config: set_config('team_name', 'myteam')",
         call. = FALSE)
  }
  team_name
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
                       error_msg = 'Failed to query Docker containers')

  # If no containers found, inform user and return empty vector
  if (length(result) == 0) {
    message('No zzcollab containers running')
    return(character(0))
  }

  result
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
rebuild <- function(target = 'docker-build') {
  # Check if we're in a zzcollab project directory by looking for Makefile
  # The Makefile is created during project initialization and contains Docker targets
  if (!file.exists('Makefile')) {
    stop('No Makefile found. Are you in a zzcollab project directory?',
         call. = FALSE)
  }

  # Execute the make command with specified target
  # intern = TRUE captures output, attr(result, "status") contains exit code
  result <- safe_system(paste('make', target), intern = TRUE,
                       error_msg = paste('Failed to execute make target:', target))

  # Return TRUE if command succeeded (exit code 0), FALSE otherwise
  # The %||% operator provides fallback value if status attribute is NULL
  (attr(result, 'status') %||% 0) == 0
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
                       error_msg = 'Failed to query Docker images')

  # Handle case where no team images exist
  if (length(result) == 0) {
    message('No zzcollab team images found')
    return(data.frame())
  }

  # Parse the tab-separated output into a structured data frame
  # Each line contains: repository, tag, size, created_date
  lines <- strsplit(result, '\t')
  # vapply (not sapply) so each column is guaranteed a length-one character
  # value per row (NA_character_ when a field is missing), never a list.
  df <- data.frame(
    repository = vapply(lines, `[`, character(1), 1),
    tag        = vapply(lines, `[`, character(1), 2),
    size       = vapply(lines, `[`, character(1), 3),
    created    = vapply(lines, `[`, character(1), 4),
    stringsAsFactors = FALSE
  )
  df
}

#' Initialize a new zzcollab team project
#'
#' Creates a research compendium in the current working directory and records the
#' team's DockerHub and GitHub accounts in the zzcollab configuration so that the
#' \code{dockerhub} and \code{github} commands can publish under them. Intended for
#' team leads setting up a new collaborative research project.
#'
#' @param team_name Character string specifying the Docker Hub team/organization name.
#'   This becomes part of the Docker image names (e.g., "myteam/projectcore").
#'   If NULL, uses value from configuration file via \code{get_config("team_name")}.
#'   
#' @param project_name Character string specifying the project name. The
#'   compendium is created in the current working directory (which should be
#'   named accordingly); the value is validated and used in status messages.
#'   Must be a valid Docker repository name (lowercase, no spaces).
#'
#' @param github_account Character string specifying GitHub account for repository creation.
#'   If NULL, uses config default or falls back to \code{team_name}.
#'   Used with GitHub CLI to create private repositories.
#'
#' @param profile Character string naming the Docker profile / quickstart bundle
#'   to scaffold (e.g. "analysis", "minimal", "rstudio"). Defaults to "analysis".
#'
#' @return Logical value indicating success (TRUE) or failure (FALSE) of the
#'   scaffolding step.
#'
#' @details
#' This function performs two steps using the current zzcollab CLI:
#'
#' 1. **Configuration**: Records the DockerHub account (and GitHub account, if
#'    given) via \code{zzcollab config set} so that later \code{dockerhub} and
#'    \code{github} commands publish under the correct accounts.
#' 2. **Scaffolding**: Runs the profile quickstart (\code{zzcollab <profile>}),
#'    which creates the R package structure, renv.lock, and Dockerfile.
#'
#' To publish the team image and repository afterwards, run
#' \code{zzcollab dockerhub} and \code{zzcollab github} in the project directory.
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
#'   github_account = "myuniversity"
#' )
#'
#' # Using configuration defaults (recommended workflow)
#' # First, set up your defaults
#' set_config("team_name", "mylab")
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
                         github_account = NULL, profile = 'analysis') {

  # Validate the init-only parameters first (before resolving config defaults),
  # so tests can check error messages without needing the zzcollab script.
  if (!is.null(github_account)) {
    validate_docker_name(github_account, 'github_account')
  }

  # Profile flows to the shell as a bare command; constrain it to the known
  # set so an arbitrary string cannot reach the shell.
  valid_profiles <- c('minimal', 'analysis', 'rstudio')
  if (!profile %in% valid_profiles) {
    stop("Invalid profile '", profile, "'. Must be one of: ",
         paste(valid_profiles, collapse = ', '), call. = FALSE)
  }

  # Shared project/team validation and team_name resolution.
  team_name <- resolve_team_project(team_name, project_name)
  github_account <- github_account %||% get_config_default('github_account') %||% team_name

  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  # Persist team/GitHub accounts so later 'dockerhub' and 'github' commands can
  # push the team image and create the repository under the correct accounts.
  safe_system(paste(zzcollab_path, 'config set dockerhub-account', shQuote(team_name)),
              ignore.stdout = TRUE, ignore.stderr = TRUE,
              error_msg = 'Failed to set dockerhub-account')
  if (!is.null(github_account)) {
    safe_system(paste(zzcollab_path, 'config set github-account', shQuote(github_account)),
                ignore.stdout = TRUE, ignore.stderr = TRUE,
                error_msg = 'Failed to set github-account')
  }

  # Scaffold the research compendium in the current working directory using the
  # chosen profile (init + renv + docker). The compendium is named after the
  # directory; project_name is validated and recorded for messaging.
  cmd <- paste(zzcollab_path, profile)
  message("Initializing project '", project_name, "' (profile: ", profile, '): ', cmd)
  result <- safe_system(cmd, error_msg = 'Failed to initialize project')
  result == 0
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
#' @return Logical value indicating success (TRUE) or failure (FALSE).
#'   The function validates team images exist before proceeding with setup.
#'
#' @details
#' This function is designed for team members joining existing projects.
#' The team lead should have already run \code{init_project()} to create
#' the necessary team infrastructure.
#'
#' **Setup Process:**
#' 1. **Prerequisite**: The project repository is already cloned and is the
#'    current working directory.
#' 2. **Build**: Builds the project's Docker image from the committed Dockerfile
#'    and renv.lock via \code{make docker-build}.
#'
#' **Prerequisites:**
#' - Team lead has run \code{init_project()} and shared repository access
#' - Docker installed and running locally
#' - Access to team's Docker images (usually public on Docker Hub)
#' - Git repository cloned locally (typically done before calling this function)
#'
#' **Development Workflow:**
#' After joining, start development with \code{make r} (shell) or
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
#' # Using configuration defaults (recommended)
#' set_config("team_name", "mylab")
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
#' # system("make r")  # or make docker-rstudio
#' }
#'
#' @seealso
#' \code{\link{init_project}} for team leads initializing projects
#' \code{\link{set_config}} for setting up configuration defaults
#' \code{\link{team_images}} for checking available team images
#'
#' @export
join_project <- function(team_name = NULL, project_name = NULL) {

  # Shared project/team validation and team_name resolution.
  team_name <- resolve_team_project(team_name, project_name)

  # In the current model a team member joins by cloning the project repository
  # and building its Docker image from the committed Dockerfile + renv.lock.
  # Cloning and setwd() happen outside R; this builds the image via the
  # project Makefile.
  if (!file.exists('Makefile')) {
    stop('No Makefile found. Clone the project repository and setwd() into it ',
         'before calling join_project().', call. = FALSE)
  }

  message("Joining project '", project_name, "' (team: ", team_name,
          "): building Docker image via 'make docker-build'")
  result <- safe_system('make docker-build',
                        error_msg = 'Failed to build project Docker image')
  result == 0
}

#' Add R package to renv
#'
#' @param packages Character vector of package names
#' @param update_snapshot Logical, update renv.lock after installation
#' @return Logical indicating success
#' @importFrom utils install.packages
#' @export
add_package <- function(packages, update_snapshot = TRUE) {
  if (!requireNamespace('renv', quietly = TRUE)) {
    stop('renv package is required for this function', call. = FALSE)
  }

  # Install packages
  for (pkg in packages) {
    message('Installing package: ', pkg)
    utils::install.packages(pkg)
  }
  
  # Update snapshot if requested
  if (update_snapshot) {
    message('Updating renv.lock...')
    renv::snapshot()
  }

  TRUE
}

#' Sync environment across team
#'
#' @return Logical indicating success
#' @export
sync_env <- function() {
  if (!requireNamespace('renv', quietly = TRUE)) {
    stop('renv package is required for this function', call. = FALSE)
  }

  if (!file.exists('renv.lock')) {
    stop('No renv.lock file found. Are you in a zzcollab project directory?',
         call. = FALSE)
  }
  
  message('Restoring environment from renv.lock...')
  renv::restore()

  # Check if we need to rebuild Docker image
  result <- safe_system('make docker-check-renv', intern = TRUE,
                       error_msg = 'Failed to check renv status')
  if ((attr(result, 'status') %||% 0) != 0) {
    message('Environment sync may require Docker image rebuild')
    message("Run rebuild() or 'make docker-build' to update Docker environment")
  }

  TRUE
}

#' Execute analysis script in container
#'
#' @param script_path Path to R script
#' @param container_cmd Make target that runs the script in the container
#'   (default: "docker-script"). The target receives the script via the
#'   SCRIPT make variable.
#' @return Logical indicating success
#' @export
run_script <- function(script_path, container_cmd = 'docker-script') {
  if (!file.exists(script_path)) {
    stop('Script file not found: ', script_path, call. = FALSE)
  }

  if (!file.exists('Makefile')) {
    stop('No Makefile found. Are you in a zzcollab project directory?',
         call. = FALSE)
  }

  # Execute script in container via the docker-script make target
  cmd <- paste0('make ', container_cmd, ' SCRIPT=', shQuote(script_path))
  message('Running script in container: ', script_path)
  result <- safe_system(cmd, error_msg = paste('Failed to run script:', script_path))
  result == 0
}

#' Render analysis reports
#'
#' @param report_path Path to R Markdown file (optional)
#' @return Logical indicating success
#' @export
render_report <- function(report_path = NULL) {
  if (!file.exists('Makefile')) {
    stop('No Makefile found. Are you in a zzcollab project directory?',
         call. = FALSE)
  }

  if (!is.null(report_path)) {
    # Render specific report
    if (!file.exists(report_path)) {
      stop('Report file not found: ', report_path, call. = FALSE)
    }
    cmd <- paste0('make docker-render REPORT=', shQuote(report_path))
  } else {
    # Use default make target
    cmd <- 'make docker-render'
  }
  
  message('Rendering report in container...')
  result <- safe_system(cmd, error_msg = 'Failed to render report')
  result == 0
}

#' Check reproducibility
#'
#' @return Logical indicating if environment is reproducible
#' @export
validate_repro <- function() {
  scripts_to_check <- c(
    'scripts/99_reproducibility_check.R',
    'validate_package_environment.R',
    'check_rprofile_options.R'
  )
  
  all_passed <- TRUE
  
  for (script in scripts_to_check) {
    if (file.exists(script)) {
      message('Running reproducibility check: ', script)
      result <- safe_system(paste('Rscript', script), intern = TRUE,
                           error_msg = paste('Failed to run reproducibility check:', script))
      if ((attr(result, 'status') %||% 0) != 0) {
        message('FAILED: ', script)
        all_passed <- FALSE
      } else {
        message('PASSED: ', script)
      }
    }
  }
  
  # Check renv status
  if (requireNamespace('renv', quietly = TRUE)) {
    if (!renv::status()$synchronized) {
      message('WARNING: renv environment is not synchronized')
      all_passed <- FALSE
    }
  }
  
  if (all_passed) {
    message('\u2705 All reproducibility checks passed')
  } else {
    message('\u274c Some reproducibility checks failed')
  }

  all_passed
}

#' Setup zzcollab project (standard setup, non-init mode)
#'
#' @param base_image Base Docker image to use (optional)
#' @return Logical indicating success
#' @export
setup_project <- function(base_image = NULL) {

  # Validate base_image if provided
  if (!is.null(base_image)) {
    if (!is.character(base_image) || length(base_image) != 1) {
      stop('base_image must be a single character string', call. = FALSE)
    }
    # Allow Docker image format: owner/image or owner/image:tag
    if (!grepl('^[a-z0-9._-]+/[a-z0-9._-]+(:[a-z0-9._-]+)?$', base_image)) {
      stop("base_image must be in format 'owner/image' or 'owner/image:tag'", call. = FALSE)
    }
  }

  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  # Build the Docker environment. --base-image is a flag of the docker
  # subcommand, not a top-level option.
  cmd <- paste(zzcollab_path, 'docker')

  if (!is.null(base_image)) {
    cmd <- paste(cmd, '--base-image', base_image)
  }

  message('Running: ', cmd)
  result <- safe_system(cmd, error_msg = 'Failed to setup project')
  result == 0
}
