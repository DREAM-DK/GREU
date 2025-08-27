# ---------------
# Technical setup
# ---------------

import sys
import shutil
import os
import dreamtools as dt
dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"

## Set local paths
root = dt.find_root("LICENSE")
sys.path.insert(0, root)
os.environ["GAMS"] = "C:/GAMS/49/gams.exe"

## Set working directory
os.chdir(fr"{root}/model")

## Create data.gdx based on GreenREFORM-DK data 
# dt.gamY.run("../data/data_from_GR.gms")


# ---------------
# Running the base model ie. calibrating the baseline scenario
# ---------------

## Create the baseline calibration (calibration.gdx) based on GreenREFORM-DK data and exogenous assumptions
dt.gamY.run("base_model.gms")

# ---------------
# Running the shock opon the baseline model
# ---------------

# dt.gamY.run("shock_model.gms")
dt.gamY.run("shock_CO2eTax.gms")

# ---------------
# Setup for plotting and tables
# ---------------

exec(open('Report/report_settings.py').read())

# ---------------
# Specify the baseline and shock scenarios
# ---------------

dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline.gdx") # b for baseline
# s = dt.Gdx("Output/shock.gdx") # s for shock
s = dt.Gdx("Output/CO2eTax_Lumpsum2consumers.gdx") # s for shock
s2 = dt.Gdx("Output/CO2eTax_Lumpsum2gov.gdx") # s for shock


dt.time(2020, 2050)


# løbende arbejde

dt.plot([s.pY_iagg], "m", layout={"title": "Price by aggregated industries"})
dt.plot([s.qY_iagg], "pq", layout={"title": "Output by aggregated industries"})


# ---------------
# Reporting of emissions
# ---------------

