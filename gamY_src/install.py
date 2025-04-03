import sys
import subprocess

# Install python modules in python installation that comes with GAMS
subprocess.run([
    sys.executable, "-m", "pip", "install", "--upgrade",
    "dream-tools==3.0.0", "gamsapi[all]==46.5.0", "nbformat", 
    "gamspy",
], check=True)


# # Install python modules in python installation that comes with GAMS
# subprocess.run([
#     "C:/GAMS/46/GMSPython/Scripts/pip", "install", "--upgrade",
#     "gamspy==1.5.1",
# ], check=True)

# subprocess.run(["C:/GAMS/46/GMSPython/Scripts/gamsPy", "install", "license", "Q:/Installation/GAMS/DREAM_GAMSPy_license.txt"], check=True)

# set GAMSDIR=C:/GAMS/46
# set gamsPy=%GAMSDIR%/GMSPython/Scripts/gamsPy
# C:/GAMS/46/GMSPython/Scripts/pip
# %gamsPy% install license Q:\Installation\GAMS\DREAM_GAMSPy_license.txt

# C:/GAMS/46/GMSPython/Scripts/gamsPy install license Q:\Installation\GAMS\DREAM_GAMSPy_license.txt

# Install python modules in python installation that comes with GAMS
# subprocess.run([
#     sys.executable, "-m", "pip", "install", "--upgrade",
#     "dream-tools==3.0.0",
#     "gamspy", 
#     # "numpy", "scipy", "statsmodels", "xlwings",
#     # "plotly", "kaleido==0.1.0.post1", "xhtml2pdf", "dataframe_image", "pyhtml2pdf", "PyPDF2",
# ], check=True)