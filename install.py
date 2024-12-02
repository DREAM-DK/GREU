import sys
import subprocess

# Install python modules in python installation that comes with GAMS
subprocess.run([
    sys.executable, "-m", "pip", "install", "--upgrade",
    "dream-tools==3.0.0", 
], check=True)
