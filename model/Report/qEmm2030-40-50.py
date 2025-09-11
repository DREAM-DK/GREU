tabel1=table(s.qEmmTot-b.qEmmTot,target_values={'em':['co2e'],'em_accounts':['UNFCCC_lulucf'],'t':[2030,2040,2050]},cols='t')
tabel2=table(s.qCO2e_iagg-b.qCO2e_iagg,target_values={'emission_categories':['Total'],'t':[2030,2040,2050]},cols='t')
tabel3=table(s.qEmmE-b.qEmmE, target_values={'em':['co2e'],'d':['cCarEne','cHouEne'],'t':[2030,2040,2050]}, cols='t')

# display(tabel1)
# display(tabel2)
# display(tabel3)

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

