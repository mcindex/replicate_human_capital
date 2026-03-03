# 05_cambodia_counterfactual.R — Equivalent of (5) cambodia_counterfactual.do
# Cambodia-specific analysis with 3 scenarios: HCI gap closure, investment boost, NPV-equivalent

# Parameters
alpha   <- 1/3
pgr     <- 0.013
delta   <- 0.05
phi     <- 0.08
endyear <- 2100
ys_max  <- 12
adys_max <- 12

years <- seq(2015, endyear, by = 5)

# Load data
hc_2015 <- readRDS(file.path(output, "human_capital_2015.rds"))
pop_bins <- readRDS(file.path(output, "population_bins.rds"))
gcf_pv  <- readRDS(file.path(output, "gcf_pv_R.rds"))  # From npv_calculations.R
total_pop_data <- readRDS(file.path(output, "total_population.rds"))

# Re-run scenario calculation for typical rate
source(file.path(codedir, "scenario_calc.R"))

# Build frame for all countries, then filter to Cambodia
frame <- expand.grid(
  wbcode = unique(hc_2015$wbcode),
  age_bin = seq(20, 60, by = 5),
  year = years,
  stringsAsFactors = FALSE
)

frame <- frame %>%
  left_join(pop_bins %>% select(iso3c, year, age_bin, pop_BOTH),
            by = c("wbcode" = "iso3c", "year", "age_bin"))

hc_start <- hc_2015 %>%
  filter(age_bin >= 20, age_bin <= 60) %>%
  select(wbcode, age_bin, hc_BOTH, ys_BOTH, qual_BOTH, hch_BOTH,
         ck, gcf, gini, pov, pov320, pov550, gdp, wbcountryname,
         Incomegroup, Lendingcategory, Region) %>%
  mutate(year = 2015L)

frame <- frame %>%
  left_join(hc_start, by = c("wbcode", "year", "age_bin")) %>%
  group_by(wbcode) %>%
  tidyr::fill(ck, gcf, gini, pov, pov320, pov550, gdp, wbcountryname,
              Incomegroup, Lendingcategory, Region, .direction = "down") %>%
  ungroup()

# Merge GCF PV data
frame <- frame %>%
  left_join(gcf_pv %>% select(wbcode, gcf_initial, gcf_sc4, gcf_sc5),
            by = "wbcode")

# Filter to Cambodia
khm <- frame %>% filter(wbcode == "KHM")
khm$a_hc <- khm$pop_BOTH * khm$hc_BOTH

# --- CONSTANT SCENARIO ---
khm$ys_BOTH_constant   <- khm$ys_BOTH
khm$qual_BOTH_constant <- khm$qual_BOTH
khm$hch_BOTH_constant  <- khm$hch_BOTH

khm <- khm %>% arrange(year, age_bin)
for (t in years[years > 2015]) {
  for (ab in seq(20, 60, by = 5)) {
    i <- which(khm$year == t & khm$age_bin == ab)
    prev_ab <- ifelse(ab == 20, 20, ab - 5)
    ip <- which(khm$year == (t - 5) & khm$age_bin == prev_ab)
    if (length(i) == 1 && length(ip) == 1) {
      khm$ys_BOTH_constant[i]   <- khm$ys_BOTH_constant[ip]
      khm$qual_BOTH_constant[i] <- khm$qual_BOTH_constant[ip]
      khm$hch_BOTH_constant[i]  <- khm$hch_BOTH_constant[ip]
    }
  }
}
khm$adye_BOTH_constant <- khm$ys_BOTH_constant * khm$qual_BOTH_constant
khm$hce_BOTH_constant  <- exp(phi * (pmin(khm$adye_BOTH_constant, adys_max) - adys_max))
khm$hc_BOTH_constant   <- khm$hch_BOTH_constant * khm$hce_BOTH_constant
khm$a_hc_constant      <- khm$pop_BOTH * khm$hc_BOTH_constant

# --- SCENARIO 1 (HCI6): One-period typical gap closure ---
khm$hc_BOTH_hci6 <- khm$hc_BOTH
hc_init <- khm$hc_BOTH[khm$year == 2015 & khm$age_bin == 20]

