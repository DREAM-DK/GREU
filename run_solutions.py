import sys
import shutil
import os
import dreamtools as dt
dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"

## Set local paths
root = dt.find_root("LICENSE")
sys.path.insert(0, root)
# os.environ["GAMS"] = "C:/GAMS/46/gams.exe"

## Set working directory
os.chdir(fr"{root}/model")

## Create data.gdx based on GreenREFORM-DK data 
# dt.gamY.run("../data/data_from_GR.gms")

dt.gamY.run("base_model.gms")

# Looking at the calibration 
static_calib = dt.Gdx("static_calibration.gdx")
static_calib.sY

dyn_calib = dt.Gdx("calibration.gdx")
dyn_calib.sY

## Save calibration.gdx as previous_calibration.gdx
# shutil.copy("calibration.gdx", "previous_calibration.gdx")

# Plotting
dt.YAXIS_TITLE_FROM_OPERATOR = {
  "pq": "Pct. changes relative to baseline",
	"m": "Difference from baseline",
}
dt.TIME_AXIS_TITLE = ""


# Shock 
dt.REFERENCE_DATABASE = base = dt.Gdx("calibration.gdx")
shoc = dt.Gdx("shock.gdx")

#Look at percentage change in pY 
dt.DataFrame(shoc.pY, "pq")

#Look at percentage change in demand for qY 
dt.DataFrame(shoc.qY, "pq")