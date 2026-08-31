import sys
import shutil
import os
from pathlib import Path
import dreamtools as dt

dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"

## Set local paths
root = dt.find_root("LICENSE")
sys.path.insert(0, root)

"""Load user-local GAMS path from user-specific-configs/gams_path.env."""
def _load_gams_from_user_config(project_root: str) -> str:
	config_path = Path(project_root) / "user-specific-configs" / "gams_path.env"
	if not config_path.exists():
		raise FileNotFoundError(
			"Missing user config: user-specific-configs/gams_path.env. "
			"Copy user-specific-configs/gams_path_template.env and set GAMS_PATH."
		)

	for raw_line in config_path.read_text(encoding="utf-8").splitlines():
		line = raw_line.strip()
		if not line or line.startswith("#"):
			continue
		if "=" not in line:
			continue

		key, value = line.split("=", 1)
		if key.strip() == "GAMS_PATH":
			gams_path = value.strip().strip('"').strip("'")
			if gams_path:
				return gams_path

	raise ValueError(
		"GAMS_PATH not found in user-specific-configs/gams_path.env. "
		"Set GAMS_PATH to your local gams.exe path."
	)

# loads the "GAMS" env variable if exists. Otherwise sets it based on user-specific-configs/gams_path.env
os.environ["GAMS"] = os.environ.get("GAMS") or _load_gams_from_user_config(root)


## Set working directory
os.chdir(fr"{root}/model")

## Create data.gdx based on GreenREFORM-DK data 
import data.Modules.financial_accounts.financial_accounts_data
import data.preprocessing.read_data
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
