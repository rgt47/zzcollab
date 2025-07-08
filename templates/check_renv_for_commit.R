#!/usr/bin/env Rscript
# Production-ready renv synchronization checker
#
# DESCRIPTION:
#   Analyzes R package dependencies across code files, DESCRIPTION, and renv.lock
#   to ensure proper synchronization before committing to version control.
#   Automatically detects missing packages and can fix DESCRIPTION + update renv.lock.
#
# USAGE:
#   Interactive mode:     Rscript check_renv_for_commit.R
#   CI/CD automation:     Rscript check_renv_for_commit.R --fix --fail-on-issues
#   Quick snapshot:       Rscript check_renv_for_commit.R --snapshot
#   Silent checking:      Rscript check_renv_for_commit.R --quiet --fail-on-issues
#
# FLAGS:
#   --fix, --auto-fix     Automatically fix DESCRIPTION and run renv::snapshot()
#   --fail-on-issues      Exit with code 1 if critical issues found (for CI/CD)
#   --snapshot           Only run renv::snapshot() and exit
#   --quiet              Minimal output, only show critical errors
#
# EXIT CODES:
#   0 = Success, no critical issues
#   1 = Critical issues found (missing packages, missing files, etc.)

# Parse arguments with validation
args <- commandArgs(trailingOnly = TRUE)
config <- list(
  auto_fix = any(c("--fix", "--auto-fix") %in% args),
  fail_on_issues = "--fail-on-issues" %in% args,
  snapshot_only = "--snapshot" %in% args,
  quiet = "--quiet" %in% args
)

# Validate argument combinations
if (config$snapshot_only && config$auto_fix) {
  stop("Cannot use --snapshot with --fix flags simultaneously")
}

# Enhanced logging with levels
log_msg <- function(..., level = "info", force = FALSE) {
  if (config$quiet && !force && level != "error") return()
  prefix <- switch(level,
    "error" = "❌",
    "warning" = "⚠️ ",
    "success" = "✅",
    "info" = "🔍"
  )
  cat(prefix, " ", ..., "\n", sep = "")
}

# Constants following R conventions
.BASE_PKGS <- c("base", "utils", "stats", "graphics", "grDevices", "methods", "datasets", "tools")
.TARGET_DIRS <- c("R", "scripts", "analysis")
.FILE_PATTERN <- "\\.(R|Rmd|qmd)$"
.PKG_NAME_PATTERN <- "^[a-zA-Z][a-zA-Z0-9._]*$"
.MIN_PKG_LENGTH <- 3L

# Early exit for snapshot-only mode
if (config$snapshot_only) {
  log_msg("Running snapshot...", level = "info")
  if (!requireNamespace("renv", quietly = TRUE)) {
    log_msg("renv package unavailable", level = "error", force = TRUE)
    quit(status = if (config$fail_on_issues) 1L else 0L)
  }
  
  tryCatch({
    renv::snapshot(type = "explicit", prompt = FALSE)
    log_msg("Snapshot complete", level = "success")
    quit(status = 0L)
  }, error = function(e) {
    log_msg("Snapshot failed: ", e$message, level = "error", force = TRUE)
    quit(status = if (config$fail_on_issues) 1L else 0L)
  })
}

log_msg("Checking renv setup...", level = "info")

