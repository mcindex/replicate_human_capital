* This .do file conducts the net present value calculations for the paper.
* It is (4/6) of the .do files in this project. 
* .do file author: Matt Collin (mcollin@brookings.edu) 
* This version: October 22, 2019
* Changes (07-26-18): calculations for GDP per capita, including changes to poverty calculations
* Changes (10-22-19): calculating relative costs of human capital investments versus physical capital investments to produce Figure 9 

* Paths are set in master.do — run master.do first to define globals
* Required globals: $root, $input, $output, $graphs, $do

* Installing customs modules (commented out unless needed)
*ssc install mmerge	

* Setting the parameters for the model
scalar alpha    = 1/3						// Cobb-Douglas factor share for capital 
scalar pgr      = .013					    // This is the growth rate of productivity
scalar delta    = .05						// Depreciation rate of capital 
scalar phi      = 0.08						// Mincerian return to education
scalar endyear  = 2100						// Last year we want the simulation to run to 
scalar ys_max   = 12						// Set max for years of schooling
scalar adys_max = 12						// Set max for quality adjusted years of schooling

* New parameters for this .do file
scalar discount  = 0.04						// Discount rate of the future
scalar increment = .001						// How much we want to raise the investment rate each iteration of the search for an equivalent pv

* Clearing matrices
clear matrix

* First we get the initial investment rate so we can set the lower bound of the loop
use "$output\human_capital_2015.dta", clear
keep wbcode gcf
duplicates drop 
rename      gcf gcf_initial
tempfile    gcf
save       `gcf', replace

* Start by retrieving just NPVs for each scenario for each country 
use "$output/hc_projections.dta", clear						

* Generate NPV of each GDP per capita `flow' at the 5 year mark
foreach scenario in baseline sc4 sc5 {
	gen pv_gdppc_`scenario' = gdppc_`scenario' / (1 + discount)^(year - 2015)	// Calculating discounted flows which take place every five years (we will not be interplolating in between observed periods)
}
keep if year > 2015 & year <= endyear											// 2015 is year 0 so we drop if from the PV calculation

* Now summing up the PV of all flows until the year we care about
collapse (sum) pv_gdppc_* (first) wbcountryname, by(wbcode)						// Collapsing to get the total PV of gdppc flows over the period 2020-2100

* Merging in original GCF info
mmerge wbcode using `gcf', unmatched(master) type(1:1)						

* Saving so we can use for running through different investment rates
tempfile pv
save    `pv'

* Grabbing full list of countries in our sample - we're going to cycle over this
levelsof wbcode, local(country)

