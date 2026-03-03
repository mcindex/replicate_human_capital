# 03_hc_worldprojections.R — Equivalent of (3) hc_worldprojections.do
# Produces Figures 2-7: world projections of HC, GDP, and poverty

endyear_proj <- 2050

tertiary_03 <- if (exists("tertiary_mode")) tertiary_mode else "No"
fname_03 <- ifelse(tertiary_03 == "Yes", "ter", "")

lrate50 <- round(hci_gap_5rate_50p, 0)
lrate75 <- round(hci_gap_5rate_75p, 0)

for (cat_name in c("world", "developing", "lowincome", "ssa")) {

  proj <- readRDS(file.path(output, paste0("hc_projections", fname_03, ".rds")))

  cat_label <- switch(cat_name,
    "world" = "World",
    "developing" = "Low and Lower-Middle Income Countries",
    "lowincome" = "Low Income Countries",
    "ssa" = "Sub-Saharan Africa"
  )

  if (cat_name == "developing") {
    proj <- proj %>% filter(!Incomegroup %in% c("High income", "Upper middle income"))
  } else if (cat_name == "lowincome") {
    proj <- proj %>% filter(Incomegroup == "Low income")
  } else if (cat_name == "ssa") {
    proj <- proj %>% filter(Region == "Sub-Saharan Africa")
  }

  proj <- proj %>% filter(year <= endyear_proj)

  # Calculate totals for each scenario
  for (sc in c("constant", "sc1", "sc2", "sc3")) {
    proj[[paste0("gdp_", sc)]]     <- proj[[paste0("gdppw_", sc)]] * proj$total_working
    proj[[paste0("poor_", sc)]]    <- proj[[paste0("pov_", sc)]] * proj$total_pop
    proj[[paste0("poor320_", sc)]] <- proj[[paste0("pov320_", sc)]] * proj$total_pop
    proj[[paste0("poor550_", sc)]] <- proj[[paste0("pov550_", sc)]] * proj$total_pop
    proj[[paste0("hc_", sc)]]      <- proj[[paste0("hcpw_", sc)]] * proj$total_working
    proj[[paste0("k_", sc)]]       <- proj[[paste0("kpw_", sc)]] * proj$total_working
  }

  # Collapse to year level
  agg_cols <- c(paste0("gdp_", c("constant","sc1","sc2","sc3")),
                paste0("poor_", c("constant","sc1","sc2","sc3")),
                paste0("poor320_", c("constant","sc1","sc2","sc3")),
                paste0("poor550_", c("constant","sc1","sc2","sc3")),
                paste0("hc_", c("constant","sc1","sc2","sc3")),
                paste0("k_", c("constant","sc1","sc2","sc3")),
                "total_working", "total_pop")

  agg <- proj %>%
    group_by(year) %>%
    summarize(across(all_of(agg_cols), ~sum(.x, na.rm = TRUE)), .groups = "drop")

  # Recalculate per-worker/per-capita
  for (sc in c("constant", "sc1", "sc2", "sc3")) {
    agg[[paste0("gdppw_", sc)]]   <- (agg[[paste0("gdp_", sc)]] / agg$total_working) / 1000
    agg[[paste0("gdppc_", sc)]]   <- (agg[[paste0("gdp_", sc)]] / agg$total_pop) / 1000
    agg[[paste0("gdppw_", sc, "_r")]] <- agg[[paste0("gdppw_", sc)]] / agg$gdppw_constant
    agg[[paste0("gdppc_", sc, "_r")]] <- agg[[paste0("gdppc_", sc)]] / agg$gdppc_constant
    agg[[paste0("hcpw_", sc)]]    <- agg[[paste0("hc_", sc)]] / agg$total_working
    agg[[paste0("kpw_", sc)]]     <- (agg[[paste0("k_", sc)]] / agg$total_working) / 1000
    agg[[paste0("pov_", sc)]]     <- agg[[paste0("poor_", sc)]] / agg$total_pop
    agg[[paste0("pov_", sc, "_r")]]   <- agg[[paste0("pov_", sc)]] / agg$pov_constant
    agg[[paste0("pov_", sc, "_p")]]   <- agg[[paste0("pov_", sc)]] - agg$pov_constant
    agg[[paste0("poor_", sc)]]    <- agg[[paste0("poor_", sc)]] / 1e6
    agg[[paste0("poor_", sc, "_d")]]  <- -1 * (agg[[paste0("poor_", sc)]] - agg$poor_constant)
    agg[[paste0("pov320_", sc)]]  <- agg[[paste0("poor320_", sc)]] / agg$total_pop
    agg[[paste0("pov320_", sc, "_r")]] <- agg[[paste0("pov320_", sc)]] / agg$pov320_constant
    agg[[paste0("pov320_", sc, "_p")]] <- agg[[paste0("pov320_", sc)]] - agg$pov320_constant
    agg[[paste0("poor320_", sc)]] <- agg[[paste0("poor320_", sc)]] / 1e6
    agg[[paste0("poor320_", sc, "_d")]] <- -1 * (agg[[paste0("poor320_", sc)]] - agg$poor320_constant)
    agg[[paste0("pov550_", sc)]]  <- agg[[paste0("poor550_", sc)]] / agg$total_pop
    agg[[paste0("pov550_", sc, "_r")]] <- agg[[paste0("pov550_", sc)]] / agg$pov550_constant
    agg[[paste0("pov550_", sc, "_p")]] <- agg[[paste0("pov550_", sc)]] - agg$pov550_constant
    agg[[paste0("poor550_", sc)]] <- agg[[paste0("poor550_", sc)]] / 1e6
    agg[[paste0("poor550_", sc, "_d")]] <- -1 * (agg[[paste0("poor550_", sc)]] - agg$poor550_constant)
  }

  # ===========================================================================
  # Graphs
  # ===========================================================================
  scenario_labels <- c(
    "Baseline",
    paste0("Closing ", lrate50, "% of gap per 5 years (typical)"),
    paste0("Closing ", lrate75, "% per 5 years (optimistic)"),
    "Gap closed immediately"
  )
  ltypes <- c("solid", "longdash", "dashed", "dotted")

  # Figure 2: HCPW
  df_hcpw <- agg %>%
    select(year, hcpw_constant, hcpw_sc1, hcpw_sc2, hcpw_sc3) %>%
    pivot_longer(-year, names_to = "scenario", values_to = "hcpw") %>%
    mutate(scenario = factor(scenario, levels = c("hcpw_constant", "hcpw_sc1", "hcpw_sc2", "hcpw_sc3"),
                             labels = scenario_labels))

  p <- ggplot(df_hcpw, aes(x = year, y = hcpw, linetype = scenario)) +
    geom_line(linewidth = 1) +
    scale_linetype_manual(values = ltypes) +
    labs(y = "Human capital per worker", x = "", linetype = NULL,
         title = cat_label) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")
  ggsave(file.path(graphs, paste0("hcpw_", cat_label, fname_03, "_R.png")),
         p, width = 10, height = 6, dpi = 200)

  # Figure 3: GDP relative to baseline
  df_gdp <- agg %>%
    select(year, gdppc_constant_r, gdppc_sc1_r, gdppc_sc2_r, gdppc_sc3_r) %>%
    pivot_longer(-year, names_to = "scenario", values_to = "gdppc_r") %>%
    mutate(scenario = factor(scenario, levels = c("gdppc_constant_r", "gdppc_sc1_r", "gdppc_sc2_r", "gdppc_sc3_r"),
                             labels = scenario_labels))

  p <- ggplot(df_gdp, aes(x = year, y = gdppc_r, linetype = scenario)) +
    geom_line(linewidth = 1) +
    scale_linetype_manual(values = ltypes) +
    labs(y = "GDP-per-capita relative to baseline scenario", x = "", linetype = NULL,
         title = cat_label) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")
  ggsave(file.path(graphs, paste0("relative_income_", cat_label, fname_03, "_R.png")),
         p, width = 10, height = 6, dpi = 200)

  # Figure 5: Poverty rates (3 lines × 4 scenarios)
  pov_data <- data.frame(year = agg$year)
  for (pline in c("pov", "pov320", "pov550")) {
    for (sc in c("constant", "sc1", "sc2", "sc3")) {
      col_name <- paste0(pline, "_", sc)
      pov_data[[col_name]] <- agg[[col_name]]
    }
  }
  pov_long <- pov_data %>%
    pivot_longer(-year, names_to = "series", values_to = "rate") %>%
    mutate(
      poverty_line = case_when(
        grepl("^pov_", series) & !grepl("pov320|pov550", series) ~ "$1.90",
        grepl("pov320", series) ~ "$3.20",
        grepl("pov550", series) ~ "$5.50"
      ),
      scenario = case_when(
        grepl("constant", series) ~ "Baseline",
        grepl("sc1", series) ~ paste0("Typical (", lrate50, "%)"),
        grepl("sc2", series) ~ paste0("Optimistic (", lrate75, "%)"),
        grepl("sc3", series) ~ "Immediate"
      )
    )

  p <- ggplot(pov_long, aes(x = year, y = rate, linetype = scenario, color = poverty_line)) +
    geom_line(linewidth = 0.8) +
    scale_color_manual(values = c("$1.90" = "black", "$3.20" = "gray40", "$5.50" = "gray70")) +
    scale_linetype_manual(values = setNames(
      c("solid", "longdash", "dashed", "dotted"),
      c("Baseline", paste0("Typical (", lrate50, "%)"),
        paste0("Optimistic (", lrate75, "%)"), "Immediate"))) +
    labs(y = "Poverty rate", x = "", color = "Poverty line", linetype = "Scenario",
         title = cat_label) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")
  ggsave(file.path(graphs, paste0("pov_", cat_label, fname_03, "_R.png")),
         p, width = 8, height = 10, dpi = 200)

  # Figure 7: People lifted out of poverty
  poor_data <- agg %>%
    select(year, ends_with("_d")) %>%
    select(year, poor_sc1_d, poor_sc2_d, poor_sc3_d,
           poor320_sc1_d, poor320_sc2_d, poor320_sc3_d,
           poor550_sc1_d, poor550_sc2_d, poor550_sc3_d)
  poor_long <- poor_data %>%
    pivot_longer(-year, names_to = "series", values_to = "millions") %>%
    mutate(
      poverty_line = case_when(
        grepl("^poor_", series) ~ "$1.90",
        grepl("poor320", series) ~ "$3.20",
        grepl("poor550", series) ~ "$5.50"
      ),
      scenario = case_when(
        grepl("sc1", series) ~ paste0("Typical (", lrate50, "%)"),
        grepl("sc2", series) ~ paste0("Optimistic (", lrate75, "%)"),
        grepl("sc3", series) ~ "Immediate"
      )
    )

  for (pline in c("$1.90", "$3.20", "$5.50")) {
    pdata <- poor_long %>% filter(poverty_line == pline)
    assign(paste0("p_", gsub("[\\$.]", "", pline)),
           ggplot(pdata, aes(x = year, y = millions, linetype = scenario)) +
             geom_line(linewidth = 1) +
             scale_linetype_manual(values = setNames(
               c("longdash", "dashed", "dotted"),
               c(paste0("Typical (", lrate50, "%)"),
                 paste0("Optimistic (", lrate75, "%)"), "Immediate"))) +
             labs(y = "Millions", subtitle = paste(pline, "a day"), linetype = NULL) +
             theme_minimal()
    )
  }

  # Combined panel
  if (!"patchwork" %in% installed.packages()[,"Package"]) {
    install.packages("patchwork", repos = "https://cloud.r-project.org")
  }
  library(patchwork)
  p_combined <- p_190 / p_320 / p_550 + plot_layout(guides = "collect") &
    theme(legend.position = "bottom")
  ggsave(file.path(graphs, paste0("poor_", cat_label, fname_03, "_R.png")),
         p_combined, width = 8, height = 12, dpi = 200)
}

