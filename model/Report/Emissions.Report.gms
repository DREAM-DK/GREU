
$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  qCO2e_i(i,iagg,emission_categories,t) "CO2e emissions by on industries level"
  qCO2e_iagg(iagg,emission_categories,t) "CO2e emissions by aggregated industries"
  qCO2e_service_other(i,t) "CO2e udledninger fra service industrier i other kategorien"  
  qCO2e_taxCategories(CO2etax,t) "CO2e udledninger fra skatte kategorier"
  ;

$ENDIF # report_def


$IF %stage% == "report":

  qCO2e_i.l[i,iagg,emission_categories,t]$iagg2i[iagg,i] =  
      sum((map_emission_categories[emission_categories,es,i],e), qemme_BU.l['CO2e',es,e,i,t])
    - sum((map_emission_categories[emission_categories,es,i],e)$MapBunkering['CO2e',es,e,i], qemme_BU.l['CO2e',es,e,i,t])
    - sum((map_emission_categories[emission_categories,es,i],e)$MapOtherDifferencesShips['CO2e',es,e,i], qemme_BU.l['CO2e',es,e,i,t])
    - sum((map_emission_categories[emission_categories,es,i],e)$MapInternationalAviation['CO2e',es,e,i], qemme_BU.l['CO2e',es,e,i,t])
    ;

  qCO2e_i.l[i,iagg,'NonEnergyEmissions',t]$iagg2i[iagg,i] = qEmmxE.l['CO2e',i,t];

  qCO2e_i.l[i,iagg,'Total',t]$iagg2i[iagg,i] = sum(emission_categories, qCO2e_i.l[i,iagg,emission_categories,t]); 


  qCO2e_iagg.l[iagg,emission_categories,t] = sum(iagg2i[iagg,i], qCO2e_i.l[i,iagg,emission_categories,t]);

  # qCO2e_taxCategories.l['energy_Corp',t] = sum((es,e,i), qCO2e_energy.l[es,e,i,t]);

$ENDIF # report






