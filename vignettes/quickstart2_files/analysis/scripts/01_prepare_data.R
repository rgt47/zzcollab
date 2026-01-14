# 01_prepare_data.R
# Purpose: Extract first half of mtcars and add derived variables

library(dplyr)

prepare_mtcars_data <- function(input_path, output_path) {
  raw_data <- read.csv(input_path, row.names = 1)

  n_rows <- nrow(raw_data)
  subset_data <- raw_data[1:(n_rows %/% 2), ]

  processed_data <- subset_data |>
    mutate(
      efficiency_class = case_when(
        mpg >= 20 ~ "high",
        mpg >= 15 ~ "medium",
        TRUE ~ "low"
      ),
      weight_kg = wt * 453.592,
      power_to_weight = hp / wt
    )

  saveRDS(processed_data, output_path)
  processed_data
}

if (sys.nframe() == 0) {
  prepare_mtcars_data(
    input_path = "analysis/data/raw_data/mtcars.csv",
    output_path = "analysis/data/derived_data/mtcars_processed.rds"
  )
}
