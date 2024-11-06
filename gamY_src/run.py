%load_ext autoreload
%autoreload 2

import sys
import shutil
import os
sys.path.insert(0, r"P:\mkb\dream-tools") # Til udvikling af dream-tools
import dreamtools as dt
dt.gamY.require_variable_with_equation = True
dt.gamY.block_equations_suffix = "_equations"
dt.gamY.variable_equation_prefix = "E_"
# dt.gamY.default_initial_level = None
dt.gamY.automatic_dummy_suffix = "_exists_dummy"

## Set local paths
root = dt.find_root()
sys.path.insert(0, root)
import paths

## Set working directory
os.chdir(fr"{root}/gamY_src")

dt.gamY.run("../data/data_from_GR.gms")

dt.gamY.run("base_model.gms")
db = dt.Gdx("calibration.gdx")

dt.time(2000, 2040)
dt.plot(db.qY_s)

## Save calibration.gdx as previous_calibration.gdx
shutil.copy("calibration.gdx", "previous_calibration.gdx")

dt.REFERENCE_DATABASE = data = dt.Gdx("../data/data.gdx")
dt.prt(db.vY_s, "i")

db.vtY_d_i.loc["k", "public"]