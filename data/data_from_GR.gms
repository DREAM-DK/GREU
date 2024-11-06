set t "Time periods." / 1980*2099/;
singleton set t1[t] /2019/;
set out "All product types produced by industries, including energy and margins";
set ene[out] "Energy products produced by industries";
set pps "End-purpose of energy";

sets
  a_rows_ "Other rows of the input-output table."

  government_consumption_types
  private_consumption_types
  capital_types
  production_industries
  export_types / xOth /
;
$gdxIn EU_GR_data_v02.gdx
$load a_rows_
$gdxIn

$gdxIn EU_GR_data.gdx
$load government_consumption_types=g, private_consumption_types=c, capital_types=k, production_industries=s
$gdxIn

set d "Demand components." /
  set.government_consumption_types
  set.private_consumption_types
  set.capital_types
  set.production_industries
  set.export_types
/;

set g[d] "Government consumption types." /
  set.government_consumption_types
/;
set c[d] "Private consumption types." /
  set.private_consumption_types
/;
set k[d] "Capital types." /
  set.capital_types
/;
set i[d] "Production industries." /
  set.production_industries
/;
set x[d] "Export types." /
  set.export_types
/;
set m[i] "Industries with imports.";

variables
  nEmployed[t]
 
;
$gdxIn EU_GR_data.gdx
$load nEmployed
$gdxIn

parameters
  vIOxE_y[i,d,t]
  vIOxE_m[i,d,t]
  vIOxE_a[a_rows_,d,t]
;
$gdxIn EU_GR_data_v02.gdx
$load vIOxE_y, vIOxE_m, vIOxE_a
$gdxIn

m[i] = yes$sum(d, vIOxE_m[i,d,t1]);

parameters GREU_data
  # Labor-market
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."

  # Input-output
  vY_i_d[i,d,t] "Output by industry and demand component."
  vM_i_d[i,d,t] "Imports by industry and demand component."
  vYM_i_d[i,d,t] "Supply by industry and demand component."
  vtY_i_d[i,d,t] "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t] "Net duties on imports by industry and demand component."
  vtYM_i_d[i,d,t] "Net duties by industry and demand component."

  # Energy
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
$load pps=purpose, out=out, ene=energy19, pXEpj_base=pXE_base.l, pLEpj_base=pLE_base.l, pCEpj_base=pCE_base.l, pREpj_base=pRE_base.l, pE_avg=pEtot.l
$load tpRE=tvRE.l, tqRE=tqRE.l, tpLE=tLE.l, tpCE=tCE.l, tpXE=tXE_.l
$load qEtot=qEtot.l,  pY_CET = pY_CET.l, pM_CET=pM_CET.l, qY_CET=qY_CET.l, qM_CET=qM_CET.l
$load qRepj=qREgj.l, qCEpj=qCE.l, qLEpj=qLE.l, qXEpj=qXE.l,qTLpj=qTL.l
$load vEAV_RE=vEAV_RE.l, vDAV_RE=vDAV_RE.l, vCAV_RE=vCAV_RE.l, vEAV_CE=vEAV_CE.l, vDAV_CE=vDAV_CE.l, vCAV_CE= vCAV_CE.l
$gdxIn

# Labor-market
nL[t] = nEmployed.l[t];
vWages_i[i,t] = vIOxE_a["SalEmpl",i,t];

# Input-output
vY_i_d[i,d,t] = vIOxE_y[i,d,t];
vM_i_d[i,d,t] = vIOxE_m[i,d,t];
vYM_i_d[i,d,t] = vY_i_d[i,d,t] + vM_i_d[i,d,t];
vtYM_i_d[i,d,t] = vIOxE_a["TaxSub",d,t] + vIOxE_a["Moms",d,t];
vtY_i_d[i,d,t]$(vYM_i_d[i,d,t] <> 0) = vtYM_i_d[i,d,t] * vY_i_d[i,d,t] / vYM_i_d[i,d,t];
vtM_i_d[i,d,t] = vtYM_i_d[i,d,t] - vtY_i_d[i,d,t];

execute_unloaddi "data",
  # Labor-market
  vWages_i, nL,
  
  # Input-output
  d, g, c, k, i, x, m,
  vY_i_d, vM_i_d, vtY_i_d, vtM_i_d,

  # Energy
  pps, out, ene,
  pXEpj_base, pLEpj_base, pCEpj_base, pREpj_base, pE_avg, tpRE, tqRE, tpLE, tpCE, tpXE, qEtot, pE_avg, pY_CET, pM_CET, qY_CET, qM_CET,
  qREpj, qCEpj, qLEpj, qXEpj, qTLpj,
  vEAV_RE = vEAV_RE.l, vDAV_RE = vDAV_RE.l, vCAV_RE = vCAV_RE.l, 
  vEAV_CE = vEAV_CE.l, vDAV_CE = vDAV_CE.l, vCAV_CE = vCAV_CE.l,
;