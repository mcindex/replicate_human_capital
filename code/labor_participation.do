* Pre-loading GDP results into a matrix
mat drop _all
use "$output/hc_projections.dta", clear
keep if year == 2050

sort wbcode
gen     id = _n
local cnum = _N
order id

foreach var of varlist gdppc_constant gdppc_sc1 gdppc_sc2 gdppc_sc3 {
	gen ln`var' = ln(`var')
}

*mkmat id gdppc_constant gdppc_sc1 gdppc_sc2 gdppc_sc3, matrix(gdp)
mkmat id lngdppc_constant lngdppc_sc1 lngdppc_sc2 lngdppc_sc3, matrix(lngdppc)

* Pre-loading labor force participation data
use "$input\data-2019-12-06.dta", clear			// ILO estimates

* Keeping the age-bands we care about
gen keep = 0 
gen band = ""
local c = 15
foreach band in 15-19 20-24 25-29 30-34 35-39 40-44 45-49 50-54 55-59 60-64 {
	replace keep = 1 		if class == "Age (5-year bands): `band'"
	replace band = "`c'"    if class == "Age (5-year bands): `band'"
	local c = `c' + 5
}
keep if keep
keep if sex == "Sex: Male" 
gen  iso = substr(source,1,3)

* Reshaping
rename obs_value lfp_
keep lfp_ iso band
reshape wide lfp_, i(iso) j(band) string
gen year = 2015

mmerge iso year using "$output/hc_projections.dta", type(1:1) unmatched(none) umatch(wbcode year) ukeep(gdppc_baseline)



* Create locals for added text 
local cnumb = rowsof(lngdppc)			// We are going to loop over each row of the matrix 
sort   gdppc
capture drop plfp*
global tadd = ""
gen lngdppc_baseline = ln(gdppc_baseline)
forvalues b = 15(5)60 {
	npregress kernel lfp_`b' lngdppc_baseline
	predict   plfp_`b'
	local a = `b' + 4
	local atext_`b' = "`b't`a'"
	local x_`b' = lngdppc[142]
	di   `x_`b''
	local y_`b' = plfp_`b'[142]
	di   `y_`b''
	lab var plfp_`b' "`b'-`a'"
	
	forvalues r = 1/`cnumb' {

		local gr = lngdppc[`r',2]
		local gr = min(100000,`gr')				// We cap at 110,000 as this is as high as the NPL predictions can go
		margins, at(lngdppc_baseline = `gr')
		mat lngdppc_constant_`b' = (nullmat(lngdppc_constant_`b') \ (`gr',r(b)) )
		
		local gr = lngdppc[`r',3]
		local gr = min(110000,`gr')				// We cap at 110,000 as this is as high as the NPL predictions can go
		margins, at(lngdppc_baseline = `gr')
		mat lngdppc_sc1_`b' = (nullmat(lngdppc_sc1_`b') \ r(b) )
		
		local gr = lngdppc[`r',4]
		local gr = min(110000,`gr')				// We cap at 110,000 as this is as high as the NPL predictions can go
		margins, at(lngdppc_baseline = `gr')
		mat lngdppc_sc2_`b' = (nullmat(lngdppc_sc2_`b') \ r(b) )
		
		local gr = lngdppc[`r',5]
		local gr = min(110000,`gr')				// We cap at 110,000 as this is as high as the NPL predictions can go
		margins, at(lngdppc_baseline = `gr')
		mat lngdppc_sc3_`b' = (nullmat(lngdppc_sc3_`b') \ r(b) )
		
	}
}

