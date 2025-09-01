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

## Create abatement_dummy_data.gdx based on excel-module
# from data.Abatement_data import Import_abatement_data

## Re-set working directory
os.chdir(fr"{root}/model")

dt.gamY.run("base_model.gms")


## Plotting of discrete and continous technical energy supply curves
from plot_supply_curves import plot_supply_curve # Function to plot abatement supply curves
plot_supply_curve("calibration_abatement.gdx")
plot_supply_curve("shock_capital_cost.gdx")
plot_supply_curve("shock_carbon_tax.gdx")

## Save calibration.gdx as previous_calibration.gdx
# shutil.copy("calibration.gdx", "previous_calibration.gdx")

# Plotting
dt.YAXIS_TITLE_FROM_OPERATOR = {
  "pq": "Pct. changes relative to baseline",
	"m": "Difference from baseline",
}
dt.TIME_AXIS_TITLE = ""


dt.REFERENCE_DATABASE = b = dt.Gdx("calibration.gdx") # b for baseline
s = dt.Gdx("shock.gdx") # s for shock
dt.time(2019, 2030)
dt.plot([b.vNetFinAssets/b.vGDP], layout={"title": "Net Financial Assets to GDP"})
dt.plot([s.qGDP, s.qC, s.qI, s.qG, s.qX, s.qM], "m", function=lambda x: x/b.vGDP, names=["GDP", "C", "I", "G", "X", "M"], layout={"yaxis_title": "Change relative to baseline GDP"})
dt.plot(s, "m", lambda db: db.vNetFinAssets/db.vGDP, layout={"title": "Net Financial Assets to GDP"})

## Running the partial abatement model
# dt.gamY.run("abatement_model_partial.gms")

