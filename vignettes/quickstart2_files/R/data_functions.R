#' Prepare mtcars data for analysis
#'
#' @param data A data frame with mtcars structure
#' @return A data frame with additional computed columns
#' @export
add_derived_variables <- function(data) {
  if (!all(c("mpg", "wt", "hp") %in% names(data))) {
    stop("Input must contain mpg, wt, and hp columns")
  }

  data |>
    dplyr::mutate(
      efficiency_class = dplyr::case_when(
        mpg >= 20 ~ "high",
        mpg >= 15 ~ "medium",
        TRUE ~ "low"
      ),
      weight_kg = wt * 453.592,
      power_to_weight = hp / wt
    )
}

#' Validate mtcars data structure
#'
#' @param data A data frame to validate
#' @return TRUE if valid, throws error otherwise
#' @export
validate_mtcars_data <- function(data) {
  required_cols <- c("mpg", "cyl", "disp", "hp", "drat", "wt",
                     "qsec", "vs", "am", "gear", "carb")

  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  if (nrow(data) == 0) {
    stop("Data frame is empty")
  }

  if (any(data$mpg <= 0, na.rm = TRUE)) {
    stop("mpg must be positive")
  }

  if (any(data$hp <= 0, na.rm = TRUE)) {
    stop("hp must be positive")
  }

  TRUE
}
