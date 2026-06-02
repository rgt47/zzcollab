# ZZCOLLAB R Interface Functions
# Provides R functions to interact with zzcollab Docker infrastructure

# Session-scoped cache for resolved internals (e.g. the zzcollab script
# path), populated lazily and reused across wrapper calls.
.zzcollab_cache <- new.env(parent = emptyenv())

#' Null-coalescing operator (internal)
#'
#' Provided for R < 4.4 where `base::\%||\%` is unavailable; on R >= 4.4 the
#' package's own definition shadows the identical base operator within the
#' namespace. Kept unexported to avoid masking `base::\%||\%` on attach.
#'
#' @noRd
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
    stop(param_name, ' must be a single character string', call. = FALSE)
  }

  # Check for empty string
  if (nchar(name) == 0) {
    stop(param_name, ' cannot be empty', call. = FALSE)
  }

  # Docker repository name rules:
  # - Lowercase letters, numbers, dots, underscores, hyphens
  # - Cannot start with dot or hyphen
  # - Max 255 characters
  if (grepl('^[.-]', name)) {
    stop(param_name, ' cannot start with a dot or hyphen', call. = FALSE)
  }

  if (grepl('[^a-z0-9._-]', name)) {
    stop(param_name, ' must contain only lowercase letters, numbers, dots, underscores, and hyphens',
         call. = FALSE)
  }

  if (nchar(name) > 255) {
    stop(param_name, ' must be 255 characters or less', call. = FALSE)
  }

  TRUE
}

#' Safe system call with error handling (vector-argument form)
#'
#' Wrapper around \code{system2()} that accepts the command and its arguments
#' as separate values, eliminating the shell-quoting surface that
#' \code{system(paste(cmd, args))} requires. Callers should pass each argument
#' as a distinct element of \code{args}; no quoting is necessary.
#'
#' Use this function for any invocation where at least one argument is derived
#' from user input. For backward-compatible literal-string calls use the
#' lower-level \code{safe_system_str()} (internal).
#'
#' @param cmd Character scalar: the executable to run (e.g. \code{'git'}).
#' @param args Character vector of arguments (default: \code{character()}).
#' @param intern Logical, capture stdout as a character vector (default: FALSE).
#' @param ignore.stdout Logical, discard stdout (default: FALSE).
#' @param ignore.stderr Logical, discard stderr (default: FALSE).
#' @param error_msg Custom prefix for warning/error messages (optional).
#' @return For \code{intern = FALSE}: integer exit status (0 = success).
#'         For \code{intern = TRUE}: character vector of captured output.
#' @keywords internal
safe_system2 <- function(cmd, args = character(), intern = FALSE,
                         ignore.stdout = FALSE, ignore.stderr = FALSE,
                         error_msg = NULL) {
  tryCatch({
    stdout_val <- if (intern) TRUE else if (ignore.stdout) FALSE else ''
    stderr_val <- if (ignore.stderr) FALSE else ''
    result <- system2(cmd, args = args,
                      stdout = stdout_val,
                      stderr = stderr_val)

    if (!intern && !identical(result, 0L) && !identical(result, 0)) {
      msg <- if (!is.null(error_msg)) {
        paste0(error_msg, ' (exit code: ', result, ')')
      } else {
        paste0('Command failed (exit code ', result, '): ',
               cmd, ' ', paste(args, collapse = ' '))
      }
      warning(msg, call. = FALSE)
    }
    result
  }, error = function(e) {
    msg <- if (!is.null(error_msg)) {
      paste0(error_msg, ': ', conditionMessage(e))
    } else {
      paste0('System command error: ', conditionMessage(e))
    }
    stop(msg, call. = FALSE)
  })
}

#' Safe system call (string form, internal)
#'
#' Legacy wrapper around \code{system()} retained for literal-string callers
#' that do not pass user-controlled data. New code should use
#' \code{safe_system2(cmd, args)} instead.
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
          paste0(error_msg, ' (exit code: ', result, ')')
        } else {
          paste0('Command failed with exit code ', result, ': ', command)
        }
        warning(msg, call. = FALSE)
      }
    }

    return(result)

  }, error = function(e) {
    msg <- if (!is.null(error_msg)) {
      paste0(error_msg, ': ', conditionMessage(e))
    } else {
      paste0('System command error: ', conditionMessage(e))
    }
    stop(msg, call. = FALSE)
  })
}

#' Find zzcollab script
#'
#' @return Path to zzcollab script
#' @keywords internal
find_zzcollab_script <- function() {
  # P-3: Do NOT prefer './zzcollab.sh' from the current working directory.
  # A working-directory-relative path is a trust issue: any zzcollab.sh placed
  # in the user's project directory would be executed instead of the installed
  # tool. Installed locations (PATH + known absolute paths) are used exclusively.

  # Installed locations do not move during a session, so cache the resolved
  # path after the first successful probe.
  cached <- get0('script_path', envir = .zzcollab_cache, inherits = FALSE)
  if (!is.null(cached)) {
    return(cached)
  }

  # First priority: zzcollab in PATH
  zzcollab_path <- Sys.which('zzcollab')
  if (nzchar(zzcollab_path)) {
    test_result <- safe_system2('zzcollab', c('config', 'list'),
                                ignore.stdout = TRUE, ignore.stderr = TRUE,
                                error_msg = 'Failed to test zzcollab config support')
    if (identical(test_result, 0L) || identical(test_result, 0)) {
      assign('script_path', 'zzcollab', envir = .zzcollab_cache)
      return('zzcollab')
    }
  }

  # Second priority: known absolute installation paths
  possible_paths <- c(
    file.path(Sys.getenv('HOME'), 'bin', 'zzcollab'),
    '/usr/local/bin/zzcollab',
    '/usr/bin/zzcollab'
  )

  for (path in possible_paths) {
    if (file.exists(path)) {
      test_result <- safe_system2(path, c('config', 'list'),
                                  ignore.stdout = TRUE, ignore.stderr = TRUE,
                                  error_msg = 'Failed to test zzcollab config support')
      if (identical(test_result, 0L) || identical(test_result, 0)) {
        assign('script_path', path, envir = .zzcollab_cache)
        return(path)
      }
    }
  }

  stop('zzcollab script with config support not found. Please use zzcollab from source directory or install updated version.',
       call. = FALSE)
}

