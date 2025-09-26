# Example Analysis Functions for Data Analysis Projects
# Project: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}

#' Load and validate analysis data
#'
#' Loads data from the processed data directory with validation checks.
#' Ensures data integrity and provides informative error messages.
#'
#' @param file_name Character string of the file name in data/processed/
#' @param required_vars Optional character vector of required variable names
#' @return Data frame with validated data
#' @export
#' @examples
#' # Load processed dataset with validation
#' data <- load_analysis_data("cleaned_dataset.csv")
#'
#' # Load with required variables check
#' data <- load_analysis_data("cleaned_dataset.csv",
#'                           required_vars = c("outcome", "predictor1"))
load_analysis_data <- function(file_name, required_vars = NULL) {
  data_path <- here::here("data", "processed", file_name)

  if (!file.exists(data_path)) {
    stop("Data file not found: ", data_path)
  }

  # Load data based on file extension
  if (grepl("\\.csv$", file_name)) {
    data <- readr::read_csv(data_path, show_col_types = FALSE)
  } else if (grepl("\\.rds$", file_name)) {
    data <- readRDS(data_path)
  } else {
    stop("Unsupported file format. Use .csv or .rds files.")
  }

  # Validate required variables
  if (!is.null(required_vars)) {
    missing_vars <- setdiff(required_vars, names(data))
    if (length(missing_vars) > 0) {
      stop("Required variables not found: ", paste(missing_vars, collapse = ", "))
    }
  }

  message("Data loaded successfully: ", nrow(data), " rows, ", ncol(data), " columns")
  return(data)
}

#' Create comprehensive data quality report
#'
#' Generates a detailed data quality assessment including missing values,
#' outliers, data types, and basic descriptive statistics.
#'
#' @param data Data frame to assess
#' @param save_report Logical, whether to save report to analysis/exploratory/
#' @return List containing quality metrics
#' @export
#' @examples
#' quality_report <- create_quality_report(data, save_report = TRUE)
create_quality_report <- function(data, save_report = FALSE) {
  quality_metrics <- list(
    timestamp = Sys.time(),
    dimensions = list(rows = nrow(data), cols = ncol(data)),
    missing_data = sapply(data, function(x) sum(is.na(x))),
    missing_percent = sapply(data, function(x) round(sum(is.na(x)) / length(x) * 100, 2)),
    data_types = sapply(data, function(x) class(x)[1]),
    unique_values = sapply(data, function(x) length(unique(x[!is.na(x)]))),
    duplicate_rows = sum(duplicated(data))
  )

  # Add numeric variable summaries
  numeric_vars <- names(dplyr::select_if(data, is.numeric))
  if (length(numeric_vars) > 0) {
    numeric_summary <- data %>%
      dplyr::select(dplyr::all_of(numeric_vars)) %>%
      dplyr::summarise_all(list(
        mean = ~round(mean(., na.rm = TRUE), 3),
        median = ~round(median(., na.rm = TRUE), 3),
        sd = ~round(sd(., na.rm = TRUE), 3),
        min = ~round(min(., na.rm = TRUE), 3),
        max = ~round(max(., na.rm = TRUE), 3)
      ))
    quality_metrics$numeric_summary <- numeric_summary
  }

  # Identify potential data quality issues
  quality_issues <- list()

  # High missing data variables
  high_missing <- names(quality_metrics$missing_percent[quality_metrics$missing_percent > 20])
  if (length(high_missing) > 0) {
    quality_issues$high_missing_variables <- high_missing
  }

  # Variables with all unique values (potential IDs)
  all_unique <- names(quality_metrics$unique_values[quality_metrics$unique_values == nrow(data)])
  if (length(all_unique) > 0) {
    quality_issues$potential_id_variables <- all_unique
  }

  # Duplicate rows
  if (quality_metrics$duplicate_rows > 0) {
    quality_issues$duplicate_rows <- quality_metrics$duplicate_rows
  }

  quality_metrics$quality_issues <- quality_issues

  if (save_report) {
    output_dir <- here::here("analysis", "exploratory")
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }
    saveRDS(quality_metrics, file.path(output_dir, "data_quality_report.rds"))
    message("Quality report saved to: analysis/exploratory/data_quality_report.rds")
  }

  return(quality_metrics)
}

