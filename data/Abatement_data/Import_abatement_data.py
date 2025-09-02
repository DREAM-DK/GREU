# -*- coding: utf-8 -*-
"""
Created on Wed March 12 2025

@author: Louis Birk Stewart
"""

import os
import dreamtools as dt
import pandas as pd
import gamspy as gp
import math

## Set local paths
root = dt.find_root("LICENSE")
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
                   'Potential (Share of energy demand)':"sqTPotential",
                   'Energy intensity (PJ in per PJ out)':"uTE",
                   'Investment costs (billion EUR per PJ out)':"vTI",
                   'Variable capital costs (billion EUR per PJ out)':"vTC",
                   'Energy price (billion EUR per PJ in)':"pTE_base",
                   'Energy tax (billion EUR per PJ in)':"pTE_tax",
                   'Capital cost index':"pTK",
                   'Energy service (PJ out)':"qES",
                   'Technical lifespan (years)':"LifeSpan"
                   }

# DATA FOR TECHNOLOGIES
# Reading data from excel
df_technologies = pd.read_excel(file_name,sheet_name='Technologies')
# Drop columns that does not enter the model
df_technologies = df_technologies.drop(columns = drop_cols_list)
# Rename columns to match names in the model
df_technologies = df_technologies.rename(columns=rename_col_list)   
# Set index for dataframe
df_technologies = df_technologies.set_index(['l','es','i','t']) 

# Create dataframe with sqTPotential, vTI, vTC and LifeSpan
df_sqTPotential = pd.DataFrame(df_technologies['sqTPotential'])
df_vTI = pd.DataFrame(df_technologies['vTI'])
df_vTC = pd.DataFrame(df_technologies['vTC'])
df_LifeSpan = pd.DataFrame(df_technologies['LifeSpan'])

# Reset index for dataframes
df_sqTPotential = df_sqTPotential.reset_index()
df_vTI = df_vTI.reset_index()
df_vTC = df_vTC.reset_index()
df_LifeSpan = df_LifeSpan.reset_index()

# DATA FOR ENERGY INPUT
# Reading data from excel
df_uTE = pd.read_excel(file_name,sheet_name='Energy input')
# Rename columns to match names in the model
df_uTE = df_uTE.rename(columns=rename_col_list)   
# Rearranging columns to match model dimensions
df_uTE = df_uTE.set_index(['l','e'])
# Resettign index
df_uTE = df_uTE.reset_index()

# DATA FOR ENERGY PRICE
# Reading data from excel
df_energy_price = pd.read_excel(file_name,sheet_name='Energy price')
# Rename columns to match names in the model
df_energy_price = df_energy_price.rename(columns=rename_col_list)   
# Rearranging columns to match model dimensions
df_energy_price = df_energy_price.set_index(['es','e','i','t'])
# Resettign index
df_energy_price = df_energy_price.reset_index()

# DATA FOR ENERGY TAX
# Reading data from excel
df_energy_tax = pd.read_excel(file_name,sheet_name='Energy tax')
# Rename columns to match names in the model
df_energy_tax = df_energy_tax.rename(columns=rename_col_list)   
# Rearranging columns to match model dimensions
df_energy_tax = df_energy_tax.set_index(['es','e','i','t'])
# Re-setting index
df_energy_tax = df_energy_tax.reset_index()

# DATA FOR CAPITAL COST INDEX
# Reading data from excel
df_capital_cost_index = pd.read_excel(file_name,sheet_name='Capital cost index')
# Rename columns to match names in the model
df_capital_cost_index = df_capital_cost_index.rename(columns=rename_col_list)   
# Determining columns as strings in order to avoid issues with GDX export
df_capital_cost_index["i"] = df_capital_cost_index["i"].astype(str)
df_capital_cost_index["t"] = df_capital_cost_index["t"].astype(str)

# DATA FOR ENERGY SERVICE
# Reading data from excel
df_energy_service = pd.read_excel(file_name,sheet_name='Energy service')
# Rename columns to match names in the model
df_energy_service = df_energy_service.rename(columns=rename_col_list)   
# Set index for dataframe
df_energy_service = df_energy_service.set_index(['es','i','t'])
# Re-setting index
df_energy_service = df_energy_service.reset_index()

# SETS
# Reading data from excel
df_sets = pd.read_excel(file_name,sheet_name='Model sets')

# ------------------------------------------------------------------
## EXPORTING DATA TO GDX FILE
# ------------------------------------------------------------------

# Create empty database
db_abatement=gp.Container()

# Creating list with model sets
set_technologies_list=list(df_sets['Set for technologies (TechID)'].unique())
set_energy_input_list=list(df_sets['Set for energy input (e) '].unique())
set_energy_service_list=list(df_sets['Set for energy service (es)'].unique())
set_industry_list=list(df_sets['Set for industry (d)'].unique())
set_year_list=list(df_sets['Set for year (t)'].unique())

# Removing missing values in list with model sets
set_energy_input_list = [x for x in set_energy_input_list if not (isinstance(x, float) and math.isnan(x)) and x is not None]
set_energy_service_list = [x for x in set_energy_service_list if not (isinstance(x, float) and math.isnan(x)) and x is not None]
set_industry_list = [x for x in set_industry_list if not (isinstance(x, float) and math.isnan(x)) and x is not None]
set_year_list = [x for x in set_year_list if not (isinstance(x, float) and math.isnan(x)) and x is not None]

# Setting year list to integers
set_year_list = [int(d) for d in set_year_list]

# Adding sets to database
l=gp.Set(db_abatement,name='l',description='Technologies',records=set_technologies_list)
e=gp.Set(db_abatement,name='e',description='Energy input',records=set_energy_input_list)
es=gp.Set(db_abatement,name='es',description='Energy service',records=set_energy_service_list)
i=gp.Set(db_abatement,name='i',description='Industry',records=set_industry_list)
t=gp.Set(db_abatement,name='t',description='Year',records=set_year_list)

# Adding parameters to database
sqTPotential=gp.Parameter(db_abatement,name='sqTPotential',domain=[l,es,i,t],description='Potential supply by technology l in ratio of energy service (share of qES)',records=df_sqTPotential.values.tolist())
uTE=gp.Parameter(db_abatement,name='uTE_load',domain=[l,e],description='Input of energy in technology l per PJ output at full potential',records=df_uTE.values.tolist())
vTI=gp.Parameter(db_abatement,name='vTI',domain=[l,es,i,t],description='Investment costs in technology l per PJ output at full potential',records=df_vTI.values.tolist())
vTC=gp.Parameter(db_abatement,name='vTC',domain=[l,es,i,t],description='Variable capital costs in technology l per PJ output at full potential',records=df_vTC.values.tolist())
LifeSpan=gp.Parameter(db_abatement,name='LifeSpan',domain=[l,es,i,t],description='Technical lifespan of technology l',records=df_LifeSpan.values.tolist())
pTE_base=gp.Parameter(db_abatement,name='pTE_base',domain=[es,e,i,t],description='Base price of energy input',records=df_energy_price.values.tolist())
pTE_tax=gp.Parameter(db_abatement,name='pTE_tax',domain=[es,e,i,t],description='Tax on energy input',records=df_energy_tax.values.tolist())
pTK=gp.Parameter(db_abatement,name='pTK',domain=[i,t],description='User cost of capital in technologies for energy services',records=df_capital_cost_index.values.tolist())
qES=gp.Parameter(db_abatement,name='qES',domain=[es,i,t],description='Energy service, quantity',records=df_energy_service.values.tolist())

# Export gdx-file with abatement data
db_abatement.write('Abatement_dummy_data.gdx')

# db_abatement.close()