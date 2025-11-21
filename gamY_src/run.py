import sys
import shutil
import os
import dreamtools as dt

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



