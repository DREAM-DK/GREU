"""
Import energy technology data from Excel and export to GDX.

Reads technology parameters, energy input coefficients, capital cost indices,
energy service quantities, and model sets from an Excel workbook
(Energy_technology_data.xlsx). The data is validated, renamed to match GAMS
model conventions, and exported as a GDX file for use in the GREU energy
demand model.

Note: To use the exported GDX file, the setting %generic_energy_technology_data% 
must be set to 0 in the model/settings.gms file.

@author: Louis Birk Stewart
"""

import os
import dreamtools as dt
import pandas as pd
import gamspy as gp

## Set local paths
root = dt.find_root("LICENSE")
data_dir = os.path.join(root, "data", "Energy_technology_data", "Excel_data")

# ------------------------------------------------------------------
## READING DATA
# ------------------------------------------------------------------

# Path to data file
file_path = os.path.join(data_dir, "Energy_technology_data.xlsx")

# Validate that all expected sheets exist
expected_sheets = ['Technologies', 'Energy input', 'Capital cost index', 'Energy service', 'Model sets']
available_sheets = pd.ExcelFile(file_path).sheet_names
for sheet in expected_sheets:
    if sheet not in available_sheets:
        raise ValueError(f"Expected sheet '{sheet}' not found in {file_path}")

# Define list for columns that need to be dropped
drop_cols_list = ["Tech type"]

# Define list for renaming columns to match names in the model
rename_col_list = {'TechID':"l",
                   'Industry':"i",
                   'Energy service':"es",
                   'Energy input':"e",
                   'Year':"t",
                   'Potential (Share of energy demand)':"sqTPotential",
                   'Energy intensity (PJ in per PJ out)':"uTE",
                   'Investment costs (billion EUR per PJ out)':"vTI",
                   'Variable capital costs (billion EUR per PJ out)':"vTC",
                   'Capital cost index':"pTK",
                   'Energy service (PJ out)':"qES",
                   'Technical lifespan (years)':"LifeSpan"
                   }

# DATA FOR TECHNOLOGIES
# Reading data from excel
df_technologies = pd.read_excel(file_path,sheet_name='Technologies')
# Drop columns that does not enter the model
df_technologies = df_technologies.drop(columns = drop_cols_list)
# Rename columns to match names in the model
df_technologies = df_technologies.rename(columns=rename_col_list)
# Set index for dataframe
df_technologies = df_technologies.set_index(['l','es','i','t'])

# Extract individual parameter DataFrames with index columns restored
tech_params = {col: df_technologies[[col]].reset_index() for col in ['sqTPotential', 'vTI', 'vTC', 'LifeSpan']}

# DATA FOR ENERGY INPUT
# Reading data from excel
df_uTE = pd.read_excel(file_path,sheet_name='Energy input')
# Rename and reorder columns to match model dimensions
df_uTE = df_uTE.rename(columns=rename_col_list)[['l','e','uTE']]

# DATA FOR CAPITAL COST INDEX
# Reading data from excel
df_capital_cost_index = pd.read_excel(file_path,sheet_name='Capital cost index')
# Rename columns to match names in the model
df_capital_cost_index = df_capital_cost_index.rename(columns=rename_col_list)
# Determining columns as strings in order to avoid issues with GDX export
df_capital_cost_index["i"] = df_capital_cost_index["i"].astype(str)
df_capital_cost_index["t"] = df_capital_cost_index["t"].astype(str)

# DATA FOR ENERGY SERVICE
# Reading data from excel
df_energy_service = pd.read_excel(file_path,sheet_name='Energy service')
# Rename and reorder columns to match model dimensions
df_energy_service = df_energy_service.rename(columns=rename_col_list)[['es','i','t','qES']]

# SETS
# Reading data from excel
df_sets = pd.read_excel(file_path,sheet_name='Model sets')
df_sets.columns = df_sets.columns.str.strip()

# ------------------------------------------------------------------
## EXPORTING DATA TO GDX FILE
# ------------------------------------------------------------------

# Create empty database
db_energy_tech=gp.Container()

def clean_set_column(df, col_name):
    """Extract unique non-null values from a DataFrame column."""
    return df[col_name].dropna().unique().tolist()

# Creating list with model sets
set_technologies_list = clean_set_column(df_sets, 'Set for technologies (TechID)')
set_energy_input_list = clean_set_column(df_sets, 'Set for energy input (e)')
set_energy_service_list = clean_set_column(df_sets, 'Set for energy service (es)')
set_industry_list = clean_set_column(df_sets, 'Set for industry (d)')
set_year_list = [int(d) for d in clean_set_column(df_sets, 'Set for year (t)')]

# Adding sets to database
set_l=gp.Set(db_energy_tech,name='l',description='Technologies',records=set_technologies_list)
set_e=gp.Set(db_energy_tech,name='e',description='Energy input',records=set_energy_input_list)
set_es=gp.Set(db_energy_tech,name='es',description='Energy service',records=set_energy_service_list)
set_i=gp.Set(db_energy_tech,name='i',description='Industry',records=set_industry_list)
set_t=gp.Set(db_energy_tech,name='t',description='Year',records=set_year_list)

# Adding parameters to database
sqTPotential=gp.Parameter(db_energy_tech,name='sqTPotential',domain=[set_l,set_es,set_i,set_t],description='Potential supply by technology l in ratio of energy service (share of qES)',records=tech_params['sqTPotential'])
uTE=gp.Parameter(db_energy_tech,name='uTE_load',domain=[set_l,set_e],description='Input of energy in technology l per PJ output at full potential',records=df_uTE)
vTI=gp.Parameter(db_energy_tech,name='vTI',domain=[set_l,set_es,set_i,set_t],description='Investment costs in technology l per PJ output at full potential',records=tech_params['vTI'])
vTC=gp.Parameter(db_energy_tech,name='vTC',domain=[set_l,set_es,set_i,set_t],description='Variable capital costs in technology l per PJ output at full potential',records=tech_params['vTC'])
LifeSpan=gp.Parameter(db_energy_tech,name='LifeSpan',domain=[set_l,set_es,set_i,set_t],description='Technical lifespan of technology l',records=tech_params['LifeSpan'])
pTK=gp.Parameter(db_energy_tech,name='pTK',domain=[set_i,set_t],description='User cost of capital in technologies for energy services',records=df_capital_cost_index)
qES=gp.Parameter(db_energy_tech,name='qES',domain=[set_es,set_i,set_t],description='Energy service, quantity',records=df_energy_service)

# Export gdx-file with energy technology data
db_energy_tech.write(os.path.join(data_dir, 'Energy_technology_data.gdx'))

db_energy_tech.close()
