import pandas as pd
import dreamtools as dt
import sys
import os

## Set local paths
root = dt.find_root("LICENSE")
sys.path.insert(0, root)
#set w.d.
os.chdir(fr"{root}/model")
#get inf and growth from gdx
input_gdx=dt.Gdx('Output/calibration.gdx')

growth=input_gdx['fqt']
inflation=input_gdx['fpt']

#initialize empty databases
output_gdx=dt.GamsPandasDatabase()

#add inflation and growth
output_gdx.add_parameter_from_series(growth,add_missing_domains=True)
output_gdx.add_parameter_from_series(inflation,add_missing_domains=True)

#write output
output_gdx.export('../data/Energy_technology_data/Generic_dummy_data/inf_growth.gdx')