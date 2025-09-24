# Execise Abatement

dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline_abatement.gdx") # b for baseline
s = dt.Gdx("Output/shock_carbon_tax_abatement.gdx") # s for shock
dt.time(2020, 2050)

## Exercise 1:
# 1.A
dt.prt(b.sqTAdoption.loc[:,['transport'],['01011'],[2035]])
dt.prt(b.sqT.loc[:,['transport'],['01011'],[2035]])

#1.B
dt.prt(b.qESE.loc[['transport'],:,['01011'],[2035]])
dt.prt(b.qREa.loc[['transport'],:,['01011'],[2035]])

# 1.C
from plot_supply_curves import plot_supply_curve # Function to plot abatement supply curves
plot_supply_curve("Output/baseline_abatement.gdx",['01011'])

# 1.D
dt.prt(b.pTPotential.loc[:,['transport'],['01011'],[2035]])

## Exercise 2:

dt.REFERENCE_DATABASE = b = dt.Gdx("Output/calibration_CCS.gdx") # b for baseline
s_CCS = dt.Gdx("Output/shock_carbon_tax_CCS.gdx") # s for shock
b_abatement = dt.Gdx("Output/baseline_abatement.gdx")
dt.time(2020, 2050)

# 2.D
dt.prt(b.sqTAdoption.loc[:,['process_special'],[23001],[2035]])
dt.prt(b.sqT.loc[:,['process_special'],[23001],[2035]])

# 2.E
dt.plot(s_CCS.tCO2_Emarg.loc[['co2ubio'],['process_special'],['Captured CO2'],[23001],:], "m")

# 2.F
# Electricity
dt.plot([s_CCS.qEpj.loc[['process_special'],['Electricity'],[23001],:]-b.qEpj.loc[['process_special'],['Electricity'],[23001],:],
         s.qEpj.loc[['process_special'],['Electricity'],[23001],:]-b_abatement.qEpj.loc[['process_special'],['Electricity'],[23001],:]])

# Captured CO2
dt.plot(s_CCS.qEpj.loc[['process_special'],['Captured CO2'],[23001],:],"m")

# Emissions
dt.plot([s_CCS.qEmmE.loc[['co2ubio'],[23001],:]-b.qEmmE.loc[['co2ubio'],[23001],:],
         s.qEmmE.loc[['co2ubio'],[23001],:]-b_abatement.qEmmE.loc[['co2ubio'],[23001],:]])


# 2.G
dt.prt(s_CCS.pTPotential.loc[:,['process_special'],['23001'],[2035]])

