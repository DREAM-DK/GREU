#Industries, demand components, capital types and energybalance
$import data.sets.gms

set l "Technologies";

variables
  w[t]
  nEmployed[t]

  qK[k,i,t]
  pK[k,i,t]
  pL[i,t]
  qL[i,t]
  qRxE[i,t]
  pRxE[i,t]

;

parameters auxiliary_data_parameters 
  pXEpj_base[es,e,t] ""
  pLEpj_base[es,e,t] ""
  pCEpj_base[es,e,t] ""
  pREpj_base[es,e,i,t] ""

  qREpj[es,e,i,t]
  qCEpj[es,e,t]
  qLEpj[es,e,t]
  qXEpj[es,e,t]
  qTLpj[es,e,t]

  vEAV_RE[es,e,i,t]
  vDAV_RE[es,e,i,t]
  vCAV_RE[es,e,i,t]

  vEAV_CE[es,e,t]
  vDAV_CE[es,e,t]
  vCAV_CE[es,e,t]

  vEAV[es,e,d,t]
  vDAV[es,e,d,t]
  vCAV[es,e,d,t]


  pY_CET[out,i,t] ""
  pM_CET[out,i,t] ""  
  qY_CET[out,i,t] ""
  qM_CET[out,i,t] ""

  vtRE_duty[etaxes,es,e,i,t]
  tEAFG_REmarg[es,e,i,t]
  vtRE_vat[es,e,i,t]

  vtCO2_RE[es,e,i,t]
  vtEAFG_RE[es,e,i,t]
  vtSO2_RE[es,e,i,t]
  vtNOx_RE[es,e,i,t]
  vtPSO_RE[es,e,i,t]
  vtVAT_RE[es,e,i,t]

  vtCE_duty[etaxes,es,e,t]  
  vtCE_vat[es,e,t]

  vtCO2_CE[es,e,t]
  vtEAFG_CE[es,e,t]
  vtSO2_CE[es,e,t]
  vtNOX_CE[es,e,t]
  vtPSO_CE[es,e,t]
  vtVAT_CE[es,e,t]

  qEmmCE_load[t,em,es,e]
  qEmmCxE_load[t,em]
  qEmmRE_load[i,t,em,es,e]
  qEmmRxE_load[i,t,em]
  qEmmtot_load[t,em,em_accounts]

  qEmmCE[em,es,e,t]
  qEmmCxE[em,t]
  qEmmRE[em,es,e,i,t]
  qEmmRxE[em,i,t]
  qEmmtot[em,em_accounts,t]

  #Nye på d 
  pEpj_base[es,e,d,t]
  qEpj[es,e,d,t]
  tqE[es,e,d,t]
  tpE[es,e,d,t]
  qEmmE_BU[em,es,e,d,t]
  qEmmxE[em,d,t]


  vtE_duty[etaxes,es,e,d,t]
  vtE_vat[es,e,d,t]
  tCO2_Emarg[em,es,e,d,t] 
  tEmarg_duty[etaxes,es,e,d,t]

  qEmmBorderTrade_load[t,em]
;

parameters GREU_data
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."

  Energybalance[ebalitems,transaction,d,es,e,t] "Main data input with regards to energy and energy-related emissions"
  NonEnergyEmissions[ebalitems,transaction,d,t] "Main data input with regards to non-energy related emissions"
  qEmmBorderTrade[em,t]

  tpLE[es,e,t] ""
  tpCE[es,e,t] ""
  tpXE[es,e,t] ""

  tCO2_REmarg_load[es,e,i,t,em]
  tCO2_REmarg[em,es,e,i,t]
  tREmarg_duty[etaxes,es,e,i,t]
  
  # tCO2_REmarg_GJ[purpose,energy19,r,t,emm_eq]

  qEtot[e,t] ""
  pE_avg[e,t] ""

  qProd[factors_of_production,i,t]
  pProd[factors_of_production,i,t]

  qEmmLULUCF5[land5,t]
  qEmmLULUCF[t] 
  sBioNatGas[t]

  GWP[em]

  vtCO2_ETS[i,t] 
  qCO2_ETS_freeallowances[i,t]

  vtNetproductionRest[i,t]
  vtCAP_prodsubsidy[i,t]

  # Abatement
  theta_load[l,es,i,e,t] "Potential, technology."
  uTE_load[l,es,i,e,t] "Energy use, technology."
  uTK_load[l,es,i,e,t] "Capital use, technology."

  theta[l,es,i,t] "Potential, technology."
  uTE[l,es,e,i,t] "Energy use, technology."
  uTK[l,es,i,t] "Capital use, technology."
