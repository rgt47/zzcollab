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
#   Strict mode:          Rscript check_renv_for_commit.R --fix --strict-imports
#
# FLAGS:
#   --fix, --auto-fix     Automatically fix DESCRIPTION and run renv::snapshot()
#   --fail-on-issues      Exit with code 1 if critical issues found (for CI/CD)
#   --snapshot           Only run renv::snapshot() and exit
#   --quiet              Minimal output, only show critical errors
#   --strict-imports     Scan all directories and put all packages in Imports
#
# EXIT CODES:
#   0 = Success, no critical issues
#   1 = Critical issues found (missing packages, missing files, etc.)

#==============================================================================
# CONFIGURATION AND CONSTANTS
#==============================================================================

# Package configuration constants (immutable)
PKG_CONFIG <- list(
  base_packages = c("base", "utils", "stats", "graphics", "grDevices", "methods", "datasets", "tools"),
  standard_dirs = c("R", "scripts", "analysis"),
  strict_dirs = c("R", "scripts", "analysis", "tests", "vignettes", "inst"),
  file_extensions = c("R", "Rmd", "qmd", "Rnw"),
  min_package_length = 3L,  # Minimum viable package name length
  cran_timeout_seconds = 30L,  # CRAN API timeout
  backup_timestamp_format = "%Y%m%d_%H%M%S"
)

# Pre-compiled regex patterns for performance
REGEX_PATTERNS <- list(
  file_pattern = paste0("\\.(", paste(PKG_CONFIG$file_extensions, collapse = "|"), ")$"),
  library_calls = "(?:library|require)\\s*\\(\\s*[\"']?([a-zA-Z][a-zA-Z0-9._]{2,})[\"']?\\s*[,)]",
  namespace_calls = "([a-zA-Z][a-zA-Z0-9._]{2,})::",
  package_name_valid = "^[a-zA-Z][a-zA-Z0-9._]{2,}$",
  comments_simple = "#[^\n]*",
  examples_section = "@examples[\\s\\S]*?(?=@[a-zA-Z]|$)",
  self_script_pattern = "^check_renv"
)

#==============================================================================
# ARGUMENT PARSING AND VALIDATION
#==============================================================================

# Parse command line arguments into validated configuration
parse_arguments <- function(args = commandArgs(trailingOnly = TRUE)) {
  config <- list(
    auto_fix = any(c("--fix", "--auto-fix") %in% args),
    fail_on_issues = "--fail-on-issues" %in% args,
    snapshot_only = "--snapshot" %in% args,
    quiet = "--quiet" %in% args,
    strict_imports = "--strict-imports" %in% args
  )
  
  # Validate argument combinations
  if (config$snapshot_only && config$auto_fix) {
    stop("Cannot use --snapshot with --fix flags simultaneously", call. = FALSE)
  }
  
  config
}

#==============================================================================
# LOGGING SYSTEM
#==============================================================================

# Create logging function factory to avoid global dependencies
create_logger <- function(config) {
  function(..., level = "info", force = FALSE) {
    if (config$quiet && !force && level != "error") return(invisible(NULL))
    
    prefix <- switch(level,
      "error" = "❌",
      "warning" = "⚠️ ",
      "success" = "✅",
      "info" = "🔍",
      "🔍"  # default
    )
    cat(prefix, " ", ..., "\n", sep = "")
    invisible(NULL)
  }
}

#==============================================================================
# PURE UTILITY FUNCTIONS
#==============================================================================

# Validate and clean package names (pure function)
clean_package_names <- function(packages, exclude_packages = character()) {
  if (!is.character(packages) || length(packages) == 0L) {
    return(character(0))
  }
  
  # Remove duplicates and unwanted packages
  packages <- unique(packages)
  packages <- packages[!packages %in% c(PKG_CONFIG$base_packages, exclude_packages, "")]
  
  # Validate package name format and length
  packages <- packages[nchar(packages) >= PKG_CONFIG$min_package_length]
  packages <- packages[grepl(REGEX_PATTERNS$package_name_valid, packages, perl = TRUE)]
  
  sort(packages)
}

