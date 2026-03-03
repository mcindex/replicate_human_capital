# 04_npv_calculations.R — Equivalent of (4) npv_calculations.do
# NPV calculations comparing human vs physical capital investment (Figure 9)
# WARNING: This script is computationally intensive (~10-15 min)

# Parameters
alpha    <- 1/3
pgr      <- 0.013
delta    <- 0.05
phi      <- 0.08
endyear  <- 2100
ys_max   <- 12
adys_max <- 12
discount <- 0.04
increment <- 0.001

years <- seq(2015, endyear, by = 5)

# Load data
hc_2015 <- readRDS(file.path(output, "human_capital_2015.rds"))
pop_bins <- readRDS(file.path(output, "population_bins.rds"))
total_pop_data <- readRDS(file.path(output, "total_population.rds"))
proj_main <- readRDS(file.path(output, "hc_projections.rds"))

# =========================================================================
# Step 1: Calculate PV of sc4 and sc5 scenarios for each country
# =========================================================================
cat("  Step 1: Computing PV of HC scenarios...\n")

pv_by_country <- proj_main %>%
  filter(year > 2015, year <= endyear) %>%
  mutate(
    pv_gdppc_sc4 = gdppc_sc4 / (1 + discount)^(year - 2015),
    pv_gdppc_sc5 = gdppc_sc5 / (1 + discount)^(year - 2015)
  ) %>%
  group_by(wbcode) %>%
  summarize(
    pv_gdppc_sc4 = sum(pv_gdppc_sc4, na.rm = TRUE),
    pv_gdppc_sc5 = sum(pv_gdppc_sc5, na.rm = TRUE),
    wbcountryname = first(wbcountryname),
    .groups = "drop"
  )

# Get initial GCF
gcf_initial_df <- hc_2015 %>%
  select(wbcode, gcf) %>%
  distinct() %>%
  rename(gcf_initial = gcf)

pv_by_country <- pv_by_country %>%
  left_join(gcf_initial_df, by = "wbcode")

# =========================================================================
# Step 2: For each country, find GCF that matches PV of optimistic scenario
# =========================================================================
cat("  Step 2: NPV search loop (this takes a while)...\n")

# Helper: simulate one country with a given GCF, return PV of gdppc
simulate_country_pv <- function(wbcode_val, gcf_val, hc_2015, pop_bins, total_pop_data) {
  # Get starting data for this country
  hc_c <- hc_2015 %>%
    filter(wbcode == wbcode_val, age_bin >= 20, age_bin <= 60) %>%
    select(wbcode, age_bin, hc_BOTH, ys_BOTH, qual_BOTH, hch_BOTH,
           ck, gcf, gini, pov, pov320, pov550, gdp)

  if (nrow(hc_c) == 0) return(NA_real_)

  # Build frame
  frame_c <- expand.grid(age_bin = seq(20, 60, by = 5), year = years, stringsAsFactors = FALSE)
  frame_c$wbcode <- wbcode_val

  frame_c <- frame_c %>%
    left_join(pop_bins %>% filter(iso3c == wbcode_val) %>% select(year, age_bin, pop_BOTH),
              by = c("year", "age_bin"))

  # Starting values
  frame_c <- frame_c %>%
    left_join(hc_c %>% mutate(year = 2015L), by = c("wbcode", "year", "age_bin"))

  # Fill forward constants
  ck_val <- hc_c$ck[1]; gini_val <- hc_c$gini[1]; gdp_val <- hc_c$gdp[1]
  pov_val <- hc_c$pov[1]; pov320_val <- hc_c$pov320[1]; pov550_val <- hc_c$pov550[1]
  frame_c$ck <- ck_val; frame_c$gini <- gini_val; frame_c$gdp <- gdp_val

  # Constant HC scenario (same as before)
  frame_c$ys_c   <- frame_c$ys_BOTH
  frame_c$qual_c <- frame_c$qual_BOTH
  frame_c$hch_c  <- frame_c$hch_BOTH

  frame_c <- frame_c %>% arrange(year, age_bin)

  for (t in years[years > 2015]) {
    for (ab in seq(20, 60, by = 5)) {
      i <- which(frame_c$year == t & frame_c$age_bin == ab)
      prev_ab <- ifelse(ab == 20, 20, ab - 5)
      ip <- which(frame_c$year == (t - 5) & frame_c$age_bin == prev_ab)
      if (length(i) == 1 && length(ip) == 1) {
        frame_c$ys_c[i]   <- frame_c$ys_c[ip]
        frame_c$qual_c[i] <- frame_c$qual_c[ip]
        frame_c$hch_c[i]  <- frame_c$hch_c[ip]
      }
    }
  }

  frame_c$adye_c <- frame_c$ys_c * frame_c$qual_c
  frame_c$hce_c  <- exp(phi * (pmin(frame_c$adye_c, adys_max) - adys_max))
  frame_c$hc_c   <- frame_c$hch_c * frame_c$hce_c

  # Collapse to country-year
  cy <- frame_c %>%
    group_by(year) %>%
    summarize(pop_BOTH = sum(pop_BOTH, na.rm = TRUE),
              a_hc_inv = sum(pop_BOTH * hc_c, na.rm = TRUE),
              .groups = "drop")

  cy$hcpw_inv <- cy$a_hc_inv / cy$pop_BOTH

  # Total population
  tp <- total_pop_data %>% filter(iso3c == wbcode_val)
  cy <- cy %>% left_join(tp, by = c("year" = "year"))

  # Productivity
  cy$gdppw <- ifelse(cy$year == 2015, gdp_val / cy$pop_BOTH, NA_real_)
  cy$kpw   <- ifelse(cy$year == 2015, ck_val / cy$pop_BOTH, NA_real_)
  hcpw_0   <- cy$hcpw_inv[cy$year == 2015]
  a_0      <- cy$gdppw[cy$year == 2015] / ((cy$kpw[cy$year == 2015]^alpha) * (hcpw_0^(1 - alpha)))
  cy$a     <- a_0 * (1 + pgr)^(cy$year - 2015)

  # Sigma
  sigma_c <- qnorm((gini_val + 1) / 2) * sqrt(2)

  # Roll forward capital with given gcf
  cy$kpw_inv <- cy$kpw
  for (j in 2:nrow(cy)) {
    if (cy$year[j] > 2015) {
      pop_ratio <- cy$pop_BOTH[j-1] / cy$pop_BOTH[j]
      cy$kpw_inv[j] <- pop_ratio * (cy$kpw_inv[j-1] + 5 * (gcf_val * cy$a[j-1] *
                        (cy$kpw_inv[j-1]^alpha) * (cy$hcpw_inv[j-1]^(1-alpha)) - delta * cy$kpw_inv[j-1]))
    }
  }

  # GDP per capita
  cy$gdppw_inv <- cy$a * (cy$kpw_inv^alpha) * (cy$hcpw_inv^(1 - alpha))
  cy$gdppc_inv <- cy$gdppw_inv * (cy$total_working / cy$total_pop)

  # PV
  pv <- cy %>%
    filter(year > 2015, year <= endyear) %>%
    summarize(pv = sum(gdppc_inv / (1 + discount)^(year - 2015), na.rm = TRUE))

  return(pv$pv)
}

