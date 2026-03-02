* This .do file prepares data used analysis for the paper:
* "The Effect of Increasing Human Capital Investment on Economic Growth and Poverty: A Simulation Exercise"
* It is (1/6) of the main .do files in this project. There are two background .do files as well. 

* Author: Matt Collin (mcollin@brookings.edu) 
* This version: October 22, 2019
* Changes (091018): including updated data from the HCI as of the HCP release
* Changes (091018): including updated data from the HCI and raised quality threshold from 600 to 625
* Changes (072318): including IHME's estimates for years of schooling
* Changes (061618): using new WB poverty numbers as of August 2018
* Changes (082219): Added the ability to include tertiary education (set local tertiary = yes) for robustness check

* Paths are set in master.do — run master.do first to define globals
* Required globals: $root, $input, $output, $graphs, $do


* Installing customs modules (commented out unless needed)
*ssc install mmerge	
*ssc install kountry
*ssc install texresults

* *	* *	* * Assumptions/adjustments in this version:

* (1) If there is no sex-specific quality measure, both sexes have the same quality
* (2) A give cohort has the same educational attainment in 2015 as they did in 2010
* (3) Those aged 20 in 2015 have the same educational attainment as those who were 20 in 2010
* (4) When there is no sex-specific stunting measure, both sexes have the same value
* (5) If a country has years of schooling OR quality adjusted years of schooling average greater than 12, then we cap it at 12
* (6) Threshold for high qualty education is now 625

* * * * * * Parameters
scalar phi 			   = 0.08								// The Mincerian return to education
scalar gam_height_mid  = 0.034								// Returns from height
scalar beta_height_asr = 19.2								// Response of height to asr
scalar beta_height_stu = 10.2								// Response of height to notstunting 
scalar gam_asr_mid     = beta_height_asr * gam_height_mid	// Returns to improving ASR
scalar gam_stu_mid     = beta_height_stu * gam_height_mid	// Returns to improving stunting

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


* Include IHME data?
local include = "Yes"

***********************************************************************************************
* Step 1: Bringing in population estimates from World Population Prospects: The 2017 Revision *
***********************************************************************************************

