#!/usr/bin/env Rscript

# Script to render all vignettes as PDFs using xelatex for Unicode support
library(rmarkdown)

# Get list of all Rmd files in current directory
rmd_files <- list.files(".", pattern = "\\.Rmd$", full.names = FALSE)
cat("Found", length(rmd_files), "vignette files to render\n\n")

# Function to render each file safely
render_vignette <- function(file) {
  cat("Rendering:", file, "...")
  start_time <- Sys.time()

  tryCatch({
    rmarkdown::render(
      file,
      output_format = pdf_document(latex_engine = "xelatex"),
      quiet = TRUE
    )
    end_time <- Sys.time()
    elapsed <- round(as.numeric(end_time - start_time), 1)
    cat(" ✅ Success (", elapsed, "s)\n")
    return(TRUE)
  }, error = function(e) {
    cat(" ❌ Error:", e$message, "\n")
    return(FALSE)
  })
}

# Render all vignettes
cat("Starting PDF rendering with xelatex engine...\n\n")
results <- sapply(rmd_files, render_vignette)

# Summary
successful <- sum(results)
total <- length(results)

cat("\n", paste(rep("=", 50), collapse=""), "\n")
cat("RENDERING SUMMARY\n")
cat(paste(rep("=", 50), collapse=""), "\n")
cat("Successfully rendered:", successful, "out of", total, "vignettes\n")

if (successful == total) {
  cat("🎉 All vignettes rendered successfully!\n")
} else {
  failed_files <- names(results)[!results]
  cat("❌ Failed files:\n")
  for (f in failed_files) {
    cat("  -", f, "\n")
  }
}

# List generated PDF files
pdf_files <- list.files(".", pattern = "\\.pdf$")
if (length(pdf_files) > 0) {
  cat("\n📄 Generated PDF files:\n")
  for (pdf in pdf_files) {
    file_size <- file.info(pdf)$size
    size_kb <- round(file_size / 1024, 1)
    cat("  -", pdf, "(", size_kb, "KB)\n")
  }
}