# Extract packages from text content (pure function, non-recursive)
extract_packages_from_text <- function(content) {
  if (!is.character(content) || length(content) == 0L || nchar(content) == 0L) {
    return(character(0))
  }
  
  # Remove comments to avoid false positives
  content <- gsub(REGEX_PATTERNS$comments_simple, "", content, perl = TRUE)
  
  packages <- character(0)
  
  # Extract library/require calls
  lib_matches <- regmatches(content, gregexpr(REGEX_PATTERNS$library_calls, content, perl = TRUE))[[1]]
  if (length(lib_matches) > 0L) {
    lib_packages <- gsub(REGEX_PATTERNS$library_calls, "\\1", lib_matches, perl = TRUE)
    packages <- c(packages, lib_packages)
  }
  
  # Extract namespace calls (pkg::function)
  ns_matches <- regmatches(content, gregexpr(REGEX_PATTERNS$namespace_calls, content, perl = TRUE))[[1]]
  if (length(ns_matches) > 0L) {
    ns_packages <- gsub("::", "", ns_matches)
    packages <- c(packages, ns_packages)
  }
  
  # Extract packages from @examples sections (non-recursive approach)
  examples_matches <- regmatches(content, gregexpr(REGEX_PATTERNS$examples_section, content, perl = TRUE))[[1]]
  if (length(examples_matches) > 0L) {
    for (example_block in examples_matches) {
      # Remove @examples line and process the rest
      example_content <- sub("@examples[^\n]*\n?", "", example_block)
      # Simple extraction without recursion
      ex_lib_matches <- regmatches(example_content, gregexpr(REGEX_PATTERNS$library_calls, example_content, perl = TRUE))[[1]]
      if (length(ex_lib_matches) > 0L) {
        ex_packages <- gsub(REGEX_PATTERNS$library_calls, "\\1", ex_lib_matches, perl = TRUE)
        packages <- c(packages, ex_packages)
      }
      ex_ns_matches <- regmatches(example_content, gregexpr(REGEX_PATTERNS$namespace_calls, example_content, perl = TRUE))[[1]]
      if (length(ex_ns_matches) > 0L) {
        ex_ns_packages <- gsub("::", "", ex_ns_matches)
        packages <- c(packages, ex_ns_packages)
      }
    }
  }
  
  packages
}

# Safe file reading with error handling
read_file_safely <- function(filepath) {
  if (!is.character(filepath) || length(filepath) != 1L || !file.exists(filepath)) {
    return(list(content = "", success = FALSE, error = "File not found or invalid path"))
  }
  
  tryCatch({
    content <- paste(readLines(filepath, warn = FALSE), collapse = "\n")
    list(content = content, success = TRUE, error = NULL)
  }, error = function(e) {
    list(content = "", success = FALSE, error = as.character(e))
  })
}

# Batch file discovery with memoization
discover_files <- function(target_dirs, file_pattern) {
  if (!is.character(target_dirs) || length(target_dirs) == 0L) {
    return(character(0))
  }
  
  # Only scan existing directories
  existing_dirs <- target_dirs[file.exists(target_dirs)]
  if (length(existing_dirs) == 0L) {
    return(character(0))
  }
  
  # Efficient batch file discovery
  all_files <- character(0)
  for (dir in existing_dirs) {
    if (dir.exists(dir)) {
      files <- list.files(dir, pattern = file_pattern, recursive = TRUE, 
                         ignore.case = TRUE, full.names = TRUE)
      all_files <- c(all_files, files)
    }
  }
  
  # Add top-level files (excluding this script)
  top_files <- list.files(".", pattern = file_pattern, ignore.case = TRUE)
  top_files <- top_files[!grepl(REGEX_PATTERNS$self_script_pattern, top_files)]
  all_files <- c(all_files, top_files)
  
  unique(all_files)
}

#==============================================================================
# PACKAGE EXTRACTION ENGINE
#==============================================================================

