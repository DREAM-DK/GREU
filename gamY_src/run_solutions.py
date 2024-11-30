import sys
import shutil
import os
import dreamtools as dt
dt.gamY.default_initial_level = 0
dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"
dt.gamY.automatic_dummy_suffix = "_exists_dummy"

## Set local paths
root = dt.find_root()
sys.path.insert(0, root)
import paths

## Set working directory
os.chdir(fr"{root}/gamY_src")

# dt.gamY.run("../data/data_from_GR.gms")

dt.gamY.run("base_model.gms")

#==============================================================================
#Exercise: Increase production costs in partial model
#==============================================================================

#Plotting
dt.YAXIS_TITLE_FROM_OPERATOR = {
    "pq" : "Pct. change relative to baseline",
    "m"  : "Difference from baseline",
}

#Display
dt.pd.options.display.float_format = '{:.2f}'.format #We only want to see 2 decimal


#Shock with Leontief-production
dt.REFERENCE_DATABASE = dbase = dt.Gdx("baseline_partial_leontief.gdx")
db = dt.Gdx("shock_partial_leontief.gdx")
dt.time(2019, 2030)

#We look at the output in sectors 23001 and 71000, which are cement and service industry. 
#The first being energy-intensive, and the second being much less energy-intensive
pf = ['TopPfunction','machine_energy']
sectors = [23001,71000] 
time = [2030]

#Plot that shows the percentage change in machine-energy price and how it spills into marginal cost
dt.plot(db.pProd.loc[pf,sectors],"pq")


#Table of relative prices in 2030
changeP = ((db.pProd.loc[:,sectors,time]/dbase.pProd.loc[:,sectors,time]-1)*100).reset_index().drop(columns={'t'})
changeP = changeP.pivot(index='pf', columns='i', values='pProd')
display(changeP)


#Shock with substitution 
dt.REFERENCE_DATABASE = dbase = dt.Gdx("baseline_partial_subst.gdx")
db = dt.Gdx("shock_partial_subst.gdx")

#Plot that shows the percentage change in machine-energy price and how it spills into marginal cost
dt.plot(db.pProd.loc[pf,sectors],"pq")

changePsubst = ((db.pProd.loc[:,sectors,time]/dbase.pProd.loc[:,sectors,time]-1)*100).reset_index().drop(columns={'t'})
changePsubst = changePsubst.pivot(index='pf', columns='i', values='pProd')
display(changePsubst)

#Combining results:
changeP_all = changeP.merge(changePsubst, on='pf', suffixes=('_leontief', '_subst'))
display(changeP_all)


#==============================================================================
#Exercise: Increase production costs in partial model with energy and emissions
#==============================================================================

#Load baseline and shock databases
dt.REFERENCE_DATABASE = dbase = dt.Gdx("baseline_partial_energy_emissions.gdx")
db = dt.Gdx("shock_partial_energy_emissions.gdx")


#Decide what dimensions to look at
pf = ['TopPfunction','machine_energy']
sectors = [23001,71000] 
time = [2030]


#Table of relative prices in 2030
changeP = ((db.pProd.loc[:,sectors,time]/dbase.pProd.loc[:,sectors,time]-1)*100).reset_index().drop(columns={'t'})
changeP = changeP.pivot(index='pf', columns='i', values='pProd')
display(changeP)


#Plot that change in total emissions. We use ("m") to show difference to baseline, as we are often 
#interested in absolute change when it comes to emissions. Change is ktCO2e
dt.plot(db.qEmmTot.loc[['CO2e'],['UNFCCC']],"m")

#Plot of cement emissions (change is measured in ktCOe)
dt.plot(db.qEmm.loc[['CO2e'],[23001]], "m")