# ===========================================================================
# Figure 4: Relative income gains by starting GDP
# ===========================================================================
proj_full <- readRDS(file.path(output, paste0("hc_projections", fname_03, ".rds")))
proj_full <- proj_full %>% filter(year <= endyear_proj)

ey_idx <- 1 + (endyear_proj - 2015) / 5  # row index within country

country_gains <- proj_full %>%
  group_by(wbcode) %>%
  summarize(
    starting_gdp = first(gdppc_constant),
    starting_pov = first(pov_constant),
    ending_gdp_ratio_sc1 = nth(gdppc_sc1_r, ey_idx),
    ending_gdp_ratio_sc2 = nth(gdppc_sc2_r, ey_idx),
    ending_gdp_ratio_sc3 = nth(gdppc_sc3_r, ey_idx),
    wbcountryname = first(wbcountryname),
    .groups = "drop"
  )

gains_long <- country_gains %>%
  pivot_longer(cols = starts_with("ending_gdp_ratio"),
               names_to = "scenario", values_to = "ratio") %>%
  mutate(scenario = case_when(
    scenario == "ending_gdp_ratio_sc1" ~ paste0("Typical (", lrate50, "%)"),
    scenario == "ending_gdp_ratio_sc2" ~ paste0("Optimistic (", lrate75, "%)"),
    scenario == "ending_gdp_ratio_sc3" ~ "Immediate"
  ))

