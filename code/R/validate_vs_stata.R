# validate_vs_stata.R — Observation-level comparison of R vs Stata outputs
# Compares every country × year × variable between R .rds and Stata .dta files
# Produces a detailed HTML report

rm(list = ls())
root    <- "C:/github-repos/replicate_human_capital"
input   <- file.path(root, "input")
output  <- file.path(root, "output")
graphs  <- file.path(root, "figures_tables")
codedir <- file.path(root, "code", "R")

library(haven); library(dplyr); library(tidyr)

# Tolerance thresholds
TOL_EXACT  <- 1e-6   # Effectively exact
TOL_CLOSE  <- 0.001  # 0.1%
TOL_ACCEPT <- 0.01   # 1%
TOL_FLAG   <- 0.05   # 5%

# Collector for all comparison results
all_comparisons <- list()

compare_var <- function(merged, var_r, var_s, stage, var_label) {
  df <- merged %>%
    filter(!is.na(.data[[var_r]]), !is.na(.data[[var_s]])) %>%
    mutate(
      diff     = .data[[var_r]] - .data[[var_s]],
      abs_diff = abs(diff),
      denom    = pmax(abs(.data[[var_s]]), 1e-10),
      pct_diff = abs_diff / denom * 100
    )

  if (nrow(df) == 0) return(NULL)

  # Classify each observation
  df$status <- case_when(
    df$abs_diff < TOL_EXACT  ~ "exact",
    df$pct_diff < TOL_CLOSE * 100  ~ "close (<0.1%)",
    df$pct_diff < TOL_ACCEPT * 100 ~ "ok (<1%)",
    df$pct_diff < TOL_FLAG * 100   ~ "warn (<5%)",
    TRUE ~ "DIVERGENT (>5%)"
  )

  summary_row <- data.frame(
    stage    = stage,
    variable = var_label,
    n_obs    = nrow(df),
    n_exact  = sum(df$status == "exact"),
    n_close  = sum(df$status == "close (<0.1%)"),
    n_ok     = sum(df$status == "ok (<1%)"),
    n_warn   = sum(df$status == "warn (<5%)"),
    n_diverge = sum(df$status == "DIVERGENT (>5%)"),
    max_pct_diff = max(df$pct_diff),
    median_pct_diff = median(df$pct_diff),
    stringsAsFactors = FALSE
  )

  # Collect divergent observations for detail
  divergent <- df %>%
    filter(status %in% c("warn (<5%)", "DIVERGENT (>5%)")) %>%
    arrange(desc(pct_diff))

  # Standardize columns for rbind across stages
  divergent <- divergent %>%
    mutate(
      val_R = .data[[var_r]],
      val_S = .data[[var_s]],
      stage = stage,
      variable = var_label,
      year = if ("year" %in% names(.)) year else NA_integer_,
      age_bin = if ("age_bin" %in% names(.)) age_bin else NA_integer_
    ) %>%
    select(stage, variable, wbcode, year, age_bin, val_R, val_S, pct_diff, status)

  list(summary = summary_row, divergent = divergent)
}

# ============================================================================
# STAGE 1: human_capital_2015 (01_assemble output)
# ============================================================================
cat("=== Stage 1: human_capital_2015 ===\n")

hc_R <- readRDS(file.path(output, "human_capital_2015.rds"))
hc_S <- haven::read_dta(file.path(output, "human_capital_2015_102219.dta"))

# Countries in each
countries_R <- sort(unique(hc_R$wbcode))
countries_S <- sort(unique(hc_S$wbcode))
in_R_only <- setdiff(countries_R, countries_S)
in_S_only <- setdiff(countries_S, countries_R)
cat(sprintf("  Countries: R=%d  Stata=%d  R-only: %s  Stata-only: %s\n",
            length(countries_R), length(countries_S),
            ifelse(length(in_R_only) > 0, paste(in_R_only, collapse=","), "none"),
            ifelse(length(in_S_only) > 0, paste(in_S_only, collapse=","), "none")))

