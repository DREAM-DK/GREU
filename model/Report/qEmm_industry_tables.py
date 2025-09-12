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