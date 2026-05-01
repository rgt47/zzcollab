#' Create power-to-weight scatter plot
#'
#' @param data Processed mtcars data frame
#' @param show_labels Logical, whether to show car labels
#' @return A ggplot object
#' @export
plot_power_weight <- function(data, show_labels = TRUE) {
  if (!"power_to_weight" %in% names(data)) {
    stop("Data must contain power_to_weight column")
  }

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = weight_kg, y = hp, color = efficiency_class)
  ) +
    ggplot2::geom_point(size = 3, alpha = 0.8) +
    ggplot2::labs(
      title = "Horsepower vs Weight by Efficiency Class",
      x = "Weight (kg)",
      y = "Horsepower",
      color = "Efficiency"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "bottom")

  if (show_labels) {
    p <- p + ggplot2::geom_text(
      ggplot2::aes(label = rownames(data)),
      hjust = -0.1,
      vjust = 0.5,
      size = 3
    )
  }

  p
}

#' Create cylinder comparison boxplot
#'
#' @param data Processed mtcars data frame
#' @return A ggplot object
#' @export
plot_mpg_by_cylinder <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = factor(cyl), y = mpg)) +
    ggplot2::geom_boxplot(fill = "steelblue", alpha = 0.7) +
    ggplot2::geom_jitter(width = 0.2, alpha = 0.5) +
    ggplot2::labs(
      title = "Fuel Efficiency by Number of Cylinders",
      x = "Number of Cylinders",
      y = "Miles Per Gallon"
    ) +
    ggplot2::theme_minimal()
}