# Merge on common countries
m1 <- inner_join(
  hc_R %>% select(wbcode, age_bin, hc_BOTH, hce_BOTH, hch_BOTH, ys_BOTH,
                   qual_BOTH, asr_BOTH, nostu_BOTH, pop_BOTH, gcf, ck, gdp, pov, gini),
  hc_S %>% select(wbcode, age_bin, hc_BOTH, hce_BOTH, hch_BOTH, ys_BOTH,
                   qual_BOTH, asr_BOTH, nostu_BOTH, pop_BOTH, gcf, ck, gdp, pov, gini),
  by = c("wbcode", "age_bin"),
  suffix = c("_R", "_S")
)
cat(sprintf("  Merged observations: %d\n", nrow(m1)))

vars_1 <- c("hc_BOTH", "hce_BOTH", "hch_BOTH", "ys_BOTH", "qual_BOTH",
             "asr_BOTH", "nostu_BOTH", "pop_BOTH", "gcf", "ck", "gdp", "pov", "gini")

for (v in vars_1) {
  res <- compare_var(m1, paste0(v, "_R"), paste0(v, "_S"), "01_assemble", v)
  if (!is.null(res)) all_comparisons[[length(all_comparisons) + 1]] <- res
}

# ============================================================================
# STAGE 2: hcpw_projections (age-bin level, from 02_hc_simulation)
# ============================================================================
cat("\n=== Stage 2: hcpw_projections (age-bin level) ===\n")

hcpw_R <- readRDS(file.path(output, "hcpw_projections.rds"))
hcpw_S <- haven::read_dta(file.path(output, "hcpw_projections_120819.dta"))

m2 <- inner_join(
  hcpw_R %>% select(wbcode, age_bin, year, hc_BOTH, hc_BOTH_constant,
                      hc_BOTH_sc1, hc_BOTH_sc2, hc_BOTH_sc3,
                      hc_BOTH_sc4, hc_BOTH_sc5, pop_BOTH),
  hcpw_S %>% select(wbcode, age_bin, year, hc_BOTH, hc_BOTH_constant,
                      hc_BOTH_sc1, hc_BOTH_sc2, hc_BOTH_sc3,
                      hc_BOTH_sc4, hc_BOTH_sc5, pop_BOTH),
  by = c("wbcode", "age_bin", "year"),
  suffix = c("_R", "_S")
)
cat(sprintf("  Merged observations: %d\n", nrow(m2)))

vars_2 <- c("hc_BOTH", "hc_BOTH_constant", "hc_BOTH_sc1", "hc_BOTH_sc2",
             "hc_BOTH_sc3", "hc_BOTH_sc4", "hc_BOTH_sc5")
for (v in vars_2) {
  res <- compare_var(m2, paste0(v, "_R"), paste0(v, "_S"), "02_hcpw_projections", v)
  if (!is.null(res)) all_comparisons[[length(all_comparisons) + 1]] <- res
}

# ============================================================================
# STAGE 3: hc_projections (country-year level, from 02_hc_simulation)
# ============================================================================
cat("\n=== Stage 3: hc_projections (country-year level) ===\n")

proj_R <- readRDS(file.path(output, "hc_projections.rds"))
proj_S <- haven::read_dta(file.path(output, "hc_projections_102219.dta"))

# Select key variables present in both
key_vars_3 <- c("hcpw_constant", "hcpw_sc1", "hcpw_sc2", "hcpw_sc3", "hcpw_sc4", "hcpw_sc5",
                 "gdppc_constant", "gdppc_sc1", "gdppc_sc2", "gdppc_sc3", "gdppc_sc4", "gdppc_sc5",
                 "gdppw_constant", "gdppw_sc1", "gdppw_sc2", "gdppw_sc3",
                 "kpw_constant", "kpw_sc1", "kpw_sc2", "kpw_sc3",
                 "pov_constant", "pov_sc1", "pov_sc2", "pov_sc3",
                 "pov320_constant", "pov320_sc1", "pov320_sc2",
                 "pov550_constant", "pov550_sc1", "pov550_sc2",
                 "working_pop_both", "total_pop", "total_working", "a")

