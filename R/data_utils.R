#' Load processed penguin data
#'
#' @param path Path to clean data file
#' @return data.frame of processed penguin data
#' @export
load_penguin_data <- function(path = "analysis/data/derived_data/penguins_clean.csv") {
  if (!file.exists(path)) {
    stop("Clean data file not found. Run analysis/scripts/01_process_data.R first.")
  }

  data <- read.csv(path, stringsAsFactors = FALSE)

  # Validate expected columns
  required_cols <- c("species", "bill_length_mm", "bill_depth_mm", "bill_ratio")
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  data
}

#' Calculate summary statistics by species
#'
#' @param data Penguin data
#' @return data.frame of summary statistics
#' @export
summarize_by_species <- function(data) {
  data |>
    dplyr::group_by(species) |>
    dplyr::summarize(
      n = dplyr::n(),
      mean_bill_length = mean(bill_length_mm, na.rm = TRUE),
      mean_bill_depth = mean(bill_depth_mm, na.rm = TRUE),
      mean_bill_ratio = mean(bill_ratio, na.rm = TRUE),
      .groups = "drop"
    )
}