;



$gdxIn P:\akg\Til_EU_projekt\EU_GR_data.gdx
$load w, qL, nEmployed
$load es=purpose, out=out, e=energy19, pXEpj_base=pXE_base.l, pLEpj_base=pLE_base.l, pCEpj_base=pCE_base.l, pREpj_base=pRE_base.l, pE_avg=pEtot.l
$load tpLE=tLE.l, tpCE=tCE.l, tpXE=tXE_.l
$load qEtot=qEtot.l,  pY_CET = pY_CET.l, pM_CET=pM_CET.l, qY_CET=qY_CET.l, qM_CET=qM_CET.l
$load qRepj=qREgj.l, qCEpj=qCE.l, qLEpj=qLE.l, qXEpj=qXE.l,qTLpj=qTL.l
$load vEAV_RE=vEAV_RE.l, vDAV_RE=vDAV_RE.l, vCAV_RE=vCAV_RE.l, vEAV_CE=vEAV_CE.l, vDAV_CE=vDAV_CE.l, vCAV_CE= vCAV_CE.l
$load pL ,pK, qK, qRxE, pRxE
$load qEmmBorderTrade_load =qEmmBorderTrade.l
$load em_accounts=accounts_all, land5
$load qEmmCE_load=qEmmConsE.l, qEmmCxE_load=qEmmConsxE.l, qEmmRE_load=qEmmProdE.l, qEmmRxE_load=qEmmProdxE.l, qEmmtot_load=qEmmtot.l, qEmmLULUCF=qEmmLULUCF.l, qEmmLULUCF5=qEmmLULUCF5.l, sBioNatGas=sBioNatGasAvgAdj.l
$load GWP=GWP.l
$load vtCO2_RE = vtCO2_RE.l, vtEAFG_RE = vtEAFG_RE.l, vtSO2_RE = vtSO2_RE.l, vtNOX_RE = vtNOX_RE.l, vtPSO_RE = vtPSO_RE.l, vtVAT_RE = vtVAT_RE.l
$load vtCO2_CE = vtCO2_CE.l, vtEAFG_CE = vtEAFG_CE.l, vtSO2_CE = vtSO2_CE.l, vtNOX_CE = vtNOX_CE.l, vtPSO_CE = vtPSO_CE.l, vtVAT_CE = vtVAT_CE.l
$load tCO2_REmarg_load = tCO2_REmarg.l, tEAFG_REmarg = tEAFG_REmarg.l
$load vtCO2_ETS = vtCO2_ETS.l, qCO2_ETS_freeallowances=qEmmProdE_dedETS.l
$load vtNetproductionRest=vtNetproductionRest.l
$load vtCAP_prodsubsidy=vtCAP_top.l
$gdxIn 

$gdxIn EU_tech_data_disagg.gdx
$load l=l theta_load=theta.l, uTE_load=uTE.l, uTK_load=uTK.l
$gdxIn


#Production
  vWages_i[i,t] = w.l[t] * qL.l[i,t];
  nL[t] = nEmployed.l[t];
  qProd['RxE',i,t]                 = qRxE.l[i,t];
  qProd['labor',i,t]               = qL.l[i,t];
  qProd['im',i,t]                  = qK.l['im',i,t];
  qProd['it',i,t]                  = qK.l['it',i,t];
  qProd['ib',i,t]                  = qK.l['ib',i,t];
  qProd['machine_energy',i,t]      = sum((es,e)$(not (sameas[es,'Heating'] or sameas[es,'Transport'])), pREpj_base[es,e,i,t]*qREpj[es,e,i,t]);
  qProd['transport_energy',i,t]    = sum((es,e)$(sameas[es,'Transport']), pREpj_base[es,e,i,t]*qREpj[es,e,i,t]);
  qProd['heating_energy',i,t]      = sum((es,e)$(sameas[es,'heating']), pREpj_base[es,e,i,t]*qREpj[es,e,i,t]);
  pProd[factors_of_production,i,t] = 1;

