# Create table with government finances in 2040
gov_table = pd.DataFrame({
    'Absolute change': {
        'Primary balance': s.vGovPrimaryBalance[2040] - b.vGovPrimaryBalance[2040],
        'Revenue': s.vGovRevenue[2040] - b.vGovRevenue[2040],
        'Expenditure': s.vGovExpenditure[2040] - b.vGovExpenditure[2040]
    },
    'Relative change (%)': {
        'Primary balance': None,  # No relative change for primary balance
        'Revenue': (s.vGovRevenue[2040]/b.vGovRevenue[2040] - 1)*100,
        'Expenditure': (s.vGovExpenditure[2040]/b.vGovExpenditure[2040] - 1)*100
    }
})
print("\nGovernment finances in 2040:")
print(gov_table)


# Create detailed table with government revenue components in 2040
gov_revenue_table = pd.DataFrame({
    'Absolute change': {
        'Total revenue': s.vGovRevenue[2040] - b.vGovRevenue[2040],
        'Net duties': (s.vtY[2040] + s.vtM[2040]) - (b.vtY[2040] + b.vtM[2040]),
        'Production taxes (net of ETS)': (s.vtY_Tax[2040] - s.vtCO2_ETS_tot[2040]) - (b.vtY_Tax[2040] - b.vtCO2_ETS_tot[2040]),
        'Household taxes': s.vHhTaxes[2040] - b.vHhTaxes[2040],
        'Corporate taxes': s.vCorpTaxes[2040] - b.vCorpTaxes[2040],
        'Net revenue from public production': s.vGovRevenue_fromPublicProduction[2040] - b.vGovRevenue_fromPublicProduction[2040]
    },
    'Relative change (%)': {
        'Total revenue': (s.vGovRevenue[2040]/b.vGovRevenue[2040] - 1)*100,
        'Net duties': ((s.vtY[2040] + s.vtM[2040])/(b.vtY[2040] + b.vtM[2040]) - 1)*100,
        'Production taxes (net of ETS)': ((s.vtY_Tax[2040] - s.vtCO2_ETS_tot[2040])/(b.vtY_Tax[2040] - b.vtCO2_ETS_tot[2040]) - 1)*100,
        'Household taxes': (s.vHhTaxes[2040]/b.vHhTaxes[2040] - 1)*100,
        'Corporate taxes': (s.vCorpTaxes[2040]/b.vCorpTaxes[2040] - 1)*100,
        'Net revenue from public production': (s.vGovRevenue_fromPublicProduction[2040]/b.vGovRevenue_fromPublicProduction[2040] - 1)*100
    }
})
print("\nDetailed government revenue in 2040:")
print(gov_revenue_table)

Serie1 = s.vtCO2e_total
Serie2 = b.vtCO2e_total

# #Korrigerer explicit index-type til integers (heltal) der er native til pandas
# Serie1=pd.Series(Serie1.values, index=Serie1.index.astype("int64"))

# #Sætter index på serie 2
# Serie2_ny = pd.Series(Serie2.values, index=Serie1.index.astype("int64"))

# #Trækker serie 2 fra serie 1 hvor serie 2 er defineret, serie 1 ellers
# result1 = Serie1.sub(Serie2, fill_value=0)

# Serie1 = pd.Series(Serie1.values, index=Serie1.index.astype("str"))
# Serie2 = pd.Series(Serie2.values, index=Serie2.index.astype("str"))

# #here goes nothing :)))
# resultat = Serie1.sub(Serie2, fill_value=0)


vtCO2e_total = s.vtCO2e_total
# vtCO2e_total = s.vtCO2e_total-b.vtCO2e_total
# display(vtCO2e_total)
vtOtherDuties_b = b.vtY + b.vtM - b.vtE_vat_total - b.vtE_duty_total
vtOtherDuties_s = s.vtY + s.vtM - s.vtE_vat_total - s.vtE_duty_total - vtCO2e_total

Net_duties_table = pd.DataFrame({
    'Absolute change': {
        'Net duties': s.vtY[2040] + s.vtM[2040] - b.vtY[2040] - b.vtM[2040],
        'VAT on energy': s.vtE_vat_total[2040] - b.vtE_vat_total[2040],
        'Duty on energy': s.vtE_duty_total[2040] - b.vtE_duty_total[2040],
        'CO2e tax': vtCO2e_total[2040],
        'Other net duties': vtOtherDuties_s[2040] - vtOtherDuties_b[2040]
    },
    'Relative change (%)': {
        'Net duties': ((s.vtY[2040] + s.vtM[2040])/(b.vtY[2040] + b.vtM[2040]) - 1)*100,
        'VAT on energy': ((s.vtE_vat_total[2040])/(b.vtE_vat_total[2040]) - 1)*100,
        'Duty on energy': ((s.vtE_duty_total[2040])/(b.vtE_duty_total[2040]) - 1)*100,
        'Other net duties': (vtOtherDuties_s[2040]/vtOtherDuties_b[2040] - 1)*100
    }
})

print("\nNet duties in 2040:")
print(Net_duties_table)

# Create detailed table with government expenditure components in 2040
gov_expenditure_table = pd.DataFrame({
    'Absolute change': {
        'Total expenditure': s.vGovExpenditure[2040] - b.vGovExpenditure[2040],
        'Government consumption': s.vG[2040] - b.vG[2040], 
        'Household transfers': s.vHhTransfers[2040] - b.vHhTransfers[2040],
        'Production subsidies': s.vtY_Sub[2040] - b.vtY_Sub[2040],
        'Lumpsum': s.vLumpsum[2040]
    },
    'Relative change (%)': {
        'Total expenditure': (s.vGovExpenditure[2040]/b.vGovExpenditure[2040] - 1)*100,
        'Government consumption': (s.vG[2040]/b.vG[2040] - 1)*100,
        'Household transfers': (s.vHhTransfers[2040]/b.vHhTransfers[2040] - 1)*100,
        'Production subsidies': (s.vtY_Sub[2040]/b.vtY_Sub[2040] - 1)*100
    }
})

print("\nDetailed government expenditure in 2040:")
print(gov_expenditure_table)


# Create table with development in public consumption and GDP over time
gov_gdp_table = pd.DataFrame({
    'vG (%)': {
        t: (s.vG[t]/b.vG[t] - 1)*100 for t in range(2020, 2040)
    },
    'qG (%)': {
        t: (s.qG[t]/b.qG[t] - 1)*100 for t in range(2020, 2040)
    },
    'pG (%)': {
        t: (s.pG[t]/b.pG[t] - 1)*100 for t in range(2020, 2040)
    },
    'vGDP (%)': {
        t: (s.vGDP[t]/b.vGDP[t] - 1)*100 for t in range(2020, 2040)
    },
    # 'G/GDP ratio (%-points)': {
    #     t: s.vG2vGDP[t] - b.vG2vGDP[t] for t in range(2020, 2040)
    # } 
})

# print("\nDevelopment in public consumption and GDP:")
# print(gov_gdp_table)



