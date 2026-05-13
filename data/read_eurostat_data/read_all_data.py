#%%
import numpy as np
import pandas as pd
import gamspy as gp
import eurostat
import os
import sys
import importlib

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

_modules_dir = os.path.dirname(os.path.abspath(__file__))

pd.set_option("mode.copy_on_write", True)
n = gp.Container()

# ========================================================================
#   Settings
# ========================================================================
country = ['DK']
currency = ['MIO_NAC'] # THIS DOES NOT APPLY TO ALL DATASETS, AS THEY HAVE DIFFERENT CURRENCY CODES

year_start = 2022 # Lagged varibles are loaded when needed
year_end = 2022

# Each module must live in data/load_eurostat_data/ and provide:
#   - {name}_data.py with a load_data(n, t, country, currency, year_start, year_end) function
modules = [
    'input_output',
    'labor_market',
    'factor_demand',
    'financial_accounts',
    'government',
]

# ========================================================================
#   Define sets
# ========================================================================
# Note:  
# Changes in these sets may require modifications in the modules, due to differences in how industries are grouped across datasets
i_list = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S'] # 'T', 'U' are excluded for now
k_list =  ['iM', 'iB'] 
re_list = ['B', 'D'] # Itermediate energy-input.
energy_list = ['energy']
factors_of_production = k_list + ['labor', 'RxE'] + energy_list
i_public_list = ['O', 'P', 'Q']
i_private_list = [x for x in i_list if x not in i_public_list]
i_private_fin_list = ['K']
i_private_nonfin_list = [x for x in i_private_list if x not in i_private_fin_list]

t = gp.Set(n, 't', description='year', records=range(1980, 2100))
t1 = gp.Set(n, 't1', description='First data year', records=[str(year_start)])
i = gp.Set(n, 'i', description='Industries', records=i_list)
k = gp.Set(n, 'k', description='Capital', records=k_list)
energy = gp.Set(n, 'energy', description='Energy', records=energy_list)
factors_of_production = gp.Set(n, 'factors_of_production', description='Factors of production', records=factors_of_production)
i_public = gp.Set(n, 'i_public', domain=i, description='Public industries', records=i_public_list or None)
i_private = gp.Set(n, 'i_private', domain=i, description='Private industries', records=i_private_list)
i_private_fin = gp.Set(n, 'i_private_fin', domain=i, description='Private financial industry', records=i_private_fin_list)
i_private_nonfin = gp.Set(n, 'i_private_nonfin', domain=i, description='Private non-financial industries', records=i_private_nonfin_list)

# ========================================================================
#   Load all modules into a container
# ========================================================================
for module_name in modules:
    mod = importlib.import_module(f'{module_name}_data')
    importlib.reload(mod)
    mod.load_data(n, t, country, currency, year_start, year_end, i_list=i_list, k_list=k_list, re_list=re_list, energy_list=energy_list)

# ========================================================================
#   Define sets based on data
# ========================================================================
# Industries with imports defined by IO-data with with imports
vIO_m = n['vIO_m'].records
m_records = vIO_m.groupby('i')['value'].apply(lambda x: (x != 0).any())
m_records = m_records[m_records].index.tolist()
gp.Set(n, 'm', domain=n['i'], description='Industries with imports', records=m_records)

# ========================================================================
#   Export to GDX
# ========================================================================
gdx_path = os.path.join(_modules_dir, '../data_eurostat.gdx')
n.write(gdx_path)

