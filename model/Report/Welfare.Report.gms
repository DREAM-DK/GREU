
$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  # Baseline variables
  pD_baseline[d,t]  "Prices in baseline"
  qD_baseline[d,t]  "Quantities in baseline"
  vHhIncome_baseline[t]  "Income in baseline"
  vNetGov2Foreign_baseline[t]  "Payments to RoW in baseline"
  vNetDividends_baseline[sector,t]  "Dividends in baseline"
  qEmmTot_baseline[em,em_accounts,t]  "Emissions in baseline"
  vNetInterests_baseline[sector,t]  "Interests in baseline"
  vHhTransfers_baseline[t]  "Transfers to HH in baseline"
  vHhTaxes_baseline[t]  "Taxes on HH in baseline"
  vLumpsum_baseline[t]  "Lumpsum in baseline"
  vWages_baseline[t]  "Wages in baseline"
  pY_i_baseline[i,t] "pY_i in baseline"

  # Reporting variables
  EVt[EV_set,t]  "Equivalent variations effects over time"
  EV[EV_set]  "Equivalent variations effects weighted over all time periods"
  EV_income[income_set]  "Equivalent variations effects on income weighted over all time periods"
  EVt_Weight[t]  "Weight for each time period"
  EVt_r_fv[t]  "Discount factor for each time period"
  EV_Shadow_price[Shadow_price_set]  "Shadow prices on emissions"
  EVt_income[income_set,t]  "Equivalent variations effects on income over time"
  EVt_display[EVt_display_set,t]  "Equivalent variations effects over time for display"

  pY_i_diff[i,t] ""
  ;

$ENDIF # report_def

$IF %stage% == "report_baseline":

  pD_baseline.l[d,t] = pD.l[d,t];
  qD_baseline.l[d,t] = qD.l[d,t];
  vHhIncome_baseline.l[t] = vHhIncome.l[t];
  vNetGov2Foreign_baseline.l[t] = vNetGov2Foreign.l[t];
  vNetDividends_baseline.l[sector,t] = vNetDividends.l[sector,t];
  qEmmTot_baseline.l[em,em_accounts,t] = qEmmTot.l[em,em_accounts,t];
  vNetInterests_baseline.l[sector,t] = vNetInterests.l[sector,t];
  vHhTransfers_baseline.l[t] = vHhTransfers.l[t];
  vHhTaxes_baseline.l[t] = vtHhWages.l[t] + vtHhReturn.l[t] + vtDirect_other.l[t];
  vLumpsum_baseline.l[t] = vLumpsum.l[t];
  vWages_baseline.l[t] = vWages.l[t];
  pY_i_baseline.l[i,t] = pY_i.l[i,t];

$ENDIF # report_baseline


$IF %stage% == "report":

EVt.l['Income_d',t] = 
     vHhIncome.l[t]-vNetInterests.l['Hh',t] 
  - (vHhIncome_baseline.l[t]-vNetInterests_baseline.l['Hh',t]); 

EVt.l['Income_f',t] = vNetGov2Foreign.l[t] 
                    - vNetGov2Foreign_baseline.l[t]; 


EVt.l['Price_d',t] = - sum(c, (pD.l[c,t]-pD_baseline.l[c,t])*qD.l[c,t]
	                           +(pD.l[c,t]-pD_baseline.l[c,t])*(qD_baseline.l[c,t]-qD.l[c,t])/2);

EVt.l['Price_f',t] = - sum(x, (pD.l[x,t]-pD_baseline.l[x,t])*qD.l[x,t]
	                           +(pD.l[x,t]-pD_baseline.l[x,t])*(qD_baseline.l[x,t]-qD.l[x,t])/2);

EVt.l['Wealth_d',t] = vNetDividends.l['Hh',t] - vNetDividends_baseline.l['Hh',t];
EVt.l['Wealth_f',t] = vNetDividends.l['RoW',t] - vNetDividends_baseline.l['RoW',t];


EVt_income.l['Wages',t] = vWages.l[t] - vWages_baseline.l[t];
EVt_income.l['Lumpsum',t] = vLumpsum.l[t] - vLumpsum_baseline.l[t];
EVt_income.l['Transfers',t] = vHhTransfers.l[t] - vHhTransfers_baseline.l[t];
EVt_income.l['HhTaxes',t] = -vtHhWages.l[t] -vtHhReturn.l[t] -vtDirect_other.l[t] +vHhTaxes_baseline.l[t];
EVt_income.l['Rest',t] = EVt.l['Income_d',t]
                        -EVt_income.l['Wages',t]-EVt_income.l['Lumpsum',t]
                        -EVt_income.l['Transfers',t]-EVt_income.l['HhTaxes',t];


  # .. vNetHh2Gov[t] =E= vtHhWages[t] + vtHhReturn[t] + vtDirect_other[t] 
  #                      + vCont[t] + vGovRevGovCorpCorrection[t] + vGovDeprCorrection[t] + vtCap[t]  
  #                      - vHhTransfers[t] - vGovNetAcquisitions[t] - vLumpsum[t];



EVt_r_fv.l[t] = (1+rInterests.l[t])/fv-1;

EVt_Weight.l[t] = 0;
EVt_Weight.l[t]$(t.val gt t0.val) = prod(tt $ (ord(t) ge ord(tt) and tt.val gt t0.val), 1/(1+EVt_r_fv.l[tt]));
EVt_Weight.l[t]$(tEnd[t])  = EVt_Weight.l[t]/EVt_r_fv.l[t];

EVt_display.l['EV',t] = sum(EV_set, EVt.l[EV_set,t]);
EVt_display.l['Weight',t] = EVt_Weight.l[t];
EVt_display.l['Weight',t]$(tEnd[t]) = 0;


EV.l[EV_set] = sum(t, EVt.l[EV_set,t]*EVt_Weight.l[t]) / sum(t, EVt_Weight.l[t]);
EV_income.l[income_set] = sum(t, EVt_income.l[income_set,t]*EVt_Weight.l[t]) / sum(t, EVt_Weight.l[t]);

EV_Shadow_price.l['EV'] = sum(EV_set, EV.l[EV_set]);
EV_Shadow_price.l['Emissions'] =  sum(t, (qEmmTot.l['co2e','UNFCCC_LULUCF',t]-qEmmTot_baseline.l['co2e','UNFCCC_LULUCF',t])
                               *EVt_Weight.l[t]) / sum(t, EVt_Weight.l[t]);
# EV mulitplyed by 1000 to get in millions - emissions is in millions of tons
EV_Shadow_price.l['Shadow_price']$(EV_Shadow_price.l['Emissions'] ne 0) =  EV_Shadow_price.l['EV']*1000
                                                                    /(EV_Shadow_price.l['Emissions']/1000);



pY_i_diff.l[i,t] = pY_i.l[i,t] - pY_i_baseline.l[i,t];



$ENDIF # report






