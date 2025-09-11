
$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  pD_baseline[d,t]  "Prices in baseline"
  qD_baseline[d,t]  "Quantities in baseline"
  vHhIncome_baseline[t]  "Income in baseline"
  vtCO2_ETS_tot_baseline[t]  "ETS payments to RoW in baseline"
  vNetDividends_baseline[sector,t]  "Dividends in baseline"
  qEmmTot_baseline[em,em_accounts,t]  "Emissions in baseline"
  vNetInterests_baseline[sector,t]  "Interests in baseline"
  vHhTransfers_baseline[t]  "Transfers to HH in baseline"
  vHhTaxes_baseline[t]  "Taxes on HH in baseline"
  vLumpsum_baseline[t]  "Lumpsum in baseline"
  vWages_baseline[t]  "Wages in baseline"
  pY_i_baseline[i,t] "pY_i in baseline"

  EVt[EV_set,t]  "Equivalent variations effects over time"
  EV[EV_set]  "Equivalent variations effects weighted over all time periods"
  EVt_Weight[t]  "Weight for each time period"
  EVt_r_fv[t]  "Discount factor for each time period"
  Shadow_price[Shadow_price_set]  "Shadow prices on emissions"
  EVt_income[income_set,t]  "Equivalent variations effects on income over time"
  EVt_display[EVt_display_set,t]  "Equivalent variations effects over time for display"

  pY_i_diff[i,t] ""
  ;

$ENDIF # report_def

$IF %stage% == "report_baseline":

  pD_baseline.l[d,t] = pD.l[d,t];
  qD_baseline.l[d,t] = qD.l[d,t];
  vHhIncome_baseline.l[t] = vHhIncome.l[t];
  vtCO2_ETS_tot_baseline.l[t] = vtCO2_ETS_tot.l[t];
  vNetDividends_baseline.l[sector,t] = vNetDividends.l[sector,t];
  qEmmTot_baseline.l[em,em_accounts,t] = qEmmTot.l[em,em_accounts,t];
  vNetInterests_baseline.l[sector,t] = vNetInterests.l[sector,t];
  vHhTransfers_baseline.l[t] = vHhTransfers.l[t];
  vHhTaxes_baseline.l[t] = vHhTaxes.l[t];
  # vLumpsum_baseline.l[t] = vLumpsum.l[t];
  vWages_baseline.l[t] = vWages.l[t];
  pY_i_baseline.l[i,t] = pY_i.l[i,t];

$ENDIF # report_baseline


$IF %stage% == "report":

EVt.l['Income_d',t] = vHhIncome.l[t]-vNetInterests.l['Hh',t] - (vHhIncome_baseline.l[t]-vNetInterests_baseline.l['Hh',t]); 
EVt.l['Income_f',t] = vtCO2_ETS_tot.l[t] - vtCO2_ETS_tot_baseline.l[t]; 


EVt.l['Price_d',t] = - sum(c, (pD.l[c,t]-pD_baseline.l[c,t])*qD.l[c,t]
	                           +(pD.l[c,t]-pD_baseline.l[c,t])*(qD_baseline.l[c,t]-qD.l[c,t])/2);

EVt.l['Price_f',t] = - sum(x, (pD.l[x,t]-pD_baseline.l[x,t])*qD.l[x,t]
	                           +(pD.l[x,t]-pD_baseline.l[x,t])*(qD_baseline.l[x,t]-qD.l[x,t])/2);

EVt.l['Wealth_d',t] = vNetDividends.l['Hh',t] - vNetDividends_baseline.l['Hh',t];
EVt.l['Wealth_f',t] = vNetDividends.l['RoW',t] - vNetDividends_baseline.l['RoW',t];


EVt_income.l['Wages',t] = vWages.l[t] - vWages_baseline.l[t];
# EVt_income.l['Lumpsum',t] = vLumpsum.l[t] - vLumpsum_baseline.l[t];
EVt_income.l['Transfers',t] = vHhTransfers.l[t] - vHhTransfers_baseline.l[t];
EVt_income.l['HhTaxes',t] = vHhTaxes.l[t] - vHhTaxes_baseline.l[t];


EVt_r_fv.l[t] = (1+rInterests.l[t])/fv-1;

EVt_Weight.l[t] = 0;
EVt_Weight.l[t]$(t.val gt t0.val) = prod(tt $ (ord(t) ge ord(tt) and tt.val gt t0.val), 1/(1+EVt_r_fv.l[tt]));
EVt_Weight.l[t]$(tEnd[t])  = EVt_Weight.l[t]/EVt_r_fv.l[t];

