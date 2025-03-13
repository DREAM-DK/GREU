# -*- coding: utf-8 -*-
"""
Created on Wed March 12 2025

@author: Louis Birk Stewart
"""

import os
import dreamtools as dt
import pandas as pd

## Set local paths
root = dt.find_root()
## Set working directory
os.chdir(fr"{root}/data/Abatement_data")

# ------------------------------------------------------------------
## READING DATA
# ------------------------------------------------------------------

# Name of data file
file_name = "Abatement_dummy_data.xlsx"

# Define list for columns that need to be dropped
drop_cols_list = ["Tech type"]

# Define list for renaming columns to match names in the model
rename_col_list = {'TechID':"l",
                   'Industry':"i",
                   'Energy service':"es",
                   'Energy input':"e",
                   'Year':"t",
                   'Potential (Share of energy demand)':"sTPotential",
                   'Energy intensity (PJ in per PJ out)':"uTE",
                   'Capital intensity (billion EUR per PJ out)':"uTK",
                   'Energy price (billion EUR per PJ in)':"pT_e_base",
                   'Energy tax (billion EUR per PJ in)':"pT_e_tax",
                   'Capital cost index':"pT_k",
                   'Energy service (PJ out)':"qES",
                   }

# DATA FOR TECHNOLOGIES
# Reading data from excel
df_technologies = pd.read_excel(file_name,sheet_name='Technologies')

# Drop columns that does not enter the model
df_technologies = df_technologies.drop(columns = drop_cols_list)

# Rename columns to match names in the model
df_technologies = df_technologies.rename(columns=rename_col_list)   

# Set index for dataframe
df_technologies = df_technologies.set_index(['l','es','e','i','t']) 

# Create dataframe with sTPotential, uTE and uTK
df_sTPotential = pd.DataFrame(df_technologies['sTPotential'])
df_uTE = pd.DataFrame(df_technologies['uTE'])
df_uTK = pd.DataFrame(df_technologies['uTK'])

# Drop energy dimension for sTPotential and uTK
df_sTPotential = df_sTPotential.reset_index()
df_sTPotential = df_sTPotential.drop(columns = 'e')
df_sTPotential = df_sTPotential.set_index(['l','es','i','t'])

df_uTK = df_uTK.reset_index()
df_uTK = df_uTK.drop(columns = 'e')
df_uTK = df_uTK.set_index(['l','es','i','t'])

# DATA FOR ENERGY PRICE
# Reading data from excel
df_energy_price = pd.read_excel(file_name,sheet_name='Energy price')

# Rename columns to match names in the model
df_energy_price = df_energy_price.rename(columns=rename_col_list)   

# Set index for dataframe
df_energy_price = df_energy_price.set_index(['es','e','i','t'])

# DATA FOR ENERGY PRICE
# Reading data from excel
df_energy_tax = pd.read_excel(file_name,sheet_name='Energy tax')

# Rename columns to match names in the model
df_energy_tax = df_energy_tax.rename(columns=rename_col_list)   

# Set index for dataframe
df_energy_tax = df_energy_tax.set_index(['es','e','i','t'])

# DATA FOR CAPITAL COST INDEX
# Reading data from excel
df_capital_cost_index = pd.read_excel(file_name,sheet_name='Capital cost index')

# Rename columns to match names in the model
df_capital_cost_index = df_capital_cost_index.rename(columns=rename_col_list)   

# Set index for dataframe
df_capital_cost_index = df_capital_cost_index.set_index(['i','t'])

# DATA FOR ENERGY SERVICE
# Reading data from excel
df_energy_service = pd.read_excel(file_name,sheet_name='Energy service')

# Rename columns to match names in the model
df_energy_service = df_energy_service.rename(columns=rename_col_list)   

# Set index for dataframe
df_energy_service = df_energy_service.set_index(['es','i','t'])


# ------------------------------------------------------------------
## EXPORTING DATA TO GDX FILE
# ------------------------------------------------------------------
# Create series that can be exported to database
sTPotential_series = pd.Series(df_sTPotential["sTPotential"], index=df_sTPotential.index)
uTE_series = pd.Series(df_uTE["uTE"], index=df_uTE.index)
uTK_series = pd.Series(df_uTK["uTK"], index=df_uTK.index)
pT_e_base_series = pd.Series(df_energy_price["pT_e_base"], index=df_energy_price.index)
pT_e_tax_series = pd.Series(df_energy_tax["pT_e_tax"], index=df_energy_tax.index)
pT_k_series = pd.Series(df_capital_cost_index["pT_k"], index=df_capital_cost_index.index)
qES_series = pd.Series(df_energy_service["qES"], index=df_energy_service.index)

# Create empty GAMS database
db = dt.GamsPandasDatabase()
# GAMS-Pandas settings
Par, Var, Set = db.create_parameter, db.create_variable, db.create_set

# Add data to database
db.add_variable_from_series(sTPotential_series, explanatory_text = 'Potential supply by technology l in ratio of energy service (share of qES)', add_missing_domains=True)
db.add_variable_from_series(uTE_series, explanatory_text = 'Input of energy in technology l per PJ output at full potential', add_missing_domains=True)
db.add_variable_from_series(uTK_series, explanatory_text = 'Input of machinery capital in technology l per PJ output output at full potential', add_missing_domains=True)
db.add_variable_from_series(pT_e_base_series, explanatory_text = 'Base price of energy input', add_missing_domains=True)
db.add_variable_from_series(pT_e_tax_series, explanatory_text = 'Tax on energy input', add_missing_domains=True)
db.add_variable_from_series(pT_k_series, explanatory_text = 'User cost of capital in technologies for energy services', add_missing_domains=True)
db.add_variable_from_series(qES_series, explanatory_text = 'Energy service, quantity.', add_missing_domains=True)

# Export gdx-file with abatement data
db.export("Abatement_dummy_data.gdx")
