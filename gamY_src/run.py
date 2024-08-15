%load_ext autoreload
%autoreload 2

import sys
import subprocess

# sys.path.insert(0, r"P:\mkb\dream-tools")
import dreamtools as dt
dt.gamY.require_variable_with_equation = True
dt.gamY.block_equations_suffix = "_equations"

## Set local paths
sys.path.insert(0, dt.find_root())
import paths

## Set working directory
# os.chdir(fr"{root}/Model")

## Install python modules in python installation that comes with GAMS
# subprocess.check_call(["curl", "https://bootstrap.pypa.io/get-pip.py", "-o", "get-pip.py"])
# subprocess.check_call([sys.executable, "get-pip.py"])
# subprocess.check_call([sys.executable, "-m", "pip", "install", 
#                        "numpy", "scipy", "statsmodels", "xlwings", "dream-tools", 
#                        "plotly", "kaleido==0.1.0.post1", "xhtml2pdf",
#                        "--upgrade",])

dt.gamY.run("calibration.gms")
db = dt.Gdx("calibration.gdx")

dt.multiindex_plotly.large_figure_layout
dt.plot(db.qY_s)