for (t in years[years > 2015]) {
  for (ab in seq(20, 60, by = 5)) {
    i <- which(khm$year == t & khm$age_bin == ab)
    if (ab == 20) {
      khm$hc_BOTH_hci6[i] <- 1 - ((1 - hci_gap_5rate_50) * (1 - hc_init))
    } else {
      ip <- which(khm$year == (t - 5) & khm$age_bin == (ab - 5))
      if (length(ip) == 1) khm$hc_BOTH_hci6[i] <- khm$hc_BOTH_hci6[ip]
    }
  }
}
khm$a_hc_hci6 <- khm$pop_BOTH * khm$hc_BOTH_hci6

# Calculate HC change ratio (for investment scenario)
hc_at_20_2020 <- khm$hc_BOTH_hci6[khm$year == 2020 & khm$age_bin == 20]
hc_at_20_2015 <- khm$hc_BOTH_hci6[khm$year == 2015 & khm$age_bin == 20]
hcchange <- hc_at_20_2020 / hc_at_20_2015
hcpincrease <- ((hc_at_20_2020 - hc_at_20_2015) / hc_at_20_2015) * 100

# --- SCENARIO 2 (INVESTMENT): Increase GCF to match steady-state effect ---
gcf_original <- khm$gcf[1]
gcf_investment_val <- gcf_original * (hcchange)^((1 - alpha) / alpha)
factorscale <- (hcchange)^((1 - alpha) / alpha)

khm$gcf_constant   <- gcf_original
khm$gcf_hci6       <- gcf_original
khm$gcf_investment  <- gcf_investment_val

# Investment scenario uses same HC as constant (no HC improvement)
khm$ys_BOTH_investment   <- khm$ys_BOTH
khm$qual_BOTH_investment <- khm$qual_BOTH
khm$hch_BOTH_investment  <- khm$hch_BOTH

for (t in years[years > 2015]) {
  for (ab in seq(20, 60, by = 5)) {
    i <- which(khm$year == t & khm$age_bin == ab)
    prev_ab <- ifelse(ab == 20, 20, ab - 5)
    ip <- which(khm$year == (t - 5) & khm$age_bin == prev_ab)
    if (length(i) == 1 && length(ip) == 1) {
      khm$ys_BOTH_investment[i]   <- khm$ys_BOTH_investment[ip]
      khm$qual_BOTH_investment[i] <- khm$qual_BOTH_investment[ip]
      khm$hch_BOTH_investment[i]  <- khm$hch_BOTH_investment[ip]
    }
  }
}
khm$adye_BOTH_investment <- khm$ys_BOTH_investment * khm$qual_BOTH_investment
khm$hce_BOTH_investment  <- exp(phi * (pmin(khm$adye_BOTH_investment, adys_max) - adys_max))
khm$hc_BOTH_investment   <- khm$hch_BOTH_investment * khm$hce_BOTH_investment
khm$a_hc_investment      <- khm$pop_BOTH * khm$hc_BOTH_investment

# --- SCENARIO 3 (NPV): GCF at NPV-equivalent level ---
gcf_npv_val <- gcf_pv$gcf_sc4[gcf_pv$wbcode == "KHM"]

khm$gcf_npv <- gcf_npv_val
khm$ys_BOTH_npv   <- khm$ys_BOTH
khm$qual_BOTH_npv <- khm$qual_BOTH
khm$hch_BOTH_npv  <- khm$hch_BOTH

