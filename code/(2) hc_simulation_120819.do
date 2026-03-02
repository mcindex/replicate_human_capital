* This .do file simulates the impact of changes in the HCI on subsequent GDP per worker and the poverty rate
* It is (2/6) of the .do files in this project. 
* Author: Matt Collin (mcollin@brookings.edu) 
* This version: October 22nd, 2019
* Changes (07-26-18): calculations for GDP per capita, including changes to poverty calculations
* Changes (08-14-18): Included new simulations needed for capital investment comparisons
* Changes (10-22-19): Added ability to include tertiary education

* Paths are set in master.do — run master.do first to define globals
* Required globals: $root, $input, $output, $graphs, $do

* Installing customs modules (commented out unless needed)
*ssc install mmerge	

* Setting the parameters for the model
scalar alpha    = 1/3						// Cobb-Douglas factor share for capital 
scalar pgr      = .0130					    // This is the growth rate of productivity
scalar delta    = .05						// Depreciation rate of capital 
scalar phi      = 0.08						// Mincerian return to education
scalar endyear  = 2100						// Last year we want the simulation to run to 

* Include tertiary education? (note, this will reset max for quality adjusted years of schooling)
* If $tertiary_mode is set by master.do, use it; otherwise default to "No"
local tertiary = "No"
if "$tertiary_mode" != "" {
	local tertiary = "$tertiary_mode"
}
if "`tertiary'" == "Yes" {
	scalar   ys_max        = 16									// Set max for years of schooling
	scalar adys_max        = 16	
	local fname = "ter"
}
else {
	scalar   ys_max        = 12									// Set max for years of schooling
	scalar adys_max        = 12									// Set max for quality adjusted years of schooling
	local fname = ""
}


*****************************************************************

* Creating frame - we expand the data so we have rows by country, year, age_bin
use "$output\human_capital_2015_102219`fname'.dta", clear
keep wbcode age_bin
local  ts = (endyear - 2015)/5 + 1
expand `ts'
bys wbcode age_bin: gen year = (2010 + 5*_n) 

* Keep working age population
keep if age_bin >=20 & age_bin <=60

* Merge in population bin data
mmerge wbcode year age_bin  using "$output/population_bins.dta", type(1:1) unmatched(master) umatch(iso3c year age_bin)

* Merging in starting values of capital, human capital, GDP
mmerge wbcode year age_bin using "$output\human_capital_2015_102219`fname'.dta", type(1:1) unmatched(master) umatch(wbcode year age_bin)

* We will only use the population level data for now, so drop female and male-specific estimates
drop *FEMALE *MALE

* Calculating age-bin aggregate human capital at T0
gen a_hc = pop_BOTH * hc_BOTH													// Which is the total pop for the age bin X the average HC for that age bin								


*****************************************
* STEP 1: Age-bin specific calculations *
*****************************************
* Here we run through all scenarios that involve changes in human capital per worker over time 

* *	* * CONSTANT SCENARIO: HC per worker improves due to aging out of older cohorts  *
gen ys_BOTH_constant   = ys_BOTH
gen qual_BOTH_constant = qual_BOTH
gen hch_BOTH_constant  = hch_BOTH 

* We're doing this in a less complicated way than the previous version: we're just using the [_n] function to grab earlier values. 
* Note that these will need to be adjusted if we decide upon a differnet number of age-bins
local ey = endyear																						 // Saving the endyear as a local so we can include it in the loops
sort wbcode year age_bin 
forvalues t = 2020(5)`ey' {																			     // Cycling over subsequent years
		bys wbcode: replace ys_BOTH_constant = ys_BOTH_constant[_n-9] if age_bin == 20  & year == `t'    // Each new 20-24 cohort takes on the educational attainment of the previous 20-24 cohort (
		bys wbcode: replace ys_BOTH_constant = ys_BOTH_constant[_n-10] if age_bin >  20 & year == `t'    // Every other cohort moves `forward' in time, carrying forward its education attainment
		
		bys wbcode: replace hch_BOTH_constant  = hch_BOTH_constant[_n-9]  if year == `t' 				 // Human Capital from health remains constant
		bys wbcode: replace qual_BOTH_constant = qual_BOTH_constant[_n-9] if year == `t' 				 // Education quality remains constant
}
gen adye_BOTH_constant = ys_BOTH_constant * qual_BOTH_constant					// Generating new adjusted years of schooling
gen hce_BOTH_constant  = exp(phi*(min(adye_BOTH_constant,adys_max)-adys_max))	// Generating new human capital from education (note we are capping adjusted years of schooling at 12)
gen hc_BOTH_constant   = hch_BOTH_constant * hce_BOTH_constant 				    // Generating new human capital under constant scenario
gen a_hc_constant      = pop_BOTH * hc_BOTH_constant							// Generating total human capital per age bin under constant scenario							

