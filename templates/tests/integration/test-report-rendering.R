# Integration Test: Report Rendering
# Tests that the main research report can be rendered successfully

library(here)

report_path <- here('analysis', 'report', 'report.Rmd')
if (!file.exists(report_path)) exit_file('report.Rmd not present yet')

# --- Report Rmd file is non-empty and has YAML header ---
report_content <- readLines(report_path)
expect_true(length(report_content) > 0)
expect_true(any(grepl('^---$', report_content)))
expect_true(any(grepl('^title:', report_content)))
expect_true(any(grepl('^author:', report_content)))

# --- Report dependencies are available ---
for (pkg in c('rmarkdown', 'knitr', 'bookdown')) {
  expect_true(requireNamespace(pkg, quietly = TRUE),
              info = paste('Package', pkg, 'is required for report rendering'))
}

# --- Bibliography files exist ---
bib_path <- here('analysis', 'report', 'references.bib')
expect_true(file.exists(bib_path))

csl_path <- here('analysis', 'report', 'statistics-in-medicine.csl')
expect_true(file.exists(csl_path))

# --- Report parses without errors ---
yaml_content <- rmarkdown::yaml_front_matter(report_path)
expect_inherits(yaml_content, 'list')
expect_true('title' %in% names(yaml_content))

# Note: Actual rendering test is omitted to avoid LaTeX dependencies in CI.
# Uncomment for local testing if LaTeX is available:
#   rmarkdown::render(report_path, output_dir = here('analysis', 'report'),
#                    quiet = TRUE)
#   expect_true(file.exists(here('analysis', 'report', 'report.pdf')))
