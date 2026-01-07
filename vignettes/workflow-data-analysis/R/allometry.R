#' Extract species-specific allometric slopes
#'
#' Calculates species-specific slopes from an interaction model
#' of the form y ~ x * species.
#'
#' @param model An lm object with interaction terms
#' @param x_var Name of the continuous predictor
#' @param species_var Name of the species factor
#'
#' @return Data frame with species and slope columns
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(palmerpenguins)
#' data <- penguins |>
#'   dplyr::filter(!is.na(body_mass_g), !is.na(bill_length_mm)) |>
#'   dplyr::mutate(
#'     log_body_mass = log(body_mass_g),
#'     log_bill_length = log(bill_length_mm)
#'   )
#' model <- lm(log_bill_length ~ log_body_mass * species, data = data)
#' extract_species_slopes(model)
#' }
extract_species_slopes <- function(model, x_var = "log_body_mass",
                                   species_var = "species") {
  if (!inherits(model, "lm")) {
    stop("model must be an lm object")
  }

  coefs <- coef(model)

  if (!(x_var %in% names(coefs))) {
    stop("x_var '", x_var, "' not found in model coefficients")
  }


  base_slope <- coefs[x_var]

  interaction_terms <- grep(paste0(x_var, ":"), names(coefs), value = TRUE)

  if (length(interaction_terms) == 0) {
    warning("No interaction terms found. Returning single slope.")
    return(data.frame(species = "all", slope = base_slope, row.names = NULL))
  }

  species_names <- gsub(paste0(x_var, ":", species_var), "",
                        interaction_terms)

  model_data <- model$model
  if (!(species_var %in% names(model_data))) {
    stop("species_var '", species_var, "' not found in model data")
  }

  reference_species <- levels(model_data[[species_var]])[1]

  slopes <- c(base_slope, base_slope + coefs[interaction_terms])
  species <- c(reference_species, species_names)

  data.frame(species = species, slope = slopes, row.names = NULL)
}


#' Compare allometric models
#'
#' Compares pooled, additive, and interaction models for allometric analysis.
#'
#' @param data Data frame containing the variables
#' @param y_var Name of the response variable (log-transformed)
#' @param x_var Name of the predictor variable (log-transformed)
#' @param group_var Name of the grouping variable
#'
#' @return List containing the three models and comparison statistics
#'
#' @export
compare_allometric_models <- function(data, y_var, x_var, group_var) {
  formula_pooled <- as.formula(paste(y_var, "~", x_var))
  formula_additive <- as.formula(paste(y_var, "~", x_var, "+", group_var))
  formula_interaction <- as.formula(paste(y_var, "~", x_var, "*", group_var))

  model_pooled <- lm(formula_pooled, data = data)
  model_additive <- lm(formula_additive, data = data)
  model_interaction <- lm(formula_interaction, data = data)

  anova_result <- anova(model_additive, model_interaction)

  list(
    pooled = model_pooled,
    additive = model_additive,
    interaction = model_interaction,
    anova = anova_result,
    aic = c(
      pooled = AIC(model_pooled),
      additive = AIC(model_additive),
      interaction = AIC(model_interaction)
    )
  )
}
