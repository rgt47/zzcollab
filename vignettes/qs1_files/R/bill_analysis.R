#' Create scatter plot of bill dimensions
#'
#' @param data Penguin data with bill measurements
#' @return ggplot object
#' @export
create_bill_plot <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x = bill_length_mm, y = bill_depth_mm,
                                      color = species)) +
    ggplot2::geom_point(size = 3, alpha = 0.7) +
    ggplot2::labs(
      title = 'Palmer Penguins: Bill Dimensions',
      x = 'Bill Length (mm)',
      y = 'Bill Depth (mm)',
      color = 'Species'
    ) +
    ggplot2::theme_minimal()
}
