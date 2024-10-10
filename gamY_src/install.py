import sys
import subprocess

# Install pip in python installation that comes with GAMS
subprocess.run(["curl", "https://bootstrap.pypa.io/get-pip.py", "-o", "get-pip.py"], check=True)
subprocess.run([sys.executable, "get-pip.py"], check=True)

# Install python modules in python installation that comes with GAMS
subprocess.run([
    sys.executable, "-m", "pip", "install", "--upgrade",
    "numpy", "scipy", "statsmodels", "xlwings", "dream-tools", 
    "plotly", "kaleido==0.1.0.post1", "xhtml2pdf", "dataframe_image", "pyhtml2pdf", "PyPDF2",
], check=True)
