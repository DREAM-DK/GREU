
import dreamtools as dt
import os
import pandas as pd

os.chdir(r'C:\Users\b165541\Documents\Modeller\EU\Fra_Asbjorn\GREU\data')

#GAMS-Pandas settings
db = dt.GamsPandasDatabase()
Par, Var, Set = db.create_parameter, db.create_variable, db.create_set

data_in = dt.Gdx('EU_GR_data.gdx')

qREgj = data_in['qREgj']

qES = qREgj.groupby(by=["purpose","r","t"]).sum().to_frame().rename(columns={"qREgj":"qES"})

qREgj_qES = qREgj.reset_index().merge(qES.reset_index(), on=["purpose","r","t"], how="left").set_index(["r","purpose","energy19","t"])

## theta 
theta_temp = qREgj_qES["qREgj"]/qREgj_qES["qES"]*0.1
theta_temp = theta_temp.fillna(0)

theta_sum = theta_temp.groupby(by=["purpose","r","t"]).sum()
theta_temp2 = theta_temp.copy().to_frame()
theta_temp2 = theta_temp2.reset_index("energy19")

theta_temp2["tech_dec"] = ""

theta_10 = theta_temp2.copy()
theta_20 = theta_temp2.copy()
theta_30 = theta_temp2.copy()
theta_40 = theta_temp2.copy()
theta_50 = theta_temp2.copy()
theta_60 = theta_temp2.copy()
theta_70 = theta_temp2.copy()
theta_80 = theta_temp2.copy()
theta_90 = theta_temp2.copy()
theta_100 = theta_temp2.copy()

theta_10["l"] = theta_10["energy19"].apply(lambda x: "t_" + x + "_10").to_frame().rename(columns={"energy19":"l"})
theta_10["tech_dec"] = 0.1

theta_20["l"] = theta_20["energy19"].apply(lambda x: "t_" + x + "_20").to_frame().rename(columns={"energy19":"l"})
theta_20["tech_dec"] = 0.2

theta_30["l"] = theta_30["energy19"].apply(lambda x: "t_" + x + "_30").to_frame().rename(columns={"energy19":"l"})
theta_30["tech_dec"] = 0.3

theta_40["l"] = theta_40["energy19"].apply(lambda x: "t_" + x + "_40").to_frame().rename(columns={"energy19":"l"})
theta_40["tech_dec"] = 0.4

theta_50["l"] = theta_50["energy19"].apply(lambda x: "t_" + x + "_50").to_frame().rename(columns={"energy19":"l"})
theta_50["tech_dec"] = 0.5

theta_60["l"] = theta_60["energy19"].apply(lambda x: "t_" + x + "_60").to_frame().rename(columns={"energy19":"l"})
theta_60["tech_dec"] = 0.6

theta_70["l"] = theta_70["energy19"].apply(lambda x: "t_" + x + "_70").to_frame().rename(columns={"energy19":"l"})
theta_70["tech_dec"] = 0.7

theta_80["l"] = theta_80["energy19"].apply(lambda x: "t_" + x + "_80").to_frame().rename(columns={"energy19":"l"})
theta_80["tech_dec"] = 0.8

theta_90["l"] = theta_90["energy19"].apply(lambda x: "t_" + x + "_90").to_frame().rename(columns={"energy19":"l"})
theta_90["tech_dec"] = 0.9

theta_100["l"] = theta_100["energy19"].apply(lambda x: "t_" + x + "_100").to_frame().rename(columns={"energy19":"l"})
theta_100["tech_dec"] = 1

theta_uTK = pd.concat([theta_10,theta_20,theta_30,theta_40,theta_50,theta_60,theta_70,theta_80,theta_90,theta_100])

theta = theta_uTK.copy()
theta = theta.drop(columns=['tech_dec'])

theta = theta.reset_index().set_index(['l','purpose','r','energy19','t'])
theta = theta.rename(columns={0:'theta'})

Var('theta', data=theta['theta'], add_missing_domains=True)

## uTE
uTE = theta
uTE = uTE.rename(columns={'theta':'uTE'})
uTE["uTE"] = 1

Var('uTE', data=uTE['uTE'], add_missing_domains=True)

## uTK
uTK = theta_uTK
uTK = uTK.drop(columns=[0])
uTK = uTK.rename(columns={'tech_dec':'uTK'})
uTK['uTK'] = 0.5*uTK['uTK']

uTK = uTK.reset_index().set_index(['l','purpose','r','energy19','t'])

Var('uTK', data=uTK['uTK'], add_missing_domains=True)

# Export data
db.export('EU_tech_data_disagg.gdx')

