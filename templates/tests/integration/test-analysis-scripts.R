# Integration Test: Analysis Scripts
# Tests that analysis scripts run without errors and produce expected outputs

library(here)

# --- Database setup script runs successfully ---
script_path <- here('analysis', 'scripts', '00_database_setup.R')
if (file.exists(script_path)) {
  expect_silent(source(script_path, local = new.env()))
}

# --- Data validation script runs ---
script_path <- here('analysis', 'scripts', '02_data_validation.R')
if (file.exists(script_path)) {
  expect_silent(source(script_path, local = new.env()))
}

# --- Reproducibility check script runs ---
script_path <- here('analysis', 'scripts', '99_reproducibility_check.R')
if (file.exists(script_path)) {
  expect_silent(source(script_path, local = new.env()))
}

# --- Analysis output directories exist and are writable ---
figures_dir <- here('analysis', 'figures')
expect_true(dir.exists(figures_dir))

test_plot_path <- file.path(figures_dir, 'test_plot.png')
expect_silent({
  png(test_plot_path, width = 800, height = 600)
  plot(1:10, 1:10, main = 'Test Plot')
  dev.off()
})
expect_true(file.exists(test_plot_path))
if (file.exists(test_plot_path)) unlink(test_plot_path)

tables_dir <- here('analysis', 'tables')
expect_true(dir.exists(tables_dir))
