# 02_hc_simulation.R — Equivalent of (2) hc_simulation.do + 2.1 scenario.do
# Projects human capital per worker under baseline + 5 scenarios,
# then calculates GDP per capita and poverty rates over time.

# Parameters
alpha   <- 1/3
pgr     <- 0.0130
delta   <- 0.05
phi     <- 0.08
endyear <- 2100

tertiary <- if (exists("tertiary_mode")) tertiary_mode else "No"
if (tertiary == "Yes") {
  ys_max   <- 16
  adys_max <- 16
  fname    <- "ter"
} else {
  ys_max   <- 12
  adys_max <- 12
  fname    <- ""
}

# =========================================================================
# Run scenario calculation (returns hci_gap_5rate_50, hci_gap_5rate_75)
# =========================================================================
source(file.path(codedir, "scenario_calc.R"))

# =========================================================================
# Create frame: country x year x age_bin
# =========================================================================
cat("  Creating simulation frame...\n")
hc_2015 <- readRDS(file.path(output, paste0("human_capital_2015", fname, ".rds")))
pop_bins <- readRDS(file.path(output, "population_bins.rds"))

# Expand to all years
years <- seq(2015, endyear, by = 5)
frame <- expand.grid(
  wbcode = unique(hc_2015$wbcode),
  age_bin = unique(hc_2015$age_bin),
  year = years,
  stringsAsFactors = FALSE
)

# Keep working age only
frame <- frame %>% filter(age_bin >= 20, age_bin <= 60)

# Merge population bins
frame <- frame %>%
  left_join(pop_bins %>% select(iso3c, year, age_bin, pop_BOTH),
            by = c("wbcode" = "iso3c", "year", "age_bin"))

# Merge starting values (2015 only)
hc_start <- hc_2015 %>%
  filter(age_bin >= 20, age_bin <= 60) %>%
  select(wbcode, age_bin, hc_BOTH, ys_BOTH, qual_BOTH, hch_BOTH, hce_BOTH,
         ck, gcf, gini, pov, pov320, pov550, gdp, wbcountryname,
         Incomegroup, Lendingcategory, Region) %>%
  mutate(year = 2015L)

frame <- frame %>%
  left_join(hc_start, by = c("wbcode", "year", "age_bin"))

# Fill forward country-level constants
frame <- frame %>%
  group_by(wbcode) %>%
  arrange(wbcode, year, age_bin) %>%
  tidyr::fill(ck, gcf, gini, pov, pov320, pov550, gdp, wbcountryname,
              Incomegroup, Lendingcategory, Region, .direction = "down") %>%
  ungroup()

# Aggregate HC at T0
frame$a_hc <- frame$pop_BOTH * frame$hc_BOTH

# =========================================================================
# STEP 1: Age-bin specific scenario calculations
# =========================================================================
cat("  Running scenarios...\n")

# Number of age bins in working age (20,25,...,60 = 9 bins)
n_bins <- 9

# --- CONSTANT SCENARIO ---
frame$ys_BOTH_constant   <- frame$ys_BOTH
frame$qual_BOTH_constant <- frame$qual_BOTH
frame$hch_BOTH_constant  <- frame$hch_BOTH

frame <- frame %>% arrange(wbcode, year, age_bin)

for (t in years[years > 2015]) {
  idx_t <- which(frame$year == t)
  for (i in idx_t) {
    wb <- frame$wbcode[i]
    ab <- frame$age_bin[i]
    # Find the row for same country, previous year (t-5), age_bin 20
    # For age_bin == 20: carry forward from previous period's age_bin 20 (same cohort entering)
    # For age_bin > 20:  carry forward from previous period's (age_bin - 5) (aging forward)
    if (ab == 20) {
      prev_idx <- which(frame$wbcode == wb & frame$year == (t - 5) & frame$age_bin == 20)
    } else {
      prev_idx <- which(frame$wbcode == wb & frame$year == (t - 5) & frame$age_bin == (ab - 5))
    }
    if (length(prev_idx) == 1) {
      frame$ys_BOTH_constant[i]   <- frame$ys_BOTH_constant[prev_idx]
      frame$qual_BOTH_constant[i] <- frame$qual_BOTH_constant[prev_idx]
      frame$hch_BOTH_constant[i]  <- frame$hch_BOTH_constant[prev_idx]
    }
  }
}

frame$adye_BOTH_constant <- frame$ys_BOTH_constant * frame$qual_BOTH_constant
frame$hce_BOTH_constant  <- exp(phi * (pmin(frame$adye_BOTH_constant, adys_max) - adys_max))
frame$hc_BOTH_constant   <- frame$hch_BOTH_constant * frame$hce_BOTH_constant
frame$a_hc_constant      <- frame$pop_BOTH * frame$hc_BOTH_constant

