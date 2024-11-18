#Industries, demand components, capital types and energybalance
$import data.sets.gms


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

  pY_CET[out,i,t] ""
  pM_CET[out,i,t] ""  
  qY_CET[out,i,t] ""
  qM_CET[out,i,t] ""

  vtRE_duty[etaxes,es,e,i,t]
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

;

parameters GREU_data
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."

  Energybalance[ebalitems,transaction,d,es,e,t] "Main data input with regards to energy and energy-related emissions"
  NonEnergyEmissions[ebalitems,transaction,d,t] "Main data input with regards to non-energy related emissions"

  tpLE[es,e,t] ""
  tpCE[es,e,t] ""
  tpXE[es,e,t] ""

  tCO2_REmarg_load[es,e,i,t,em]
  tCO2_REmarg[em,es,e,i,t]
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
;



$gdxIn P:\akg\Til_EU_projekt\EU_GR_data.gdx
$load w, qL, nEmployed
$load es=purpose, out=out, e=energy19, pXEpj_base=pXE_base.l, pLEpj_base=pLE_base.l, pCEpj_base=pCE_base.l, pREpj_base=pRE_base.l, pE_avg=pEtot.l
$load tpLE=tLE.l, tpCE=tCE.l, tpXE=tXE_.l
$load qEtot=qEtot.l,  pY_CET = pY_CET.l, pM_CET=pM_CET.l, qY_CET=qY_CET.l, qM_CET=qM_CET.l
$load qRepj=qREgj.l, qCEpj=qCE.l, qLEpj=qLE.l, qXEpj=qXE.l,qTLpj=qTL.l
$load vEAV_RE=vEAV_RE.l, vDAV_RE=vDAV_RE.l, vCAV_RE=vCAV_RE.l, vEAV_CE=vEAV_CE.l, vDAV_CE=vDAV_CE.l, vCAV_CE= vCAV_CE.l
$load pL ,pK, qK, qRxE, pRxE
# $load em =emm_eq
$load em_accounts=accounts_all, land5
$load qEmmCE_load=qEmmConsE.l, qEmmCxE_load=qEmmConsxE.l, qEmmRE_load=qEmmProdE.l, qEmmRxE_load=qEmmProdxE.l, qEmmtot_load=qEmmtot.l, qEmmLULUCF=qEmmLULUCF.l, qEmmLULUCF5=qEmmLULUCF5.l, sBioNatGas=sBioNatGasAvgAdj.l
$load GWP=GWP.l
$load vtCO2_RE = vtCO2_RE.l, vtEAFG_RE = vtEAFG_RE.l, vtSO2_RE = vtSO2_RE.l, vtNOX_RE = vtNOX_RE.l, vtPSO_RE = vtPSO_RE.l, vtVAT_RE = vtVAT_RE.l
$load vtCO2_CE = vtCO2_CE.l, vtEAFG_CE = vtEAFG_CE.l, vtSO2_CE = vtSO2_CE.l, vtNOX_CE = vtNOX_CE.l, vtPSO_CE = vtPSO_CE.l, vtVAT_CE = vtVAT_CE.l
$load tCO2_REmarg_load = tCO2_REmarg.l
$load vtCO2_ETS = vtCO2_ETS.l, qCO2_ETS_freeallowances=qEmmProdE_dedETS.l
$load vtNetproductionRest=vtNetproductionRest.l
$load vtCAP_prodsubsidy=vtCAP_top.l
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

#Emissions
  qEmmCE[em,es,e,t]         = sum(c,Energybalance[em,'household_consumption',c,es,e,t]);
  qEmmCxE[em,t]             = NonEnergyEmissions[em,'household_consumption','cHouEne',t];

  qEmmRE[em,es,e,i,t]       = Energybalance[em,'input_in_production',i,es,e,t];
  qEmmRxE[em,i,t]           = NonEnergyEmissions[em,'input_in_production',i,t];
  qEmmtot[em,em_accounts,t] = qEmmTot_load[t,em,em_accounts];


#Taxes 
  vtRE_duty[etaxes,es,e,i,t]  = Energybalance[etaxes,'input_in_production',i,es,e,t];
  vtRE_vat[es,e,i,t]          = Energybalance['VAT','input_in_production',i,es,e,t];

  vtCE_duty[etaxes,es,e,t]    = Energybalance[etaxes,'household_consumption','cCarEne',es,e,t];
  vtCE_duty[etaxes,es,e,t]    = Energybalance[etaxes,'household_consumption','cHouEne',es,e,t];
  vtCE_vat[es,e,t]            = Energybalance['VAT','household_consumption','cCarEne',es,e,t];
  vtCE_vat[es,e,t]            = Energybalance['VAT','household_consumption','cHouEne',es,e,t];

  tCO2_REmarg[em,es,e,i,t]    = tCO2_REmarg_load[es,e,i,t,em];


execute_unloaddi "data", vWages_i, nL, es, out, e, pXEpj_base, pLEpj_base, pCEpj_base, pREpj_base, pE_avg, 
                        tpLE, tpCE, tpXE, 
                        qEtot, pE_avg, pY_CET, pM_CET, qY_CET, qM_CET,
                        qREpj, qCEpj, qLEpj, qXEpj, qTLpj
                        vEAV_RE = vEAV_RE.l, vDAV_RE = vDAV_RE.l, vCAV_RE = vCAV_RE.l, 
                        vEAV_CE = vEAV_CE.l, vDAV_CE = vDAV_CE.l, vCAV_CE = vCAV_CE.l, 
                        qProd, pProd,
                        em, em_accounts, land5, qEmmCE, qEmmCxE, qEmmRE, qEmmRxE, qEmmtot, qEmmLULUCF5, qEmmLULUCF, sBioNatGas,
                        c, x, k, g,
                        GWP,
                        vtRE_duty, vtRE_vat
                        vtCE_duty, vtCE_vat
                        tCO2_REmarg
                        vtCO2_RE
                        vtCO2_ETS, qCO2_ETS_freeallowances
                         vtNetproductionRest,
                         vtCAP_prodsubsidy;