* * * Prior to calculating Scenarios 1 and 2, we run this .do file to calculate the `typical' and `optimistic' scenarios
* These return two scalars:  hci_gap_5rate_50 and  hci_gap_5rate_75, the hci_gap five year `growth' under these two scenarios (50 = typical and 75 = optimistic)
preserve
do "$do/2.1 (background) scenario_102219`fname'.do"
restore


* * * * SCENARIO 1: HCI follows the `typical' scenario in which the HCI gap closes by roughly 5% every 5 years 
gen hc_BOTH_sc1 = hc_BOTH														// Setting initial (t0) value
sort wbcode year age_bin 
forvalues t = 2020(5)`ey' {
		bys wbcode: replace hc_BOTH_sc1 = 1-((1-hci_gap_5rate_50)*(1-hc_BOTH_sc1[_n-9])) if age_bin == 20 & year == `t'   // The newest cohort closes 5% of the gap 
		bys wbcode: replace hc_BOTH_sc1 = hc_BOTH_sc1[_n-10]            if age_bin >  20 & year == `t'   				  // Every other cohort moves `forward' in time, carrying forward its education attainment
}
gen a_hc_sc1      = pop_BOTH * hc_BOTH_sc1										// Generating total human capital per age bin under scenario 1						


* *	* * SCENARIO 2: the HCI gap is closed at the same rate as the 75 percentile of best performers in the HCI database
gen hc_BOTH_sc2 = hc_BOTH														// Setting initial (t0) value
sort wbcode year age_bin 
forvalues t = 2020(5)`ey' {
		bys wbcode: replace hc_BOTH_sc2 = 1-((1-hci_gap_5rate_75)*(1-hc_BOTH_sc2[_n-9])) if age_bin == 20 & year == `t'   // The newest cohort closes 5% of the gap 
		bys wbcode: replace hc_BOTH_sc2 = hc_BOTH_sc2[_n-10]            if age_bin >  20 & year == `t'   // Every other cohort moves `forward' in time, carrying forward its education attainment
}
gen a_hc_sc2      = pop_BOTH * hc_BOTH_sc2										// Generating total human capital per age bin under scenario 1						

				
* *	* SCENARIO 3: HCI is closed immediately
gen hc_BOTH_sc3 = hc_BOTH														// Setting initial (t0) value
sort wbcode year age_bin 
forvalues t = 2020(5)`ey' {
		bys wbcode: replace hc_BOTH_sc3 = 1							  			if age_bin == 20 & year == `t'   // The newest cohort has maximum HCI
		bys wbcode: replace hc_BOTH_sc3 = hc_BOTH_sc3[_n-10]            		if age_bin >  20 & year == `t'   // Every other cohort moves `forward' in time, carrying forward its education attainment
}
gen a_hc_sc3      = pop_BOTH * hc_BOTH_sc3	


