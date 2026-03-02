# Replication Package: The Effect of Increasing Human Capital Investment on Economic Growth and Poverty

**Authors:** Matthew Collin and David N. Weil

**Journal:** *Journal of Human Capital*, Vol. 14, No. 1 (Spring 2020), pp. 105–147

**DOI:** [10.1086/708195](https://doi.org/10.1086/708195)

## Description

This repository contains the data and code needed to replicate the tables and figures in the paper. The analysis uses a calibrated simulation model to project how increases in human capital investment (health, education, and stunting reduction) affect economic growth and poverty over a 50-year horizon. The paper covers 157 countries and reports results aggregated by World Bank income group.

## Software Requirements

- **Stata 15 or later** (MP edition recommended for speed; tested with StataNow 18.5 MP)
- **Python 3.8+** (optional, only needed to regenerate the 2019-vintage World Bank data file or the HTML replication report)
- All required Stata packages are bundled in `code/ado/` — no manual installation needed

### Bundled Stata Packages

| Package | Purpose |
|---------|---------|
| `mmerge` | Flexible merge command |
| `kountry` | Country name/code conversion |
| `texresults` | Export Stata scalars to LaTeX macros |
| `wbopendata` | World Bank Open Data API access |

## Replication Instructions

1. **Download the repository** and ensure all input data files are in `input/`. One file (`hci_data_21Sept2018_FINAL.dta`, 111 MB) exceeds GitHub's size limit — see [`input/README.md`](input/README.md) for download instructions.

2. **Set the root path.** Open `master.do` and change line 20:
   ```stata
   global root "C:\github-repos\replicate_human_capital"
   ```
   to the path where you placed the repository.

3. **Run `master.do`** in Stata. It will:
   - Set all relative paths
   - Load bundled packages from `code/ado/`
   - Execute all analysis scripts in order
   - Produce all figures in `figures_tables/` and all intermediate datasets in `output/`

4. **Labor force participation (Figures 10–11):** These must be run separately in a clean Stata session because `npregress kernel` estimates conflict with the main pipeline. After setting globals, run:
   ```stata
   do "$do/labor_participation.do"
   ```

**Estimated total runtime:** ~30 minutes (Stata MP on a modern machine; Step 4 / NPV calculations is the bottleneck at ~15 min).

## File Structure

```
replicate_human_capital/
├── master.do                     # Entry point — sets paths, runs all scripts
├── replicate.md                  # Detailed replication guide with run order
├── README.md                     # This file
├── .gitignore
├── code/                         # All analysis scripts
│   ├── (1) assemble.do
│   ├── (2) hc_simulation.do
│   ├── (3) hc_worldprojections.do
│   ├── (4) npv_calculations.do
│   ├── (5) cambodia_counterfactual.do
│   ├── (6) hc_education_compare.do
│   ├── (7) fertility_table3.do
│   ├── 1.1 (background) barrolee_ihme_conversion.do
│   ├── 2.1 (background) scenario.do
│   ├── labor_participation.do
│   ├── lastgraph.grec
│   ├── download_wb_2019_vintage.py
│   ├── generate_replication_report.py
│   └── ado/                      # Bundled Stata packages
├── input/                        # Raw input data (read-only)
│   └── README.md                 # Data descriptions and sources
├── output/                       # Generated intermediate datasets
├── figures_tables/               # Generated figures and tables
└── analysis/                     # Replication reports (HTML/PDF)
```

## What the Scripts Produce

| Script | Outputs |
|--------|---------|
| (1) `assemble.do` | Assembled master dataset in `output/` |
| (2) `hc_simulation.do` | HC projections and simulation results |
| (3) `hc_worldprojections.do` | Figures 2–7 (world projections by income group) |
| (4) `npv_calculations.do` | Figure 9 (NPV scatterplot) |
| (5) `cambodia_counterfactual.do` | Figure 8 (Cambodia counterfactual) |
| (6) `hc_education_compare.do` | Appendix Figures A.1–A.4 (secondary vs. tertiary) |
| (7) `fertility_table3.do` | Table 3 (fertility channel) |
| `labor_participation.do` | Figures 10–11 (labor force participation, standalone) |

## Replication Notes

### Table 3 (Fertility Channel)
Table 3 in the published paper was computed outside of Stata. Script (7) replicates it using population-weighted averages with the log-elasticity formula from Section 6.1. Results match 8 of 24 cells exactly; the remainder are within 0.1–0.5 percentage points, consistent with intermediate rounding in the original calculation.

### Figure 9 (NPV Scatterplot)
The World Bank revises historical expenditure data over time. To exactly replicate Figure 9, script (4) uses a December 2019 vintage of the WDI data (`wb_health_education_expenditure_2019vintage.dta`), downloaded via the Python script `code/download_wb_2019_vintage.py`.

### Figures 10–11 (Labor Force Participation)
`labor_participation.do` uses `npregress kernel`, which conflicts with stored estimation results from the main pipeline. It must be run in a fresh Stata session.

## Data Availability

All input data are publicly available. See [`input/README.md`](input/README.md) for detailed sources and download instructions for the one file not included in this repository due to size.

## License

This replication package is provided for academic and research purposes.
