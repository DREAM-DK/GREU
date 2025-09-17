def plot_supply_curve(gdxname,desired_sectors=None):
    if desired_sectors:
        desired_sectors=[str(x) for x in desired_sectors]
    # Define which years the supply curves should be plottet for
    year_list = [2035]

    # Import packages
    import dreamtools as dt
    import pandas as pd
    pd.options.plotting.backend = 'matplotlib'
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_pdf import PdfPages
    # Color settings (related to plt)
    prop_cycle = plt.rcParams["axes.prop_cycle"]
    colors = prop_cycle.by_key()["color"]

    ## Read data in gdx-file
    e = dt.Gdx(gdxname)

    # READING DATA
    # Prices (discrete)
    pTPotential = e["pTPotential"].to_frame()
    pTPotential = pTPotential.reset_index()
    pTPotential.set_index(['t', 'd','es','l'], inplace=True)

    # Potentials (discrete)
    sqTPotential = e["sqTPotential"].to_frame()
    sqTPotential = sqTPotential.reset_index()
    sqTPotential.set_index(['t', 'd','es','l'], inplace=True)

    # Prices and potentials in a joint dataframe (discrete)
    df_discrete_input = sqTPotential.reset_index().merge(pTPotential.reset_index(), how="left").set_index(sqTPotential.index.names)
    df_discrete_input = df_discrete_input[df_discrete_input.index.get_level_values("t")>2018]
    if desired_sectors:
        df_discrete_input=df_discrete_input[df_discrete_input.index.get_level_values('d').astype(str).isin(desired_sectors)]
    # Prices (smooth)
    pESmarg_scen = e["pESmarg_scen"].to_frame()
    pESmarg_scen = pESmarg_scen.reset_index()
    pESmarg_scen.set_index(['t', 'd','es','scen'], inplace=True)

    # Price where energy equals energy service demanded
    pESmarg_eq = e["pESmarg_eq"].to_frame()
    pESmarg_eq = pESmarg_eq.reset_index()
    pESmarg_eq.set_index(['t', 'd','es'], inplace=True)

    # Potentials (smooth)
    sqT_sum_scen = e["sqT_sum_scen"].to_frame()
    sqT_sum_scen = sqT_sum_scen.reset_index()
    sqT_sum_scen.set_index(['t', 'd','es','scen'], inplace=True)

    # Prices and potentials in a joint dataframe (Smooth)
    df_smooth_input = sqT_sum_scen.reset_index().merge(pESmarg_scen.reset_index(), how="left").set_index(sqT_sum_scen.index.names)
    df_smooth_input = df_smooth_input[df_smooth_input.index.get_level_values("t")>2018]



    def Discrete_supply(df_discrete_input,ss,p,yr=2019):
        # DESCRIPTION
    
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
        pESmarg_discrete = list(df_pESmarg_discrete['pESmarg_discrete'])[0]

        return df, df_MAC, pESmarg_discrete

    def Smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr=2019):
        # DESCRIPTION
    
        xs_list = (ss,p,yr)
        df = df_smooth_input.xs(xs_list,level = ['d','es','t'])
        df.reset_index(inplace=True)
        df = df.sort_values(by='pESmarg_scen', ascending=True)
        df.set_index('scen', inplace=True)

        pESmarg_smooth = pESmarg_eq.xs(xs_list,level = ['d','es','t'])
        pESmarg_smooth = list(pESmarg_smooth['pESmarg_eq'])[0]

        return df, pESmarg_smooth


    def plot_abatement(ss,p,yr=2019,pct=1):

        # Within each combination of sector, purpose and tax-step the tehnologies are sorted after the lowest new price (pTPotential)
        df=Discrete_supply(df_discrete_input,ss,p,yr)[0]
        df_MAC=Discrete_supply(df_discrete_input,ss,p,yr)[1]
        pESmarg_discrete=Discrete_supply(df_discrete_input,ss,p,yr)[2]

        # Plot discrete supply curve
        plt.plot(pct*df_MAC['theta_cumsum'],df_MAC['pTPotential'], label='Discreet',linewidth=1.5)
        # Plot discrete pESmarg
        # plt.axhline(pESmarg_discrete,color=colors[0], linestyle='--',linewidth=1.5)

        # Plot smooth curve
        df_smooth=Smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr)[0]
        plt.plot(pct*df_smooth['sqT_sum_scen'],df_smooth['pESmarg_scen'], label='Continous',linewidth=1.5)
        # Plot smooth pESmarg
        # pESmarg_smooth=Smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr)[1]
        # plt.axhline(pESmarg_smooth,color=colors[1], linestyle='--',linewidth=1.5)

        # Insert line where demand equals supply (where sTSupply_suml = 1)
        plt.axvline(pct, color= 'k', linestyle='--',linewidth=1.5)
        # Limit axis
        plt.xlim(right = (list(df_MAC['theta_cumsum'].tail(1))[0]+ 0.1)*pct )
        plt.ylim(bottom = (list(df['pTPotential'].head(1))[0] - 0.2))

        # Legend
        plt.legend(loc='best', fontsize=12)
        # Axis settings
        plt.xlabel(r'$\sum_{l}sqT_{l,es,d,t}$',fontsize='12')
        plt.ylabel(r'$pES^{marg}_{es,d,t}$',fontsize='12')
        plt.xticks(fontsize=12)
        plt.yticks(fontsize=12)

        # Define the size of the figure
        plt.tight_layout()

        plt.savefig('Supply_curve.svg')

        # Title settings
        plt.title("Energy supply, "+str(ss)+", "+str(p)+", "+str(yr),fontsize='12',weight='bold')


    # Calling function for plotting discrete and smooth supply curve
    with PdfPages('Supply_curves.pdf') as pdf:
        for yr in year_list:
            for ss in df_discrete_input.index.get_level_values('d').unique().tolist():
                for p in sorted(df_discrete_input[df_discrete_input.index.get_level_values('d')==ss].index.get_level_values('es').unique().tolist()):
                    plot_abatement(ss,p,yr=yr)
                    pdf.savefig(bbox_inches='tight')
                    plt.show()
