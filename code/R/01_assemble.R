# 01_assemble.R — Equivalent of (1) assemble.do + 1.1 background
# Assembles all input data into a master dataset for the HC simulation.

source(file.path(codedir, "country_names.R"))

# Parameters
phi        <- 0.08
gam_height_mid  <- 0.034
beta_height_asr <- 19.2
beta_height_stu <- 10.2
gam_asr_mid     <- beta_height_asr * gam_height_mid
gam_stu_mid     <- beta_height_stu * gam_height_mid

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

include_ihme <- TRUE

# =========================================================================
# Step 1: Population estimates from WPP 2017
# =========================================================================
cat("  Step 1: Reading WPP population data...\n")

read_wpp <- function(gender_label, file_suffix) {
  filepath <- file.path(input, paste0("WPP2017_POP_F07_", file_suffix,
                                       "_POPULATION_BY_AGE_", gender_label, ".xlsx"))
  df <- readxl::read_excel(filepath, sheet = "MEDIUM VARIANT", range = "C17:AA4355",
                           col_names = TRUE)

  # Columns: Region, Notes, Country code, Reference date, then age bins (0-4, 5-9, ..., 100+)
  cnames <- names(df)
  # Age columns start at position 5 (after 4 metadata cols)
  age_cols <- cnames[5:length(cnames)]
  age_bins <- seq(0, (length(age_cols) - 1) * 5, by = 5)
  new_names <- paste0("pop_", gender_label, age_bins)
  names(df)[5:length(cnames)] <- new_names

  # Filter out regions (Countrycode >= 900) and rename
  df <- df %>%
    filter(`Country code` < 900) %>%
    rename(Region = `Region, subregion, country or area *`,
           Countrycode = `Country code`,
           year = `Reference date (as of 1 July)`) %>%
    select(Region, Countrycode, year, all_of(new_names))

  df
}

pop_male   <- read_wpp("MALE", "2")
pop_female <- read_wpp("FEMALE", "3")

# Merge male and female
pop <- inner_join(pop_male, pop_female, by = c("Countrycode", "year", "Region"))
stopifnot(nrow(pop) == nrow(pop_male))

# Calculate BOTH and convert from thousands to full values
age_bins_vec <- seq(0, 100, by = 5)
for (ab in age_bins_vec) {
  pop[[paste0("pop_BOTH", ab)]] <- (pop[[paste0("pop_MALE", ab)]] + pop[[paste0("pop_FEMALE", ab)]]) * 1000
  pop[[paste0("pop_MALE", ab)]]   <- pop[[paste0("pop_MALE", ab)]] * 1000
  pop[[paste0("pop_FEMALE", ab)]] <- pop[[paste0("pop_FEMALE", ab)]] * 1000
}

# Clean country names and map to ISO3C
pop$Region <- clean_wpp_names(pop$Region)
pop <- pop %>% filter(Region != "Channel Islands")
pop$iso3c <- map_to_iso3c(pop$Region)
pop$iso3c[pop$Region == "Curacao"] <- "CUW"
stopifnot(all(!is.na(pop$iso3c)))
pop <- pop %>% select(-Region, -Countrycode)

# Reshape to long
pop_long <- pop %>%
  pivot_longer(
    cols = starts_with("pop_"),
    names_to = c("gender", "age_bin"),
    names_pattern = "pop_(MALE|FEMALE|BOTH)(\\d+)",
    values_to = "pop"
  ) %>%
  mutate(age_bin = as.integer(age_bin)) %>%
  pivot_wider(names_from = gender, values_from = pop,
              names_prefix = "pop_")

# Save population bins
saveRDS(pop_long, file.path(output, "population_bins.rds"))

# Save total population and dependency ratios
total_pop <- pop_long %>%
  group_by(iso3c, year) %>%
  summarize(
    total_pop = sum(pop_BOTH),
    total_working = sum(pop_BOTH[age_bin >= 20 & age_bin <= 60]),
    .groups = "drop"
  )
saveRDS(total_pop, file.path(output, "total_population.rds"))

# Keep only 2015
pop_2015 <- pop_long %>% filter(year == 2015)
saveRDS(pop_2015, file.path(output, "population_bins_2015.rds"))

# =========================================================================
# Step 2: Quality adjusted years of schooling (HLO data)
# =========================================================================
cat("  Step 2: Reading HLO quality data...\n")
hlo <- haven::read_dta(file.path(input, "hlo_data_21Sept2018.dta"))

