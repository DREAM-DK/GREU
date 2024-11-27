import sys
import shutil
import os
sys.path.insert(0, r"P:\mkb\dream-tools") # Til udvikling af dream-tools
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

## Save calibration.gdx as previous_calibration.gdx
# shutil.copy("calibration.gdx", "previous_calibration.gdx")

dt.REFERENCE_DATABASE = calibration = dt.Gdx("calibration.gdx")
db = dt.Gdx("shock.gdx")
dt.time(2019, 2025)
dt.plot([db.vGDP, db.vC, db.vI, db.vG, db.vX, db.vM], "m")
