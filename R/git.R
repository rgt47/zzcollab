# ZZCOLLAB R Interface: Git and GitHub helpers
# Split out of utils.R. Shared internals (safe_system, find_zzcollab_script,
# %||%) live in utils.R and are available at load time.

# Print an outcome message based on a command's exit status and return the
# logical result. Shared by the git/PR wrappers below (git_status differs: it
# returns the porcelain output rather than a logical).
report_status <- function(result, ok_msg, fail_msg) {
  if (result == 0) {
    message(ok_msg)
    TRUE
  } else {
    message(fail_msg)
    FALSE
  }
}

#' Create and push git commit
#'
#' @param message Commit message
#' @param add_all Logical, add all files (default: TRUE)
#' @return Logical indicating success
#' @export
git_commit <- function(message, add_all = TRUE) {
  if (add_all) {
    result1 <- safe_system2('git', 'add .' , error_msg = 'Failed to add files to git')
    if (!identical(result1, 0L) && !identical(result1, 0)) {
      stop('Failed to add files to git', call. = FALSE)
    }
  }

  # P-3: pass message as a separate argument so no shell quoting is needed.
  result2 <- safe_system2('git', c('commit', '-m', message),
                           error_msg = 'Failed to create git commit')

  report_status(result2, paste0('\u2705 Commit created: ', message),
                '\u274c Commit failed')
}

#' Push commits to GitHub
#'
#' @param branch Branch name (default: current branch)
#' @return Logical indicating success  
#' @export
git_push <- function(branch = NULL) {
  args <- if (is.null(branch)) 'push' else c('push', 'origin', branch)
  result <- safe_system2('git', args, error_msg = 'Failed to push to GitHub')

  report_status(result, '\u2705 Successfully pushed to GitHub', '\u274c Push failed')
}

#' Create GitHub pull request
#'
#' @param title Pull request title
#' @param body Pull request body (optional)
#' @param base Base branch (default: "main")
#' @return Logical indicating success
#' @export
create_pr <- function(title, body = NULL, base = 'main') {
  # Require the gh CLI (the GitHub command-line tool). Sys.which resolves it
  # in-process; the previous system.file(package = 'gh') check probed for an
  # unrelated CRAN R package named 'gh' and, if that was installed, skipped
  # the CLI check entirely.
  if (!nzchar(Sys.which('gh'))) {
    stop('GitHub CLI (gh) is required. Install with: brew install gh',
         call. = FALSE)
  }

  # P-3: pass title, body, and base as separate args (no shell quoting needed).
  args <- c('pr', 'create', '--title', title, '--base', base)
  if (!is.null(body)) {
    args <- c(args, '--body', body)
  }

  result <- safe_system2('gh', args, error_msg = 'Failed to create pull request')

  report_status(result, '\u2705 Pull request created successfully',
                '\u274c Failed to create pull request')
}

#' Check git status
#'
#' @return Character vector with git status output
#' @export
git_status <- function() {
  result <- safe_system('git status --porcelain', intern = TRUE,
                       error_msg = 'Failed to check git status')

  if (length(result) == 0) {
    message('\u2705 Working directory clean')
    character(0)
  } else {
    message('\ud83d\udcdd Changes detected:')
    print(result)
    result
  }
}

#' Create feature branch
#'
#' @param branch_name Name of the new branch
#' @return Logical indicating success
#' @export
create_branch <- function(branch_name) {
  # Ensure we're on main and up to date (literal args, no user data)
  safe_system2('git', c('checkout', 'main'), ignore.stdout = TRUE,
               error_msg = 'Failed to checkout main branch')
  safe_system2('git', 'pull', ignore.stdout = TRUE,
               error_msg = 'Failed to pull latest changes')

  # Create and checkout new branch (P-3: pass branch_name as a separate arg)
  result <- safe_system2('git', c('checkout', '-b', branch_name),
                         error_msg = paste('Failed to create branch:', branch_name))

  report_status(result,
                paste0('\u2705 Created and switched to branch: ', branch_name),
                paste0('\u274c Failed to create branch: ', branch_name))
}