foreach c in `country' {														// Cycling over countries 
preserve																		// Preserving as we are going to return to this data each time we loop over countries
	* Loop starts here
	keep if wbcode == "`c'"														

	foreach scenario in sc4 sc5 {
		scalar pv_`scenario' = pv_gdppc_`scenario'[1]							// Loading a scalar with the pv with both the typical and optimistic scenarios
	}

	scalar gcf_lowerbound  = gcf_initial[1]      
	local  gcf_lowerbound  = gcf_initial[1]
	local  step 		   = increment

	

	* Starting a while loop: as long as the chosen level of investment produces a PV for 2020-2100 which is lower than that of the optimistic scenario, we are going to continue looping
	local g = `gcf_lowerbound' 													// Starting with the existing level of investment
	local diff = -1 
	while `diff' < 0 {															

		local g = `g' + `step'													// Move the investment rate up by .01 percentage points
		
		 qui {
		 
		 
			***************************************************************************
			* Now we start up a new simulation exercise using the new investment rate *
			***************************************************************************
			* Creating frame
			use "$output\human_capital_2015.dta", clear
			keep wbcode age_bin
			local  ts = (endyear - 2015)/5 + 1
			expand `ts'
			bys wbcode age_bin: gen year = (2010 + 5*_n) 

			* Keep working age population
			keep if age_bin >=20 & age_bin <=60

			* Merge in population bin data
			mmerge wbcode year age_bin  using "$output/population_bins.dta", type(1:1) unmatched(master) umatch(iso3c year age_bin)

			* Merging in starting values of capital, human capital, GDP
			mmerge wbcode year age_bin using "$output\human_capital_2015.dta", type(1:1) unmatched(master) umatch(wbcode year age_bin)

			* We will only use the population level data for now, so drop female and male-specific estimates
			drop *FEMALE *MALE

			* Calculating age-bin aggregate human capital at T0
			gen a_hc = pop_BOTH * hc_BOTH										// Which is the total pop for the age bin X the average HC for that age bin								

			keep if wbcode == "`c'" 											// We will just do this for one country at a time

			

			*****************************************
			* STEP 1: Age-bin specific calculations *
			*****************************************

			* *	* SIMULATION SCENARIO : The investment rate immediately moves by a X% incriment. HCI remains constant
			gen     gcf_investment   = gcf[1]
			replace gcf_investment	 = `g'

			gen ys_BOTH_investment   = ys_BOTH
			gen qual_BOTH_investment = qual_BOTH
			gen hch_BOTH_investment  = hch_BOTH 

			* We're doing this in a less complicated way than the previous version: we're just using the [_n] function to grab earlier values. 
			* Note that these will need to be adjusted if we decide upon a differnet number of age-bins
			local ey = endyear 
			sort wbcode year age_bin 
			forvalues t = 2020(5)`ey' {																			           // Cycling over subsequent years
					bys wbcode: replace ys_BOTH_investment   = ys_BOTH_investment[_n-9]   if age_bin == 20  & year == `t'  // Each new 20-24 cohort takes on the educational attainment of the previous 20-24 cohort (
					bys wbcode: replace ys_BOTH_investment   = ys_BOTH_investment[_n-10]  if age_bin >  20 & year == `t'   // Every other cohort moves `forward' in time, carrying forward its education attainment
					
					bys wbcode: replace hch_BOTH_investment  = hch_BOTH_investment[_n-9]  if year == `t' 				   // Human Capital from health remains constant
					bys wbcode: replace qual_BOTH_investment = qual_BOTH_investment[_n-9] if year == `t' 				   // Education quality remains constant
			}
				
			gen adye_BOTH_investment = ys_BOTH_investment * qual_BOTH_investment					// Generating new adjusted years of schooling
			gen hce_BOTH_investment  = exp(phi*(min(adye_BOTH_investment,adys_max)-adys_max))		// Generating new human capital from education (note we are capping adjusted years of schooling at 12)
			gen hc_BOTH_investment   = hch_BOTH_investment * hce_BOTH_investment 				    // Generating new human capital under constant scenario
			gen a_hc_investment      = pop_BOTH * hc_BOTH_investment								// Generating total human capital per age bin under constant scenario							


			*****************************************************************************
			* STEP 2: Collapsing to country-year level and making final HC calculations *
			*****************************************************************************

			* Summing up total human capital
			collapse (sum) pop_BOTH a_hc* (first) wbcountryname ck gcf* gini pov* gdp Incomegroup Lendingcategory Region, by(wbcode year)	// This gives us total working population for each country year and total HC for that country year

			gen hcpw_investment = a_hc_investment / pop_BOTH

			* Bringing in total population numbers 
			mmerge wbcode year using "$output/total_population.dta", umatch(iso3c year) type(1:1) unmatched(master)


			*******************************************
			* STEP 3: Calculating productivity growth *
			*******************************************
			*Generating year 0 productivity 
			gen gdppw = gdp  / pop_BOTH											 if year == 2015	 // GDP per worker
			gen hcpw  = a_hc / pop_BOTH											 if year == 2015	 // HC  per worker
			gen kpw   = ck   / pop_BOTH											 if year == 2015	 // K   per worker 
			gen a     = gdppw / ( ((kpw)^(alpha))*((hcpw_investment)^(1-alpha))) if year == 2015	 // Year 0 productivity

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
			gen sigma = invnormal( ( gini + 1 )/2 ) * sqrt(2) 
			bys wbcode: replace sigma = sigma[1] if year > 2015								// We assume that the variance remains fixed

			* Final GDP and poverty calculations
			sort wbcode year 
			gen  ck_investment  = ck
			gen  kpw_investment = ck_investment / pop_BOTH								// Calculating capital per worker in the first period
			gen  pov_investment = pov													// Poverty rate
			gen  pov320_investment = pov320												// Poverty rate
			gen  pov550_investment = pov550												// Poverty rate

			* Rolling forward in five year intervals and using the secnario specific values of capital and human capital
			forvalues t = 2020(5)`ey' {
				bys wbcode: replace kpw_investment = 	(pop_BOTH[_n-1]/pop_BOTH)*( kpw_investment[_n-1] + 5 * (gcf_investment[_n-1] * a[_n-1] * (kpw_investment[_n-1]^(alpha))*(hcpw_investment[_n-1]^(1-alpha)) - delta * kpw_investment[_n-1]) ) if year == `t'
			}

			* Generating GDP per worker
			gen     gdppw_investment = a * (kpw_investment^(alpha))*(hcpw_investment^(1-alpha))
			
			
			* Calculating GDP per capita
			gen    gdppc_investment =  gdppw_investment * (total_working/total_pop)		// GDP per capita is defined as GDP per worker X the working age fraction 
			
			* Generating poverty rate and poverty rate relative to baseline
			foreach p in pov pov320 pov550 {
				bys wbcode: replace `p'_investment   = normal(invnormal(`p'[1]) - (1/sigma)* ln((gdppc_investment)/(gdppc_investment[1]))) if year > 2015  // Note that [1] indicates the value in year 0 for that country
			}
				
			*****************************************************
			* Calculting PVs under hypothetical investment rate *
			*****************************************************
			gen pv_gdppc_investment = gdppc_investment / (1 + discount)^(year - 2015)
			keep if year > 2015 & year <= endyear
			collapse (sum) pv_gdppc_investment (first) gcf_investment

			scalar inv = gcf_investment[1]
			foreach scenario in sc4 sc5 {
				scalar d_`scenario' = abs(pv_gdppc_investment - pv_`scenario')
			}
			
			* Calculating difference between PV under hypothetical investment rate and the optimistic scenario
			local diff = pv_gdppc_investment - pv_sc5							// If it is positive, we will exit the loop and save the results
			
			* Dropping latest investment rate and PVs into a matrix 
			mat `c' = (nullmat(`c')\ inv,d_sc4,d_sc5)
		}
			di "Iteration `g' for `c'"
			di `diff'
			
		
		
	}

	* Loading results from matrix, finding the investment rate that minimizes the difference between PVs, and saving it a scalar
	clear
	svmat `c'
	rename `c'1 gcf
	rename `c'2 sc4
	rename `c'3 sc5
	gen rank = _n
	foreach scenario in sc4 sc5 {
		sort `scenario'
		scalar g_`c'_`scenario' = gcf[1]
	}

