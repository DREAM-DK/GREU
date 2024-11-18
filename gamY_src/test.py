import sys
import shutil
import os

import dreamtools as dt
dt.gamY.require_variable_with_equation = True
dt.gamY.block_equations_suffix = "_equations"
dt.gamY.automatic_dummy_suffix = "_exists_dummy"

## Set local paths
root = dt.find_root()
sys.path.insert(0, root)
#import paths

## Set working directory
os.chdir(fr"{root}/gamY_src")

dt.gamY.run("test.gms")