#' Generate correlation analysis with significance tests
#'
#' Performs correlation analysis between numeric variables with statistical
#' significance testing and multiple comparison correction.
#'
#' @param data Data frame containing numeric variables
#' @param method Correlation method: "pearson", "spearman", or "kendall"
#' @param alpha Significance level for correlation tests
#' @return List containing correlation matrix, p-values, and significant correlations
#' @export
#' @examples
#' cor_results <- analyze_correlations(data, method = "pearson")
#' print(cor_results$significant_correlations)
analyze_correlations <- function(data, method = "pearson", alpha = 0.05) {
  numeric_data <- dplyr::select_if(data, is.numeric)

  if (ncol(numeric_data) < 2) {
    stop("Need at least 2 numeric variables for correlation analysis")
  }

  # Calculate correlation matrix
  cor_matrix <- cor(numeric_data, use = "complete.obs", method = method)

  # Calculate p-values
  n <- nrow(numeric_data)
  cor_test_results <- Hmisc::rcorr(as.matrix(numeric_data), type = method)
  p_values <- cor_test_results$P

  # Apply multiple comparison correction
  p_values_adj <- p.adjust(p_values[upper.tri(p_values)], method = "fdr")

  # Create results data frame
  cor_results <- expand.grid(
    var1 = colnames(cor_matrix),
    var2 = colnames(cor_matrix),
    stringsAsFactors = FALSE
  ) %>%
    dplyr::filter(var1 != var2) %>%
    dplyr::mutate(
      correlation = mapply(function(v1, v2) cor_matrix[v1, v2], var1, var2),
      p_value = mapply(function(v1, v2) p_values[v1, v2], var1, var2)
    ) %>%
    dplyr::arrange(desc(abs(correlation)))

  # Add adjusted p-values (approximate mapping)
  cor_results$p_value_adj <- p.adjust(cor_results$p_value, method = "fdr")

  # Identify significant correlations
  significant_cors <- cor_results %>%
    dplyr::filter(p_value_adj < alpha, !is.na(p_value_adj)) %>%
    dplyr::arrange(desc(abs(correlation)))

  results <- list(
    correlation_matrix = cor_matrix,
    correlation_results = cor_results,
    significant_correlations = significant_cors,
    method = method,
    alpha = alpha,
    n_observations = n
  )

  return(results)
}

#' Create standardized visualization theme
#'
#' Returns a ggplot2 theme optimized for analysis reports and presentations.
#' Ensures consistent styling across all generated plots.
#'
#' @param base_size Base font size for the theme
#' @param grid_color Color for grid lines
#' @return ggplot2 theme object
#' @export
#' @examples
#' library(ggplot2)
#' p <- ggplot(data, aes(x = var1, y = var2)) +
#'   geom_point() +
#'   theme_analysis()
theme_analysis <- function(base_size = 11, grid_color = "grey90") {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      # Plot title and subtitle
      plot.title = ggplot2::element_text(size = base_size + 3, face = "bold", margin = ggplot2::margin(b = 10)),
      plot.subtitle = ggplot2::element_text(size = base_size + 1, margin = ggplot2::margin(b = 15)),
      plot.caption = ggplot2::element_text(size = base_size - 1, color = "grey50", hjust = 0),

      # Axes
      axis.title = ggplot2::element_text(size = base_size, face = "bold"),
      axis.text = ggplot2::element_text(size = base_size - 1),
      axis.line = ggplot2::element_line(color = "black", linewidth = 0.5),

      # Legend
      legend.title = ggplot2::element_text(size = base_size, face = "bold"),
      legend.text = ggplot2::element_text(size = base_size - 1),
      legend.position = "bottom",

      # Panel
      panel.grid.major = ggplot2::element_line(color = grid_color, linewidth = 0.3),
      panel.grid.minor = ggplot2::element_blank(),
      panel.border = ggplot2::element_rect(color = "black", fill = NA, linewidth = 0.5),

      # Strip (for facets)
      strip.text = ggplot2::element_text(size = base_size, face = "bold"),
      strip.background = ggplot2::element_rect(fill = "grey95", color = "black")
    )
}

