import sys
import shutil
import os
import dreamtools as dt
from plot_supply_curves import plot_supply_curve # Function to plot abatement supply curves

# import gamspy as gp

dt.gamY.default_initial_level = 0
dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"
dt.gamY.automatic_dummy_suffix = "_exists_dummy"

## Set local paths
root = dt.find_root()
sys.path.insert(0, root)
# import paths

# Manually add GAMS to path
os.environ["GAMS"] = "C:/GAMS/49/gams.exe"

## Read abatement data
from data.Abatement_data import Import_abatement_data

## Set working directory to model folder
os.chdir(fr"{root}/gamY_src")

dt.gamY.run("base_model.gms")

# Plot smooth and discrete supply curves
plot_supply_curve("calibration.gdx")
plot_supply_curve("shock_capital_cost.gdx")
plot_supply_curve("shock_carbon_tax.gdx")
plot_supply_curve("shock_CCS_subsidy.gdx")

## Save calibration.gdx as previous_calibration.gdx
# shutil.copy("calibration.gdx", "previous_calibration.gdx")

# dt.REFERENCE_DATABASE = b = dt.Gdx("calibration.gdx")
# ab = dt.Gdx("Abatement_partial.gdx")

# dt.time(2019, 2030)
# dt.plot(ab.qE_tech.loc[['heating'],:,[10030],:], "m")


## Electrification
# e = dt.Gdx("Abatement_partial_elec.gdx")


## Carbon tax
# c = dt.Gdx("Abatement_partial_carbon_tax.gdx")



