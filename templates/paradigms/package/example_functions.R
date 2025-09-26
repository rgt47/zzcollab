# Example Package Functions
# Package: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}

#' Hello World Function
#'
#' A simple example function that demonstrates proper roxygen2 documentation
#' and package development best practices.
#'
#' @param name Character string. The name to greet. Default is "World".
#' @param exclaim Logical. Whether to add an exclamation mark. Default is TRUE.
#' @param capitalize Logical. Whether to capitalize the greeting. Default is FALSE.
#'
#' @return A character string containing the greeting message.
#'
#' @details
#' This function serves as a template for creating well-documented package functions.
#' It demonstrates:
#' - Proper parameter documentation with types and defaults
#' - Input validation with informative error messages
#' - Clear return value specification
#' - Usage examples in multiple scenarios
#' - Internal helper function usage
#'
#' @examples
#' # Basic usage
#' hello_world()
#'
#' # Customize the greeting
#' hello_world("Alice")
#' hello_world("Bob", exclaim = FALSE)
#' hello_world("Charlie", capitalize = TRUE)
#'
#' # Multiple names
#' names <- c("Alice", "Bob", "Charlie")
#' sapply(names, hello_world)
#'
#' @seealso
#' \code{\link{goodbye_world}} for the complementary farewell function
#'
#' @export
hello_world <- function(name = "World", exclaim = TRUE, capitalize = FALSE) {
  # Input validation
  if (!is.character(name) || length(name) != 1) {
    stop("'name' must be a character string of length 1", call. = FALSE)
  }

  if (!is.logical(exclaim) || length(exclaim) != 1) {
    stop("'exclaim' must be a logical value of length 1", call. = FALSE)
  }

  if (!is.logical(capitalize) || length(capitalize) != 1) {
    stop("'capitalize' must be a logical value of length 1", call. = FALSE)
  }

  # Create greeting using internal helper
  greeting <- create_greeting("Hello", name, exclaim, capitalize)

  return(greeting)
}

#' Goodbye World Function
#'
#' A complementary farewell function that demonstrates function families
#' and consistent API design within a package.
#'
#' @param name Character string. The name to bid farewell. Default is "World".
#' @param exclaim Logical. Whether to add an exclamation mark. Default is TRUE.
#' @param capitalize Logical. Whether to capitalize the farewell. Default is FALSE.
#'
#' @return A character string containing the farewell message.
#'
#' @examples
#' # Basic usage
#' goodbye_world()
#'
#' # Customize the farewell
#' goodbye_world("Alice", exclaim = FALSE)
#' goodbye_world("Team", capitalize = TRUE)
#'
#' @family greeting functions
#' @seealso \code{\link{hello_world}}
#' @export
goodbye_world <- function(name = "World", exclaim = TRUE, capitalize = FALSE) {
  # Input validation (could be refactored to shared validation function)
  if (!is.character(name) || length(name) != 1) {
    stop("'name' must be a character string of length 1", call. = FALSE)
  }

  if (!is.logical(exclaim) || length(exclaim) != 1) {
    stop("'exclaim' must be a logical value of length 1", call. = FALSE)
  }

  if (!is.logical(capitalize) || length(capitalize) != 1) {
    stop("'capitalize' must be a logical value of length 1", call. = FALSE)
  }

  # Create farewell using internal helper
  greeting <- create_greeting("Goodbye", name, exclaim, capitalize)

  return(greeting)
}

#' Add Numbers with Validation
#'
#' Demonstrates numeric computation with comprehensive input validation
#' and error handling following R package best practices.
#'
#' @param x Numeric vector. First set of numbers to add.
#' @param y Numeric vector. Second set of numbers to add.
#' @param na.rm Logical. Should missing values be removed? Default is FALSE.
#'
#' @return Numeric vector containing the element-wise sum of x and y.
#'
#' @details
#' This function performs element-wise addition with proper recycling rules
#' and handles missing values according to the na.rm parameter.
#'
#' If \code{na.rm = TRUE}, missing values are treated as 0 in the addition.
#' If \code{na.rm = FALSE} (default), any missing values result in NA output.
#'
#' @examples
#' # Basic addition
#' add_numbers(1:5, 6:10)
#'
#' # With recycling
#' add_numbers(c(1, 2, 3), 10)
#'
#' # Handling missing values
#' add_numbers(c(1, NA, 3), c(4, 5, 6))
#' add_numbers(c(1, NA, 3), c(4, 5, 6), na.rm = TRUE)
#'
#' @export
add_numbers <- function(x, y, na.rm = FALSE) {
  # Input validation
  if (!is.numeric(x)) {
    stop("'x' must be numeric", call. = FALSE)
  }

  if (!is.numeric(y)) {
    stop("'y' must be numeric", call. = FALSE)
  }

  if (!is.logical(na.rm) || length(na.rm) != 1) {
    stop("'na.rm' must be a logical value of length 1", call. = FALSE)
  }

  # Handle missing values if requested
  if (na.rm) {
    x[is.na(x)] <- 0
    y[is.na(y)] <- 0
  }

  # Perform addition (R handles recycling automatically)
  result <- x + y

  return(result)
}

