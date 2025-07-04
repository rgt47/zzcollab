#!/usr/bin/env Rscript

# Check for changes to critical R options in .Rprofile
# These options can significantly affect analysis results and should be reviewed

# Critical R options to monitor
CRITICAL_OPTIONS <- c(
  "stringsAsFactors",
  "contrasts", 
  "na.action",
  "digits",
  "OutDec"
)

# Read .Rprofile and extract option calls
extract_options_from_rprofile <- function(file_path = ".Rprofile") {
  if (!file.exists(file_path)) {
    return(NULL)
  }
  
  content <- readLines(file_path, warn = FALSE)
  
  # Find lines with options() calls
  option_lines <- grep("^\\s*options\\(", content, value = TRUE)
  
  # Extract the critical options
  critical_values <- list()
  
  for (opt in CRITICAL_OPTIONS) {
    # Look for this specific option
    pattern <- paste0("options\\(\\s*", opt, "\\s*=\\s*([^)]+)\\)")
    matches <- grep(pattern, content, value = TRUE)
    
    if (length(matches) > 0) {
      # Extract the value
      value <- sub(paste0(".*options\\(\\s*", opt, "\\s*=\\s*([^)]+)\\).*"), "\\1", matches[1])
      critical_values[[opt]] <- trimws(value)
    }
  }
  
  return(critical_values)
}

# Check if critical options have changed
check_for_changes <- function() {
  # Get current options
  current_options <- extract_options_from_rprofile()
  
  if (is.null(current_options) || length(current_options) == 0) {
    cat("No critical R options found in .Rprofile\n")
    return(invisible(0))
  }
  
  # Check if we're in a git repository and can compare
  if (system("git rev-parse --git-dir", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0) {
    cat("Not in a git repository - cannot check for changes\n")
    return(invisible(0))
  }
  
  # Check if .Rprofile has been modified
  git_status <- system("git diff --name-only HEAD .Rprofile", intern = TRUE, ignore.stderr = TRUE)
  
  if (length(git_status) > 0 && ".Rprofile" %in% git_status) {
    cat("⚠️  CRITICAL R OPTIONS CHANGE DETECTED ⚠️\n")
    cat("The .Rprofile file has been modified.\n")
    cat("Current critical R options:\n")
    
    for (opt in names(current_options)) {
      cat(sprintf("  %s = %s\n", opt, current_options[[opt]]))
    }
    
    cat("\n🔍 Please review these changes carefully as they affect analysis behavior.\n")
    cat("📋 Consider having a senior team member review these changes.\n")
    
    return(invisible(1))
  }
  
  cat("✅ No changes detected to critical R options\n")
  return(invisible(0))
}

# Run the check
if (!interactive()) {
  exit_code <- check_for_changes()
  quit(status = exit_code)
}