# Main package extraction function
extract_code_packages <- function(config, log_fn) {
  # Choose directories based on mode
  target_dirs <- if (config$strict_imports) PKG_CONFIG$strict_dirs else PKG_CONFIG$standard_dirs
  
  # Discover all relevant files
  all_files <- discover_files(target_dirs, REGEX_PATTERNS$file_pattern)
  
  if (length(all_files) == 0L) {
    log_fn("No R/Rmd/qmd/Rnw files found", level = "warning")
    return(character(0))
  }
  
  mode_name <- if (config$strict_imports) "strict" else "standard"
  log_fn("Scanning ", length(all_files), " files in ", mode_name, " mode...", level = "info")
  
  # Process files efficiently using lists instead of vector concatenation
  package_lists <- vector("list", length(all_files))
  failed_count <- 0L
  
  for (i in seq_along(all_files)) {
    file_result <- read_file_safely(all_files[i])
    if (file_result$success) {
      package_lists[[i]] <- extract_packages_from_text(file_result$content)
    } else {
      failed_count <- failed_count + 1L
      package_lists[[i]] <- character(0)
    }
  }
  
  if (failed_count > 0L) {
    log_fn("Failed to read ", failed_count, " files", level = "warning")
  }
  
  # Flatten package lists efficiently
  all_packages <- unlist(package_lists, use.names = FALSE)
  
  # Clean packages (get self package name for exclusion)
  self_pkg <- get_self_package_name()
  clean_package_names(all_packages, c(self_pkg))
}

#==============================================================================
# CONFIGURATION FILE PARSERS
#==============================================================================

# Get self package name safely
get_self_package_name <- function() {
  if (!file.exists("DESCRIPTION")) return("")
  
  tryCatch({
    desc_data <- read.dcf("DESCRIPTION")
    if ("Package" %in% colnames(desc_data)) desc_data[, "Package"] else ""
  }, error = function(e) "")
}

# Parse DESCRIPTION file with multiple fallback strategies
parse_description_file <- function() {
  if (!file.exists("DESCRIPTION")) {
    return(list(packages = character(0), error = TRUE, message = "DESCRIPTION file not found"))
  }
  
  tryCatch({
    # Primary: Try desc package for robust parsing
    if (requireNamespace("desc", quietly = TRUE)) {
      d <- desc::desc()
      deps <- d$get_deps()
      all_packages <- unique(deps$package[deps$type %in% c("Imports", "Suggests", "Depends")])
      all_packages <- all_packages[!all_packages %in% c("R", "")]
      return(list(packages = all_packages, error = FALSE, message = "Parsed with desc package"))
    }
    
    # Fallback: Manual DCF parsing
    desc_data <- read.dcf("DESCRIPTION")
    
    extract_deps <- function(field_name) {
      if (!field_name %in% colnames(desc_data) || is.na(desc_data[, field_name])) {
        return(character(0))
      }
      deps <- trimws(strsplit(desc_data[, field_name], ",")[[1]])
      deps <- gsub("\\s*\\([^)]+\\)", "", deps)  # Remove version constraints
      deps[deps != "" & deps != "R"]
    }
    
    all_packages <- unique(c(
      extract_deps("Imports"),
      extract_deps("Suggests"),
      extract_deps("Depends")
    ))
    
    list(packages = all_packages, error = FALSE, message = "Parsed with read.dcf")
    
  }, error = function(e) {
    list(packages = character(0), error = TRUE, message = paste("Parse failed:", e$message))
  })
}

# Parse renv.lock file with fallbacks
parse_renv_lock_file <- function() {
  if (!file.exists("renv.lock")) {
    return(list(packages = character(0), error = TRUE, message = "renv.lock file not found"))
  }
  
  tryCatch({
    # Primary: JSON parsing
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      lock_data <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
      if ("Packages" %in% names(lock_data)) {
        packages <- names(lock_data$Packages)
        packages <- packages[!packages %in% PKG_CONFIG$base_packages]
        return(list(packages = packages, error = FALSE, message = "Parsed with jsonlite"))
      }
    }
    
    # Fallback: Manual parsing
    content <- readLines("renv.lock", warn = FALSE)
    pkg_lines <- grep('"[^"]+": \\{', content, value = TRUE)
    if (length(pkg_lines) > 0L) {
      packages <- gsub('.*"([^"]+)": \\{.*', '\\1', pkg_lines)
      packages <- packages[!packages %in% c("R", "Packages", PKG_CONFIG$base_packages)]
      return(list(packages = packages, error = FALSE, message = "Parsed manually"))
    }
    
    list(packages = character(0), error = TRUE, message = "No packages found in renv.lock")
    
  }, error = function(e) {
    list(packages = character(0), error = TRUE, message = paste("Parse failed:", e$message))
  })
}

