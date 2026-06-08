
import gamspy as gp
import eurostat
import pandas as pd

def load_data(n, t, country, year_start, year_end, **kwargs):
    # ========================================================================
    #   Module-specific sets
    # ========================================================================
    sector = gp.Set(n, 'sector', description='Sectors', records=['FinCorp', 'NonFinCorp', 'Gov', 'Hh', 'RoW'])
    sector_map = {"S11": "NonFinCorp", "S12": "FinCorp", "S13": "Gov", "S14": "Hh", "S15": "Hh", "S2": "RoW"}
    
    # ========================================================================
    #   Helper functions
    # ========================================================================
    def net_direct_flow(df, na_item):
        """Compute net flow (RECV - PAID) for a given na_item."""
        return (
            df[df['na_item'] == na_item]
            .pivot_table(index=['sector', 'year'], columns='direct', values='level', aggfunc='sum')
            .fillna(0)
            .assign(level=lambda x: x.get('RECV', 0) - x.get('PAID', 0))
            .reset_index()[['sector', 'year', 'level']]
        )

    def get_flow(df, na_item, flow_type):
        if flow_type == 'NET':
            return net_direct_flow(df, na_item)
        return df[(df['na_item'] == na_item) & (df['direct'] == flow_type)][['sector', 'year', 'level']]

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
                    'D6', 'D63', 'D7', 'B2A3G', 'D1', 'D2', 'D3', 'D4', 'D41', 'D42', 'D43', 'D44', 'D45'],
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

    # Construct variables: (variable_name, na_item, flow_type) where flow_type is 'RECV', 'PAID' or 'NET'
    variable_specs = [
        ('vNetLending_s', 'B9', 'RECV'),
        ('vGrossSavings_s', 'B8G', 'RECV'),
        ('vNetCapTransfers_s', 'D9', 'NET'),
        ('vGrossCapFormation_s', 'P5G', 'PAID'),
        ('vNetAcquisitions_s', 'NP', 'PAID'),
        ('vGrossDispIncome_s', 'B6G', 'RECV'),
        ('vConsExp_s', 'P3', 'PAID'),
        ('vNetPensEntitlementAdj_s', 'D8', 'NET'),
        ('vGrossPrimIncome_s', 'B5G', 'RECV'),
        ('vNetCurrentIncomeWealthTax_s', 'D5', 'NET'),
        ('vNetSocialContributions_s', 'D6', 'NET'),
        ('vNetSocialTransfersKind_s', 'D63', 'NET'),
        ('vNetOtherCurrentTrans_s', 'D7', 'NET'),
        ('vGrossOpSurplusMixedIncome_s', 'B2A3G', 'RECV'),
        ('vWagesRec_s', 'D1', 'RECV'),
        ('vProductionImportTaxRec_s', 'D2', 'RECV'),
        ('vSubsidiesExp_s', 'D3', 'PAID'),
        ('vNetPropertyIncome_s', 'D4', 'NET'),
        ('vNetInterests_s', 'D41', 'NET'),
        ('vNetDividends_s', 'D42', 'NET'),
        ('vNetReinvestedEarningsFDI_s', 'D43', 'NET'),
        ('vNetOtherInvestmentIncome_s', 'D44', 'NET'),
        ('vNetRents_s', 'D45', 'NET'),

        ('vInterestsPaid_s', 'D41', 'PAID'),
        ('vInterestsReceived_s', 'D41', 'RECV'),
        ('vDividendsPaid_s', 'D42', 'PAID'),
        ('vDividendsReceived_s', 'D42', 'RECV'),
        ('vReinvestedEarningsFDIPaid_s', 'D43', 'PAID'),
        ('vReinvestedEarningsFDIReceived_s', 'D43', 'RECV'),
        ('vOtherInvestmentIncomePaid_s', 'D44', 'PAID'),
        ('vOtherInvestmentIncomeReceived_s', 'D44', 'RECV'),

    ]

    all_data = pd.concat(
        [get_flow(raw_data, na_item, flow_type).assign(variable=var_name)
         for var_name, na_item, flow_type in variable_specs],
        ignore_index=True
    )[['variable', 'sector', 'year', 'level']]

    # Calculate RoW as residual to ensure data sums to zero across all sectors
    variable__redisual_row_list = ['vNetLending_s', 'vNetCapTransfers_s', 'vNetAcquisitions_s', 'vNetCurrentIncomeWealthTax_s', 
                         'vNetSocialContributions_s', 'vNetOtherCurrentTrans_s', 'vNetPropertyIncome_s', 'vNetInterests_s', 
                         'vNetDividends_s', 'vNetReinvestedEarningsFDI_s', 'vNetOtherInvestmentIncome_s', 'vNetRents_s']
    all_data_residual = all_data[all_data['variable'].isin(variable__redisual_row_list)].copy()
    all_data_residual = all_data_residual[all_data_residual['sector'] != 'RoW'].copy()
    row_residuals = (all_data_residual.groupby(['variable', 'year'], as_index=False)['level'].sum()
                     .assign(level=lambda x: -x['level'], sector='RoW'))
    all_data_residual = pd.concat([all_data_residual, row_residuals], ignore_index=True)
    all_data = pd.concat([all_data[~all_data['variable'].isin(variable__redisual_row_list)], all_data_residual], ignore_index=True)
    
    # ========================================================================
    #   Store parameters in container
    # ========================================================================
    variables_list = [
        ('vNetLending_s', 'Net lending by sector'),
        ('vGrossSavings_s', 'Gross savings by sector'),
        ('vNetCapTransfers_s', 'Net capital transfers by sector'),
        ('vGrossCapFormation_s', 'Gross capital formation by sector'),
        ('vNetAcquisitions_s', 'Net acquisitions by sector'),
        ('vGrossPrimIncome_s', 'Gross primary income by sector'),
        ('vGrossDispIncome_s', 'Gross disposable income by sector'),
        ('vConsExp_s', 'Consumption expenditure by sector'),
        ('vNetPensEntitlementAdj_s', 'Net pensions entitlement adjustments by sector'),
        ('vNetCurrentIncomeWealthTax_s', 'Net current income and wealth tax by sector'),
        ('vNetSocialContributions_s', 'Net social contributions by sector'),
        ('vNetSocialTransfersKind_s', 'Net social transfers in kind by sector'),
        ('vNetOtherCurrentTrans_s', 'Net other current transactions by sector'),
        ('vGrossOpSurplusMixedIncome_s', 'Operating surplus mixed income by sector, gross'),
        ('vWagesRec_s', 'Wages received by sector'),
        ('vProductionImportTaxRec_s', 'Production import tax received by sector'),
        ('vSubsidiesExp_s', 'Subsidies expenditure by sector'),
        ('vNetPropertyIncome_s', 'Net property income by sector'),
        ('vNetInterests_s', 'Net interests by sector'),
        ('vNetDividends_s', 'Net dividends by sector'),
        ('vNetReinvestedEarningsFDI_s', 'Net reinvested earnings on FDI by sector'),
        ('vNetOtherInvestmentIncome_s', 'Net other investment income by sector'),
        ('vNetRents_s', 'Net rents by sector'),

        ('vInterestsPaid_s', 'Net interests paid by sector'),
        ('vInterestsReceived_s', 'Net interests received by sector'),
        ('vDividendsPaid_s', 'Net dividends paid by sector'),
        ('vDividendsReceived_s', 'Net dividends received by sector'),
        ('vReinvestedEarningsFDIPaid_s', 'Net reinvested earnings on FDI paid by sector'),
        ('vReinvestedEarningsFDIReceived_s', 'Net reinvested earnings on FDI received by sector'),
        ('vOtherInvestmentIncomePaid_s', 'Net other investment income paid by sector'),
        ('vOtherInvestmentIncomeReceived_s', 'Net other investment income received by sector'),
    ]

    for var_name, desc in variables_list:
        df = all_data[all_data["variable"] == var_name][["sector", "year", "level"]].copy()
        # if df.empty:
        #     raise KeyError(
        #         f"Missing records for {var_name}. "
        #         f"Known variables: {sorted(all_data['variable'].unique().tolist())}"
        #     )
        records_df = (
            df.rename(columns={'year': 't'})
            .assign(t=lambda x: x['t'].astype(str))[['sector', 't', 'level']]
        )
        gp.Parameter(
            n,
            name=var_name,
            domain=[sector, t],
            description=desc,
            records=records_df.values.tolist(),
        )

    