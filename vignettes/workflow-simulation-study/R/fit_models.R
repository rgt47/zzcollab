#' Fit GEE model for longitudinal binary data
#'
#' Fits a generalized estimating equations model with specified correlation
#' structure.
#'
#' @param data Data frame from simulate_longitudinal_binary
#' @param corstr Correlation structure ("exchangeable", "ar1", "independence")
#'
#' @return List with:
#'
#' - estimate: Point estimate for treatment-by-time interaction
#' - se: Standard error of estimate
#' - converged: Logical indicating successful convergence
#' - method: Character string "GEE"
#' - corstr: Correlation structure used
#'
#' @export
#'
#' @examples
#' \dontrun{
#' data <- simulate_longitudinal_binary(n_subjects = 100, seed = 42)
#' result <- fit_gee(data, corstr = "exchangeable")
#' result$estimate
#' }
fit_gee <- function(data, corstr = "exchangeable") {
  if (!requireNamespace("geepack", quietly = TRUE)) {
    stop("Package 'geepack' required for GEE models. ",
         "Install with: install.packages('geepack')")
  }

  valid_corstr <- c("exchangeable", "ar1", "independence", "unstructured")
  if (!corstr %in% valid_corstr) {
    stop("corstr must be one of: ", paste(valid_corstr, collapse = ", "))
  }

  required_cols <- c("subject_id", "time", "treatment", "y")
  if (!all(required_cols %in% names(data))) {
    stop("data must contain columns: ", paste(required_cols, collapse = ", "))
  }

  tryCatch({
    model <- geepack::geeglm(
      y ~ treatment * time,
      family = binomial(link = "logit"),
      data = data,
      id = subject_id,
      corstr = corstr
    )

    coefs <- summary(model)$coefficients
    interaction_row <- grep("treatment.*:time|time:treatment.*",
                            rownames(coefs))

    if (length(interaction_row) == 0) {
      stop("Interaction term not found in model output")
    }

    list(
      estimate = coefs[interaction_row, "Estimate"],
      se = coefs[interaction_row, "Std.err"],
      converged = TRUE,
      method = "GEE",
      corstr = corstr
    )
  }, error = function(e) {
    list(
      estimate = NA_real_,
      se = NA_real_,
      converged = FALSE,
      method = "GEE",
      corstr = corstr,
      error = conditionMessage(e)
    )
  })
}


#' Fit GLMM for longitudinal binary data
#'
#' Fits a generalized linear mixed model with random intercepts.
#'
#' @param data Data frame from simulate_longitudinal_binary
#'
#' @return List with:
#'
#' - estimate: Point estimate for treatment-by-time interaction
#' - se: Standard error of estimate
#' - converged: Logical indicating successful convergence (not singular)
#' - method: Character string "GLMM"
#'
#' @export
#'
#' @examples
#' \dontrun{
#' data <- simulate_longitudinal_binary(n_subjects = 100, seed = 42)
#' result <- fit_glmm(data)
#' result$estimate
#' }
fit_glmm <- function(data) {
  if (!requireNamespace("lme4", quietly = TRUE)) {
    stop("Package 'lme4' required for GLMM models. ",
         "Install with: install.packages('lme4')")
  }

  required_cols <- c("subject_id", "time", "treatment", "y")
  if (!all(required_cols %in% names(data))) {
    stop("data must contain columns: ", paste(required_cols, collapse = ", "))
  }

  tryCatch({
    model <- lme4::glmer(
      y ~ treatment * time + (1 | subject_id),
      family = binomial(link = "logit"),
      data = data,
      control = lme4::glmerControl(
        optimizer = "bobyqa",
        optCtrl = list(maxfun = 100000)
      )
    )

    coefs <- summary(model)$coefficients
    interaction_row <- grep("treatment.*:time|time:treatment.*",
                            rownames(coefs))

    if (length(interaction_row) == 0) {
      stop("Interaction term not found in model output")
    }

    list(
      estimate = coefs[interaction_row, "Estimate"],
      se = coefs[interaction_row, "Std. Error"],
      converged = !lme4::isSingular(model),
      method = "GLMM"
    )
  }, error = function(e) {
    list(
      estimate = NA_real_,
      se = NA_real_,
      converged = FALSE,
      method = "GLMM",
      error = conditionMessage(e)
    )
  })
}