#==============================================================================
# CRAN VALIDATION (WITH CACHING)
#==============================================================================

# Validate packages against CRAN (cached for session)
validate_against_cran <- function(packages, log_fn) {
  if (!is.character(packages) || length(packages) == 0L) {
    return(list(valid = character(0), invalid = character(0), error = FALSE))
  }
  
  log_fn("Validating ", length(packages), " packages against CRAN...", level = "info")
  
  tryCatch({
    # Set timeout and restore on exit
    old_timeout <- getOption("timeout")
    on.exit(options(timeout = old_timeout), add = TRUE)
    options(timeout = PKG_CONFIG$cran_timeout_seconds)
    
    # Get available packages
    available_pkgs <- available.packages(contriburl = contrib.url("https://cloud.r-project.org/"))
    cran_packages <- rownames(available_pkgs)
    
    # Split into valid and invalid
    valid_packages <- packages[packages %in% cran_packages]
    invalid_packages <- packages[!packages %in% cran_packages]
    
    if (length(invalid_packages) > 0L) {
      log_fn("Invalid packages: ", paste(sort(invalid_packages), collapse = ", "), level = "warning")
    }
    
    list(valid = valid_packages, invalid = invalid_packages, error = FALSE)
    
  }, error = function(e) {
    log_fn("CRAN validation failed: ", e$message, level = "warning")
    list(valid = packages, invalid = character(0), error = TRUE)
  })
}

#==============================================================================
# DESCRIPTION FILE MODIFICATION
#==============================================================================

# Fix DESCRIPTION file with robust error handling
fix_description_file <- function(missing_packages, invalid_packages, log_fn) {
  if (length(missing_packages) == 0L && length(invalid_packages) == 0L) {
    return(list(success = FALSE, message = "No changes needed"))
  }
  
  if (!file.exists("DESCRIPTION")) {
    return(list(success = FALSE, message = "DESCRIPTION file not found"))
  }
  
  # Create timestamped backup
  backup_file <- paste0("DESCRIPTION.backup.", format(Sys.time(), PKG_CONFIG$backup_timestamp_format))
  if (!file.copy("DESCRIPTION", backup_file)) {
    return(list(success = FALSE, message = "Failed to create backup"))
  }
  
  tryCatch({
    # Primary: Use desc package for robust editing
    if (requireNamespace("desc", quietly = TRUE)) {
      d <- desc::desc()
      
      # Remove invalid packages from all dependency fields
      for (pkg in invalid_packages) {
        d$del_dep(pkg)
      }
      
      # Add missing packages to Imports
      for (pkg in missing_packages) {
        d$set_dep(pkg, "Imports")
      }
      
      d$write()
      
    } else {
      # Fallback: Manual editing with bounds checking
      desc_lines <- readLines("DESCRIPTION")
      imports_idx <- grep("^Imports:", desc_lines)
      
      if (length(imports_idx) == 0L) {
        # Add new Imports section
        if (length(missing_packages) > 0L) {
          new_imports_line <- paste("Imports:", paste(missing_packages, collapse = ",\n    "))
          desc_lines <- c(desc_lines, new_imports_line)
        }
      } else {
        # Update existing Imports section with proper bounds checking
        start_idx <- imports_idx[1L]
        end_idx <- length(desc_lines)
        
        # Find end of Imports section safely
        for (i in (start_idx + 1L):length(desc_lines)) {
          if (!grepl("^\\s", desc_lines[i]) && desc_lines[i] != "") {
            end_idx <- i - 1L
            break
          }
        }
        
        # Parse existing imports
        imports_section <- desc_lines[start_idx:min(end_idx, length(desc_lines))]
        imports_text <- gsub("^Imports:\\s*", "", paste(imports_section, collapse = " "))
        
        existing_packages <- character(0)
        if (nchar(trimws(imports_text)) > 0L) {
          existing_packages <- trimws(strsplit(imports_text, ",")[[1]])
          existing_packages <- gsub("\\s*\\([^)]+\\)", "", existing_packages)
        }
        
        # Update package list
        cleaned_existing <- existing_packages[!existing_packages %in% invalid_packages]
        all_packages <- sort(unique(c(cleaned_existing[cleaned_existing != ""], missing_packages)))
        
        # Rebuild DESCRIPTION
        if (length(all_packages) > 0L) {
          new_imports <- paste("Imports:", paste(all_packages, collapse = ",\n    "))
          new_imports_lines <- strsplit(new_imports, "\n")[[1]]
        } else {
          new_imports_lines <- character(0)
        }
        
        # Safely reconstruct file
        before_section <- if (start_idx > 1L) desc_lines[1L:(start_idx - 1L)] else character(0)
        after_section <- if (end_idx < length(desc_lines)) desc_lines[(end_idx + 1L):length(desc_lines)] else character(0)
        
        desc_lines <- c(before_section, new_imports_lines, after_section)
      }
      
      writeLines(desc_lines, "DESCRIPTION")
    }
    
    # Report changes
    change_messages <- character(0)
    if (length(missing_packages) > 0L) {
      log_fn("Added packages: ", paste(missing_packages, collapse = ", "), level = "success")
      change_messages <- c(change_messages, paste("Added:", length(missing_packages), "packages"))
    }
    if (length(invalid_packages) > 0L) {
      log_fn("Removed invalid packages: ", paste(invalid_packages, collapse = ", "), level = "success")
      change_messages <- c(change_messages, paste("Removed:", length(invalid_packages), "invalid packages"))
    }
    
    # Remove backup on success
    file.remove(backup_file)
    
    list(success = TRUE, message = paste(change_messages, collapse = "; "))
    
  }, error = function(e) {
    # Restore from backup on error
    if (file.exists(backup_file)) {
      file.copy(backup_file, "DESCRIPTION", overwrite = TRUE)
      file.remove(backup_file)
    }
    list(success = FALSE, message = paste("Update failed:", e$message))
  })
}

