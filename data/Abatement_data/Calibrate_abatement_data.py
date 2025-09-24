
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
print(qES)
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

# theta_temp2 = theta_temp.copy().to_frame()
# theta_temp2 = theta_temp2.reset_index("e")

# theta_temp2["tech_dec"] = ""

# theta_10 = theta_temp2.copy()
# theta_20 = theta_temp2.copy()
# theta_30 = theta_temp2.copy()
# theta_40 = theta_temp2.copy()
# theta_50 = theta_temp2.copy()
# theta_60 = theta_temp2.copy()
# theta_70 = theta_temp2.copy()
# theta_80 = theta_temp2.copy()
# theta_90 = theta_temp2.copy()
# theta_100 = theta_temp2.copy()

# theta_10["l"] = theta_10["energy19"].apply(lambda x: "t_" + x + "_10").to_frame().rename(columns={"energy19":"l"})
# theta_10["tech_dec"] = 0.1

# theta_20["l"] = theta_20["energy19"].apply(lambda x: "t_" + x + "_20").to_frame().rename(columns={"energy19":"l"})
# theta_20["tech_dec"] = 0.2

# theta_30["l"] = theta_30["energy19"].apply(lambda x: "t_" + x + "_30").to_frame().rename(columns={"energy19":"l"})
# theta_30["tech_dec"] = 0.3

# theta_40["l"] = theta_40["energy19"].apply(lambda x: "t_" + x + "_40").to_frame().rename(columns={"energy19":"l"})
# theta_40["tech_dec"] = 0.4

# theta_50["l"] = theta_50["energy19"].apply(lambda x: "t_" + x + "_50").to_frame().rename(columns={"energy19":"l"})
# theta_50["tech_dec"] = 0.5

# theta_60["l"] = theta_60["energy19"].apply(lambda x: "t_" + x + "_60").to_frame().rename(columns={"energy19":"l"})
# theta_60["tech_dec"] = 0.6

# theta_70["l"] = theta_70["energy19"].apply(lambda x: "t_" + x + "_70").to_frame().rename(columns={"energy19":"l"})
# theta_70["tech_dec"] = 0.7

# theta_80["l"] = theta_80["energy19"].apply(lambda x: "t_" + x + "_80").to_frame().rename(columns={"energy19":"l"})
# theta_80["tech_dec"] = 0.8

# theta_90["l"] = theta_90["energy19"].apply(lambda x: "t_" + x + "_90").to_frame().rename(columns={"energy19":"l"})
# theta_90["tech_dec"] = 0.9

# theta_100["l"] = theta_100["energy19"].apply(lambda x: "t_" + x + "_100").to_frame().rename(columns={"energy19":"l"})
# theta_100["tech_dec"] = 1

# theta_uTK = pd.concat([theta_10,theta_20,theta_30,theta_40,theta_50,theta_60,theta_70,theta_80,theta_90,theta_100])

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

## uTK
# uTK = theta_uTK
# uTK = uTK.drop(columns=[0])
# uTK = uTK.rename(columns={'tech_dec':'uTK'})
# uTK['uTK'] = 0.5*uTK['uTK']

# uTK = uTK.reset_index().set_index(['l','purpose','r','energy19','t'])

# Var('uTK', data=uTK['uTK'], add_missing_domains=True)

# Export data
db.export('calibrate_abatement_data_python.gdx')

