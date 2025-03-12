# -*- coding: utf-8 -*-
"""
Created on Wed March 12 2025

@author: Louis Birk Stewart
"""

import os
import dreamtools as dt
import pandas as pd
import xlwings as xw

path = "C:/Users/b165541/Documents/"

os.chdir(path)


# %%
# ------------------------------------------------------------------#

# Navn på datafil
file_name = "testupload.xlsx"
app = xw.App()
wb = xw.Book(file_name)

x1 = pd.read_excel(file_name,sheet_name='Ark1')

# t_list_input = [2025,2030,2035] # Angiver årene for hvilke vi har teknologier
# s = "MO CCS"


# # %% Følgende loop indsætter årstal [2025,2030,2035] i fanen og indlæser indholdet ind i en dictionary

# x1 = {}

# for t in t_list_input:
#     wb.sheets['Hovedmenu']['D7'].value = t
#     # time.sleep(20)
#     wb.save()
#     x1[s,t] = pd.read_excel(file_name,sheet_name=s,header=10)
#     x1[s,t]['t']=t
#     x1[s,t]['s_cat']=s[3:]
#     x1[s,t] = x1[s,t].reset_index().rename(columns={"index":"sheetID_data"})
#     print(t)


# # %% 
# df = pd.concat(x1.values())
# # Drop søjler
# df = df.loc[:,~df.columns.str.contains("Unnamed")]
# df = df.drop(columns=["Case"])                             
# df = df.reset_index()

# df["tech_cost_energy"] = df['Reduktionsomkostning (kr./ton CO2)']-df['Reduktionsomkostning ekskl. brændsel- og elforbrug (kr./ton CO2)']
# # Rename 
# df.columns

# # Laver liste med ændring af kolonnenavne
#     # Navne vælges: syntaksen er {"gammelt navn1":"nytnavn1", "gammelt navn2":"nytnavn2"}
#     # (For en god ordens skyld, så check at det navn der lige nu bruges også opdateres senere i koden, hvis der henvises til det
#     # - brug crtl-F)
# rename_col_list = {'CO2-besparelse (kton CO2)':"CO2_potential_kt",
#                    'Beskrivelse af reduktionstiltag':'Reduktionstiltag',
#                    'Reduktionsomkostning ekskl. brændsel- og elforbrug (kr./ton CO2)':'tech_cost_capital',
#                    'Reduktionsomkostning (kr./ton CO2)':"tech_cost",
#                    'tech_cost_energy':'tech_cost_energy'
#                    }

# df = df.rename(columns=rename_col_list)                       # Ændrer kolonnenavne

# # Sæt et techCCS_data på der matcher det i selve arket. 
# df['techCCS'] = (df['sheetID_data']+1).astype(int).astype(str)
# #df.techCCS = df.techCCS.str.zfill(2)
# df['techCCS'] = "t"+ df['techCCS']

# # Teknologierne kan skifte rækkefølge i løbet af årene. Navngivningen laves ud fra rækkefølgen i 2025
# df2025 = df.copy()[df['t']==2025] # Dataframe for 2025-data
# # Liste med kolonner der identificere teknologierne
# tech_id_vars = ['Reduktionstiltag']
# # Beholder kun de identificerende kolonner og kolonnen med teknologinavnet
# df2025 = df2025[tech_id_vars+['techCCS']] 
# # Dropper kolonnen med teknologinavnet fra den oprindelige dataframe, da navnet skal defineres ud fra 2025 teknologinavnet 
# df = df.drop(columns=['techCCS']) 
# # Merger teknologinavne fra 2025 på den oprindelige dataframe, så teknologierne har de samme navne på tværs af årene 
# df = df.merge(df2025[tech_id_vars+["techCCS"]], how="left", on=tech_id_vars)

# # Definerer s_cat ud fra reduktionstiltag
# df["s_cat"] = df["Reduktionstiltag"].str.split(" ").str[0]

# # %% 
# df = df.dropna(subset=["Reduktionstiltag"]).sort_values(["t", "tech_cost"])
# df = df.sort_values(["sheetID_data", "t"])


# # %% 
# # drop søjler:
# drop_cols = ["sheetID_data", "Reduktionstiltag", "index"]
# df = df.drop(columns = drop_cols)
# df.columns

# # %% Struktur rigtigt
# df = df.set_index(['techCCS','s_cat','t']) # Sætter index

# # Laver dataframe med CO2_potential_ton, tech_cost_capital, og tech_cost_energy
# df_co2 = pd.DataFrame(df['CO2_potential_kt']) 
# df_tech_cost_capital = pd.DataFrame(df['tech_cost_capital']) 
# df_tech_cost_energy = pd.DataFrame(df['tech_cost_energy'])
# df_tech_cost = pd.DataFrame(df['tech_cost'])

# # Laver series til udskrivning
# co2_series = pd.Series(df_co2["CO2_potential_kt"], index=df_co2.index)
# tech_cost_capital_series = pd.Series(df_tech_cost_capital["tech_cost_capital"], index=df_tech_cost_capital.index)
# tech_cost_energy_series = pd.Series(df_tech_cost_energy["tech_cost_energy"], index=df_tech_cost_energy.index)
# tech_cost_series = pd.Series(df_tech_cost["tech_cost"], index=df_tech_cost.index)

# # %%
# #GAMS-Pandas settings
# db = dt.GamsPandasDatabase()
# Par, Var, Set = db.create_parameter, db.create_variable, db.create_set

# db.add_variable_from_series(co2_series, explanatory_text = 'CO2 Reduction Potential, kt', add_missing_domains=True)
# db.add_variable_from_series(tech_cost_capital_series, explanatory_text = 'Capital Cost, kr. pr. ton', add_missing_domains=True)
# db.add_variable_from_series(tech_cost_energy_series, explanatory_text = 'Energy Cost, kr. pr. ton', add_missing_domains=True)
# db.add_variable_from_series(tech_cost_series, explanatory_text = 'Total Cost, kr. pr. ton', add_missing_domains=True)

# db.export("EA_CCS.gdx")


# %%