# Extract R package dependencies from code files
#
# Scans R/, scripts/, analysis/ directories and top-level files for:
# - library() and require() calls
# - namespace calls (pkg::function)
#
# Returns: character vector of unique package names (filtered and validated)
extract_code_packages <- function() {
  # Find target files efficiently
  all_files <- character(0)
  
  for (dir in .TARGET_DIRS) {
    if (dir.exists(dir)) {
      files <- list.files(dir, pattern = .FILE_PATTERN, recursive = TRUE, 
                         ignore.case = TRUE, full.names = TRUE)
      all_files <- c(all_files, files)
    }
  }
  
  # Include top-level R files (excluding this script)
  top_files <- list.files(".", pattern = .FILE_PATTERN, ignore.case = TRUE)
  top_files <- top_files[!grepl("^check_renv_ready", top_files)]
  all_files <- c(all_files, top_files)
  
  if (length(all_files) == 0L) {
    log_msg("No R/Rmd/qmd files found in target directories", level = "warning")
    return(character(0))
  }
  
  log_msg("Scanning ", length(all_files), " files...", level = "info")
  
  # Optimized package extraction
  packages <- character(0)
  failed_files <- character(0)
  
  for (file in all_files) {
    if (!file.exists(file)) {
      failed_files <- c(failed_files, file)
      next
    }
    
    result <- tryCatch({
      # Read file efficiently
      content <- paste(readLines(file, warn = FALSE), collapse = "\n")
      
      # Remove comments preserving roxygen
      content <- gsub("(?<!#')#[^'\n]*", "", content, perl = TRUE)
      
      # Extract library/require calls with improved regex
      lib_pattern <- "(?:library|require)\\s*\\(\\s*[\"']?([a-zA-Z][a-zA-Z0-9._]*)[\"']?\\s*[,)]"
      lib_matches <- regmatches(content, gregexpr(lib_pattern, content, perl = TRUE))[[1]]
      
      lib_packages <- character(0)
      if (length(lib_matches) > 0L) {
        lib_packages <- gsub(".*\\(\\s*[\"']?([a-zA-Z][a-zA-Z0-9._]*)[\"']?.*", "\\1", lib_matches)
        lib_packages <- lib_packages[nchar(lib_packages) >= .MIN_PKG_LENGTH]
      }
      
      # Extract namespace calls
      ns_pattern <- "([a-zA-Z][a-zA-Z0-9._]{2,})::"
      ns_matches <- regmatches(content, gregexpr(ns_pattern, content, perl = TRUE))[[1]]
      
      ns_packages <- character(0)
      if (length(ns_matches) > 0L) {
        ns_packages <- gsub("::.*", "", ns_matches)
      }
      
      c(lib_packages, ns_packages)
    }, error = function(e) {
      failed_files <<- c(failed_files, file)
      character(0)
    })
    
    packages <- c(packages, result)
  }
  
  if (length(failed_files) > 0L) {
    log_msg("Failed to read ", length(failed_files), " files", level = "warning")
  }
  
  # Get self package name
  self_pkg <- get_self_package_name()
  
  # Clean and validate packages
  packages <- unique(packages)
  packages <- packages[!packages %in% c(.BASE_PKGS, self_pkg, "")]
  packages <- packages[nchar(packages) >= .MIN_PKG_LENGTH]
  packages <- packages[grepl(.PKG_NAME_PATTERN, packages)]
  
  packages
}

# Get the current package name from DESCRIPTION file
#
# Returns: character string of package name, or empty string if not found
get_self_package_name <- function() {
  if (!file.exists("DESCRIPTION")) return("")
  
  tryCatch({
    desc <- read.dcf("DESCRIPTION")
    if ("Package" %in% colnames(desc)) desc[, "Package"] else ""
  }, error = function(e) "")
}

# Parse package dependencies from DESCRIPTION file
#
# Extracts packages from Imports, Suggests, and Depends fields
# Returns: list(packages = character vector, error = logical)
parse_description <- function() {
  if (!file.exists("DESCRIPTION")) {
    log_msg("DESCRIPTION file not found", level = "error", force = TRUE)
    return(list(packages = character(0), error = TRUE))
  }
  
  tryCatch({
    desc <- read.dcf("DESCRIPTION")
    
    parse_field <- function(field) {
      if (!field %in% colnames(desc) || is.na(desc[, field])) {
        return(character(0))
      }
      
      deps <- trimws(strsplit(desc[, field], ",")[[1]])
      # Remove version constraints and filter
      deps <- gsub("\\s*\\([^)]+\\)", "", deps)
      deps[deps != "" & deps != "R"]
    }
    
    all_packages <- unique(c(
      parse_field("Imports"),
      parse_field("Suggests"), 
      parse_field("Depends")
    ))
    
    list(packages = all_packages, error = FALSE)
  }, error = function(e) {
    log_msg("Failed to parse DESCRIPTION: ", e$message, level = "error", force = TRUE)
    list(packages = character(0), error = TRUE)
  })
}

