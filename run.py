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

## Create abatement_dummy_data.gdx based on excel-module
from data.Abatement_data import Abatement_dummy_data

## Set working directory
os.chdir(fr"{root}/model")

## Create data.gdx based on GreenREFORM-DK data 
dt.gamY.run("../data/data_from_GR.gms")

## Run the base CGE model - creating main_CGE.gdx
dt.gamY.run("base_model.gms", test_CGE="1")

## Run the base model with abatement model - creating main_abatement.gdx
dt.gamY.run("base_model_abatement.gms", test_CGE="0", test_abatement="1")

## Run a simple shock model - creating shock.gdx
dt.gamY.run("shock_model.gms", include_abatement="1")


## Run a CO2 tax shock
dt.gamY.run("shock_CO2_tax.gms", include_abatement="1")


# ---------------
# Setup for plotting and tables
# ---------------
exec(open('Report/report_settings.py').read())


# ---------------
# Specify the baseline and shock scenarios
# ---------------
dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline.gdx") # b for baseline
s = dt.Gdx("Output/shock_carbon_tax.gdx") # s for shock






## Plotting of discrete and continous technical energy supply curves
from plot_supply_curves import plot_supply_curve # Function to plot abatement supply curves
plot_supply_curve("calibration_abatement.gdx")
# plot_supply_curve("shock_capital_cost.gdx")
plot_supply_curve("shock_carbon_tax.gdx")
# plot_supply_curve("shock_CCS_subsidy.gdx")

