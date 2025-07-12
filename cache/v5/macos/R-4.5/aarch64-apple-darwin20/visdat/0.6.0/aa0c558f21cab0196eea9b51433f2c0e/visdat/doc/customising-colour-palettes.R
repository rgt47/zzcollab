## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
library(visdat)

## ----standard-----------------------------------------------------------------
vis_dat(typical_data)

## ----custom-------------------------------------------------------------------
library(ggplot2)
vis_dat(typical_data) +
  scale_fill_manual(
    values = c(
      "character" = "red",
      "factor" = "blue",
      "logical" = "green",
      "numeric" = "purple",
      "NA" = "gray"
  ))

## ----show-pal-----------------------------------------------------------------
palette()

## ----pal-hex-visdat-----------------------------------------------------------
vis_dat(typical_data) +
  scale_fill_manual(
    values = c(
      "character" = "#61D04F",
      "factor" = "#2297E6",
      "logical" = "#28E2E5",
      "numeric" = "#CD0BBC",
      "NA" = "#F5C710"
  ))

## ----scale-fill-brewer--------------------------------------------------------
vis_dat(typical_data) +
  scale_fill_brewer()

## ----scale-fill-viridis-------------------------------------------------------
vis_dat(typical_data) +
  scale_fill_viridis_d()