* Looping over files, cleaning up and assembling combined file with sex-disaggregated population data
local i = 2																		// This indicator cycles over filenames
foreach gender in MALE FEMALE {													// Looping over make and female 

	* Projections 
	import excel "$input\WPP2017_POP_F07_`i'_POPULATION_BY_AGE_`gender'.xlsx", sheet("MEDIUM VARIANT") cellrange(C17:AA4355) firstrow clear
	
	* Cleaning up the Excel file
	local b = 0 
	foreach var of varlist G-AA {
		rename `var' pop_`gender'`b'
		local b = `b' + 5
	}	
	tempfile e
	save    `e', replace
		
	drop if Countrycode >= 900													// Dropping regions
	rename Reference year
	keep Region Countrycode pop_`gender'0-pop_`gender'100 year					// Keeping cohorts we care about
	tempfile p_`gender'
	save    `p_`gender'', replace												// Saving for later
	local i = `i' + 1															// Cycling over filenames
}

* Merging the male, female and combined files 
use `p_MALE', clear
mmerge Countrycode year using `p_FEMALE', type(1:1) 
assert _merge == 3									
drop   _merge 
forvalues b = 0(5)100 {															// Looping over cohorts
	gen pop_BOTH`b' = pop_MALE`b' + pop_FEMALE`b'
	replace pop_BOTH`b'   = pop_BOTH`b'   * 1000								// Converting to full values (rather than 1000s)
	replace pop_MALE`b'   = pop_MALE`b'   * 1000
	replace pop_FEMALE`b' = pop_FEMALE`b' * 1000
}

* Cleaning up country codes
replace Region = "Macedonia"  		if Region == "TFYR Macedonia"
replace Region = "Micronesia"  		if Region == "Micronesia (Fed. States of)"
replace Region = "Curacao"     		if Region == "Curaçao"
replace Region = "Reunion"     		if Region == "Réunion"
replace Region = "Macao"       		if Region == "China, Macao SAR"
replace Region = "North Korea" 		if Region == "Dem. People's Republic of Korea"
replace Region = "Hong Kong"   		if Region == "China, Hong Kong SAR"
replace Region = "Palestine"   		if Region == "State of Palestine" 
replace Region = "Czech Republic"   if Region == "Czechia" 
replace Region = "Taiwan"   		if Region == "China, Taiwan Province of China" 
replace Region = "Cape Verde"       if Region == "Cabo Verde"
replace Region = "Bolivia"          if Region == "Bolivia (Plurinational State of)"
replace Region = "Cote d'Ivoire"    if Region == "Côte d'Ivoire"
replace Region = "Venezuela"        if Region == "Venezuela (Bolivarian Republic of)"
drop 					     		if Region == "Channel Islands"
kountry Region, from(other) stuck
rename _ISO3N_ numcode2
kountry numcode2, from(iso3n) to(iso3c) m
drop numcode2 NAMES_STD MARKER
rename _ISO3C_ iso3c
replace 	   iso3c = "CUW" 		 if Region == "Curaçao" | Region == "Curacao"
assert         iso3c != ""
drop Region Country

* Reshaping to a long file
reshape long pop_MALE pop_FEMALE pop_BOTH, i(iso3c year) j(age_bin)

* Saving - both across all projection years and just for 2015
save "$output/population_bins.dta"	   , replace 

* Saving overal population totals and dependency ratios for country years
preserve
	gen total_working = pop_BOTH if age_bin >= 20 & age_bin <= 60 
	collapse (sum) pop_BOTH total_working, by(iso3c year)
	rename         pop_BOTH total_pop
	save "$output/total_population.dta", replace
restore

keep if year == 2015
save "$output/population_bins_2015.dta", replace 								

***********************************************************************************
* Step 2: Grabbing quality adjusted years of schooling from Patrinos et al (2018) *
***********************************************************************************
use "$input\hlo_data_21Sept2018.dta", clear

* Generating quality adjustment factor (the test score divided by 625)
foreach g in mf f m {
	qui gen test_`g' = hlo_`g'_fill
	qui gen test_max_`g' = 625													// New threshold for "high quality" education - added 09/10/18
	qui gen qual_`g' = test_`g'/test_max_`g'
}

* Keeping the most recent available quality measure (or 2015, whichever comes first)
keep if qual_mf != . 
drop if year > 2015	| year == .													// Note there are some measurements from 2016 and 2017 
sort wbcode year
bys  wbcode: keep if _n == _N

* We assume each gender has the same quality if there is no gender disaggrated value
replace qual_f = qual_mf if qual_f == . 
replace qual_m = qual_mf if qual_m == . 

rename qual_mf qual_BOTH 
rename qual_m  qual_MALE
rename qual_f  qual_FEMALE
keep year wbcode qual*

save "$output/quality_2015.dta", replace


************************************************************************************************
* Step 3: Grabbing Barro and Lee schooling attainment data and supplementing it with IHME data *
************************************************************************************************
* Barro-Lee data
foreach g in MF F M {															// Cycling over combined, male and female
	use "$input/BL2013_`g'_v2.1.dta", clear
	if "`tertiary'" == "No" {
		gen ys_`g' = yr_sch_pri + yr_sch_sec									// Reconstructing average years as Primary + Secondary
	}
	else if  "`tertiary'" == "Yes" {											// If we decide to include tertiary
		gen ys_`g' = yr_sch_pri + yr_sch_sec + yr_sch_ter						// then we include tertiary
	}
	drop if ageto == 999														// Dropping open cohorts
	keep WBcode year agefrom ys_`g'
	keep if year == 2010														// We are interested in the last value (2010)
	sort WBcode agefrom
	bys WBcode: replace ys_`g' = ys_`g'[_n+1] if agefrom == 15 					// Assumption (3): Those who were aged 15 in 2010 are assumed to have the education of those aged 20 in 2010 
	tempfile y`g'
	save    `y`g'', replace
}

* Merging male, female and combined together	
use `yMF', clear
mmerge WBcode year agefrom using `yM'
mmerge WBcode year agefrom using `yF'

* This is the educational attainment of each cohort in 2010. 
* Now we will `age' each cohort by 5 years, keeping the same level of attainment
gen     age_bin  = agefrom + 5													// Assumption (2)
drop if age_bin  < 20 
replace year     = year + 5
rename  ys_MF ys_BOTH
rename  ys_M  ys_MALE
rename  ys_F  ys_FEMALE
keep    WBcode year age_bin ys*
foreach g in BOTH MALE FEMALE {
	if      "`tertiary'" == "No" {
		label var ys_`g' "Average years of Primary + Secondary Schooling (`g')"
	}
	else if "`tertiary'" == "Yes" {
		label var ys_`g' "Average years of Primary + Secondary + Tertiary Schooling (`g')"
	}
	replace   ys_`g' = min(ys_max,ys_`g')										// Capping the maximum years of schooling
}

save "$output/schooling_2015`fname'.dta", replace


* IHME data
import delimited "$input\IHME_GBD_2016_COVARIATES_1980_2016_EDUCATION_YRS_PC_Y2017M09D05.csv", clear 
keep if age_group_id >= 8 &  age_group_id <= 17
keep if year_id == 2010															// We are only keeping 2010 and will age it in the same way as Barro Lee
replace sex_label = "MALE"   if sex_label == "Males"
replace sex_label = "FEMALE" if sex_label == "Females"
rename val ys_
split age_group_name
destring age_group_name1, gen(age_bin)
drop if location_id == 4657														// There are duplicate values for Mexico - we will drop the second set

keep ys* location* year age_bin sex_label
reshape wide ys_, i(location_id location_name year age_bin) j(sex_label) string
kountry location_name, from(other) stuck
rename _ISO3N_ numcode2
kountry numcode2, from(iso3n) to(iso3c) m
drop numcode2 NAMES_STD MARKER
drop if _ISO3C == ""
rename  _ISO3C iso3c
keep           iso3c ys* age_bin

* Merging in population data so we can construct averages
gen year = 2015
mmerge iso3c year age_bin using "$output/population_bins.dta", type(1:1) unmatched(none) umatch(iso3c year age_bin)
gen ys_BOTH = ys_FEMALE * (pop_FEMALE/pop_BOTH) + ys_MALE * (pop_MALE/pop_BOTH) // Generating overall years of schooling, weighted by population


* Calculating conversion factors between IHME and Barro-Lee
save "$output/IHME_conversion.dta", replace										// Using this later to convert IHME years of schooling
preserve
	do "$do/1.1 (background) barrolee_ihme_conversion.do"
restore

replace     ys_BOTH = biyr1*ys_BOTH + biyr2*ys_BOTH^2 + bicons					// Converting to Barro-Lee (Pri-Tert)
if "`tertiary'" == "No" {														// If we are using tertiary we stop here, otherwise.... 
	replace ys_BOTH = blyr1*ys_BOTH + blyr2*ys_BOTH^2							// Converting to Barro-Lee (Pri-Sec)
}


sort iso3c year age_bin
foreach g in BOTH FEMALE MALE {
	bys  iso3c: replace ys_`g' = ys_`g'[_n+1] if age_bin == 15 					// Assumption (3): Those who were aged 15 in 2010 are assumed to have the education of those aged 20 in 2010 
}

* This is the educational attainment of each cohort in 2010. 
* Now we will `age' each cohort by 5 years, keeping the same level of attainment
replace age_bin  = age_bin + 5													// Ageing everyone
drop if age_bin  < 20 
drop _merge 

* We cap all education attainment at ten years
foreach g in BOTH FEMALE MALE {
	replace ys_`g' = min(ys_max,ys_`g')
}

