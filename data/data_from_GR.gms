set t "Time periods." / 1980*2099/;
set i "Production industries.";
set k "Capital types" /im,it,ib/ ;
set d "Demand components.";
set out "All product types produced by industries, including ergy and margins";
set e[out] "ergy products produced by industries";
set es "ergy-service";

set factors_of_production /
  "labor"
  RxE #Non-ergy input
  set.k, # Types of capital
  machine_ergy
  transport_ergy
  heating_ergy

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


;

$gdxIn P:\akg\Til_EU_projekt\EU_GR_data.gdx
$load i=s, w, qL, nEmployed
$load es=purpose, out=out, e=energy19, pXEpj_base=pXE_base.l, pLEpj_base=pLE_base.l, pCEpj_base=pCE_base.l, pREpj_base=pRE_base.l, pE_avg=pEtot.l, pREpj = pREgj.l
$load tpRE=tvRE.l, tqRE=tqRE.l, tpLE=tLE.l, tpCE=tCE.l, tpXE=tXE_.l
$load qEtot=qEtot.l,  pY_CET = pY_CET.l, pM_CET=pM_CET.l, qY_CET=qY_CET.l, qM_CET=qM_CET.l
$load qRepj=qREgj.l, qCEpj=qCE.l, qLEpj=qLE.l, qXEpj=qXE.l,qTLpj=qTL.l
$load vEAV_RE=vEAV_RE.l, vDAV_RE=vDAV_RE.l, vCAV_RE=vCAV_RE.l, vEAV_CE=vEAV_CE.l, vDAV_CE=vDAV_CE.l, vCAV_CE= vCAV_CE.l
$load pL ,pK, qK, qRxE, pRxE
$gdxIn 

vWages_i[i,t] = w.l[t] * qL.l[i,t];
nL[t] = nEmployed.l[t];

qProd['RxE',i,t]                 = qRxE.l[i,t];
qProd['labor',i,t]               = qL.l[i,t];
qProd['im',i,t]                  = qK.l['im',i,t];
qProd['it',i,t]                  = qK.l['it',i,t];
qProd['ib',i,t]                  = qK.l['ib',i,t];
qProd['machine_ergy',i,t]      = sum((es,e)$(not (sameas[es,'Heating'] or sameas[es,'Transport'])), pREpj[es,e,i,t]*qREpj[es,e,i,t]);
qProd['transport_ergy',i,t]    = sum((es,e)$(sameas[es,'Transport']), pREpj[es,e,i,t]*qREpj[es,e,i,t]);
qProd['heating_ergy',i,t]      = sum((es,e)$(sameas[es,'heating']), pREpj[es,e,i,t]*qREpj[es,e,i,t]);
pProd[factors_of_production,i,t] = 1;


execute_unloaddi "data", vWages_i, nL, es, out, e, pXEpj_base, pLEpj_base, pCEpj_base, pREpj_base, pE_avg, tpRE, tqRE, tpLE, tpCE, tpXE, qEtot, pE_avg, pY_CET, pM_CET, qY_CET, qM_CET,
                        qREpj, qCEpj, qLEpj, qXEpj, qTLpj
                        vEAV_RE = vEAV_RE.l, vDAV_RE = vDAV_RE.l, vCAV_RE = vCAV_RE.l, 
                        vEAV_CE = vEAV_CE.l, vDAV_CE = vDAV_CE.l, vCAV_CE = vCAV_CE.l, k,
                        qProd, pProd;