# Main search loop
countries <- unique(pv_by_country$wbcode)
results <- data.frame(wbcode = countries, gcf_sc4 = NA_real_, gcf_sc5 = NA_real_,
                      stringsAsFactors = FALSE)

for (ci in seq_along(countries)) {
  c_code <- countries[ci]
  pv_sc4 <- pv_by_country$pv_gdppc_sc4[pv_by_country$wbcode == c_code]
  pv_sc5 <- pv_by_country$pv_gdppc_sc5[pv_by_country$wbcode == c_code]
  gcf_start <- pv_by_country$gcf_initial[pv_by_country$wbcode == c_code]

  if (is.na(gcf_start) || is.na(pv_sc5)) next

  if (ci %% 10 == 1) cat(sprintf("    Country %d/%d: %s\n", ci, length(countries), c_code))

  # Search: increment GCF until PV exceeds optimistic scenario
  g <- gcf_start
  best_sc4 <- list(gcf = g, diff = Inf)
  best_sc5 <- list(gcf = g, diff = Inf)

  repeat {
    g <- g + increment
    pv_inv <- simulate_country_pv(c_code, g, hc_2015, pop_bins, total_pop_data)
    if (is.na(pv_inv)) break

    d_sc4 <- abs(pv_inv - pv_sc4)
    d_sc5 <- abs(pv_inv - pv_sc5)

    if (d_sc4 < best_sc4$diff) best_sc4 <- list(gcf = g, diff = d_sc4)
    if (d_sc5 < best_sc5$diff) best_sc5 <- list(gcf = g, diff = d_sc5)

    if (pv_inv >= pv_sc5) break
    if (g > 1) break  # Safety: GCF can't exceed 100%
  }

  results$gcf_sc4[results$wbcode == c_code] <- best_sc4$gcf
  results$gcf_sc5[results$wbcode == c_code] <- best_sc5$gcf
}

# Merge initial GCF
results <- results %>%
  left_join(gcf_initial_df, by = "wbcode")

saveRDS(results, file.path(output, "gcf_pv_R.rds"))

# =========================================================================
# Figure 9: Scatterplots
# =========================================================================
cat("  Generating Figure 9...\n")

# Merge starting GDP
proj_2015 <- proj_main %>% filter(year == 2015) %>% select(wbcode, gdppc_constant)
results <- results %>% left_join(proj_2015, by = "wbcode")