# Only keep vars that exist in both
vars_in_R <- intersect(key_vars_3, names(proj_R))
vars_in_S <- intersect(key_vars_3, names(proj_S))
vars_3 <- intersect(vars_in_R, vars_in_S)

m3 <- inner_join(
  proj_R %>% select(wbcode, year, all_of(vars_3)),
  proj_S %>% select(wbcode, year, all_of(vars_3)),
  by = c("wbcode", "year"),
  suffix = c("_R", "_S")
)
cat(sprintf("  Merged observations: %d\n", nrow(m3)))

for (v in vars_3) {
  res <- compare_var(m3, paste0(v, "_R"), paste0(v, "_S"), "02_hc_projections", v)
  if (!is.null(res)) all_comparisons[[length(all_comparisons) + 1]] <- res
}

# ============================================================================
# STAGE 4: hc_projections TERTIARY
# ============================================================================
cat("\n=== Stage 4: hc_projections (tertiary) ===\n")

proj_ter_R <- readRDS(file.path(output, "hc_projectionster.rds"))
proj_ter_S <- haven::read_dta(file.path(output, "hc_projections_102219ter.dta"))

vars_ter <- intersect(vars_3, intersect(names(proj_ter_R), names(proj_ter_S)))

m4 <- inner_join(
  proj_ter_R %>% select(wbcode, year, all_of(vars_ter)),
  proj_ter_S %>% select(wbcode, year, all_of(vars_ter)),
  by = c("wbcode", "year"),
  suffix = c("_R", "_S")
)
cat(sprintf("  Merged observations: %d\n", nrow(m4)))

for (v in vars_ter) {
  res <- compare_var(m4, paste0(v, "_R"), paste0(v, "_S"), "02_hc_projections_ter", v)
  if (!is.null(res)) all_comparisons[[length(all_comparisons) + 1]] <- res
}

# ============================================================================
# STAGE 5: GCF/NPV results
# ============================================================================
cat("\n=== Stage 5: GCF/NPV results ===\n")

gcf_R <- readRDS(file.path(output, "gcf_pv_R.rds"))
gcf_S <- haven::read_dta(file.path(output, "gcf_pv_102219.dta"))

m5 <- inner_join(
  gcf_R %>% select(wbcode, gcf_sc4, gcf_sc5, gcf_initial),
  gcf_S %>% select(wbcode, gcf_sc4, gcf_sc5, gcf_initial),
  by = "wbcode",
  suffix = c("_R", "_S")
)
cat(sprintf("  Merged observations: %d\n", nrow(m5)))

for (v in c("gcf_sc4", "gcf_sc5", "gcf_initial")) {
  res <- compare_var(m5, paste0(v, "_R"), paste0(v, "_S"), "04_npv", v)
  if (!is.null(res)) all_comparisons[[length(all_comparisons) + 1]] <- res
}

# ============================================================================
# STAGE 6: Table 3 (fertility)
# ============================================================================
cat("\n=== Stage 6: Table 3 ===\n")

t3_R <- readRDS(file.path(output, "table3_results_R.rds"))
t3_S <- haven::read_dta(file.path(output, "table3_results.dta"))

# Standardize income group names for join
t3_R$Incomegroup <- trimws(t3_R$Incomegroup)
t3_S$Incomegroup <- trimws(t3_S$Incomegroup)

m6 <- inner_join(t3_R, t3_S, by = "Incomegroup", suffix = c("_R", "_S"))
cat(sprintf("  Merged rows: %d\n", nrow(m6)))
m6$wbcode <- m6$Incomegroup  # for compare_var display

for (v in c("hc_increase_typ", "hc_increase_opt", "fert_change_typ", "fert_change_opt",
            "gdppc_increase_typ", "gdppc_increase_opt", "gdppc_fert_typ", "gdppc_fert_opt")) {
  res <- compare_var(m6, paste0(v, "_R"), paste0(v, "_S"), "07_table3", v)
  if (!is.null(res)) all_comparisons[[length(all_comparisons) + 1]] <- res
}

