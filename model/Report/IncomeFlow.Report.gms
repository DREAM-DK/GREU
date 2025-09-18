
$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  vCashFlow[sector,t]  "Change in finansiel assets before dividends"
  vtY_NetTaxSub[t] "Total net tax and subsidies from corp to gov"
  vNetGov2Corp_xIO_tot[t] "Total net gov to corp"
  vIncomeFlow[flow,sector,t] "Income flow between sectors"
  vIncomeFlowAgg[flowAgg,sector,t] "Income flow between sectors - aggregated"
  ;

$ENDIF # report_def


$IF %stage% == "report":

  vtY_NetTaxSub.l[t] = sum(i$i_private[i], vtY_i_NetTaxSub.l[i,t]);
  vNetGov2Corp_xIO_tot.l[t] = sum(i$i_private[i], vNetGov2Corp_xIO.l[i,t]);


  vCashFlow.l[sector,t] = vNetFinAssets.l[sector,t] - vNetFinAssets.l[sector,t-1]/fv - vNetDividends.l[sector,t] - vNetRevaluations.l[sector,t];

  
  vIncomeFlow.l['CashFlow',sector,t] = vCashflow.l[sector,t];
  vIncomeFlow.l['Interests',sector,t] = vNetInterests.l[sector,t];

  vIncomeFlow.l['Wages','Hh',t] = vWages.l[t];
  vIncomeFlow.l['Wages','Corp',t] = -sum(i$i_private[i],vWages_i.l[i,t]);
  vIncomeFlow.l['Wages','Gov',t] =  -sum(i$i_public[i], vWages_i.l[i,t]);
  
  vIncomeFlow.l['Hh2Gov','Hh',t] = -vNetHh2Gov.l[t];
  vIncomeFlow.l['Hh2Gov','Gov',t] = vNetHh2Gov.l[t];

  vIncomeFlow.l['C','Hh',t] = -vC.l[t];

  vIncomeFlow.l['Gov2F','Gov',t] = -vNetGov2Foreign.l[t];
  vIncomeFlow.l['Gov2F','RoW',t] = vNetGov2Foreign.l[t];

  vIncomeFlow.l['Gov2Corp','Gov',t] = vtY_NetTaxSub.l[t]-vNetGov2Corp_xIO_tot.l[t];
  vIncomeFlow.l['Gov2Corp','Corp',t] = -vtY_NetTaxSub.l[t]+vNetGov2Corp_xIO_tot.l[t];


  vIncomeFlow.l['Y','Corp',t] = sum(i$i_private[i], vY_i.l[i,t] - vD.l[i,t] - vE_i.l[i,t]);
  vIncomeFlow.l['I','Corp',t] = -vI_private.l[t];
  vIncomeFlow.l['I','Gov',t] = -vI_public.l[t];
  vIncomeFlow.l['Y','Gov',t] =  sum(i$i_public[i], vEBITDA_i.l[i,t]+vWages_i.l[i,t]+vtY_i_NetTaxSub.l[i,t]-vNetGov2Corp_xIO.l[i,t]);
  vIncomeFlow.l['X','RoW',t] = -vX.l[t];
  vIncomeFlow.l['M','RoW',t] =  vM.l[t];
  vIncomeFlow.l['G','Gov',t] = -vG.l[t];
  vIncomeFlow.l['Duties','Gov',t] = vtY.l[t] + vtM.l[t];
 
  vIncomeFlow.l['Test',sector,t] = 0;
  vIncomeFlow.l['Test',sector,t] = sum(flow, vIncomeFlow.l[flow,sector,t])-vIncomeFlow.l['CashFlow',sector,t]*2;

  
  vIncomeFlowAgg.l['Wages',sector,t] = vIncomeFlow.l['Wages',sector,t];
  vIncomeFlowAgg.l['Tax_transfers','Hh',t] = vIncomeFlow.l['Hh2Gov','Hh',t]; 
  vIncomeFlowAgg.l['Tax_transfers','Corp',t] = vIncomeFlow.l['Gov2Corp','Corp',t];
  vIncomeFlowAgg.l['Tax_transfers','RoW',t] = vIncomeFlow.l['Gov2F','RoW',t];
  vIncomeFlowAgg.l['Tax_transfers','Gov',t] = vIncomeFlow.l['Hh2Gov','Gov',t]
                                             +vIncomeFlow.l['Gov2F','Gov',t]
                                             +vIncomeFlow.l['Gov2Corp','Gov',t];
  
  vIncomeFlowAgg.l['Surply_YM','Gov',t] = vIncomeFlow.l['Y','Gov',t];
  vIncomeFlowAgg.l['Surply_YM','Corp',t] = vIncomeFlow.l['Y','Corp',t];
  vIncomeFlowAgg.l['Surply_YM','RoW',t] = vIncomeFlow.l['M','RoW',t];
  vIncomeFlowAgg.l['Demand_CGIX','Hh',t] = vIncomeFlow.l['C','Hh',t];
  vIncomeFlowAgg.l['Demand_CGIX','Gov',t] = vIncomeFlow.l['G','Gov',t]
                                         + vIncomeFlow.l['I','Gov',t];
  vIncomeFlowAgg.l['Demand_CGIX','Corp',t] = vIncomeFlow.l['I','Corp',t];
  vIncomeFlowAgg.l['Demand_CGIX','RoW',t] = vIncomeFlow.l['X','RoW',t];
  vIncomeFlowAgg.l['Duties','Gov',t] = vIncomeFlow.l['Duties','Gov',t];

                                             


$ENDIF # report

