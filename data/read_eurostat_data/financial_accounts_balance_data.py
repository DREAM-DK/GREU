
import gamspy as gp
import eurostat
import pandas as pd

def load_data(n, t, country, year_start, year_end, **kwargs):
    # ========================================================================
    #   Module-specific sets
    # ========================================================================
    sector = gp.Set(n, 'sector', description='Sectors', records=['FinCorp', 'NonFinCorp', 'Gov', 'Hh', 'RoW'])
    al = gp.Set(n, 'al', description='Financial positions', records=['ASS', 'LIAB'])
    f = gp.Set(n, 'f', description='Financial instruments', records=['Debt', 'Equity'])

    sector_map = {"S11": "NonFinCorp", "S12": "FinCorp", "S13": "Gov", "S14": "Hh", "S15": "Hh", "S2": "RoW"}
    
    # ========================================================================
    #   Helper functions
    # ========================================================================
    def process_data(df, na_items):
        """Filter and aggregate values by sector, al, and year."""
        return (df[df["na_item"].isin(na_items)]
                .groupby(["sector", "finpos", "year"], as_index=False).agg(level=("level", "sum"))
                .rename(columns={'year': 't', 'finpos': 'al'})
                .assign(t=lambda x: x['t'].astype(str))[['sector', 'al', 't', 'level']])

    def process_data_minus_F11(df, na_items):
        """Subtract F11 (Monetary gold)."""
        base = process_data(df, na_items)
        f11 = process_data(df, ['F11'])
        return (base.merge(f11, on=['sector', 'al', 't'], suffixes=('_base', '_F11'), how='outer').fillna(0).assign(level=lambda x: x['level_base'] - x['level_F11'])[['sector', 'al', 't', 'level']])

    # ========================================================================
    #   Load raw data
    # ========================================================================
    dataset_code = 'nasa_10_f_bs'
    filter_pars = {
        'startPeriod': year_start-1, # Loads data for previous year to avoid division by zero in model
        'endPeriod': year_end, 
        'unit': 'MIO_EUR',
        'geo': country,
        'sector': ['S11','S12','S13','S14','S15','S2'],
        'na_item': ['F','F1','F11','F2','F3','F4','F5','F51','F52','F6','F7','F8'],
        'co_nco': 'CO'
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Process data
    # ========================================================================
    # Transform to long format
    raw_data = pd.melt(raw_data, id_vars=['sector','finpos','na_item'], value_vars=list(map(str, range(year_start - 1, year_end + 1))), var_name='year', value_name='level')
    raw_data['level'] = raw_data['level'] / 1000
    raw_data['sector'] = raw_data['sector'].replace(sector_map)
    raw_data = raw_data.groupby(['sector', 'finpos', 'na_item', 'year'], as_index=False)['level'].sum()

    # Financial assets and the type of income they generate
    # F1   Monetary gold and special drawing rights (SDRs)       # D41 Interests
    # -- F11 Monetary gold
    # F2   Currency and deposits                                 # D41 Interests
    # F3   Debt securities                                       # D41 Interests
    # F4   Loans                                                 # D41 Interests
    # F51  Equity                                                # D42 Distributed income of corporations, D43 Reinvested earnings on direct foreign investment
    # F52  Investment fund shares                                # D44 Other investment income
    # F6   Insurance, pensions and standardised guarantees       # D44 Other investment income
    # F7   Financial derivatives and employee stock options      # None
    # F8   Other accounts receivable/payable                     # D41 Interests

    # Debt instruments = F1 + F2 + F3 + F4 + F52 + F6 + F7 + F8 - F11
    Debt = process_data_minus_F11(raw_data, ['F1', 'F2', 'F3', 'F4', 'F52', 'F6', 'F7', 'F8']).assign(f='Debt')

    # Total financial assets (subtracted F11 Monetary gold)
    FinAssets = process_data_minus_F11(raw_data, ['F']).assign(f='vFinAssets')

    # Equity instruments = F51 
    Equity = process_data(raw_data, ['F51']).assign(f='Equity')

    # # Combine into long format
    vFinAL = pd.concat([Debt, Equity], ignore_index=True)

    # ========================================================================
    #   Store parameters in container
    # ========================================================================
    gp.Parameter(n, name='vFinAL', domain=[sector, f, al, t],
                 description='Financial assets (ASS) or liabilities (LIAB) by sector and instrument.',
                 records=vFinAL[['sector', 'f', 'al', 't', 'level']].values.tolist())

    

    
