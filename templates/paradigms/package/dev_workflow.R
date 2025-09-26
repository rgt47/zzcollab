# Package Development Workflow Script
# Package: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}

# This script provides a comprehensive development workflow for R package creation,
# testing, documentation, and release. It follows R package development best practices
# and automates common development tasks.

# Load required packages for development
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}

if (!requireNamespace("usethis", quietly = TRUE)) {
  install.packages("usethis")
}

library(devtools)
library(usethis)

# Set package development options
options(
  repos = c(CRAN = "https://cran.rstudio.com/"),
  usethis.full_name = "{{AUTHOR_NAME}} {{AUTHOR_LAST}}",
  usethis.description = list(
    `Authors@R` = utils::person(
      "{{AUTHOR_NAME}}", "{{AUTHOR_LAST}}",
      email = "{{AUTHOR_EMAIL}}",
      role = c("aut", "cre"),
      comment = c(ORCID = "{{AUTHOR_ORCID}}")
    ),
    License = "MIT + file LICENSE",
    Version = "0.0.0.9000"
  )
)

cat("=== {{PACKAGE_NAME}} Package Development Workflow ===\n")
cat("Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}\n")
cat("Date:", format(Sys.Date(), "%Y-%m-%d"), "\n\n")

# =============================================================================
# DEVELOPMENT WORKFLOW FUNCTIONS
# =============================================================================

#' Quick Development Check
#'
#' Performs a quick check of the package state including loading,
#' testing, and documentation status.
quick_check <- function() {
  cat("\n=== QUICK PACKAGE CHECK ===\n")

  # Load package
  cat("Loading package...")
  tryCatch({
    devtools::load_all()
    cat(" ✓ Package loaded successfully\n")
  }, error = function(e) {
    cat(" ✗ Error loading package:", e$message, "\n")
  })

  # Check documentation
  cat("Checking documentation...")
  tryCatch({
    devtools::document()
    cat(" ✓ Documentation updated\n")
  }, error = function(e) {
    cat(" ✗ Error updating documentation:", e$message, "\n")
  })

  # Run tests
  cat("Running tests...")
  tryCatch({
    test_results <- devtools::test()
    if (test_results$failed == 0) {
      cat(" ✓ All tests passed (", test_results$passed, " tests)\n")
    } else {
      cat(" ✗", test_results$failed, "tests failed\n")
    }
  }, error = function(e) {
    cat(" ✗ Error running tests:", e$message, "\n")
  })

  # Check package
  cat("Running R CMD check...")
  tryCatch({
    check_results <- devtools::check(quiet = TRUE)
    if (length(check_results$errors) == 0 && length(check_results$warnings) == 0) {
      cat(" ✓ Package check passed\n")
    } else {
      cat(" ⚠ Package check found issues\n")
      if (length(check_results$errors) > 0) {
        cat("   Errors:", length(check_results$errors), "\n")
      }
      if (length(check_results$warnings) > 0) {
        cat("   Warnings:", length(check_results$warnings), "\n")
      }
    }
  }, error = function(e) {
    cat(" ✗ Error running check:", e$message, "\n")
  })

  cat("\n=== QUICK CHECK COMPLETE ===\n")
}

