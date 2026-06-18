# ZZCOLLAB R Interface: Help and next-steps (split out of utils.R)

#' Get zzcollab help
#'
#' Displays help documentation for zzcollab. Can show general help or specialized
#' help pages covering specific topics like configuration, workflows, Docker, and more.
#'
#' @param topic Character string specifying which help page to display.
#'   Options include:
#'   - NULL or "general": Main help with all command-line options (default)
#'   - "docker": Docker essentials for researchers
#'   - "profiles": Available Docker profiles
#'   - "config": Configuration system guide
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
#' # Learn about configuration system
#' zzcollab_help("config")
#'
#' # Available Docker profiles
#' zzcollab_help("profiles")
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
  # Valid help topics (must match the CLI dispatcher in modules/help.sh).
  valid_topics <- c('general', 'docker', 'profiles', 'config', 'next-steps')

  # Validate the topic before any script lookup: topic validation is pure R, so
  # an invalid topic must be rejected with a clear error even when the zzcollab
  # CLI is not installed (e.g. during package tests / R CMD check).
  if (!is.null(topic) && topic != 'general' && !(topic %in% valid_topics)) {
    stop('Unknown help topic: ', topic, '\n',
         'Valid topics: ', paste(valid_topics, collapse = ', '),
         call. = FALSE)
  }

  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  # Build command with topic argument.
  # The CLI routes topics via the 'help' subcommand (e.g. 'zzcollab help docker');
  # 'next-steps' is a help topic, not a flag.
  if (is.null(topic) || topic == 'general') {
    cmd <- paste(zzcollab_path, 'help')
  } else {
    cmd <- paste(zzcollab_path, 'help', topic)
  }

  result <- safe_system(cmd, intern = TRUE,
                       error_msg = 'Failed to retrieve zzcollab help')
  result
}

#' Get zzcollab next steps
#'
#' @return Character vector with next steps information
#' @export
zzcollab_next_steps <- function() {
  # Find zzcollab script
  zzcollab_path <- find_zzcollab_script()

  cmd <- paste(zzcollab_path, 'help next-steps')
  result <- safe_system(cmd, intern = TRUE,
                       error_msg = 'Failed to retrieve next steps information')
  result
}