for (t in years[years > 2015]) {
  for (ab in seq(20, 60, by = 5)) {
    i <- which(khm$year == t & khm$age_bin == ab)
    prev_ab <- ifelse(ab == 20, 20, ab - 5)
    ip <- which(khm$year == (t - 5) & khm$age_bin == prev_ab)
    if (length(i) == 1 && length(ip) == 1) {
      khm$ys_BOTH_npv[i]   <- khm$ys_BOTH_npv[ip]
      khm$qual_BOTH_npv[i] <- khm$qual_BOTH_npv[ip]
      khm$hch_BOTH_npv[i]  <- khm$hch_BOTH_npv[ip]
    }
  }
}
khm$adye_BOTH_npv <- khm$ys_BOTH_npv * khm$qual_BOTH_npv
khm$hce_BOTH_npv  <- exp(phi * (pmin(khm$adye_BOTH_npv, adys_max) - adys_max))
khm$hc_BOTH_npv   <- khm$hch_BOTH_npv * khm$hce_BOTH_npv
khm$a_hc_npv      <- khm$pop_BOTH * khm$hc_BOTH_npv

# =========================================================================
# Collapse to country-year
# =========================================================================
khm_proj <- khm %>%
  group_by(wbcode, year) %>%
  summarize(
    pop_BOTH = sum(pop_BOTH, na.rm = TRUE),
    a_hc = sum(khm$pop_BOTH * khm$hc_BOTH, na.rm = FALSE),
    a_hc_constant   = sum(a_hc_constant, na.rm = TRUE),
    a_hc_hci6       = sum(a_hc_hci6, na.rm = TRUE),
    a_hc_investment = sum(a_hc_investment, na.rm = TRUE),
    a_hc_npv        = sum(a_hc_npv, na.rm = TRUE),
    ck = first(ck), gcf = first(gcf), gini = first(gini),
    pov = first(pov), pov320 = first(pov320), pov550 = first(pov550),
    gdp = first(gdp),
    gcf_constant = first(gcf_constant), gcf_hci6 = first(gcf_hci6),
    gcf_investment = first(gcf_investment), gcf_npv = first(gcf_npv),
    wbcountryname = first(wbcountryname),
    .groups = "drop"
  )

# HCPW
for (sc in c("constant", "hci6", "investment", "npv")) {
  khm_proj[[paste0("hcpw_", sc)]] <- khm_proj[[paste0("a_hc_", sc)]] / khm_proj$pop_BOTH
}

# Total population
khm_proj <- khm_proj %>%
  left_join(total_pop_data, by = c("wbcode" = "iso3c", "year"))

# Productivity
khm_proj <- khm_proj %>%
  mutate(
    gdppw = ifelse(year == 2015, gdp / pop_BOTH, NA_real_),
    hcpw  = ifelse(year == 2015, sum(khm$pop_BOTH[khm$year == 2015] * khm$hc_BOTH[khm$year == 2015], na.rm = TRUE) / pop_BOTH, NA_real_),
    kpw   = ifelse(year == 2015, ck / pop_BOTH, NA_real_),
    a     = ifelse(year == 2015, gdppw / ((kpw^alpha) * (hcpw_constant^(1 - alpha))), NA_real_)
  )
a_2015 <- khm_proj$a[khm_proj$year == 2015]
khm_proj$a <- ifelse(khm_proj$year > 2015, a_2015 * (1 + pgr)^(khm_proj$year - 2015), khm_proj$a)

# Sigma
sigma_khm <- qnorm((khm_proj$gini[1] + 1) / 2) * sqrt(2)

