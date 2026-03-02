* This .do file converts IHME's years of schooling, which include pre-primary through tertiary, 
* into Barro-Lee years of schooling, which for our purposes will only inlucde primary and secondary. 
* Author: Matt Collin (mcollin@brookings.edu) 
* This version: OCtober 10th, 2019


* Paths are set in master.do — run master.do first to define globals
* Required globals: $root, $input, $output, $graphs, $do


* Installing customs modules (commented out unless needed)
*ssc install mmerge	
*ssc install kountry

* We start with Barro-Lee data, and determine, on average, the relationship between (Primary + Secondary) and (Primary + Secondary + Tertiary)
use "$input/BL2013_MF_v2.1.dta", clear							// Loading Barro-Lee
format yr_sch %9.0g
drop if ageto == 999	
keep if agefrom >= 20 & agefrom <= 65											// We'll restrict the analysis to the working age population
keep if year == 2010															// For the most recent year we have available


* After looking at the scatter plot - quadratic seems to capture the relationship pretty well
* We supress the constant here as (Primary + Secondary) should equal (Primary + Secondary + Tertiary) at the origin. 
gen ys_MF   = yr_sch_pri + yr_sch_sec												
gen yr_sch2 = yr_sch^ 2
reg ys_MF yr_sch yr_sch2, nocons	
predict yhat 

* Capturing the conversion values
scalar blyr1 = _b[yr_sch]
scalar blyr2 = _b[yr_sch2]

* And graphing the relationhip between the two 
twoway (scatter ys_MF yr_sch , sort mcolor(black%20)  mlwidth(none))					///
	   (line yhat yr_sch, sort lcolor(gs14))													///
		, ytitle(BL years of schooling (Primary through Secondary))				///
		  xtitle(BL years of schooling (Primary through Tertiary)) 				///
		  subtitle("Barro-Lee (Pri-Tert) to Barro-Lee (Pri-Sec)")				///
		  name(bl, replace)														///
		  legend(off) graphregion(fcolor(white) lcolor(white))
		  
rename agefrom age_bin
tempfile bl 
save    `bl', replace

* Now we go through the same procedure, converting IHME (PrePrimary-Tertiary) years of schooling into Barro-Lee (Primary-Tertiary)
use "$output/IHME_conversion.dta", clear
mmerge iso3c age_bin using `bl', type(1:1) umatch(WBcode age_bin) 
drop yhat

* Again, quadratic fits well enough, although we no longer supress the constant (as IHME pre-primary can kick in at low levels)
gen ys_BOTH2 = ys_BOTH^2
reg yr_sch ys_BOTH ys_BOTH2												
predict yhat

* And graphing the relationship between the two
twoway (scatter yr_sch ys_BOTH , sort mcolor(black%20)  mlwidth(none))				///
	   (line yhat ys_BOTH, sort color(gs14))												///
		, ytitle(BL years of schooling (Primary through Tertiary))				///
		  xtitle(IHME years of schooling (Pre-primary through Tert)) 	    	///
		  subtitle("IHME to Barro-Lee")											///
		  name(ihme, replace)													///
		  legend(off) graphregion(fcolor(white) lcolor(white))

* Storing conversion values
scalar biyr1  = _b[ys_BOTH]
scalar biyr2  = _b[ys_BOTH2]
scalar bicons = _cons

* Combining both graphs into a single graph for the paper
graph combine ihme bl,   cols(2) note("Note: solid line indicates predicted values from quadratic regression")			 ///
				  ycommon   graphregion(fcolor(white) lcolor(white))

				  
	  
* Exporting for use in the paper
gr export "$graphs/barrolee_ihme.png", as(png) width(2500) replace	
gr export "$graphs/barrolee_ihme.eps", as(eps)  replace	
		
exit
