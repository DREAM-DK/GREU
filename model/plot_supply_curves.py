"""
Plotting module for energy technology supply curves.

This module visualizes how energy service demand is met by competing technologies,
comparing two representations of the supply side:

  1. Discrete supply curve (step-function):
     Technologies are ranked from cheapest to most expensive (by pTPotential).
     Each technology contributes a share of the total energy service demand (sqTPotential).
     The resulting step-function shows the marginal cost of supplying one additional
     unit of energy service as cumulative supply increases.

  2. Continuous (smooth) supply curve:
     A calibrated smooth approximation of the discrete curve, parameterized across
     scenarios (scen). This is the representation used in the GAMS optimization model.

For each combination of sector (d), energy service (es), and year (t), the module
produces a single chart overlaying both curves with a vertical line at the point
where cumulative supply equals demand (share = 1). All charts are collected into
a multi-page PDF (Supply_curves.pdf).

Entry point:
    plot_supply_curve(gdxname, desired_sectors=None, year_list=None)

Data source:
    A GAMS GDX file containing the parameters pTPotential, sqTPotential,
    pESmarg_scen, pESmarg_eq, and sqT_sum_scen.
"""

import numpy as np
import dreamtools as dt
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

pd.options.plotting.backend = 'matplotlib'

# Function for reading parameters from gdx-file and setting desired index columns
def _read_gdx_param(gdx, name, index_cols):
    return gdx[name].to_frame().reset_index().set_index(index_cols)


def _discrete_supply(df_discrete_input,ss,p,yr=2019):
    """Build the discrete step-function supply curve for a given sector, energy service, and year.

    Sorts technologies by price (cheapest first), computes cumulative potential shares,
    and identifies the marginal technology price where supply meets demand.

    Returns (df, df_MAC, pESmarg_discrete): the technology DataFrame, the step-function
    DataFrame suitable for plotting, and the discrete marginal price.
    """

    # Eliminating dimensions
    xs_list = (ss,p,yr)
    df = df_discrete_input.xs(xs_list,level = ['d','es','t'])
    # Sorting data from cheapest to most expensive
    df.reset_index(inplace=True)
    df = df.sort_values(by='pTPotential', ascending=True)
    df.set_index('l', inplace=True)

    # Calculate the cumulated potential within a combination of sector, purpose and tax-step
    df['theta_cumsum'] = df['sqTPotential'].cumsum()
    # Calculating how much potential that is left after the utilization of each technology 
    df['theta_remaining'] = 1-df['theta_cumsum'].shift(periods=1) # (to cover the energy service demanded for each combination of sector and purpose the cumulated potential has to be 1)
    df.loc[df.index == df.index[0],'theta_remaining'] = 1

    # Calculating the utilization of the tecnologies potential
    df['theta_util'] = df[['sqTPotential','theta_remaining']].min(axis=1)
    df.loc[df['theta_util']<0, 'theta_util'] = 0

    df_MAC=df.copy()
    df_MAC_lower = df.copy()

    df_MAC_lower['theta_cumsum'] = df_MAC['theta_cumsum'] - df_MAC['sqTPotential']
    df_MAC = pd.concat([df_MAC,df_MAC_lower])
    df_MAC = df_MAC.sort_values(by=['pTPotential','theta_cumsum'])

    df_pESmarg_discrete = df.loc[df['theta_util']==df['theta_remaining']][['pTPotential']].rename(columns={'pTPotential':'pESmarg_discrete'})
    pESmarg_discrete = df_pESmarg_discrete['pESmarg_discrete'].iloc[0]

    return df, df_MAC, pESmarg_discrete


def _smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr=2019):
    """Extract the continuous (smooth) supply curve for a given sector, energy service, and year.

    Returns (df, pESmarg_smooth): the scenario-indexed supply DataFrame sorted by price,
    and the equilibrium marginal price where supply equals demand.
    """

    xs_list = (ss,p,yr)
    df = df_smooth_input.xs(xs_list,level = ['d','es','t'])
    df.reset_index(inplace=True)
    df = df.sort_values(by='pESmarg_scen', ascending=True)
    df.set_index('scen', inplace=True)

    pESmarg_smooth = pESmarg_eq.xs(xs_list,level = ['d','es','t'])
    pESmarg_smooth = pESmarg_smooth['pESmarg_eq'].iloc[0]

    return df, pESmarg_smooth


