
import gamspy as gp
import eurostat
import pandas as pd

def load_data(n, t, country, year_start, year_end, **kwargs):
    # ========================================================================
    #   Load raw data 
    # ========================================================================
    dataset_code = 'nama_10_a64_e'
    filter_pars = {
        'startPeriod': year_start - 1, 
        'endPeriod': year_end, 
        'unit': ['THS_PER', 'THS_HW'],
        'geo': country,
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)

    # ========================================================================
    #   Process data
    # ========================================================================
    # Transform to long format
    raw_data.rename(columns={'nace_r2':'i'},inplace=True)
    raw_data = pd.melt(raw_data, id_vars=['i', 'unit', 'na_item'],
                       value_vars=list(map(str, range(year_start - 1, year_end + 1))),
                       var_name='year', value_name='level')
    raw_data['level'] = raw_data['level'] * 1000

    nEmployed = raw_data[(raw_data['i'] == 'TOTAL') & (raw_data['unit'] == 'THS_PER') & (raw_data['na_item'] == 'EMP_DC')][['year', 'level']]
    hSalEmployed = raw_data[(raw_data['i'] == 'TOTAL') & (raw_data['unit'] == 'THS_HW') & (raw_data['na_item'] == 'SAL_DC')][['year', 'level']]
    hSelfEmployed = raw_data[(raw_data['i'] == 'TOTAL') & (raw_data['unit'] == 'THS_HW') & (raw_data['na_item'] == 'SELF_DC')][['year', 'level']]

    # ========================================================================
    #   Store parameters in container
    # ========================================================================
    gp.Parameter(n,name='nEmployed',domain=[t],
                 description='Total number of employees including independents',
                 records=nEmployed[['year', 'level']].values.tolist())
    gp.Parameter(n,name='hSalEmployed',domain=[t],
                 description='Total hours worked by salaried employees',
                 records=hSalEmployed[['year', 'level']].values.tolist())
    gp.Parameter(n,name='hSelfEmployed',domain=[t],
                 description='Total hours worked by self-employed employees',
                 records=hSelfEmployed[['year', 'level']].values.tolist())
