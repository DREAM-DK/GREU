#### Execise Energy Technology ####

## Exercise 1:

dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline_energy_technology.gdx") # b for baseline
s = dt.Gdx("Output/shock_carbon_tax_energy_technology.gdx") # s for shock
dt.time(2020, 2050)

# 1.B
dt.prt(b.sqTAdoption.loc[:,['transport'],['01011'],[2035]])
dt.prt(b.sqT.loc[:,['transport'],['01011'],[2035]])

#1.C
dt.prt(b.qESE.loc[['transport'],:,['01011'],[2035]])
dt.prt(b.qREa.loc[['transport'],:,['01011'],[2035]])

# 1.D
from plot_supply_curves import plot_supply_curve # Function to plot energy technology supply curves
plot_supply_curve("Output/baseline_energy_technology.gdx",['01011'])

# 1.E
dt.prt(b.pTPotential.loc[:,['transport'],['01011'],[2035]])

# 1.F
# Emissions
dt.plot([s.qCO2e_taxgroup, s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "pq", names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], layout={"title": "Change in CO2e emissions"})

# GDP-components
dt.plot([s.qC, s.qG, s.qI, s.qX, s.qM], "pq", 
        names=["Consumption", "Government consumption", "Investments", "Exports", "Imports"], 
        layout={"title": "Main macroeconomic variables"})

# Shadow prices
display(s.EV)
display(s.Shadow_price)


## Exercise 2:

dt.REFERENCE_DATABASE = b = dt.Gdx("Output/calibration_CCS.gdx") # b for baseline
s_CCS = dt.Gdx("Output/shock_carbon_tax_CCS.gdx") # s for shock
b_energy_technology = dt.Gdx("Output/baseline_energy_technology.gdx")
dt.time(2020, 2050)

# 2.D
dt.prt(b.sqTAdoption.loc[:,['process_special'],[23001],[2035]])
dt.prt(b.sqT.loc[:,['process_special'],[23001],[2035]])

# 2.E
dt.plot(s_CCS.tCO2_Emarg.loc[['co2ubio'],['process_special'],['Captured CO2'],[23001],:], "m")

# 2.F
# Captured CO2
dt.plot(s_CCS.qEpj.loc[['process_special'],['Captured CO2'],[23001],:],"m")

# 2.G
# Electricity
dt.plot([s_CCS.qEpj.loc[['process_special'],['Electricity'],[23001],:]-b.qEpj.loc[['process_special'],['Electricity'],[23001],:],
         s.qEpj.loc[['process_special'],['Electricity'],[23001],:]-b_energy_technology.qEpj.loc[['process_special'],['Electricity'],[23001],:]])

# Emissions
dt.plot([s_CCS.qEmmE.loc[['co2ubio'],[23001],:]-b.qEmmE.loc[['co2ubio'],[23001],:],
         s.qEmmE.loc[['co2ubio'],[23001],:]-b_energy_technology.qEmmE.loc[['co2ubio'],[23001],:]])

# 2.H
# Price of energy service
dt.plot([s_CCS.pES.loc[['process_special'],[23001],:]-b.pES.loc[['process_special'],[23001],:],
         s.pES.loc[['process_special'],[23001],:]-b_energy_technology.pES.loc[['process_special'],[23001],:]])

# Quantity of energy service
dt.plot([s_CCS.qES.loc[['process_special'],[23001],:]-b.qES.loc[['process_special'],[23001],:],
         s.qES.loc[['process_special'],[23001],:]-b_energy_technology.qES.loc[['process_special'],[23001],:]])

## Exercise 3:

dt.REFERENCE_DATABASE = b = dt.Gdx("Output/calibration_electrification.gdx") # b for baseline
s = dt.Gdx("Output/shock_carbon_tax_electrification.gdx") # s for shock
s = dt.Gdx("Output/shock_carbon_tax_CCS.gdx") # s for shock
dt.time(2020, 2050)

# 3.D
dt.plot(s.qEmmE.loc[['co2ubio'],[55560],:],"m")
dt.plot([s.qCO2e_taxgroup, s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "pq", names=["Energy, Corp", "Energy, Hh", "Non-energy", "All emissions"], layout={"title": "Change in CO2e emissions"})

# 3.E
dt.plot(s.sqT.loc[:,['transport'],[55560],:],"m")