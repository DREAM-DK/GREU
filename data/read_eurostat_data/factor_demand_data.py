import numpy as np
import gamspy as gp
import eurostat
import pandas as pd
# import modules.sets_data as sets_data

def load_data(n, t, country, currency, year_start, year_end, i_list=None, k_list=None, **kwargs):
    # ========================================================================
    #   Helper function - Price indices
    # ========================================================================
    def price_indicies_by_unit(df, numerator_unit, denominator_unit, key_cols, year_end):
        num = df.loc[df['unit'] == numerator_unit, key_cols + ['level']].rename(
            columns={'level': 'level_num'})
        den = df.loc[df['unit'] == denominator_unit, key_cols + ['level']].rename(
            columns={'level': 'level_den'})
        out = num.merge(den, on=key_cols, how='inner')
        out['level'] = out['level_num'] / out['level_den']
        out = out.drop(columns=['level_num', 'level_den'])
        if 'year' in key_cols:
            rebase_keys = [c for c in key_cols if c != 'year']
            ymatch = pd.to_numeric(out['year'], errors='coerce') == year_end
            base = out.loc[ymatch, rebase_keys + ['level']].rename(columns={'level': '_base'})
            out = out.merge(base, on=rebase_keys, how='left')
            out['level'] = out['level'] / out['_base']
            out = out.drop(columns=['_base'])
        return out

    def deflate_by_price_index(nominal_df, price_index_df, key_cols, nominal_col='level', index_col='level'):
        """Real (deflated) series = nominal / rebased price index, aligned on ``key_cols``."""
        nom = nominal_df[key_cols + [nominal_col]].rename(columns={nominal_col: '_nom'})
        idx = price_index_df[key_cols + [index_col]].rename(columns={index_col: '_idx'})
        out = nom.merge(idx, on=key_cols, how='inner')
        out['level'] = out['_nom'] / out['_idx']
        out = out.drop(columns=['_nom', '_idx'])
        return out

    # ========================================================================
    #   Load raw data - Capital stock data
    # ========================================================================
    dataset_code = 'nama_10_nfa_st'
    filter_pars = {
        'startPeriod': year_start, # Loads data for previous year because of lagged values in model
        'endPeriod': year_end, 
        'unit': ['CRC_MNAC', 'PYR_MNAC'],
        'asset10': ['N11G','N11KG','N11MG','N115G','N117G'],
        'geo': country,
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Process data
    # ========================================================================
    # Transform to long format 
    raw_data.rename(columns={'nace_r2':'i', 'asset10':'k'},inplace=True)
    raw_data = pd.melt(raw_data, id_vars=['i', 'k', 'unit'],
                       value_vars=list(map(str, range(year_start, year_end + 1))),
                       var_name='year', value_name='level')
    raw_data['level'] = raw_data['level'] / 1000

    # Rename and aggregate data
    k_list_rename = {'N11G': 'iTot','N11KG': 'iB','N11MG': 'iM','N115G': 'iM','N117G': 'iM'}
    raw_data['k'] = raw_data['k'].replace(k_list_rename)
    raw_data = raw_data.groupby(['i', 'k', 'year', 'unit'], as_index=False)['level'].sum()
 
    # Deflate capital stock data
    pK_k_i = price_indicies_by_unit(raw_data, 'CRC_MNAC', 'PYR_MNAC', ['i', 'k', 'year'], year_end)
    qK_k_i_nominal = raw_data[raw_data['i'].isin(i_list) & raw_data['k'].isin(k_list) & (raw_data['unit'] == 'CRC_MNAC')]
    qK_k_i = deflate_by_price_index(qK_k_i_nominal, pK_k_i, ['i', 'k', 'year'])

    # # Test data consistency
    # assert np.allclose(raw_data[raw_data['k']=='iTot'].level.reset_index(drop=True),
    #                    raw_data[raw_data['k']=='iB'].level.reset_index(drop=True) 
    #                    +raw_data[raw_data['k']=='iM'].level.reset_index(drop=True), rtol=1e-3, atol=1e-3), "Data inkonsistency: qK_k_i['Tot'] != qK_k_i['iM'] + qK_k_i['iB']"

    # ========================================================================
    #   Load raw data - Investment data
    # ========================================================================
    dataset_code = 'nama_10_a64_p5'
    filter_pars = {
        'startPeriod': year_start, # Loads data for previous year because of lagged values in model
        'endPeriod': year_end, 
        'unit': ['CP_MNAC', 'PYP_MNAC'],
        'asset10': ['N11G','N11KG','N11MG','N115G','N117G','N12G'],
        'na_item': ['P51G','P52'],
        'geo': country,
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Process data - Investment data
    # ========================================================================
    # Transform to long format 
    raw_data.rename(columns={'nace_r2':'i', 'asset10':'k'},inplace=True)
    raw_data = pd.melt(raw_data, id_vars=['i','k', 'unit','na_item'],
                       value_vars=list(map(str, range(year_start, year_end + 1))),
                       var_name='year', value_name='level')
    raw_data['level'] = raw_data['level'] / 1000

    # Rename and aggregate data
    raw_data['k'] = raw_data['k'].replace(k_list_rename)
    raw_data = raw_data[raw_data['i'].isin(i_list)]

    vI_k_i = raw_data[raw_data['k'].isin(k_list) & raw_data['na_item'].isin(['P51G'])]
    vI_k_i = vI_k_i.groupby(['i', 'k', 'unit', 'year'], as_index=False)['level'].sum()

    vInvt_i = raw_data[raw_data['k'].isin(['N12G']) & raw_data['na_item'].isin(['P52'])]

    # Deflate investment data
    pI_k_i = price_indicies_by_unit(vI_k_i, 'CP_MNAC', 'PYP_MNAC', ['i', 'k', 'year'], year_end)
    qI_k_i_nominal = vI_k_i[vI_k_i['unit'] == 'CP_MNAC']
    qI_k_i = deflate_by_price_index(qI_k_i_nominal, pI_k_i, ['i', 'k', 'year'])
    
    pInvt_i = price_indicies_by_unit(vInvt_i, 'CP_MNAC', 'PYP_MNAC', ['i', 'year'], year_end)
    qInvt_i_nominal = vInvt_i[vInvt_i['unit'] == 'CP_MNAC']
    qInvt_i = deflate_by_price_index(qInvt_i_nominal, pInvt_i, ['i', 'year'])

    # Test data consistency
    # assert np.allclose(raw_data[raw_data['k']=='iTot'].level.reset_index(drop=True),
    #                    raw_data[raw_data['k']=='iB'].level.reset_index(drop=True) 
    #                    +raw_data[raw_data['k']=='iM'].level.reset_index(drop=True), rtol=1e-3, atol=1e-3), "Data inkonsistency: qI_k_i['Tot'] != qI_k_i['iM'] + qI_k_i['iB']"
    
    # ========================================================================
    #   Store parameters in container
    # ========================================================================

    gp.Parameter(n,name='qK_k_i',domain=[n['k'], n['i'], t],
                 description='Capital stock by capital type and industry',
                 records=qK_k_i[['k', 'i', 'year', 'level']].values.tolist())
    gp.Parameter(n,name='qI_k_i',domain=[n['k'], n['i'], t],
                 description='Gross fixed capital formation by capital type and industry',
                 records=qI_k_i[['k', 'i', 'year', 'level']].values.tolist())             
    gp.Parameter(n,name='qInvt_i',domain=[n['i'], t],
                 description='Inventory investment by industry',
                 records=qInvt_i[['i', 'year', 'level']].values.tolist())