#' Fit conditional logistic regression
#'
#' Fits a conditional logistic regression model stratified by subject.
#'
#' @param data Data frame from simulate_longitudinal_binary
#'
#' @return List with:
#'
#' - estimate: Point estimate for treatment-by-time interaction
#' - se: Standard error of estimate
#' - converged: Logical indicating successful convergence
#' - method: Character string "Conditional"
#'
#' @export
#'
#' @examples
#' \dontrun{
#' data <- simulate_longitudinal_binary(n_subjects = 100, seed = 42)
#' result <- fit_conditional(data)
#' result$estimate
#' }
fit_conditional <- function(data) {
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("Package 'survival' required for conditional logistic regression. ",
         "Install with: install.packages('survival')")
  }

  required_cols <- c("subject_id", "time", "treatment", "y")
  if (!all(required_cols %in% names(data))) {
    stop("data must contain columns: ", paste(required_cols, collapse = ", "))
  }

  tryCatch({
    data$treatment_numeric <- as.numeric(data$treatment == "treatment")

    model <- survival::clogit(
      y ~ treatment_numeric:time + time + strata(subject_id),
      data = data
    )

    coefs <- summary(model)$coefficients
    interaction_row <- grep("treatment_numeric:time", rownames(coefs))

    if (length(interaction_row) == 0) {
      stop("Interaction term not found in model output")
    }

    list(
      estimate = coefs[interaction_row, "coef"],
      se = coefs[interaction_row, "se(coef)"],
      converged = model$info$convergence == 0,
      method = "Conditional"
    )
  }, error = function(e) {
    list(
      estimate = NA_real_,
      se = NA_real_,
      converged = FALSE,
      method = "Conditional",
      error = conditionMessage(e)
    )
  })
}


#' Fit all models to a dataset
#'
#' Convenience function to fit all methods and return combined results.
#'
#' @param data Data frame from simulate_longitudinal_binary
#' @param methods Character vector of methods to fit. Default is all methods.
#'   Options: "gee_exch", "gee_ar1", "gee_ind", "glmm", "conditional"
#'
#' @return Data frame with results from all methods, one row per method
#'
#' @export
#'
#' @examples
#' \dontrun{
#' data <- simulate_longitudinal_binary(n_subjects = 100, seed = 42)
#' results <- fit_all_models(data)
#' results
#' }
fit_all_models <- function(data,
                           methods = c("gee_exch", "gee_ar1", "gee_ind",
                                       "glmm", "conditional")) {
  all_methods <- c("gee_exch", "gee_ar1", "gee_ind", "glmm", "conditional")

  invalid_methods <- setdiff(methods, all_methods)
  if (length(invalid_methods) > 0) {
    stop("Invalid methods: ", paste(invalid_methods, collapse = ", "),
         "\nValid options: ", paste(all_methods, collapse = ", "))
  }

  results_list <- list()

  if ("gee_exch" %in% methods) {
    results_list$gee_exch <- fit_gee(data, corstr = "exchangeable")
  }

  if ("gee_ar1" %in% methods) {
    results_list$gee_ar1 <- fit_gee(data, corstr = "ar1")
  }

  if ("gee_ind" %in% methods) {
    results_list$gee_ind <- fit_gee(data, corstr = "independence")
  }

  if ("glmm" %in% methods) {
    results_list$glmm <- fit_glmm(data)
  }

  if ("conditional" %in% methods) {
    results_list$conditional <- fit_conditional(data)
  }

  do.call(rbind, lapply(names(results_list), function(name) {
    r <- results_list[[name]]
    data.frame(
      method = name,
      estimate = r$estimate,
      se = r$se,
      converged = r$converged,
      stringsAsFactors = FALSE
    )
  }))
}
