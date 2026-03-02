
* Author: Matt Collin (but with most of the code cribbed from an e-mail by Aart Kraay) 
* Date:   01-07-19

* Here, we ask the question: what constitutes a reasonable scenario for progress on the human capital index? 

* For this, we start with the latest version of the HCI database, and we look at four components: 

*	(1) Expected years of schooling (eyrs_mf) 
*	(2) Relative test scores (test_mf) 
*   (3) The proportion of children under five who are not stunted (nostu)
*   (4) Adult survival rates (15-20) (asr_mf)

* Our "business as usual" or "typical" scenario will be if each of these components grows at the median rate over 10 years
	* Our "optimistic" scenario will be if each of these compnents grows at the 75th percentile over 10 years. 

local tertiary = "No" 	

* For the tertiary education check we will use growth rates in the 20-24 age level of tertiary education as recorded in Barro-Lee
* And then bolt it on to EYS
* One issue is that Barro-Lee only covers up until 2010. So we will take tertiary education for 20-25 in 2005 and 2010, and assume the same
* growth rate between the two holds between 2010 and 2015. 
if "`tertiary'" == "Yes" {
	use "$input/BL2013_MF_v2.1.dta", clear
	keep if agefrom == 20 & ageto==24
	keep if year == 2005 | year == 2010
	sort BLcode year
	replace yr_sch_ter = (((yr_sch_ter - yr_sch_ter[_n-1]))) + yr_sch_ter if year == 2010 & year[_n-1] == 2005 & BLcode[_n-1] == BLcode // Assuming the 2015 value of tertiary schooling will have growth at the same rate
	replace year       = 2015 if year == 2010 																		// Advancing to 2015
	tempfile bter
	save    `bter', replace
	
	keep if year == 2015
	replace year =  2017
	tempfile bter17
	save    `bter17', replace
}
	
* We use historical growth between 2005 and 2015, using the HCI database
use "$input\hci_data_21Sept2018_FINAL.dta", clear   	// We start with the latest version of the HCI database
tsset countrynumber year 
* Adding in tertiary to EYS if needed

if "`tertiary'" == "Yes" {
	mmerge wbcode year using `bter'  , unmatched(master) umatch(WBcode year) ukeep(yr_sch_ter)
	mmerge wbcode year using `bter17', unmatched(master) umatch(WBcode year) ukeep(yr_sch_ter) update
	replace eyrs_mf = eyrs_mf + yr_sch_ter 
	replace eyrs_mf = min(eyrs_mf,18) if eyrs_mf !=.
}


* We calculate growth rates for three of the components here	
sort countrynumber year
foreach var in eyrs_mf nostu_mf asr_mf {
	gen d10_`var' = `var' - L10.`var'
    su  d10_`var' if year==2015, d
	scalar p50d`var' = `r(p50)'
	scalar p75d`var' = `r(p75)'
}
 
 
  * The median and 75th percentile growth rates in HLO have been calculated separately by Aart:
scalar p50dtest_mf = 6
scalar p75dtest_mf = 19

* So now we know the rate of change over 10 years. But what do we use as our starting point?
* Here we turn to the median values for the three components as they exist in the HCI database:
foreach var in eyrs_mf test_mf nostu_mf asr_mf {
	su `var' if year==2017 & eyrs_mf~=. & test_mf~=., d     // Summing
	scalar p50`var' = `r(p50)'								// Saving the mean rate
}


* Exporting for table in paper
cd "$output
texresults using results`fname'.tex, texmacro(ttest)     result(p50dtest_mf)  replace round(.001) unitzero
texresults using results`fname'.tex, texmacro(otest)     result(p75dtest_mf)  append  round(.001) unitzero
texresults using results`fname'.tex, texmacro(mtest)     result(p50test_mf)   append  round(.01)  unitzero
foreach var in eyrs nostu asr {
	texresults using results`fname'.tex, texmacro(t`var')     result(p50d`var'_mf)  append  round(.001) unitzero
	texresults using results`fname'.tex, texmacro(o`var')     result(p75d`var'_mf)  append  round(.001) unitzero
	texresults using results`fname'.tex, texmacro(m`var')     result(p50`var'_mf)   append  round(.01)  unitzero
}


  
* Calculating HCI as of 2015
* * * * * * Parameters
scalar phi 			   = 0.08								// The Mincerian return to education
scalar gam_height_mid  = 0.034								// Returns from height
scalar beta_height_asr = 19.2								// Response of height to asr
scalar beta_height_stu = 10.2								// Response of height to notstunting 
scalar gam_asr_mid     = beta_height_asr * gam_height_mid	// Returns to improving ASR
scalar gam_stu_mid     = beta_height_stu * gam_height_mid	// Returns to improving stunting
scalar maxhlo          = 625								// Set max for HLO

if "`tertiary'" == "Yes" {
	scalar   nys_max        = 18									// Set max for years of schooling including preprimary
	scalar nadys_max        = 18	
	local fname = "ter"
}
else {
	scalar   nys_max        = 14								// Set max for years of schooling
	scalar nadys_max        = 14									// Set max for quality adjusted years of schooling
	local fname = ""
}