save "$output/schooling_2015_IHME_new`fname'.dta", replace

	
***********************************************************
* Step 4: Adult survival rates and stunting *
***********************************************************
* ASR
use "$input\asr_data_21Sept2018.dta", clear
foreach g in mf m f {
	gen asr_`g' = 1-mort_15to60_`g'_fill 										// Generating ASR
}

rename asr_mf asr_BOTH
rename asr_f  asr_FEMALE
rename asr_m  asr_MALE
keep   asr* wbcode year
save "$output/asr.dta", replace
keep if year == 2015
save "$output/asr_2015.dta", replace

* STUNTING
use "$input\stunting_data_21Sept2018.dta", clear
foreach g in mf m f {
	qui gen nostu_`g'=1-stunt_`g'_fill											// Generating proportion of children *not* stunting
}

rename  nostu_mf nostu_BOTH
rename  nostu_m  nostu_MALE
rename  nostu_f  nostu_FEMALE
replace nostu_MALE   = nostu_BOTH if nostu_MALE == . 							// Assumption (4): we fill male and female in with averages when they aren't available 
replace nostu_FEMALE = nostu_BOTH if nostu_FEMALE == . 
keep   nostu* wbcode year
save "$output/stunt.dta", replace
keep if year == 2015
save "$output/stunt_2015.dta", replace


