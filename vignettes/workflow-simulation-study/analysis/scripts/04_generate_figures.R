# 04_generate_figures.R
# Generate publication-quality figures for simulation results
#
# Input: analysis/data/derived_data/simulation_performance.rds
# Output: analysis/figures/*.png

library(tidyverse)
library(patchwork)

# Load data ------------------------------------------------------------------

perf_file <- "analysis/data/derived_data/simulation_performance.rds"

if (!file.exists(perf_file)) {
  stop("Performance file not found. Run 03_analyze_results.R first.")
}

performance <- readRDS(perf_file)

# Create output directory
fig_dir <- "analysis/figures"
if (!dir.exists(fig_dir)) {
  dir.create(fig_dir, recursive = TRUE)
}

# Clean method names for display ---------------------------------------------

performance <- performance |>
  mutate(
    method_label = case_when(
      method == "gee_exch" ~ "GEE (Exchangeable)",
      method == "gee_ar1" ~ "GEE (AR1)",
      method == "gee_ind" ~ "GEE (Independence)",
      method == "glmm" ~ "GLMM",
      method == "conditional" ~ "Conditional Logistic",
      TRUE ~ method
    ),
    effect_label = case_when(
      beta_interaction == 0 ~ "Null (OR = 1.0)",
      beta_interaction == 0.3 ~ "Small (OR = 1.35)",
      beta_interaction == 0.5 ~ "Moderate (OR = 1.65)",
      TRUE ~ as.character(beta_interaction)
    ),
    sigma_label = paste0("σ[b] == ", sigma_b)
  )

# Common theme ---------------------------------------------------------------

theme_sim <- theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 10, face = "bold"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(size = 12, face = "bold"),
    axis.title = element_text(size = 10)
  )

# Figure 1: Bias by method and sample size -----------------------------------

fig_bias <- performance |>
  filter(beta_interaction != 0) |>
  ggplot(aes(x = factor(n_subjects), y = bias, color = method_label)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(position = position_dodge(width = 0.6), size = 2.5) +
  geom_errorbar(
    aes(
      ymin = bias - 1.96 * empirical_se / sqrt(n_valid),
      ymax = bias + 1.96 * empirical_se / sqrt(n_valid)
    ),
    position = position_dodge(width = 0.6),
    width = 0.25,
    linewidth = 0.5
  ) +
  facet_grid(
    effect_label ~ sigma_label,
    labeller = labeller(sigma_label = label_parsed)
  ) +
  scale_color_brewer(palette = "Set1") +
  labs(
    x = "Sample Size (n per group)",
    y = "Bias in Treatment Effect Estimate",
    color = "Method",
    title = "Figure 1: Estimation Bias by Method, Sample Size, and Effect Size",
    caption = "Error bars show 95% confidence intervals for Monte Carlo error"
  ) +
  theme_sim +
  guides(color = guide_legend(nrow = 2))

ggsave(
  file.path(fig_dir, "fig1_bias.png"),
  fig_bias,
  width = 10, height = 8, dpi = 300
)

cat("Saved: fig1_bias.png\n")

# Figure 2: Coverage probability ---------------------------------------------

fig_coverage <- performance |>
  filter(beta_interaction != 0) |>
  ggplot(aes(x = factor(n_subjects), y = coverage, color = method_label)) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "gray50") +
  geom_hline(yintercept = c(0.925, 0.975), linetype = "dotted",
             color = "gray70", linewidth = 0.3) +
  geom_point(position = position_dodge(width = 0.6), size = 2.5) +
  facet_grid(
    effect_label ~ sigma_label,
    labeller = labeller(sigma_label = label_parsed)
  ) +
  scale_color_brewer(palette = "Set1") +
  scale_y_continuous(
    limits = c(0.85, 1.0),
    breaks = seq(0.85, 1.0, 0.05)
  ) +
  labs(
    x = "Sample Size (n per group)",
    y = "95% CI Coverage Probability",
    color = "Method",
    title = "Figure 2: Confidence Interval Coverage",
    caption = "Dashed line: nominal 95% coverage; Dotted lines: acceptable range (92.5%-97.5%)"
  ) +
  theme_sim +
  guides(color = guide_legend(nrow = 2))

ggsave(
  file.path(fig_dir, "fig2_coverage.png"),
  fig_coverage,
  width = 10, height = 8, dpi = 300
)

cat("Saved: fig2_coverage.png\n")

# Figure 3: Power curves -----------------------------------------------------

fig_power <- performance |>
  filter(beta_interaction != 0) |>
  ggplot(aes(
    x = n_subjects,
    y = power,
    color = method_label,
    linetype = factor(sigma_b)
  )) +
  geom_hline(yintercept = 0.80, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2) +
  facet_wrap(~ effect_label, nrow = 1) +
  scale_color_brewer(palette = "Set1") +
  scale_y_continuous(
    limits = c(0, 1),
    labels = scales::percent_format(),
    breaks = seq(0, 1, 0.2)
  ) +
  scale_x_continuous(breaks = c(50, 100, 200)) +
  scale_linetype_manual(
    values = c("solid", "dashed"),
    labels = c("σ = 0.5", "σ = 1.0")
  ) +
  labs(
    x = "Sample Size (n per group)",
    y = "Statistical Power",
    color = "Method",
    linetype = "Random Effect SD",
    title = "Figure 3: Power Curves by Effect Size and Between-Subject Variability",
    caption = "Dashed horizontal line: 80% power threshold"
  ) +
  theme_sim +
  guides(
    color = guide_legend(nrow = 2, order = 1),
    linetype = guide_legend(order = 2)
  )