#==============================================================================
# RENV OPERATIONS
#==============================================================================

# Run renv snapshot with comprehensive error handling
run_renv_snapshot <- function(force_clean, log_fn) {
  if (!requireNamespace("renv", quietly = TRUE)) {
    return(list(success = FALSE, message = "renv package unavailable"))
  }
  
  tryCatch({
    if (force_clean) {
      log_fn("Regenerating lockfile...", level = "info")
      
      # Install missing packages
      install_result <- tryCatch({
        renv::install()
        TRUE
      }, error = function(e) {
        log_fn("Package installation warning: ", e$message, level = "warning")
        FALSE
      })
      
      # Backup and remove existing lockfile
      if (file.exists("renv.lock")) {
        backup_name <- paste0("renv.lock.backup.", format(Sys.time(), PKG_CONFIG$backup_timestamp_format))
        file.copy("renv.lock", backup_name)
        file.remove("renv.lock")
        log_fn("Removed old renv.lock (backup created)", level = "info")
      }
    }
    
    # Create new snapshot
    renv::snapshot(type = "explicit", prompt = FALSE)
    log_fn("Lockfile updated successfully", level = "success")
    
    list(success = TRUE, message = "Snapshot completed successfully")
    
  }, error = function(e) {
    list(success = FALSE, message = paste("Snapshot failed:", e$message))
  })
}

#==============================================================================
# MAIN EXECUTION ORCHESTRATOR
#==============================================================================

# Snapshot-only mode handler
handle_snapshot_only <- function(config, log_fn) {
  log_fn("Running snapshot...", level = "info")
  
  if (!requireNamespace("renv", quietly = TRUE)) {
    log_fn("renv package unavailable", level = "error", force = TRUE)
    return(if (config$fail_on_issues) 1L else 0L)
  }
  
  result <- run_renv_snapshot(force_clean = FALSE, log_fn = log_fn)
  if (result$success) {
    log_fn("Snapshot complete", level = "success")
    return(0L)
  } else {
    log_fn("Snapshot failed: ", result$message, level = "error", force = TRUE)
    return(if (config$fail_on_issues) 1L else 0L)
  }
}

