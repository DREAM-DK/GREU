# Change the paths to the R and GAMS installations on your system
# r_path = r"C:/Program Files/R/R-4.4.0"
gams_path = r"C:/GAMS/46"


import os

def set_environment_path(gams_path):
    """
    Set the environment variables R_HOME, RSCRIPT, GAMSDIR, and GAMS.

    Parameters:
    r_path (str): Path to the R installation directory.
    gams_path (str): Path to the GAMS installation directory.
    """
    # Ensure the paths use the correct format
    # r_path = os.path.abspath(r_path)
    gams_path = os.path.abspath(gams_path)

    extension = ".exe" if os.name == "nt" else ""
    
    # Construct the paths using os.path.join for platform independence
    # rscript_path = os.path.join(r_path, "bin", f"Rscript{extension}")
    gams_executable_path = os.path.join(gams_path, f"gams{extension}")
    # assert os.path.exists(rscript_path), f"Rscript not found at {rscript_path}"
    assert os.path.exists(gams_executable_path), f"GAMS executable not found at {gams_executable_path}"
    
    # Set the environment variables
    # os.environ["R_HOME"] = r_path
    # os.environ["RSCRIPT"] = rscript_path
    os.environ["GAMSDIR"] = gams_path
    os.environ["GAMS"] = gams_executable_path

set_environment_path(gams_path)