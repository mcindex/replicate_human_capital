"""
Download 2019-vintage World Bank health/education expenditure data
from the WDI Database Archives (source 57, version 201912).

Indicators:
  SE.XPD.TOTL.GD.ZS  — Government expenditure on education (% GDP)
  SH.XPD.CHEX.GD.ZS  — Current health expenditure (% GDP)

Output: input/wb_health_education_expenditure_2019vintage.dta
"""

import wbgapi as wb
import pandas as pd
import numpy as np
import os

ROOT = r"C:\github-repos\replicate_human_capital"
OUTPUT_PATH = os.path.join(ROOT, "input", "wb_health_education_expenditure_2019vintage.dta")
VERSION = '201912'

print(f"Downloading WDI Archives (db=57) version {VERSION}...")

# Download education expenditure — include blanks so all countries appear
print("  Fetching SE.XPD.TOTL.GD.ZS (education)...")
educ_df = wb.data.DataFrame('SE.XPD.TOTL.GD.ZS', db=57, version=VERSION,
                            skipBlanks=False, columns='series')
educ_df = educ_df.reset_index()
educ_df.columns = ['countrycode', 'time', 'educ_gdp']
educ_df['year'] = educ_df['time'].str.replace('YR', '').astype(int)
educ_df = educ_df.drop(columns=['time'])
print(f"    {len(educ_df)} rows, {educ_df['countrycode'].nunique()} countries")
print(f"    Non-null educ: {educ_df['educ_gdp'].notna().sum()}")

# Download health expenditure
print("  Fetching SH.XPD.CHEX.GD.ZS (health)...")
health_df = wb.data.DataFrame('SH.XPD.CHEX.GD.ZS', db=57, version=VERSION,
                              skipBlanks=False, columns='series')
health_df = health_df.reset_index()
health_df.columns = ['countrycode', 'time', 'health_gdp']
health_df['year'] = health_df['time'].str.replace('YR', '').astype(int)
health_df = health_df.drop(columns=['time'])
print(f"    {len(health_df)} rows, {health_df['countrycode'].nunique()} countries")
print(f"    Non-null health: {health_df['health_gdp'].notna().sum()}")

# Merge
print("  Merging...")
merged = pd.merge(educ_df, health_df, on=['countrycode', 'year'], how='outer')
merged = merged.sort_values(['countrycode', 'year']).reset_index(drop=True)

# Add metadata columns (matching the structure of the current file)
merged['countryname'] = ''
merged['region'] = ''
merged['regionname'] = ''
merged['adminregion'] = ''
merged['adminregionname'] = ''
merged['incomelevel'] = ''
merged['incomelevelname'] = ''
merged['lendingtype'] = ''
merged['lendingtypename'] = ''

# Reorder columns to match current file
col_order = ['countrycode', 'countryname', 'region', 'regionname',
             'adminregion', 'adminregionname', 'incomelevel', 'incomelevelname',
             'lendingtype', 'lendingtypename', 'year', 'educ_gdp', 'health_gdp']
merged = merged[col_order]

# Cast types to match
merged['year'] = merged['year'].astype(np.int16)
merged['educ_gdp'] = merged['educ_gdp'].astype(np.float32)
merged['health_gdp'] = merged['health_gdp'].astype(np.float32)

print(f"\nFinal dataset: {merged.shape[0]} rows, {merged.shape[1]} columns")
print(f"Countries: {merged['countrycode'].nunique()}")
print(f"Year range: {merged['year'].min()} - {merged['year'].max()}")
print(f"Educ non-null: {merged['educ_gdp'].notna().sum()}")
print(f"Health non-null: {merged['health_gdp'].notna().sum()}")

# Save
merged.to_stata(OUTPUT_PATH, write_index=False, version=118)
print(f"\nSaved to: {OUTPUT_PATH}")

# Compare with current (2026) file
CURRENT_PATH = os.path.join(ROOT, "input", "wb_health_education_expenditure.dta")
current = pd.read_stata(CURRENT_PATH)
print(f"\n--- Comparison ---")
print(f"Current (2026): {current.shape[0]} rows, {current['countrycode'].nunique()} countries, "
      f"educ={current['educ_gdp'].notna().sum()}, health={current['health_gdp'].notna().sum()}")
print(f"Archive (2019): {merged.shape[0]} rows, {merged['countrycode'].nunique()} countries, "
      f"educ={merged['educ_gdp'].notna().sum()}, health={merged['health_gdp'].notna().sum()}")
