# Simulation Study: Longitudinal Binary Data Methods

This directory contains companion files for the vignette
`workflow-simulation-study.Rmd`, demonstrating a complete simulation study
comparing methods for analyzing longitudinal binary outcomes.

## Overview

The simulation compares five analytic methods:

1. **GEE (Exchangeable)** - Generalized estimating equations with exchangeable
   correlation
2. **GEE (AR1)** - GEE with first-order autoregressive correlation
3. **GEE (Independence)** - GEE with independence working correlation
4. **GLMM** - Generalized linear mixed model with random intercepts
5. **Conditional Logistic** - Conditional logistic regression stratified by
   subject

## Directory Structure

```
workflow-simulation-study/
├── README.md                           # This file
├── R/
│   ├── simulate_data.R                 # Data generation functions
│   ├── fit_models.R                    # Model fitting functions
│   └── performance_metrics.R           # Performance evaluation
├── tests/
│   └── testthat/
│       ├── test-simulate_data.R        # 20 tests
│       ├── test-fit_models.R           # 18 tests
│       └── test-performance_metrics.R  # 22 tests
├── analysis/
│   ├── scripts/
│   │   ├── 02_run_simulation.R         # Main simulation runner
│   │   ├── 03_analyze_results.R        # Results analysis
│   │   └── 04_generate_figures.R       # Figure generation
│   ├── data/
│   │   └── derived_data/               # Simulation results (generated)
│   ├── figures/                        # Output figures (generated)
│   └── report/
│       ├── report.Rmd                  # Manuscript template
│       └── references.bib              # Bibliography
```

## Quick Start

### 1. Install Dependencies

```r
install.packages(c(
  "geepack",       # GEE models
  "lme4",          # GLMM
  "survival",      # Conditional logistic regression
  "broom",         # Tidy model output
  "broom.mixed",   # Tidy mixed models
  "furrr",         # Parallel processing
  "progressr",     # Progress bars
  "tictoc",        # Timing
  "tidyverse",     # Data manipulation
  "patchwork"      # Combine figures
))
```

### 2. Run Small Test Simulation

```r
# Test with reduced parameters
source("R/simulate_data.R")
source("R/fit_models.R")

# Generate one dataset
data <- simulate_longitudinal_binary(n_subjects = 100, seed = 42)

# Fit all models
results <- fit_all_models(data)
print(results)
```

### 3. Run Full Simulation

```bash
# From project root
Rscript analysis/scripts/02_run_simulation.R  # ~30 min with parallel
Rscript analysis/scripts/03_analyze_results.R
Rscript analysis/scripts/04_generate_figures.R
```

### 4. Render Manuscript

```r
rmarkdown::render("analysis/report/report.Rmd")
```

## Key Functions

### Data Generation

```r
# Generate correlated longitudinal binary data
data <- simulate_longitudinal_binary(
  n_subjects = 100,
  n_timepoints = 4,
  beta = c(-1, 0, 0.2, 0.3),  # intercept, trt, time, interaction
  sigma_b = 0.5,
  seed = 42
)

# Create simulation grid
grid <- create_simulation_grid(
  n_subjects = c(50, 100, 200),
  beta_interaction = c(0, 0.3, 0.5),
  sigma_b = c(0.5, 1.0),
  n_sims = 1000
)
```

### Model Fitting

```r
# Fit individual methods
result_gee <- fit_gee(data, corstr = "exchangeable")
result_glmm <- fit_glmm(data)
result_cond <- fit_conditional(data)

# Fit all methods at once
all_results <- fit_all_models(data)
```

### Performance Evaluation

```r
# Calculate performance metrics
perf <- calculate_performance(
  estimates = simulation_estimates,
  ses = simulation_ses,
  true_value = 0.3
)
# Returns: bias, coverage, power, SE ratio, etc.

# Summarize full simulation
performance <- summarize_simulation(results, true_values)
```

## Simulation Parameters

| Parameter | Values | Interpretation |
|-----------|--------|----------------|
| n_subjects | 50, 100, 200 | Sample size per group |
| beta_interaction | 0, 0.3, 0.5 | Treatment effect (log-OR) |
| sigma_b | 0.5, 1.0 | Between-subject SD |
| n_timepoints | 4 | Number of measurements |
| n_sims | 1000 | Replications per scenario |

## Expected Results

Based on the simulation design:

- **Bias**: All methods show minimal bias (<0.02)
- **Coverage**: GEE-Exch and GLMM ~95%; Conditional ~92-94%
- **Type I Error**: All methods ~5%
- **Power at n=100, β=0.5**: ~80-85%

## Running Tests

```r
# Run all tests
testthat::test_dir("tests/testthat")

# Run specific test file
testthat::test_file("tests/testthat/test-simulate_data.R")
```

## Customization

### Different Correlation Structure

Modify `simulate_data.R` to generate AR(1) correlated data:

```r
# Add AR(1) correlation to simulate_longitudinal_binary()
# This requires multivariate probit or copula methods
```

### Additional Methods

Add new methods to `fit_models.R`:

```r
fit_new_method <- function(data) {
  # Implementation
  list(
    estimate = ...,
    se = ...,
    converged = TRUE,
    method = "new_method"
  )
}
```

### Different Estimands

Modify performance metrics for different targets:

```r
# E.g., marginal vs conditional effects
# Modify calculate_performance() accordingly
```

## Dependencies

- R >= 4.0
- geepack >= 1.3
- lme4 >= 1.1
- survival >= 3.0
- tidyverse >= 2.0
- furrr >= 0.3

## Citation

If using this code, please cite:

```
@misc{simulation_longitudinal_binary,
  author = {Your Name},
  title = {Comparing Methods for Longitudinal Binary Outcomes: A Simulation Study},
  year = {2025},
  url = {https://github.com/...}
}
```

## Related Resources

- Parent vignette: `vignettes/workflow-simulation-study.Rmd`
- Morris et al. (2019) - ADEMP framework for simulation studies
- Burton et al. (2006) - Design of simulation studies in medical statistics
