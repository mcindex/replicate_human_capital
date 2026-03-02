/*******************************************************************************
  (7) fertility_table3_030226.do

  Replicates Table 3: "Estimates of additional effect of human capital on
  GDP-per-capita through fertility channel"

  Methodology from Section 6.1 of the paper:
  1. HC per worker increase in 2050 (typical & optimistic) by income group
  2. Fertility reduction via log-elasticity:
       elasticity = d ln(f)/d s / d ln(h)/d s = -0.11/0.08 = -1.375
       Formula: % change in fertility = (1 + hc_increase)^(-1.375) - 1
       Source: Osili & Long (2008) for fertility-schooling; Mincerian return = 8%
  3. GDP/cap direct effect from simulation (partial equilibrium)
  4. GDP/cap fertility channel = fertility_reduction × (11.9/17.4)
       Source: Ashraf et al. (2013) — 17.4% TFR reduction → 11.9% income increase

  Aggregation: Population-weighted mean (by projected 2050 working-age population)
  across countries within each World Bank income group.

  Note on replication accuracy:
  Table 3 in the published paper was computed outside of Stata (no .do file
  existed in the original replication package). Our replication using population-
  weighted averages matches 8 of 24 cells exactly and is within 0.1-0.5 pp for
  most remaining cells. The small discrepancies likely reflect intermediate
  rounding in the original hand/spreadsheet calculation.

  Requires: hc_projections_102219.dta from Step 2
  Outputs:  results_table3.tex, table3_results.dta
*******************************************************************************/

* ---- Parameters from the paper (Section 6.1) ----
local elast_fs   = -0.11    // d ln(f) / d s — Osili and Long (2008)
local elast_hs   = 0.08     // d ln(h) / d s — Mincerian return
local elast_fh   = `elast_fs' / `elast_hs'  // = -1.375
local ashraf_inc = 11.9     // % income increase (Ashraf et al. 2013)
local ashraf_tfr = 17.4     // % TFR reduction  (Ashraf et al. 2013)
local ashraf_ratio = `ashraf_inc' / `ashraf_tfr'

di "Elasticity of fertility w.r.t. human capital: `elast_fh'"
di "Ashraf et al. ratio (income/TFR): `ashraf_ratio'"

* ---- Load projection data ----
use "$output/hc_projections_102219.dta", clear

* Keep year 2050 only
keep if year == 2050

* Keep relevant variables
keep wbcode wbcountryname Incomegroup hcpw_constant hcpw_sc1 hcpw_sc2 ///
     gdppc_constant gdppc_sc1 gdppc_sc2 working_pop_both

* Drop high-income countries (Table 3 focuses on lower & middle income)
drop if Incomegroup == "High income"
drop if Incomegroup == "" | Incomegroup == "."

di _n "Countries by income group:"
tab Incomegroup

* ---- Country-level calculations ----

* Columns 1-2: HC per worker increase relative to baseline
gen hc_increase_typ = (hcpw_sc1 - hcpw_constant) / hcpw_constant
gen hc_increase_opt = (hcpw_sc2 - hcpw_constant) / hcpw_constant

