
$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  vCashFlow[sector,t]  "Change in finansiel assets before dividends"
  vEBITDA[t] "Total EBITDA"
  vtY_NetTaxSub[t] "Total net tax and subsidies from corp to gov"
  vIncomeFlow[flow,sector,t] "Income flow between sectors"
  ;

$ENDIF # report_def


$IF %stage% == "report":

  vCashFlow.l[sector,t] = vNetFinAssets.l[sector,t] - vNetFinAssets.l[sector,t-1]/fv - vNetDividends.l[sector,t] - vNetRevaluations.l[sector,t];

  vEBITDA.l[t] = sum(i$i_private[i], vEBITDA_i.l[i,t]);
  
  vtY_NetTaxSub.l[t] = sum(i$i_private[i], vtY_i_NetTaxSub.l[i,t]);
  
  vIncomeFlow.l['CashFlow',sector,t] = vCashflow.l[sector,t];
  vIncomeFlow.l['Interests',sector,t] = vNetInterests.l[sector,t];
  vIncomeFlow.l['Wages','Hh',t] = vWages.l[t];
  vIncomeFlow.l['Wages','Corp',t] = -sum(i$i_private[i],vWages_i.l[i,t]);
  vIncomeFlow.l['Transfers','Hh',t] = vHhTransfers.l[t];
  vIncomeFlow.l['Transfers','Gov',t] = -vHhTransfers.l[t];
  vIncomeFlow.l['HhTaxes','Hh',t] = -vHhTaxes.l[t];
  vIncomeFlow.l['HhTaxes','Gov',t] = vHhTaxes.l[t];
  vIncomeFlow.l['C','Hh',t] = -vC.l[t];
  # vIncomeFlow.l['CorpTaxes','Corp',t] = -vCorpTaxes.l[t];
  # vIncomeFlow.l['CorpTaxes','Gov',t] = vCorpTaxes.l[t];
  vIncomeFlow.l['Y','Corp',t] = sum(i$i_private[i], vY_i.l[i,t] - vD.l[i,t] - vE_i.l[i,t]);
  # vIncomeFlow.l['NetTaxSub','Gov',t] =  vtY_NetTaxSub.l[t]+sum(i$i_private[i], vtCO2e_non_energy.l[i,t]);
  # vIncomeFlow.l['NetTaxSub','Corp',t] = -vtY_NetTaxSub.l[t]-sum(i$i_private[i], vtCO2e_non_energy.l[i,t]);
  vIncomeFlow.l['I','Corp',t] = -vI_private.l[t];
  vIncomeFlow.l['I','Gov',t] = -vI_public.l[t];
  vIncomeFlow.l['ETS','Gov',t] = -vtCO2_ETS_tot.l[t];
  vIncomeFlow.l['ETS','RoW',t] = vtCO2_ETS_tot.l[t];
  vIncomeFlow.l['Y','Gov',t] =  sum(i$i_public[i], vEBITDA_i.l[i,t]+vWages_i.l[i,t]);
  vIncomeFlow.l['Wages','Gov',t] =  -sum(i$i_public[i], vWages_i.l[i,t]);
  vIncomeFlow.l['X','RoW',t] = -vX.l[t];
  vIncomeFlow.l['M','RoW',t] =  vM.l[t];
  vIncomeFlow.l['G','Gov',t] = -vG.l[t];
  vIncomeFlow.l['Duties','Gov',t] = vtY.l[t] + vtM.l[t];
  # vIncomeFlow.l['Lumpsum','Gov',t] = -vLumpsum.l[t];
  # vIncomeFlow.l['Lumpsum','Hh',t] = vLumpsum.l[t];

  vIncomeFlow.l['Test',sector,t] = 0;
  vIncomeFlow.l['Test',sector,t] = sum(flow, vIncomeFlow.l[flow,sector,t])-vIncomeFlow.l['CashFlow',sector,t]*2;

  


$ENDIF # report