p <- ggplot(gains_long, aes(x = starting_gdp, y = ratio, shape = scenario)) +
  geom_point(alpha = 0.6) +
  scale_x_log10(labels = scales::comma) +
  scale_shape_manual(values = c(16, 17, 4)) +
  labs(y = "GDPPC in 2050 relative to baseline scenario",
       x = "GDP-per-capita in 2015 (Log scale)", shape = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(file.path(graphs, paste0("income_gains", fname_03, "_R.png")),
       p, width = 10, height = 6, dpi = 200)

# ===========================================================================
# Figure 6: Poverty changes by country (dot chart)
# ===========================================================================
pov_gains <- proj_full %>%
  group_by(wbcode) %>%
  summarize(
    starting_pov = first(pov_constant),
    ending_pov_constant = nth(pov_constant, ey_idx),
    ending_pov_sc1 = nth(pov_sc1, ey_idx),
    ending_pov_sc2 = nth(pov_sc2, ey_idx),
    ending_pov_sc3 = nth(pov_sc3, ey_idx),
    wbcountryname = first(wbcountryname),
    .groups = "drop"
  ) %>%
  filter(starting_pov > 0.10, !is.na(starting_pov))

pov_gains_long <- pov_gains %>%
  pivot_longer(cols = c(ending_pov_constant, ending_pov_sc1, ending_pov_sc2, ending_pov_sc3, starting_pov),
               names_to = "series", values_to = "rate") %>%
  mutate(series = factor(series,
    levels = c("starting_pov", "ending_pov_constant", "ending_pov_sc1", "ending_pov_sc2", "ending_pov_sc3"),
    labels = c("2015", "2050 baseline", "2050 typical", "2050 optimistic", "2050 immediate")))

pov_gains_long$wbcountryname <- factor(pov_gains_long$wbcountryname,
  levels = pov_gains %>% arrange(desc(starting_pov)) %>% pull(wbcountryname))

p <- ggplot(pov_gains_long, aes(x = rate, y = wbcountryname, shape = series)) +
  geom_point(size = 2) +
  scale_shape_manual(values = c(15, 3, 16, 17, 4)) +
  labs(x = "Poverty rate", y = "", shape = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom", legend.direction = "vertical",
        axis.text.y = element_text(size = 6))
ggsave(file.path(graphs, paste0("pov_gains", fname_03, "_R.png")),
       p, width = 6, height = 12, dpi = 200)

cat("  03_hc_worldprojections.R complete.\n")
