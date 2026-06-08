
import gamspy as gp
import eurostat
import pandas as pd

def load_data(n, t, country, year_start, year_end, **kwargs):
    # ========================================================================
    #   Load raw data
    # ========================================================================
    dataset_code = 'gov_10a_main'
    filter_pars = {
        'startPeriod': year_start, 
        'endPeriod': year_end, 
        'cofog99': 'TOTAL',
        'sector': 'S13',
        'unit': 'MIO_NAC',
        'geo': country,
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)
    na_item_labels = dict(eurostat.get_dic('gov_10a_exp', 'na_item'))

    # ========================================================================
    #   Process data
    # ========================================================================
    na_item_list = ['B9', 'TR', 'TE', # Net lending/net borrowing identity
                    'P11_P12_P131', 'D2REC', 'D39REC', 'D4REC', 'D5REC', 'D61REC', 'D7REC', 'D91REC', 'D92_D99REC', # Revenue components
                    'D51A_C1REC', 'D51B_C2REC',
                    'P2', 'P5', 'P51C', 'D1PAY', 'D29PAY', 'D3PAY', 'D4PAY', 'D62_D632PAY', 'D632PAY', 'D7PAY', 'D8', 'D9PAY', 'NP'] # Expenditure components

    # Eurostat na_item code -> model parameter name
    na_item_to_var = {
        # Net lending/net borrowing identity
        'B9': 'vGovBalance',
        'TR': 'vGovRevenue',
        'TE': 'vGovExpenditure',
        # Revenue components
        'P11_P12_P131': 'vGovSalesRev',
        'D2REC': 'vtIndirect',
        'D39REC': 'vGovOthSubRev',
        'D4REC': 'vGovPropertyIncome',
        'D5REC': 'vtDirect',
        'D61REC': 'vGovSocialContRev',
        'D7REC': 'vGovOthCurrentTransRev',
        'D91REC': 'vtCap',
        'D92_D99REC': 'vGovCapRev',

        'D51A_C1REC': 'vtHhIncome',
        'D51B_C2REC': 'vtCorp',
        # Expenditure components
        'P2': 'vGovIntermediateCons',
        'P5': 'vGovCapInv',
        'P51C': 'vGovDepr',
        'D1PAY': 'vGovEmplComp',
        'D29PAY': 'vGovOthProdTax',
        'D3PAY': 'vGovSub',
        'D4PAY': 'vGovInterestPayments',
        'D62_D632PAY': 'vGovSocBenefitExp',
        'D632PAY': 'vSocTransKind',
        'D7PAY': 'vGovOthCurrentTransExp',
        'D8': 'vGovAdjExp',
        'D9PAY': 'vGovCapTransExp',
        'NP': 'vGovNetAcquisitions',
    }

    # Transform to long format
    raw_data = pd.melt(raw_data, id_vars=['na_item'],
                       value_vars=list(map(str, range(year_start, year_end + 1))),
                       var_name='year', value_name='level')
    raw_data['level'] = raw_data['level'] / 1000
    raw_data['variable'] = raw_data['na_item'].map(
        lambda code: na_item_to_var.get(code) or f'v{code}'
    )

    # ========================================================================
    #   Store parameters in container
    # ========================================================================
    for na_item in na_item_list:
        var_name = na_item_to_var.get(na_item) or f'v{na_item}'
        data = raw_data[raw_data['variable'] == var_name][['year', 'level']]
        gp.Parameter(n, name=var_name, domain=[t],
                     description=f'{na_item_labels[na_item]}',
                     records=data[['year', 'level']].values.tolist())