# Main analysis and reporting function
main_analysis <- function(config, log_fn) {
  log_fn("Checking renv setup...", level = "info")
  
  # Step 1: Extract packages from code
  code_packages <- extract_code_packages(config, log_fn)
  
  # Step 2: Parse configuration files
  desc_result <- parse_description_file()
  renv_result <- parse_renv_lock_file()
  
  # Step 3: Validate all packages against CRAN in single call
  all_packages_to_validate <- unique(c(code_packages, desc_result$packages))
  cran_validation <- validate_against_cran(all_packages_to_validate, log_fn)
  
  # Step 4: Determine package status
  validated_code_packages <- intersect(code_packages, cran_validation$valid)
  validated_desc_packages <- intersect(desc_result$packages, cran_validation$valid)
  invalid_desc_packages <- intersect(desc_result$packages, cran_validation$invalid)
  
  # Step 5: Analysis results
  missing_from_desc <- setdiff(validated_code_packages, validated_desc_packages)
  unused_in_desc <- setdiff(validated_desc_packages, validated_code_packages)
  extra_in_renv <- setdiff(renv_result$packages, desc_result$packages)
  
  # Step 6: Determine critical issues
  has_critical_issues <- length(missing_from_desc) > 0L || 
                        length(invalid_desc_packages) > 0L || 
                        desc_result$error || 
                        renv_result$error
  
  # Step 7: Report findings
  log_fn("Found ", length(validated_code_packages), " valid code packages, ", 
         length(desc_result$packages), " DESCRIPTION packages, ",
         length(renv_result$packages), " renv.lock packages", level = "info")
  
  if (length(missing_from_desc) > 0L) {
    log_fn("Missing from DESCRIPTION: ", paste(sort(missing_from_desc), collapse = ", "), 
           level = "error", force = TRUE)
  }
  
  if (length(invalid_desc_packages) > 0L) {
    log_fn("Invalid packages in DESCRIPTION: ", paste(sort(invalid_desc_packages), collapse = ", "), 
           level = "error", force = TRUE)
  }
  
  if (length(unused_in_desc) > 0L && !config$strict_imports) {
    log_fn("Unused packages in DESCRIPTION: ", length(unused_in_desc), " packages", level = "warning")
  }
  
  if (length(extra_in_renv) > 0L) {
    log_fn("Extra packages in renv.lock: ", length(extra_in_renv), " packages", level = "warning")
  }
  
  # Step 8: Handle fixes if requested
  if (has_critical_issues && config$auto_fix) {
    log_fn("Auto-fixing issues...", level = "info")
    fix_result <- fix_description_file(missing_from_desc, invalid_desc_packages, log_fn)
    if (fix_result$success) {
      snapshot_result <- run_renv_snapshot(force_clean = length(extra_in_renv) > 0L, log_fn = log_fn)
      if (!snapshot_result$success) {
        log_fn("Warning: ", snapshot_result$message, level = "warning")
      }
    }
  } else if (has_critical_issues && interactive()) {
    cat("Fix detected issues? [y/N]: ")
    response <- tolower(trimws(readLines(n = 1L)))
    if (response %in% c("y", "yes")) {
      fix_result <- fix_description_file(missing_from_desc, invalid_desc_packages, log_fn)
      if (fix_result$success) {
        run_renv_snapshot(force_clean = length(extra_in_renv) > 0L, log_fn = log_fn)
      }
    }
  } else if (length(extra_in_renv) > 0L && config$auto_fix) {
    run_renv_snapshot(force_clean = TRUE, log_fn = log_fn)
  }
  
  # Step 9: Final status
  if (has_critical_issues) {
    log_fn("Repository NOT READY for commit", level = "error", force = TRUE)
    return(1L)
  } else {
    log_fn("Repository READY for commit", level = "success", force = TRUE)
    return(0L)
  }
}

# Main entry point
main <- function() {
  # Parse configuration
  config <- parse_arguments()
  log_fn <- create_logger(config)
  
  # Handle snapshot-only mode
  if (config$snapshot_only) {
    exit_code <- handle_snapshot_only(config, log_fn)
    quit(status = exit_code)
  }
  
  # Run main analysis
  exit_code <- main_analysis(config, log_fn)
  
  # Show usage help for non-interactive runs
  if (!config$quiet && length(commandArgs(trailingOnly = TRUE)) == 0L && !interactive()) {
    cat("\n📖 USAGE: --fix --fail-on-issues --snapshot --quiet --strict-imports\n")
    cat("For detailed help, see script header documentation.\n")
  }
  
  # Exit with appropriate code
  if (config$fail_on_issues && exit_code != 0L) {
    quit(status = exit_code)
  }
  
  invisible(exit_code)
}

# Execute main function
main()