forvalues b = 15(5)60 {
	local a = `b' + 4
	local atext_`b' = "`b'-`a'"
}

twoway (line plfp_20 lngdppc, lcolor(black)  lpattern(dash)) ///
	   (line plfp_25 lngdppc, lcolor(black)  lpattern(vshortdash)) ///
	   (line plfp_30 lngdppc, lcolor(black)  				) ///
	   (line plfp_35 lngdppc, lcolor(black) lpattern(longdash_dot)) ///
	   (line plfp_40 lngdppc, lcolor(gs7)   lpattern(dash)) ///
	   (line plfp_45 lngdppc, lcolor(gs7)   lpattern(vshortdash)	) ///
	   (line plfp_50 lngdppc , lcolor(gs7) 	) ///
	   (line plfp_55 lngdppc,  lcolor(gs7)   lpattern(longdash_dot)	) ///
	   (line plfp_60 lngdppc,  lcolor(black) lwidth(thick)  lpattern(dot)	) ///
	   , xlabel(6.9 "1,000" 9.2 "10,000" 11.5 "100,000") ///
		 ytitle(Labor force participation (percent)) ///
		 text(`y_20' `x_20'  "`atext_20'" , place(e) size(vsmall)) ///
		 text(`y_25' `x_25'  "`atext_25'" , place(e) size(vsmall)) ///
		 text(`y_30' `x_30'  "`atext_30'" , place(e) size(vsmall)) ///
		 text(`y_35' `x_35'  "`atext_35'" , place(e) size(vsmall)) ///
		 text(`y_40' `x_40'  "`atext_40'" , place(e) size(vsmall)) ///
		 text(`y_45' `x_45'  "`atext_45'" , place(e) size(vsmall)) ///
		 text(`y_50' `x_50'  "`atext_50'" , place(e) size(vsmall)) ///
		 text(`y_55' `x_55'  "`atext_55'" , place(e) size(vsmall)) ///
		 text(`y_60' `x_60'  "`atext_60'" , place(e) size(vsmall)) ///
		 xtitle(Log(GDP per capita) (2015)) ///
		 graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) scheme(modern)
graph play "$do\lastgraph.grec"
gr export "$graphs/lfp.png", as(png) width(2500) replace
gr export "$graphs/lfp.eps", as(eps) replace

		


* Recreating full matrix with all predicted values and dumping results into a dataset 
clear
forvalues b = 15(5)60{
	clear
	mat lngdppc_plus_`b' = (lngdppc, lngdppc_constant_`b' , lngdppc_sc1_`b' , lngdppc_sc2_`b' , lngdppc_sc3_`b')
	svmat lngdppc_plus_`b'
	rename lngdppc_plus_`b'1 id 
	drop   lngdppc_plus_`b'3-lngdppc_plus_`b'6
	rename lngdppc_plus_`b'7  constant_`b'
	rename lngdppc_plus_`b'8  sc1_`b'
	rename lngdppc_plus_`b'9  sc2_`b'
	rename lngdppc_plus_`b'10 sc3_`b'
	tempfile m`b'
	save    `m`b'', replace
}
use `m15', clear 
forvalues b = 20(5) 60 {
	mmerge id using `m`b'', type(1:1) 
}


* Saving results
save "$output/predicted_participation.dta", replace


* Loading in country codes, etc
use "$output/hc_projections.dta", clear
keep if year == 2050
sort wbcode
gen     id = _n

mmerge id using "$output/predicted_participation.dta", type(1:1) 
gen lngdppc_constant = ln(gdppc_constant)
assert lngdppc_constant == lngdppc_plus_152	// Making sure the merge is true 
tempfile k 
save    `k', replace
keep wbcode constant* sc*
reshape long constant_ sc1_ sc2_ sc3_, i(wbcode) j(agebin)

* Formatting to bound at 0 - 1 
foreach var of varlist constant sc1 sc2 sc3 {
	replace `var' = 0   if `var' < 0 
	replace `var' = 100 if `var' > 100 & `var' != . 
	replace `var' = `var' / 100 						// Converting to fractions
}
tempfile a
save    `a', replace

use "$output/hcpw_projections.dta", clear 
keep if year == 2050
keep wbcode age_bin a_hc*
mmerge wbcode age_bin using `a', type(1:1) umatch(wbcode agebin) unmatched(master)

foreach spec in constant sc1 sc2 sc3 {
	gen a_hc_`spec'_adjust = a_hc_constant * `spec'_
}

collapse (sum) a_hc_*, by(wbcode)

foreach spec in sc1 sc2 sc3 {
	gen ratio_`spec' = a_hc_`spec'_adjust / a_hc_constant_adjust
}


mmerge wbcode using `k', ukeep(lngdppc_constant)
 
twoway (scatter ratio_sc1 lngdppc_constant, mcolor(none) mlabel(wbcode) mlabcolor(black) mlabposition(0)), ytitle(Ratio of LF-adjusted human capital (typical over baseline)) xtitle(GDP per capita in 2015) xlabel(6.907 "1,000" 9.21 "10,000" 11.51 "100,000") scheme(modern) scale(0.9)
gr export "$graphs/lfp_2.png", as(png) width(2500) replace
gr export "$graphs/lfp_2.eps", as(eps) replace


exit

* NOTE: Code below is unfinished scratch work from the original replication package.
* It attempts to predict LFP at projected GDP levels but never stores npregress estimates
* and doesn't produce any output. The two figures (10 & 11) are exported above.

* Now loading GDP results and using margins command to predict levels of labor force participation for each group
use "$output/hc_projections.dta", clear 
keep if year == 2050
local e = _N

foreach scenario in constant sc1 sc2 sc3 {
	forvalues b = 15(5)60 {
		gen plfp_`b' = . 
		est restore np`b'
		estimates esample:
		forvalues i = 1/`e' {
			local k = gdppc_`scenario'[`i']
			margins, at(gdppc_baseline = `k')
		}
		
	}

}

		 





exit





keep iso lfp* lngdp
gen year = 9999
tempfile lf
save    `lf', replace

	
* Loading HCI simulation projections
use "$output/hc_projections.dta", clear 

keep wbcode year hcpw* gdppc*
keep if year == 2050
append using `lf'


gen lngdppc = . 
foreach s in baseline sc1 sc2 sc3 {
	replace lngdppc = ln(gdppc_`s')
	forvalues ag = 15(5)60 {
		preserve
			use `lf', clear
			npregress kernel lfp_`ag' lngdp
		restore
		predict plfp_`ag'_`s'
	}
}





* Preloading 2015 GDP per capita
use "$output/hc_projections.dta", clear 


use "$input/data-2019-12-06.dta", clear

* Keeping the age-bands we care about
gen keep = 0 
gen band = ""
local c = 15
foreach band in 15-19 20-24 25-29 30-34 35-39 40-44 45-49 50-54 55-59 60-64 {
	replace keep = 1 		if class == "Age (5-year bands): `band'"
	replace band = "`c'" if class == "Age (5-year bands): `band'"
	local c = `c' + 5
}
keep if keep
keep if sex == "Sex: Male" 
gen  iso = substr(source,1,3)

* Reshaping
rename obs_value lfp_
keep lfp_ iso band
reshape wide lfp_, i(iso) j(band) string
gen year = 2015

mmerge iso year using "$output/hc_projections.dta", type(1:1) unmatched(none) umatch(wbcode year) ukeep(gdppc_baseline)


		 
		 ///		 
		 text(`x_15' `y_15' "`atext_15'", place(e))  ///
		 text(`x_20' `y_20' "`atext_20'", place(e))  ///
		 text(`x_25' `y_25' "`atext_25'", place(e))  ///
		 text(`x_30' `y_30' "`atext_30'", place(e))  ///
		 text(`x_35' `y_35' "`atext_35'", place(e))  ///
		 text(`x_40' `y_40' "`atext_40'", place(e))  ///
		 text(`x_45' `y_45' "`atext_45'", place(e))  ///
		 text(`x_50' `y_50' "`atext_50'", place(e))  ///
		 text(`x_55' `y_55' "`atext_55'", place(e))  ///
		 text(`x_60' `y_60' "`atext_60'", place(e)) 
