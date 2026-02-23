#%%
import numpy as np
import pandas as pd
import gamspy as gp
import eurostat 
import os

## SETTINGS
geo_list = ['DK']
year_start = 2019
year_end = 2020

## Initializing container and constructing GAMS sets
n = gp.Container()
pd.set_option("mode.copy_on_write", True)

data_sets = {}
# Sector set: FinCorp, NonFinCorp, Gov, Hh, RoW
data_sets['sector'] = ['FinCorp', 'NonFinCorp', 'Gov', 'Hh', 'RoW']

# Insert sets into container
t_list = [year for year in range(1980, 2100)] # List of model years
t      = gp.Set(n,'t',description='year',records=t_list)
t1     = gp.Set(n,'t1',description='First data year',records=[str(year_start)])

sector = gp.Set(n, 'sector', description='Sectors', records=data_sets['sector'])

# Read data from Eurostat
code_financial_accounts = 'nasa_10_f_bs'
filter_pars_financial_accounts = {
    'startPeriod': year_start, 
    'endPeriod': year_end, 
    'unit': 'MIO_NAC',
    'geo': geo_list,
    'sector': ['S11','S12','S13','S14','S15','S2'],
    'na_item': ['F','F1','F11','F2','F3','F4','F5','F51','F6','F7','F8'],
    'co_nco': 'CO'
}
data_financial_accounts = eurostat.get_data_df(code_financial_accounts, filter_pars=filter_pars_financial_accounts)
data_financial_accounts = pd.melt(data_financial_accounts, id_vars=['sector','finpos','na_item'], value_vars=list(map(str, range(year_start, year_end + 1))), var_name='year', value_name='level')
data_financial_accounts['level'] = data_financial_accounts['level']/1000

# Helper function to process financial data (filter, aggregate, calculate net) and return only net values
def process_financial_data(df, na_items):
    result = (df[df["na_item"].isin(na_items)].groupby(["sector", "finpos", "year"], as_index=False).agg(level=("level", "sum"))
              .replace({"sector": {"S11": "NonFinCorp", "S12": "FinCorp", "S13": "Gov", "S14": "Hh", "S15": "Hh", "S2": "RoW"},"finpos": {"ASS": "as", "LIAB": "li"}})
              .groupby(["sector", "finpos", "year"], as_index=False).agg({"level": "sum"}))
    
    return (result.pivot(index=["sector", "year"], columns="finpos", values="level")
            .assign(level=lambda x: x["as"] - x["li"]).reset_index().rename(columns={'year': 't'})
            .assign(t=lambda x: x['t'].astype(str))[['sector', 't', 'level']])

# Helper function to process financial data and subtract F11
def process_financial_data_minus_F11(df, na_items):
    base = process_financial_data(df, na_items)
    f11 = process_financial_data(df, ['F11'])
    return (base.merge(f11, on=['sector', 't'], suffixes=('_base', '_F11'), how='outer').fillna(0).assign(level=lambda x: x['level_base'] - x['level_F11'])[['sector', 't', 'level']])

# Debt instruments = 
# + F1  Monetary gold and special drawing rights (SDRs)
# + F2  Currency and deposits
# + F3  Debt securities
# + F4  Loans
# + F6  Insurance, pensions and standardised guarantees
# + F7  Financial derivatives and employee stock options
# + F8  Other accounts receivable/payable
# - F11 Monetary gold
debt_instruments = process_financial_data_minus_F11(data_financial_accounts, ['F1', 'F2', 'F3', 'F4', 'F6', 'F7', 'F8']) # F11 is subtracted inside the function

# Financial assets (Subtracted F11 Monetary gold)
financial_assets = process_financial_data_minus_F11(data_financial_accounts, ['F']) # F11 is subtracted inside the function

# Equity instruments = F5 Equity and investment fund shares/units
equity_instruments = process_financial_data(data_financial_accounts, ['F5'])

# Calculate RoW as residual to ensure data sums to zero across all sectors
# First, remove any existing RoW data (if it exists from S2 mapping)
financial_assets = financial_assets[financial_assets['sector'] != 'RoW'].copy()
debt_instruments = debt_instruments[debt_instruments['sector'] != 'RoW'].copy()
equity_instruments = equity_instruments[equity_instruments['sector'] != 'RoW'].copy()

# For each time period, RoW = -sum(Hh, FinCorp, NonFinCorp, Gov)
row_finassets_list = []
row_debt_list = []
row_equity_list = []
for year in financial_assets['t'].unique():
    # Financial assets: RoW = -sum of other sectors
    row_finassets = -financial_assets[financial_assets['t'] == year]['level'].sum()
    row_finassets_list.append({'sector': 'RoW', 't': year, 'level': row_finassets})
    
    # Debt instruments: RoW = -sum of other sectors
    row_debt = -debt_instruments[debt_instruments['t'] == year]['level'].sum()
    row_debt_list.append({'sector': 'RoW', 't': year, 'level': row_debt})
    
    # Equity instruments: RoW = -sum of other sectors
    row_equity = -equity_instruments[equity_instruments['t'] == year]['level'].sum()
    row_equity_list.append({'sector': 'RoW', 't': year, 'level': row_equity})

# Add RoW rows to dataframes
if row_finassets_list:
    financial_assets = pd.concat([financial_assets, pd.DataFrame(row_finassets_list)], ignore_index=True)
if row_debt_list:
    debt_instruments = pd.concat([debt_instruments, pd.DataFrame(row_debt_list)], ignore_index=True)
if row_equity_list:
    equity_instruments = pd.concat([equity_instruments, pd.DataFrame(row_equity_list)], ignore_index=True)

# Create parameters with domain [sector, t] (only net values, including RoW as residual)
vNetFinAssets = gp.Parameter(n, name='vNetFinAssets', domain=[sector, t], description='Net financial assets by sector', records=financial_assets[['sector', 't', 'level']].values.tolist())
vNetDebtInstruments = gp.Parameter(n, name='vNetDebtInstruments', domain=[sector, t], description='Net debt instruments by sector', records=debt_instruments[['sector', 't', 'level']].values.tolist())
vNetEquity = gp.Parameter(n, name='vNetEquity', domain=[sector, t], description='Net equity instruments by sector', records=equity_instruments[['sector', 't', 'level']].values.tolist())

## EXPORT DATA (same folder as this script)
_gdx_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'financial_accounts_data.gdx')
n.write(_gdx_path)

# %%
