# ---------------
# Technical setup
# ---------------

import sys
import shutil
import os
import dreamtools as dt
dt.gamY.automatic_dummy_suffix = "_exists_dummy"
dt.gamY.variable_equation_prefix = "E_"

## Set local paths
root = dt.find_root("LICENSE")
sys.path.insert(0, root)
os.environ["GAMS"] = "C:/GAMS/49/gams.exe"

## Set working directory
os.chdir(fr"{root}/model")

## Create data.gdx based on GreenREFORM-DK data 
# dt.gamY.run("../data/data_from_GR.gms")


# ---------------
# Running the base model ie. calibrating the baseline scenario
# ---------------

## Create the baseline calibration (calibration.gdx) based on GreenREFORM-DK data and exogenous assumptions
dt.gamY.run("base_model.gms")

# ---------------
# Running the shock opon the baseline model
# ---------------

dt.gamY.run("shock_model.gms")


dt.gamY.run("shock_CO2eTax.gms")


# ---------------
# Setup for plotting and tables
# ---------------

import pandas as pd
from define_output_functions import extract_table_by_name, multiple_conditions_extract_table_by_name, newname

def table(series: pd.Series, target_values: dict, cols: str) -> pd.DataFrame:
    """
    From a MultiIndexed Series, extract entries matching multiple index level values and pivot one level into columns.

    Parameters:
    - series: pd.Series with MultiIndex
    - target_values: dict of {level_name: list of allowed values}
    - unstack_level: name of index level to pivot into columns

    Returns:
    - pd.DataFrame with one row per remaining levels, one column per value of unstacked level
    """

    indexer = pd.Series([True] * len(series), index=series.index)

    for level, allowed in target_values.items():
        level_vals = series.index.get_level_values(level)
        indexer &= level_vals.isin(allowed)

    # Filter and pivot
    filtered = series[indexer]
    df = filtered.unstack(cols)

    # Ensure all expected columns are present (fill with NaN if missing)
    expected_columns = target_values.get(cols, df.columns.tolist())
    return df.reindex(columns=expected_columns)



# Plotting
dt.YAXIS_TITLE_FROM_OPERATOR = {
  "pq": "Pct. changes relative to baseline",
	"m": "Difference from baseline",
}
dt.TIME_AXIS_TITLE = ""


# ---------------
# Specify the baseline and shock scenarios
# ---------------

dt.REFERENCE_DATABASE = b = dt.Gdx("Output/baseline.gdx") # b for baseline
s = dt.Gdx("Output/shock.gdx") # s for shock
dt.time(2019, 2030)



# løbende arbejde
display(b.vtE_duty)

tableCO2=table(b.vtE_duty,target_values={'t':[2030], 'etaxes':['co2_tax']},cols='d')-table(b.vtE_duty,target_values={'t':[2020], 'etaxes':['co2_tax']},cols='d')
tableCO2=table(b.vtE_duty,target_values={'t':[2030], 'etaxes':['co2_tax']},cols='d')

display(tableCO2)


# ---------------
# Reporting of emissions
# ---------------

# Total reduction in emissions
dt.plot([s.qEmmTot.loc[['co2e'],['UNFCCC_lulucf']]], "m", layout={"title": "CO2e emissions, total"})
tabel1=table(s.qEmmTot-b.qEmmTot,target_values={'em':['co2e'],'em_accounts':['UNFCCC_lulucf'],'t':[2030]},cols='t')
tabel2=table(s.qCO2e_iagg-b.qCO2e_iagg,target_values={'emission_categories':['Total'],'t':[2030]},cols='t')
tabel3=table(s.qEmmE-b.qEmmE, target_values={'em':['co2e'],'d':['cCarEne','cHouEne'],'t':[2030]}, cols='t')

display(tabel1)
display(tabel2)
display(tabel3)

# Remove columns from tables
tabel1 = tabel1.droplevel('em')
tabel2 = tabel2.droplevel('emission_categories')
tabel3 = tabel3.droplevel('em')

# Combine tables
combined_table = pd.concat([tabel1, tabel2, tabel3])
display(combined_table)

# Test if the underlying sum of the table is correct
test_sum = combined_table[2030].drop('UNFCCC_lulucf').sum()
test = combined_table.loc['UNFCCC_lulucf', 2030]- test_sum
print(f"Is sum 0? {abs(test) < 1e-10}")  # Use small tolerance due to rounding errors


# Reduction on industry level
dt.plot([s.qCO2e_iagg.loc[:,['Total']]], "m", layout={"title": "CO2e emissions, industri aggregated"})
dt.plot([s.qCO2e_iagg.loc[['service'],:]], "m", layout={"title": "CO2e emissions, Services"})

# Table for all industries
tabel_qCO2e=table(series=s.qCO2e_iagg-b.qCO2e_iagg,target_values={'t':[2020,2025,2030]},cols='t')
print(tabel_qCO2e)

# Only service
tabel_services=table(series=s.qCO2e_iagg-b.qCO2e_iagg,target_values={'iagg':['service'],'t':[2020,2025,2030]},cols='t')
print(tabel_services)

