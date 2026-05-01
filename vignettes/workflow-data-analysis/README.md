# Write as You Go: Companion Files

This directory contains extracted files from the vignette
`workflow-data-analysis.Rmd`. These files demonstrate the "Write as You Go"
approach to manuscript-driven data analysis.

## Directory Structure

```
workflow-data-analysis/
├── README.md                      # This file
├── report.Rmd                     # Complete manuscript template
├── references.bib                 # Bibliography
├── R/
│   └── allometry.R                # Extracted analysis functions
├── tests/
│   └── testthat/
│       └── test-allometry.R       # Unit tests for functions
└── analysis/
    └── data/
        └── README.md              # Data documentation template
```

## File Descriptions

### report.Rmd

A complete manuscript demonstrating the Write as You Go approach. This file
combines:

- Research questions and hypotheses
- Methods with embedded code
- Results with inline statistics
- Discussion and interpretation

The manuscript analyzes allometric relationships between bill morphology
and body mass in Palmer penguins, discovering Simpson's paradox in the
pooled analysis.

### R/allometry.R

Reusable functions extracted from the manuscript:

- `extract_species_slopes()`: Calculate species-specific slopes from
  interaction models
- `compare_allometric_models()`: Compare pooled, additive, and interaction
  models

These functions emerged through progressive disclosure as patterns became
apparent during analysis.

### tests/testthat/test-allometry.R

Unit tests for the extracted functions, including:

- Structure validation
- Edge case handling
- Input validation
- Integration tests with penguin data

### analysis/data/README.md

Template for documenting data provenance, including:

- Source and collection methods
- Variable descriptions
- Known quality issues
- Citation information

## Usage

### Option 1: Use as Template

Copy this directory to start a new project:

```bash
cp -r vignettes/workflow-data-analysis my-new-project
cd my-new-project
```

Then modify `report.Rmd` for your analysis.

### Option 2: Reference for Learning

Read through `report.Rmd` to see how prose and code integrate. Note how:

1. Research questions appear before any code
2. Methods justify analytical choices before implementing them
3. Interpretation follows immediately after each result
4. Functions are extracted only after patterns emerge

## Key Principles Demonstrated

1. **Prose Before Code**: Each analysis section begins with the research
   question and methodological rationale

2. **Immediate Interpretation**: Results are interpreted in context, not
   in a separate discussion section written later

3. **Progressive Disclosure**: Start with inline code, extract functions
   only when reuse patterns emerge

4. **Single Source of Truth**: The manuscript is both the lab notebook
   and the final paper

## Dependencies

Required R packages:

- palmerpenguins
- tidyverse
- broom
- testthat (for tests)

Install with:

```r
install.packages(c("palmerpenguins", "tidyverse", "broom", "testthat"))
```

## Related Resources

- Parent vignette: `vignettes/workflow-data-analysis.Rmd`
- ZZCOLLAB documentation: `docs/`
- Research compendium guide: Marwick et al. (2018)