ggsave(
  file.path(fig_dir, "fig3_power.png"),
  fig_power,
  width = 12, height = 5, dpi = 300
)

cat("Saved: fig3_power.png\n")

# Figure 4: SE calibration (SE ratio) ----------------------------------------

fig_se_ratio <- performance |>
  filter(beta_interaction != 0) |>
  ggplot(aes(x = factor(n_subjects), y = se_ratio, fill = method_label)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  facet_grid(
    effect_label ~ sigma_label,
    labeller = labeller(sigma_label = label_parsed)
  ) +
  scale_fill_brewer(palette = "Set1") +
  scale_y_continuous(limits = c(0, 1.5), breaks = seq(0, 1.5, 0.25)) +
  labs(
    x = "Sample Size (n per group)",
    y = "SE Ratio (Model SE / Empirical SE)",
    fill = "Method",
    title = "Figure 4: Standard Error Calibration",
    caption = "Ratio = 1 indicates well-calibrated standard errors"
  ) +
  theme_sim +
  guides(fill = guide_legend(nrow = 2))

ggsave(
  file.path(fig_dir, "fig4_se_ratio.png"),
  fig_se_ratio,
  width = 10, height = 8, dpi = 300
)

cat("Saved: fig4_se_ratio.png\n")

# Figure 5: Type I error rates -----------------------------------------------

fig_type1 <- performance |>
  filter(beta_interaction == 0) |>
  ggplot(aes(x = method_label, y = power, fill = factor(sigma_b))) +
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "gray50") +
  geom_hline(yintercept = c(0.025, 0.075), linetype = "dotted",
             color = "gray70") +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  facet_wrap(~ paste("n =", n_subjects), nrow = 1) +
  scale_fill_brewer(palette = "Set2", labels = c("σ = 0.5", "σ = 1.0")) +
  scale_y_continuous(limits = c(0, 0.10), breaks = seq(0, 0.10, 0.025)) +
  labs(
    x = "Method",
    y = "Type I Error Rate",
    fill = "Random Effect SD",
    title = "Figure 5: Type I Error Rates Under the Null Hypothesis",
    caption = "Dashed line: nominal 5% rate; Dotted lines: acceptable range"
  ) +
  theme_sim +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8)
  )

ggsave(
  file.path(fig_dir, "fig5_type1_error.png"),
  fig_type1,
  width = 12, height = 5, dpi = 300
)

cat("Saved: fig5_type1_error.png\n")

# Combined summary figure ----------------------------------------------------

p1 <- performance |>
  filter(beta_interaction == 0.3, sigma_b == 0.5) |>
  ggplot(aes(x = n_subjects, y = bias, color = method_label)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_line() +
  geom_point() +
  scale_color_brewer(palette = "Set1") +
  labs(x = "Sample Size", y = "Bias", title = "A) Bias") +
  theme_sim +
  theme(legend.position = "none")

p2 <- performance |>
  filter(beta_interaction == 0.3, sigma_b == 0.5) |>
  ggplot(aes(x = n_subjects, y = coverage, color = method_label)) +
  geom_hline(yintercept = 0.95, linetype = "dashed") +
  geom_line() +
  geom_point() +
  scale_color_brewer(palette = "Set1") +
  scale_y_continuous(limits = c(0.9, 1)) +
  labs(x = "Sample Size", y = "Coverage", title = "B) Coverage") +
  theme_sim +
  theme(legend.position = "none")

p3 <- performance |>
  filter(beta_interaction == 0.3, sigma_b == 0.5) |>
  ggplot(aes(x = n_subjects, y = power, color = method_label)) +
  geom_hline(yintercept = 0.80, linetype = "dashed") +
  geom_line() +
  geom_point() +
  scale_color_brewer(palette = "Set1") +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(x = "Sample Size", y = "Power", title = "C) Power") +
  theme_sim +
  theme(legend.position = "none")

p4 <- performance |>
  filter(beta_interaction == 0.3, sigma_b == 0.5) |>
  ggplot(aes(x = n_subjects, y = se_ratio, color = method_label)) +
  geom_hline(yintercept = 1, linetype = "dashed") +
  geom_line() +
  geom_point() +
  scale_color_brewer(palette = "Set1") +
  labs(x = "Sample Size", y = "SE Ratio", title = "D) SE Calibration",
       color = "Method") +
  theme_sim

fig_summary <- (p1 | p2) / (p3 | p4) +
  plot_annotation(
    title = "Simulation Summary: Small Effect (OR = 1.35), Low Heterogeneity (σ = 0.5)",
    theme = theme(plot.title = element_text(size = 12, face = "bold"))
  )

ggsave(
  file.path(fig_dir, "fig_summary.png"),
  fig_summary,
  width = 10, height = 8, dpi = 300
)

cat("Saved: fig_summary.png\n")

# Report completion ----------------------------------------------------------

cat("\n=== All figures generated ===\n")
cat("Output directory:", fig_dir, "\n")
cat("Files:\n")
list.files(fig_dir, pattern = "\\.png$") |>
  paste("-", .) |>
  cat(sep = "\n")