# 2030
tabel_2030=table(s.qCO2e_iagg-b.qCO2e_iagg,target_values={'t':[2030]},cols='t')
print(tabel_2030)

# Service industries in 2030
tabel_serviceindustries=multiple_conditions_extract_table_by_name(s.qCO2e_i-b.qCO2e_i,target_values={'iagg':['service'],'t':[2030]},cols='emission_categories')
print(tabel_serviceindustries)

# Level, relative and absolute
tabel_level=multiple_conditions_extract_table_by_name(b.qCO2e_i,target_values={'iagg':['service'],'emission_categories':['Total'],'t':[2030]},cols='t').droplevel(['iagg','emission_categories'])
tabel_rela =multiple_conditions_extract_table_by_name((s.qCO2e_i/b.qCO2e_i-1)*100,target_values={'iagg':['service'],'emission_categories':['Total'],'t':[2030]},cols='t').droplevel(['iagg','emission_categories'])
tabel_abso =multiple_conditions_extract_table_by_name(s.qCO2e_i-b.qCO2e_i,target_values={'iagg':['service'],'emission_categories':['Total'],'t':[2030]},cols='t').droplevel(['iagg','emission_categories'])

all_tabel = pd.DataFrame({
    'Baseline level': tabel_level[2030],
    'Relative changes (%)': tabel_rela[2030],
    'Absolute changes': tabel_abso[2030]
})
print("\nCO2e emissions for service industries in 2030:")
print(all_tabel)



#--------------------------------
# Reporting of public finances
#--------------------------------

dt.plot([s.vGovPrimaryBalance, b.vGovPrimaryBalance], names=["Shock", "Baseline"], layout={"title": "Primary balance"})
dt.plot(s.vGovPrimaryBalance,"m", layout={"title": "Primary balance"})

print(s.vGovPrimaryBalance[2030],s.vGovPrimaryBalance[2025])


# Create table with government finances in 2030
gov_table = pd.DataFrame({
    'Absolute change': {
        'Primary balance': s.vGovPrimaryBalance[2030] - b.vGovPrimaryBalance[2030],
        'Revenue': s.vGovRevenue[2030] - b.vGovRevenue[2030],
        'Expenditure': s.vGovExpenditure[2030] - b.vGovExpenditure[2030]
    },
    'Relative change (%)': {
        'Primary balance': None,  # No relative change for primary balance
        'Revenue': (s.vGovRevenue[2030]/b.vGovRevenue[2030] - 1)*100,
        'Expenditure': (s.vGovExpenditure[2030]/b.vGovExpenditure[2030] - 1)*100
    }
})
print("\nGovernment finances in 2030:")
print(gov_table)


# Create detailed table with government revenue components in 2030
gov_revenue_table = pd.DataFrame({
    'Absolute change': {
        'Total revenue': s.vGovRevenue[2030] - b.vGovRevenue[2030],
        'Net duties': (s.vtY[2030] + s.vtM[2030]) - (b.vtY[2030] + b.vtM[2030]),
        'Production taxes (net of ETS)': (s.vtY_Tax[2030] - s.vtCO2_ETS_tot[2030]) - (b.vtY_Tax[2030] - b.vtCO2_ETS_tot[2030]),
        'Household taxes': s.vHhTaxes[2030] - b.vHhTaxes[2030],
        'Corporate taxes': s.vCorpTaxes[2030] - b.vCorpTaxes[2030],
        'Net revenue from public production': s.vGovRevenue_fromPublicProduction[2030] - b.vGovRevenue_fromPublicProduction[2030]
    },
    'Relative change (%)': {
        'Total revenue': (s.vGovRevenue[2030]/b.vGovRevenue[2030] - 1)*100,
        'Net duties': ((s.vtY[2030] + s.vtM[2030])/(b.vtY[2030] + b.vtM[2030]) - 1)*100,
        'Production taxes (net of ETS)': ((s.vtY_Tax[2030] - s.vtCO2_ETS_tot[2030])/(b.vtY_Tax[2030] - b.vtCO2_ETS_tot[2030]) - 1)*100,
        'Household taxes': (s.vHhTaxes[2030]/b.vHhTaxes[2030] - 1)*100,
        'Corporate taxes': (s.vCorpTaxes[2030]/b.vCorpTaxes[2030] - 1)*100,
        'Net revenue from public production': (s.vGovRevenue_fromPublicProduction[2030]/b.vGovRevenue_fromPublicProduction[2030] - 1)*100
    }
})
print("\nDetailed government revenue in 2030:")
print(gov_revenue_table)


# Create detailed table with government expenditure components in 2030
gov_expenditure_table = pd.DataFrame({
    'Absolute change': {
        'Total expenditure': s.vGovExpenditure[2030] - b.vGovExpenditure[2030],
        'Government consumption': s.vG[2030] - b.vG[2030], 
        'Household transfers': s.vHhTransfers[2030] - b.vHhTransfers[2030],
        'Production subsidies': s.vtY_Sub[2030] - b.vtY_Sub[2030]
    },
    'Relative change (%)': {
        'Total expenditure': (s.vGovExpenditure[2030]/b.vGovExpenditure[2030] - 1)*100,
        'Government consumption': (s.vG[2030]/b.vG[2030] - 1)*100,
        'Household transfers': (s.vHhTransfers[2030]/b.vHhTransfers[2030] - 1)*100,
        'Production subsidies': (s.vtY_Sub[2030]/b.vtY_Sub[2030] - 1)*100
    }
})

