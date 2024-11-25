set t "Time periods." / 1980*2099/;
set i "Production industries.";
set d "Demand components.";
set k "Capital types" /im,it,ib/ ;
set c "Consumption categories; ";
set g "Public consumption categories";
set x "Export types";

set out "All product types produced by industries, including ergy and margins";
set e[out] "ergy products produced by industries";
set es "Energy-service";
set em "Emissiontype" ;
set em_accounts "Different accounting levels of emissions inventories";
set land5 "Five aggregate land-use categories";

set l "Technologies";

set factors_of_production /
  "labor"
  RxE #Non-ergy input
  set.k, # Types of capital
  machine_energy
  transport_energy
  heating_energy

  refinery_crudeoil
  naturalgas_for_distribution
  biogas_for_processing

/;
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

parameters GREU_data
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."
  pXEpj_base[es,e,t] ""
  pLEpj_base[es,e,t] ""
  pCEpj_base[es,e,t] ""
  pREpj_base[es,e,i,t] ""

  pREpj[es,e,i,t] ""

  tpRE[es,e,i,t] ""
  tqRE[es,e,i,t] ""
  tpLE[es,e,t] ""
  tpCE[es,e,t] ""
  tpXE[es,e,t] ""

  qEtot[e,t] ""
  pE_avg[e,t] ""
  pY_CET[out,i,t] ""
  pM_CET[out,i,t] ""  
  qY_CET[out,i,t] ""
  qM_CET[out,i,t] ""

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

  qProd[factors_of_production,i,t]
  pProd[factors_of_production,i,t]

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

  qEmmLULUCF5[land5,t]
  qEmmLULUCF[t] 
  sBioNatGas[t]

  GWP[em]

  # Abatement
  theta_load[l,es,i,e,t] "Potential, technology."
  uTE_load[l,es,i,e,t] "Energy use, technology."
  uTK_load[l,es,i,e,t] "Capital use, technology."

  theta[l,es,i,t] "Potential, technology."
  uTE[l,es,e,i,t] "Energy use, technology."
  uTK[l,es,i,t] "Capital use, technology."
;

$gdxIn C:\Users\b165541\Documents\Modeller\EU\Fra_Asbjorn\EU_GR_data.gdx
$load i=s, w, qL, nEmployed
$load es=purpose, out=out, e=energy19, pXEpj_base=pXE_base.l, pLEpj_base=pLE_base.l, pCEpj_base=pCE_base.l, pREpj_base=pRE_base.l, pE_avg=pEtot.l, pREpj = pREgj.l
$load tpRE=tvRE.l, tqRE=tqRE.l, tpLE=tLE.l, tpCE=tCE.l, tpXE=tXE_.l
$load qEtot=qEtot.l,  pY_CET = pY_CET.l, pM_CET=pM_CET.l, qY_CET=qY_CET.l, qM_CET=qM_CET.l
$load qRepj=qREgj.l, qCEpj=qCE.l, qLEpj=qLE.l, qXEpj=qXE.l,qTLpj=qTL.l
$load vEAV_RE=vEAV_RE.l, vDAV_RE=vDAV_RE.l, vCAV_RE=vCAV_RE.l, vEAV_CE=vEAV_CE.l, vDAV_CE=vDAV_CE.l, vCAV_CE= vCAV_CE.l
$load pL ,pK, qK, qRxE, pRxE
$load em =emm_eq, em_accounts=accounts_all, land5
$load qEmmCE_load=qEmmConsE.l, qEmmCxE_load=qEmmConsxE.l, qEmmRE_load=qEmmProdE.l, qEmmRxE_load=qEmmProdxE.l, qEmmtot_load=qEmmtot.l, qEmmLULUCF=qEmmLULUCF.l, qEmmLULUCF5=qEmmLULUCF5.l, sBioNatGas=sBioNatGasAvgAdj.l
$load c, x, g
$load GWP=GWP.l
$gdxIn 

$gdxIn EU_tech_data_disagg.gdx
$load l=l theta_load=theta.l, uTE_load=uTE.l, uTK_load=uTK.l
$gdxIn

vWages_i[i,t] = w.l[t] * qL.l[i,t];
nL[t] = nEmployed.l[t];

qProd['RxE',i,t]                 = qRxE.l[i,t];
qProd['labor',i,t]               = qL.l[i,t];
qProd['im',i,t]                  = qK.l['im',i,t];
qProd['it',i,t]                  = qK.l['it',i,t];
qProd['ib',i,t]                  = qK.l['ib',i,t];
qProd['machine_energy',i,t]      = sum((es,e)$(not (sameas[es,'Heating'] or sameas[es,'Transport'])), pREpj[es,e,i,t]*qREpj[es,e,i,t]);
qProd['transport_energy',i,t]    = sum((es,e)$(sameas[es,'Transport']), pREpj[es,e,i,t]*qREpj[es,e,i,t]);
qProd['heating_energy',i,t]      = sum((es,e)$(sameas[es,'heating']), pREpj[es,e,i,t]*qREpj[es,e,i,t]);
pProd[factors_of_production,i,t] = 1;

qEmmCE[em,es,e,t] = qEmmCE_load[t,em,es,e];
qEmmCxE[em,t] = qEmmCxE_load[t,em];
qEmmRE[em,es,e,i,t] = qEmmRE_load[i,t,em,es,e];
qEmmRxE[em,i,t] = qEmmRxE_load[i,t,em];
qEmmtot[em,em_accounts,t] = qEmmTot_load[t,em,em_accounts];

theta[l,es,i,t] = sum(e, theta_load[l,es,i,e,t]);
uTE[l,es,e,i,t] = uTE_load[l,es,i,e,t];
uTK[l,es,i,t] = sum(e, uTK_load[l,es,i,e,t]);

execute_unloaddi "data", vWages_i, nL, es, out, e, pXEpj_base, pLEpj_base, pCEpj_base, pREpj_base, pE_avg, tpRE, tqRE, tpLE, tpCE, tpXE, qEtot, pE_avg, pY_CET, pM_CET, qY_CET, qM_CET,
                        qREpj, qCEpj, qLEpj, qXEpj, qTLpj
                        vEAV_RE = vEAV_RE.l, vDAV_RE = vDAV_RE.l, vCAV_RE = vCAV_RE.l, 
                        vEAV_CE = vEAV_CE.l, vDAV_CE = vDAV_CE.l, vCAV_CE = vCAV_CE.l, 
                        qProd, pProd,
                        em, em_accounts, land5, qEmmCE, qEmmCxE, qEmmRE, qEmmRxE, qEmmtot, qEmmLULUCF5, qEmmLULUCF, sBioNatGas,
                        c, x, k, g,
                        GWP,
                        theta, uTE, uTK;