#' Full Development Check
#'
#' Performs comprehensive package validation including all tests,
#' documentation checks, and CRAN-readiness assessment.
full_check <- function() {
  cat("\n=== COMPREHENSIVE PACKAGE VALIDATION ===\n")

  # Update documentation
  cat("1. Updating documentation...\n")
  devtools::document()

  # Install package dependencies
  cat("2. Installing dependencies...\n")
  devtools::install_deps()

  # Load package
  cat("3. Loading package...\n")
  devtools::load_all()

  # Run comprehensive tests
  cat("4. Running comprehensive tests...\n")
  test_results <- devtools::test()
  cat("   Tests passed:", test_results$passed, "\n")
  cat("   Tests failed:", test_results$failed, "\n")

  if (test_results$failed > 0) {
    cat("   ⚠ Fix failing tests before proceeding\n")
    return(invisible(FALSE))
  }

  # Check test coverage
  if (requireNamespace("covr", quietly = TRUE)) {
    cat("5. Checking test coverage...\n")
    coverage <- covr::package_coverage()
    coverage_percent <- covr::percent_coverage(coverage)
    cat("   Test coverage:", round(coverage_percent, 1), "%\n")

    if (coverage_percent < 80) {
      cat("   ⚠ Consider improving test coverage (target: >80%)\n")
    } else {
      cat("   ✓ Good test coverage\n")
    }
  }

  # Spell check
  if (requireNamespace("spelling", quietly = TRUE)) {
    cat("6. Checking spelling...\n")
    spelling_errors <- spelling::spell_check_package()
    if (nrow(spelling_errors) == 0) {
      cat("   ✓ No spelling errors found\n")
    } else {
      cat("   ⚠", nrow(spelling_errors), "potential spelling errors found\n")
    }
  }

  # R CMD check
  cat("7. Running R CMD check...\n")
  check_results <- devtools::check()

  # Summarize results
  cat("\n=== VALIDATION SUMMARY ===\n")
  if (length(check_results$errors) == 0 && length(check_results$warnings) == 0) {
    cat("✓ Package passes all checks and is ready for release\n")
    return(invisible(TRUE))
  } else {
    cat("⚠ Package has issues that should be addressed:\n")
    if (length(check_results$errors) > 0) {
      cat("  Errors:", length(check_results$errors), "\n")
    }
    if (length(check_results$warnings) > 0) {
      cat("  Warnings:", length(check_results$warnings), "\n")
    }
    return(invisible(FALSE))
  }
}

#' Setup Package Infrastructure
#'
#' Sets up essential package infrastructure including testing,
#' documentation, and development tools.
setup_package_infrastructure <- function() {
  cat("\n=== SETTING UP PACKAGE INFRASTRUCTURE ===\n")

  # Setup testthat
  cat("1. Setting up testthat framework...\n")
  tryCatch({
    usethis::use_testthat()
    cat("   ✓ testthat framework initialized\n")
  }, error = function(e) {
    cat("   ⚠ testthat already setup or error occurred\n")
  })

  # Setup roxygen2
  cat("2. Configuring roxygen2 documentation...\n")
  tryCatch({
    usethis::use_roxygen_md()
    cat("   ✓ roxygen2 with markdown enabled\n")
  }, error = function(e) {
    cat("   ⚠ roxygen2 already configured or error occurred\n")
  })

  # Setup package-level documentation
  cat("3. Creating package documentation...\n")
  tryCatch({
    usethis::use_package_doc()
    cat("   ✓ Package-level documentation created\n")
  }, error = function(e) {
    cat("   ⚠ Package documentation already exists or error occurred\n")
  })

  # Setup README
  cat("4. Setting up README...\n")
  tryCatch({
    usethis::use_readme_rmd()
    cat("   ✓ README.Rmd created\n")
  }, error = function(e) {
    cat("   ⚠ README already exists or error occurred\n")
  })

  # Setup NEWS
  cat("5. Setting up NEWS file...\n")
  tryCatch({
    usethis::use_news_md()
    cat("   ✓ NEWS.md created\n")
  }, error = function(e) {
    cat("   ⚠ NEWS.md already exists or error occurred\n")
  })

  # Setup code coverage
  cat("6. Setting up code coverage...\n")
  tryCatch({
    usethis::use_coverage()
    cat("   ✓ Code coverage configured\n")
  }, error = function(e) {
    cat("   ⚠ Code coverage already configured or error occurred\n")
  })

  # Setup MIT license
  cat("7. Setting up MIT license...\n")
  tryCatch({
    usethis::use_mit_license()
    cat("   ✓ MIT license configured\n")
  }, error = function(e) {
    cat("   ⚠ License already configured or error occurred\n")
  })

  cat("\n=== INFRASTRUCTURE SETUP COMPLETE ===\n")
}

#' Build and Install Package
#'
#' Builds the package and installs it locally for testing.
build_and_install <- function(build_vignettes = TRUE) {
  cat("\n=== BUILDING AND INSTALLING PACKAGE ===\n")

  # Update documentation first
  cat("1. Updating documentation...\n")
  devtools::document()

  # Build package
  cat("2. Building package...\n")
  pkg_path <- devtools::build(vignettes = build_vignettes)
  cat("   Package built:", pkg_path, "\n")

  # Install package
  cat("3. Installing package...\n")
  devtools::install()
  cat("   ✓ Package installed successfully\n")

  # Test installation
  cat("4. Testing installation...\n")
  tryCatch({
    library({{PACKAGE_NAME}}, character.only = TRUE)
    cat("   ✓ Package loads correctly\n")
  }, error = function(e) {
    cat("   ✗ Error loading installed package:", e$message, "\n")
  })

  cat("\n=== BUILD AND INSTALL COMPLETE ===\n")
  return(invisible(pkg_path))
}