restore
}


* Now we load in the chosen GCFs which replicate the same NPV values
gen gcf_sc4 = . 																// Creating empty value for typical scenario
gen gcf_sc5 = . 																// Creating empty value for optimistic scenario
levelsof wbcode, local(country)
foreach c in `country' {														// Looping over countries
	foreach scenario in sc4 sc5 {
		replace gcf_`scenario' = g_`c'_`scenario' if wbcode == "`c'"			// Filling in the chosen GCF from what was produced from the loop
	}
}

save "$output/gcf_pv.dta", replace

*********************
* Additional graphs *
*********************

* Producing new graph showing how these GCFs change according to income
use "$output/hc_projections.dta", clear
keep if year == 2015
tempfile i 
save    `i', replace 

use "$output/gcf_pv.dta", clear
mmerge wbcode using 		`i'								 , ukeep(gdppc_constant)        // Bringing in starting levels of gdp
mmerge wbcode 	      using "$output/country_categories.dta" , type(1:1) unmatched(master)  // WB Country Categories

gen diff_sc4 = (gcf_sc4 - gcf_initial) * 100
gen diff_sc5 = (gcf_sc5 - gcf_initial) * 100

* How does the health and education calculus change? 
preserve
	* Using 2019-vintage World Bank data (health & education expenditure as % of GDP)
	* Source: WDI Database Archives (db=57), version 201912
	* Original indicators: se.xpd.totl.gd.zs, sh.xpd.chex.gd.zs
	use "$input/wb_health_education_expenditure_2019vintage.dta", clear

	sort countrycode year
	forvalues y = 2000/2018 {
		foreach var of varlist educ_gdp health_gdp {
			bys countrycode: replace `var' = `var'[_n-1] if `var' == . & year == `y'	// Imputing most recent value from earlier values
		}
	}
	keep if year == 2018
	tempfile eh
	save    `eh', replace
restore 

gen age_bin = 20
mmerge wbcode         using `eh'	   							   , umatch(countrycode) ukeep(educ health)  unmatched(master) // Bringing in cost of health and educatoin
mmerge wbcode age_bin using "$output\human_capital_2015.dta",                     ukeep(hc_BOTH)      unmatched(master) // Bringing in starting levels of human capital
drop age_bin
gen cost_hci = hc_BOTH/(educ_gdp + health_gdp)

preserve
	do "$do/2.1 (background) scenario.do" 								// Re-calculating the `typical' scenario
restore
di hci_gap_5rate_50 

* Calculating the change in HCI driven by running each scenario forward 5 years
* and then the cost in terms of GDP, assuming constant returns
gen change_hci_50_per = (hci_gap_5rate_50*(1-hc_BOTH))/hc_BOTH
gen change_hci_75_per = (hci_gap_5rate_75*(1-hc_BOTH))/hc_BOTH
gen cost_50           = change_hci_50_per  * (educ_gdp + health_gdp)
gen cost_75           = change_hci_75_per  * (educ_gdp + health_gdp)



* Producing scatterplot comparing costs (Figure 9a)
gen y = diff_sc4
sum cost_50
local k = `r(max)'
twoway (scatter cost_50 diff_sc4, mcolor(black%80) msymbol(none) mlabel(wbcode) mlabcolor(black%80) mlabposition(0)) 							///
	   (function y=x, range(0 `k') lcolor(black)),						///
	   text(1.07 0.35 "45 degree line", place(e) size(small))	///
       ytitle(Extra human capital investment (% of GDP))    ///
	   xtitle(Extra physical capital investment (% of GDP)) ///
	   graphregion(fcolor(white) lcolor(white)) legend(off)
gr export "$graphs/cost_corr50.png", as(png) width(3000) replace	
gr export "$graphs/cost_corr50.eps", as(eps) replace	

 
sum cost_75
local k = `r(max)'
twoway (scatter cost_75 diff_sc5, mlabcolor(black%80)  msymbol(none) mlabel(wbcode) mlabposition(0)) 							///
	   (function y=x, range(0 `k') lcolor(black)),						///
	   text(2.8 1 "45 degree line", place(e) size(small))	///
       ytitle(Extra human capital investment (% of GDP))    ///
	   xtitle(Extra physical capital investment (% of GDP)) ///
	   graphregion(fcolor(white) lcolor(white)) legend(off)
 gr export "$graphs/cost_corr75.png", as(png) width(3000) replace	
 gr export "$graphs/cost_corr75.eps", as(eps)  replace

* Producing scatterplot comparing ratio of costs by starting GDP per capita
gen ratio_50 = diff_sc4 / cost_50
gen ratio_75 = diff_sc5 / cost_75
  
twoway (scatter ratio_50 gdppc_constant, mcolor(black%80) msymbol(none) mlabel(wbcode) mlabcolor(black%80) mlabposition(0)) ///
       , ytitle(Ratio of required physical capital investment to human capital) ytitle(, size(small))                   ///
	     xtitle(Log(GDP per capita) (2015)) xscale(log) xlabel(1000 "1,000" 10000 "10,000" 100000 "100,000")            ///
		 graphregion(fcolor(white) lcolor(white))  
gr export "$graphs/cost_ratio50.png", as(png) width(3000) replace	
gr export "$graphs/cost_ratio50.eps", as(eps)   replace	

 
twoway (scatter ratio_75 gdppc_constant, mcolor(black%80) msymbol(none) mlabel(wbcode) mlabcolor(black%80) mlabposition(0)) ///
       , ytitle(Ratio of required physical capital investment to human capital) ytitle(, size(small))                   ///
	     xtitle(Log(GDP per capita) (2015)) xscale(log) xlabel(1000 "1,000" 10000 "10,000" 100000 "100,000")            ///
		 graphregion(fcolor(white) lcolor(white)) 
gr export "$graphs/cost_ratio75.png", as(png) width(3000) replace	
gr export "$graphs/cost_ratio75.eps", as(eps) replace	


exit