def plot_supply_curve(gdxname,desired_sectors=None,year_list=None):
    """Read energy technology data from a GDX file and produce a multi-page PDF of supply curves.

    For each combination of sector, energy service, and year, plots the discrete
    step-function and continuous supply curves side by side. Output is saved as
    'Supply_curves.pdf' (all pages) and 'Supply_curve.svg' (last page only).
    """
    if desired_sectors:
        desired_sectors=[str(x) for x in desired_sectors]
    if year_list is None:
        year_list = [2035]

    # Color settings (related to plt)
    prop_cycle = plt.rcParams["axes.prop_cycle"]
    colors = prop_cycle.by_key()["color"]

    ## Read data in gdx-file
    e = dt.Gdx(gdxname)

    # READING DATA
    # Discrete supply curve data
    pTPotential = _read_gdx_param(e, "pTPotential", ['t', 'd', 'es', 'l'])
    sqTPotential = _read_gdx_param(e, "sqTPotential", ['t', 'd', 'es', 'l'])
    # Smooth supply curve data
    pESmarg_scen = _read_gdx_param(e, "pESmarg_scen", ['t', 'd', 'es', 'scen'])
    pESmarg_eq = _read_gdx_param(e, "pESmarg_eq", ['t', 'd', 'es'])
    sqT_sum_scen = _read_gdx_param(e, "sqT_sum_scen", ['t', 'd', 'es', 'scen'])

    # Prices and potentials in a joint dataframe (discrete)
    df_discrete_input = sqTPotential.reset_index().merge(pTPotential.reset_index(), how="left").set_index(sqTPotential.index.names)
    df_discrete_input = df_discrete_input[df_discrete_input.index.get_level_values("t")>2018]
    if desired_sectors:
        df_discrete_input=df_discrete_input[df_discrete_input.index.get_level_values('d').astype(str).isin(desired_sectors)]

    # Prices and potentials in a joint dataframe (Smooth)
    df_smooth_input = sqT_sum_scen.reset_index().merge(pESmarg_scen.reset_index(), how="left").set_index(sqT_sum_scen.index.names)
    df_smooth_input = df_smooth_input[df_smooth_input.index.get_level_values("t")>2018]
    if desired_sectors:
        df_smooth_input=df_smooth_input[df_smooth_input.index.get_level_values('d').astype(str).isin(desired_sectors)]


    def plot_energy_technology(ss,p,yr=2019,pct=1):
        """Plot discrete and smooth supply curves for a single sector/service/year combination."""

        fig, ax = plt.subplots()

        # Within each combination of sector, purpose and tax-step the technologies are sorted after the lowest new price (pTPotential)
        df, df_MAC, pESmarg_discrete = _discrete_supply(df_discrete_input, ss, p, yr)

        # Plot discrete supply curve (horizontal segments dotted, vertical segments solid)
        x = (pct * df_MAC['theta_cumsum']).values
        y = df_MAC['pTPotential'].values
        x_horiz, y_horiz = [], []
        x_vert, y_vert = [], []
        for i in range(len(x) - 1):
            if y[i] == y[i + 1]:
                x_horiz.extend([x[i], x[i + 1], np.nan])
                y_horiz.extend([y[i], y[i + 1], np.nan])
            else:
                x_vert.extend([x[i], x[i + 1], np.nan])
                y_vert.extend([y[i], y[i + 1], np.nan])
        ax.plot(x_horiz, y_horiz, color='C0', linestyle=':', linewidth=1.5)
        ax.plot(x_vert, y_vert, color='C0', linestyle='-', linewidth=1.5)
        ax.plot([], [], color='C0', linestyle='-', linewidth=1.5, label='Discrete')
        # Plot discrete pESmarg
        # ax.axhline(pESmarg_discrete,color=colors[0], linestyle='--',linewidth=1)

        # Plot smooth curve
        df_smooth=_smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr)[0]
        ax.plot(pct*df_smooth['sqT_sum_scen'],df_smooth['pESmarg_scen'], color=colors[1], label='Continuous',linewidth=1.5)
        # Plot smooth pESmarg
        # pESmarg_smooth=_smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr)[1]
        # ax.axhline(pESmarg_smooth,color=colors[1], linestyle='--',linewidth=1)

        # Insert line where demand equals supply (where sTSupply_suml = 1)
        ax.axvline(pct, color= 'k', linestyle='--',linewidth=1.5)
        # Limit axis
        ax.set_xlim(right = (df_MAC['theta_cumsum'].iloc[-1] + 0.1) * pct)
        ax.set_ylim(bottom = (df['pTPotential'].iloc[0] - 0.05))

        # Legend
        ax.legend(loc='best', fontsize=12)
        # Axis settings
        ax.set_xlabel(r'$\sum_{l}sqT_{l,es,d,t}$',fontsize='12')
        ax.set_ylabel(r'$pES^{marg}_{es,d,t}$',fontsize='12')
        ax.tick_params(labelsize=12)

        # Title settings
        ax.set_title(f"Energy supply, {ss}, {p}, {yr}",fontsize='12',weight='bold')

        fig.tight_layout()
        fig.savefig('Supply_curve.svg')

        return fig


    # Calling function for plotting discrete and smooth supply curve
    with PdfPages('Supply_curves.pdf') as pdf:
        for yr in year_list:
            for ss in df_discrete_input.index.get_level_values('d').unique().tolist():
                for p in sorted(df_discrete_input[df_discrete_input.index.get_level_values('d')==ss].index.get_level_values('es').unique().tolist()):
                    fig = plot_energy_technology(ss,p,yr=yr)
                    pdf.savefig(fig, bbox_inches='tight')
                    plt.show()
                    plt.close(fig)