# Merge country categories
categories <- readRDS(file.path(output, "country_categories.rds"))
results <- results %>% left_join(categories, by = "wbcode")

results$diff_sc4 <- (results$gcf_sc4 - results$gcf_initial) * 100
results$diff_sc5 <- (results$gcf_sc5 - results$gcf_initial) * 100

# Merge health & education expenditure
source(file.path(codedir, "scenario_calc.R"))

wb_exp <- haven::read_dta(file.path(input, "wb_health_education_expenditure_2019vintage.dta"))
wb_exp <- wb_exp %>%
  arrange(countrycode, year)

# Forward-fill within country
for (y in 2000:2018) {
  wb_exp <- wb_exp %>%
    group_by(countrycode) %>%
    mutate(
      educ_gdp = ifelse(is.na(educ_gdp) & year == y, lag(educ_gdp), educ_gdp),
      health_gdp = ifelse(is.na(health_gdp) & year == y, lag(health_gdp), health_gdp)
    ) %>%
    ungroup()
}
wb_2018 <- wb_exp %>% filter(year == 2018) %>% select(countrycode, educ_gdp, health_gdp)

# Merge HC at age 20
hc_20 <- hc_2015 %>% filter(age_bin == 20) %>% select(wbcode, hc_BOTH)
results <- results %>%
  left_join(wb_2018, by = c("wbcode" = "countrycode")) %>%
  left_join(hc_20, by = "wbcode")

results$cost_hci <- results$hc_BOTH / (results$educ_gdp + results$health_gdp)

# Cost of HC improvement
results$change_hci_50_per <- (hci_gap_5rate_50 * (1 - results$hc_BOTH)) / results$hc_BOTH
results$change_hci_75_per <- (hci_gap_5rate_75 * (1 - results$hc_BOTH)) / results$hc_BOTH
results$cost_50 <- results$change_hci_50_per * (results$educ_gdp + results$health_gdp)
results$cost_75 <- results$change_hci_75_per * (results$educ_gdp + results$health_gdp)

# Figure 9a: cost_50 vs diff_sc4
p1 <- ggplot(results %>% filter(!is.na(cost_50) & !is.na(diff_sc4)),
             aes(x = diff_sc4, y = cost_50)) +
  geom_text(aes(label = wbcode), size = 2.5, alpha = 0.8) +
  geom_abline(slope = 1, intercept = 0, color = "black") +
  annotate("text", x = 0.35, y = 1.07, label = "45 degree line", size = 3) +
  labs(y = "Extra human capital investment (% of GDP)",
       x = "Extra physical capital investment (% of GDP)",
       title = "Typical scenario") +
  theme_minimal()
ggsave(file.path(graphs, "cost_corr50_R.png"), p1, width = 8, height = 6, dpi = 200)

# Figure 9b: cost_75 vs diff_sc5
p2 <- ggplot(results %>% filter(!is.na(cost_75) & !is.na(diff_sc5)),
             aes(x = diff_sc5, y = cost_75)) +
  geom_text(aes(label = wbcode), size = 2.5, alpha = 0.8) +
  geom_abline(slope = 1, intercept = 0, color = "black") +
  annotate("text", x = 1, y = 2.8, label = "45 degree line", size = 3) +
  labs(y = "Extra human capital investment (% of GDP)",
       x = "Extra physical capital investment (% of GDP)",
       title = "Optimistic scenario") +
  theme_minimal()
ggsave(file.path(graphs, "cost_corr75_R.png"), p2, width = 8, height = 6, dpi = 200)

# Ratio plots
results$ratio_50 <- results$diff_sc4 / results$cost_50
results$ratio_75 <- results$diff_sc5 / results$cost_75

p3 <- ggplot(results %>% filter(!is.na(ratio_50)),
             aes(x = gdppc_constant, y = ratio_50)) +
  geom_text(aes(label = wbcode), size = 2.5, alpha = 0.8) +
  scale_x_log10(labels = scales::comma) +
  labs(y = "Ratio of required physical to human capital investment",
       x = "GDP per capita (2015, log scale)", title = "Typical scenario") +
  theme_minimal()
ggsave(file.path(graphs, "cost_ratio50_R.png"), p3, width = 8, height = 6, dpi = 200)

p4 <- ggplot(results %>% filter(!is.na(ratio_75)),
             aes(x = gdppc_constant, y = ratio_75)) +
  geom_text(aes(label = wbcode), size = 2.5, alpha = 0.8) +
  scale_x_log10(labels = scales::comma) +
  labs(y = "Ratio of required physical to human capital investment",
       x = "GDP per capita (2015, log scale)", title = "Optimistic scenario") +
  theme_minimal()
ggsave(file.path(graphs, "cost_ratio75_R.png"), p4, width = 8, height = 6, dpi = 200)

cat("  04_npv_calculations.R complete.\n")
