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
    test_result <- safe_system(paste(zzcollab_path, "config list"),
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
      test_result <- safe_system(paste(path, "config list"),
                                 ignore.stdout = TRUE, ignore.stderr = TRUE,
                                 error_msg = "Failed to test zzcollab config support")
      if (test_result == 0) {
        return(path)
      }
    }
  }

  stop("zzcollab script with config support not found. Please use zzcollab from source directory or install updated version.")
}

