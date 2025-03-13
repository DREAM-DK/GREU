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
## READING AND MANIPULATING DATA
# ------------------------------------------------------------------

# Name of data file
file_name = "Abatement_dummy_data.xlsx"

# Reading data from excel
df = pd.read_excel(file_name,sheet_name='Ark1')

# Drop columns that does not enter the model
drop_cols_list = ["Tech type"]
df = df.drop(columns = drop_cols_list)
df.columns

# Rename columns to match names in the model
rename_col_list = {'TechID':"l",
                   'Sector':"d",
                   'Energy service':"es",
                   'Energy input':"e",
                   'Year':"t",
                   'Potential (Share of energy demand)':"sTPotential",
                   'Relative energy use (share)':"uTE",
                   'Levelised capital costs (billion EUR per PJ)':"uTK",
                   }

df = df.rename(columns=rename_col_list)   

# Set index for dataframe
df = df.set_index(['l','d','es','e','t']) 

# Create dataframe with sTPotential, uTE and uTK
df_sTPotential = pd.DataFrame(df['sTPotential'])
df_uTE = pd.DataFrame(df['uTE'])
df_uTK = pd.DataFrame(df['uTK'])

# ------------------------------------------------------------------
## EXPORTING DATA TO GDX FILE
# ------------------------------------------------------------------
# Create series that can be exported to database
sTPotential_series = pd.Series(df_sTPotential["sTPotential"], index=df_sTPotential.index)
uTE_series = pd.Series(df_uTE["uTE"], index=df_uTE.index)
uTK_series = pd.Series(df_uTK["uTK"], index=df_uTK.index)

# Create empty GAMS database
db = dt.GamsPandasDatabase()
# GAMS-Pandas settings
Par, Var, Set = db.create_parameter, db.create_variable, db.create_set

# Add data to database
db.add_variable_from_series(sTPotential_series, explanatory_text = 'Potential supply by technology l in ratio of energy service (share of qES)', add_missing_domains=True)
db.add_variable_from_series(uTE_series, explanatory_text = 'Input of energy in technology l per PJ output at full potential', add_missing_domains=True)
db.add_variable_from_series(uTK_series, explanatory_text = 'Input of machinery capital in technology l per PJ output output at full potential', add_missing_domains=True)

# Export gdx-file with abatement data
db.export("Abatement_dummy_data.gdx")