* Calculating the HCI of the median country in 2015
scalar hci_2015 = exp(phi*(((p50test_mf/maxhlo)*p50eyrs_mf)- nadys_max) + 0.5 * ( gam_asr_mid * (p50asr_mf - 1) +  gam_stu_mid * (p50nostu_mf - 1) ) )
di     hci_2015
scalar hci_gap_2015 = 1 - hci_2015

* Now calculating the change in the HCI gap if that median country progresses according to the 50th or 75th percentile 
foreach scen in 50 75 {
	scalar hci_2025_`scen' = exp(phi*(((( p50test_mf + p`scen'dtest_mf)/maxhlo)*(p50eyrs_mf + p`scen'deyrs_mf))-nadys_max) + 0.5 * ( gam_asr_mid * (p50asr_mf + p`scen'dasr_mf - 1) +  gam_stu_mid * (p50nostu_mf + p`scen'dnostu_mf- 1) ) )
	scalar hci_gap_2025_`scen' = 1 - hci_2025_`scen'
	scalar hci_gap_change_`scen' = (hci_gap_2015 - hci_gap_2025_`scen') / hci_gap_2015
}

di hci_2015
di hci_2025_50
di hci_gap_change_50
di hci_2025_75
di hci_gap_change_75

* Calculating the annual growth (shrink) rates of the human capital gap 
scalar hci_gap_1rate_50 = (1-hci_gap_change_50)^(1/10) - 1
scalar hci_gap_1rate_75 = (1-hci_gap_change_75)^(1/10) - 1

* Calculating the 5 year growth (shrink rate) 
scalar hci_gap_5rate_50 = 1-(1+hci_gap_1rate_50)^5
scalar hci_gap_5rate_75 = 1-(1+hci_gap_1rate_75)^5
scalar hci_gap_1rate_50 = hci_gap_1rate_50 * -1
scalar hci_gap_1rate_75 = hci_gap_1rate_75 * -1

* Outputting some text to check the results
di "The typical rate is a proportional reduction in the gap of " hci_gap_1rate_50 " every year and " hci_gap_5rate_50 " every five years."
di "The optimistic rate is a proportional reduction in the gap of " hci_gap_1rate_75 " every year and " hci_gap_5rate_75 " every five years."



******** Generating output for the working paper
scalar hci_gap_5rate_50p = hci_gap_5rate_50*100
scalar hci_gap_5rate_75p = hci_gap_5rate_75*100
scalar hci_gap_1rate_50p = hci_gap_1rate_50*100
scalar hci_gap_1rate_75p = hci_gap_1rate_75*100

cd "$output"																	// Changing to the output directory 																	

* Using textresults to output figures used in the text 
texresults using results`fname'.tex, texmacro(typical)       result(hci_gap_5rate_50)  append round(.0001)		// The typical rate of 5yr progress, absolute
texresults using results`fname'.tex, texmacro(typicalp)      result(hci_gap_5rate_50p) append round(1)			// The typical rate of 5yr progress, rounded in % terms
texresults using results`fname'.tex, texmacro(typicalpp)     result(hci_gap_5rate_50p) append round(.1)		// The typical rate of 5yr progress, rounded in % terms, with more precision
texresults using results`fname'.tex, texmacro(optimistic)    result(hci_gap_5rate_75)  append round(.0001)		// The optimistic rate of 5yr progress, absolute
texresults using results`fname'.tex, texmacro(optimisticp)   result(hci_gap_5rate_75p) append round(1)			// The optimistic rate of 5yr progress, rounded in % terms
texresults using results`fname'.tex, texmacro(optimisticpp)  result(hci_gap_5rate_75p) append round(.1)		// The optimistic rate of 5yr progress, rounded in % terms,  with more precision
texresults using results`fname'.tex, texmacro(otypical)      result(hci_gap_1rate_50)  append round(.0001)		// The typical rate of 1yr progress, absolute
texresults using results`fname'.tex, texmacro(otypicalp)     result(hci_gap_1rate_50p) append round(1)			// The typical rate of 1yr progress, rounded in % terms
texresults using results`fname'.tex, texmacro(otypicalpp)    result(hci_gap_1rate_50p) append round(.1)		// The typical rate of 1yr progress, rounded in % terms, with more precision
texresults using results`fname'.tex, texmacro(ooptimistic)   result(hci_gap_1rate_75)  append round(.0001)		// The optimistic rate of 1yr progress, absolute
texresults using results`fname'.tex, texmacro(ooptimisticp)  result(hci_gap_1rate_75p) append round(1)			// The optimistic rate of 1yr progress, rounded in % terms
texresults using results`fname'.tex, texmacro(ooptimisticpp) result(hci_gap_1rate_75p) append round(.1)		// The optimistic rate of 1yr progress, rounded in % terms,  with more precision
  

exit


