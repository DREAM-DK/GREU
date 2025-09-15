# ---------------
# Setup for plotting and tables
# ---------------
exec(open('Report/report_settings.py').read())


# ---------------
# Specify the baseline and shock scenarios
# ---------------
dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline.gdx") # b for baseline
s = dt.Gdx("Output/shock_carbon_tax.gdx") # s for shock
s_a = dt.Gdx("Output/shock_carbon_tax_abatement.gdx") # s for shock
s_steps = dt.Gdx("Output/shock_carbon_tax_steps.gdx") # s for shock

dt.time(2019, 2030)

# ---------------
# Reporting of emissions
# ---------------

dt.plot([b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], names=["Total emissions"], layout={"title": "CO2e emissions, total"})

dt.plot([s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']], s_a.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "m", names=["Only CGE", "CGE with abatement"], layout={"title": "CO2e emissions, total"})


dt.plot([b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']], b.qCO2e_taxgroup], layout={"title": "CO2e emissions, total"})
dt.plot([b.qCO2e_taxgroup, b.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], layout={"title": "CO2e emissions, total"})


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

dt.plot([qC_Y, qG_Y, qI_Y, qX_Y, qM_Y], names=["Consumption", "Government consumption", "Investments", "Exports", "Imports"], layout={"title": "Change in share of GDP (%)"})





exec(open('Report/GDP_overview.py').read())


dt.plot([s.vCashFlow], "m", layout={"title": "Cash flow between sectors"})
dt.plot([s.vIncomeFlow.loc[:,['Corp'],:]], "m", layout={"title": "Cash flow for corporations"})
dt.plot([s.vIncomeFlow.loc[:,['Hh'],:]], "m", layout={"title": "Cash flow for households"})
dt.plot([s2.vIncomeFlow.loc[:,['Hh'],:]], "m", layout={"title": "Cash flow for households"})


tabel1=table(s.vIncomeFlow - b.vIncomeFlow,target_values={'t':[2030]},cols='sector')
display(tabel1)



#--------------------------------
# Reporting of public finances
#--------------------------------

# vPrimBudg_xLump = s.vGovPrimaryBalance+s.vLumpsum-b.vGovPrimaryBalance
# vPrimBudg_xLump[2020] = 0; 
# CO2etax = s.vtCO2e_total
# CO2etax[2020] = 0; CO2etax[2021] = 0; CO2etax[2022] = 0; CO2etax[2023] = 0; CO2etax[2024] = 0;


# dt.plot([vPrimBudg_xLump, CO2etax], names=["Government budget eksl. lumpsum", "Revenue from CO2e tax"], layout={"title": "Changes in public finances"})



# dt.plot([b.vGovPrimaryBalance], names=["Baseline"], layout={"title": "Primary balance"})


# dt.plot([s.vGovPrimaryBalance, b.vGovPrimaryBalance], names=["Shock", "Baseline"], layout={"title": "Primary balance"})
# dt.plot(s.vGovPrimaryBalance,"m", layout={"title": "Primary balance"})

# print(s.vGovPrimaryBalance[2030],s.vGovPrimaryBalance[2025])


# exec(open('Report/Public_finances.py').read())

# gov_revenue_table.to_excel('gov_revenue_2040.xlsx')
# Net_duties_table.to_excel('Net_duties_2040.xlsx')
# gov_expenditure_table.to_excel('gov_expenditure_2040.xlsx')



#--------------------------------
# Reporting of welfare
#--------------------------------

# dt.plot([s.EVt], names=["Income, domestic", "Price, domestic", "Price, foreign", "Wealth, domestic"], layout={"title": "Equivalent variations"})

# dt.plot([s.EVt], figsize=(5,5), layout={"title": "Equivalent variations"})

# dt.plot([s.EVt], layout={"title": "Equivalent variations"})

# dt.plot([s.EVt_display], layout={"title": "Equivalent variations"})

# dt.plot([s.EVt_Weight], layout={"title": "Equivalent variations"})
# display(s.EVt_Weight)

# dt.plot([s.EVt_income], layout={"title": "Equivalent variations"})


# display(s.vtCO2_ETS2)

# display(s.EV)
# display(s2.EV)

# display(s_steps.EV)

# display(s.Shadow_price)
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
plot_supply_curve("calibration_abatement.gdx")
# plot_supply_curve("shock_capital_cost.gdx")
plot_supply_curve("shock_carbon_tax.gdx")
# plot_supply_curve("shock_CCS_subsidy.gdx")

