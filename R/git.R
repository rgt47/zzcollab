# ZZCOLLAB R Interface: Git and GitHub helpers
# Split out of utils.R. Shared internals (safe_system, find_zzcollab_script,
# %||%) live in utils.R and are available at load time.

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

  # shQuote the message so quotes, $(...), and other shell metacharacters in
  # the commit message are not interpreted by the shell.
  commit_cmd <- paste("git commit -m", shQuote(message))
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
    cmd <- paste("git push origin", shQuote(branch))
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
  result <- safe_system(paste("git checkout -b", shQuote(branch_name)),
                       error_msg = paste("Failed to create branch:", branch_name))

  if (result == 0) {
    message("\u2705 Created and switched to branch: ", branch_name)
    return(TRUE)
  } else {
    message("\u274c Failed to create branch: ", branch_name)
    return(FALSE)
  }
}
