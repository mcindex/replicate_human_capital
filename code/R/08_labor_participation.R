# 08_labor_participation.R — Equivalent of labor_participation.do
# ILO labor force participation data, kernel regression, Figures 10-11

# Load projection data (for GDP per capita)
proj <- readRDS(file.path(output, "hc_projections.rds"))

proj_2015 <- proj %>% filter(year == 2015)
proj_2050 <- proj %>% filter(year == 2050) %>%
  mutate(id = row_number()) %>%
  arrange(wbcode)

# Log GDP per capita
proj_2050$lngdppc_constant <- log(proj_2050$gdppc_constant)
proj_2050$lngdppc_sc1      <- log(proj_2050$gdppc_sc1)
proj_2050$lngdppc_sc2      <- log(proj_2050$gdppc_sc2)
proj_2050$lngdppc_sc3      <- log(proj_2050$gdppc_sc3)

# =========================================================================
# Load ILO labor force participation data
# =========================================================================
cat("  Reading ILO data...\n")
ilo <- haven::read_dta(file.path(input, "data-2019-12-06.dta"))

# Keep age bands 15-64 (5-year) and male only
bands <- c("15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60-64")
band_starts <- seq(15, 60, by = 5)

ilo_filtered <- ilo %>%
  mutate(band = NA_character_)

for (i in seq_along(bands)) {
  ilo_filtered$band[ilo_filtered$classif1_label == paste0("Age (5-year bands): ", bands[i])] <- as.character(band_starts[i])
}

ilo_filtered <- ilo_filtered %>%
  filter(!is.na(band), sex_label == "Sex: Male") %>%
  mutate(iso = substr(source_label, 1, 3)) %>%
  select(iso, band, obs_value) %>%
  rename(lfp = obs_value) %>%
  pivot_wider(names_from = band, values_from = lfp, names_prefix = "lfp_")

ilo_filtered$year <- 2015L

# Merge with GDP per capita
ilo_merged <- ilo_filtered %>%
  inner_join(proj_2015 %>% select(wbcode, gdppc_constant) %>%
               rename(gdppc_baseline = gdppc_constant),
             by = c("iso" = "wbcode"))

ilo_merged$lngdppc_baseline <- log(ilo_merged$gdppc_baseline)

# =========================================================================
# Kernel regression for each age band
# =========================================================================
cat("  Running kernel regressions...\n")

ilo_merged <- ilo_merged %>% arrange(lngdppc_baseline)

# We use loess as R equivalent of npregress kernel
predicted_list <- list()

for (b in band_starts) {
  col <- paste0("lfp_", b)
  if (!col %in% names(ilo_merged)) next

  df_fit <- ilo_merged %>% filter(!is.na(.data[[col]]), !is.na(lngdppc_baseline))
  if (nrow(df_fit) < 10) next

  fit <- loess(as.formula(paste(col, "~ lngdppc_baseline")), data = df_fit, span = 0.75)
  df_fit[[paste0("plfp_", b)]] <- predict(fit, df_fit)

  predicted_list[[as.character(b)]] <- df_fit %>%
    select(iso, lngdppc_baseline, all_of(paste0("plfp_", b)))
}

# Combine predictions
pred_all <- ilo_merged %>% select(iso, lngdppc_baseline)
for (b in band_starts) {
  pcol <- paste0("plfp_", b)
  if (as.character(b) %in% names(predicted_list)) {
    pred_all <- pred_all %>%
      left_join(predicted_list[[as.character(b)]] %>% select(iso, all_of(pcol)),
                by = "iso")
  }
}

# =========================================================================
# Figure 10: LFP kernel regressions by age band
# =========================================================================
pred_long <- pred_all %>%
  select(iso, lngdppc_baseline, starts_with("plfp_")) %>%
  pivot_longer(cols = starts_with("plfp_"), names_to = "age_band", values_to = "lfp") %>%
  mutate(age_band = gsub("plfp_", "", age_band),
         age_label = paste0(age_band, "-", as.integer(age_band) + 4)) %>%
  filter(!is.na(lfp))

# Get text position for labels (rightmost point)
text_pos <- pred_long %>%
  group_by(age_label) %>%
  filter(lngdppc_baseline == max(lngdppc_baseline)) %>%
  slice(1) %>%
  ungroup()

p_lfp <- ggplot(pred_long, aes(x = lngdppc_baseline, y = lfp, color = age_label)) +
  geom_line(linewidth = 0.8) +
  geom_text(data = text_pos, aes(label = age_label), hjust = -0.1, size = 2.5) +
  scale_x_continuous(breaks = c(log(1000), log(10000), log(100000)),
                     labels = c("1,000", "10,000", "100,000")) +
  labs(y = "Labor force participation (percent)",
       x = "Log(GDP per capita) (2015)") +
  theme_minimal() +
  theme(legend.position = "none")