# Parse package list from renv.lock file
#
# Uses jsonlite if available, falls back to manual parsing
# Returns: list(packages = character vector, error = logical)
parse_renv_lock <- function() {
  if (!file.exists("renv.lock")) {
    log_msg("renv.lock file not found", level = "error", force = TRUE)
    return(list(packages = character(0), error = TRUE))
  }
  
  # Try jsonlite first
  packages <- tryCatch({
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      lock_data <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
      if ("Packages" %in% names(lock_data)) {
        pkgs <- names(lock_data$Packages)
        pkgs[!pkgs %in% .BASE_PKGS]
      } else {
        character(0)
      }
    } else {
      character(0)
    }
  }, error = function(e) character(0))
  
  # Fallback to manual parsing if jsonlite fails
  if (length(packages) == 0L) {
    packages <- tryCatch({
      content <- readLines("renv.lock", warn = FALSE)
      pkg_lines <- grep('"[^"]+": \\{', content, value = TRUE)
      if (length(pkg_lines) > 0L) {
        pkgs <- gsub('.*"([^"]+)": \\{.*', '\\1', pkg_lines)
        pkgs[!pkgs %in% c("R", "Packages", .BASE_PKGS)]
      } else {
        character(0)
      }
    }, error = function(e) character(0))
  }
  
  list(packages = packages, error = length(packages) == 0L)
}

# CRAN validation with caching and timeout
validate_cran_packages <- function(packages) {
  if (length(packages) == 0L) return(packages)
  
  log_msg("Validating ", length(packages), " packages against CRAN...", level = "info")
  
  tryCatch({
    # Set timeout for CRAN check
    old_timeout <- getOption("timeout")
    on.exit(options(timeout = old_timeout), add = TRUE)
    options(timeout = 30)
    
    available_pkgs <- available.packages(contriburl = contrib.url("https://cloud.r-project.org/"))
    cran_packages <- rownames(available_pkgs)
    
    valid_packages <- packages[packages %in% cran_packages]
    invalid_packages <- packages[!packages %in% cran_packages]
    
    if (length(invalid_packages) > 0L) {
      log_msg("Packages not found on CRAN: ", paste(sort(invalid_packages), collapse = ", "), 
              level = "warning")
    }
    
    if (length(valid_packages) > 0L) {
      log_msg("Valid CRAN packages: ", paste(sort(valid_packages), collapse = ", "), 
              level = "success")
    }
    
    valid_packages
  }, error = function(e) {
    log_msg("CRAN validation failed (network issue?): ", e$message, level = "warning")
    log_msg("Proceeding with all detected packages", level = "info")
    packages
  })
}

