import gamspy as gp
import pandas as pd
import os
import dreamtools as dt

root = dt.find_root("LICENSE")
os.chdir(fr"{root}/model")
#load container
s = gp.Container()
s.loadRecordsFromGdx('./Output/calibration.gdx',symbol_names=['e', 't', 'pE_avg'])

t_sub = ['2020']

# filter + rename
df = s['pE_avg'].records
df_filtered = df[df['t'].isin(t_sub)]

pE_new = gp.Variable(s, 'price_vector0', domain=[s['e'], s['t']])
pE_new.records = df_filtered


s.write('../data/initial_energy_price.gdx')