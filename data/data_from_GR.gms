set t "Time periods." / 1980*2019/;
singleton set t1[t] /2019/;

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
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."

  vY_i_d[i,d,t] "Output by industry and demand component."
  vM_i_d[i,d,t] "Imports by industry and demand component."
  vYM_i_d[i,d,t] "Supply by industry and demand component."
  vtY_i_d[i,d,t] "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t] "Net duties on imports by industry and demand component."
  vtYM_i_d[i,d,t] "Net duties by industry and demand component."
;

vWages_i[i,t] = vIOxE_a["SalEmpl",i,t];
nL[t] = nEmployed.l[t];

vY_i_d[i,d,t] = vIOxE_y[i,d,t];
vM_i_d[i,d,t] = vIOxE_m[i,d,t];
vYM_i_d[i,d,t] = vY_i_d[i,d,t] + vM_i_d[i,d,t];
vtYM_i_d[i,d,t] = vIOxE_a["TaxSub",d,t] + vIOxE_a["Moms",d,t];
vtY_i_d[i,d,t]$(vYM_i_d[i,d,t] <> 0) = vtYM_i_d[i,d,t] * vY_i_d[i,d,t] / vYM_i_d[i,d,t];
vtM_i_d[i,d,t] = vtYM_i_d[i,d,t] - vtY_i_d[i,d,t];

execute_unloaddi "data",
  d, g, c, k, i, x, m
  vWages_i, nL
  vY_i_d, vM_i_d, vtY_i_d, vtM_i_d
;