* *	* * SCENARIO 4: HCI gap is closed by the typical scenario for one five year period, then is held fixed
gen hc_BOTH_sc4 = hc_BOTH														// Setting initial (t0) value
sort wbcode year age_bin 
forvalues t = 2020(5)`ey' {
		bys wbcode: replace hc_BOTH_sc4 = 1-((1-hci_gap_5rate_50)*(1-hc_BOTH[1])) if age_bin == 20 & year == `t'   // The newest cohort closes 5% of the gap 
		bys wbcode: replace hc_BOTH_sc4 = hc_BOTH_sc4[_n-10]            		  if age_bin >  20 & year == `t'   // Every other cohort moves `forward' in time, carrying forward its education attainment
}
gen a_hc_sc4      = pop_BOTH * hc_BOTH_sc4


* *	* SCENARIO 5: HCI is closed by the optimistic scenario for one five year period, then is held fixed
gen hc_BOTH_sc5 = hc_BOTH														// Setting initial (t0) value
sort wbcode year age_bin 
forvalues t = 2020(5)`ey' {
		bys wbcode: replace hc_BOTH_sc5 = 1-((1-hci_gap_5rate_75)*(1-hc_BOTH[1])) if age_bin == 20 & year == `t'   // The newest cohort closes 5% of the gap 
		bys wbcode: replace hc_BOTH_sc5 = hc_BOTH_sc5[_n-10]            		  if age_bin >  20 & year == `t'   // Every other cohort moves `forward' in time, carrying forward its education attainment
}
gen a_hc_sc5      = pop_BOTH * hc_BOTH_sc5


*****************************************************************************
* STEP 2: Collapsing to country-year level and making final HC calculations *
*****************************************************************************

* Saving a separate file to make labor force participation rate changes
save "$output/hcpw_projections_120819.dta", replace

* Summing up total working population and total human capital
collapse (sum) pop_BOTH a_hc* (first) wbcountryname ck gcf* gini pov* gdp Incomegroup Lendingcategory Region, by(wbcode year)	// This gives us total working population for each country year and total HC for that country year

* Calculating HCPW under the baseline scenario (NOTE WE ARE NO LONGER USING THIS SCENARIO)
gen hcpw_baseline = a_hc / pop_BOTH
sort wbcode year
bys  wbcode : replace hcpw_baseline = hcpw_baseline[1] if _n > 1				// We hold HCPW constant

* Calculating HCPW under subsequent two senarios
foreach sc in constant sc1 sc2 sc3 sc4 sc5 {
	gen hcpw_`sc' = a_hc_`sc'/pop_BOTH
}

* Bringing in total population numbers 
mmerge wbcode year using "$output/total_population.dta", umatch(iso3c year) type(1:1) unmatched(master)

*******************************************
* STEP 3: Calculating productivity growth *
*******************************************
*Generating year 0 productivity 
gen gdppw = gdp  / pop_BOTH											if year == 2015	 // GDP per worker
gen hcpw  = a_hc / pop_BOTH											if year == 2015	 // HC  per worker
gen kpw   = ck   / pop_BOTH											if year == 2015	 // K   per worker 
gen a     = gdppw / ( ((kpw)^(alpha))*((hcpw_baseline)^(1-alpha)))	if year == 2015	 // Year 0 productivity (equation 14)

* Now rolling the model forward and calculating productivity growth
sort wbcode year
forvalues t = 2020(5)`ey' {
	bys  wbcode: replace a = a[1]*(1+pgr)^((`t'-2015))	if year ==`t'		    // Calculating productivity growth
}


**********************
* Final Calculations * 
**********************

* Each country has a Gini coefficient value taken at t0 (2015). We use that value to calculate the 
* variance of the log distribution of income: 
gen sigma = invnormal( ( gini + 1 )/2 ) * sqrt(2) 								// Following equation (16) in the paper
bys wbcode: replace sigma = sigma[1] if year > 2015								// We assume that the variance remains fixed

