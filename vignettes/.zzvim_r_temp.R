library("papaja")
library("palmerpenguins")
library("dplyr")
library("ggplot2")
library("broom")
library("emmeans")

# Load our analysis functions
source("../R/data_processing.R")
source("../R/statistical_analysis.R")
source("../R/visualization.R")

# Set up figure and table output
r_refs("../references.bib")
