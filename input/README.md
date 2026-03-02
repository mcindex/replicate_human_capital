# Input Data — Collin & Weil (2020) Replication

All files in this directory are **read-only inputs** — they are never overwritten by the code.

## Large Files (Not Tracked by Git)

The following file exceeds GitHub's 50 MB limit and is **not included in the repository**. You must download it separately before running the code.

| File | Size | Source | How to obtain |
|------|------|--------|---------------|
| `hci_data_21Sept2018_FINAL.dta` | 111 MB | World Bank Human Capital Project (Kraay 2018) | [Download from Dropbox](https://www.dropbox.com/scl/fi/9jtptpqzsikai6oppcagk/hci_data_21Sept2018_FINAL.dta?rlkey=9ya2j985z73ecn2muve2gezsw&st=wje9nrcv&dl=0). The file is the September 21, 2018 release of the HCI micro-database in Stata format. Place in this directory. |

## All Input Files

| File | Size | Description | Source |
|------|------|-------------|--------|
| `2015 line up.xlsx` | 71 KB | Poverty headcounts ($1.90, $3.20, $5.50/day) and Gini coefficients | World Bank PovcalNet |
| `BL2013_F_v2.1.dta` | 5.3 MB | Barro-Lee educational attainment — Female | Barro & Lee (2013) dataset v2.1 |
| `BL2013_M_v2.1.dta` | 5.3 MB | Barro-Lee educational attainment — Male | Barro & Lee (2013) dataset v2.1 |
| `BL2013_MF_v2.1.dta` | 5.3 MB | Barro-Lee educational attainment — Both sexes | Barro & Lee (2013) dataset v2.1 |
| `CLASS.xls` | 240 KB | World Bank country income classifications | World Bank |
| `IHME_GBD_2016_COVARIATES_1980_2016_EDUCATION_YRS_PC_Y2017M09D05.csv` | 45 MB | Years of schooling per capita, 1980-2016 | IHME Global Burden of Disease 2016 |
| `WPP2017_POP_F07_1_POPULATION_BY_AGE_BOTH_SEXES.xlsx` | 10.3 MB | UN population projections by age — Both sexes | UN Population Division, WPP 2017 |
| `WPP2017_POP_F07_2_POPULATION_BY_AGE_MALE.xlsx` | 10.1 MB | UN population projections by age — Male | UN Population Division, WPP 2017 |
| `WPP2017_POP_F07_3_POPULATION_BY_AGE_FEMALE.xlsx` | 10.1 MB | UN population projections by age — Female | UN Population Division, WPP 2017 |
| `asr_data_21Sept2018.dta` | 4.3 MB | Adult survival rate data | World Bank HCP (Sept 2018 release) |
| `data-2019-12-06.dta` | 5.3 MB | ILO labor force participation rates | ILO STAT (Dec 2019 download) |
| `gdp_constant_ppp.xls` | 207 KB | GDP per capita, PPP (constant 2011 international $) | World Bank WDI |
| `gross_capital_formation_0718.xls` | 265 KB | Gross capital formation (% of GDP) | World Bank WDI |
| `hci_data_21Sept2018_FINAL.dta` | 111 MB | World Bank HCI micro-database (**not in repo — see above**) | Kraay (2018), World Bank HCP. [Download from Dropbox](https://www.dropbox.com/scl/fi/9jtptpqzsikai6oppcagk/hci_data_21Sept2018_FINAL.dta?rlkey=9ya2j985z73ecn2muve2gezsw&st=wje9nrcv&dl=0). |
| `hlo_data_21Sept2018.dta` | 7.3 MB | Harmonized Learning Outcomes | World Bank HCP (Sept 2018 release) |
| `masterdata.dta` | 1.2 MB | HCI master country list with codes | World Bank HCP |
| `pwt90.dta` | 3.0 MB | Penn World Table version 9.0 | Feenstra, Inklaar & Timmer (2015) |
| `stunting_data_21Sept2018.dta` | 18.1 MB | Child stunting prevalence | World Bank HCP (Sept 2018 release) |
| `wb_health_education_expenditure.dta` | 3.5 MB | Gov't health & education expenditure (% GDP) | World Bank WDI via `wbopendata` (2026 download; indicators: `se.xpd.totl.gd.zs`, `sh.xpd.chex.gd.zs`) |
| `wb_health_education_expenditure_2019vintage.dta` | 423 KB | Same as above, Dec 2019 vintage | WDI Database Archives (db=57, version=201912) via `wbgapi` Python package. See `code/download_wb_2019_vintage.py`. |

## Notes

- The World Bank HCP data files (`hci_data`, `hlo_data`, `asr_data`, `stunting_data`, `masterdata`) are all from the September 21, 2018 release, which corresponds to the version used for the original paper.
- The 2019-vintage expenditure file is used by `(4) npv_calculations.do` to exactly replicate Figure 9. The World Bank periodically revises historical data, so a current download will produce slightly different scatterplot positions.
