# scenario_calc.R — Equivalent of 2.1 (background) scenario.do
# Calculates the "typical" and "optimistic" scenario growth rates for the HCI gap.
# Returns scalars: hci_gap_5rate_50, hci_gap_5rate_75, hci_gap_5rate_50p, hci_gap_5rate_75p
# These are assigned into the parent environment.

# Parameters (same as Stata)
phi_sc            <- 0.08
gam_height_mid_sc <- 0.034
beta_height_asr   <- 19.2
beta_height_stu   <- 10.2
gam_asr_mid_sc    <- beta_height_asr * gam_height_mid_sc
gam_stu_mid_sc    <- beta_height_stu * gam_height_mid_sc
maxhlo            <- 625

tertiary_sc <- if (exists("tertiary_mode")) tertiary_mode else "No"

if (tertiary_sc == "Yes") {
  nys_max  <- 18
  nadys_max <- 18
  fname_sc <- "ter"
} else {
  nys_max  <- 14
  nadys_max <- 14
  fname_sc <- ""
}

# --- Tertiary education adjustment to EYS ---
hci_raw <- haven::read_dta(file.path(input, "hci_data_21Sept2018_FINAL.dta"))

if (tertiary_sc == "Yes") {
  bl_mf <- haven::read_dta(file.path(input, "BL2013_MF_v2.1.dta"))
  bl_ter <- bl_mf %>%
    filter(agefrom == 20, ageto == 24, year %in% c(2005, 2010)) %>%
    arrange(BLcode, year) %>%
    group_by(BLcode) %>%
    mutate(yr_sch_ter = ifelse(year == 2010 & lag(year) == 2005,
                                yr_sch_ter + (yr_sch_ter - lag(yr_sch_ter)),
                                yr_sch_ter)) %>%
    ungroup()

  # Stata saves BOTH year=2005 (original) and year=2015 (extrapolated) into tempfile bter,
  # then mmerge on (wbcode, year) matches both. So tertiary gets added at 2005, 2015, and 2017.
  bl_ter_2005 <- bl_ter %>% filter(year == 2005)  # original yr_sch_ter at 2005
  bl_ter_2015 <- bl_ter %>% filter(year == 2010) %>% mutate(year = 2015)
  bl_ter_2017 <- bl_ter_2015 %>% mutate(year = 2017)

  hci_raw <- hci_raw %>%
    left_join(bl_ter_2005 %>% select(WBcode, year, yr_sch_ter),
              by = c("wbcode" = "WBcode", "year")) %>%
    left_join(bl_ter_2015 %>% select(WBcode, year, yr_sch_ter),
              by = c("wbcode" = "WBcode", "year"), suffix = c("", "_15")) %>%
    left_join(bl_ter_2017 %>% select(WBcode, year, yr_sch_ter),
              by = c("wbcode" = "WBcode", "year"), suffix = c("", "_17")) %>%
    mutate(yr_sch_ter = coalesce(yr_sch_ter, yr_sch_ter_15, yr_sch_ter_17)) %>%
    select(-yr_sch_ter_15, -yr_sch_ter_17) %>%
    # Stata: `replace eyrs_mf = eyrs_mf + yr_sch_ter` is UNCONDITIONAL.
    # When yr_sch_ter is NA, this sets eyrs_mf to NA too. This is important:
    # it restricts the d10/levels calculations to only countries with BL tertiary data.
    mutate(eyrs_mf = eyrs_mf + yr_sch_ter,
           eyrs_mf = ifelse(!is.na(eyrs_mf) & eyrs_mf > 18, 18, eyrs_mf))
}

# --- Calculate 10-year growth rates ---
hci <- hci_raw %>%
  arrange(countrynumber, year)

# For each variable, calculate d10 = value - value 10 years prior
# Stata: tsset countrynumber year => annual data, L10 = 10 observations back
hci <- hci %>%
  group_by(countrynumber) %>%
  mutate(
    d10_eyrs_mf  = eyrs_mf  - lag(eyrs_mf,  n = 10),
    d10_nostu_mf = nostu_mf - lag(nostu_mf, n = 10),
    d10_asr_mf   = asr_mf   - lag(asr_mf,   n = 10)
  ) %>%
  ungroup()