ggsave(file.path(graphs, "lfp_R.png"), p_lfp, width = 10, height = 6, dpi = 200)

# =========================================================================
# Figure 11: LF-adjusted HC ratio
# =========================================================================
cat("  Computing LF-adjusted HC ratios...\n")

# For each country in projection data at 2050, predict LFP at projected GDP levels
# using the kernel regressions fitted above

# We need to predict LFP at different GDP levels for each scenario
predict_lfp_at_gdp <- function(lngdp_val, age_b, fit_data) {
  col <- paste0("lfp_", age_b)
  df <- fit_data %>% filter(!is.na(.data[[col]]), !is.na(lngdppc_baseline))
  if (nrow(df) < 10) return(NA_real_)
  fit <- loess(as.formula(paste(col, "~ lngdppc_baseline")), data = df, span = 0.75)
  pred <- predict(fit, newdata = data.frame(lngdppc_baseline = lngdp_val))
  pred <- pmax(0, pmin(100, pred)) / 100  # Convert to fraction, bound 0-1
  return(pred)
}

# Load HCPW projections at age-bin level
hcpw_proj <- readRDS(file.path(output, "hcpw_projections.rds"))
hcpw_2050 <- hcpw_proj %>%
  filter(year == 2050) %>%
  select(wbcode, age_bin, a_hc_constant, a_hc_sc1, a_hc_sc2, a_hc_sc3)

# For each country and age bin, predict LFP under each scenario
countries_2050 <- proj_2050 %>% select(wbcode, lngdppc_constant, lngdppc_sc1)

# Map age_bin (20-60) to LFP bands (20-60)
lfp_ratios <- hcpw_2050 %>%
  left_join(countries_2050, by = "wbcode")

for (sc in c("constant", "sc1", "sc2", "sc3")) {
  lngdp_col <- paste0("lngdppc_", ifelse(sc == "constant", "constant", sc))
  if (!lngdp_col %in% names(lfp_ratios)) {
    # sc2, sc3 columns
    lfp_ratios[[lngdp_col]] <- log(proj_2050[[paste0("gdppc_", sc)]])[match(lfp_ratios$wbcode, proj_2050$wbcode)]
  }
}

# Predict LFP for each country-agebin-scenario combination
for (sc in c("constant", "sc1")) {
  lngdp_col <- paste0("lngdppc_", sc)
  adj_col <- paste0("a_hc_", sc, "_adjust")
  lfp_ratios[[adj_col]] <- NA_real_

  for (i in 1:nrow(lfp_ratios)) {
    ab <- lfp_ratios$age_bin[i]
    if (ab < 20 || ab > 60) next
    lngdp <- lfp_ratios[[lngdp_col]][i]
    if (is.na(lngdp)) next
    lfp_pred <- predict_lfp_at_gdp(lngdp, ab, ilo_merged)
    if (is.na(lfp_pred)) lfp_pred <- 1  # Default to 1 if prediction fails
    lfp_ratios[[adj_col]][i] <- lfp_ratios[[paste0("a_hc_constant")]][i] * lfp_pred
  }
}

# Collapse to country level
lfp_country <- lfp_ratios %>%
  group_by(wbcode) %>%
  summarize(
    a_hc_constant_adjust = sum(a_hc_constant_adjust, na.rm = TRUE),
    a_hc_sc1_adjust = sum(a_hc_sc1_adjust, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(ratio_sc1 = a_hc_sc1_adjust / a_hc_constant_adjust) %>%
  left_join(countries_2050 %>% select(wbcode, lngdppc_constant), by = "wbcode")

p_lfp2 <- ggplot(lfp_country %>% filter(!is.na(ratio_sc1)),
                  aes(x = lngdppc_constant, y = ratio_sc1)) +
  geom_text(aes(label = wbcode), size = 2.5, alpha = 0.8) +
  scale_x_continuous(breaks = c(log(1000), log(10000), log(100000)),
                     labels = c("1,000", "10,000", "100,000")) +
  labs(y = "Ratio of LF-adjusted human capital (typical over baseline)",
       x = "GDP per capita in 2015") +
  theme_minimal()
ggsave(file.path(graphs, "lfp_2_R.png"), p_lfp2, width = 10, height = 6, dpi = 200)

cat("  08_labor_participation.R complete.\n")
