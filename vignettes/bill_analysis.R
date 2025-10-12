#' Create scatter plot of bill dimensions
#'
#' @param data Palmer penguins data
#' @return ggplot object
#' @export
create_bill_plot <- function(data = palmerpenguins::penguins) {
  data %>%
    dplyr::filter(!is.na(bill_length_mm), !is.na(bill_depth_mm)) %>%
    ggplot2::ggplot(ggplot2::aes(x = bill_length_mm, y = bill_depth_mm,
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
