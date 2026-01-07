# Data Documentation

This directory contains data for the penguin morphology analysis.

## Directory Structure

```
data/
├── raw_data/           # Original, unmodified data (read-only)
│   └── penguins.csv    # Palmer penguins morphometric data
├── derived_data/       # Processed, analysis-ready data
│   └── (created by analysis scripts)
└── README.md           # This file
```

## Raw Data

### penguins.csv

**Source**: Palmer Archipelago Long-Term Ecological Research (LTER) program,
accessed via the palmerpenguins R package (version 0.1.0)

**Collection Period**: 2007-2009

**Location**: Palmer Station, Antarctica (64.77°S, 64.05°W)

**Collection Method**: Morphometric measurements collected from adult penguins
during breeding season. Birds were captured, measured, and released.

**Variables**:

| Variable | Type | Description | Units |
|----------|------|-------------|-------|
| species | factor | Penguin species | Adelie, Chinstrap, Gentoo |
| island | factor | Island in Palmer Archipelago | Biscoe, Dream, Torgersen |
| bill_length_mm | numeric | Culmen length | millimeters |
| bill_depth_mm | numeric | Culmen depth | millimeters |
| flipper_length_mm | numeric | Flipper length | millimeters |
| body_mass_g | numeric | Body mass | grams |
| sex | factor | Sex | female, male |
| year | integer | Study year | 2007, 2008, 2009 |

**Sample Size**: 344 observations

**Known Issues**:

- 11 observations have missing morphometric measurements (body_mass_g,
  bill_length_mm, bill_depth_mm, or flipper_length_mm)
- 2 observations have missing sex

**Data Quality Notes**:

- Measurements taken by trained field researchers following standardized
  protocols
- Species identification confirmed by experienced observers
- Body mass may vary with breeding stage and time of day

**Citation**:

Horst AM, Hill AP, Gorman KB (2020). palmerpenguins: Palmer Archipelago
(Antarctica) penguin data. R package version 0.1.0.
https://allisonhorst.github.io/palmerpenguins/

**Original Data Source**:

Gorman KB, Williams TD, Fraser WR (2014). Ecological Sexual Dimorphism and
Environmental Variability within a Community of Antarctic Penguins (Genus
Pygoscelis). PLoS ONE 9(3): e90081. doi:10.1371/journal.pone.0090081

## Derived Data

Derived datasets are created by analysis scripts and documented here as
they are generated.

### penguins_clean.csv (if created)

**Created by**: `analysis/scripts/01_prepare_data.R` or directly in
`analysis/report/report.Rmd`

**Description**: Cleaned dataset excluding observations with missing
morphometric data and including log-transformed variables for allometric
analysis.

**Transformations applied**:

1. Removed observations with missing bill_length_mm, bill_depth_mm, or
   body_mass_g (n = 11)
2. Added log_body_mass = log(body_mass_g)
3. Added log_bill_length = log(bill_length_mm)
4. Added log_bill_depth = log(bill_depth_mm)

**Final sample size**: 333 observations

## Data Versioning

For large datasets not tracked in git, document:

- Download URL
- Download date
- MD5 checksum
- Download script location

## Reproducibility

To reproduce the raw data:

```r
library(palmerpenguins)
write.csv(penguins, "analysis/data/raw_data/penguins.csv", row.names = FALSE)
```

Alternatively, the data is available directly from the package:

```r
library(palmerpenguins)
data(penguins)
```