#' Data Summary with Custom Options
#'
#' Creates customizable data summaries demonstrating data.frame handling,
#' parameter validation, and flexible output formatting.
#'
#' @param data A data.frame to summarize.
#' @param columns Character vector of column names to include. If NULL (default),
#'   all numeric columns are included.
#' @param stats Character vector of statistics to compute. Options include
#'   "mean", "median", "sd", "min", "max", "n", "missing". Default is all.
#' @param round_digits Integer. Number of decimal places for rounding. Default is 2.
#'
#' @return A data.frame containing the requested summary statistics.
#'
#' @examples
#' # Using built-in dataset
#' data("mtcars")
#'
#' # Basic summary
#' summarize_data(mtcars)
#'
#' # Custom columns and statistics
#' summarize_data(mtcars,
#'                columns = c("mpg", "hp", "wt"),
#'                stats = c("mean", "sd", "n"))
#'
#' # High precision
#' summarize_data(mtcars, round_digits = 4)
#'
#' @import dplyr
#' @export
summarize_data <- function(data, columns = NULL,
                          stats = c("mean", "median", "sd", "min", "max", "n", "missing"),
                          round_digits = 2) {
  # Input validation
  if (!is.data.frame(data)) {
    stop("'data' must be a data.frame", call. = FALSE)
  }

  if (nrow(data) == 0) {
    stop("'data' must have at least one row", call. = FALSE)
  }

  if (!is.null(columns)) {
    if (!is.character(columns)) {
      stop("'columns' must be a character vector", call. = FALSE)
    }

    missing_cols <- setdiff(columns, names(data))
    if (length(missing_cols) > 0) {
      stop("Columns not found in data: ", paste(missing_cols, collapse = ", "), call. = FALSE)
    }
  }

  # Validate statistics
  valid_stats <- c("mean", "median", "sd", "min", "max", "n", "missing")
  invalid_stats <- setdiff(stats, valid_stats)
  if (length(invalid_stats) > 0) {
    stop("Invalid statistics: ", paste(invalid_stats, collapse = ", "),
         "\nValid options: ", paste(valid_stats, collapse = ", "), call. = FALSE)
  }

  if (!is.numeric(round_digits) || length(round_digits) != 1 || round_digits < 0) {
    stop("'round_digits' must be a non-negative integer", call. = FALSE)
  }

  # Select columns
  if (is.null(columns)) {
    numeric_data <- dplyr::select_if(data, is.numeric)
    if (ncol(numeric_data) == 0) {
      stop("No numeric columns found in data", call. = FALSE)
    }
  } else {
    numeric_data <- data[, columns, drop = FALSE]
    non_numeric <- !sapply(numeric_data, is.numeric)
    if (any(non_numeric)) {
      warning("Non-numeric columns will be skipped: ",
              paste(names(numeric_data)[non_numeric], collapse = ", "))
      numeric_data <- numeric_data[, !non_numeric, drop = FALSE]
    }
  }

  # Compute summary statistics
  summary_list <- list()

  for (col in names(numeric_data)) {
    col_stats <- list(variable = col)

    if ("n" %in% stats) {
      col_stats$n <- length(numeric_data[[col]])
    }

    if ("missing" %in% stats) {
      col_stats$missing <- sum(is.na(numeric_data[[col]]))
    }

    # Compute numeric statistics
    col_data <- numeric_data[[col]]
    if ("mean" %in% stats) {
      col_stats$mean <- round(mean(col_data, na.rm = TRUE), round_digits)
    }

    if ("median" %in% stats) {
      col_stats$median <- round(median(col_data, na.rm = TRUE), round_digits)
    }

    if ("sd" %in% stats) {
      col_stats$sd <- round(sd(col_data, na.rm = TRUE), round_digits)
    }

    if ("min" %in% stats) {
      col_stats$min <- round(min(col_data, na.rm = TRUE), round_digits)
    }

    if ("max" %in% stats) {
      col_stats$max <- round(max(col_data, na.rm = TRUE), round_digits)
    }

    summary_list[[col]] <- col_stats
  }

  # Convert to data.frame
  result <- do.call(rbind, lapply(summary_list, data.frame))
  rownames(result) <- NULL

  return(result)
}

# Internal helper functions (not exported)

#' Create Formatted Greeting (Internal)
#'
#' Internal helper function for creating consistent greeting messages.
#' This function is not exported and is used by hello_world() and goodbye_world().
#'
#' @param greeting_word Character string. The greeting word ("Hello", "Goodbye", etc.)
#' @param name Character string. The name to include in greeting.
#' @param exclaim Logical. Whether to add exclamation mark.
#' @param capitalize Logical. Whether to capitalize the greeting.
#'
#' @return Character string with formatted greeting.
#'
#' @keywords internal
create_greeting <- function(greeting_word, name, exclaim, capitalize) {
  # Create base message
  message <- paste(greeting_word, name)

  # Apply capitalization
  if (capitalize) {
    message <- toupper(message)
  }

  # Add exclamation if requested
  if (exclaim) {
    message <- paste0(message, "!")
  } else {
    message <- paste0(message, ".")
  }

  return(message)
}

#' Validate Package Arguments (Internal)
#'
#' Internal helper function for common argument validation patterns.
#' Reduces code duplication across package functions.
#'
#' @param arg The argument to validate
#' @param arg_name Character string. Name of the argument for error messages.
#' @param type Character string. Expected type ("character", "numeric", "logical")
#' @param length_one Logical. Whether argument must have length 1.
#'
#' @return Invisible NULL if validation passes, throws error if validation fails.
#'
#' @keywords internal
validate_argument <- function(arg, arg_name, type, length_one = TRUE) {
  # Type checking
  type_check_fun <- switch(type,
    "character" = is.character,
    "numeric" = is.numeric,
    "logical" = is.logical,
    stop("Unknown type: ", type)
  )

  if (!type_check_fun(arg)) {
    stop("'", arg_name, "' must be ", type, call. = FALSE)
  }

  # Length checking
  if (length_one && length(arg) != 1) {
    stop("'", arg_name, "' must have length 1", call. = FALSE)
  }

  invisible(NULL)
}