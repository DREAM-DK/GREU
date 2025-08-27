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


vtCO2e_total=s.vtCO2e_total-s.vtCO2e_total
vtCO2e_total=vtCO2e_total+b.vtCO2e_total
vtCO2e_total = s.vtCO2e_total- b.vtCO2e_total
vtOtherDuties_b = b.vtY + b.vtM - b.vtE_vat_total - b.vtE_duty_total
vtOtherDuties_s = s.vtY + s.vtM - s.vtE_vat_total - s.vtE_duty_total - vtCO2e_total

Net_duties_table = pd.DataFrame({
    'Absolute change': {
        'Net duties': s.vtY[2030] + s.vtM[2030] - b.vtY[2030] - b.vtM[2030],
        'VAT on energy': s.vtE_vat_total[2030] - b.vtE_vat_total[2030],
        'Duty on energy': s.vtE_duty_total[2030] - b.vtE_duty_total[2030],
        'CO2e tax': vtCO2e_total[2030],
        'Other net duties': vtOtherDuties_s[2030] - vtOtherDuties_b[2030]
    },
    'Relative change (%)': {
        'Net duties': ((s.vtY[2030] + s.vtM[2030])/(b.vtY[2030] + b.vtM[2030]) - 1)*100,
        'VAT on energy': ((s.vtE_vat_total[2030])/(b.vtE_vat_total[2030]) - 1)*100,
        'Duty on energy': ((s.vtE_duty_total[2030])/(b.vtE_duty_total[2030]) - 1)*100,
        'Other net duties': (vtOtherDuties_s[2030]/vtOtherDuties_b[2030] - 1)*100
    }
})

print("\nNet duties in 2030:")
print(Net_duties_table)

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
    'vG (%)': {
        t: (s.vG[t]/b.vG[t] - 1)*100 for t in range(2020, 2030)
    },
    'qG (%)': {
        t: (s.qG[t]/b.qG[t] - 1)*100 for t in range(2020, 2030)
    },
    'pG (%)': {
        t: (s.pG[t]/b.pG[t] - 1)*100 for t in range(2020, 2030)
    },
    'vGDP (%)': {
        t: (s.vGDP[t]/b.vGDP[t] - 1)*100 for t in range(2020, 2030)
    },
    # 'G/GDP ratio (%-points)': {
    #     t: s.vG2vGDP[t] - b.vG2vGDP[t] for t in range(2020, 2030)
    # } 
})

# print("\nDevelopment in public consumption and GDP:")
# print(gov_gdp_table)



