# --------------------------------------------------------------------------------------------
# Module to calibrate energy technologies from relative energy use in data.
# The file calib_abatement_techs.gms makes the final calibration of the energy technologies
# based on the data in this file.
# --------------------------------------------------------------------------------------------

import dreamtools as dt
import os
import pandas as pd

## Set local paths
root = dt.find_root("LICENSE")
## Set working directory
os.chdir(fr"{root}/data/Abatement_data")

gdx_input_dir = fr"{root}\model"
gdx_output_dir = fr"{root}\data\Abatement_data"


#GAMS-Pandas settings
db = dt.GamsPandasDatabase()
Par, Var, Set = db.create_parameter, db.create_variable, db.create_set

data_in = dt.Gdx(f"{gdx_input_dir}\output\calibration.gdx")

qEpj = data_in['qEpj']

qES = qEpj.groupby(by=["es","d","t"]).sum().to_frame().rename(columns={"qEpj":"qES"})
Var('qES', data=qES['qES'], add_missing_domains=True)

qEpj_qES = qEpj.reset_index().merge(qES.reset_index(), on=["es","d","t"], how="left").set_index(["d","es","e","t"])

## theta 
theta_temp = qEpj_qES["qEpj"]/qEpj_qES["qES"]#*0.1
theta_temp = theta_temp.fillna(0)
theta_temp = theta_temp.reset_index("e")
theta_temp["l_input"] = theta_temp["e"].apply(lambda x: "t_" + x).to_frame().rename(columns={"e":"l_input"})
theta_temp = theta_temp.reset_index().set_index(["l_input","d","es","e","t"])
print(theta_temp)

theta_sum = theta_temp.groupby(by=["es","d","t"]).sum()
print(theta_sum)


sqtPotential_input = theta_temp.copy()
sqtPotential_input = sqtPotential_input.reset_index().drop(columns=['e'])
sqtPotential_input = sqtPotential_input.reset_index().set_index(['l_input','es','d','t'])
sqtPotential_input = sqtPotential_input.rename(columns={0:'sqtPotential_input'})
sqtPotential_input = sqtPotential_input.drop(columns=['index'])
print(sqtPotential_input)

Var('sqtPotential_input', data=sqtPotential_input['sqtPotential_input'], add_missing_domains=True)

## uTE
uTE_input = theta_temp.copy()
uTE_input = uTE_input.rename(columns={0:'uTE_input'})
uTE_input = uTE_input.reset_index().set_index(['l_input','es','e','d','t'])
uTE_input["uTE_input"] = 1
print(uTE_input)

Var('uTE_input', data=uTE_input['uTE_input'], add_missing_domains=True)

# Export data
db.export('calibrate_abatement_data_python.gdx')

