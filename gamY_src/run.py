## imports
import os 
import sys
import glob
import shutil
import subprocess
import webbrowser
import dreamtools as dt

## set paths to programs
from paths import GAMS_path, gamY_path

sys.path.insert(0, gamY_path)
import gamY
os.environ["GAMSDIR"] = GAMS_path
os.environ["GAMS"] = GAMS_path + r"\gams.exe"

gamY.py_call("base_model.gms")
gamY.gams_error("base_model.gms", check_error=True)

db = dt.Gdx("calibration.gdx")
