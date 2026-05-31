# ZZCOLLAB R Interface: Configuration system (split out of utils.R)

#=============================================================================
# CONFIGURATION SYSTEM R INTERFACE
#=============================================================================

#' Run a zzcollab config subcommand
#'
#' Internal helper shared by the config wrappers: resolves the zzcollab
#' script once and runs \code{zzcollab config <args>} via \code{safe_system()}.
#'
#' @param args Character vector of arguments following \code{config}, already
#'   shell-quoted where needed (e.g. \code{c("get", shQuote(key))}).
#' @param intern Passed to \code{safe_system()}; \code{TRUE} captures stdout.
#' @param error_msg Passed to \code{safe_system()}.
#' @return The \code{safe_system()} result: captured lines when
#'   \code{intern = TRUE}, otherwise the integer exit status.
#' @keywords internal
zzc_config <- function(args, intern = FALSE, error_msg = NULL) {
  zzcollab_path <- find_zzcollab_script()
  cmd <- paste(c(zzcollab_path, "config", args), collapse = " ")
  safe_system(cmd, intern = intern, error_msg = error_msg)
}

#' Get configuration value from zzcollab configuration system
#'
#' Retrieves configuration values from the zzcollab configuration hierarchy.
#' The system uses a three-tier configuration system with priority order:
#' project-level (./zzcollab.yaml) > user-level (~/.zzcollab/config.yaml) > system-level (/etc/zzcollab/config.yaml).
#'
#' @param key Character string specifying the configuration key to retrieve.
#'   Common keys include:
#'   - "team_name": Docker Hub team/organization name
#'   - "profile_name": Docker profile ("minimal", "analysis", "rstudio")
#'   - "github_account": GitHub account for repository creation
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
#' # Get GitHub account with fallback
#' github <- get_config("github_account") %||% get_config("team_name")
#' }
#'
#' @seealso
#' \code{\link{set_config}} for setting configuration values
#' \code{\link{list_config}} for viewing all configuration
#' \code{\link{get_config_default}} for configuration with defaults
#'
#' @export
get_config <- function(key) {
  result <- zzc_config(c("get", shQuote(key)), intern = TRUE,
                       error_msg = paste("Failed to get config value:", key))

  # `config get` echoes an empty string for unset keys (the "(not set)"
  # sentinel only appears in `config list`). Treat blank or sentinel
  # output as unset so %||% fallbacks behave correctly.
  if (length(result) > 0 && nzchar(trimws(result[1])) &&
        !grepl("\\(not set\\)", result[1])) {
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
#'   - "profile_name": Docker profile ("minimal", "analysis", "rstudio")
#'   - "github_account": Your GitHub account for repository creation
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
#' set_config("github_account", "myuniversity")
#'
#' # Check if configuration was successful
#' if (set_config("team_name", "newteam")) {
#'   cat("Team name updated successfully\n")
#' } else {
#'   cat("Failed to update configuration\n")
#' }
#' }
#'
#' @seealso
#' \code{\link{get_config}} for retrieving configuration values
#' \code{\link{list_config}} for viewing all current configuration
#' \code{\link{init_config}} for initializing default configuration
#'
#' @export
set_config <- function(key, value) {
  result <- zzc_config(c("set", shQuote(key), shQuote(value)),
                       error_msg = paste("Failed to set config value:", key))
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
  result <- zzc_config("list", intern = TRUE,
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
#' set_config("profile_name", "rstudio")
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
  result <- zzc_config("validate",
                       error_msg = "Failed to validate configuration")
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
#' - github_account: (empty, for repository creation)
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
  result <- zzc_config("init",
                       error_msg = "Failed to initialize configuration")
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
#'   \"team_name\", \"profile_name\", \"github_account\").
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