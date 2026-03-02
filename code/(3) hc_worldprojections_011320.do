* This .do file produces Figures 3, 4, 5, 6 and 7 for the paper
* "The Effect of Increasing Human Capital Investment on Economic Growth and Poverty: A Simulation Exercise"
* It is (3/6) of the .do files in this project. 
* .do file author: Matt Collin (mcollin@brookings.edu) 
* This version: October 22, 2019
* Changes (07-26-18): calculations for GDP per capita, including changes to poverty calculations
* Changes (10-22-19): Added in the option to calculate everything for tertiar
set scheme s2color, perm

* Parameters
scalar endyear = 2050		// Set the year you want the projections to run until (2065 is the latest you are allowed)

* Include tertiary education? (note, this will reset max for quality adjusted years of schooling)
local tertiary = "No" 
if "`tertiary'" == "Yes" {
	local fname = "ter"
}
else {
	local fname = ""
}

foreach cat in world developing lowincome ssa {									// We produces the same figures for the following sub-categories, which we cycle over 

	* Loading Projections file
	use "$output/hc_projections_102219`fname'.dta", clear								

	* Cutting down sample to category of countries we care about
	if "`cat'" == "world" {														// For world, we keep everything
		global cat "World"														// Defining labels for subsequent graphs
	}
	else if "`cat'" == "developing" {											// Keeping only low and lower middle income countries
		keep if Incomegroup != "High income" & Incomegroup != "Upper middle income"	
		global cat "Low and Lower-Middle Income Countries"
	}
	else if "`cat'" == "lowincome" {											// Low income countries
		keep if Incomegroup == "Low income"	
		global cat "Low Income Countries"
	}
	else if "`cat'" == "ssa" {													// Sub-Saharan Africa
		keep if Region == "Sub-Saharan Africa"	
		global cat "Sub-Saharan Africa"
	}
		
		
	* Keeping to the timeframe specified 
	keep if year <= endyear
	
	*keep if wbcountryname == "Morocco" | wbcountryname == "Zambia"

	* We're going to calculate Total GDP and total poor under the three scenarios
	foreach scenario in constant sc1 sc2 sc3 {
		gen gdp_`scenario '    = gdppw_`scenario'  * total_working
		gen poor_`scenario'    = pov_`scenario'    * total_pop
		gen poor320_`scenario' = pov320_`scenario' * total_pop
		gen poor550_`scenario' = pov550_`scenario' * total_pop
		gen hc_`scenario'      = hcpw_`scenario'   * total_working
		gen  k_`scenario'      = kpw_`scenario'    * total_working
	}

	* Now we are going to add up GDP, poor people, total and working age populations, and recalculate our statistics of interest
	collapse (sum) gdp_* poor* hc_* k_* total_working total_pop , by(year)

	* And re-calculate our outcomes of interest on a per worker - or per capita - basis
	foreach scenario in constant sc1 sc2 sc3 {
		gen gdppw_`scenario'       = (gdp_`scenario'   / total_working) / 1000 	// GDP per worker is expressed in 1,000s
		gen gdppc_`scenario'       = (gdp_`scenario'   / total_pop)	  / 1000	// GDP per capita is expressed in 1,000s
		gen gdppw_`scenario'_r     =  gdppw_`scenario' / gdppw_constant
		gen gdppc_`scenario'_r     =  gdppc_`scenario' / gdppc_constant
		gen  hcpw_`scenario'       =  hc_`scenario'    / total_working
		gen   kpw_`scenario'       = (k_`scenario'     / total_working) / 1000     // Capital per worker is expressed in 1,000s
		gen   pov_`scenario'       =  poor_`scenario'  / total_pop
		gen   pov_`scenario'_r     = pov_`scenario'   / pov_constant
		gen   pov_`scenario'_p     =  pov_`scenario'   - pov_constant
		replace  poor_`scenario'   = poor_`scenario'  / 1000000					// Recalculating the poor in millions
		gen  poor_`scenario'_d     = -1*(poor_`scenario'  - poor_constant)
		gen   pov320_`scenario'     = poor320_`scenario'  / total_pop
		gen   pov320_`scenario'_r   = pov320_`scenario'   / pov320_constant
		gen   pov320_`scenario'_p   = pov320_`scenario'   - pov320_constant
		replace  poor320_`scenario' = poor320_`scenario'  / 1000000					// Recalculating the poor in millions
		gen  poor320_`scenario'_d   = -1*(poor320_`scenario'  - poor320_constant)
		gen   pov550_`scenario'     = poor550_`scenario'  / total_pop
		gen   pov550_`scenario'_r   = pov550_`scenario'   / pov550_constant
		gen   pov550_`scenario'_p   = pov550_`scenario'   - pov550_constant
		replace  poor550_`scenario' = poor550_`scenario'  / 1000000					// Recalculating the poor in millions
		gen  poor550_`scenario'_d   = -1*(poor550_`scenario'  - poor550_constant)
		
		gen gdppcp_`scenario' = (gdppc_`scenario'_r - 1) * 100
		gen povp_`scenario' =  (pov_`scenario') * 100
		gen  povr_`scenario' = (pov_`scenario'_p) * 100 * -1
		gen poord_`scenario'  = poor_`scenario'_d   
		gen poordt_`scenario'  = poor320_`scenario'_d   
		gen poordf_`scenario'  = poor550_`scenario'_d   
	
	}


	
	**********************
	* Graphs for article *
	**********************
	scalar lrate50 = round(hci_gap_5rate_50p,1)
	scalar lrate75 = round(hci_gap_5rate_75p,1)
	local  lrate50 = lrate50
	local  lrate75 = lrate75 
	
	*Human Capital Per worker (Figure 2) 
		twoway (line hcpw_constant year, sort lwidth(thick) lpattern(solid) 	   lcolor(black)) ///
		       (line hcpw_sc1 year     , sort lwidth(thick) lpattern(longdash_dot) lcolor(black)) ///
		       (line hcpw_sc2 year	   , sort lwidth(thick) lpattern(dash)  	   lcolor(black)) ///
		       (line hcpw_sc3 year	   , sort lwidth(thick) lpattern(shortdash)    lcolor(black)) ///
		   if year <=2050, ytitle(Human capital per worker) 	xlabel(#8)		 				  ///
		   xtitle("") 																			  ///
		   graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) 				  ///
		   legend(order(1 "Baseline" 2 "Closing `lrate50'% of gap per 5 years (typical)" 3 "Closing `lrate75'% per 5 years (optimistic)" 4 "Gap closed immediately") region(lcolor(white))) xsize(8) ysize(5)
		   gr export "$graphs/hcpw_`cat'_011320`fname'.png", as(png) height(1500) width(2400) replace	
		   gr export "$graphs/hcpw_`cat'_011320`fname'.eps", as(eps) replace	

		   	
	
	* GDP relative to baseline (Figure 3) 
	twoway (line gdppc_constant_r year, sort lwidth(thick) lpattern(solid) 	      lcolor(black)) ///
		   (line gdppc_sc1_r year     , sort lwidth(thick) lpattern(longdash_dot) lcolor(black)) ///
		   (line gdppc_sc2_r year	  , sort lwidth(thick) lpattern(dash)  	      lcolor(black)) ///
		   (line gdppc_sc3_r year	  , sort lwidth(thick) lpattern(shortdash)    lcolor(black)) ///
		   if year <=2050, ytitle(GDP-per-capita relative to baseline scenario) ///
		   xtitle("")  xlabel(#8)												///
		   graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
		   legend(order(1 "Baseline" 2 "Closing `lrate50'% of gap per 5 years (typical)" 3 "Closing `lrate75'% per 5 years (optimistic)"  4 "Gap closed immediately") region(lcolor(white))) xsize(8) ysize(5)
		   gr export "$graphs/relative_income_`cat'_011320`fname'.png", as(png) height(1500) width(2400) replace	
		   gr export "$graphs/relative_income_`cat'_011320`fname'.eps", as(eps) replace	

	

	* Poverty figures (Figure 5)
	local dollarsign = char(36)
	twoway (line pov_constant year          , sort lwidth(thick) lpattern(solid) 	    lcolor(black)) ///											
	       (line pov_sc1 year               , sort lwidth(thick) lpattern(longdash_dot) lcolor(black)) ///
		   (line pov_sc2 year               , sort lwidth(thick) lpattern(dash)  	    lcolor(black)) ///
		   (line pov_sc3 year if year <=2050, sort lwidth(thick) lpattern(shortdash)    lcolor(black)) ///
		   (line pov320_constant year		, sort lwidth(thick) lpattern(solid) 	    lcolor(gs7))   ///
		   (line pov320_sc1 year			, sort lwidth(thick) lpattern(longdash_dot) lcolor(gs7))   ///
		   (line pov320_sc2 year			, sort lwidth(thick) lpattern(dash)  	    lcolor(gs7))   ///
		   (line pov320_sc3 year			, sort lwidth(thick) lpattern(shortdash)    lcolor(gs7))   ///
		   (line pov550_constant year		, sort lwidth(thick) lpattern(solid) 	    lcolor(gs10))  ///
		   (line pov550_sc1 year			, sort lwidth(thick) lpattern(longdash_dot) lcolor(gs10))  ///
		   (line pov550_sc2 year			, sort lwidth(thick) lpattern(dash)  	    lcolor(gs10))  ///
		   (line pov550_sc3 year			, sort lwidth(thick) lpattern(shortdash)    lcolor(gs10))  ///
			if year <=2050,																			   ///
			ytitle(Poverty rate) ylabel(#10) xtitle("") xlabel(#8)									   ///
			legend(order(1 "Baseline" 2 "Closing `lrate50'% of gap per 5 years (typical)" 3 "Closing `lrate75'% per 5 years (optimistic)"  4 "Gap closed immediately") region(lcolor(white)) cols(1)) ///
			xsize(8) ysize(15) scale(0.8) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))
	
	gr_edit .yaxis1.title.DragBy .1439344700813729 -1.858831311294153
	gr_edit .yaxis1.title.DragBy 0 -1.143896191565633
	gr_edit .plotregion1.AddTextBox added_text editor .4599910591419174 2017.668603213198
	gr_edit .plotregion1.added_text_new = 1
	gr_edit .plotregion1.added_text_rec = 1
	gr_edit .plotregion1.added_text[1].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid)) box_alignment(east) editcopy
	gr_edit .plotregion1.added_text[1].text = {}
	gr_edit .plotregion1.added_text[1].text.Arrpush $5.50 PPP
	gr_edit .plotregion1.AddTextBox added_text editor .2874932984252928 2016.157687784776
	gr_edit .plotregion1.added_text_new = 2
	gr_edit .plotregion1.added_text_rec = 2
	gr_edit .plotregion1.added_text[2].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid)) box_alignment(east) editcopy
	gr_edit .plotregion1.added_text[2].text = {}
	gr_edit .plotregion1.added_text[2].text.Arrpush $3.20 PPP
	gr_edit .plotregion1.AddTextBox added_text editor .1245546075720581 2015.68282865013
	gr_edit .plotregion1.added_text_new = 3
	gr_edit .plotregion1.added_text_rec = 3
	gr_edit .plotregion1.added_text[3].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid)) box_alignment(east) editcopy
	gr_edit .plotregion1.added_text[3].text = {}
	gr_edit .plotregion1.added_text[3].text.Arrpush $1.90 PPP
	gr_edit .legend.plotregion1.AddTextBox added_text editor .7207596892606298 47.42924142117065
	gr_edit .legend.plotregion1.added_text_new = 1
	gr_edit .legend.plotregion1.added_text_rec = 1
	gr_edit .legend.plotregion1.added_text[1].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid)) box_alignment(east) editcopy
	gr_edit .legend.plotregion1.AddTextBox added_text editor 1.880897814580746 21.76118539846311
	gr_edit .legend.plotregion1.added_text_new = 2
	gr_edit .legend.plotregion1.added_text_rec = 2
	gr_edit .legend.plotregion1.added_text[2].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid)) box_alignment(east) editcopy
	gr_edit .plotregion1.added_text[1].DragBy 0 -2
	gr_edit .plotregion1.added_text[3].DragBy -.0186002866668227 -.5945724599191449
	gr_edit .plotregion1.added_text[2].DragBy -.0238316172918665 -1.274083842683885
	
		
	gr export "$graphs/pov_`cat'_011320`fname'.png", as(png) width(2000) replace	
	gr export "$graphs/pov_`cat'_011320`fname'.eps", as(eps)			 replace	
	
	* Number of people not in poverty (Figure 7)

	* At 1.90
	twoway (line poor_sc1_d year, sort lwidth(thick) lpattern(longdash_dot) lcolor(black)) 		///
		   (line poor_sc2_d year, sort lwidth(thick) lpattern(dash)         lcolor(black)) 		///
		   (line poor_sc3_d year, sort lwidth(thick) lpattern(vshortdash)   lcolor(black)) 	    ///
		   , xscale(off) name(p1, replace) ytitle(Millions)	subtitle(`dollarsign'1.90 a day) 	graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))	///
		   legend(order(1 "Closing `lrate50'% of gap per 5 years" 2 "Closing `lrate75'% per 5 years"  3 "Gap closed immediately") region(lcolor(none)) cols(1)) xlabel(#8)	
	
	* At 3.20
	twoway (line poor320_sc1_d year, sort lwidth(thick) lpattern(longdash_dot) lcolor(black)) 		///
		   (line poor320_sc2_d year, sort lwidth(thick) lpattern(dash)         lcolor(black)) 		///
		   (line poor320_sc3_d year, sort lwidth(thick) lpattern(vshortdash)   lcolor(black)) 	    ///
		   , xscale(off) name(p2, replace) ytitle(Millions) subtitle(`dollarsign'3.20 a day) xlabel(#8)	 graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))
		  
	* At 5.50
	twoway (line poor550_sc1_d year, sort lwidth(thick) lpattern(longdash_dot) lcolor(black)) 		///
		   (line poor550_sc2_d year, sort lwidth(thick) lpattern(dash)         lcolor(black)) 		///
		   (line poor550_sc3_d year, sort lwidth(thick) lpattern(vshortdash)   lcolor(black)) 	    ///
		   , name(p3, replace) 				ytitle(Millions) subtitle(`dollarsign'5.50 a day)		xlabel(#8)		 graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))
	 
	* Combining
	grc1leg p1 p2 p3,  ///
			cols(1) xsize(8) ysize(15) 				graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))				
	gr_edit .style.editstyle declared_ysize(8) editcopy
	gr_edit .gmetric_mult = 0.9
	gr_edit .title.style.editstyle size(medium) editcopy
	
	gr export "$graphs/poor_`cat'_011320`fname'.png", as(png) width(3000) replace	
	gr export "$graphs/poor_`cat'_011320`fname'.eps", as(eps) replace	
	
