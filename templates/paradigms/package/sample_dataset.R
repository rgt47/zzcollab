# Sample Dataset for {{PACKAGE_NAME}}
# This file creates example datasets included with the package

#' Sample Research Dataset
#'
#' A synthetic dataset created for demonstrating package functionality.
#' This dataset simulates a typical research scenario with measurements,
#' grouping variables, and realistic patterns including missing data.
#'
#' @format A data frame with 200 rows and 7 variables:
#' \describe{
#'   \item{id}{integer. Unique identifier for each observation (1-200)}
#'   \item{measurement_a}{numeric. Primary measurement variable with normal distribution (mean=50, sd=10)}
#'   \item{measurement_b}{numeric. Secondary measurement variable with normal distribution (mean=100, sd=15)}
#'   \item{measurement_c}{numeric. Tertiary measurement variable with some extreme values}
#'   \item{group}{factor. Categorical grouping variable with levels: "Control", "Treatment1", "Treatment2"}
#'   \item{batch}{factor. Batch identifier with levels: "Batch_A", "Batch_B", "Batch_C", "Batch_D"}
#'   \item{date_collected}{Date. Collection date ranging from 2023-01-01 to 2023-12-31}
#' }
#'
#' @details
#' This dataset was created to demonstrate typical data analysis workflows
#' including:
#' - Summary statistics computation
#' - Group comparisons
#' - Missing data handling (approximately 5% missing values)
#' - Quality assessment procedures
#' - Visualization techniques
#'
#' The data includes realistic patterns:
#' - Treatment groups show different effect sizes
#' - Batch effects are simulated
#' - Missing data follows realistic patterns (not completely random)
#' - Measurement correlations reflect typical research scenarios
#'
#' @source Generated synthetically for package demonstration purposes.
#'   Created using reproducible random number generation with seed 12345.
#'
#' @examples
#' # Load the dataset
#' data(sample_research_data)
#'
#' # Basic structure
#' str(sample_research_data)
#' summary(sample_research_data)
#'
#' # Quick analysis using package functions
#' library({{PACKAGE_NAME}})
#' summary_stats <- summarize_data(sample_research_data)
#' print(summary_stats)
#'
#' # Group-wise analysis
#' if (requireNamespace("dplyr", quietly = TRUE)) {
#'   library(dplyr)
#'   group_summary <- sample_research_data %>%
#'     group_by(group) %>%
#'     summarise(
#'       n = n(),
#'       mean_a = mean(measurement_a, na.rm = TRUE),
#'       mean_b = mean(measurement_b, na.rm = TRUE)
#'     )
#'   print(group_summary)
#' }
#'
#' @seealso
#' \code{\link{summarize_data}} for analyzing this dataset
#' \code{\link{small_test_data}} for a smaller example dataset
"sample_research_data"

#' Small Test Dataset
#'
#' A minimal dataset for testing and quick examples. Contains clean data
#' with no missing values, suitable for demonstrating basic functionality.
#'
#' @format A data frame with 20 rows and 4 variables:
#' \describe{
#'   \item{x}{numeric. Simple sequence from 1 to 20}
#'   \item{y}{numeric. Values from 21 to 40 (x + 20)}
#'   \item{category}{character. Alternating "A" and "B" values}
#'   \item{score}{numeric. Random values between 0 and 100}
#' }
#'
#' @details
#' This dataset is designed for:
#' - Quick function testing
#' - Documentation examples
#' - Unit tests
#' - Simple demonstrations
#'
#' All values are non-missing and follow simple patterns for predictable results.
#'
#' @source Generated for package testing and examples.
#'
#' @examples
#' # Load the dataset
#' data(small_test_data)
#'
#' # View the data
#' print(small_test_data)
#'
#' # Quick summary
#' library({{PACKAGE_NAME}})
#' quick_summary <- summarize_data(small_test_data)
#' print(quick_summary)
#'
#' @seealso \code{\link{sample_research_data}} for a larger, more realistic dataset
"small_test_data"

# Create the actual datasets (this code runs when the package is built)

# Set reproducible seed
set.seed(12345)

# Create sample_research_data
n_obs <- 200

sample_research_data <- data.frame(
  id = 1:n_obs,

  # Primary measurements with realistic distributions
  measurement_a = rnorm(n_obs, mean = 50, sd = 10),
  measurement_b = rnorm(n_obs, mean = 100, sd = 15),
  measurement_c = rnorm(n_obs, mean = 75, sd = 12),

  # Grouping variables
  group = factor(sample(c("Control", "Treatment1", "Treatment2"),
                       n_obs, replace = TRUE, prob = c(0.4, 0.3, 0.3))),
  batch = factor(sample(c("Batch_A", "Batch_B", "Batch_C", "Batch_D"),
                       n_obs, replace = TRUE)),

  # Date variable
  date_collected = sample(seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "day"),
                         n_obs, replace = TRUE)
)

# Add treatment effects
treatment1_indices <- which(sample_research_data$group == "Treatment1")
treatment2_indices <- which(sample_research_data$group == "Treatment2")

# Treatment1 increases measurement_a by 5 units on average
sample_research_data$measurement_a[treatment1_indices] <-
  sample_research_data$measurement_a[treatment1_indices] + rnorm(length(treatment1_indices), 5, 2)

# Treatment2 increases measurement_a by 10 units on average
sample_research_data$measurement_a[treatment2_indices] <-
  sample_research_data$measurement_a[treatment2_indices] + rnorm(length(treatment2_indices), 10, 3)

# Add batch effects for measurement_b
batch_effects <- c("Batch_A" = 0, "Batch_B" = 5, "Batch_C" = -3, "Batch_D" = 2)
for (batch in names(batch_effects)) {
  batch_indices <- which(sample_research_data$batch == batch)
  sample_research_data$measurement_b[batch_indices] <-
    sample_research_data$measurement_b[batch_indices] + batch_effects[batch]
}

# Add some correlation between measurements
sample_research_data$measurement_c <-
  0.3 * sample_research_data$measurement_a +
  0.2 * sample_research_data$measurement_b +
  rnorm(n_obs, 0, 8)

# Add realistic missing data patterns (about 5% missing)
missing_indices_a <- sample(1:n_obs, size = round(0.03 * n_obs))
missing_indices_b <- sample(1:n_obs, size = round(0.02 * n_obs))
missing_indices_c <- sample(1:n_obs, size = round(0.05 * n_obs))

sample_research_data$measurement_a[missing_indices_a] <- NA
sample_research_data$measurement_b[missing_indices_b] <- NA
sample_research_data$measurement_c[missing_indices_c] <- NA

# Add some extreme values to measurement_c
extreme_indices <- sample(1:n_obs, size = 3)
sample_research_data$measurement_c[extreme_indices] <- c(150, -20, 200)

# Create small_test_data
small_test_data <- data.frame(
  x = 1:20,
  y = 21:40,
  category = rep(c("A", "B"), 10),
  score = round(runif(20, 0, 100), 1)
)

# Save datasets for package inclusion
# Note: In actual package development, these would be saved to data/ directory
# using usethis::use_data()

# Example of how to save data in package development:
# usethis::use_data(sample_research_data, overwrite = TRUE)
# usethis::use_data(small_test_data, overwrite = TRUE)