# ============================================================================
# BUILD SUMMARY
# ============================================================================
cat("\n\n")
cat("================================================================\n")
cat("  OBSERVATION-LEVEL VALIDATION SUMMARY\n")
cat("================================================================\n\n")

summary_df <- do.call(rbind, lapply(all_comparisons, function(x) x$summary))
divergent_df <- bind_rows(lapply(all_comparisons, function(x) {
  if (nrow(x$divergent) > 0) x$divergent else NULL
}))

# Print summary table
for (stage in unique(summary_df$stage)) {
  cat(sprintf("\n--- %s ---\n", stage))
  stage_df <- summary_df %>% filter(stage == !!stage)
  for (i in 1:nrow(stage_df)) {
    r <- stage_df[i, ]
    status_emoji <- ifelse(r$n_diverge == 0 & r$n_warn == 0, "PASS",
                           ifelse(r$n_diverge == 0, "WARN", "FAIL"))
    cat(sprintf("  [%s] %-22s  n=%d  exact=%d  close=%d  ok=%d  warn=%d  DIVERGE=%d  max=%.2f%%\n",
                status_emoji, r$variable, r$n_obs, r$n_exact, r$n_close, r$n_ok,
                r$n_warn, r$n_diverge, r$max_pct_diff))
  }
}

# Print divergent observations
if (!is.null(divergent_df) && nrow(divergent_df) > 0) {
  cat("\n\n================================================================\n")
  cat("  DIVERGENT OBSERVATIONS (>5% difference)\n")
  cat("================================================================\n")

  divs_only <- divergent_df %>% filter(status == "DIVERGENT (>5%)")
  if (nrow(divs_only) > 0) {
    # Group by country to see which countries are problematic
    by_country <- divs_only %>%
      group_by(wbcode) %>%
      summarize(n_divergent = n(), max_pct = max(pct_diff),
                stages = paste(unique(stage), collapse=", "),
                variables = paste(unique(variable), collapse=", "),
                .groups = "drop") %>%
      arrange(desc(n_divergent))

    cat("\nDivergent countries:\n")
    print(as.data.frame(by_country), row.names = FALSE)
  }

  cat("\n\nWarning observations (1-5%):\n")
  warns_only <- divergent_df %>% filter(status == "warn (<5%)")
  if (nrow(warns_only) > 0) {
    by_country_warn <- warns_only %>%
      group_by(wbcode) %>%
      summarize(n_warn = n(), max_pct = max(pct_diff),
                stages = paste(unique(stage), collapse=", "),
                .groups = "drop") %>%
      arrange(desc(n_warn))
    print(as.data.frame(head(by_country_warn, 20)), row.names = FALSE)
  }
} else {
  cat("\n  No divergent observations found.\n")
}

# Overall totals
cat("\n\n================================================================\n")
cat("  TOTALS\n")
cat("================================================================\n")
cat(sprintf("  Total comparisons:     %d variable × observation pairs\n", sum(summary_df$n_obs)))
cat(sprintf("  Exact matches:         %d (%.1f%%)\n",
            sum(summary_df$n_exact), sum(summary_df$n_exact) / sum(summary_df$n_obs) * 100))
cat(sprintf("  Close (<0.1%%):         %d (%.1f%%)\n",
            sum(summary_df$n_close), sum(summary_df$n_close) / sum(summary_df$n_obs) * 100))
cat(sprintf("  OK (<1%%):              %d (%.1f%%)\n",
            sum(summary_df$n_ok), sum(summary_df$n_ok) / sum(summary_df$n_obs) * 100))
cat(sprintf("  Warning (1-5%%):        %d (%.1f%%)\n",
            sum(summary_df$n_warn), sum(summary_df$n_warn) / sum(summary_df$n_obs) * 100))
cat(sprintf("  DIVERGENT (>5%%):       %d (%.1f%%)\n",
            sum(summary_df$n_diverge), sum(summary_df$n_diverge) / sum(summary_df$n_obs) * 100))

# Save for report generation
saveRDS(list(summary = summary_df, divergent = divergent_df),
        file.path(output, "validation_results.rds"))
cat("\nResults saved to output/validation_results.rds\n")
