* =============================================================================
* Master .do file
* "The Effect of Increasing Human Capital Investment on Economic Growth
*  and Poverty: A Simulation Exercise"
* Authors: Matthew Collin & David N. Weil
* Journal of Human Capital, 2020
* =============================================================================
* Original Stata version: Stata 15 (MP)
* Tested with: StataNow 18.5 MP
* This master file sets all global paths and runs scripts in order.
* To replicate: change the $root path below to your project directory.
* =============================================================================

clear all
set more off

* =============================================================================
* SET ROOT DIRECTORY — change this to your project folder
* =============================================================================
global root "C:\github-repos\replicate_human_capital"

* Derived paths (do not change)
global input   "$root/input"
global output  "$root/output"
global graphs  "$root/figures_tables"
global do      "$root/code"

* Add local ado directory (bundled packages for reproducibility)
cap mkdir "$root/code/ado"
adopath ++ "$root/code/ado"

* =============================================================================
* Required user-written Stata packages
* These are bundled in code/ado/ for reproducibility.
* If running for the first time and code/ado/ is empty, uncomment to install:
* =============================================================================
* ssc install mmerge
* ssc install kountry
* ssc install texresults
* ssc install wbopendata

* =============================================================================
* MAIN ANALYSIS (Primary-Secondary model) — run in order
* =============================================================================
global tertiary_mode "No"

* (1) Assemble all input data for the model
*     Merges population projections, education, health, investment, GDP,
*     poverty, and country classification data into a master dataset.
*     Calls: 1.1 (background) barrolee_ihme_conversion_011320.do
do "$do/(1) assemble_102219.do"

* (2) Run the human capital simulation model
*     Projects human capital per worker under baseline + 5 scenarios,
*     then calculates GDP per capita and poverty rates over time.
*     Calls: 2.1 (background) scenario_102219.do
do "$do/(2) hc_simulation_120819.do"

* (3) Produce world projection statistics and graphs (Figures 2-7)
*     Calculates aggregate outcomes for world, developing, low-income, and SSA
do "$do/(3) hc_worldprojections_011320.do"

* (4) NPV calculations comparing human vs physical capital investment (Figure 9)
*     WARNING: This file is computationally intensive and takes a long time to run.
do "$do/(4) npv_calculations_011320.do"

* (5) Cambodia counterfactual analysis (Figure 8)
do "$do/(5) cambodia_counterfactual_011320.do"

* =============================================================================
* TERTIARY EDUCATION MODEL (Appendix robustness check)
* Re-runs Steps 1 and 2 with tertiary education included,
* then runs Step 6 which compares secondary-only and tertiary models.
* =============================================================================
global tertiary_mode "Yes"

* (1-ter) Assemble data with tertiary education
do "$do/(1) assemble_102219.do"

* (2-ter) Run simulation with tertiary education
do "$do/(2) hc_simulation_120819.do"

* Save tertiary scenario scalars with "ter" suffix (Step 6 needs both sets)
scalar hci_gap_5rate_50ter  = hci_gap_5rate_50
scalar hci_gap_5rate_75ter  = hci_gap_5rate_75
scalar hci_gap_5rate_50pter = hci_gap_5rate_50p
scalar hci_gap_5rate_75pter = hci_gap_5rate_75p

* Restore secondary scenario scalars
global tertiary_mode "No"
do "$do/2.1 (background) scenario_102219.do"

* (6) Tertiary education robustness checks (Appendix figures)
*     Compares primary-secondary model to primary-tertiary model
*     Requires both sec and ter projection files + both sets of scenario scalars
do "$do/(6) hc_education_compare_011320.do"

* (7) Table 3: Effect of HC on GDP through fertility channel (Section 6.1)
*     Uses log-elasticity from Osili & Long (2008) and Ashraf et al. (2013)
*     Pop-weighted averages by income group; matches 8/24 cells exactly
do "$do/(7) fertility_table3_030226.do"

* =============================================================================
* STANDALONE SCRIPTS (not part of main pipeline)
* =============================================================================
* Labor force participation analysis (Figures 10-11)
* Must be run in a separate clean Stata session — estimates conflict with main pipeline
* do "$do/labor_participation_011320.do"

exit
