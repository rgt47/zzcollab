# Render Complete Manuscript
# Research Compendium: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}
# Date: {{DATE}}

# This script renders the complete manuscript in multiple formats
# after ensuring all analyses, figures, and tables are up to date.

# Load required packages
library({{PACKAGE_NAME}})
library(here)
library(rmarkdown)
library(bookdown)

# Load package functions
devtools::load_all()

# Set up paths
manuscript_dir <- here("manuscript")
submission_dir <- here("submission", "manuscript_versions")

# Create submission directory
if (!dir.exists(submission_dir)) {
  dir.create(submission_dir, recursive = TRUE)
}

message("Starting complete manuscript rendering workflow...")

# Step 1: Ensure all analyses are up to date
message("Verifying analysis dependencies...")

# Check if analysis results exist and are current
analysis_current <- check_analysis_currency()
if (!analysis_current) {
  message("Analysis results are out of date. Running complete analysis pipeline...")
  source(here("analysis", "reproduce", "01_data_preparation.R"))
  source(here("analysis", "reproduce", "02_statistical_analysis.R"))
  source(here("analysis", "reproduce", "03_figures_tables.R"))
} else {
  message("Analysis results are current.")
}

# Step 2: Render main manuscript
message("Rendering main manuscript...")

# Render Word format for collaboration and submission
render(
  input = file.path(manuscript_dir, "paper.Rmd"),
  output_file = file.path(submission_dir, "manuscript_word.docx"),
  output_format = bookdown::word_document2(
    reference_docx = file.path(manuscript_dir, "templates", "manuscript_template.docx"),
    number_sections = TRUE
  )
)

# Render PDF format for submission
render(
  input = file.path(manuscript_dir, "paper.Rmd"),
  output_file = file.path(submission_dir, "manuscript_pdf.pdf"),
  output_format = bookdown::pdf_document2(
    latex_engine = "xelatex",
    number_sections = TRUE
  )
)

# Render HTML format for web sharing
render(
  input = file.path(manuscript_dir, "paper.Rmd"),
  output_file = file.path(submission_dir, "manuscript_html.html"),
  output_format = bookdown::html_document2(
    number_sections = TRUE,
    toc = TRUE,
    toc_float = TRUE
  )
)

# Step 3: Render supplementary materials
message("Rendering supplementary materials...")

# Render supplementary Word format
render(
  input = file.path(manuscript_dir, "supplementary.Rmd"),
  output_file = file.path(submission_dir, "supplementary_word.docx"),
  output_format = bookdown::word_document2(
    number_sections = TRUE
  )
)

# Render supplementary PDF format
render(
  input = file.path(manuscript_dir, "supplementary.Rmd"),
  output_file = file.path(submission_dir, "supplementary_pdf.pdf"),
  output_format = bookdown::pdf_document2(
    latex_engine = "xelatex",
    number_sections = TRUE
  )
)

# Step 4: Create submission package
message("Creating submission package...")

# Copy figures and tables to submission directory
file.copy(
  from = list.files(here("submission", "figures"), full.names = TRUE),
  to = file.path(submission_dir, "figures"),
  recursive = TRUE
)

file.copy(
  from = list.files(here("submission", "tables"), full.names = TRUE),
  to = file.path(submission_dir, "tables"),
  recursive = TRUE
)

# Create submission README
submission_readme <- paste0(
  "# Submission Package for {{MANUSCRIPT_TITLE}}\n\n",
  "Generated: ", Sys.time(), "\n\n",
  "## Files Included:\n\n",
  "### Main Manuscript\n",
  "- `manuscript_word.docx` - Word format for submission\n",
  "- `manuscript_pdf.pdf` - PDF format for submission\n",
  "- `manuscript_html.html` - HTML format for web sharing\n\n",
  "### Supplementary Materials\n",
  "- `supplementary_word.docx` - Supplementary materials (Word)\n",
  "- `supplementary_pdf.pdf` - Supplementary materials (PDF)\n\n",
  "### Figures and Tables\n",
  "- `figures/` - High-resolution figures\n",
  "- `tables/` - Publication-ready tables\n\n",
  "## Reproducibility\n\n",
  "All analyses can be reproduced by running the scripts in `analysis/reproduce/`\n",
  "in order, or by running this script (`04_manuscript_render.R`).\n"
)

writeLines(submission_readme, file.path(submission_dir, "README.md"))

message("Manuscript rendering completed successfully.")

# Create rendering log
rendering_log <- list(
  script = "04_manuscript_render.R",
  timestamp = Sys.time(),
  r_version = R.version.string,
  package_version = packageVersion("{{PACKAGE_NAME}}"),
  files_generated = list.files(submission_dir, recursive = TRUE),
  rendering_specs = list(
    main_formats = c("Word", "PDF", "HTML"),
    supplementary_formats = c("Word", "PDF"),
    latex_engine = "xelatex"
  )
)

# Save rendering log
saveRDS(rendering_log, file.path(submission_dir, "manuscript_rendering_log.rds"))

message("Manuscript rendering log saved.")
message("Complete submission package available in: submission/manuscript_versions/")