quality <- hlo %>%
  mutate(
    test_mf = hlo_mf_fill,
    test_f  = hlo_f_fill,
    test_m  = hlo_m_fill,
    test_max = 625,
    qual_mf = test_mf / test_max,
    qual_f  = test_f / test_max,
    qual_m  = test_m / test_max
  ) %>%
  filter(!is.na(qual_mf), year <= 2015, !is.na(year)) %>%
  arrange(wbcode, year) %>%
  group_by(wbcode) %>%
  slice_tail(n = 1) %>%
  ungroup() %>%
  mutate(
    qual_f = ifelse(is.na(qual_f), qual_mf, qual_f),
    qual_m = ifelse(is.na(qual_m), qual_mf, qual_m)
  ) %>%
  rename(qual_BOTH = qual_mf, qual_MALE = qual_m, qual_FEMALE = qual_f) %>%
  select(year, wbcode, qual_BOTH, qual_MALE, qual_FEMALE)

saveRDS(quality, file.path(output, "quality_2015.rds"))

# =========================================================================
# Step 3: Barro-Lee schooling data + IHME conversion
# =========================================================================
cat("  Step 3: Reading Barro-Lee and IHME education data...\n")

# Read Barro-Lee for each gender
read_bl <- function(gender_suffix) {
  df <- haven::read_dta(file.path(input, paste0("BL2013_", gender_suffix, "_v2.1.dta")))
  if (tertiary == "No") {
    df$ys <- df$yr_sch_pri + df$yr_sch_sec
  } else {
    df$ys <- df$yr_sch_pri + df$yr_sch_sec + df$yr_sch_ter
  }
  df <- df %>%
    filter(ageto != 999, year == 2010) %>%
    arrange(WBcode, agefrom) %>%
    group_by(WBcode) %>%
    mutate(ys = ifelse(agefrom == 15, lead(ys), ys)) %>%  # Assumption 3
    ungroup() %>%
    select(WBcode, year, agefrom, ys)
  names(df)[names(df) == "ys"] <- paste0("ys_", gender_suffix)
  df
}

bl_MF <- read_bl("MF")
bl_M  <- read_bl("M")
bl_F  <- read_bl("F")

# Merge all three
schooling <- bl_MF %>%
  left_join(bl_M, by = c("WBcode", "year", "agefrom")) %>%
  left_join(bl_F, by = c("WBcode", "year", "agefrom"))

# Age cohorts by 5 years
schooling <- schooling %>%
  mutate(age_bin = agefrom + 5, year = year + 5) %>%
  filter(age_bin >= 20) %>%
  rename(ys_BOTH = ys_MF, ys_MALE = ys_M, ys_FEMALE = ys_F) %>%
  select(WBcode, year, age_bin, ys_BOTH, ys_MALE, ys_FEMALE)

# Cap years of schooling
for (g in c("BOTH", "MALE", "FEMALE")) {
  schooling[[paste0("ys_", g)]] <- pmin(ys_max, schooling[[paste0("ys_", g)]])
}

saveRDS(schooling, file.path(output, paste0("schooling_2015", fname, ".rds")))

# --- IHME data ---
ihme <- read.csv(file.path(input, "IHME_GBD_2016_COVARIATES_1980_2016_EDUCATION_YRS_PC_Y2017M09D05.csv"),
                 stringsAsFactors = FALSE)

