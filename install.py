import sys
import subprocess

# Install python modules in python installation that comes with GAMS
subprocess.run([
    sys.executable, "-m", "pip", "install", "--upgrade",
    "dream-tools==4.0.0",
    "pandas==3.0.2", 
    "gamsapi[all]", 
    "nbformat",
    "gamspy==1.21.0",
    "pyarrow==24.0.0",
    "matplotlib",
    "eurostat",
], check=True)
