
import gamspy as gp
import eurostat
import pandas as pd

def load_data(n, t, country, year_start, year_end, i_list=None, re_list=None, energy_list=None, **kwargs):
    # ========================================================================
    #   Define sets 
    # ========================================================================
    # Rename items from eurostat data to model names
    def rename(items, mapping):
        return list(dict.fromkeys(mapping.get(item, item) for item in items))
    
    # Industries (detailed Eurostat codes for data loading)
    i_list_raw = ['A01', 'A02', 'A03', 'B', 'C10-12', 'C13-15', 'C16', 'C17', 'C18', 'C19',
        'C20', 'C21', 'C22', 'C23', 'C24', 'C25', 'C26', 'C27', 'C28', 'C29',
        'C30', 'C31_32', 'C33', 'D35', 'E36', 'E37-39', 'F', 'G45', 'G46', 'G47',
        'H49', 'H50', 'H51', 'H52', 'H53', 'I', 'J58', 'J59_60', 'J61', 'J62_63',
        'K64', 'K65', 'K66', 'L68A', 'L68B', 'M69_70', 'M71', 'M72', 'M73',
        'M74_75', 'N77', 'N78', 'N79', 'N80-82', 'O84', 'P85', 'Q86', 'Q87_88',
        'R90-92', 'R93', 'S94', 'S95', 'S96', 'T', 'U']
    i_agg_map = {code: code[0] for code in i_list_raw}

    # Input components
    nettax_list_rename = {'D21X31': 'vNetProductTax', 'D29X39': 'vNetOtherProductionTax'}
    nettax_list = rename(['D21X31', 'D29X39'], nettax_list_rename)
    
    value_added_list_rename = {'D1': 'CompEmpl', 'B2A3G': 'OpSurplus'}
    value_added_list = rename(['D1', 'B2A3G'], value_added_list_rename)

    m_list_rename = {'P7': 'm'}
    m_list = rename(['P7'], m_list_rename)

    # Output components
    c_list_rename = {'P3_S14': 'cHh', 'P3_S15': 'cHh'}
    c_list = rename(['P3_S14', 'P3_S15'], c_list_rename)

    g_list_rename = {'P3_S13': 'cGov'}
    g_list = rename(['P3_S13'], g_list_rename)

    k_list = ['iM', 'iB']

    invt_list_rename = {'P52': 'invt'}
    invt_list = rename(['P52'], invt_list_rename) 

    invt_ene_list = ['invt_ene']

    x_list_rename = {'P6': 'xOth'}
    x_list = rename(['P6'], x_list_rename)

    rx_list = [i for i in i_list if i not in re_list]

    # Defining aggregated sets
    d_list = i_list + c_list + g_list + k_list + invt_list + invt_ene_list + x_list + energy_list
    d_rename = {**c_list_rename, **g_list_rename, **invt_list_rename, **x_list_rename}

    d_ene_list = re_list + invt_ene_list + energy_list
    d_non_ene_list = [i for i in d_list if i not in d_ene_list]
    
    a_list = nettax_list + value_added_list
    a_rename = {**nettax_list_rename, **value_added_list_rename}

    # Store sets
    i = gp.Set(n, 'i', description='Industries', records = i_list)
    rx = gp.Set(n, 'rx', description='Non-energy intermediate input types', records = rx_list)
    re = gp.Set(n, 're', description='Energy intermediate input types', records = re_list)
    a_rows_ = gp.Set(n, 'a_rows_', description='Other rows in the input-output table', records = a_list)
    k = gp.Set(n, 'k', description='Capital', records = k_list)
    c = gp.Set(n, 'c', description='Private consumption', records = c_list)
    g = gp.Set(n, 'g', description='Government consumption', records = g_list)
    invt = gp.Set(n, 'invt', description='Inventories', records = invt_list)
    invt_ene = gp.Set(n, 'invt_ene', description='Energy inventories', records = invt_ene_list)
    x = gp.Set(n, 'x', description='Exports', records = x_list)
    d = gp.Set(n, 'd', description='Demand components', records = d_list)
    d_non_ene = gp.Set(n, 'd_non_ene', description='Non-energy demand components', records = d_non_ene_list)
    d_ene = gp.Set(n, 'd_ene', description='Energy demand components', records = d_ene_list)

    # ========================================================================
    #   Load raw data for domestic demand
    # ========================================================================
    dataset_code = 'naio_10_fcp_ii3'
    filter_pars = {
        'startPeriod': year_start - 1, 
        'endPeriod': year_end, 
        'unit': 'MIO_EUR',
        'c_dest': country,
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Load raw data for exports
    # ========================================================================
    filter_pars = {
        'startPeriod': year_start - 1, 
        'endPeriod': year_end, 
        'unit': 'MIO_EUR',
        'c_orig': country,
    }
    raw_data_exports = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Process data
    # ========================================================================
    # Transform to long format
    raw_data.rename(columns={'ind_ava': 'i', 'ind_use': 'd', 'c_orig\TIME_PERIOD': 'c_orig'}, inplace=True)    
    raw_data = pd.melt(raw_data, id_vars=['i', 'd', 'c_dest', 'c_orig'],
                       value_vars=list(map(str, range(year_start - 1, year_end + 1))),
                       var_name='year', value_name='level')
    
    # Map country of origin to domestic vs import supply
    raw_data['c_orig'] = raw_data['c_orig'].isin([country,'DOM']).map({True: 'DOM', False: 'IMP'})
    raw_data['i'] = raw_data['i'].replace(a_rename)
    raw_data['d'] = raw_data['d'].replace(d_rename)
    raw_data['i'] = raw_data['i'].replace(i_agg_map)
    raw_data['d'] = raw_data['d'].replace(i_agg_map)
    raw_data = raw_data.groupby(['i', 'd', 'c_orig', 'year'], as_index=False)['level'].sum()

    # Split P51G (gross fixed capital formation) into iB (from construction) and iM (from other industries)
    raw_data.loc[(raw_data['d'] == 'P51G') & (raw_data['i'] == 'F'), 'd'] = 'iB'
    raw_data.loc[(raw_data['d'] == 'P51G'), 'd'] = 'iM'

    # Set invt_ene to zero for all industries (can be populated by user)
    raw_data = pd.concat([raw_data, raw_data[raw_data['d'] == 'invt'].assign(d='invt_ene', level=0)])
    
    # Exports
    raw_data_exports.rename(columns={'ind_ava': 'i', 'ind_use': 'd', 'c_orig\TIME_PERIOD': 'c_orig'}, inplace=True)
    raw_data_exports = pd.melt(raw_data_exports, id_vars=['i', 'd', 'c_dest', 'c_orig'],
                       value_vars=list(map(str, range(year_start - 1, year_end + 1))),
                       var_name='year', value_name='level')
    raw_data_exports = raw_data_exports[raw_data_exports['c_dest'] != country]
    raw_data_exports['i'] = raw_data_exports['i'].replace(i_agg_map)
    raw_data_exports = raw_data_exports.groupby(['i', 'year'], as_index=False)['level'].sum()
    raw_data_exports = raw_data_exports.assign(d='xOth', c_orig='DOM')

    # Add the exports to the IO-data
    raw_data = pd.concat(
        [raw_data, raw_data_exports[['i', 'd', 'c_orig', 'year', 'level']]],
        ignore_index=True,
    )
    
    # Defining variables for domestic supply, imports and decomposition of GVA
    vIO_y = raw_data[(raw_data['c_orig'] == 'DOM')
                    & raw_data['i'].isin(i_list)
                    & raw_data['d'].isin(d_list)][['i', 'd', 'year', 'level']]

    vIO_m = raw_data[(raw_data['c_orig'] == 'IMP')
                    & raw_data['i'].isin(i_list)
                    & raw_data['d'].isin(d_list)][['i', 'd', 'year', 'level']]

    raw_data_total = raw_data.groupby(['i', 'd', 'c_orig', 'year'], as_index=False)['level'].sum()
    vIO_a = raw_data_total[(raw_data_total['c_orig'] == 'DOM')
                    & raw_data_total['i'].isin(a_list)
                    & raw_data_total['d'].isin(d_list)][['i', 'd', 'year', 'level']]

    # ========================================================================
    #   Store parameters in container
    # ========================================================================
    gp.Parameter(n, name='vIO_y', domain=[i, d, t],
                 description='IO-data, domestic supply',
                 records=vIO_y[['i', 'd', 'year', 'level']].values.tolist())
    gp.Parameter(n, name='vIO_m', domain=[i, d, t],
                 description='IO-data, imports',
                 records=vIO_m[['i', 'd', 'year', 'level']].values.tolist())
    gp.Parameter(n, name='vIO_a', domain=[a_rows_, d, t],
                 description='Total demand by demand component',
                 records=vIO_a[['i', 'd', 'year', 'level']].values.tolist())