****************************
* Step 5:  Investment Rate * 
****************************
* We use gross capital formation as a % of gdp 
import excel "$input\gross_capital_formation_0718.xls", sheet("Data") firstrow clear
local y = 1960 
foreach var of varlist E-BJ {
	rename `var' gcf`y'
	local y = `y' + 1
}
reshape long gcf, i(CountryCode) j(year)
keep if year >= 2006 & year <=2015												// We will use the average between 2006 and 2015
collapse (mean) gcf, by(CountryCode)											// Note that if a country has missing values for any years in this period, we'll be using whatever values are available for the average
replace         gcf = gcf / 100
save  "$output/gcf.dta", replace 

***********************************
* Step 6:  Physical capital stock * 
***********************************
use "$input\pwt90.dta", clear
*gen r = rgdpe/cgdpe
*replace ck = r*ck
keep if year == 2014
replace year =  2015															// We are using 2014 values for 2015
keep countrycode year ck
replace ck = ck * 1000000														// Converting capital stock to full value
save "$output/pwt.dta", replace
 
*******************************************
* Step 7:  GDP 2015 (constant 2011 $ ppp) * 
*******************************************
import excel "$input\gdp_constant_ppp.xls", sheet("Data") firstrow clear
local y = 1960 
foreach var of varlist E-BJ {
	rename `var' gdp`y'
	local y = `y' + 1
}
reshape long gdp, i(CountryCode) j(year)
keep if year == 2015															// We will use the value for 2015
keep year gdp CountryCode
save  "$output/gdp.dta", replace 

***************************************************
* Steps 8 and 9 a:  Poverty and Gini coefficients *
***************************************************
foreach k in "1.9" "3.2" "5.5" {												// Cycling over the three poverty lines

	import excel "$input\2015 line up.xlsx", sheet("`k'") firstrow clear
	duplicates drop

	* First we need to sum up the estimates that are weighted sums of subpopulations
	gen l = ""
	foreach c in India China Indonesia {
		replace l = "R"       if Country == "`c'--Rural"
		replace l = "U"       if Country == "`c'--Urban"
		replace l = "W"       if Country == "`c'*"
		replace Country = "`c'" if Country == "`c'--Rural"
		replace Country = "`c'" if Country == "`c'--Urban"
		replace Country = "`c'" if Country == "`c'*"

	}
	destring Gini, gen(gini) force
	gen ws = Survey == "Weighted sum"
	bys Country: egen ews = max(ws)
	bys Country: replace gini = (gini[2]*Population[2])/Population[1] + (gini[3]*Population[3])/Population[1] if Survey == "Weighted sum"
	gen 	sy = Survey
	replace sy = "2015" if sy == "Weighted sum"

	* For the interpolated estimates we need to repeat the same interpolation exercise for the Gini coefficient
	replace sy = "2015" if sy == "Interpolated"
	destring sy, gen(y)
	bys Country: ipolate gini y, gen(gini2)
	bys Country: keep if _n ==1
	keep Country Headcount gini2
	rename Headcount pov
	rename gini gini

	* Fixing Country codes
	replace Country = "Argentina"  if Country == "Argentina--Urban"
	replace Country = "Egypt" 	   if Country =="Egypt, Arab Republic of"
	replace Country = "Macedonia"  if Country == "Macedonia, former Yugoslav Republic of"
	replace Country = "Venezuela"  if Country == "Venezuela, Republica Bolivariana de"
	replace Country = "Yemen" 	   if Country == "Yemen, Republic of"
	replace Country = "Cape Verde" if Country == "Cabo Verde"
	kountry Country, from(other) stuck
	rename _ISO3N_ numcode2
	kountry numcode2, from(iso3n) to(iso3c) m
	drop numcode2 NAMES_STD MARKER
	rename _ISO3C_ iso3c
	replace iso3 = "XKX" if Country == "Kosovo"
	drop                 if Country == "Eswatini"
	assert  iso3 != ""

	* Rescaling
	replace pov  = pov/100
	replace gini = gini/100 

	*Renaming
	if "`k'" == "3.2" {
		rename pov pov320
	}
	else if "`k'" == "5.5" {
			rename pov pov550
	}
		
	gen year = 2015
	
	save "$output/newpov`k'.dta", replace

}
	

 
**********************************************
* Step 10: World Bank Income Classifications *
********************************************** 
import excel "$input\CLASS.xls", sheet("List of economies") cellrange(C5:I225) firstrow clear	// Importing country categories as of June 2018
drop in 1
drop in 219
keep   Code Region Incomegroup Lendingcategory
rename Code wbcode 
assert      wbcode != ""
save "$output\country_categories.dta", replace


