set t "Time periods." / 1980*2019/;
set i "Production industries.";
set d "Demand components.";

variables
  w[t]
  qL[i,t]
  nEmployed[t]
;

parameters GREU_data
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."
;

$gdxIn EU_GR_data.gdx
$load i=s, w, qL, nEmployed
$gdxIn

vWages_i[i,t] = w.l[t] * qL.l[i,t];
nL[t] = nEmployed.l[t];

execute_unloaddi "data", vWages_i, nL;