#Energy and emissions.
  $import create_energybalance.gms #Here GreenREFORM variables are combine to create the full energybalance as we would preferably receive it from the Statistical Office.

  pEpj_base[es,e,d,t]$(sum(demand_transaction, Energybalance['PJ',demand_transaction,d,es,e,t])) = sum(demand_transaction, Energybalance['BASE',demand_transaction,d,es,e,t])/sum(demand_transaction, Energybalance['PJ',demand_transaction,d,es,e,t]);
  qEpj[es,e,d,t] = sum(demand_transaction, Energybalance['PJ',demand_transaction,d,es,e,t]);

  vEAV[es,e,d,t] = sum(demand_transaction, Energybalance['EAV',demand_transaction,d,es,e,t]);
  vCAV[es,e,d,t] = sum(demand_transaction, Energybalance['CAV',demand_transaction,d,es,e,t]);
  vDAV[es,e,d,t] = sum(demand_transaction, Energybalance['DAV',demand_transaction,d,es,e,t]);

#Emissions
  qEmmE_BU[em,es,e,d,t]     = sum(demand_transaction,Energybalance[em,demand_transaction,d,es,e,t]);
  qEmmxE[em,d,t]            = sum(demand_transaction,NonEnergyEmissions[em,demand_transaction,d,t]);

  qEmmtot[em,em_accounts,t] = qEmmTot_load[t,em,em_accounts];

  qEmmBorderTrade[em,t]     = qEmmBorderTrade_load[t,em];
#Margins 


#Taxes 
  vtRE_duty[etaxes,es,e,i,t]  = Energybalance[etaxes,'input_in_production',i,es,e,t];
  vtRE_vat[es,e,i,t]          = Energybalance['VAT','input_in_production',i,es,e,t];

  vtCE_duty[etaxes,es,e,t]    = Energybalance[etaxes,'household_consumption','cCarEne',es,e,t];
  vtCE_duty[etaxes,es,e,t]    = Energybalance[etaxes,'household_consumption','cHouEne',es,e,t];
  vtCE_vat[es,e,t]            = Energybalance['VAT','household_consumption','cCarEne',es,e,t];
  vtCE_vat[es,e,t]            = Energybalance['VAT','household_consumption','cHouEne',es,e,t];

  tCO2_REmarg[em,es,e,i,t]          = tCO2_REmarg_load[es,e,i,t,em];
  tREmarg_duty['EAFG_tax',es,e,i,t] = tEAFG_REmarg[es,e,i,t]/1000; #Dividing by 1000 to convert from kroner per GJ to bio. kroner per Pj.

  vtE_duty[etaxes,es,e,d,t] = sum(demand_transaction, Energybalance[etaxes,demand_transaction,d,es,e,t]);
  vtE_vat[es,e,d,t]          = sum(demand_transaction, Energybalance['VAT',demand_transaction,d,es,e,t]);
  tCO2_Emarg[em,es,e,i,t]    = tCO2_REmarg[em,es,e,i,t];
  tEmarg_duty['EAFG_tax',es,e,i,t]      = tEAFG_REmarg[es,e,i,t]/1000; #Dividing by 1000 to convert from kroner per GJ to bio. kroner per Pj.

  # Abatement
  theta[l,es,i,t] = sum(e, theta_load[l,es,i,e,t]);
  uTE[l,es,e,i,t] = uTE_load[l,es,i,e,t];
  uTK[l,es,i,t] = sum(e, uTK_load[l,es,i,e,t]);

execute_unloaddi "data", vWages_i, nL, es, out, e, 
                        pE_avg, 
                        qEtot, pE_avg, pY_CET, pM_CET, qY_CET, qM_CET,
                        vEAV, vDAV, vCAV,
                        qProd, pProd,
                        em, em_accounts, land5, qEmmE_BU, qEmmxE, qEmmtot, qEmmLULUCF5, qEmmLULUCF, sBioNatGas, qEmmBorderTrade
                        c, x, k, g,
                        GWP,
                        vtCO2_ETS, qCO2_ETS_freeallowances
                        vtNetproductionRest,
                        vtCAP_prodsubsidy
                        pEpj_base, qEpj
                        vtE_duty, vtE_vat, tCO2_Emarg, tEmarg_duty
                        Energybalance, NonEnergyEmissions
                        theta, uTE, uTK;