# Robust DESCRIPTION fixing with backup
fix_description <- function(missing_packages, invalid_packages = character(0)) {
  if (length(missing_packages) == 0L && length(invalid_packages) == 0L) return(FALSE)
  
  # Create backup
  backup_file <- paste0("DESCRIPTION.backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy("DESCRIPTION", backup_file)
  
  tryCatch({
    desc_lines <- readLines("DESCRIPTION")
    imports_idx <- grep("^Imports:", desc_lines)
    
    if (length(imports_idx) == 0L) {
      log_msg("No Imports section found in DESCRIPTION", level = "error", force = TRUE)
      file.remove(backup_file)
      return(FALSE)
    }
    
    # Find section boundaries
    start_idx <- imports_idx[1L]
    end_idx <- start_idx
    
    for (i in (start_idx + 1L):length(desc_lines)) {
      if (i > length(desc_lines) || 
          (!grepl("^\\s", desc_lines[i]) && desc_lines[i] != "")) {
        end_idx <- i - 1L
        break
      }
      end_idx <- i
    }
    
    # Parse existing imports
    imports_text <- gsub("^Imports:\\s*", "", paste(desc_lines[start_idx:end_idx], collapse = " "))
    existing <- if (nchar(trimws(imports_text)) > 0L) {
      gsub("\\s*\\([^)]+\\)", "", trimws(strsplit(imports_text, ",")[[1]]))
    } else {
      character(0)
    }
    
    # Process changes
    cleaned_existing <- existing[!existing %in% invalid_packages]
    removed_packages <- existing[existing %in% invalid_packages]
    new_packages <- setdiff(missing_packages, cleaned_existing)
    
    if (length(new_packages) == 0L && length(removed_packages) == 0L) {
      file.remove(backup_file)
      return(FALSE)
    }
    
    # Build new imports section
    all_packages <- sort(c(cleaned_existing[cleaned_existing != ""], new_packages))
    new_imports <- paste("Imports:", paste(all_packages, collapse = ",\n    "))
    new_imports_lines <- strsplit(new_imports, "\n")[[1]]
    
    # Reconstruct file
    new_lines <- c(
      desc_lines[1L:(start_idx - 1L)],
      new_imports_lines,
      if (end_idx < length(desc_lines)) desc_lines[(end_idx + 1L):length(desc_lines)] else character(0)
    )
    
    writeLines(new_lines, "DESCRIPTION")
    
    # Report changes
    if (length(new_packages) > 0L) {
      log_msg("Added packages: ", paste(new_packages, collapse = ", "), level = "success")
    }
    if (length(removed_packages) > 0L) {
      log_msg("Removed invalid packages: ", paste(removed_packages, collapse = ", "), level = "success")
    }
    
    # Remove backup on success
    file.remove(backup_file)
    return(TRUE)
    
  }, error = function(e) {
    log_msg("Failed to update DESCRIPTION: ", e$message, level = "error", force = TRUE)
    if (file.exists(backup_file)) {
      file.copy(backup_file, "DESCRIPTION", overwrite = TRUE)
      file.remove(backup_file)
      log_msg("DESCRIPTION restored from backup", level = "info")
    }
    return(FALSE)
  })
}

# Enhanced snapshot function with proper error handling
run_snapshot <- function(force_clean = FALSE) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    log_msg("renv package unavailable", level = "error", force = TRUE)
    return(FALSE)
  }
  
  tryCatch({
    if (force_clean) {
      log_msg("Installing missing packages and regenerating lockfile...", level = "info")
      
      # Install missing packages
      install_result <- tryCatch({
        renv::install()
        log_msg("Missing packages installed", level = "success")
        TRUE
      }, error = function(e) {
        log_msg("Package installation issues: ", e$message, level = "warning")
        FALSE
      })
      
      # Remove lockfile to force regeneration
      if (file.exists("renv.lock")) {
        lockfile_backup <- paste0("renv.lock.backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
        file.copy("renv.lock", lockfile_backup)
        file.remove("renv.lock")
        log_msg("Removed old renv.lock (backup created)", level = "info")
      }
    }
    
    # Create new lockfile
    renv::snapshot(type = "explicit", prompt = FALSE)
    log_msg("Lockfile updated successfully", level = "success")
    return(TRUE)
    
  }, error = function(e) {
    log_msg("Snapshot failed: ", e$message, level = "error", force = TRUE)
    return(FALSE)
  })
}

# Get script name for recursion
get_script_name <- function() {
  script_args <- commandArgs()
  file_arg <- script_args[grepl("--file=", script_args)]
  if (length(file_arg) > 0L) {
    return(basename(sub(".*=", "", file_arg)))
  }
  "check_renv_for_commit.R"
}