#' Save plot with standardized format
#'
#' Saves ggplot objects with consistent formatting, file naming, and metadata.
#' Automatically saves both PNG and PDF versions for flexibility.
#'
#' @param plot ggplot2 object to save
#' @param filename Base filename (without extension)
#' @param width Plot width in inches
#' @param height Plot height in inches
#' @param dpi Resolution for PNG output
#' @return Invisible list of saved file paths
#' @export
#' @examples
#' p <- ggplot(data, aes(x = var1, y = var2)) + geom_point()
#' save_analysis_plot(p, "correlation_plot", width = 10, height = 6)
save_analysis_plot <- function(plot, filename, width = 10, height = 6, dpi = 300) {
  figures_dir <- here::here("outputs", "figures")
  if (!dir.exists(figures_dir)) {
    dir.create(figures_dir, recursive = TRUE)
  }

  # Clean filename
  filename <- gsub("[^A-Za-z0-9_-]", "_", filename)

  # Save PNG version
  png_path <- file.path(figures_dir, paste0(filename, ".png"))
  ggplot2::ggsave(
    filename = png_path,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    type = "cairo"
  )

  # Save PDF version
  pdf_path <- file.path(figures_dir, paste0(filename, ".pdf"))
  ggplot2::ggsave(
    filename = pdf_path,
    plot = plot,
    width = width,
    height = height,
    device = "pdf"
  )

  # Create metadata
  metadata <- list(
    filename = filename,
    created = Sys.time(),
    dimensions = list(width = width, height = height),
    dpi = dpi,
    r_version = R.version.string,
    files = c(png_path, pdf_path)
  )

  saveRDS(metadata, file.path(figures_dir, paste0(filename, "_metadata.rds")))

  message("Plot saved: ", basename(png_path), " and ", basename(pdf_path))
  return(invisible(metadata$files))
}

#' Generate analysis session documentation
#'
#' Creates comprehensive documentation of analysis session including
#' loaded packages, data sources, parameters, and computational environment.
#'
#' @param script_name Name of the analysis script
#' @param data_sources Character vector of data file paths used
#' @param parameters Named list of analysis parameters
#' @return List containing session documentation
#' @export
#' @examples
#' session_doc <- document_analysis_session(
#'   script_name = "exploratory_analysis.R",
#'   data_sources = c("data/processed/cleaned_data.csv"),
#'   parameters = list(alpha = 0.05, seed = 123)
#' )
document_analysis_session <- function(script_name, data_sources = NULL, parameters = NULL) {
  session_doc <- list(
    script_name = script_name,
    timestamp = Sys.time(),
    r_version = R.version.string,
    platform = R.version$platform,
    session_info = sessionInfo(),
    working_directory = getwd(),
    data_sources = data_sources,
    parameters = parameters,
    loaded_packages = search()[grepl("package:", search())],
    system_info = Sys.info()
  )

  # Add data source metadata if provided
  if (!is.null(data_sources)) {
    data_metadata <- lapply(data_sources, function(path) {
      if (file.exists(path)) {
        list(
          file = path,
          size = file.size(path),
          modified = file.mtime(path),
          exists = TRUE
        )
      } else {
        list(
          file = path,
          exists = FALSE
        )
      }
    })
    names(data_metadata) <- basename(data_sources)
    session_doc$data_metadata <- data_metadata
  }

  return(session_doc)
}