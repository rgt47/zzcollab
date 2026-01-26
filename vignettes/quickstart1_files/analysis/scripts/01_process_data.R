# Data Processing Script: Clean raw penguin data
# Input: analysis/data/raw_data/penguins_raw.csv
# Output: analysis/data/derived_data/penguins_clean.csv

library(dplyr)

# Load raw data
raw_data <- read.csv("analysis/data/raw_data/penguins_raw.csv")

# Process data
clean_data <- raw_data |>
  # Remove rows with missing values
  filter(!is.na(bill_length_mm), !is.na(bill_depth_mm)) |>
  # Add derived variables
  mutate(
    bill_ratio = bill_length_mm / bill_depth_mm,
    size_category = case_when(
      body_mass_g < 3500 ~ "small",
      body_mass_g < 4500 ~ "medium",
      TRUE ~ "large"
    )
  )

# Create output directory if needed
dir.create("analysis/data/derived_data", showWarnings = FALSE, recursive = TRUE)

# Save processed data
write.csv(clean_data, "analysis/data/derived_data/penguins_clean.csv",
          row.names = FALSE)

# Log processing results
cat("Processed", nrow(clean_data), "valid records from", nrow(raw_data),
    "raw records\n")
cat("Removed", nrow(raw_data) - nrow(clean_data), "incomplete records\n")
