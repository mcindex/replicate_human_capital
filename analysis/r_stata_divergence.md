# R vs Stata Validation: Summary of Divergences

## Overview

We validate the R replication against the Stata output at the observation level, comparing 331,666 variable-by-observation pairs across six stages of the analysis pipeline. We classify each comparison by the percentage difference between R and Stata values.

## Final Validation Results

| Category | Count | Share |
|----------|------:|------:|
| Exact match (<0.0001%) | 248,207 | 74.8% |
| Close (<0.1%) | 82,644 | 24.9% |
| Acceptable (<1%) | 268 | 0.1% |
| Warning (1-5%) | 469 | 0.1% |
| Divergent (>5%) | 78 | 0.02% |

**99.7% of all comparisons are exact or close (<0.1%).**

## Stages with Perfect Agreement

The following stages produce identical or near-identical results between R and Stata:

- **01_assemble**: All 13 variables across 1,690 observations match exactly. The one exception is `gini`, where 24 observations differ by up to 0.6% due to a minor difference in how R's `approx()` and Stata's `ipolate` handle interpolation at boundary points.

- **02_hcpw_projections**: All 7 variables across 23,328 age-bin-level HC projections are exact matches.

- **02_hc_projections (primary)**: All HC per worker projections (6 scenarios) match exactly. All GDP per capita projections (6 scenarios) are within 0.001%. All capital and productivity variables are within 0.001%.

- **02_hc_projections (tertiary)**: After fixing the tertiary scenario scalar computation (see below), all HC and GDP variables match to within 0.001%.

- **07_table3**: All 8 Table 3 variables match the Stata output exactly or to within 0.1%.

## Sources of Remaining Divergence

### 1. Poverty Projections Near Zero (49 divergent observations)

The poverty projection formula maps GDP per capita changes through a log-normal distribution:

$$\text{pov}(t) = \Phi\left(\Phi^{-1}(\text{pov}_0) - \frac{1}{\sigma} \ln \frac{\text{GDP}_{pc}(t)}{\text{GDP}_{pc}(0)}\right)$$

When initial poverty is very small (approaching zero), $\Phi^{-1}(\text{pov}_0)$ approaches $-\infty$, and small numerical differences in the GDP per capita ratio are amplified into large percentage differences in the poverty rate. This is a well-known property of the inverse normal transformation at the tails.

The affected observations are concentrated in Indonesia (IDN), where the $1.90 poverty rate is extremely low (< 2%), and China (CHN). The absolute differences are negligible (e.g., poverty of 0.008 vs 0.009), but the percentage metric registers them as large.

These differences arise from tiny floating-point discrepancies in the GDP per capita computation (always < 0.01%) that are amplified by the nonlinear poverty formula.

### 2. NPV Grid Search (29 divergent observations)

The NPV calculation in Step 4 uses a grid search to find the gross capital formation (GCF) rate that produces a present value of GDP gains equivalent to the optimistic human capital scenario. Both R and Stata search in increments of 0.001 (0.1 percentage points).

Because the underlying GDP simulation involves compounding over 35 years with a 4% discount rate, two GCF values that differ by a single increment (0.001) can produce present values that are quite close to the target. R and Stata occasionally converge on adjacent grid points, producing GCF estimates that differ by one step (0.1pp). In percentage terms, this can appear as a 5-10% difference, but the economic magnitude is trivial.

## Bugs Found and Fixed During Validation

### In the R code

1. **Tertiary scenario: unconditional replace** (`scenario_calc.R`). Stata's `replace eyrs_mf = eyrs_mf + yr_sch_ter` sets `eyrs_mf` to missing when `yr_sch_ter` is missing — this restricts the subsequent median calculations to only countries with Barro-Lee tertiary data. The R code initially preserved `eyrs_mf` for non-Barro-Lee countries, producing different medians (N=80 vs N=61 at the growth rate stage, N=162 vs N=135 at the levels stage). Fixing this brought the tertiary scenario scalars from 2.2%/5.4% to 2.3%/5.6%, matching Stata exactly.

2. **IHME conversion intercept** (`01_assemble.R`). The original Stata code uses `scalar bicons = _cons`, where `_cons` in Stata evaluates to the system constant 1, not the regression intercept `_b[_cons]` = -0.854. The R code initially used the regression intercept. Setting `bicons <- 1` to match Stata's actual behavior resolved all IHME schooling divergences.

3. **Sub-national IHME entries** (`01_assemble.R`). R's `countrycode` package mapped "Northern Ireland" (location_id=433) and "Sweden except Stockholm" (location_id=4940) to GBR and SWE respectively, creating duplicates. Stata's `kountry` command does not map these sub-national entries. Filtering them out resolved the country-count mismatch (145 vs 144; BLZ is the remaining R-only country, which has Barro-Lee data but was not in the original Stata analysis).

4. **Gini interpolation** (`01_assemble.R`). Stata uses `ipolate` for linear interpolation of Gini coefficients to year 2015. The R code initially took the first non-missing Gini value. Adding `approx()` interpolation resolved 58 previously divergent observations.

5. **10-year lag** (`scenario_calc.R`). The HCI data is annual, so a 10-year lag requires `lag(x, n=10)`, not `lag(x, n=2)` as was initially coded.
