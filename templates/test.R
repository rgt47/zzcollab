 rm(list = ls())
 library(pacman)
 p_load( naniar, DT,
   conflicted, ggthemes, datapasta, janitor, kableExtra,
   tidytuesdayR, tidyverse, knitr, readxl
 )
 dt <- function(x) datatable(head(x, 100), filter = "top")
 conflict_prefer("filter", "dplyr")
 conflict_prefer("select", "dplyr")
 conflict_prefer("summarize", "dplyr")
 theme_set(theme_bw())
 source("~/shr/zz.tools.R")
 options(scipen = 1, digits = 3)
