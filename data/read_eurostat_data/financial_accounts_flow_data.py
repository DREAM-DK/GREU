
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
    def _na_item_mask(df, na_item):
        if isinstance(na_item, (list, tuple, set)):
            return df['na_item'].isin(na_item)
        return df['na_item'] == na_item

    def net_direct_flow(df, na_item):
        """Compute net flow (RECV - PAID) for a given na_item (or list of na_items)."""
        flows = (
            df[_na_item_mask(df, na_item)]
            .groupby(['sector', 'year', 'direct'], as_index=False)['level'].sum()
        )
        recv = flows[flows['direct'] == 'RECV'].drop(columns='direct')
        paid = flows[flows['direct'] == 'PAID'].drop(columns='direct')
        return (
            recv.merge(paid, on=['sector', 'year'], how='outer', suffixes=('_recv', '_paid'))
            .fillna(0)
            .assign(level=lambda x: x['level_recv'] - x['level_paid'])[['sector', 'year', 'level']]
        )

    def get_flow(df, na_item, flow_type, sectors=None):
        """Return flows for na_item and flow_type ('RECV', 'PAID', or 'NET').

        sectors: optional list of sector names to include; None means all sectors.
        """
        if flow_type == 'NET':
            result = net_direct_flow(df, na_item)
        else:
            result = (
                df[_na_item_mask(df, na_item) & (df['direct'] == flow_type)]
                .groupby(['sector', 'year'], as_index=False)['level'].sum()
            )
        if sectors is not None:
            result = result[result['sector'].isin(sectors)]
        return result

    # ========================================================================
    #   Load raw data 
    # ========================================================================
    dataset_code = 'nasa_10_nf_tr'
    filter_pars = {
        'startPeriod': year_start-1, # Loads data for previous year to avoid division by zero in model
        'endPeriod': year_end, 
        'unit': 'CP_MEUR',
        'geo': country,
        'sector': ['S11','S12','S13','S14','S15','S2'],
        'na_item': ['B9', 'B8G', 'D9', 'P5G', 'NP', 'B6G', 'P3', 'D8', 'B5G', 'D5', 
                    'D6', 'D61', 'D62', 'D63', 'D7', 'B2A3G', 'D1', 'D2', 'D3', 'D4', 'D41', 'D42', 'D43', 'D44', 'D45',
                    'P6', 'P7'],
    }
    raw_data = eurostat.get_data_df(dataset_code, filter_pars=filter_pars)
    na_item_labels = dict(eurostat.get_dic('nasa_10_nf_tr', 'na_item'))

    # ========================================================================
    #   Process data
    # ========================================================================
    # Transform to long format
    raw_data = pd.melt(raw_data, id_vars=['direct', 'na_item', 'sector'], value_vars=list(map(str, range(year_start - 1, year_end + 1))), var_name='year', value_name='level')
    raw_data['sector'] = raw_data['sector'].replace(sector_map)
    raw_data['level'] = raw_data['level'] / 1000
    raw_data = raw_data.groupby(['direct', 'na_item', 'sector', 'year'], as_index=False)['level'].sum()     # S14 and S15 both map to Hh — aggregate so (sector, year) is unique for GDX

    # Reallocate Hh B2A3G (mixed income) to NonFinCorp.
    # Offsetting via B2A3G_correction transfer from NonFinCorp to Hh
    b2a3g_correction_hh = raw_data.loc[(raw_data['direct'] == 'RECV') & (raw_data['na_item'] == 'B2A3G') & (raw_data['sector'] == 'Hh')].replace({'B2A3G': 'B2A3G_correction'})
    b2a3g_correction_nonfincorp = b2a3g_correction_hh.copy().replace({'Hh': 'NonFinCorp', 'RECV': 'PAID'})
    raw_data = pd.concat([raw_data, b2a3g_correction_hh, b2a3g_correction_nonfincorp], ignore_index=True)

    raw_data = raw_data.merge(
        b2a3g_correction_nonfincorp[['direct','na_item','sector','year','level']].replace({'B2A3G_correction': 'B2A3G'}).rename(columns={'level':'corr'}),
        on=['direct','na_item','sector','year'],
        how='left'
    ).assign(level=lambda x: x['level'] + x['corr'].fillna(0)).drop(columns='corr')

    # Financial assets and the type of income they generate
    # F1   Monetary gold and special drawing rights (SDRs)       # D41 Interests
    # -- F11 Monetary gold
    # F2   Currency and deposits                                 # D41 Interests
    # F3   Debt securities                                       # D41 Interests
    # F4   Loans                                                 # D41 Interests
    # F51  Equity                                                # D42 Distributed income of corporations, D43 Reinvested earnings on direct foreign investment
    # F52  Investment fund shares                                # D44
    # F6   Insurance, pensions and standardised guarantees       # D44
    # F7   Financial derivatives and employee stock options      # None
    # F8   Other accounts receivable/payable                     # D41 Interests

    vFinIncome_equity_ass = get_flow(raw_data, 'D42', 'RECV').assign(f='Equity', al='ASS')
    vFinIncome_equity_liab = get_flow(raw_data, 'D42', 'PAID').assign(f='Equity', al='LIAB')
    vFinIncome_debt_ass = get_flow(raw_data, ['D41', 'D43', 'D44', 'D45'], 'RECV').assign(f='Debt', al='ASS')
    vFinIncome_debt_liab = get_flow(raw_data, ['D41', 'D43', 'D44', 'D45'], 'PAID').assign(f='Debt', al='LIAB')
    vFinIncome = (
        pd.concat([vFinIncome_equity_ass, vFinIncome_equity_liab, vFinIncome_debt_ass, vFinIncome_debt_liab], ignore_index=True)
        .rename(columns={'year': 't'})
        .assign(t=lambda x: x['t'].astype(str))
    )
    
    vNetFinTransactions = get_flow(raw_data, 'B9', 'RECV')[['sector', 'year', 'level']]

    # Households
    vNetTransfers2Hh = get_flow(raw_data, ['D5', 'D61', 'D62', 'D7', 'D8', 'D9'], 'NET', ['Hh'])[['year', 'level']]
    vHhConsumption = get_flow(raw_data, 'P3', 'PAID', ['Hh'])[['year', 'level']]
    vHhWages = get_flow(raw_data, 'D1', 'RECV', ['Hh'])[['year', 'level']]
    vCorrectionNonFinCorp2Hh = get_flow(raw_data, 'B2A3G_correction', 'RECV', ['Hh'])[['year', 'level']]

    ## Corporations
    vNetTransfers2FinCorp = get_flow(raw_data, ['D5', 'D61', 'D62', 'D7', 'D8', 'D9'], 'NET', ['FinCorp'])[['year', 'level']]
    vNetTransfers2NonFinCorp = get_flow(raw_data, ['D5', 'D61', 'D62', 'D7', 'D8', 'D9'], 'NET', ['NonFinCorp'])[['year', 'level']]
    vGrossCapitalFormation = get_flow(raw_data, 'P5G', 'PAID', ['FinCorp', 'NonFinCorp','Hh'])[['sector', 'year', 'level']]
    vGrossOpSurplusMixedIncome = get_flow(raw_data, 'B2A3G', 'RECV', ['FinCorp', 'NonFinCorp'])[['sector', 'year', 'level']]
    vNonFinancialNonProducesAssets = get_flow(raw_data, 'NP', 'PAID', ['FinCorp', 'NonFinCorp', 'Hh', 'RoW'])[['sector','year', 'level']]

    # Rest of World
    vRowPrimaryIncomeCurrentBalanceOther = get_flow(raw_data, ['D1', 'D2', 'D3', 'D5', 'D6', 'D7', 'D8', 'D9'], 'NET', ['RoW'])[['year', 'level']]
    vExports = get_flow(raw_data, 'P6', 'PAID', ['RoW'])[['year', 'level']]
    vImports = get_flow(raw_data, 'P7', 'RECV', ['RoW'])[['year', 'level']]


    # ========================================================================
    #   Store parameters in container
    # ========================================================================
    gp.Parameter(n, name='vFinIncome', domain=[sector, f, al, t],
                 description='Property income received (ASS) or paid (LIAB) by sector and instrument.',
                 records=vFinIncome[['sector', 'f', 'al', 't', 'level']].values.tolist())

    gp.Parameter(n, name='vNetFinTransactions', domain=[sector, t], 
                 description='Net lending/netborrowing by sector.',
                 records=vNetFinTransactions[['sector', 'year', 'level']].values.tolist())

    gp.Parameter(n, name='vNetTransfers2Hh', domain=[t], 
                 description='Net transfers received by households.',
                 records=vNetTransfers2Hh[['year', 'level']].values.tolist())
    gp.Parameter(n, name='vHhConsumption', domain=[t],
                 description='Household consumption.',
                 records=vHhConsumption[['year', 'level']].values.tolist())
    gp.Parameter(n, name='vHhWages', domain=[t],
                 description='Household wages.',
                 records=vHhWages[['year', 'level']].values.tolist())
    gp.Parameter(n, name='vCorrectionNonFinCorp2Hh', domain=[t],
                 description='Correction of non-financial corporations to households.',
                 records=vCorrectionNonFinCorp2Hh[['year', 'level']].values.tolist())

    gp.Parameter(n, name='vNetTransfers2FinCorp', domain=[t], 
                 description='Net transfers received by financial corporations.',
                 records=vNetTransfers2FinCorp[['year', 'level']].values.tolist())
    gp.Parameter(n, name='vNetTransfers2NonFinCorp', domain=[t], 
                 description='Net transfers received by non-financial corporations.',
                 records=vNetTransfers2NonFinCorp[['year', 'level']].values.tolist())
    gp.Parameter(n, name='vGrossCapitalFormation', domain=[sector,t],
                 description='Gross capital formation.',
                 records=vGrossCapitalFormation[['sector', 'year', 'level']].values.tolist())
    gp.Parameter(n, name='vGrossOpSurplusMixedIncome', domain=[sector,t],
                 description='Operating surplus and mixed income by sector.',
                 records=vGrossOpSurplusMixedIncome[['sector', 'year', 'level']].values.tolist())
    gp.Parameter(n, name='vNonFinancialNonProducesAssets', domain=[sector,t],
                 description='Aquisition less disposals of non-financial non-produced assets (NP).',
                 records=vNonFinancialNonProducesAssets[['sector', 'year', 'level']].values.tolist())

    gp.Parameter(n, name='vRowPrimaryIncomeCurrentBalanceOther', domain=[t],
                 description='Primary income, current transfers and capital transers other than property income (D.1 net - D.9 net (excl. D.4 net)).',
                 records=vRowPrimaryIncomeCurrentBalanceOther[['year', 'level']].values.tolist())
    gp.Parameter(n, name='vExports', domain=[t],
                 description='Exports.',
                 records=vExports[['year', 'level']].values.tolist())
    gp.Parameter(n, name='vImports', domain=[t],
                 description='Imports.',
                 records=vImports[['year', 'level']].values.tolist())



    