/*

	* Macros for LaTex paper
	sort year 
	local c = 1
	
	local rhcpw = ".01"
	local rgdppcp = "1"
	local rpovp    = ".1"
	local rpoord    = "10"
	local rpoordt    = "10"
	local rpoordf    = "10"
	local rpovr    = ".1"
	
	texresults using results_`cat'.tex, texmacro(place`cat')     result(hci_gap_5rate_50) replace round(.0001)
	foreach y in XV XX XXV XXX XXXV XL XLV L {
		foreach re in hcpw gdppcp povp poord poordt poordf povr {
				texresults using results_`cat'.tex, texmacro(`re'zero`y'`cat')     result(`re'_constant[`c'])  append round(`r`re'') unitzero
				texresults using results_`cat'.tex, texmacro(`re'one`y'`cat')     result(`re'_sc1[`c'])  append round(`r`re'') unitzero
				texresults using results_`cat'.tex, texmacro(`re'two`y'`cat')     result(`re'_sc2[`c'])  append round(`r`re'') unitzero
				texresults using results_`cat'.tex, texmacro(`re'three`y'`cat')     result(`re'_sc3[`c'])  append round(`r`re'') unitzero
		}
		local c = `c' + 1
	}
	
*/

}



* Relative income gains (Figure 4) 
* Loading Projections file
use "$output/hc_projections_102219`fname'.dta", clear								
keep if year <= endyear