*****************************************************************************************************************
* Step 11: Creating master file  (WARNING - DO NOT RUN THIS SNIPPET BY ITSELF OR YOU WILL ALWAYS DROP IHME DATA *
*****************************************************************************************************************

* First we draw in the list of countries which are covered by the HCI 
use "$input/masterdata.dta", clear
keep if year == 2015

* Then we expand by 20 to give us ages 0-95
expand 20
bys wbcode: gen age_bin = (5*_n)-5


* Loading in data as of 2015
mmerge wbcode age_bin using "$output/population_bins_2015"		  , type(1:1) umatch(iso3 age_bin)   	unmatched(master)  			 // Population
mmerge wbcode year    using "$output/quality_2015"				  , type(n:1) 					     	unmatched(master)  			 // Quality
mmerge wbcode age_bin using "$output/schooling_2015`fname'"		  , type(n:1) umatch(WBcode age_bin) 	unmatched(master)  			 // Attainment
mmerge wbcode year    using "$output/stunt_2015"				  , type(n:1) 						 	unmatched(master)  			 // Stunting
mmerge wbcode year    using "$output/asr_2015"  				  , type(n:1) 							unmatched(master)  			 // Adult Survival Rates
mmerge wbcode         using "$output/gcf"       				  , type(n:1) umatch(CountryCode)	 	unmatched(master)  			 // Investment Rate
mmerge wbcode year    using "$output/pwt"       				  , type(n:1) umatch(countrycode year)  unmatched(master)  			 // Capital stock
mmerge wbcode year    using "$output/gdp"       				  , type(n:1) umatch(CountryCode year)  unmatched(master) 			 // GDP
mmerge wbcode year    using "$output/newpov1.9.dta"     		  , type(n:1) umatch(iso3 year)  		unmatched(master)  			 // Poverty headcount and Gini
mmerge wbcode year    using "$output/newpov3.2.dta"     		  , type(n:1) umatch(iso3 year)  		unmatched(master) ukeep(pov) // Poverty headcount 3.20
mmerge wbcode year    using "$output/newpov5.5.dta"     		  , type(n:1) umatch(iso3 year)  		unmatched(master) ukeep(pov) // Poverty headcount 5.50
mmerge wbcode 	      using "$output/country_categories.dta"      , type(n:1) 						    unmatched(master)  			 // WB Country Categories

* Loading in IHME data
if "`include'" == "Yes" {
	mmerge wbcode age_bin using "$output/schooling_2015_IHME_new`fname'", 	   			///
	type(n:1) umatch(iso3c age_bin) 	unmatched(master)  update 				// Attainment
}

* Generating Adjusted years of education and human capital from education 
foreach g in BOTH MALE FEMALE {
	gen adye_`g' = ys_`g' * qual_`g'	if ys_`g' != . & qual_`g' != .			 // Adjusted years of education is average years of schooling for cohort a X the quality adjustment
	gen hce_`g'  = exp(phi*(min(adye_`g',adys_max)-adys_max))	if adye_`g' !=.	 // Assumption (5) : a few countries have adjusted combined LAYS greater than 12, so we cap the value at 12 here 
}


* Generating human capital from health
foreach g in BOTH MALE FEMALE {
	gen hch_`g' = . 
	replace hch_`g' = exp( gam_asr_mid * (asr_`g' - 1 )) if nostu_`g' == . 
	replace hch_`g' = exp((gam_asr_mid * (asr_`g' - 1 ) + gam_stu_mid* (nostu_`g' -1 ))/2 ) if nostu_`g' != . 
}

* Total human capital for each age cohort
foreach g in BOTH MALE FEMALE {
	gen hc_`g' = hce_`g' * hch_`g' 
}


* Labelling
drop _merge
lab var age_bin "Age cohort"
lab var gdp     "GDP PPP (in constant 2011 $)"
lab var pov     "Poverty headcount ratio" 
lab var gini    "Gini coefficient"
foreach g in BOTH MALE FEMALE {
	lab var pop_`g'   "Population (`g')"
	lab var qual_`g'  "Education quality (`g')"
	lab var nostu_`g' "% of children not stunted (`g')"
	lab var asr_`g'   "Adult survival rate (`g')"
	lab var adye_`g'  "Adjusted years of schooling (`g')"
	lab var hce_`g'   "Human Capital from Education (`g')"
	lab var hch_`g'   "Human Capital from Health (`g')"
	lab var hc_`g'    "Human capital (`g')"
}

preserve
keep if age_bin == 20
gen dropper = 0 
foreach var of varlist qual_BOTH ys_BOTH ck gdp gcf asr_BOTH pov {
	gen missing_`var' = `var' == . 
}
foreach var of varlist qual_BOTH ys_BOTH ck gdp gcf asr_BOTH  {
	replace dropper = 1 if missing_`var' == 1
}
restore 

* Dropping those without critical inputs to our simulation
drop if qual_BOTH  == . 
drop if ys_BOTH    == . 
drop if ck         == .
drop if gdp        == . 
drop if gcf        == . 
drop if asr_BOTH   == . 


* *	* * * * *  Saving the file for T0 (2015) * 	* 	* 	* 	* 
save "$output\human_capital_2015`fname'.dta", replace
