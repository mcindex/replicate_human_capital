# country_names.R — Helper: standardize country names and map to ISO3C
# Mirrors the kountry-based mapping from the Stata code

library(countrycode)

# WPP country name cleaning (matches Stata assemble.do lines 101-115)
clean_wpp_names <- function(region) {
  region <- ifelse(region == "TFYR Macedonia", "Macedonia", region)
  region <- ifelse(region == "Micronesia (Fed. States of)", "Micronesia", region)
  region <- ifelse(region == "Curaçao" | region == "Curacao", "Curacao", region)
  region <- ifelse(region == "Réunion", "Reunion", region)
  region <- ifelse(region == "China, Macao SAR", "Macao", region)
  region <- ifelse(region == "Dem. People's Republic of Korea", "North Korea", region)
  region <- ifelse(region == "China, Hong Kong SAR", "Hong Kong", region)
  region <- ifelse(region == "State of Palestine", "Palestine", region)
  region <- ifelse(region == "Czechia", "Czech Republic", region)
  region <- ifelse(region == "China, Taiwan Province of China", "Taiwan", region)
  region <- ifelse(region == "Cabo Verde", "Cape Verde", region)
  region <- ifelse(region == "Bolivia (Plurinational State of)", "Bolivia", region)
  region <- ifelse(region == "Côte d'Ivoire", "Cote d'Ivoire", region)
  region <- ifelse(region == "Venezuela (Bolivarian Republic of)", "Venezuela", region)
  region
}

# Map cleaned country names to ISO3C codes
map_to_iso3c <- function(names, source_type = "country.name") {
  iso3c <- countrycode(names, origin = source_type, destination = "iso3c",
                       warn = FALSE,
                       custom_match = c(
                         "Curacao" = "CUW",
                         "Curaçao" = "CUW",
                         "Kosovo" = "XKX",
                         "Micronesia" = "FSM",
                         "Channel Islands" = NA_character_
                       ))
  iso3c
}

# Poverty file country name cleaning (matches Stata lines 390-402)
clean_poverty_names <- function(country) {
  country <- ifelse(country == "Argentina--Urban", "Argentina", country)
  country <- ifelse(country == "Egypt, Arab Republic of", "Egypt", country)
  country <- ifelse(country == "Macedonia, former Yugoslav Republic of", "Macedonia", country)
  country <- ifelse(country == "Venezuela, Republica Bolivariana de", "Venezuela", country)
  country <- ifelse(country == "Yemen, Republic of", "Yemen", country)
  country <- ifelse(country == "Cabo Verde", "Cape Verde", country)
  country
}
