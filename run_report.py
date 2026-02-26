# ---------------
# Setup for plotting and tables
# ---------------
exec(open('Report/report_settings.py').read())


# ---------------
# Specify the baseline and shock scenarios
# ---------------
dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline.gdx") # b for baseline
s = dt.Gdx("Output/shock_carbon_tax.gdx") # s for shock
#s_a = dt.Gdx("Output/shock_carbon_tax_abatement.gdx") # s for shock


dt.time(2020, 2050)

# ---------------
# Reporting of emissions
# ---------------

dt.plot([s.qCO2e_taxgroup, s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "m", names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], layout={"title": "Change in CO2e emissions"})
dt.plot([s.qCO2e_taxgroup, s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "pq", names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], layout={"title": "Change in CO2e emissions"})

# Tabel of emissions in 2030, 2040 and 2050 for more disaggregated information
# exec(open('Report/qEmm2030-40-50.py').read())


#-----------------
# MACRO reporting
#-----------------

# Plot of main macroeconomic variables
dt.plot([s.pGDP, s.qGDP, s.pW], "pq", names=["GDP deflator", "Real GDP", "Wage level"], 
        layout={"title": "Main macroeconomic variables"})


dt.plot([s.qC, s.qG, s.qI, s.qX, s.qM], "pq", 
        names=["Consumption", "Government consumption", "Investments", "Exports", "Imports"], 
        layout={"title": "Main macroeconomic variables"})


# Table of main macroeconomic variables in 2030 for more disaggregated information
# exec(open('Report/GDP_overview.py').read())


#-----------------
# Reporting of income flows
#-----------------

# Income flows between sectors in the baseline projection
# tabelBaseAgg=table(b.vIncomeFlowAgg,target_values={'t':[2040]},cols='sector')
# display(tabelBaseAgg)
# Change in income flows
tabelDiffAgg=table(s.vIncomeFlowAgg-b.vIncomeFlowAgg,target_values={'t':[2040]},cols='sector')
display(tabelDiffAgg)

dt.plot([s.vCashFlow], "m", layout={"title": "Cash flow between sectors"})
dt.plot([s.vIncomeFlowAgg.loc[:,['NonFinCorp'],:]], "m", layout={"title": "Cash flow for non-financial corporations"})
dt.plot([s.vIncomeFlowAgg.loc[:,['FinCorp'],:]], "m", layout={"title": "Cash flow for financial corporations"})
dt.plot([s.vIncomeFlowAgg.loc[:,['Hh'],:]], "m", layout={"title": "Cash flow for households"})


#--------------------------------
# Reporting of public finances
#--------------------------------

exec(open('Report/Public_finances.py').read())

dt.plot([prim_baseline, prim_shock], names=["Baseline", "Shock"], layout={"title": "Primary balance excl. lumpsum, pct. of GDP"})
# dt.plot([b.vLumpsum, s.vLumpsum], names=["Baseline", "Shock"], layout={"title": "Lumpsum payments"})
dt.plot([vPrimBudg_xLump, CO2etax], names=["Government budget eksl. lumpsum", "Revenue from CO2e tax"], 
        layout={"title": "Changes in public finances, pct. of GDP"})

print("\nGovernment finances in 2040:")
print(gov_table)

print("\nBreakdown of indirect taxes in 2040:")
print(indirect_table)


#--------------------------------
# Reporting of welfare
#--------------------------------

display(s.EV)
dt.plot([s.EVt], names=["Income, domestic", "Price, domestic", "Price, foreign", "Wealth, domestic"], layout={"title": "Equivalent variations"})
dt.plot([s.EVt_income], layout={"title": "Equivalent variations"})


display(s.EV_Shadow_price)




# s.EVt.to_excel('EVt.xlsx')

