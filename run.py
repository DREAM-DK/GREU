import sys
import shutil
import os
import dreamtools as dt

dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"

## Set local paths
root = dt.find_root("LICENSE")
sys.path.insert(0, root)
os.environ["GAMS"] = "C:/GAMS/51/gams.exe"

## Set working directory
os.chdir(fr"{root}/model")

## Create data.gdx based on GreenREFORM-DK data 
import data.Modules.financial_accounts.financial_accounts_data
dt.gamY.run("../data/data_from_GR.gms")

## Run the base CGE model - creating main_CGE.gdx
dt.gamY.run("base_model.gms", s="saved/base_model", test_CGE="1")

## Run the base model with energy technology model - creating main_energy_technology.gdx
dt.gamY.run("base_model_energy_technology.gms", s="saved/base_model_energy_technology", test_CGE="0", test_energy_technology="1")

## Run a simple shock model - creating shock.gdx
dt.gamY.run("shock_model.gms", include_energy_technology="1")

## Run a CO2 tax shock
dt.gamY.run("shock_CO2_tax.gms", r="saved/base_model", include_energy_technology="0")
dt.gamY.run("shock_CO2_tax.gms", r="saved/base_model_energy_technology", include_energy_technology="1")

## Run a CO2 tax shock with steps
dt.gamY.run("shock_CO2_tax_steps.gms", r="saved/base_model", include_energy_technology="0")
dt.gamY.run("shock_CO2_tax_steps.gms", r="saved/base_model_energy_technology", include_energy_technology="1")

## Open run_report.py to see all the reporting
exec(open('../run_report.py').read())