# --- Helper function for HC scenarios ---
run_hc_scenario <- function(frame, rate, scenario_name, one_period = FALSE) {
  col <- paste0("hc_BOTH_", scenario_name)
  acol <- paste0("a_hc_", scenario_name)
  frame[[col]] <- frame$hc_BOTH

  for (t in years[years > 2015]) {
    idx_t <- which(frame$year == t)
    for (i in idx_t) {
      wb <- frame$wbcode[i]
      ab <- frame$age_bin[i]

      if (ab == 20) {
        if (one_period) {
          # One-period: use initial HC value (first obs for this country at age 20)
          first_idx <- which(frame$wbcode == wb & frame$year == 2015 & frame$age_bin == 20)
          if (length(first_idx) == 1) {
            frame[[col]][i] <- 1 - ((1 - rate) * (1 - frame$hc_BOTH[first_idx]))
          }
        } else if (is.infinite(rate) || rate >= 1) {
          # Immediate closure
          frame[[col]][i] <- 1
        } else {
          # Progressive gap closure
          prev_idx <- which(frame$wbcode == wb & frame$year == (t - 5) & frame$age_bin == 20)
          if (length(prev_idx) == 1) {
            frame[[col]][i] <- 1 - ((1 - rate) * (1 - frame[[col]][prev_idx]))
          }
        }
      } else {
        # Aging forward
        prev_idx <- which(frame$wbcode == wb & frame$year == (t - 5) & frame$age_bin == (ab - 5))
        if (length(prev_idx) == 1) {
          frame[[col]][i] <- frame[[col]][prev_idx]
        }
      }
    }
  }

  frame[[acol]] <- frame$pop_BOTH * frame[[col]]
  frame
}

frame <- run_hc_scenario(frame, hci_gap_5rate_50, "sc1")
frame <- run_hc_scenario(frame, hci_gap_5rate_75, "sc2")
frame <- run_hc_scenario(frame, Inf, "sc3")               # Immediate
frame <- run_hc_scenario(frame, hci_gap_5rate_50, "sc4", one_period = TRUE)
frame <- run_hc_scenario(frame, hci_gap_5rate_75, "sc5", one_period = TRUE)

# =========================================================================
# Save HCPW projections (age-bin level, for labor participation later)
# =========================================================================
saveRDS(frame, file.path(output, paste0("hcpw_projections", fname, ".rds")))

# =========================================================================
# STEP 2: Collapse to country-year level
# =========================================================================
cat("  Collapsing to country-year...\n")

proj <- frame %>%
  group_by(wbcode, year) %>%
  summarize(
    working_pop_both = sum(pop_BOTH, na.rm = TRUE),
    a_hc         = sum(a_hc, na.rm = TRUE),
    a_hc_constant = sum(a_hc_constant, na.rm = TRUE),
    a_hc_sc1     = sum(a_hc_sc1, na.rm = TRUE),
    a_hc_sc2     = sum(a_hc_sc2, na.rm = TRUE),
    a_hc_sc3     = sum(a_hc_sc3, na.rm = TRUE),
    a_hc_sc4     = sum(a_hc_sc4, na.rm = TRUE),
    a_hc_sc5     = sum(a_hc_sc5, na.rm = TRUE),
    wbcountryname = first(wbcountryname),
    ck = first(ck), gcf = first(gcf), gini = first(gini),
    pov = first(pov), pov320 = first(pov320), pov550 = first(pov550),
    gdp = first(gdp),
    Incomegroup = first(Incomegroup), Lendingcategory = first(Lendingcategory),
    Region = first(Region),
    .groups = "drop"
  )

# Calculate HCPW
proj$hcpw_baseline <- proj$a_hc / proj$working_pop_both
# Hold baseline HCPW constant at 2015 value
proj <- proj %>%
  group_by(wbcode) %>%
  mutate(hcpw_baseline = first(hcpw_baseline)) %>%
  ungroup()

for (sc in c("constant", "sc1", "sc2", "sc3", "sc4", "sc5")) {
  proj[[paste0("hcpw_", sc)]] <- proj[[paste0("a_hc_", sc)]] / proj$working_pop_both
}

# Merge total population
total_pop <- readRDS(file.path(output, "total_population.rds"))
proj <- proj %>%
  left_join(total_pop, by = c("wbcode" = "iso3c", "year"))

# =========================================================================
# STEP 3: Calculate productivity
# =========================================================================
cat("  Calculating productivity and GDP...\n")

proj <- proj %>%
  group_by(wbcode) %>%
  mutate(
    gdppw = ifelse(year == 2015, gdp / working_pop_both, NA_real_),
    hcpw  = ifelse(year == 2015, a_hc / working_pop_both, NA_real_),
    kpw   = ifelse(year == 2015, ck / working_pop_both, NA_real_),
    a     = ifelse(year == 2015, gdppw / ((kpw^alpha) * (hcpw_baseline^(1 - alpha))), NA_real_)
  ) %>%
  ungroup()

