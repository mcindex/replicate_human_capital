* This .do file produces Figures 3, 4, 5, and 6 for the paper
* "The Effect of Increasing Human Capital Investment on Economic Growth and Poverty: A Simulation Exercise"
* It is (6/6) of the .do files in this project. 
* .do file author: Matt Collin (mcollin@brookings.edu) 
* This version: October 22, 2019

* This .do file calculates the Appendix graphs comparing outcomes from the original model to that included tertiary education

* Parameters
scalar endyear = 2050		// Set the year you want the projections to run until (2065 is the latest you are allowed)

* We are going to calculate and append results using secondary and tertiary education separately


foreach cat in world developing lowincome ssa {									// We produces the same figures for the following sub-categories, which we cycle over 

	foreach e in sec ter {
		if "`e'" == "sec" {
			local fname = ""
		}
		else if "`e'" == "ter" {
			local fname = "ter"
		}

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
		
		keep  year hcpw_* gdppc_*_r pov_*
		foreach var of varlist hcpw_* gdppc_*_r pov_*  {
			rename `var' `var'`fname'											// renaming only if it is tertiary education file
		}
		
		if "`e'" == "sec" {
			tempfile sec
			save    `sec', replace
		}
		else if "`e'" == "ter" {
			mmerge year using `sec', type(1:1) 
		}
	}
	
	
	**********************
	* Graphs for article *
	**********************
	scalar lrate50 = round(hci_gap_5rate_50p,1)
	scalar lrate75 = round(hci_gap_5rate_75p,1)
	local  lrate50 = lrate50
	local  lrate75 = lrate75 
	
	scalar lrate50ter = round(hci_gap_5rate_50pter,1)
	scalar lrate75ter = round(hci_gap_5rate_75pter,1)
	local  lrate50ter = lrate50ter
	local  lrate75ter = lrate75ter 
	
	*Human Capital Per worker (Figure 2) 
			twoway (line hcpw_constant    year, sort lwidth(thick) lcolor(black)                             ) ///
				   (line hcpw_sc1         year, sort lwidth(thick) lcolor(black) lpattern(longdash)      			            ) ///
				   (line hcpw_sc2         year, sort lwidth(thick) lcolor(black) lpattern(vshortdash)                    ) ///
				   (line hcpw_constantter year, sort lwidth(thick) lcolor(gs7)      )    ///
				   (line hcpw_sc1ter      year, sort lwidth(thick) lcolor(gs7)       lpattern(longdash)) ///		
				   (line hcpw_sc2ter      year, sort lwidth(thick) lcolor(gs7) lpattern(vshortdash)) ///
		  		   if year <=2050, ytitle(Human capital per worker) 	xlabel(#8)		///
		   xtitle("") 															///
		   legend(order(1 "Baseline" 4 "Baseline" 2 "Closing `lrate50'% of gap per 5 years (typical)"  5 "Closing `lrate50ter'% of gap per 5 years (typical)"  3 "Closing `lrate75'% per 5 years (optimistic)" 6 "Closing `lrate75ter'% per 5 years (optimistic)") rows(3) region(lcolor(white))) xsize(8) ysize(5) ///
		   graphregion(fcolor(white) lcolor(white))	
		   
		   gr_edit .legend.plotregion1.DragBy -3.98692810457516 .0653594771242024
     	   gr_edit .legend.AddTextBox added_text editor 12.59673202614379 .53861797220467
		   gr_edit .legend.added_text_new = 1
		   gr_edit .legend.added_text_rec = 1
		   gr_edit .legend.added_text[1].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
		   gr_edit .legend.added_text[1].style.editstyle size(medlarge) editcopy
		   gr_edit .legend.added_text[1].text = {}
		   gr_edit .legend.added_text[1].text.Arrpush Primary-Secondary
		   
		   gr_edit .legend.AddTextBox added_text editor 11.94313725490196 31.12685326632231
		   gr_edit .legend.added_text_new = 2
		   gr_edit .legend.added_text_rec = 2
		   gr_edit .legend.added_text[2].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
		   gr_edit .legend.AddTextBox added_text editor 12.79281045751634 70.66933692645304
		   gr_edit .legend.added_text_new = 3
		   gr_edit .legend.added_text_rec = 3
		   gr_edit .legend.added_text[3].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
		   gr_edit .legend.added_text[3].style.editstyle size(medlarge) editcopy
		   gr_edit .legend.added_text[3].text = {}
		   gr_edit .legend.added_text[3].text.Arrpush Primary-Tertiary
			   
		   gr export "$graphs/hcpw_`cat'_011320_secter.png", as(png) height(1500) width(2400) replace	
			gr export "$graphs/hcpw_`cat'_011320_secter.eps", as(eps)  replace	


		   
	* GDP relative to baseline (Figure 3) 
	twoway (line gdppc_constant_r    year, sort lwidth(thick) lcolor(black)                                ) ///
		   (line gdppc_sc1_r         year, sort lwidth(thick) lcolor(black) lpattern(longdash)       			           ) ///
		   (line gdppc_sc2_r         year, sort lwidth(thick) lcolor(black) lpattern(vshortdash)                     ) ///
		   (line gdppc_constant_rter year, sort lwidth(thick) lcolor(gs7) ) ///
		   (line gdppc_sc1_rter      year, sort lwidth(thick) lcolor(gs7) lpattern(longdash)    ) ///		
		   (line gdppc_sc2_rter      year, sort lwidth(thick) lcolor(gs7) lpattern(vshortdash) ) ///
		   if year <=2050, ytitle(GDP-per-capita relative to baseline scenario) ///
		   xtitle("")  xlabel(#8)												///
		   legend(order(1 "Baseline" 4 "Baseline" 2 "Closing `lrate50'% of gap per 5 years (typical)"  5 "Closing `lrate50ter'% of gap per 5 years (typical)"  3 "Closing `lrate75'% per 5 years (optimistic)" 6 "Closing `lrate75ter'% per 5 years (optimistic)") rows(3) region(lcolor(white))) xsize(8) ysize(5) ///
		   graphregion(fcolor(white) lcolor(white))	 
		   
		   gr_edit .legend.plotregion1.DragBy -3.98692810457516 .0653594771242024
     	   gr_edit .legend.AddTextBox added_text editor 12.59673202614379 .53861797220467
		   gr_edit .legend.added_text_new = 1
		   gr_edit .legend.added_text_rec = 1
		   gr_edit .legend.added_text[1].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
		   gr_edit .legend.added_text[1].style.editstyle size(medlarge) editcopy
		   gr_edit .legend.added_text[1].text = {}
		   gr_edit .legend.added_text[1].text.Arrpush Primary-Secondary
		   
		   gr_edit .legend.AddTextBox added_text editor 11.94313725490196 31.12685326632231
		   gr_edit .legend.added_text_new = 2
		   gr_edit .legend.added_text_rec = 2
		   gr_edit .legend.added_text[2].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
		   gr_edit .legend.AddTextBox added_text editor 12.79281045751634 70.66933692645304
		   gr_edit .legend.added_text_new = 3
		   gr_edit .legend.added_text_rec = 3
		   gr_edit .legend.added_text[3].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
		   gr_edit .legend.added_text[3].style.editstyle size(medlarge) editcopy
		   gr_edit .legend.added_text[3].text = {}
		   gr_edit .legend.added_text[3].text.Arrpush Primary-Tertiary
		   
		   gr export "$graphs/relative_income_`cat'_011320_secter.png", as(png) height(1500) width(2400) replace	
		   gr export "$graphs/relative_income_`cat'_011320_secter.eps", as(eps)  	 replace	

	* Poverty figures (Figure 5)
	local dollarsign = char(36)
	twoway (line pov_constant    year, sort lwidth(thick) lcolor(black)				   ) ///
	       (line pov_sc1         year, sort lwidth(thick) lcolor(black) lpattern(longdash)				   ) ///
		   (line pov_sc2         year, sort lwidth(thick) lcolor(black) lpattern(vshortdash)      				   ) ///
		   (line pov_constantter year, sort lwidth(thick) lcolor(gs7)) ///
	       (line pov_sc1ter      year, sort lwidth(thick) lcolor(gs7) lpattern(longdash) ) ///
		   (line pov_sc2ter      year, sort lwidth(thick) lcolor(gs7) lpattern(vshortdash)) ///
		  	if year <=2050,																		     ///
			ytitle(Poverty rate) ylabel(#10) xtitle("") xlabel(#8)								     ///
		   legend(order(1 "Baseline" 2 "Closing `lrate50'% of gap per 5 years (typical)" 3 "Closing `lrate75'% per 5 years (optimistic)" 4 "Baseline" 5 "Closing `lrate50ter'% of gap per 5 years (typical)" 6 "Closing `lrate75ter'% per 5 years (optimistic)") cols(1) region(lcolor(white)))  ///
			xsize(8) ysize(15) scale(0.8)  legend(region(lcolor(white))) graphregion(fcolor(white) lcolor(white))
				
			gr_edit .AddTextBox added_text editor 21.80318619285071 -.1380831916495433
			gr_edit .added_text_new = 1
			gr_edit .added_text_rec = 1
			gr_edit .added_text[1].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
			gr_edit .added_text[1].style.editstyle size(medium) editcopy
			gr_edit .added_text[1].text = {}
			gr_edit .added_text[1].text.Arrpush Primary-Secondary:
			gr_edit .AddTextBox added_text editor 8.89260333917658 1.797856305332605
			gr_edit .added_text_new = 2
			gr_edit .added_text_rec = 2
			gr_edit .added_text[2].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
			gr_edit .added_text[2].style.editstyle size(medium) editcopy
			gr_edit .added_text[2].text = {}
			gr_edit .added_text[2].text.Arrpush Primary-Tertiary:
			gr_edit .legend.plotregion1.AddTextBox added_text editor 16.3058449518132 19.96376402191184
			gr_edit .legend.plotregion1.added_text_new = 1
			gr_edit .legend.plotregion1.added_text_rec = 1
			gr_edit .legend.plotregion1.added_text[1].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
			gr_edit .legend.plotregion1.AddTextBox added_text editor 22.56427004981584 38.00275341732285
			gr_edit .legend.plotregion1.added_text_new = 2
			gr_edit .legend.plotregion1.added_text_rec = 2
			gr_edit .legend.plotregion1.added_text[2].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
			gr_edit .AddTextBox added_text editor 14.98250091166437 81.53436433728497
			gr_edit .added_text_new = 3
			gr_edit .added_text_rec = 3
			gr_edit .added_text[3].style.editstyle  angle(default) size(medsmall) color(black) horizontal(left) vertical(middle) margin(zero) linegap(zero) drawbox(no) boxmargin(zero) fillcolor(bluishgray) linestyle( width(thin) color(black) pattern(solid) align(inside)) box_alignment(east) editcopy
			gr_edit .legend.plotregion1.DragBy .2454284352157902 7.976424144513127

		
	gr export "$graphs/pov_`cat'_011320_secter.png", as(png) width(2000) replace	
gr export "$graphs/pov_`cat'_011320_secter.eps", as(eps)  replace	

		
		
}

