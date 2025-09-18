# ---------------
# Setup for plotting and tables
# ---------------
exec(open('Report/report_settings.py').read())


# ---------------
# Specify the baseline and shock scenarios
# ---------------
dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline.gdx") # b for baseline
s = dt.Gdx("Output/shock_carbon_tax.gdx") # s for shock

dt.time(2020, 2050)

# ---------------
# Reporting of emissions
# ---------------

dt.plot([b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], names=["Total emissions"], layout={"title": "CO2e emissions, total"})

# dt.plot([s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']], s_a.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "m", names=["Only CGE", "CGE with abatement"], layout={"title": "CO2e emissions, total"})


dt.plot([b.qCO2e_taxgroup, b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], 
        names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], 
        layout={"title": "CO2e emissions, total"})


energyCorpPart = b.qCO2e_taxgroup.loc[['energy_Corp']]/b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]*100
energyHhPart = b.qCO2e_taxgroup.loc[['energy_Hh']]/b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]*100
nonEnergyPart = b.qCO2e_taxgroup.loc[['non_energy']]/b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]*100
energyCorpPart = energyCorpPart.droplevel('em').droplevel('CO2etax').droplevel('em_accounts')
energyHhPart = energyHhPart.droplevel('em').droplevel('CO2etax').droplevel('em_accounts')
nonEnergyPart = nonEnergyPart.droplevel('em').droplevel('CO2etax').droplevel('em_accounts')
NotPart = 100 - energyCorpPart - energyHhPart - nonEnergyPart

dt.plot([energyCorpPart, energyHhPart, nonEnergyPart, NotPart], names=["Energy, Corp", "Energy, Hh", "Non-energy", "Not part of tax"], layout={"title": "Tax categories part of total CO2e emissions (%)"})
dt.plot([s.qCO2e_taxgroup, s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "m", names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], layout={"title": "Change in CO2e emissions"})
dt.plot([s.qCO2e_taxgroup, s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "pq", names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], layout={"title": "Change in CO2e emissions"})


exec(open('Report/qEmm2030-40-50.py').read())

# # Reduction on industry level
# dt.plot([s.qCO2e_iagg.loc[:,['Total']]], "m", layout={"title": "CO2e emissions, industri aggregated"})
# dt.plot([s.qCO2e_iagg.loc[['service'],:]], "m", layout={"title": "CO2e emissions, Services"})

# exec(open('Report/qEmm_industry_tables.py').read())


#-----------------
# MACRO reporting
#-----------------

# Plot of main macroeconomic variables
dt.plot([s.pGDP, s.qGDP, s.pW], "pq", names=["GDP deflator", "Real GDP", "Wage level"], 
        layout={"title": "Main macroeconomic variables"})


dt.plot([s.qC, s.qG, s.qI, s.qX, s.qM], "pq", 
        names=["Consumption", "Government consumption", "Investments", "Exports", "Imports"], 
        layout={"title": "Main macroeconomic variables"})


qC_Y = (s.qC/s.qGDP - b.qC/b.qGDP)*100
qG_Y = (s.qG/s.qGDP - b.qG/b.qGDP)*100
qI_Y = (s.qI/s.qGDP - b.qI/b.qGDP)*100
qX_Y = (s.qX/s.qGDP - b.qX/b.qGDP)*100
qM_Y = (s.qM/s.qGDP - b.qM/b.qGDP)*100

dt.plot([qC_Y, qG_Y, qI_Y, qX_Y, qM_Y], names=["Consumption", "Government consumption", "Investments", "Exports", "Imports"], layout={"title": "Change in share of GDP (%)"})


exec(open('Report/GDP_overview.py').read())


#-----------------
# Reporting of income flows
#-----------------

dt.plot([s.vCashFlow], "m", layout={"title": "Cash flow between sectors"})

tabelBase=table(b.vIncomeFlow,target_values={'t':[2030]},cols='sector')
display(tabelBase)
tabelBaseAgg=table(b.vIncomeFlowAgg,target_values={'t':[2030]},cols='sector')
display(tabelBaseAgg)
tabelDiffAgg=table(s.vIncomeFlowAgg-b.vIncomeFlowAgg,target_values={'t':[2030]},cols='sector')
display(tabelDiffAgg)

dt.plot([s.vIncomeFlowAgg.loc[:,['Corp'],:]], "m", layout={"title": "Cash flow for corporations"})
dt.plot([s.vIncomeFlowAgg.loc[:,['Hh'],:]], "m", layout={"title": "Cash flow for households"})


#--------------------------------
# Reporting of public finances
#--------------------------------

exec(open('Report/Public_finances.py').read())

dt.plot([prim_baseline, prim_shock], names=["Baseline", "Shock"], layout={"title": "Primary balance, pct. of GDP"})
dt.plot([b.vLumpsum, s.vLumpsum], names=["Baseline", "Shock"], layout={"title": "Lumpsum payments"})
dt.plot([vPrimBudg_xLump, CO2etax], names=["Government budget eksl. lumpsum", "Revenue from CO2e tax"], 
        layout={"title": "Changes in public finances, pct. of GDP"})

print("\nGovernment finances in 2040:")
print(gov_table)

print("\nBreakdown of indirect taxes in 2040:")
print(indirect_table)


#--------------------------------
# Reporting of welfare
#--------------------------------

dt.plot([s.EVt], names=["Income, domestic", "Price, domestic", "Price, foreign", "Wealth, domestic"], layout={"title": "Equivalent variations"})

display(s.EV)
display(s.Shadow_price)




dt.plot([s.EVt_display], layout={"title": "Equivalent variations"})
dt.plot([s.EVt_income], layout={"title": "Equivalent variations"})


# dt.plot([s.EVt], figsize=(5,5), layout={"title": "Equivalent variations"})

# dt.plot([s.EVt_Weight], layout={"title": "Equivalent variations"})
# display(s.EVt_Weight)



# display(s.vtCO2_ETS2)


# display(s_steps.EV)

# display(s_steps.Shadow_price)


# s.EVt.to_excel('EVt.xlsx')
# s.EVt_Weight.to_excel('EVt_Weight.xlsx')

# s.EV.to_excel('EV.xlsx')
# s.Shadow_price.to_excel('Shadow_price.xlsx')







# ---------------
# Abatement plotting
# ---------------

## Plotting of discrete and continous technical energy supply curves
from plot_supply_curves import plot_supply_curve # Function to plot abatement supply curves
plot_supply_curve("Output/calibration_abatement.gdx",["23001"])
plot_supply_curve("Output/pre_calibration_abatement.gdx",["23001"])
plot_supply_curve("Output/shock_carbon_tax_abatement.gdx",["23001"])

# plot_supply_curve("shock_CCS_subsidy.gdx")