# Roll productivity forward
proj <- proj %>%
  group_by(wbcode) %>%
  mutate(a = ifelse(year > 2015, first(a) * (1 + pgr)^(year - 2015), a)) %>%
  ungroup()

# =========================================================================
# STEP 4: Final calculations — GDP, poverty for each scenario
# =========================================================================

# Sigma from Gini
proj$sigma <- qnorm((proj$gini + 1) / 2) * sqrt(2)
proj <- proj %>%
  group_by(wbcode) %>%
  mutate(sigma = first(sigma)) %>%
  ungroup()

scenarios <- c("constant", "baseline", "sc1", "sc2", "sc3", "sc4", "sc5")

for (scenario in scenarios) {
  hcpw_col <- paste0("hcpw_", scenario)

  # Initialize capital and poverty
  proj[[paste0("kpw_", scenario)]]    <- proj$ck / proj$working_pop_both
  proj[[paste0("pov_", scenario)]]    <- proj$pov
  proj[[paste0("pov320_", scenario)]] <- proj$pov320
  proj[[paste0("pov550_", scenario)]] <- proj$pov550

  kpw_col    <- paste0("kpw_", scenario)
  pov_col    <- paste0("pov_", scenario)
  pov320_col <- paste0("pov320_", scenario)
  pov550_col <- paste0("pov550_", scenario)

  # Roll forward capital (equation 24)
  proj <- proj %>% arrange(wbcode, year)
  countries <- unique(proj$wbcode)

  for (c in countries) {
    cidx <- which(proj$wbcode == c)
    for (j in 2:length(cidx)) {
      i <- cidx[j]
      ip <- cidx[j - 1]
      if (proj$year[i] > 2015) {
        pop_ratio <- proj$working_pop_both[ip] / proj$working_pop_both[i]
        kpw_prev  <- proj[[kpw_col]][ip]
        gcf_val   <- proj$gcf[ip]
        a_val     <- proj$a[ip]
        hcpw_val  <- proj[[hcpw_col]][ip]

        proj[[kpw_col]][i] <- pop_ratio * (kpw_prev + 5 * (gcf_val * a_val *
                              (kpw_prev^alpha) * (hcpw_val^(1 - alpha)) - delta * kpw_prev))
      }
    }
  }

  # GDP per worker and per capita
  proj[[paste0("gdppw_", scenario)]] <- proj$a * (proj[[kpw_col]]^alpha) * (proj[[hcpw_col]]^(1 - alpha))
  proj[[paste0("gdppc_", scenario)]] <- proj[[paste0("gdppw_", scenario)]] * (proj$total_working / proj$total_pop)

  # Poverty update
  gdppc_col <- paste0("gdppc_", scenario)
  for (c in countries) {
    cidx <- which(proj$wbcode == c)
    gdppc_0 <- proj[[gdppc_col]][cidx[1]]
    for (p_prefix in c("pov", "pov320", "pov550")) {
      p_col <- paste0(p_prefix, "_", scenario)
      pov_0 <- proj[[p_col]][cidx[1]]
      if (!is.na(pov_0) && !is.na(gdppc_0) && !is.na(proj$sigma[cidx[1]]) && pov_0 > 0) {
        for (j in 2:length(cidx)) {
          i <- cidx[j]
          gdppc_t <- proj[[gdppc_col]][i]
          if (!is.na(gdppc_t) && gdppc_t > 0) {
            proj[[p_col]][i] <- pnorm(qnorm(pov_0) - (1 / proj$sigma[cidx[1]]) * log(gdppc_t / gdppc_0))
          }
        }
      }
    }
  }

  # Relative measures
  proj[[paste0("gdppw_", scenario, "_r")]] <- proj[[paste0("gdppw_", scenario)]] / proj$gdppw_constant
  proj[[paste0("gdppc_", scenario, "_r")]] <- proj[[gdppc_col]] / proj$gdppc_constant

  for (p_prefix in c("pov", "pov320", "pov550")) {
    proj[[paste0(p_prefix, "_", scenario, "_r")]] <- proj[[paste0(p_prefix, "_", scenario)]] / proj[[paste0(p_prefix, "_constant")]]
    proj[[paste0(p_prefix, "_", scenario, "_p")]] <- proj[[paste0(p_prefix, "_", scenario)]] - proj[[paste0(p_prefix, "_constant")]]
  }
}

# Fill forward country names etc.
proj <- proj %>%
  group_by(wbcode) %>%
  tidyr::fill(wbcountryname, Incomegroup, Lendingcategory, Region, .direction = "down") %>%
  ungroup()

# Save
saveRDS(proj, file.path(output, paste0("hc_projections", fname, ".rds")))

cat("  02_hc_simulation.R complete. Countries:", length(unique(proj$wbcode)), "\n")
