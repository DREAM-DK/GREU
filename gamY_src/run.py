import sys
import shutil
import os
import dreamtools as dt
dt.gamY.default_initial_level = 0
dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"
dt.gamY.automatic_dummy_suffix = "_exists_dummy"

## Set local paths
root = dt.find_root()
sys.path.insert(0, root)
# import paths

## Set working directory
os.chdir(fr"{root}/gamY_src")

# dt.gamY.run("../data/data_from_GR.gms")

dt.gamY.run("base_model.gms")

## Save calibration.gdx as previous_calibration.gdx
# shutil.copy("calibration.gdx", "previous_calibration.gdx")

dt.REFERENCE_DATABASE = b = dt.Gdx("calibration.gdx")
ab = dt.Gdx("Abatement_partial.gdx")
dt.time(2019, 2030)
dt.plot(ab.qE_tech.loc[['heating'],:,[10030],:], "m")
dt.DataFrame(ab.qAdoption.loc[:,['heating'],[10030],:]).round(2)
dt.DataFrame(ab.qAdoption.loc[['t_Electricity_calib','t_Electricity_calib_2'],['heating'],[10030],:]).round(5)


# Increased electrification in baseline
dt.REFERENCE_DATABASE = b = dt.Gdx("Abatement_partial.gdx")
e = dt.Gdx("Abatement_partial_elec.gdx")
dt.time(2019, 2030)
dt.plot(e.qE_tech.loc[['heating'],:,[10030],:], "pq")
dt.DataFrame(e.qE_tech.loc[['heating'],:,[10030],:], "pq").round(2)
dt.DataFrame(e.qAdoption.loc[['t_Diesel for transport_100','t_Electricity_calib','t_Electricity_calib_2'],['heating'],[10030],:]).round(2)


