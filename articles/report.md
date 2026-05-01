# Palmer Penguins Bill Dimensions Analysis

## Introduction

Analysis of bill length and bill depth measurements across three penguin
species from the Palmer Station Antarctica LTER.

## Data Loading

``` r

library(palmerpenguins)
library(ggplot2)
library(dplyr)

# Source analysis functions from R/
source("../../R/bill_analysis.R")

# Preview data
head(penguins)
```

## Analysis

### Bill Dimensions by Species

``` r

# Generate plot using function from R/
plot <- create_bill_plot()
print(plot)

# Save plot
ggsave("../figures/bill_scatter.png", plot, width = 8, height = 6)
```

## Summary

The analysis reveals distinct bill dimension patterns across penguin
species.