print("\nDetailed government expenditure in 2030:")
print(gov_expenditure_table)


# Create table with development in public consumption and GDP over time
gov_gdp_table = pd.DataFrame({
    'Public consumption (%)': {
        t: (s.vG[t]/b.vG[t] - 1)*100 for t in range(2019, 2031)
    },
    'GDP (%)': {
        t: (s.vGDP[t]/b.vGDP[t] - 1)*100 for t in range(2019, 2031)
    },
    'G/GDP ratio (%-points)': {
        t: s.vG2vGDP[t] - b.vG2vGDP[t] for t in range(2019, 2031)
    }
})

print("\nDevelopment in public consumption and GDP:")
print(gov_gdp_table)




























# Gem all_tabel til Excel
all_tabel.to_excel('service_CO2e_2030.xlsx')
print("\nTabellen er gemt som 'service_CO2e_2030.xlsx'")





































tabel1=extract_table_by_name(series=s.qCO2e_iagg-b.qCO2e_iagg,target_names=[2020,2025,2030],level='t')
tabel2=extract_table_by_name(series=(s.qCO2e_iagg-b.qCO2e_iagg)/b.qCO2e_iagg*100,target_names=[2020,2025,2030],level='t')
print("Absolutte ændringer i CO2e udledninger:")
print(tabel1)
print("\nRelative ændringer i CO2e udledninger (%):")
print(tabel2)


# Niveauer i baseline for service_other CO2e udledninger i 2030
tabel_niveau = extract_table_by_name(series=b.qCO2e_service_other, target_names=[2030], level='t')
print(tabel_niveau)

# Absolutte ændringer i service_other CO2e udledninger i 2030
tabel_abs = extract_table_by_name(series=s.qCO2e_service_other-b.qCO2e_service_other, target_names=[2030], level='t')

# Relative ændringer i service_other CO2e udledninger i 2030
tabel_rel = extract_table_by_name(series=(s.qCO2e_service_other-b.qCO2e_service_other)/b.qCO2e_service_other*100, target_names=[2030], level='t')

# Saml alle tre tabeller
samlet_tabel = pd.DataFrame({
    'Baseline niveau': tabel_niveau[2030],
    'Absolut ændring': tabel_abs[2030],
    'Relativ ændring (%)': tabel_rel[2030]
})

print("\nCO2e udledninger for service_other i 2030:")
print(samlet_tabel)









tabel2=extract_table_by_name(series=s.qCO2e_iagg-b.qCO2e_iagg,target_names=[2020,2025,2030],level='t')
print("\nRelative ændringer i CO2e udledninger:")
print(tabel2)


tabel2=extract_table_by_name(series=s.qCO2e_service_other-b.qCO2e_service_other,target_names=[2020,2025,2030],level='t')
print(tabel2)








dt.plot([b.vNetFinAssets/b.vGDP], layout={"title": "Net Financial Assets to GDP"})
dt.plot([s.qGDP, s.qC, s.qI, s.qG, s.qX, s.qM], "m", function=lambda x: x/b.vGDP, names=["GDP", "C", "I", "G", "X", "M"], layout={"yaxis_title": "Change relative to baseline GDP"})
dt.plot(s, "m", lambda db: db.vNetFinAssets/db.vGDP, layout={"title": "Net Financial Assets to GDP"})
dt.plot([b.vNetFinAssets/b.vGDP], layout={"title": "Net Financial Assets to GDP"})





tabel1=extract_table_by_name(series=s.qCO2e_service_other,target_names=[45000,46000],level='i')
print(tabel1)
tabel2=extract_table_by_name(series=s.qCO2e_service_other-b.qCO2e_service_other,target_names=[2020,2025,2030],level='t')
print(tabel2)


tabel4=multiple_conditions_extract_table_by_name(s.qCO2e_service_other,target_values={'i':[45000,46000],'t':[2022,2024]},cols='i')
print(tabel4)


dt.plot([s.qY], "m", layout={"title": "CO2e emissions"})

dt.plot([s.qI_k_i.loc[['iM'],[23001]]], "m", layout={"title": "Investeringer, cement"})

# Plot investeringer
dt.plot([s.qI], "m", layout={"title": "Investeringer"})

dt.plot([s.qI_k_i.loc[['iM'],[49509]]], "m", layout={"title": "Investeringer, transport"})





# Plot udvikling for industri 49509 (transport)
dt.plot([s.qY_i.loc[[49509]]], "m", layout={"title": "Produktion i transportindustri 49509"})
dt.plot([s.qY_i[[49509]],s.pY_i[[49509]],s.qEmmE.loc[['co2e'],[49509]]], "pq")



## Running the partial abatement model
# dt.gamY.run("abatement_model_partial.gms")