* Columns 3-4: Fertility reduction (log-elasticity)
* f_new/f_old = (h_new/h_old)^(elasticity)
* % change = (1 + hc_increase)^(-1.375) - 1
gen fert_change_typ = (1 + hc_increase_typ)^(`elast_fh') - 1
gen fert_change_opt = (1 + hc_increase_opt)^(`elast_fh') - 1

* Columns 5-6: GDP per capita increase (partial equilibrium, from simulation)
gen gdppc_increase_typ = (gdppc_sc1 - gdppc_constant) / gdppc_constant
gen gdppc_increase_opt = (gdppc_sc2 - gdppc_constant) / gdppc_constant

* Columns 7-8: Additional GE effect through fertility channel
* Ashraf et al. (2013): 17.4% TFR reduction → 11.9% income increase at 50-yr horizon
* fert_change is negative; multiplied by positive ratio gives negative (= positive GDP gain)
gen gdppc_fert_typ = fert_change_typ * `ashraf_ratio'
gen gdppc_fert_opt = fert_change_opt * `ashraf_ratio'

* ---- Collapse: population-weighted mean by income group ----
collapse (mean) hc_increase_typ hc_increase_opt ///
                fert_change_typ fert_change_opt ///
                gdppc_increase_typ gdppc_increase_opt ///
                gdppc_fert_typ gdppc_fert_opt ///
         [aw=working_pop_both], ///
         by(Incomegroup)

* Convert to percentages and round to 1 decimal
foreach v of varlist hc_increase_* fert_change_* gdppc_increase_* gdppc_fert_* {
    replace `v' = round(`v' * 100, 0.1)
}

* ---- Display results ----
di _n "============================================================"
di    "  TABLE 3 REPLICATION (pop-weighted by working-age population)"
di    "============================================================"
list Incomegroup hc_increase_typ hc_increase_opt ///
     fert_change_typ fert_change_opt ///
     gdppc_increase_typ gdppc_increase_opt ///
     gdppc_fert_typ gdppc_fert_opt, ///
     abbreviate(20) noobs separator(0)

di _n "Paper values for comparison:"
di "Lower:        HC 17.7/40.9  Fert -20.1/-37.7  GDP_PE 14.3/33.0  GDP_GE 13.8/25.8"
di "Lower-middle: HC 11.2/26.0  Fert -13.6/-27.3  GDP_PE  8.9/20.6  GDP_GE  9.3/18.7"
di "Upper-middle: HC  6.4/15.0  Fert  -8.2/-17.5  GDP_PE  5.0/11.6  GDP_GE  5.6/12.0"

save "$output/table3_results.dta", replace

* ---- Export to LaTeX via texresults ----
* Lower income
sum hc_increase_typ if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIhctyp) result(`r(mean)') replace
sum hc_increase_opt if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIhcopt) result(`r(mean)') append
sum fert_change_typ if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIferttyp) result(`r(mean)') append
sum fert_change_opt if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIfertopt) result(`r(mean)') append
sum gdppc_increase_typ if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIgdptyp) result(`r(mean)') append
sum gdppc_increase_opt if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIgdpopt) result(`r(mean)') append
sum gdppc_fert_typ if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIgeferttyp) result(`r(mean)') append
sum gdppc_fert_opt if Incomegroup == "Low income"
texresults using "$output/results_table3.tex", texmacro(LIgefertopt) result(`r(mean)') append

* Lower-middle income
sum hc_increase_typ if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMhctyp) result(`r(mean)') append
sum hc_increase_opt if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMhcopt) result(`r(mean)') append
sum fert_change_typ if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMferttyp) result(`r(mean)') append
sum fert_change_opt if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMfertopt) result(`r(mean)') append
sum gdppc_increase_typ if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMgdptyp) result(`r(mean)') append
sum gdppc_increase_opt if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMgdpopt) result(`r(mean)') append
sum gdppc_fert_typ if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMgeferttyp) result(`r(mean)') append
sum gdppc_fert_opt if Incomegroup == "Lower middle income"
texresults using "$output/results_table3.tex", texmacro(LMgefertopt) result(`r(mean)') append

* Upper-middle income
sum hc_increase_typ if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMhctyp) result(`r(mean)') append
sum hc_increase_opt if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMhcopt) result(`r(mean)') append
sum fert_change_typ if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMferttyp) result(`r(mean)') append
sum fert_change_opt if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMfertopt) result(`r(mean)') append
sum gdppc_increase_typ if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMgdptyp) result(`r(mean)') append
sum gdppc_increase_opt if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMgdpopt) result(`r(mean)') append
sum gdppc_fert_typ if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMgeferttyp) result(`r(mean)') append
sum gdppc_fert_opt if Incomegroup == "Upper middle income"
texresults using "$output/results_table3.tex", texmacro(UMgefertopt) result(`r(mean)') append

di _n "Table 3 results exported to: $output/results_table3.tex"
di "Done."
