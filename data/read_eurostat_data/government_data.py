## THIS SCRIPT IS  PRELIMINARY UNTIL THE GOVERNMENTMODULE IS MODELLED USING EUROSTAT DATA.

import gamspy as gp
import os

_SOURCE_YEAR = '2020'


def _remap_government_time_index(records, year_start):
    """data_DK.gdx government series are indexed at 2020; relabel to the model calibration year."""
    if records is None or len(records) == 0:
        return records
    df = records.copy()
    if 't' not in df.columns:
        return df
    df['t'] = df['t'].astype(str).replace({_SOURCE_YEAR: str(year_start)})
    return df


def load_data(n, t, country, currency, year_start, year_end, **kwargs):
    g = n['g']
    gdx_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data_DK.gdx')

    # Load GDX file
    gdx = gp.Container()
    gdx.read(gdx_path)

    # Variables with domain [t] from government_data_variables
    t_variables = {
        'vtIndirect': 'Revenue from indirect taxes.',
        'vtDirect': 'Total direct taxes',
        'vtCorp': 'Taxation of corporations',
        'vCont': 'Contributions to social security',
        'vGovRevQuasi': 'Revenue from quasi-corporations',
        'vGovRent': 'Revenue from rent',
        'vtGovDepr': 'Depreciation of public capital',
        'vGovReceiveCorp': 'Capital transfers from corporations',
        'vGovReceiveCorpNonCap': 'Other transfers from corporations',
        'vGovReceiveF': 'Transfers from foreign countries',
        'vtCap': 'Capital taxes',
        'vGov2Corp': 'Transfers to corporations',
        'vGovSub': 'Government subsidies to corporations',
        'vHhTransfers': 'Transfers to households and non-profits from government.',
        'vGov2Foreign': 'Transfers from government to foreign countries',
        'vGovNetAcquisitions': 'Net acquisitions of non-produced non-financial assets',
    }

    for var_name, description in t_variables.items():
        rec = _remap_government_time_index(gdx[var_name].records, year_start)
        gp.Parameter(n, name=var_name, domain=[t], description=description, records=rec)

    # # qD[g,t] - Government consumption demand
    # gp.Parameter(n, name='qD', domain=[g, t], description='Government consumption demand',
    #              records=gdx['qD'].records)
