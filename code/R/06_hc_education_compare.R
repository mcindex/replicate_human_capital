# 06_hc_education_compare.R — Equivalent of (6) hc_education_compare.do
# Compares primary-secondary model to primary-tertiary model (Appendix figures)

endyear_comp <- 2050

# Need both sets of scenario scalars (sec and ter)
# At this point in master.R: hci_gap_5rate_50/75 = sec values,
# hci_gap_5rate_50ter/75ter = ter values (saved earlier)

lrate50    <- round(hci_gap_5rate_50p, 0)
lrate75    <- round(hci_gap_5rate_75p, 0)
lrate50ter <- round(hci_gap_5rate_50pter, 0)
lrate75ter <- round(hci_gap_5rate_75pter, 0)

for (cat_name in c("world", "developing", "lowincome", "ssa")) {

  cat_label <- switch(cat_name,
    "world" = "World",
    "developing" = "Low and Lower-Middle Income Countries",
    "lowincome" = "Low Income Countries",
    "ssa" = "Sub-Saharan Africa"
  )

  # Process both sec and ter
  combined_list <- list()
  for (e in c("sec", "ter")) {
    fn <- ifelse(e == "sec", "", "ter")
    proj <- readRDS(file.path(output, paste0("hc_projections", fn, ".rds")))

    if (cat_name == "developing") {
      proj <- proj %>% filter(!Incomegroup %in% c("High income", "Upper middle income"))
    } else if (cat_name == "lowincome") {
      proj <- proj %>% filter(Incomegroup == "Low income")
    } else if (cat_name == "ssa") {
      proj <- proj %>% filter(Region == "Sub-Saharan Africa")
    }

    proj <- proj %>% filter(year <= endyear_comp)

    for (sc in c("constant", "sc1", "sc2", "sc3")) {
      proj[[paste0("gdp_", sc)]]     <- proj[[paste0("gdppw_", sc)]] * proj$total_working
      proj[[paste0("poor_", sc)]]    <- proj[[paste0("pov_", sc)]] * proj$total_pop
      proj[[paste0("hc_", sc)]]      <- proj[[paste0("hcpw_", sc)]] * proj$total_working
      proj[[paste0("k_", sc)]]       <- proj[[paste0("kpw_", sc)]] * proj$total_working
    }

    agg_cols <- c(paste0("gdp_", c("constant","sc1","sc2","sc3")),
                  paste0("poor_", c("constant","sc1","sc2","sc3")),
                  paste0("hc_", c("constant","sc1","sc2","sc3")),
                  paste0("k_", c("constant","sc1","sc2","sc3")),
                  "total_working", "total_pop")

    agg <- proj %>%
      group_by(year) %>%
      summarize(across(all_of(agg_cols), ~sum(.x, na.rm = TRUE)), .groups = "drop")

    for (sc in c("constant", "sc1", "sc2")) {
      agg[[paste0("hcpw_", sc)]] <- agg[[paste0("hc_", sc)]] / agg$total_working
      agg[[paste0("gdppc_", sc, "_r")]] <- (agg[[paste0("gdp_", sc)]] / agg$total_pop) /
                                            (agg$gdp_constant / agg$total_pop)
      agg[[paste0("pov_", sc)]] <- agg[[paste0("poor_", sc)]] / agg$total_pop
    }

    suffix <- ifelse(e == "ter", "ter", "")
    result <- agg %>% select(year, starts_with("hcpw_"), starts_with("gdppc_"), starts_with("pov_"))

    if (e == "ter") {
      names(result)[-1] <- paste0(names(result)[-1], "ter")
    }

    combined_list[[e]] <- result
  }

  combined <- inner_join(combined_list[["sec"]], combined_list[["ter"]], by = "year")

  # Figure A.1: HCPW comparison
  hcpw_df <- combined %>%
    select(year, hcpw_constant, hcpw_sc1, hcpw_sc2,
           hcpw_constantter, hcpw_sc1ter, hcpw_sc2ter) %>%
    pivot_longer(-year, names_to = "series", values_to = "hcpw") %>%
    mutate(
      model = ifelse(grepl("ter$", series), "Primary-Tertiary", "Primary-Secondary"),
      scenario = case_when(
        grepl("constant", series) ~ "Baseline",
        grepl("sc1", series) ~ "Typical",
        grepl("sc2", series) ~ "Optimistic"
      )
    )

  p <- ggplot(hcpw_df, aes(x = year, y = hcpw, linetype = scenario, color = model)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c("Primary-Secondary" = "black", "Primary-Tertiary" = "gray50")) +
    scale_linetype_manual(values = c("Baseline" = "solid", "Typical" = "longdash", "Optimistic" = "dotted")) +
    labs(y = "Human capital per worker", x = "", color = NULL, linetype = NULL,
         title = cat_label) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")
  ggsave(file.path(graphs, paste0("hcpw_", cat_label, "_secter_R.png")),
         p, width = 10, height = 6, dpi = 200)

  # Figure A.2: GDP relative to baseline
  gdp_df <- combined %>%
    select(year, gdppc_constant_r, gdppc_sc1_r, gdppc_sc2_r,
           gdppc_constant_rter, gdppc_sc1_rter, gdppc_sc2_rter) %>%
    pivot_longer(-year, names_to = "series", values_to = "ratio") %>%
    mutate(
      model = ifelse(grepl("ter$", series), "Primary-Tertiary", "Primary-Secondary"),
      scenario = case_when(
        grepl("constant", series) ~ "Baseline",
        grepl("sc1", series) ~ "Typical",
        grepl("sc2", series) ~ "Optimistic"
      )
    )

  p <- ggplot(gdp_df, aes(x = year, y = ratio, linetype = scenario, color = model)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c("Primary-Secondary" = "black", "Primary-Tertiary" = "gray50")) +
    scale_linetype_manual(values = c("Baseline" = "solid", "Typical" = "longdash", "Optimistic" = "dotted")) +
    labs(y = "GDP-per-capita relative to baseline", x = "", color = NULL, linetype = NULL,
         title = cat_label) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")
  ggsave(file.path(graphs, paste0("relative_income_", cat_label, "_secter_R.png")),
         p, width = 10, height = 6, dpi = 200)

  # Figure A.3: Poverty comparison
  pov_df <- combined %>%
    select(year, pov_constant, pov_sc1, pov_sc2,
           pov_constantter, pov_sc1ter, pov_sc2ter) %>%
    pivot_longer(-year, names_to = "series", values_to = "rate") %>%
    mutate(
      model = ifelse(grepl("ter$", series), "Primary-Tertiary", "Primary-Secondary"),
      scenario = case_when(
        grepl("constant", series) ~ "Baseline",
        grepl("sc1", series) ~ "Typical",
        grepl("sc2", series) ~ "Optimistic"
      )
    )

  p <- ggplot(pov_df, aes(x = year, y = rate, linetype = scenario, color = model)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = c("Primary-Secondary" = "black", "Primary-Tertiary" = "gray50")) +
    scale_linetype_manual(values = c("Baseline" = "solid", "Typical" = "longdash", "Optimistic" = "dotted")) +
    labs(y = "Poverty rate", x = "", color = NULL, linetype = NULL,
         title = cat_label) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")
  ggsave(file.path(graphs, paste0("pov_", cat_label, "_secter_R.png")),
         p, width = 8, height = 10, dpi = 200)
}

cat("  06_hc_education_compare.R complete.\n")