EVt_display.l['EV',t] = sum(EV_set, EVt.l[EV_set,t]);
EVt_display.l['Weight',t] = EVt_Weight.l[t];
EVt_display.l['Weight',t]$(tEnd[t]) = 0;


EV.l[EV_set] = sum(t, EVt.l[EV_set,t]*EVt_Weight.l[t]) / sum(t, EVt_Weight.l[t]);

Shadow_price.l['EV'] = sum(EV_set, EV.l[EV_set]);
Shadow_price.l['Emissions'] =  sum(t, (qEmmTot.l['co2e','UNFCCC_LULUCF',t]-qEmmTot_baseline.l['co2e','UNFCCC_LULUCF',t])
                               *EVt_Weight.l[t]) / sum(t, EVt_Weight.l[t]);
# EV mulitplyed by 1000 to get in millions - emissions is in millions of tons
Shadow_price.l['Shadow_price']$(Shadow_price.l['Emissions'] ne 0) =  Shadow_price.l['EV']*1000
                                                                    /(Shadow_price.l['Emissions']/1000);



pY_i_diff.l[i,t] = pY_i.l[i,t] - pY_i_baseline.l[i,t];

    # E_Sdis[t]$(tEndo[t])..   Sdis[t]     =E= prod(tt $ (ord(t) ge ord(tt) and tt.val gt t0.val), 1/(1+rHH[tt]));  


# EVt['vaegt',t] = 0;
# EVt['vaegt',t]$(tx0[t]) = Sdis.l[t];
# EVt['vaegt',t]$(tEnd[t])  = Sdis.l[t]/rHH.l[t];


# EVti[set_EVti,s,t] = 0;
# EVti['pris',s,t]$(tx0[t]) = -sum(c, (pC_ym.l[c,s,t]/pC_ym_baseline.l[c,s,t]-1)*qC_ym.l[c,s,t]);
# EVti['PrisUdl',s,t]$(tx0[t]) = -((pX_y.l['xoth',s,t]/pX_y_baseline.l['xoth',s,t]-1)*qX_y.l['xoth',s,t]+(pX_y.l['xoth',s,t]/pX_y_baseline.l['xoth',s,t]-1)*(qX_y_baseline.l['xoth',s,t]-qX_y.l['xoth',s,t])/2);
# EVti['Pris+',s,t] $(EVti['Pris',s,t] gt 0) = EVti['Pris',s,t];
# EVti['Pris-',s,t] $(EVti['Pris',s,t] lt 0) = EVti['Pris',s,t];
# EVti['PrisUdl+',s,t] $(EVti['PrisUdl',s,t] gt 0) = EVti['PrisUdl',s,t];
# EVti['PrisUdl-',s,t] $(EVti['PrisUdl',s,t] lt 0) = EVti['PrisUdl',s,t];


# EVt[set_EV_all,t] = 0;

# EVt['Pris+',t] = sum(s, EVti['Pris+',s,t]);
# EVt['Pris-',t] = sum(s, EVti['Pris-',s,t]);
# EVt['PrisUdl+',t] = sum(s, EVti['PrisUdl+',s,t]);
# EVt['PrisUdl-',t] = sum(s, EVti['PrisUdl-',s,t]);


# Hwage.l[t]    = w.l[t] * Hours.l[t] * prod_a.l[t] * nEmployed.l[t];
# Htrans.l[t]   = vTrans.l[t];
# Hleisure.l[t] = - pCHH.l['cTot',t] * qDisUtility.l[t];
# Hother.l[t]   = vLeisureAdjustedIncome.l[t]-Hwage.l[t]-Htrans.l[t]-Htax.l[t]-Hleisure.l[t];    
# EVt['indk',t] = (vLeisureAdjustedIncome.l[t]-vLeisureAdjustedIncome_baseline.l[t]);
# EVt['indk_w',t] = (Hwage.l[t]-Hwage_baseline.l[t]);
# EVt['indk_trans',t] = (Htrans.l[t]-Htrans_baseline.l[t]);
# EVt['indk_tax_xLump',t] = - (vtDirect.l[t]-vtCorp.l[t]-t_r.l[t]*rHHxAfk.l[t]*vWealth.l[t-1]/fv) -jvtIndirect.l[t]-vGovProfit.l[t]-vGovReceiveHH.l[t]-vtBequest.l[t]-vtChurch.l[t]-vCont.l[t]+vGov2HH.l[t]+vGovLand.l[t];
# EVt['indk_lei',t] = (Hleisure.l[t]-Hleisure_baseline.l[t]);
# EVt['indk_other',t] = (Hother.l[t]-Hother_baseline.l[t]);
# EVt['indk_lumpsum',t] = -vLumpsum.l[t];