# Median and p75 of 10-year growth rates at year 2015
growth_2015 <- hci %>% filter(year == 2015)
p50d_eyrs_mf  <- median(growth_2015$d10_eyrs_mf, na.rm = TRUE)
p75d_eyrs_mf  <- quantile(growth_2015$d10_eyrs_mf, 0.75, na.rm = TRUE, type = 2)
p50d_nostu_mf <- median(growth_2015$d10_nostu_mf, na.rm = TRUE)
p75d_nostu_mf <- quantile(growth_2015$d10_nostu_mf, 0.75, na.rm = TRUE, type = 2)
p50d_asr_mf   <- median(growth_2015$d10_asr_mf, na.rm = TRUE)
p75d_asr_mf   <- quantile(growth_2015$d10_asr_mf, 0.75, na.rm = TRUE, type = 2)

# HLO growth rates (from Aart Kraay, hardcoded in Stata)
p50d_test_mf <- 6
p75d_test_mf <- 19

# Median levels in 2017 (conditional on both eyrs and test being non-missing)
levels_2017 <- hci %>%
  filter(year == 2017, !is.na(eyrs_mf), !is.na(test_mf))
p50_eyrs_mf  <- median(levels_2017$eyrs_mf, na.rm = TRUE)
p50_test_mf  <- median(levels_2017$test_mf, na.rm = TRUE)
p50_nostu_mf <- median(levels_2017$nostu_mf, na.rm = TRUE)
p50_asr_mf   <- median(levels_2017$asr_mf, na.rm = TRUE)

# --- Calculate HCI for median country in 2015 ---
hci_2015 <- exp(phi_sc * (((p50_test_mf / maxhlo) * p50_eyrs_mf) - nadys_max) +
               0.5 * (gam_asr_mid_sc * (p50_asr_mf - 1) + gam_stu_mid_sc * (p50_nostu_mf - 1)))
hci_gap_2015 <- 1 - hci_2015

# --- Calculate HCI gap change under p50 and p75 scenarios ---
for (scen in c(50, 75)) {
  pd_test  <- get(paste0("p", scen, "d_test_mf"))
  pd_eyrs  <- get(paste0("p", scen, "d_eyrs_mf"))
  pd_nostu <- get(paste0("p", scen, "d_nostu_mf"))
  pd_asr   <- get(paste0("p", scen, "d_asr_mf"))

  hci_2025 <- exp(phi_sc * ((((p50_test_mf + pd_test) / maxhlo) * (p50_eyrs_mf + pd_eyrs)) - nadys_max) +
                 0.5 * (gam_asr_mid_sc * (p50_asr_mf + pd_asr - 1) + gam_stu_mid_sc * (p50_nostu_mf + pd_nostu - 1)))
  hci_gap_2025 <- 1 - hci_2025
  hci_gap_change <- (hci_gap_2015 - hci_gap_2025) / hci_gap_2015

  assign(paste0("hci_gap_change_", scen), hci_gap_change)
  assign(paste0("hci_2025_", scen), hci_2025)
}

# --- Calculate annual and 5-year gap closure rates ---
hci_gap_1rate_50 <- (1 - hci_gap_change_50)^(1/10) - 1
hci_gap_1rate_75 <- (1 - hci_gap_change_75)^(1/10) - 1

hci_gap_5rate_50 <- 1 - (1 + hci_gap_1rate_50)^5
hci_gap_5rate_75 <- 1 - (1 + hci_gap_1rate_75)^5

# Make annual rates positive (they represent gap closure, not growth)
hci_gap_1rate_50 <- hci_gap_1rate_50 * -1
hci_gap_1rate_75 <- hci_gap_1rate_75 * -1

# Percentage versions
hci_gap_5rate_50p <- hci_gap_5rate_50 * 100
hci_gap_5rate_75p <- hci_gap_5rate_75 * 100

cat(sprintf("Typical rate: %.4f per 5 years (%.1f%%)\n", hci_gap_5rate_50, hci_gap_5rate_50p))
cat(sprintf("Optimistic rate: %.4f per 5 years (%.1f%%)\n", hci_gap_5rate_75, hci_gap_5rate_75p))
