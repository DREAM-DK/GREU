
import gamspy as gp
import eurostat
import pandas as pd

def load_data(n, t, country, currency, year_start, year_end, **kwargs):
    # ========================================================================
    #   Module-specific sets
    # ========================================================================
    sector = gp.Set(n, 'sector', description='Sectors', records=['FinCorp', 'NonFinCorp', 'Gov', 'Hh', 'RoW'])
    sector_map = {"S11": "NonFinCorp", "S12": "FinCorp", "S13": "Gov", "S14": "Hh", "S15": "Hh", "S2": "RoW"}
    
    # ========================================================================
    #   Helper functions
    # ========================================================================
    def process_data(df, na_items):
        """Filter, aggregate, and calculate net (assets - liabilities) values."""
        result = (df[df["na_item"].isin(na_items)].groupby(["sector", "finpos", "year"], as_index=False).agg(level=("level", "sum"))
                  .replace({"sector": sector_map,"finpos": {"ASS": "as", "LIAB": "li"}})
                  .groupby(["sector", "finpos", "year"], as_index=False).agg({"level": "sum"}))
        return (result.pivot(index=["sector", "year"], columns="finpos", values="level")
                .assign(level=lambda x: x["as"] - x["li"]).reset_index().rename(columns={'year': 't'})
                .assign(t=lambda x: x['t'].astype(str))[['sector', 't', 'level']])

    def process_data_minus_F11(df, na_items):
        """Process financial data and subtract F11 (Monetary gold)."""
        base = process_data(df, na_items)
        f11 = process_data(df, ['F11'])
        return (base.merge(f11, on=['sector', 't'], suffixes=('_base', '_F11'), how='outer').fillna(0).assign(level=lambda x: x['level_base'] - x['level_F11'])[['sector', 't', 'level']])

    # ========================================================================
    #   Load raw data - Financial balance sheets
    # ========================================================================
    dataset_code = 'nasa_10_f_bs'
    filter_pars = {
        'startPeriod': year_start-1, # Loads data for previous year to avoid division by zero in model
        'endPeriod': year_end, 
        'unit': currency,
        'geo': country,
        'sector': ['S11','S12','S13','S14','S15','S2'],
        'na_item': ['F','F1','F11','F2','F3','F4','F5','F51','F6','F7','F8'],
        'co_nco': 'CO'
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Process data - Financial balance sheets
    # ========================================================================
    # Transform to long format
    raw_data = pd.melt(raw_data, id_vars=['sector','finpos','na_item'], value_vars=list(map(str, range(year_start - 1, year_end + 1))), var_name='year', value_name='level')
    raw_data['level'] = raw_data['level'] / 1000

    # Debt instruments = 
    # + F1  Monetary gold and special drawing rights (SDRs)
    # + F2  Currency and deposits
    # + F3  Debt securities
    # + F4  Loans
    # + F6  Insurance, pensions and standardised guarantees
    # + F7  Financial derivatives and employee stock options
    # + F8  Other accounts receivable/payable
    # - F11 Monetary gold

    # Debt instruments = F1 + F2 + F3 + F4 + F6 + F7 + F8 - F11
    debt_instruments = process_data_minus_F11(raw_data, ['F1', 'F2', 'F3', 'F4', 'F6', 'F7', 'F8'])
    debt_instruments['variable'] = 'vNetDebtInstruments'

    # Financial assets (subtracted F11 Monetary gold)
    financial_assets = process_data_minus_F11(raw_data, ['F'])
    financial_assets['variable'] = 'vNetFinAssets'

    # Equity instruments = F5 Equity and investment fund shares/units
    equity_instruments = process_data(raw_data, ['F5'])
    equity_instruments['variable'] = 'vNetEquity'

    # Combine into long format
    all_data = pd.concat([financial_assets, debt_instruments, equity_instruments], ignore_index=True)

    # Calculate RoW as residual to ensure data sums to zero across all sectors
    all_data = all_data[all_data['sector'] != 'RoW'].copy()
    row_residuals = (all_data.groupby(['variable', 't'], as_index=False)['level'].sum()
                     .assign(level=lambda x: -x['level'], sector='RoW'))
    all_data = pd.concat([all_data, row_residuals], ignore_index=True)

    # ========================================================================
    #   Load raw data - Non-financial transactions
    # ========================================================================
    dataset_code = 'nasa_10_nf_tr'
    filter_pars = {
        'startPeriod': year_start-1, # Loads data for previous year to avoid division by zero in model
        'endPeriod': year_end, 
        'direct': 'Paid',
        'unit': 'CP_MNAC',
        'geo': country,
        'sector': ['S11','S12','S13','S14','S15','S2'],
        'na_item': ['B9'],
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Process data - Non-financial transactions
    # ========================================================================
    # Transform to long format
    raw_data = pd.melt(raw_data, id_vars=['sector'], value_vars=list(map(str, range(year_start - 1, year_end + 1))), var_name='year', value_name='level')
    raw_data['sector'] = raw_data['sector'].replace(sector_map)
    raw_data['level'] = raw_data['level'] / 1000
    raw_data = raw_data.groupby(['sector', 'year'], as_index=False)['level'].sum()     # S14 and S15 both map to Hh — aggregate so (sector, year) is unique for GDX

    # Calculate RoW as residual to ensure data sums to zero across all sectors
    sector_flows = raw_data[raw_data['sector'] != 'RoW'].copy()
    row_residuals = (sector_flows.groupby(['year'], as_index=False)['level'].sum()
                     .assign(level=lambda x: -x['level'], sector='RoW'))
    sector_flows = pd.concat([sector_flows, row_residuals], ignore_index=True)

    # ========================================================================
    #   Store parameters in container
    # ========================================================================
    descriptions = {
        'vNetFinAssets': 'Net financial assets by sector',
        'vNetDebtInstruments': 'Net debt instruments by sector',
        'vNetEquity': 'Net equity instruments by sector',
    }
    for var_name, group in all_data.groupby('variable'):
        gp.Parameter(n, name=var_name, domain=[sector, t], description=descriptions[var_name],
                     records=group[['sector', 't', 'level']].values.tolist())

    gp.Parameter(n, name='vNetSectorFlows', domain=[sector, t], description='Net sector flows', records=sector_flows[['sector', 'year', 'level']].values.tolist())