# =============================================================================
# master.R — R Replication of the Stata Analysis Pipeline
# "The Effect of Increasing Human Capital Investment on Economic Growth
#  and Poverty: A Simulation Exercise"
# Authors: Matthew Collin & David N. Weil
# Journal of Human Capital, 2020
# =============================================================================
# Original Stata version: Stata 15 (MP)
# R version: 4.3.2+
# This master file sets all paths, installs/loads packages, and sources scripts.
# To replicate: change the `root` path below to your project directory.
# =============================================================================

rm(list = ls())

# =============================================================================
# SET ROOT DIRECTORY — change this to your project folder
# =============================================================================
root <- "C:/github-repos/replicate_human_capital"

# Derived paths (do not change)
input   <- file.path(root, "input")
output  <- file.path(root, "output")
graphs  <- file.path(root, "figures_tables")
codedir <- file.path(root, "code", "R")

# =============================================================================
# INSTALL AND LOAD REQUIRED PACKAGES
# =============================================================================
required_packages <- c(
  "haven",        # Read .dta files
  "readxl",       # Read .xls/.xlsx files
  "dplyr",        # Data manipulation
  "tidyr",        # Reshaping
  "ggplot2",      # Graphs
  "countrycode",  # Country name/code conversion
  "data.table",   # Fast merges and by-group operations
  "stringr",      # String manipulation
  "purrr",        # Functional programming helpers
  "scales",       # Axis label formatting
  "patchwork"     # Multi-panel figure layout
)

install_if_missing <- function(pkgs) {
  missing <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
  if (length(missing) > 0) {
    cat("Installing packages:", paste(missing, collapse = ", "), "\n")
    install.packages(missing, repos = "https://cloud.r-project.org")
  }
}

install_if_missing(required_packages)
invisible(lapply(required_packages, library, character.only = TRUE))

cat("All packages loaded successfully.\n")

# =============================================================================
# TERTIARY MODE FLAG (mirrors Stata $tertiary_mode)
# =============================================================================
# Set to "Yes" to include tertiary education; "No" for primary+secondary only
tertiary_mode <- "No"

# =============================================================================
# MAIN ANALYSIS (Primary-Secondary model) — run in order
# =============================================================================

# (1) Assemble all input data for the model
cat("\n=== Running 01_assemble.R ===\n")
source(file.path(codedir, "01_assemble.R"))

# (2) Run the human capital simulation model
cat("\n=== Running 02_hc_simulation.R ===\n")
source(file.path(codedir, "02_hc_simulation.R"))

# (3) Produce world projection statistics and graphs (Figures 2-7)
cat("\n=== Running 03_hc_worldprojections.R ===\n")
source(file.path(codedir, "03_hc_worldprojections.R"))

# (4) NPV calculations (Figure 9) — computationally intensive
cat("\n=== Running 04_npv_calculations.R ===\n")
source(file.path(codedir, "04_npv_calculations.R"))

# (5) Cambodia counterfactual analysis (Figure 8)
cat("\n=== Running 05_cambodia_counterfactual.R ===\n")
source(file.path(codedir, "05_cambodia_counterfactual.R"))

# =============================================================================
# TERTIARY EDUCATION MODEL (Appendix robustness check)
# =============================================================================
tertiary_mode <- "Yes"

# (1-ter) Assemble data with tertiary education
cat("\n=== Running 01_assemble.R (tertiary) ===\n")
source(file.path(codedir, "01_assemble.R"))

# (2-ter) Run simulation with tertiary education
cat("\n=== Running 02_hc_simulation.R (tertiary) ===\n")
source(file.path(codedir, "02_hc_simulation.R"))

# Save tertiary scenario scalars
hci_gap_5rate_50ter  <- hci_gap_5rate_50
hci_gap_5rate_75ter  <- hci_gap_5rate_75
hci_gap_5rate_50pter <- hci_gap_5rate_50p
hci_gap_5rate_75pter <- hci_gap_5rate_75p

# Restore secondary scenario scalars
tertiary_mode <- "No"
source(file.path(codedir, "scenario_calc.R"))

# (6) Tertiary education robustness checks (Appendix figures)
cat("\n=== Running 06_hc_education_compare.R ===\n")
source(file.path(codedir, "06_hc_education_compare.R"))

# (7) Table 3: Fertility channel (Section 6.1)
cat("\n=== Running 07_fertility_table3.R ===\n")
source(file.path(codedir, "07_fertility_table3.R"))

# =============================================================================
# STANDALONE SCRIPTS
# =============================================================================
# (8) Labor force participation analysis (Figures 10-11)
cat("\n=== Running 08_labor_participation.R ===\n")
source(file.path(codedir, "08_labor_participation.R"))

cat("\n=== All R scripts completed successfully. ===\n")
