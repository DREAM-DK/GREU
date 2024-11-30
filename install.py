import sys
import subprocess

# Install pip in python installation that comes with GAMS
subprocess.run(["curl", "https://bootstrap.pypa.io/get-pip.py", "-o", "get-pip.py"], check=True)
subprocess.run([sys.executable, "get-pip.py"], check=True)

# Install python modules in python installation that comes with GAMS
subprocess.run([
    sys.executable, "-m", "pip", "install", "--upgrade",
    "dream-tools==3.0.0", 
], check=True)
