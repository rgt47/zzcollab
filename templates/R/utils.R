#' Create AR(1) correlation matrix
#'
#' @param n_times Number of time points
#' @param rho Correlation parameter
#' @return A correlation matrix with AR(1) structure
#' @export
create_ar1_corr <- function(n_times, rho) {
  matrix(rho^abs(outer(1:n_times, 1:n_times, "-")), n_times, n_times)
}