dt.plot([b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], names=["Total emissions"], layout={"title": "CO2e emissions, total"})
qEmmEnergyPart = b.qCO2e_taxCategories.loc[['energy']]/b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]
dt.plot([qEmmEnergyPart], names=["Share"], layout={"title": "Energy part of CO2e emissions"})
dt.plot([s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']], s.qCO2e_taxCategories.loc[['energy']]], "m", names=["All emissions", "Energy emissions"], layout={"title": "Change in CO2e emissions"})
dt.plot([s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']], s2.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "m", names=["Lumpsum to households", "Without lumpsum"], layout={"title": "Change in total CO2e emissions"})


exec(open('Report/qEmm2030-40-50.py').read())

# Reduction on industry level
dt.plot([s.qCO2e_iagg.loc[:,['Total']]], "m", layout={"title": "CO2e emissions, industri aggregated"})
dt.plot([s.qCO2e_iagg.loc[['service'],:]], "m", layout={"title": "CO2e emissions, Services"})

exec(open('Report/qEmm_industry_tables.py').read())


#-----------------
# MACRO reporting
#-----------------


# Plot of main macroeconomic variables
dt.plot([s.pGDP, s.qGDP, s.pW], "pq", names=["GDP deflator", "Real GDP", "Wage level"], 
    layout={
        "title": "Main macroeconomic variables"
    }
)

dt.plot([s.qC, s.qG, s.qI, s.qX, s.qM], "pq", names=["Consumption", "Government consumption", "Investments", "Exports", "Imports"], 
    layout={
        "title": "Main macroeconomic variables"
    }
)

qC_Y = (s.qC/s.qGDP - b.qC/b.qGDP)*100
qG_Y = (s.qG/s.qGDP - b.qG/b.qGDP)*100
qI_Y = (s.qI/s.qGDP - b.qI/b.qGDP)*100
qX_Y = (s.qX/s.qGDP - b.qX/b.qGDP)*100
qM_Y = (s.qM/s.qGDP - b.qM/b.qGDP)*100

dt.plot([qC_Y, qG_Y, qI_Y, qX_Y, qM_Y], names=["Consumption", "Government consumption", "Investments", "Exports", "Imports"], layout={"title": "Share of GDP (%)"})


exec(open('Report/GDP_overview.py').read())


dt.plot([s.vCashFlow], "m", layout={"title": "Cash flow between sectors"})
dt.plot([s.vIncomeFlow.loc[:,['Corp'],:]], "m", layout={"title": "Cash flow between sectors"})
dt.plot([s.vIncomeFlow.loc[:,['Hh'],:]], "m", layout={"title": "Cash flow between sectors"})
dt.plot([s2.vIncomeFlow.loc[:,['Hh'],:]], "m", layout={"title": "Cash flow between sectors"})


tabel1=table(s.vIncomeFlow - b.vIncomeFlow,target_values={'t':[2035]},cols='sector')
display(tabel1)



#--------------------------------
# Reporting of public finances
#--------------------------------

dt.plot([b.vGovPrimaryBalance], names=["Baseline"], layout={"title": "Primary balance"})


dt.plot([s.vGovPrimaryBalance, b.vGovPrimaryBalance], names=["Shock", "Baseline"], layout={"title": "Primary balance"})
dt.plot(s.vGovPrimaryBalance,"m", layout={"title": "Primary balance"})

print(s.vGovPrimaryBalance[2030],s.vGovPrimaryBalance[2025])

exec(open('Report/Public_finances.py').read())

























# Gem all_tabel til Excel
all_tabel.to_excel('service_CO2e_2030.xlsx')
print("\nTabellen er gemt som 'service_CO2e_2030.xlsx'")





































tabel1=extract_table_by_name(series=s.qCO2e_iagg-b.qCO2e_iagg,target_names=[2020,2025,2030],level='t')
tabel2=extract_table_by_name(series=(s.qCO2e_iagg-b.qCO2e_iagg)/b.qCO2e_iagg*100,target_names=[2020,2025,2030],level='t')
print("Absolutte ændringer i CO2e udledninger:")
print(tabel1)
print("\nRelative ændringer i CO2e udledninger (%):")
print(tabel2)


# Niveauer i baseline for service_other CO2e udledninger i 2030
tabel_niveau = extract_table_by_name(series=b.qCO2e_service_other, target_names=[2030], level='t')
print(tabel_niveau)

# Absolutte ændringer i service_other CO2e udledninger i 2030
tabel_abs = extract_table_by_name(series=s.qCO2e_service_other-b.qCO2e_service_other, target_names=[2030], level='t')

# Relative ændringer i service_other CO2e udledninger i 2030
tabel_rel = extract_table_by_name(series=(s.qCO2e_service_other-b.qCO2e_service_other)/b.qCO2e_service_other*100, target_names=[2030], level='t')

# Saml alle tre tabeller
samlet_tabel = pd.DataFrame({
    'Baseline niveau': tabel_niveau[2030],
    'Absolut ændring': tabel_abs[2030],
    'Relativ ændring (%)': tabel_rel[2030]
})

print("\nCO2e udledninger for service_other i 2030:")
print(samlet_tabel)









tabel2=extract_table_by_name(series=s.qCO2e_iagg-b.qCO2e_iagg,target_names=[2020,2025,2030],level='t')
print("\nRelative ændringer i CO2e udledninger:")
print(tabel2)


tabel2=extract_table_by_name(series=s.qCO2e_service_other-b.qCO2e_service_other,target_names=[2020,2025,2030],level='t')
print(tabel2)








dt.plot([b.vNetFinAssets/b.vGDP], layout={"title": "Net Financial Assets to GDP"})
dt.plot([s.qGDP, s.qC, s.qI, s.qG, s.qX, s.qM], "m", function=lambda x: x/b.vGDP, names=["GDP", "C", "I", "G", "X", "M"], layout={"yaxis_title": "Change relative to baseline GDP"})
dt.plot(s, "m", lambda db: db.vNetFinAssets/db.vGDP, layout={"title": "Net Financial Assets to GDP"})
dt.plot([b.vNetFinAssets/b.vGDP], layout={"title": "Net Financial Assets to GDP"})





tabel1=extract_table_by_name(series=s.qCO2e_service_other,target_names=[45000,46000],level='i')
print(tabel1)
tabel2=extract_table_by_name(series=s.qCO2e_service_other-b.qCO2e_service_other,target_names=[2020,2025,2030],level='t')
print(tabel2)


tabel4=multiple_conditions_extract_table_by_name(s.qCO2e_service_other,target_values={'i':[45000,46000],'t':[2022,2024]},cols='i')
print(tabel4)


dt.plot([s.qY], "m", layout={"title": "CO2e emissions"})

dt.plot([s.qI_k_i.loc[['iM'],[23001]]], "m", layout={"title": "Investeringer, cement"})

# Plot investeringer
dt.plot([s.qI], "m", layout={"title": "Investeringer"})

dt.plot([s.qI_k_i.loc[['iM'],[49509]]], "m", layout={"title": "Investeringer, transport"})





# Plot udvikling for industri 49509 (transport)
dt.plot([s.qY_i.loc[[49509]]], "m", layout={"title": "Produktion i transportindustri 49509"})
dt.plot([s.qY_i[[49509]],s.pY_i[[49509]],s.qEmmE.loc[['co2e'],[49509]]], "pq")



## Running the partial abatement model
# dt.gamY.run("abatement_model_partial.gms")