# EVt['pris',t]$(tEndo[t]) = -vLeisureAdjustedIncome.l[t]*(pC.l['ctot',t]/pC_baseline.l['ctot',t]-1);
# EVt['PrisUdl',t]  = sum(s, -((pX_y.l['xoth',s,t]-pX_y_baseline.l['xoth',s,t])*qX_y.l['xoth',s,t]
# 	                             +(pX_y.l['xoth',s,t]-pX_y_baseline.l['xoth',s,t])*(qX_y_baseline.l['xoth',s,t]-qX_y.l['xoth',s,t])/2));
# EVt['formue',t]    = sum(sp$(NOT s_DK[sp]),  sEquityDKownedEndo.l[t1] *vFCFE.l[sp,t]) + sum(s_DK,    sEquityDKownedExo.l[s_DK,t1] *vFCFE.l[s_DK,t]); 
# EVt['formueUdl',t] = sum(sp, vFCFE.l[sp,t]) - EVt['formue',t]; 


# EVt['vaegt',t] = 0;
# EVt['vaegt',t]$(tx0[t]) = Sdis.l[t];
# EVt['vaegt',t]$(tEnd[t])  = Sdis.l[t]/rHH.l[t];

# EVt['vaegt_Investor',t] = 0;
# EVt['vaegt_Investor',t]$(tx0[t]) = prod(tt $ (ord(t) ge ord(tt) and tt.val gt t0.val), fv/(1+rInvestor.l['49509',tt]));
# EVt['vaegt_Investor',t]$(tEnd[t])  = EVt['vaegt_Investor',t]/(rInvestor.l['49509',t]/fv);


# #  Nutidsværdien udregnes via diskontering af tidsserierne
# EV[set_EV_all,'NPV'] = sum(t, EVt[set_EV_all,t]*EVt['vaegt',t]);  

# #  Korrektioner ift. tidsserieudregningerne
# #  omega[t]    =E= pU[t]**(1-eC_R)
# EV['pris','NPV'] = sum(t$(t0[t]),  -(omega.l[t]**(1/(1-eC_R.l))/pU_baseline.l[t]-1)*(H.l[t]+(1-pDeath.l)*vWealth.l[t]))
#             +sum(t$(tx0[t]), -(omega.l[t]**(1/(1-eC_R.l))/pU_baseline.l[t]-1)*EVt['vaegt',t]*pDeath.l*H.l[t])
#             +sum(t$(tx0[t]), -(pC.l['ctot',t]/pC_baseline.l['ctot',t]-1)*EVt['vaegt',t]*(1-s_R.l[t])*vLeisureAdjustedIncome.l[t]);



# EV['formue_old','NPV'] = sum(t$(t0[t]), vWealth_shockCorrection.l[t])*(1-pDeath.l);
# EV['formueUdl_old','NPV'] = sum(t$(t0[t]), ((sum(sp,vEquity.l[sp,t])-sum(sp,vEquity_baseline.l[sp,t]))-vWealth_shockCorrection.l[t])*(1-pDeath.l));

# EV['formue_rInv','NPV'] = sum(t, EVt['formue',t]*EVt['vaegt_Investor',t]);  
# EV['formueUdl_rInv','NPV'] = sum(t, EVt['formueUdl',t]*EVt['vaegt_Investor',t]);  


# #  Samlet EV
# EV['EV_dk','NPV'] = EV['Indk','NPV']+EV['Pris','NPV']+EV['Formue','NPV'];
# EV['EV_inklUdl','NPV'] = EV['EV_dk','NPV'] + EV['PrisUdl','NPV'] + EV['formueUdl','NPV'];

# #  Omregning til 2023-niveau og årligt gennemsnit
# EV[set_EV_all,'NPV'] = EV[set_EV_all,'NPV']/inf_growth_factor['2023'];
# EV[set_EV_all,'yearly'] = EV[set_EV_all,'NPV']/sum(t, EVt['vaegt',t]);
  


$ENDIF # report






