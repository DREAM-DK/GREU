set t "Time periods." / 1980*2099/;
set i "Production industries.";
set d "Demand components.";
set out "All product types produced by industries, including energy and margins";
set ene[out] "Energy products produced by industries";
set pps "End-purpose of energy";

variables
  w[t]
  qL[i,t]
  nEmployed[t]
 
;

parameters GREU_data
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."
  pXEpj_base[pps,ene,t] ""
  pLEpj_base[pps,ene,t] ""
  pCEpj_base[pps,ene,t] ""
  pREpj_base[pps,ene,i,t] ""

  tpRE[pps,ene,i,t] ""
  tqRE[pps,ene,i,t] ""
  tpLE[pps,ene,t] ""
  tpCE[pps,ene,t] ""
  tpXE[pps,ene,t] ""

  qEtot[ene,t] ""
  pE_avg[ene,t] ""
  pY_CET[out,i,t] ""
  pM_CET[out,i,t] ""  
  qY_CET[out,i,t] ""
  qM_CET[out,i,t] ""

  qREpj[pps,ene,i,t]
  qCEpj[pps,ene,t]
  qLEpj[pps,ene,t]
  qXEpj[pps,ene,t]
  qTLpj[pps,ene,t]

  vEAV_RE[pps,ene,i,t]
  vDAV_RE[pps,ene,i,t]
  vCAV_RE[pps,ene,i,t]

  vEAV_CE[pps,ene,t]
  vDAV_CE[pps,ene,t]
  vCAV_CE[pps,ene,t]



;

$gdxIn EU_GR_data.gdx
$load i=s, w, qL, nEmployed
$load pps=purpose, out=out, ene=energy19, pXEpj_base=pXE_base.l, pLEpj_base=pLE_base.l, pCEpj_base=pCE_base.l, pREpj_base=pRE_base.l, pE_avg=pEtot.l
$load tpRE=tvRE.l, tqRE=tqRE.l, tpLE=tLE.l, tpCE=tCE.l, tpXE=tXE_.l
$load qEtot=qEtot.l,  pY_CET = pY_CET.l, pM_CET=pM_CET.l, qY_CET=qY_CET.l, qM_CET=qM_CET.l
$load qRepj=qREgj.l, qCEpj=qCE.l, qLEpj=qLE.l, qXEpj=qXE.l,qTLpj=qTL.l
$load vEAV_RE=vEAV_RE.l, vDAV_RE=vDAV_RE.l, vCAV_RE=vCAV_RE.l, vEAV_CE=vEAV_CE.l, vDAV_CE=vDAV_CE.l, vCAV_CE= vCAV_CE.l

$gdxIn

vWages_i[i,t] = w.l[t] * qL.l[i,t];
nL[t] = nEmployed.l[t];

execute_unloaddi "data", vWages_i, nL, pps, out, ene, pXEpj_base, pLEpj_base, pCEpj_base, pREpj_base, pE_avg, tpRE, tqRE, tpLE, tpCE, tpXE, qEtot, pE_avg, pY_CET, pM_CET, qY_CET, qM_CET,
                        qREpj, qCEpj, qLEpj, qXEpj, qTLpj
                        vEAV_RE = vEAV_RE.l, vDAV_RE = vDAV_RE.l, vCAV_RE = vCAV_RE.l, 
                        vEAV_CE = vEAV_CE.l, vDAV_CE = vDAV_CE.l, vCAV_CE = vCAV_CE.l;