* Final GDP and poverty calculations
foreach scenario in constant baseline sc1 sc2 sc3 sc4 sc5 {								// Calculating capital stock and GDP for each scenario
	sort wbcode year 
	gen  ck_`scenario'  = ck
	gen  kpw_`scenario' = ck_`scenario' / pop_BOTH								// Calculating capital per worker in the first period
	gen  pov_`scenario' = pov													// Poverty rate
	gen  pov320_`scenario' = pov320												// Poverty rate
	gen  pov550_`scenario' = pov550												// Poverty rate

	* Rolling forward in five year intervals and using the secnario specific values of capital and human capital
	forvalues t = 2020(5)`ey' {
		bys wbcode: replace kpw_`scenario' = 	(pop_BOTH[_n-1]/pop_BOTH)*( kpw_`scenario'[_n-1] + 5 * (gcf[1] * a[_n-1] * (kpw_`scenario'[_n-1]^(alpha))*(hcpw_`scenario'[_n-1]^(1-alpha)) - delta * kpw_`scenario'[_n-1]) ) if year == `t'  // Equation 24
	}

	* Generating GDP per worker
	gen     gdppw_`scenario' = a * (kpw_`scenario'^(alpha))*(hcpw_`scenario'^(1-alpha))
	
	
	* Calculating GDP per capita
	gen    gdppc_`scenario' =  gdppw_`scenario' * (total_working/total_pop)		// GDP per capita is defined as GDP per worker X the working age fraction 
	
	* Generating poverty rate and poverty rate relative to baseline
	foreach p in pov pov320 pov550 {
		bys wbcode: replace `p'_`scenario'   = normal(invnormal(`p'[1]) - (1/sigma)* ln((gdppc_`scenario')/(gdppc_`scenario'[1]))) if year > 2015  // Note that [1] indicates the value in year 0 for that country
					gen     `p'_`scenario'_r = `p'_`scenario' / `p'_constant
					gen     `p'_`scenario'_p = `p'_`scenario' - `p'_constant
	}
	
	* Calculating relative GDP
	gen     gdppw_`scenario'_r = gdppw_`scenario' / gdppw_constant			// Calculating GDP relative to baseline	
	gen     gdppc_`scenario'_r = gdppc_`scenario' / gdppc_constant			// Calculating GDP relative to baseline	
	
	
	lab var ck_`scenario'      "Capital stock (`scenario' scenario)"
	lab var kpw_`scenario'     "Capital per worker (`scenario' scenario)" 
	lab var gdppw_`scenario'   "GDP per worker (`scenario' scenario)" 
	lab var gdppc_`scenario'   "GDP per capita (`scenario' scenario)"
	lab var gdppw_`scenario'_r "GDP per worker (`scenario' scenario) relative to baseline"
	lab var gdppc_`scenario'_r "GDP per capita (`scenario' scenario) relative to baseline"
	lab var pov_`scenario'     "Poverty rate (`scenario' scenario)"
	lab var pov_`scenario'_r   "Poverty rate (`scenario' scenario) relative to baseline"
	lab var pov_`scenario'_p   "Poverty rate percentage point difference (`scenario' scenario) from baseline"
	
}


rename pop_BOTH working_pop_both
lab var working       "Working population (Age 20-64)"
lab var hcpw_baseline "Human Capital Per Worker (Baseline)"
lab var hcpw_constant "Human Capital Per Worker (Constant)"
lab var hcpw_sc1      "Human Capital Per Worker (Scenario 1)"
lab var hcpw_sc2      "Human Capital Per Worker (Scenario 2)"
lab var a             "Productivity" 
lab var total_pop     "Total population"
lab var total_working "Total working population (20-64)" 
lab var wbcode        "World Bank/ISO3 Country Code"
lab var year          "Projection Year" 
lab var wbcountryname "Country Name"
lab var Income        "WB Income Classification" 
lab var Lending       "WB Lending Category" 
lab var Region        "WB Region"


* We lost country name so I'm going to fill those out again
foreach var of varlist wbcountryname Income Lending Region {
	bys wbcode: replace `var' = `var'[_n-1] if `var' == ""
}

keep wbcode year working_pop_both wbcountryname hcpw_baseline hcpw_constant hcpw_sc* a ck_constant-gdppc_sc5_r total* *_p Incomegroup Lendingcategory Region
save "$output/hc_projections_102219`fname'.dta", replace



exit