#' Release Readiness Check
#'
#' Performs final checks before package release to CRAN or other repositories.
release_check <- function() {
  cat("\n=== RELEASE READINESS CHECK ===\n")

  # Check version number
  desc <- read.dcf("DESCRIPTION")
  version <- desc[1, "Version"]
  cat("Current version:", version, "\n")

  if (grepl("9000$", version)) {
    cat("⚠ Development version detected. Consider updating version number for release.\n")
  }

  # Run comprehensive validation
  cat("\nRunning comprehensive validation...\n")
  validation_passed <- full_check()

  # Check for CRAN-specific requirements
  cat("\nChecking CRAN requirements...\n")

  # Check submission tools if available
  if (requireNamespace("rhub", quietly = TRUE)) {
    cat("Consider running rhub checks for CRAN submission:\n")
    cat("  rhub::check_for_cran()\n")
    cat("  rhub::check_on_windows()\n")
    cat("  rhub::check_on_macos()\n")
  }

  if (requireNamespace("winbuilder", quietly = TRUE)) {
    cat("Consider running win-builder check:\n")
    cat("  devtools::check_win_devel()\n")
    cat("  devtools::check_win_release()\n")
  }

  # Final recommendation
  if (validation_passed) {
    cat("\n✓ Package appears ready for release!\n")
    cat("Next steps:\n")
    cat("  1. Update version number if needed\n")
    cat("  2. Update NEWS.md with changes\n")
    cat("  3. Submit to CRAN or chosen repository\n")
  } else {
    cat("\n⚠ Package needs fixes before release\n")
    cat("Address validation issues and run release_check() again\n")
  }

  return(invisible(validation_passed))
}

# =============================================================================
# WORKFLOW SHORTCUTS
# =============================================================================

# Quick development iteration
dev_iterate <- function() {
  devtools::load_all()
  devtools::test()
}

# Update documentation and check
doc_check <- function() {
  devtools::document()
  devtools::check()
}

# Install package dependencies
install_dev_deps <- function() {
  devtools::install_deps(dependencies = TRUE)
}

# =============================================================================
# WORKFLOW MENU
# =============================================================================

#' Interactive Development Menu
#'
#' Provides an interactive menu for common package development tasks.
dev_menu <- function() {
  while (TRUE) {
    cat("\n=== {{PACKAGE_NAME}} DEVELOPMENT MENU ===\n")
    cat("1. Quick check (load, test, document)\n")
    cat("2. Full validation (comprehensive testing)\n")
    cat("3. Setup package infrastructure\n")
    cat("4. Build and install package\n")
    cat("5. Release readiness check\n")
    cat("6. Quick dev iteration (load + test)\n")
    cat("7. Update documentation\n")
    cat("8. Install dependencies\n")
    cat("0. Exit\n")
    cat("\nChoice: ")

    choice <- readline()

    switch(choice,
      "1" = quick_check(),
      "2" = full_check(),
      "3" = setup_package_infrastructure(),
      "4" = build_and_install(),
      "5" = release_check(),
      "6" = dev_iterate(),
      "7" = { devtools::document(); cat("Documentation updated\n") },
      "8" = install_dev_deps(),
      "0" = { cat("Goodbye!\n"); break },
      cat("Invalid choice. Please try again.\n")
    )
  }
}

# =============================================================================
# PACKAGE INFORMATION
# =============================================================================

cat("Package development workflow loaded.\n")
cat("Available functions:\n")
cat("  - quick_check(): Fast development check\n")
cat("  - full_check(): Comprehensive validation\n")
cat("  - setup_package_infrastructure(): Setup dev tools\n")
cat("  - build_and_install(): Build and install package\n")
cat("  - release_check(): Pre-release validation\n")
cat("  - dev_menu(): Interactive development menu\n")
cat("\nShortcuts:\n")
cat("  - dev_iterate(): Quick load + test\n")
cat("  - doc_check(): Document + check\n")
cat("  - install_dev_deps(): Install all dependencies\n")
cat("\nTo start: run dev_menu() for interactive workflow\n")