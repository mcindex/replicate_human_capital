# 07_fertility_table3.R — Equivalent of (7) fertility_table3.do
# Replicates Table 3: Effect of HC on GDP through fertility channel
#
# Hybrid aggregate-then-transform approach:
# - HC/fertility: weighted by working-age population
# - GDP: weighted by total population

# Parameters from Section 6.1
elast_fs    <- -0.11    # d ln(f) / d s — Osili and Long (2008)
elast_hs    <- 0.08     # d ln(h) / d s — Mincerian return
elast_fh    <- elast_fs / elast_hs  # = -1.375
ashraf_inc  <- 11.9     # % income increase (Ashraf et al. 2013)
ashraf_tfr  <- 17.4     # % TFR reduction  (Ashraf et al. 2013)
ashraf_ratio <- ashraf_inc / ashraf_tfr

cat(sprintf("  Elasticity of fertility w.r.t. human capital: %.3f\n", elast_fh))
cat(sprintf("  Ashraf et al. ratio (income/TFR): %.4f\n", ashraf_ratio))

# Load projection data
proj <- readRDS(file.path(output, "hc_projections.rds"))

# Keep year 2050 only
proj2050 <- proj %>%
  filter(year == 2050) %>%
  select(wbcode, wbcountryname, Incomegroup, hcpw_constant, hcpw_sc1, hcpw_sc2,
         gdppc_constant, gdppc_sc1, gdppc_sc2, working_pop_both, total_pop)

# Drop high-income countries
proj2050 <- proj2050 %>%
  filter(!Incomegroup %in% c("High income", "", NA))

cat("  Countries by income group:\n")
print(table(proj2050$Incomegroup))

# ====================================================================
# PART A: HC and Fertility columns
# Aggregate-then-transform, weighted by working-age population
# ====================================================================
hc_fert <- proj2050 %>%
  group_by(Incomegroup) %>%
  summarize(
    hcpw_constant = weighted.mean(hcpw_constant, working_pop_both, na.rm = TRUE),
    hcpw_sc1      = weighted.mean(hcpw_sc1, working_pop_both, na.rm = TRUE),
    hcpw_sc2      = weighted.mean(hcpw_sc2, working_pop_both, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    hc_increase_typ = (hcpw_sc1 - hcpw_constant) / hcpw_constant,
    hc_increase_opt = (hcpw_sc2 - hcpw_constant) / hcpw_constant,
    fert_change_typ = (1 + hc_increase_typ)^elast_fh - 1,
    fert_change_opt = (1 + hc_increase_opt)^elast_fh - 1,
    gdppc_fert_typ  = fert_change_typ * ashraf_ratio,
    gdppc_fert_opt  = fert_change_opt * ashraf_ratio
  ) %>%
  mutate(across(c(hc_increase_typ:gdppc_fert_opt), ~ round(.x * 100, 1))) %>%
  select(Incomegroup, hc_increase_typ, hc_increase_opt,
         fert_change_typ, fert_change_opt, gdppc_fert_typ, gdppc_fert_opt)

# ====================================================================
# PART B: GDP per capita columns (partial equilibrium)
# Aggregate-then-transform, weighted by total population
# ====================================================================
gdp_pe <- proj2050 %>%
  group_by(Incomegroup) %>%
  summarize(
    gdppc_constant = weighted.mean(gdppc_constant, total_pop, na.rm = TRUE),
    gdppc_sc1      = weighted.mean(gdppc_sc1, total_pop, na.rm = TRUE),
    gdppc_sc2      = weighted.mean(gdppc_sc2, total_pop, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    gdppc_increase_typ = (gdppc_sc1 - gdppc_constant) / gdppc_constant,
    gdppc_increase_opt = (gdppc_sc2 - gdppc_constant) / gdppc_constant
  ) %>%
  mutate(across(c(gdppc_increase_typ, gdppc_increase_opt), ~ round(.x * 100, 1))) %>%
  select(Incomegroup, gdppc_increase_typ, gdppc_increase_opt)

# ====================================================================
# Merge the two parts
# ====================================================================
table3 <- inner_join(hc_fert, gdp_pe, by = "Incomegroup")

# Display
cat("\n============================================================\n")
cat("  TABLE 3 REPLICATION\n")
cat("  HC/Fert: aggregate-then-transform, working_pop weight\n")
cat("  GDP:     aggregate-then-transform, total_pop weight\n")
cat("============================================================\n")
print(as.data.frame(table3))

cat("\nPaper values for comparison:\n")
cat("Low income:    HC 17.7/40.9  Fert -20.1/-37.7  GDP_PE 14.3/33.0  GDP_GE -13.8/-25.8\n")
cat("Lower-middle:  HC 11.2/26.0  Fert -13.6/-27.3  GDP_PE  8.9/20.6  GDP_GE  -9.3/-18.7\n")
cat("Upper-middle:  HC  6.4/15.0  Fert  -8.2/-17.5  GDP_PE  5.0/11.6  GDP_GE  -5.6/-12.0\n")

saveRDS(table3, file.path(output, "table3_results_R.rds"))

cat("  07_fertility_table3.R complete.\n")