# Main execution flow
main <- function() {
  # Extract and validate packages
  code_packages <- extract_code_packages()
  validated_packages <- validate_cran_packages(code_packages)
  
  # Parse configuration files
  desc_result <- parse_description()
  renv_result <- parse_renv_lock()
  
  log_msg("Found ", length(validated_packages), " valid code packages, ", 
          length(desc_result$packages), " DESCRIPTION packages, ",
          length(renv_result$packages), " renv.lock packages", level = "info")
  
  # Analyze synchronization issues
  missing_from_desc <- setdiff(validated_packages, desc_result$packages)
  
  # Validate DESCRIPTION packages against CRAN
  invalid_in_desc <- character(0)
  if (length(desc_result$packages) > 0L) {
    all_desc_packages <- desc_result$packages
    validated_desc_packages <- validate_cran_packages(all_desc_packages)
    invalid_in_desc <- setdiff(all_desc_packages, validated_desc_packages)
    invalid_in_desc <- invalid_in_desc[!invalid_in_desc %in% .BASE_PKGS]
  }
  
  # Determine critical issues
  has_critical_issues <- length(missing_from_desc) > 0L || 
                        length(invalid_in_desc) > 0L || 
                        desc_result$error || 
                        renv_result$error
  
  # Report findings
  if (length(missing_from_desc) > 0L) {
    log_msg("Missing from DESCRIPTION: ", paste(sort(missing_from_desc), collapse = ", "), 
            level = "error", force = TRUE)
  }
  
  if (length(invalid_in_desc) > 0L) {
    log_msg("Invalid packages in DESCRIPTION: ", paste(sort(invalid_in_desc), collapse = ", "), 
            level = "error", force = TRUE)
  }
  
  unused_in_desc <- setdiff(desc_result$packages, validated_packages)
  unused_in_desc <- unused_in_desc[!unused_in_desc %in% invalid_in_desc]
  if (length(unused_in_desc) > 0L) {
    log_msg("Unused packages in DESCRIPTION: ", paste(sort(unused_in_desc), collapse = ", "), level = "warning")
  }
  
  extra_in_renv <- setdiff(renv_result$packages, desc_result$packages)
  if (length(extra_in_renv) > 0L) {
    log_msg("Extra packages in renv.lock: ", paste(sort(extra_in_renv), collapse = ", "), level = "warning")
  }
  
  # Handle fixes
  if (has_critical_issues) {
    if (config$auto_fix) {
      log_msg("Auto-fixing issues...", level = "info")
      need_clean <- length(extra_in_renv) > 0L
      
      if (fix_description(missing_from_desc, invalid_in_desc)) {
        if (run_snapshot(force_clean = need_clean)) {
          # Re-run verification
          script_name <- get_script_name()
          recheck_args <- paste("Rscript", script_name, "--quiet")
          if (config$fail_on_issues) recheck_args <- paste(recheck_args, "--fail-on-issues")
          system(recheck_args)
          return(invisible(NULL))
        }
      }
    } else if (interactive()) {
      cat("Fix detected issues? [y/N]: ")
      response <- trimws(readLines(n = 1L))
      if (tolower(response) %in% c("y", "yes")) {
        need_clean <- length(extra_in_renv) > 0L
        if (fix_description(missing_from_desc, invalid_in_desc)) {
          run_snapshot(force_clean = need_clean)
        }
      }
    } else {
      log_msg("Run with --fix to automatically resolve issues", level = "info")
    }
  } else if (length(extra_in_renv) > 0L && config$auto_fix) {
    run_snapshot(force_clean = TRUE)
  }
  
  # Final status
  if (has_critical_issues) {
    log_msg("Repository NOT READY for commit", level = "error", force = TRUE)
  } else {
    log_msg("Repository READY for commit", level = "success")
  }
  
  # Exit handling
  exit_code <- if (has_critical_issues) 1L else 0L
  if (config$fail_on_issues && exit_code != 0L) {
    quit(status = exit_code)
  }
  
  # Usage help for non-interactive mode
  if (!config$quiet && length(args) == 0L && !interactive()) {
    cat("\n📖 USAGE: --fix --fail-on-issues --snapshot --quiet\n")
    cat("For detailed help, see script header documentation.\n")
  }
  
  invisible(exit_code)
}

# Execute main function
main()