# GDP and poverty for each scenario
for (scenario in c("constant", "investment", "hci6", "npv")) {
  hcpw_col <- paste0("hcpw_", scenario)
  gcf_col  <- paste0("gcf_", scenario)
  kpw_col  <- paste0("kpw_", scenario)

  khm_proj[[kpw_col]] <- khm_proj$ck / khm_proj$pop_BOTH
  khm_proj[[paste0("pov_", scenario)]] <- khm_proj$pov
  khm_proj[[paste0("pov320_", scenario)]] <- khm_proj$pov320
  khm_proj[[paste0("pov550_", scenario)]] <- khm_proj$pov550

  for (j in 2:nrow(khm_proj)) {
    if (khm_proj$year[j] > 2015) {
      pop_ratio <- khm_proj$pop_BOTH[j-1] / khm_proj$pop_BOTH[j]
      kpw_prev <- khm_proj[[kpw_col]][j-1]
      gcf_val <- khm_proj[[gcf_col]][j-1]
      a_val <- khm_proj$a[j-1]
      hcpw_val <- khm_proj[[hcpw_col]][j-1]
      khm_proj[[kpw_col]][j] <- pop_ratio * (kpw_prev + 5 * (gcf_val * a_val *
                                 (kpw_prev^alpha) * (hcpw_val^(1-alpha)) - delta * kpw_prev))
    }
  }

  khm_proj[[paste0("gdppw_", scenario)]] <- khm_proj$a * (khm_proj[[kpw_col]]^alpha) * (khm_proj[[hcpw_col]]^(1-alpha))
  khm_proj[[paste0("gdppc_", scenario)]] <- khm_proj[[paste0("gdppw_", scenario)]] * (khm_proj$total_working / khm_proj$total_pop)

  gdppc_0 <- khm_proj[[paste0("gdppc_", scenario)]][1]
  pov_0 <- khm_proj$pov[1]
  for (j in 2:nrow(khm_proj)) {
    gdppc_t <- khm_proj[[paste0("gdppc_", scenario)]][j]
    if (!is.na(pov_0) && !is.na(gdppc_t) && pov_0 > 0) {
      khm_proj[[paste0("pov_", scenario)]][j] <- pnorm(qnorm(pov_0) - (1/sigma_khm) * log(gdppc_t/gdppc_0))
    }
  }

  khm_proj[[paste0("gdppw_", scenario, "_r")]] <- khm_proj[[paste0("gdppw_", scenario)]] / khm_proj$gdppw_constant
  khm_proj[[paste0("gdppc_", scenario, "_r")]] <- khm_proj[[paste0("gdppc_", scenario)]] / khm_proj$gdppc_constant
}

# =========================================================================
# Figure 8: Cambodia counterfactual
# =========================================================================
lrate50_val <- round(hci_gap_5rate_50p, 1)
gcf_i_pp <- round((gcf_investment_val - gcf_original) * 100, 1)
gcf_npv_pp <- round((gcf_npv_val - gcf_original) * 100, 1)

df_cam <- khm_proj %>%
  select(year, gdppc_hci6_r, gdppc_investment_r, gdppc_npv_r) %>%
  pivot_longer(-year, names_to = "scenario", values_to = "ratio") %>%
  mutate(scenario = case_when(
    scenario == "gdppc_hci6_r" ~ paste0("HCI gap reduction by ", lrate50_val, "%"),
    scenario == "gdppc_investment_r" ~ paste0("Investment increase by ", gcf_i_pp, " pp (steady state)"),
    scenario == "gdppc_npv_r" ~ paste0("Investment increase by ", gcf_npv_pp, " pp (same PV)")
  ))

p <- ggplot(df_cam, aes(x = year, y = ratio, linetype = scenario)) +
  geom_line(linewidth = 1) +
  scale_linetype_manual(values = c("solid", "dotted", "dashed")) +
  labs(y = "GDP-per-capita relative to baseline scenario", x = "", linetype = NULL,
       title = "Cambodia") +
  theme_minimal() +
  theme(legend.position = "bottom", legend.direction = "vertical")
ggsave(file.path(graphs, "cambodia_R.png"), p, width = 10, height = 6, dpi = 200)

# Print key results
cat(sprintf("  HC start: %.3f, HC end: %.3f, HC increase: %.1f%%\n",
            hc_at_20_2015, hc_at_20_2020, hcpincrease))
cat(sprintf("  GCF original: %.1f%%, GCF investment: %.1f%%, GCF NPV: %.3f\n",
            gcf_original * 100, gcf_investment_val * 100, gcf_npv_val))
cat(sprintf("  GDP/cap 2030 (HCI): %.1f%%, (Inv): %.1f%%, (NPV): %.1f%%\n",
            (khm_proj$gdppc_hci6_r[4] - 1) * 100,
            (khm_proj$gdppc_investment_r[4] - 1) * 100,
            (khm_proj$gdppc_npv_r[4] - 1) * 100))

cat("  05_cambodia_counterfactual.R complete.\n")
