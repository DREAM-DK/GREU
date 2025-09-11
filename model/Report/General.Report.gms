
$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  # vCashFlow[sector,t]  "Change in finansiel assets before dividends"
  qY_iagg[iagg,t] "Output by aggregated industries"
  pY_iagg[iagg,t] "Price by aggregated industries"
  qDomesticDemand[t] "Domestic demand"
  vtE_vat_total[t] "Total VAT on energy"
  vtE_duty_total[t] "Total duty on energy excl. CO2e-tax"
  vtCO2e_total[t] "Total CO2e-tax"
  ;

$ENDIF # report_def


$IF %stage% == "report":

  # vCashFlow.l[sector,t] = vNetFinAssets.l[sector,t] - vNetFinAssets.l[sector,t-1]/fv - vNetDividends.l[sector,t];

  qY_iagg.l[iagg,t]$(t_endoyrs[t]) = sum(i$iagg2i[iagg,i], sum(tBase,pY_i.l[i,tBase])*qY_i.l[i,t]);
  pY_iagg.l[iagg,t]$(t_endoyrs[t]) = sum(i$iagg2i[iagg,i], pY_i.l[i,t]*qY_i.l[i,t])/qY_iagg.l[iagg,t];

  qDomesticDemand.l[t] = sum(tBase,pC.l[tBase]*qC.l[t]) + sum(tBase,pI.l[tBase]*qI.l[t]) + sum(tBase,pG.l[tBase]*qG.l[t]) + sum(tBase,pM.l[tBase]*qM.l[t]);

  vtE_vat_total.l[t] = sum(d, vtE_vat_tot.l[d,t]);
  vtE_duty_total.l[t] = sum(d, vtE_duty_tot.l[d,t]);
  # vtCO2e_total.l[t] = sum((CO2etax), tCO2e.l[CO2etax,t] * qCO2e_taxgroup.l[CO2etax,t]);


$ENDIF # report






