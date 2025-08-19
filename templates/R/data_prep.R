#' Prepare penguin subset data
#'
#' Takes the first n records from penguin data and adds log-transformed body mass
#' 
#' @param data A data frame containing penguin data with body_mass_g column
#' @param n_records Number of records to select (default: 50)
#' @param remove_na_mass Whether to remove records with missing body mass (default: TRUE)
#' @return A data frame with subset of records and log_body_mass_g column added
#' @export
#' @examples
#' \dontrun{
#' # Load sample data
#' penguins_raw <- read.csv(here::here("data", "raw_data", "penguins.csv"))
#' penguins_subset <- prepare_penguin_subset(penguins_raw, n_records = 50)
#' }
prepare_penguin_subset <- function(data, n_records = 50, remove_na_mass = TRUE) {
  # Input validation
  if (!is.data.frame(data)) {
    stop("Input 'data' must be a data frame")
  }
  
  if (!"body_mass_g" %in% names(data)) {
    stop("Data must contain 'body_mass_g' column")
  }
  
  if (!is.numeric(n_records) || n_records <= 0) {
    stop("n_records must be a positive number")
  }
  
  if (nrow(data) < n_records) {
    warning(paste("Data has", nrow(data), "rows but", n_records, "requested. Using all available rows."))
    n_records <- nrow(data)
  }
  
  # Select first n records
  result <- utils::head(data, n_records)
  
  # Remove missing body mass if requested
  if (remove_na_mass) {
    initial_rows <- nrow(result)
    result <- result[!is.na(result$body_mass_g), ]
    removed_rows <- initial_rows - nrow(result)
    
    if (removed_rows > 0) {
      message(paste("Removed", removed_rows, "rows with missing body_mass_g"))
    }
  }
  
  # Add log transformation
  result$log_body_mass_g <- log(result$body_mass_g)
  
  return(result)
}

#' Validate penguin data structure
#'
#' Checks if data contains expected penguin columns and data types
#'
#' @param data A data frame to validate
#' @param required_columns Character vector of required column names
#' @return Logical indicating if data is valid, with attributes for details
#' @export
validate_penguin_data <- function(data, required_columns = c("species", "island", "bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g", "sex", "year")) {
  
  if (!is.data.frame(data)) {
    attr(data, "validation_errors") <- "Input is not a data frame"
    return(FALSE)
  }
  
  errors <- character(0)
  
  # Check required columns
  missing_cols <- setdiff(required_columns, names(data))
  if (length(missing_cols) > 0) {
    errors <- c(errors, paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # Check data types for numeric columns
  numeric_cols <- c("bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g", "year")
  for (col in intersect(numeric_cols, names(data))) {
    if (!is.numeric(data[[col]])) {
      errors <- c(errors, paste("Column", col, "should be numeric but is", class(data[[col]])[1]))
    }
  }
  
  # Check for reasonable value ranges
  if ("body_mass_g" %in% names(data)) {
    if (any(data$body_mass_g <= 0, na.rm = TRUE)) {
      errors <- c(errors, "body_mass_g contains non-positive values")
    }
    if (any(data$body_mass_g > 10000, na.rm = TRUE)) {
      errors <- c(errors, "body_mass_g contains unreasonably large values (>10000g)")
    }
  }
  
  # Check species values
  if ("species" %in% names(data)) {
    expected_species <- c("Adelie", "Chinstrap", "Gentoo")
    unexpected_species <- setdiff(unique(data$species[!is.na(data$species)]), expected_species)
    if (length(unexpected_species) > 0) {
      errors <- c(errors, paste("Unexpected species values:", paste(unexpected_species, collapse = ", ")))
    }
  }
  
  if (length(errors) > 0) {
    attr(data, "validation_errors") <- errors
    return(FALSE)
  }
  
  return(TRUE)
}

#' Calculate summary statistics for penguin data
#'
#' @param data A data frame containing penguin data
#' @param group_by Character vector of columns to group by (optional)
#' @return A data frame with summary statistics
#' @export
summarize_penguin_data <- function(data, group_by = NULL) {
  if (!validate_penguin_data(data)) {
    stop("Data validation failed: ", paste(attr(data, "validation_errors"), collapse = "; "))
  }
  
  numeric_cols <- c("bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g")
  available_cols <- intersect(numeric_cols, names(data))
  
  if (is.null(group_by)) {
    # Overall summary
    summary_stats <- data.frame(
      variable = available_cols,
      n = sapply(available_cols, function(col) sum(!is.na(data[[col]]))),
      mean = sapply(available_cols, function(col) mean(data[[col]], na.rm = TRUE)),
      sd = sapply(available_cols, function(col) stats::sd(data[[col]], na.rm = TRUE)),
      min = sapply(available_cols, function(col) min(data[[col]], na.rm = TRUE)),
      max = sapply(available_cols, function(col) max(data[[col]], na.rm = TRUE)),
      stringsAsFactors = FALSE
    )
  } else {
    # Grouped summary (simplified version)
    summary_stats <- aggregate(
      data[available_cols],
      by = data[group_by],
      FUN = function(x) c(mean = mean(x, na.rm = TRUE), n = sum(!is.na(x))),
      simplify = FALSE
    )
  }
  
  return(summary_stats)
}