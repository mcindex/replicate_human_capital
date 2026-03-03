# Replication Guide — Human Capital Investment Paper

## Quick Start
1. Install Stata 15+ (MP recommended)
2. Open `master.do` and set `$root` to your project directory
3. Run `master.do` — it handles everything including package loading

## Stata Scripts (run order via master.do)

All Stata .do files are in `code/`. User-written packages are bundled in `code/ado/`.

| Order | File | Description | Runtime |
|-------|------|-------------|---------|
| 1 | `(1) assemble.do` | Assembles all input data. Calls 1.1 background. | ~1 min |
| 1.1 | `1.1 (background) barrolee_ihme_conversion.do` | IHME→Barro-Lee conversion. Called by (1). | (called) |
| 2 | `(2) hc_simulation.do` | Main simulation. Calls 2.1 background. | ~2 min |
| 2.1 | `2.1 (background) scenario.do` | Scenario calculations. Called by (2), (4), (5). | (called) |
| 3 | `(3) hc_worldprojections.do` | World projections & graphs (Figs 2-7). | ~1 min |
| 4 | `(4) npv_calculations.do` | NPV calculations (Fig 9). **Slow.** | ~15 min |
| 5 | `(5) cambodia_counterfactual.do` | Cambodia analysis (Fig 8). | ~2 min |
| 1-ter | `(1) assemble.do` | Re-run with tertiary education. | ~1 min |
| 2-ter | `(2) hc_simulation.do` | Re-run with tertiary education. | ~2 min |
| 6 | `(6) hc_education_compare.do` | Sec vs ter comparison (Appendix). | ~1 min |
| 7 | `(7) fertility_table3.do` | Table 3: fertility channel (Sec 6.1). | ~10 sec |
| -- | `labor_participation.do` | LFP analysis (Figs 10-11, standalone). | ~5 min |

## Input Data

All in `input/`. 20 files total:

| File | Description | Source |
|------|-------------|--------|
| BL2013_*_v2.1.dta (3 files) | Barro-Lee education data (M, F, MF) | Barro & Lee (2013) |
| WPP2017_POP_F07_*.xlsx (3 files) | UN Population projections by age/sex | UN Population Division |
| IHME_GBD_2016_...csv | IHME years of schooling | IHME GBD 2016 |
| hci_data_21Sept2018_FINAL.dta | World Bank HCI database | Kraay (2018) |
| hlo_data_21Sept2018.dta | Harmonized Learning Outcomes | World Bank HCP |
| asr_data_21Sept2018.dta | Adult survival rates | World Bank HCP |
| stunting_data_21Sept2018.dta | Child stunting data | World Bank HCP |
| masterdata.dta | HCI master country list | World Bank HCP |
| pwt90.dta | Penn World Table 9.0 | Feenstra et al. |
| gdp_constant_ppp.xls | GDP (constant 2011 PPP) | World Bank WDI |
| gross_capital_formation_0718.xls | Gross capital formation (% GDP) | World Bank WDI |
| CLASS.xls | WB income classifications | World Bank |
| 2015 line up.xlsx | Poverty headcounts & Gini | World Bank PovcalNet |
| data-2019-12-06.dta | ILO labor force participation | ILO |
| wb_health_education_expenditure.dta | Health & education expenditure (% GDP) | World Bank WDI (downloaded 2026-03-02 via `wbopendata`; indicators: se.xpd.totl.gd.zs, sh.xpd.chex.gd.zs) |

## Output

- Intermediate datasets → `output/`
- Figures and graphs → `figures_tables/`
- LaTeX result macros → `output/results*.tex`

## Bundled Packages (code/ado/)

| Package | Version | Purpose |
|---------|---------|---------|
| mmerge | - | Flexible merge command |
| kountry | - | Country name/code conversion |
| texresults | - | Export scalars to LaTeX macros |
| wbopendata | - | World Bank API access (used in Step 4) |

## Replication Notes

### Table 3 (Fertility Channel)
Table 3 in the published paper was computed outside of Stata (no original .do file existed).
File (7) replicates it using population-weighted averages (by projected 2050 working-age population)
with the log-elasticity formula from Section 6.1. Results match 8 of 24 cells exactly and are
within 0.1–0.5 pp for the rest. See the .do file header for full methodology.

### Figures 10-11 (Labor Force Participation)
`labor_participation.do` must be run in a separate, clean Stata session because
`npregress kernel` estimates conflict with stored results from the main pipeline.
Run via: `do "$do/labor_participation.do"` after setting globals.

### Figure 9 (NPV Scatterplot)
Scatterplot positions differ slightly from the published paper due to World Bank data vintage
(2026 download vs ~2019 original). The World Bank revises historical data; exact replication
would require a 2019-vintage API snapshot.

## Python Scripts

| File | Description |
|------|-------------|
| `generate_replication_report.py` | HTML replication report with side-by-side figure comparison |

## R Scripts (code/R/)

R replication of the Stata pipeline, translated by Claude Code. Not independently reviewed by the authors.

| Order | File | Description | Status |
|-------|------|-------------|--------|
| -- | `master.R` | Entry point: sets paths, loads packages, sources all scripts | TESTED |
| -- | `country_names.R` | Helper: country name standardization & ISO3C mapping | TESTED |
| -- | `scenario_calc.R` | Equiv of 2.1 background: compute HCI gap closure rates | TESTED |
| 1 | `01_assemble.R` | Equiv of (1) assemble.do + 1.1 background | PASS |
| 2 | `02_hc_simulation.R` | Equiv of (2) hc_simulation.do + scenario | PASS |
| 3 | `03_hc_worldprojections.R` | Equiv of (3): Figures 2-7 | PASS |
| 4 | `04_npv_calculations.R` | Equiv of (4): Figure 9, NPV search | PASS |
| 5 | `05_cambodia_counterfactual.R` | Equiv of (5): Figure 8 | PASS |
| 6 | `06_hc_education_compare.R` | Equiv of (6): Appendix sec vs ter | PASS |
| 7 | `07_fertility_table3.R` | Equiv of (7): Table 3 fertility channel | PASS |
| 8 | `08_labor_participation.R` | Equiv of labor_participation.do: Figs 10-11 | PASS |
| -- | `validate_vs_stata.R` | Observation-level validation (331k comparisons, 6 stages) | utility |
| -- | `run_and_validate.R` | Run full pipeline then validate | utility |
| -- | `test_pipeline.R` | Full pipeline validation against Stata output | utility |

### Notes (updated 2026-03-03)
- All R figures output with `_R` suffix to avoid overwriting Stata output.
- R has 145 countries vs Stata's 144 (1 extra from IHME/BL mapping).
- Nigeria shows ~1-4% deviation due to IHME conversion input difference.
- Required R packages: haven, readxl, dplyr, tidyr, ggplot2, countrycode, data.table, stringr, purrr, scales, patchwork.
