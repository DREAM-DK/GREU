# --------------------------------------------------------------------------------------------
# Module to calibrate energy technologies from relative energy use in data.
# The file calib_energy_technologies.gms makes the final calibration of the energy technologies
# based on the data in this file.
# --------------------------------------------------------------------------------------------

import dreamtools as dt
import os
import pandas as pd

## Set local paths
root = dt.find_root("LICENSE")
## Set working directory
os.chdir(f"{root}/data/Energy_technology_data")

gdx_input_dir = f"{root}/model"

# Verify that the calibration GDX file exists before loading
gdx_path = f"{gdx_input_dir}/output/calibration.gdx"
if not os.path.exists(gdx_path):
    raise FileNotFoundError(f"Required input file not found: {gdx_path}")

#GAMS-Pandas settings
db = dt.GamsPandasDatabase()
Par, Var, Set = db.create_parameter, db.create_variable, db.create_set

## Loading qEpj and pEpj_marg from calibration GDX file
data_in = dt.Gdx(gdx_path)
qEpj = data_in['qEpj']
pEpj_marg = data_in['pEpj_marg']
Var('pEpj_marg', data=pEpj_marg, add_missing_domains=True)

## Creating energy service demand, qES (indexed by (es, d, t))
qES = qEpj.groupby(by=["es","d","t"]).sum().to_frame().rename(columns={"qEpj":"qES"})
Var('qES', data=qES['qES'], add_missing_domains=True)

## Calculating energy shares and creating fictive technologies
energy_shares = (qEpj / qEpj.groupby(by=["es","d","t"]).transform("sum")).fillna(0).rename("energy_share")
energy_shares = energy_shares.reset_index("e")
energy_shares["l_input"] = "t_" + energy_shares["e"]
energy_shares = energy_shares.reset_index().set_index(["l_input","es","e","d","t"])

# Verify that energy shares sum to 1 (or 0 for groups with no energy use)
energy_shares_sum = energy_shares.groupby(by=["es","d","t"]).sum()
assert ((energy_shares_sum["energy_share"] == 0) | ((energy_shares_sum["energy_share"] - 1).abs() < 1e-9)).all(), \
    "Energy shares (theta) do not sum to 0 or 1 for all (es, d, t) groups"

## Creating relative technology potential, sqTPotential_input (indexed by (l_input, d, es, t))
sqTPotential_input = (
    energy_shares
    .reset_index("e", drop=True)
    .rename(columns={"energy_share": "sqTPotential_input"})
)

Var('sqTPotential_input', data=sqTPotential_input['sqTPotential_input'], add_missing_domains=True)

## Creating relative energy input and setting it to 1, uTE_input (indexed by (l_input, d, es, e, t))
uTE_input = pd.DataFrame(1, index=energy_shares.index, columns=["uTE_input"])

Var('uTE_input', data=uTE_input['uTE_input'], add_missing_domains=True)

# Export data
db.export('calibrate_Energy_technology_data_python.gdx')

