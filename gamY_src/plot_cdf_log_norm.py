# def plot_supply_curve(gdxname):

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
e = dt.Gdx("cdf_log_norm.gdx")

# READING DATA
# Prices (discrete)
tech_cost = e["tech_cost"].to_frame()
tech_cost = tech_cost.reset_index()
tech_cost.set_index(['l'], inplace=True)

# Potentials (discrete)
tech_pot = e["tech_pot"].to_frame()
tech_pot = tech_pot.reset_index()
tech_pot.set_index(['l'], inplace=True)

# Prices and potentials in a joint dataframe (discrete)
df_discrete_input = tech_pot.reset_index().merge(tech_cost.reset_index(), how="left").set_index(tech_pot.index.names)

# Prices (smooth)
cdf_scen_input = e["cdf_scen_input"].to_frame()
cdf_scen_input = cdf_scen_input.reset_index()
cdf_scen_input.set_index(['l','scen_cdf'], inplace=True)

# Potentials (smooth)
cdf_scen_sigma_low = e["cdf_scen_sigma_low"].to_frame()
cdf_scen_sigma_low = cdf_scen_sigma_low.reset_index()
cdf_scen_sigma_low.set_index(['l','scen_cdf'], inplace=True)

cdf_scen_sigma_med = e["cdf_scen_sigma_med"].to_frame()
cdf_scen_sigma_med = cdf_scen_sigma_med.reset_index()
cdf_scen_sigma_med.set_index(['l','scen_cdf'], inplace=True)

cdf_scen_sigma_high = e["cdf_scen_sigma_high"].to_frame()
cdf_scen_sigma_high = cdf_scen_sigma_high.reset_index()
cdf_scen_sigma_high.set_index(['l','scen_cdf'], inplace=True)


# Prices and potentials in a joint dataframe (Smooth)
df_smooth_input = cdf_scen_input.reset_index().merge(cdf_scen_sigma_low.reset_index(), how="left").set_index(cdf_scen_input.index.names)
df_smooth_input = df_smooth_input.reset_index().merge(cdf_scen_sigma_med.reset_index(), how="left").set_index(df_smooth_input.index.names)
df_smooth_input = df_smooth_input.reset_index().merge(cdf_scen_sigma_high.reset_index(), how="left").set_index(df_smooth_input.index.names)


def Discrete_supply(df_discrete_input):
    # DESCRIPTION
    
    # Eliminating dimensions
    df_MAC = df_discrete_input
    # Sorting data from cheapest to most expensive
    df_MAC.reset_index(inplace=True)
    df_MAC = df_MAC.sort_values(by='tech_cost', ascending=True)
    df_MAC.set_index('l', inplace=True)

    df_MAC['tech_cost'] = [0]
    df_MAC['tech_pot'] = [0]

    df_MAC1 = df_MAC.copy()
    df_MAC1['tech_cost'] = [1]
    df_MAC1['tech_pot'] = [0]

    df_MAC2 = df_MAC.copy()
    df_MAC2['tech_cost'] = [1]
    df_MAC2['tech_pot'] = [1]

    df_MAC3 = df_MAC.copy()
    df_MAC3['tech_cost'] = [2]
    df_MAC3['tech_pot'] = [1]

    df_MAC = pd.concat([df_MAC,df_MAC1,df_MAC2,df_MAC3])
    df_MAC = df_MAC.sort_values(by='tech_cost', ascending=True)

    return df_MAC

def Smooth_supply(df_smooth_input):
    # DESCRIPTION
    
    df = df_smooth_input
    df.reset_index(inplace=True)
    df = df.sort_values(by='cdf_scen_input', ascending=True)
    df.set_index(['l','scen_cdf'], inplace=True)

    return df


def plot_smoothing_tech():

    # Within each combination of sector, purpose and tax-step the tehnologies are sorted after the lowest new price (pTPotential)
    df_MAC=Discrete_supply(df_discrete_input)

    # Plot discrete supply curve
    plt.plot(df_MAC['tech_cost'], df_MAC['tech_pot'], label='Discreet',linewidth=1.5)

    # Plot smooth curve
    df_smooth=Smooth_supply(df_smooth_input)
    plt.plot(df_smooth['cdf_scen_input'], df_smooth['cdf_scen_sigma_low'], label=r'$\sigma=0.05$',linewidth=1.5)
    plt.plot(df_smooth['cdf_scen_input'], df_smooth['cdf_scen_sigma_med'], label=r'$\sigma=0.15$',linewidth=1.5)
    plt.plot(df_smooth['cdf_scen_input'], df_smooth['cdf_scen_sigma_high'], label=r'$\sigma=0.30$',linewidth=1.5)

    # Legend
    plt.legend(loc='best', fontsize=12)
    # Axis settings
    plt.xlabel(r'$pES^{marg}_{es,d,t}$',fontsize='12')
    plt.ylabel(r'$cdf(pES^{marg}_{es,d,t})$',fontsize='12')
    plt.xticks(fontsize=12)
    plt.yticks(fontsize=12)
    # Title settings
    # plt.title("CDF",fontsize='12',weight='bold')

    # Define the size of the figure
    plt.tight_layout()

    # Save figure
    plt.savefig('Smoothing_tech.svg')

    # Show and close the plot
    plt.show()
    plt.close()


def plot_partial_expected_value():

    # Plot smooth curve
    df_smooth=Smooth_supply(df_smooth_input)
    plt.plot(df_smooth['cdf_scen_input'], df_smooth['cdf_scen_sigma_high'],linewidth=1.5, color='r')
    
    # Define technology adoption
    x_cutoff = 1.25
    df_smooth['cdf_input_fill'] = df_smooth.loc[df_smooth['cdf_scen_input']<=x_cutoff,'cdf_scen_input']
    df_smooth['cdf_fill'] = df_smooth.loc[df_smooth['cdf_scen_input']<=x_cutoff,'cdf_scen_sigma_high']
    y_cutoff = df_smooth['cdf_fill'].max()

    # Fill area under the curve
    # plt.fill_between(df_smooth['cdf_input_fill'], df_smooth['cdf_fill'], 0,color='none',hatch='//',edgecolor='m')
    plt.fill_between(df_smooth['cdf_input_fill'], df_smooth['cdf_fill'], 0,color=(0.1,0.2,0.2),alpha=0.3)

    # Horizontal line
    plt.axhline(y_cutoff, color='k', linestyle='--',linewidth=1.5)

    # Exact horizontal and vertical lines
    # plt.plot([x_cutoff, x_cutoff], [0, y_cutoff], color='k', linestyle='--')
    # plt.plot([0, x_cutoff], [y_cutoff, y_cutoff], color='k', linestyle='--')

    # Axis settings
    plt.xlabel(r'$pES^{marg}_{es,d,t}$',fontsize='12')
    plt.ylabel(r'$cdf(pES^{marg}_{es,d,t})$',fontsize='12')
    plt.xticks(fontsize=12)
    plt.yticks(fontsize=12)
    # Title settings
    # plt.title("CDF",fontsize='12',weight='bold')
    
    # Define the size of the figure
    plt.tight_layout()

    # Save figure
    plt.savefig('Partial_expected_value.svg')

    # Show and close the plot
    plt.show()
    plt.close()


# Calling function for plotting discrete and smooth supply curve
plot_smoothing_tech()
plot_partial_expected_value()
