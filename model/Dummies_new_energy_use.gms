set exclude_energy(e) /
  'waste'
  'Heat pumps'
  'Captured CO2'
  /;

parameter
  d1pEpj_base_CGE[es,e,d,t]
  d1pEpj_CGE[es,e,d,t]
  # d1tCO2_ETS2_E_CGE[em,es,e,d,t]
  d1EmmE_BU_CGE[em,es,e,d,t]
  uEmmE_BU_CGE[em,es,e,d,t]
  d1tCO2_E_CGE[em,es,e,d,t]
  tCO2_Emarg_CGE[em,es,e,i,t]
  d1tE_duty_CGE[etaxes,es,e,d,t]

  d1pEpj_base_abatement[es,e,d,t]
  d1pEpj_abatement[es,e,d,t]
  # d1tCO2_ETS2_E_abatement[em,es,e,d,t]
  d1EmmE_BU_abatement[em,es,e,d,t]
  uEmmE_BU_abatement[em,es,e,d,t]
  d1tCO2_E_abatement[em,es,e,d,t]
  tCO2_Emarg_abatement[em,es,e,i,t]
  d1tE_duty_abatement[etaxes,es,e,d,t]
;


## DUMMIES FOR ENERGY PRICES
d1pEpj_base_CGE[es,e,d,t] = d1pEpj_base[es,e,d,t];
d1pEpj_CGE[es,e,d,t]      = d1pEpj[es,e,d,t];
# d1tCO2_ETS2_E_CGE[em,es,e,d,t] = d1tCO2_ETS2_E[em,es,e,d,t];


d1pEpj_base[es,e,d,t]$(d1pEpj_base[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not exclude_energy(e)))            = yes;
d1pEpj[es,e,d,t]$(d1pEpj[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not exclude_energy(e)))                      = yes;
# d1tCO2_ETS2_E[em,es,e,d,t]$(d1tCO2_ETS2_E[em,es,e,d,t] or (d1pEpj[es,e,d,t] and CO2ubio[em] and not in_ETS[es] and not sameas[e,'waste']))   = yes;
d1pEpj_base_abatement[es,e,d,t]$(d1pEpj_base[es,e,d,t] and not d1pEpj_base_CGE[es,e,d,t]) = yes;
d1pEpj_abatement[es,e,d,t]$(d1pEpj[es,e,d,t] and not d1pEpj_CGE[es,e,d,t]) = yes;
# d1tCO2_ETS2_E_abatement[em,es,e,d,t]$(d1tCO2_ETS2_E[em,es,e,d,t] and not d1tCO2_ETS2_E_CGE[em,es,e,d,t]) = yes;

## DUMMIES FOR EMISSIONS (ONLY ON NEW ENERGY USE IN THE ABATEMENT MODEL COMPARED TO CGE)
d1EmmE_BU_CGE[em,es,e,d,t] = d1EmmE_BU[em,es,e,d,t];
d1EmmE_BU[em,es,e,d,t]$((sameas[em,'CO2ubio'] or sameas[em,'CO2bio']) and d1pEpj_abatement[es,e,d,t] and sum((es_a,d_a,tt), d1EmmE_BU[em,es_a,e,d_a,tt])) = yes;
d1EmmE_BU['CO2e',es,e,d,t]$(d1EmmE_BU['CO2ubio',es,e,d,t]) = yes;
d1EmmE_BU_abatement[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t] and not d1EmmE_BU_CGE[em,es,e,d,t]) = yes;

## EMISSION COEFFICIENTS
uEmmE_BU_CGE[em,es,e,d,t] = uEmmE_BU.l[em,es,e,d,t];
uEmmE_BU.l[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_abatement[em,es,e,d,t] and not sameas[em,'CO2e']) = sum((es_a,d_a)$(d1EmmE_BU_CGE[em,es_a,e,d_a,t]), qEmmE_BU.l[em,es_a,e,d_a,t])
                                                                                                       / sum((es_a,d_a)$(d1EmmE_BU_CGE[em,es_a,e,d_a,t]), qEpj.l[es_a,e,d_a,t]);
uEmmE_BU_abatement[em,es,e,d,t]$(uEmmE_BU.l[em,es,e,d,t] and not uEmmE_BU_CGE[em,es,e,d,t]) = uEmmE_BU.l[em,es,e,d,t];

## DOMESTIC CARBON TAX
d1tCO2_E_CGE[em,es,e,d,t]      = d1tCO2_E[em,es,e,d,t];
d1tCO2_E[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_abatement[em,es,e,d,t] and not sameas[em,'CO2e'] and sum((ee), d1tCO2_E_CGE[em,es,ee,d,t])) = yes;
d1tCO2_E_abatement[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t] and not d1tCO2_E_CGE[em,es,e,d,t]) = yes;

tCO2_Emarg_CGE[em,es,e,i,t] = tCO2_Emarg.l[em,es,e,i,t];
tCO2_Emarg.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_E_abatement[em,es,e,i,t] and sum(ee$(d1pEpj_CGE[es,ee,i,t]), qEpj.l[es,ee,i,t])) 
  = sum(ee$(d1pEpj_CGE[es,ee,i,t] and sum(em_a, d1tCO2_E_CGE[em_a,es,ee,i,t])), tCO2_Emarg_CGE[em,es,ee,i,t]*qEpj.l[es,ee,i,t])
  / sum(ee$(d1pEpj_CGE[es,ee,i,t] and sum(em_a, d1tCO2_E_CGE[em_a,es,ee,i,t])), qEpj.l[es,ee,i,t]);
tCO2_Emarg_abatement[em,es,e,i,t]$(tCO2_Emarg.l[em,es,e,i,t] and not tCO2_Emarg_CGE[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];

d1tE_duty_CGE[etaxes,es,e,d,t] = d1tE_duty[etaxes,es,e,d,t];
d1tE_duty[etaxes,es,e,d,t]$(sameas[etaxes,'co2_tax'] and sum(em, d1tCO2_E_abatement[em,es,e,d,t])) = yes;
d1tE_duty_abatement[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t] and not d1tE_duty_CGE[etaxes,es,e,d,t]) = yes;

@update_exist_dummies()