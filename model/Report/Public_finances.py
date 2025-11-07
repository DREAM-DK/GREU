prim_baseline = b.vGovPrimaryBalance/b.vGDP *100
prim_shock = (s.vGovPrimaryBalance+(s.vLumpsum-b.vLumpsum))/s.vGDP *100
prim_shock[2020] = s.vGovPrimaryBalance[2020]/s.vGDP[2020]  # Set 2020 value to baseline as lumpsum has no value

vPrimBudg_xLump = (s.vGovPrimaryBalance+s.vLumpsum)/s.vGDP*100-(b.vGovPrimaryBalance+b.vLumpsum)/b.vGDP*100
vPrimBudg_xLump[2020] = s.vGovPrimaryBalance[2020]/s.vGDP[2020]*100-b.vGovPrimaryBalance[2020]/b.vGDP[2020]*100; 
CO2etax = (s.vtCO2_Corp+s.vtCO2_Hh+s.vtCO2_xE_tot)/s.vGDP*100-(b.vtCO2_Corp+b.vtCO2_Hh+b.vtCO2_xE_tot)/b.vGDP*100

# dt.plot([prim_baseline, prim_shock], names=["Baseline", "Shock"], layout={"title": "Primary balance"})
# dt.plot([b.vLumpsum, s.vLumpsum], names=["Baseline", "Shock"], layout={"title": "Lumpsum payments"})
# dt.plot([vPrimBudg_xLump, CO2etax], names=["Government budget eksl. lumpsum", "Revenue from CO2e tax"], layout={"title": "Changes in public finances"})



# Create table with government finances in 2040
gov_table = pd.DataFrame({
    'Absolute change': {
        'Primary balance': s.vGovPrimaryBalance[2040] - b.vGovPrimaryBalance[2040],
        # 'Revenue': s.vGovRevenue[2040] - b.vGovRevenue[2040],
        # 'Expenditure': s.vGovExpenditure[2040] - b.vGovExpenditure[2040],
        'Direct taxes': s.vtDirect[2040] - b.vtDirect[2040],
        'Indirect taxes': s.vtIndirect[2040] - b.vtIndirect[2040],
        'Other revenues': s.vGovRevOther[2040] - b.vGovRevOther[2040],
        'Government consumption': s.vG[2040] - b.vG[2040],
        'Household transfers': s.vHhTransfers[2040] - b.vHhTransfers[2040],
        'Government investments': s.vI_public[2040] - b.vI_public[2040],
        'Other expenditures': s.vGovExpOther[2040] - b.vGovExpOther[2040],
        'Lumpsum': s.vLumpsum[2040] - b.vLumpsum[2040]
    },
    'Relative change (%)': {
        'Primary balance': None,  # No relative change for primary balance
        # 'Revenue': (s.vGovRevenue[2040]/b.vGovRevenue[2040] - 1)*100,
        # 'Expenditure': (s.vGovExpenditure[2040]/b.vGovExpenditure[2040] - 1)*100
        'Direct taxes': (s.vtDirect[2040]/b.vtDirect[2040] - 1)*100,
        'Indirect taxes': (s.vtIndirect[2040]/b.vtIndirect[2040] - 1)*100,
        'Other revenues': (s.vGovRevOther[2040]/b.vGovRevOther[2040] - 1)*100,
        'Government consumption': (s.vG[2040]/b.vG[2040] - 1)*100,
        'Household transfers': (s.vHhTransfers[2040]/b.vHhTransfers[2040] - 1)*100,
        'Government investments': (s.vI_public[2040]/b.vI_public[2040] - 1)*100,
        'Other expenditures': (s.vGovExpOther[2040]/b.vGovExpOther[2040] - 1)*100,
    }
})
# print("\nGovernment finances in 2040:")
# print(gov_table)


indirect_table = pd.DataFrame({
    'Absolute change': {
        'Indirect taxes': s.vtIndirect[2040] - b.vtIndirect[2040],
        'CO2 tax, corporations': s.vtCO2_Corp[2040] - b.vtCO2_Corp[2040],
        'CO2 tax, households': s.vtCO2_Hh[2040] - b.vtCO2_Hh[2040],
        'CO2 tax, non-energy': s.vtCO2_xE_tot[2040] - b.vtCO2_xE_tot[2040],
        'Duty on energy excl. CO2': s.vtE_duty_xCO2[2040] - b.vtE_duty_xCO2[2040],
        'VAT on energy': s.vtE_vat_total[2040] - b.vtE_vat_total[2040],
        'Other indirect taxes': s.vtIndirect_Rest[2040] - b.vtIndirect_Rest[2040]
    },
    'Relative change (%)': {
        'Indirect taxes': (s.vtIndirect[2040]/b.vtIndirect[2040] - 1)*100,
        'CO2 tax, corporations': (s.vtCO2_Corp[2040]/b.vtCO2_Corp[2040] - 1)*100,
        'CO2 tax, households': (s.vtCO2_Hh[2040]/b.vtCO2_Hh[2040] - 1)*100,
        'CO2 tax, non-energy': (s.vtCO2_xE_tot[2040]/b.vtCO2_xE_tot[2040] - 1)*100,
        'Duty on energy excl. CO2': (s.vtE_duty_xCO2[2040]/b.vtE_duty_xCO2[2040] - 1)*100,
        'VAT on energy': (s.vtE_vat_total[2040]/b.vtE_vat_total[2040] - 1)*100,
        'Other indirect taxes': (s.vtIndirect_Rest[2040]/b.vtIndirect_Rest[2040] - 1)*100
    }
})
# print("\nBreakdown of indirect taxes in 2040:")
# print(indirect_table)