sort wbcode year
bys wbcode: gen starting_gdp = gdppc_constant[1]
bys wbcode: gen starting_pov = pov_constant[1]  
bys wbcode: gen starting_poor = (pov_constant[1] * total_pop[1])

local ey = 1 + (endyear - 2015) / 5
foreach s in constant sc1 sc2 sc3 {
	bys wbcode: gen ending_gdp_ratio_`s'  = gdppc_`s'_r[`ey']
	bys wbcode: gen ending_pov_ratio_`s' = (pov_`s'[`ey']) / starting_pov
	bys wbcode: gen ending_pov_`s'       = (pov_`s'[`ey'])
	bys wbcode: gen ending_poor_`s'      = (pov_`s'[`ey'] * total_pop[`ey']) 
}
collapse (mean) starting* ending* (first) wbcountryname, by(wbcode)
twoway (scatter ending_gdp_ratio_sc1 starting_gdp, sort             mcolor(black%50) mlcolor(black%60) mlwidth(none)) 			 ///
       (scatter ending_gdp_ratio_sc2 starting_gdp, sort  msymbol(T) mcolor(black%50) mlcolor(black%60) mlwidth(none))		     ///
	   (scatter ending_gdp_ratio_sc3 starting_gdp, sort  msymbol(X) mcolor(black%50) mlcolor(black%60) 				) 			 ///
	  , ytitle(GDPPC in 2050 relative to baseline scenario) ///
	    xtitle(GDP-per-capita in 2015 (Log scale)) xscale(log)       ///
		xlabel(1000 "1000" 10000 "10000" 100000 "100000")            ///
		graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
		legend(order(1 "Closing `lrate50'% of gap per 5 years" 2 "Closing `lrate75'% per 5 years"  3 "Closing immediately") region(lcolor(white)))
gr export "$graphs/income_gains_011320`fname'.png", as(png) width(3000) replace	
gr export "$graphs/income_gains_011320`fname'.eps", as(eps) replace	


* Changes in poverty, by country (Figure 6)
graph dot (asis) ending_pov_constant ending_pov_sc* starting_pov if starting_pov > .10 & starting_pov != . ///
    , over(wbcountryname, sort(starting_pov) descending label(labsize(small)))  noextendline 			   ///
	  legend(order( 5 "Poverty rate in 2015" 1 "Poverty rate in 2050 (baseline scenario)" 2 "Poverty rate in 2050 (typical scenario)" 3 "Poverty rate in 2050 (optimistic scenario)" 4 "Poverty rate in 2050 (immediate scenario)") cols(1) region(lcolor(white))) ///
	   xsize(4) ysize(7) graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))			   ///
	   marker(5, mcolor(black) msymbol(S))  marker(2, mcolor(black) 	) marker(3, mcolor(black) msymbol(T))  marker(4, mcolor(black) msymbol(X))   marker(1, mcolor(black) msymbol(+)) 
gr export "$graphs/pov_gains_011320`fname'.png", as(png) width(2500) replace
gr export "$graphs/pov_gains_011320`fname'.eps", as(eps)  replace

	   
exit

