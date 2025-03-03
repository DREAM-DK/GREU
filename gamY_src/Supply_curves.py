# Import packages
import pandas as pd
pd.options.plotting.backend = 'matplotlib'
import matplotlib.pyplot as plt
# Color settings (related to plt)
prop_cycle = plt.rcParams["axes.prop_cycle"]
colors = prop_cycle.by_key()["color"]
# import PdfPages

## Read data in gdx-file
e = dt.Gdx("calib_dummy_techs.gdx")

# Prices (discrete)
pTPotential = e["pTPotential"].to_frame()
pTPotential = pTPotential.reset_index()
pTPotential = pTPotential.rename(columns={"es":"purpose","d":"s"})
pTPotential.set_index(['t', 's','purpose','l'], inplace=True)

# Potentials (discrete)
theta = e["sTPotential"].to_frame()
theta = theta.reset_index()
theta = theta.rename(columns={"es":"purpose","d":"s","sTPotential":"theta"})
theta.set_index(['t', 's','purpose','l'], inplace=True)

# Prices and potentials in a joint dataframe (discrete)
df_discrete_input = theta.reset_index().merge(pTPotential.reset_index(), how="left").set_index(theta.index.names)
df_discrete_input = df_discrete_input[df_discrete_input.index.get_level_values("t")>2018]

# Prices (smooth)
pESmarg_trace = e["pESmarg_trace"].to_frame()
pESmarg_trace = pESmarg_trace.reset_index()
pESmarg_trace = pESmarg_trace.rename(columns={"es":"purpose","d":"s"})
pESmarg_trace.set_index(['t', 's','purpose','trace'], inplace=True)

# Price where energy equals energy service demanded
pESmarg_eq = e["pESmarg_eq"].to_frame()
pESmarg_eq = pESmarg_eq.reset_index()
pESmarg_eq = pESmarg_eq.rename(columns={"es":"purpose","d":"s"})
pESmarg_eq.set_index(['t', 's','purpose','trace'], inplace=True)

# Potentials (smooth)
sTSupply_trace_suml = e["sTSupply_trace_suml"].to_frame()
sTSupply_trace_suml = sTSupply_trace_suml.reset_index()
sTSupply_trace_suml = sTSupply_trace_suml.rename(columns={"es":"purpose","d":"s"})
sTSupply_trace_suml.set_index(['t', 's','purpose','trace'], inplace=True)

# Prices and potentials in a joint dataframe (Smooth)
df_smooth_input = sTSupply_trace_suml.reset_index().merge(pESmarg_trace.reset_index(), how="left").set_index(sTSupply_trace_suml.index.names)
df_smooth_input = df_smooth_input[df_smooth_input.index.get_level_values("t")>2018]



def Discrete_supply(df_discrete_input,ss,p,yr=2019):
    # DESCRIPTION
 
    xs_list = (ss,p,yr)
    df = df_discrete_input.xs(xs_list,level = ['s','purpose','t'])
    df.reset_index(inplace=True)
    df = df.sort_values(by='pTPotential', ascending=True)
    df.set_index('l', inplace=True)

    # Calculate the cumulated potential within a combination of sector, purpose and tax-step
    df['theta_cumsum'] = df['theta'].cumsum()
    # Calculating how much potential that is left after the utilization of each technology 
    df['theta_remaining'] = 1-df['theta_cumsum'].shift(periods=1) # (to cover the energy service demanded for each combination of sector and purpose the cumulated potential has to be 1)
    df.loc[df.index == df.index[0],'theta_remaining'] = 1

    # Calculating the utilization of the tecnologies potential
    df['theta_util'] = df[['theta','theta_remaining']].min(axis=1)
    df.loc[df['theta_util']<0, 'theta_util'] = 0
    
    df_MAC=df.copy()
    df_MAC_lower = df.copy()

    df_MAC_lower['theta_cumsum'] = df_MAC['theta_cumsum'] - df_MAC['theta']
    df_MAC = pd.concat([df_MAC,df_MAC_lower])
    df_MAC = df_MAC.sort_values(by=['pTPotential','theta_cumsum'])

    df_MAC_svP = df.loc[df['theta_util']==df['theta_remaining']][['pTPotential']].rename(columns={'pTPotential':'MAC_svP'})
    MAC_svP = list(df_MAC_svP['MAC_svP'])[0]

    return df, df_MAC, MAC_svP

def Smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr=2019):
    # DESCRIPTION
 
    xs_list = (ss,p,yr)
    df = df_smooth_input.xs(xs_list,level = ['s','purpose','t'])
    df.reset_index(inplace=True)
    df = df.sort_values(by='pESmarg_trace', ascending=True)
    df.set_index('trace', inplace=True)

    Smooth_svP = pESmarg_eq.xs(xs_list,level = ['s','purpose','t'])
    Smooth_svP = list(Smooth_svP['pESmarg_eq'])[0]

    return df, Smooth_svP


def Supply_sigma_val_test(df_discrete_input,ss,p,yr=2019,pct=100):
    
    # Within each combination of sector, purpose and tax-step the tehnologies are sorted after the lowest new price (pTPotential)
    df=Discrete_supply(df_discrete_input,ss,p,yr)[0]
    df_MAC=Discrete_supply(df_discrete_input,ss,p,yr)[1]
    MAC_svP=Discrete_supply(df_discrete_input,ss,p,yr)[2]

    # Plot discrete supply curve
    plt.plot(pct*df_MAC['theta_cumsum'],df_MAC['pTPotential'], label='Discreet',linewidth=1.5)
    # Plot discrete pESmarg
    plt.axhline(MAC_svP,color=colors[0], linestyle='--',linewidth=1.5)

    # Plot smooth curve
    df_smooth=Smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr)[0]
    plt.plot(pct*df_smooth['sTSupply_trace_suml'],df_smooth['pESmarg_trace'], label='Smooth',linewidth=1.5)
    # Plot smooth pESmarg
    smooth_svP=Smooth_supply(df_smooth_input,pESmarg_eq,ss,p,yr)[1]
    plt.axhline(smooth_svP,color=colors[1], linestyle='--',linewidth=1.5)

    # Insert line where demand equals supply (where sTSupply_suml = 1)
    plt.axvline(pct, color= 'k', linestyle='--',linewidth=1.5)
    plt.xlim(right = (list(df['theta_cumsum'].tail(1))[0]+ 0.1)*pct )

    # Legend
    plt.legend(loc='best', fontsize=12)
    # Axis settings
    plt.xlabel('Pct. share of energy demand met',fontsize='12')
    plt.ylabel('Usercost (Mia. DKK per PJ)',fontsize='12')
    plt.xticks(fontsize=12)
    plt.yticks(fontsize=12)
    # Title settings
    plt.title("Energy supply, "+str(ss)+", "+str(p)+", "+str(yr),fontsize='12',weight='bold')


# Calling function for plotting discrete and smooth supply curve
# with PdfPages('Figs\Supply_sigma_val_test.pdf') as pdf:
for yr in [2019]:
    for ss in df_discrete_input.index.get_level_values('s').unique().tolist():
        for p in sorted(df_discrete_input[df_discrete_input.index.get_level_values('s')==ss].index.get_level_values('purpose').unique().tolist()):
            Supply_sigma_val_test(df_discrete_input,ss,p,yr=yr)
                # pdf.savefig(bbox_inches='tight')
            plt.show()