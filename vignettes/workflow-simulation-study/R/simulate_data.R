#' Generate correlated longitudinal binary data
#'
#' Simulates longitudinal binary outcomes with subject-specific random
#' effects following a logistic-normal model.
#'
#' @param n_subjects Number of subjects
#' @param n_timepoints Number of measurement occasions
#' @param beta Fixed effect coefficients (intercept, treatment, time,
#'   treatment:time)
#' @param sigma_b Standard deviation of random intercept
#' @param seed Random seed for reproducibility
#'
#' @return Data frame with columns: subject_id, time, treatment, y
#'
#' @export
#'
#' @examples
#' # Generate small dataset
#' data <- simulate_longitudinal_binary(n_subjects = 50, seed = 42)
#' head(data)
#'
#' # Specify custom parameters
#' data <- simulate_longitudinal_binary(
#'   n_subjects = 100,
#'   n_timepoints = 6,
#'   beta = c(-0.5, 0, 0.1, 0.4),
#'   sigma_b = 0.8,
#'   seed = 123
#' )
simulate_longitudinal_binary <- function(n_subjects,
                                         n_timepoints = 4,
                                         beta = c(-1, 0, 0.2, 0.3),
                                         sigma_b = 0.5,
                                         seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  if (length(beta) != 4) {
    stop("beta must have 4 elements: intercept, treatment, time, interaction")
  }

  if (n_subjects < 2) {
    stop("n_subjects must be at least 2")
  }

  if (n_timepoints < 2) {
    stop("n_timepoints must be at least 2")
  }

  if (sigma_b < 0) {
    stop("sigma_b must be non-negative")
  }

  subject_id <- rep(1:n_subjects, each = n_timepoints)
  time <- rep(0:(n_timepoints - 1), times = n_subjects)

  treatment <- rep(
    sample(c(0, 1), n_subjects, replace = TRUE),
    each = n_timepoints
  )

  random_intercept <- rep(
    rnorm(n_subjects, mean = 0, sd = sigma_b),
    each = n_timepoints
  )

  linear_predictor <- beta[1] +
    beta[2] * treatment +
    beta[3] * time +
    beta[4] * treatment * time +
    random_intercept

  prob <- plogis(linear_predictor)

  y <- rbinom(length(prob), size = 1, prob = prob)

  data.frame(
    subject_id = subject_id,
    time = time,
    treatment = factor(treatment, levels = c(0, 1),
                       labels = c("control", "treatment")),
    y = y
  )
}


#' Generate simulation scenarios
#'
#' Creates a data frame of all parameter combinations for the simulation.
#'
#' @param n_subjects Vector of sample sizes
#' @param beta_interaction Vector of treatment-by-time interaction effects
#' @param sigma_b Vector of random effect standard deviations
#' @param n_sims Number of simulations per scenario
#'
#' @return Data frame with one row per simulation replicate, containing:
#'
#' - scenario_id: Unique identifier for parameter combination
#' - sim_id: Simulation replicate number within scenario
#' - seed: Unique random seed for reproducibility
#' - n_subjects, beta_interaction, sigma_b: Parameter values
#'
#' @export
#'
#' @examples
#' # Small grid for testing
#' grid <- create_simulation_grid(
#'   n_subjects = c(50, 100),
#'   beta_interaction = c(0, 0.3),
#'   sigma_b = 0.5,
#'   n_sims = 10
#' )
#' nrow(grid)  # 40 rows (2 * 2 * 1 * 10)
create_simulation_grid <- function(n_subjects = c(50, 100, 200),
                                   beta_interaction = c(0, 0.3, 0.5),
                                   sigma_b = c(0.5, 1.0),
                                   n_sims = 1000) {
  if (any(n_subjects < 2)) {
    stop("All n_subjects values must be at least 2")
  }

  if (any(sigma_b < 0)) {
    stop("All sigma_b values must be non-negative")
  }

  if (n_sims < 1) {
    stop("n_sims must be at least 1")
  }

  scenarios <- expand.grid(
    n_subjects = n_subjects,
    beta_interaction = beta_interaction,
    sigma_b = sigma_b,
    stringsAsFactors = FALSE
  )

  scenarios$scenario_id <- seq_len(nrow(scenarios))

  sim_grid <- scenarios[rep(seq_len(nrow(scenarios)), each = n_sims), ]
  sim_grid$sim_id <- rep(seq_len(n_sims), times = nrow(scenarios))
  sim_grid$seed <- seq_len(nrow(sim_grid))

  rownames(sim_grid) <- NULL

  sim_grid
}


#' Convert log-odds to probability
#'
#' Utility function for the inverse logit transformation.
#'
#' @param x Log-odds value(s)
#'
#' @return Probability value(s) between 0 and 1
#'
#' @export
#'
#' @examples
#' inv_logit(0)    # 0.5
#' inv_logit(-1)   # ~0.27
#' inv_logit(1)    # ~0.73
inv_logit <- function(x) {
  1 / (1 + exp(-x))
}


#' Convert probability to log-odds
#'
#' Utility function for the logit transformation.
#'
#' @param p Probability value(s) between 0 and 1
#'
#' @return Log-odds value(s)
#'
#' @export
#'
#' @examples
#' logit(0.5)   # 0
#' logit(0.27)  # ~-1
#' logit(0.73)  # ~1
logit <- function(p) {
  if (any(p <= 0 | p >= 1)) {
    stop("p must be between 0 and 1 (exclusive)")
  }
  log(p / (1 - p))
}