ihme <- ihme %>%
  filter(age_group_id >= 8, age_group_id <= 17, year_id == 2010) %>%
  mutate(
    sex_label = ifelse(sex_label == "Males", "MALE", ifelse(sex_label == "Females", "FEMALE", sex_label)),
    age_bin = as.integer(sub(" .*", "", age_group_name))
  ) %>%
  filter(location_id != 4657) %>%  # Drop duplicate Mexico
  filter(!location_id %in% c(433, 4940)) %>%  # Drop sub-national entries (Northern Ireland, Sweden excl Stockholm) to match Stata's kountry behavior
  select(val, location_id, location_name, year_id, age_bin, sex_label) %>%
  rename(ys = val) %>%
  # Handle any remaining duplicates by taking the mean
  group_by(location_id, location_name, year_id, age_bin, sex_label) %>%
  summarize(ys = mean(ys, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = sex_label, values_from = ys, names_prefix = "ys_")

# Map country names to ISO3C
ihme$iso3c <- map_to_iso3c(ihme$location_name)
ihme <- ihme %>% filter(!is.na(iso3c))

# Merge population data for weighted average
ihme <- ihme %>%
  mutate(year = 2015L) %>%
  inner_join(pop_2015 %>% select(iso3c, year, age_bin, pop_MALE, pop_FEMALE, pop_BOTH),
             by = c("iso3c", "year", "age_bin"))
ihme$ys_BOTH <- ihme$ys_FEMALE * (ihme$pop_FEMALE / ihme$pop_BOTH) +
                ihme$ys_MALE * (ihme$pop_MALE / ihme$pop_BOTH)

# --- IHME-to-Barro-Lee conversion (equivalent of 1.1 background) ---
# Step A: BL Pri+Sec vs BL Pri+Sec+Ter (quadratic, no constant)
bl_conv <- haven::read_dta(file.path(input, "BL2013_MF_v2.1.dta"))
bl_conv <- bl_conv %>%
  filter(ageto != 999, agefrom >= 20, agefrom <= 65, year == 2010) %>%
  mutate(ys_MF = yr_sch_pri + yr_sch_sec,
         yr_sch2 = yr_sch^2)

# Quadratic regression: ys_MF ~ yr_sch + yr_sch2, no intercept
fit_bl <- lm(ys_MF ~ yr_sch + yr_sch2 - 1, data = bl_conv)
blyr1 <- coef(fit_bl)["yr_sch"]
blyr2 <- coef(fit_bl)["yr_sch2"]

# Step B: BL Pri+Sec+Ter vs IHME (quadratic, with constant)
ihme_conv <- ihme %>%
  select(iso3c, age_bin, ys_BOTH) %>%
  rename(WBcode = iso3c)

bl_conv_merge <- bl_conv %>%
  select(WBcode, agefrom, yr_sch) %>%
  rename(age_bin = agefrom)

merged_conv <- inner_join(ihme_conv, bl_conv_merge, by = c("WBcode", "age_bin"))
merged_conv$ys_BOTH2 <- merged_conv$ys_BOTH^2

fit_ihme <- lm(yr_sch ~ ys_BOTH + ys_BOTH2, data = merged_conv)
biyr1  <- coef(fit_ihme)["ys_BOTH"]
biyr2  <- coef(fit_ihme)["ys_BOTH2"]
# NOTE: The original Stata code uses `scalar bicons = _cons`, where `_cons` in Stata
# is a system constant equal to 1 (NOT _b[_cons] which is the regression intercept).
# This means the paper's results use bicons=1 rather than the actual intercept (-0.854).
# We replicate this behavior to match the published results.
bicons <- 1

# Apply conversion to IHME data
ihme$ys_BOTH <- biyr1 * ihme$ys_BOTH + biyr2 * ihme$ys_BOTH^2 + bicons  # IHME -> BL(Pri-Ter)
if (tertiary == "No") {
  ihme$ys_BOTH <- blyr1 * ihme$ys_BOTH + blyr2 * ihme$ys_BOTH^2         # BL(Pri-Ter) -> BL(Pri-Sec)
}

# Age forward by 5 years (same as BL processing)
ihme <- ihme %>%
  arrange(iso3c, age_bin) %>%
  group_by(iso3c) %>%
  mutate(
    ys_BOTH   = ifelse(age_bin == 15, lead(ys_BOTH), ys_BOTH),
    ys_FEMALE = ifelse(age_bin == 15, lead(ys_FEMALE), ys_FEMALE),
    ys_MALE   = ifelse(age_bin == 15, lead(ys_MALE), ys_MALE)
  ) %>%
  ungroup() %>%
  mutate(age_bin = age_bin + 5) %>%
  filter(age_bin >= 20)

# Cap schooling
for (g in c("BOTH", "FEMALE", "MALE")) {
  ihme[[paste0("ys_", g)]] <- pmin(ys_max, ihme[[paste0("ys_", g)]])
}

ihme_school <- ihme %>% select(iso3c, age_bin, ys_BOTH, ys_MALE, ys_FEMALE)
saveRDS(ihme_school, file.path(output, paste0("schooling_2015_IHME_new", fname, ".rds")))

# =========================================================================
# Step 4: Adult survival rates and stunting
# =========================================================================
cat("  Step 4: Reading ASR and stunting data...\n")
asr <- haven::read_dta(file.path(input, "asr_data_21Sept2018.dta"))
asr <- asr %>%
  mutate(
    asr_BOTH   = 1 - mort_15to60_mf_fill,
    asr_FEMALE = 1 - mort_15to60_f_fill,
    asr_MALE   = 1 - mort_15to60_m_fill
  ) %>%
  select(wbcode, year, asr_BOTH, asr_FEMALE, asr_MALE)
saveRDS(asr, file.path(output, "asr.rds"))
asr_2015 <- asr %>% filter(year == 2015)
saveRDS(asr_2015, file.path(output, "asr_2015.rds"))

stunt <- haven::read_dta(file.path(input, "stunting_data_21Sept2018.dta"))
stunt <- stunt %>%
  mutate(
    nostu_BOTH   = 1 - stunt_mf_fill,
    nostu_MALE   = 1 - stunt_m_fill,
    nostu_FEMALE = 1 - stunt_f_fill,
    nostu_MALE   = ifelse(is.na(nostu_MALE), nostu_BOTH, nostu_MALE),
    nostu_FEMALE = ifelse(is.na(nostu_FEMALE), nostu_BOTH, nostu_FEMALE)
  ) %>%
  select(wbcode, year, nostu_BOTH, nostu_MALE, nostu_FEMALE)
saveRDS(stunt, file.path(output, "stunt.rds"))
stunt_2015 <- stunt %>% filter(year == 2015)
saveRDS(stunt_2015, file.path(output, "stunt_2015.rds"))

# =========================================================================
# Step 5: Investment rate (GCF)
# =========================================================================
cat("  Step 5: Reading GCF data...\n")
gcf_raw <- readxl::read_excel(file.path(input, "gross_capital_formation_0718.xls"),
                               sheet = "Data", col_names = TRUE)
# Columns E onward are years starting at 1960
year_cols <- names(gcf_raw)[5:ncol(gcf_raw)]
year_values <- 1960:(1960 + length(year_cols) - 1)
names(gcf_raw)[5:ncol(gcf_raw)] <- paste0("gcf", year_values)

gcf <- gcf_raw %>%
  select(`Country Code`, all_of(paste0("gcf", year_values))) %>%
  rename(CountryCode = `Country Code`) %>%
  pivot_longer(cols = starts_with("gcf"), names_to = "year", values_to = "gcf",
               names_prefix = "gcf") %>%
  mutate(year = as.integer(year), gcf = as.numeric(gcf)) %>%
  filter(year >= 2006, year <= 2015) %>%
  group_by(CountryCode) %>%
  summarize(gcf = mean(gcf, na.rm = TRUE), .groups = "drop") %>%
  mutate(gcf = gcf / 100)
saveRDS(gcf, file.path(output, "gcf.rds"))

# =========================================================================
# Step 6: Physical capital stock (PWT)
# =========================================================================
cat("  Step 6: Reading PWT data...\n")
pwt <- haven::read_dta(file.path(input, "pwt90.dta"))
pwt <- pwt %>%
  filter(year == 2014) %>%
  mutate(year = 2015L, ck = ck * 1e6) %>%
  select(countrycode, year, ck)
saveRDS(pwt, file.path(output, "pwt.rds"))

# =========================================================================
# Step 7: GDP 2015
# =========================================================================
cat("  Step 7: Reading GDP data...\n")
gdp_raw <- readxl::read_excel(file.path(input, "gdp_constant_ppp.xls"),
                               sheet = "Data", col_names = TRUE)
year_cols_g <- names(gdp_raw)[5:ncol(gdp_raw)]
year_values_g <- 1960:(1960 + length(year_cols_g) - 1)
names(gdp_raw)[5:ncol(gdp_raw)] <- paste0("gdp", year_values_g)

gdp <- gdp_raw %>%
  select(`Country Code`, all_of(paste0("gdp", year_values_g))) %>%
  rename(CountryCode = `Country Code`) %>%
  pivot_longer(cols = starts_with("gdp"), names_to = "year", values_to = "gdp",
               names_prefix = "gdp") %>%
  mutate(year = as.integer(year), gdp = as.numeric(gdp)) %>%
  filter(year == 2015) %>%
  select(CountryCode, year, gdp)
saveRDS(gdp, file.path(output, "gdp.rds"))

# =========================================================================
# Steps 8-9: Poverty and Gini
# =========================================================================
cat("  Steps 8-9: Reading poverty data...\n")

read_poverty <- function(pov_line) {
  sheet_name <- pov_line
  df <- readxl::read_excel(file.path(input, "2015 line up.xlsx"), sheet = sheet_name)
  df <- distinct(df)

  # Handle India, China, Indonesia sub-populations
  for (country in c("India", "China", "Indonesia")) {
    df$Country <- gsub(paste0("^", country, "--Rural$"), country, df$Country)
    df$Country <- gsub(paste0("^", country, "--Urban$"), country, df$Country)
    df$Country <- gsub(paste0("^", country, "\\*$"), country, df$Country)
  }

  df$gini_num <- suppressWarnings(as.numeric(df$Gini))
  df$Population <- as.numeric(df$Population)

  # For countries with weighted sum: recalculate gini from urban/rural components
  # The weighted sum row uses population-weighted average of sub-component ginis
  df <- df %>%
    group_by(Country) %>%
    mutate(
      has_ws = any(Survey == "Weighted sum"),
      gini_num = ifelse(has_ws & Survey == "Weighted sum" & n() >= 3,
                        (nth(gini_num, 2) * nth(Population, 2)) / nth(Population, 1) +
                        (nth(gini_num, 3) * nth(Population, 3)) / nth(Population, 1),
                        gini_num)
    ) %>%
    ungroup()

  # Interpolate gini to year 2015, matching Stata's ipolate logic:
  # - "Weighted sum" and "Interpolated" rows get year = 2015
  # - Other rows: parse Survey string as year
  # - Linear interpolation within country
  df$sy <- df$Survey
  df$sy[df$sy == "Weighted sum"]  <- "2015"
  df$sy[df$sy == "Interpolated"]  <- "2015"
  df$y <- suppressWarnings(as.numeric(df$sy))

  # Interpolate gini within each country group, matching Stata's ipolate
  interp_gini <- function(gini_vals, y_vals) {
    idx <- !is.na(gini_vals) & !is.na(y_vals)
    if (sum(idx) >= 2 && length(unique(y_vals[idx])) >= 2) {
      approx(x = y_vals[idx], y = gini_vals[idx], xout = y_vals, rule = 2)$y
    } else {
      gini_vals
    }
  }

  df <- df %>%
    group_by(Country) %>%
    mutate(gini_interp = interp_gini(gini_num, y)) %>%
    slice(1) %>%
    ungroup() %>%
    transmute(
      Country,
      pov = Headcount,
      gini = gini_interp
    )

  # Clean country names
  df$Country <- clean_poverty_names(df$Country)
  df$iso3c <- map_to_iso3c(df$Country)
  df$iso3c[df$Country == "Kosovo"] <- "XKX"
  df <- df %>% filter(Country != "Eswatini", !is.na(iso3c))

  df$pov  <- df$pov / 100
  df$gini <- df$gini / 100

  if (pov_line == "3.2") {
    df <- df %>% rename(pov320 = pov)
  } else if (pov_line == "5.5") {
    df <- df %>% rename(pov550 = pov)
  }

  df$year <- 2015L
  df
}

pov_1.9 <- read_poverty("1.9")
pov_3.2 <- read_poverty("3.2")
pov_5.5 <- read_poverty("5.5")

saveRDS(pov_1.9, file.path(output, "newpov1.9.rds"))
saveRDS(pov_3.2, file.path(output, "newpov3.2.rds"))
saveRDS(pov_5.5, file.path(output, "newpov5.5.rds"))

# =========================================================================
# Step 10: WB Income Classifications
# =========================================================================
cat("  Step 10: Reading CLASS data...\n")
class_data <- readxl::read_excel(file.path(input, "CLASS.xls"),
                                  sheet = "List of economies",
                                  range = "C5:I225", col_names = TRUE)
class_data <- class_data[-1, ]  # Drop first row (header artifact)
class_data <- class_data[1:(nrow(class_data)-1), ]  # Drop last row
class_data <- class_data %>%
  select(Code, Region, `Income group`, `Lending category`) %>%
  rename(wbcode = Code, Incomegroup = `Income group`, Lendingcategory = `Lending category`) %>%
  filter(wbcode != "" & !is.na(wbcode))
saveRDS(class_data, file.path(output, "country_categories.rds"))

# =========================================================================
# Step 11: Creating master file
# =========================================================================
cat("  Step 11: Creating master dataset...\n")

master <- haven::read_dta(file.path(input, "masterdata.dta"))
master <- master %>% filter(year == 2015)

# Expand by 20 age bins (0 to 95)
master <- master %>%
  slice(rep(1:n(), each = 20)) %>%
  group_by(wbcode) %>%
  mutate(age_bin = (seq_len(n()) - 1) * 5) %>%
  ungroup()

# Merge all datasets
master <- master %>%
  left_join(pop_2015 %>% select(iso3c, age_bin, pop_BOTH, pop_MALE, pop_FEMALE),
            by = c("wbcode" = "iso3c", "age_bin")) %>%
  left_join(quality %>% select(wbcode, qual_BOTH, qual_MALE, qual_FEMALE),
            by = "wbcode") %>%
  left_join(schooling %>% select(WBcode, age_bin, ys_BOTH, ys_MALE, ys_FEMALE),
            by = c("wbcode" = "WBcode", "age_bin")) %>%
  left_join(stunt_2015 %>% select(wbcode, nostu_BOTH, nostu_MALE, nostu_FEMALE),
            by = "wbcode") %>%
  left_join(asr_2015 %>% select(wbcode, asr_BOTH, asr_FEMALE, asr_MALE),
            by = "wbcode") %>%
  left_join(gcf %>% select(CountryCode, gcf),
            by = c("wbcode" = "CountryCode")) %>%
  left_join(pwt %>% select(countrycode, ck),
            by = c("wbcode" = "countrycode")) %>%
  left_join(gdp %>% select(CountryCode, gdp),
            by = c("wbcode" = "CountryCode")) %>%
  left_join(pov_1.9 %>% select(iso3c, pov, gini),
            by = c("wbcode" = "iso3c")) %>%
  left_join(pov_3.2 %>% select(iso3c, pov320),
            by = c("wbcode" = "iso3c")) %>%
  left_join(pov_5.5 %>% select(iso3c, pov550),
            by = c("wbcode" = "iso3c")) %>%
  left_join(class_data %>% select(wbcode, Region, Incomegroup, Lendingcategory),
            by = "wbcode")

# Update with IHME data (fills in missing schooling values)
if (include_ihme) {
  ihme_data <- readRDS(file.path(output, paste0("schooling_2015_IHME_new", fname, ".rds")))
  master <- master %>%
    left_join(ihme_data %>% select(iso3c, age_bin, ys_BOTH, ys_MALE, ys_FEMALE) %>%
                rename(ys_BOTH_ihme = ys_BOTH, ys_MALE_ihme = ys_MALE, ys_FEMALE_ihme = ys_FEMALE),
              by = c("wbcode" = "iso3c", "age_bin"))
  # Update: fill missing BL values with IHME
  master <- master %>%
    mutate(
      ys_BOTH   = ifelse(is.na(ys_BOTH), ys_BOTH_ihme, ys_BOTH),
      ys_MALE   = ifelse(is.na(ys_MALE), ys_MALE_ihme, ys_MALE),
      ys_FEMALE = ifelse(is.na(ys_FEMALE), ys_FEMALE_ihme, ys_FEMALE)
    ) %>%
    select(-ys_BOTH_ihme, -ys_MALE_ihme, -ys_FEMALE_ihme)
}

# Generate human capital from education
for (g in c("BOTH", "MALE", "FEMALE")) {
  ys_col   <- paste0("ys_", g)
  qual_col <- paste0("qual_", g)
  adye_col <- paste0("adye_", g)
  hce_col  <- paste0("hce_", g)

  master[[adye_col]] <- ifelse(!is.na(master[[ys_col]]) & !is.na(master[[qual_col]]),
                                master[[ys_col]] * master[[qual_col]], NA_real_)
  master[[hce_col]]  <- ifelse(!is.na(master[[adye_col]]),
                                exp(phi * (pmin(master[[adye_col]], adys_max) - adys_max)),
                                NA_real_)
}

# Generate human capital from health
for (g in c("BOTH", "MALE", "FEMALE")) {
  asr_col   <- paste0("asr_", g)
  nostu_col <- paste0("nostu_", g)
  hch_col   <- paste0("hch_", g)

  master[[hch_col]] <- ifelse(
    is.na(master[[nostu_col]]),
    exp(gam_asr_mid * (master[[asr_col]] - 1)),
    exp((gam_asr_mid * (master[[asr_col]] - 1) + gam_stu_mid * (master[[nostu_col]] - 1)) / 2)
  )
}

# Total human capital
for (g in c("BOTH", "MALE", "FEMALE")) {
  master[[paste0("hc_", g)]] <- master[[paste0("hce_", g)]] * master[[paste0("hch_", g)]]
}

# Drop countries missing critical inputs
master <- master %>%
  filter(!is.na(qual_BOTH), !is.na(ys_BOTH), !is.na(ck),
         !is.na(gdp), !is.na(gcf), !is.na(asr_BOTH))

cat("  Countries in master:", length(unique(master$wbcode)), "\n")

# Save
saveRDS(master, file.path(output, paste0("human_capital_2015", fname, ".rds")))

cat("  01_assemble.R complete.\n")
