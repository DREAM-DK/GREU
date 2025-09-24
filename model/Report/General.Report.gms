# ----------------------------------------------------------------------------------------------------------------------
# 1. Report Variables
# ----------------------------------------------------------------------------------------------------------------------

$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  # vCashFlow[sector,t]  "Change in finansiel assets before dividends"
  qY_iagg[iagg,t] "Output by aggregated industries"
  pY_iagg[iagg,t] "Price by aggregated industries"
  qDomesticDemand[t] "Domestic demand"
  vtE_vat_total[t] "Total VAT on energy"
  vtE_duty_xCO2[t] "Total duty on energy excl. CO2e-tax"
  vtCO2e_total[t] "Total CO2e-tax"
  vtCO2_Corp[t] "Total CO2-tax paid by corporations"
  vtCO2_Hh[t] "Total CO2-tax paid by households"
  vtCO2_xE_tot[t] "Total emission tax from non-energy emissions"
  vtIndirect_Rest[t] "Other indirect taxes"
  vtCO2_Mechanic[d,t] "Mechanic value of CO2-tax"
  vtCO2_Mechanic_change[d,t] "Change in mechanic value of CO2-tax"
  qEmmxE_baseline[em,d,t] "Baseline non-energy emissions"
  qEpj_baseline[es,e,d,t] "Baseline energy use"
  qEpj_duty_deductible_baseline[etaxes,es,e,d,t] "Baseline duty deductible"
  vtCO2_xE_baseline[d,t] "Baseline tax value of non-energy emissions"
  vtE_duty_baseline[etaxes,es,e,d,t] "Baseline duty value"
  pY0_i_Mechanic_change[i,t] " Mechanic change in output price by industry"
  qY0_i_baseline[i,t] "Baseline output by industry"
  ;

$ENDIF # report_def

# ----------------------------------------------------------------------------------------------------------------------
# 2. Baseline values
# ----------------------------------------------------------------------------------------------------------------------

$IF %stage% == "report_baseline":

  qEmmxE_baseline.l[em,d,t] = qEmmxE.l[em,d,t];
  qEpj_baseline.l[es,e,d,t] = qEpj.l[es,e,d,t];
  qEpj_duty_deductible_baseline.l[etaxes,es,e,d,t] = qEpj_duty_deductible.l[etaxes,es,e,d,t];
  vtCO2_xE_baseline.l[d,t] = vtCO2_xE.l[d,t];
  vtE_duty_baseline.l[etaxes,es,e,d,t] = vtE_duty.l[etaxes,es,e,d,t];
  qY0_i_baseline.l[i,t] = qY0_i.l[i,t];

$ENDIF # report_baseline

# ----------------------------------------------------------------------------------------------------------------------
# 3. Metric Calculations
# ----------------------------------------------------------------------------------------------------------------------

$IF %stage% == "report":

  # vCashFlow.l[sector,t] = vNetFinAssets.l[sector,t] - vNetFinAssets.l[sector,t-1]/fv - vNetDividends.l[sector,t];

  qY_iagg.l[iagg,t]$(t_endoyrs[t]) = sum(i$iagg2i[iagg,i], sum(tBase,pY_i.l[i,tBase])*qY_i.l[i,t]);
  pY_iagg.l[iagg,t]$(t_endoyrs[t]) = sum(i$iagg2i[iagg,i], pY_i.l[i,t]*qY_i.l[i,t])/qY_iagg.l[iagg,t];

  qDomesticDemand.l[t] = sum(tBase,pC.l[tBase]*qC.l[t]) + sum(tBase,pI.l[tBase]*qI.l[t]) + sum(tBase,pG.l[tBase]*qG.l[t]) + sum(tBase,pM.l[tBase]*qM.l[t]);

  vtE_vat_total.l[t] = sum(d, vtE_vat_tot.l[d,t]);
  vtE_duty_xCO2.l[t] = sum(d, vtE_duty_tot.l[d,t]) - sum((es,e,d), vtE_duty.l['co2_tax',es,e,d,t]);
  # vtCO2e_total.l[t] = sum((CO2etax), tCO2e.l[CO2etax,t] * qCO2e_taxgroup.l[CO2etax,t]);

  vtCO2_Corp.l[t] = sum((es,e,i), vtE_duty.l['co2_tax',es,e,i,t]);
  vtCO2_Hh.l[t] = sum((es,e,c), vtE_duty.l['co2_tax',es,e,c,t]) 
                + sum((em,es,e,c), tCO2_Emarg_C_pj.l[em,es,e,c,t]*qEpj.l[es,e,c,t]);
  vtCO2_xE_tot.l[t] = sum(i, vtCO2_xE.l[i,t]);

  vtIndirect_Rest.l[t] = vtIndirect.l[t] - vtE_vat_total.l[t] - vtE_duty_xCO2.l[t]
                       - vtCO2_Corp.l[t] - vtCO2_Hh.l[t] - vtCO2_xE_tot.l[t];

  # Mechanic value of CO2-tax
  vtCO2_Mechanic.l[d,t] = tCO2_xEmarg.l[d,t]/10**6 * qEmmxE_baseline.l['CO2e',d,t]
                          + sum((es,e), tEmarg_duty.l['co2_tax',es,e,d,t] *
                                (qEpj_baseline.l[es,e,d,t] + epsilon - qEpj_duty_deductible_baseline.l['co2_tax',es,e,d,t])
                                + jvtE_duty.l['co2_tax',es,e,d,t]);

  # Mechanic change in value of CO2-tax
  vtCO2_Mechanic_change.l[d,t] = vtCO2_Mechanic.l[d,t]
                               - vtCO2_xE_baseline.l[d,t]
                               - sum((es,e), vtE_duty_baseline.l['co2_tax',es,e,d,t]);

  pY0_i_Mechanic_change.l[i,t]$(qY0_i_baseline.l[i,t]) = vtCO2_Mechanic_change.l[i,t] / qY0_i_baseline.l[i,t]*100;



$ENDIF # report






