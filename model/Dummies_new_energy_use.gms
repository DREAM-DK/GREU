set exclude_energy(e) /
  'Waste'
  'Waste oil'
  'Heat pumps'
  'Wood waste'
  'Straw for energy purposes'
  'Natural gas (Extraction)'
  'Renewable energy'
  'Liquid biofuels'
  # 'Captured CO2'
  /;

parameter
  d1pEpj_base_CGE[es,e,d,t]
  d1pEpj_CGE[es,e,d,t]
  d1pREa_CGE[es,e_a,i,t]
  d1pREa_inNest_CGE[es,e_a,i,t]
  d1tqEpj_CGE[es,e,d,t]
  d1qEpj_CGE[es,e,d,t]
  # d1tCO2_ETS2_E_CGE[em,es,e,d,t]
  d1EmmE_BU_CGE[em,es,e,d,t]
  uEmmE_BU_CGE[em,es,e,d,t]
  d1tCO2_E_CGE[em,es,e,d,t]
  tCO2_Emarg_CGE[em,es,e,i,t]
  d1tE_duty_CGE[etaxes,es,e,d,t]

  d1pEpj_base_abatement[es,e,d,t]
  d1pEpj_abatement[es,e,d,t]
  d1pREa_abatement[es,e_a,i,t]
  d1pREa_inNest_abatement[es,e_a,i,t]
  d1tqEpj_abatement[es,e,d,t]
  d1qEpj_abatement[es,e,d,t]
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
d1pREa_CGE[es,e_a,i,t]    = d1pREa[es,e_a,i,t];
d1pREa_inNest_CGE[es,e_a,i,t] = d1pREa_inNest[es,e_a,i,t];
d1tqEpj_CGE[es,e,d,t]     = d1tqEpj[es,e,d,t];
d1qEpj_CGE[es,e,d,t]      = d1qEpj[es,e,d,t];
# d1tCO2_ETS2_E_CGE[em,es,e,d,t] = d1tCO2_ETS2_E[em,es,e,d,t];


d1pEpj_base[es,e,d,t]$(d1pEpj_base[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not (exclude_energy(e) or sameas(e,'Captured CO2'))))            = yes;
d1pEpj[es,e,d,t]$(d1pEpj[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not exclude_energy(e)))                            = yes;
d1pREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t] or (sum(l, d1uTE[l,es,e_a,i,t]) and sameas(e_a,'Captured CO2')))                 = yes;
d1pREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t] or (sum(l, d1uTE[l,es,e_a,i,t]) and not exclude_energy(e_a)))                    = yes;
d1pREa_inNest[es,e_a,i,t]$(d1pREa_inNest[es,e_a,i,t] or (sum(l, d1uTE[l,es,e_a,i,t]) and sameas(e_a,'Captured CO2')))   = yes;
d1pREa_inNest[es,e_a,i,t]$(d1pREa_inNest[es,e_a,i,t] or (sum(l, d1uTE[l,es,e_a,i,t]) and not exclude_energy(e_a)))      = yes;
d1tqEpj[es,e,d,t]$(d1tqEpj[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and sameas(e,'Captured CO2')))                       = yes;
d1qEpj[es,e,d,t]$(d1qEpj[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and sameas(e,'Captured CO2')))                         = yes;
# d1tCO2_ETS2_E[em,es,e,d,t]$(d1tCO2_ETS2_E[em,es,e,d,t] or (d1pEpj[es,e,d,t] and CO2ubio[em] and not in_ETS[es] and not sameas[e,'waste']))   = yes;
d1pEpj_base_abatement[es,e,d,t]$(d1pEpj_base[es,e,d,t] and not d1pEpj_base_CGE[es,e,d,t]) = yes;
d1pEpj_abatement[es,e,d,t]$(d1pEpj[es,e,d,t] and not d1pEpj_CGE[es,e,d,t])                = yes;
d1pREa_abatement[es,e_a,i,t]$(d1pREa[es,e_a,i,t] and not d1pREa_CGE[es,e_a,i,t])          = yes;
d1pREa_inNest_abatement[es,e_a,i,t]$(d1pREa_inNest[es,e_a,i,t] and not d1pREa_inNest_CGE[es,e_a,i,t]) = yes;
d1tqEpj_abatement[es,e,d,t]$(d1tqEpj[es,e,d,t] and not d1tqEpj_CGE[es,e,d,t])             = yes;
d1qEpj_abatement[es,e,d,t]$(d1qEpj[es,e,d,t] and not d1qEpj_CGE[es,e,d,t])             = yes;
# d1tCO2_ETS2_E_abatement[em,es,e,d,t]$(d1tCO2_ETS2_E[em,es,e,d,t] and not d1tCO2_ETS2_E_CGE[em,es,e,d,t]) = yes;

## DUMMIES FOR EMISSIONS (ONLY ON NEW ENERGY USE IN THE ABATEMENT MODEL COMPARED TO CGE)
d1EmmE_BU_CGE[em,es,e,d,t] = d1EmmE_BU[em,es,e,d,t];
d1EmmE_BU[em,es,e,d,t]$((sameas[em,'CO2ubio'] or sameas[em,'CO2bio']) and d1pEpj_abatement[es,e,d,t] and sum((es_a,d_a,tt), d1EmmE_BU[em,es_a,e,d_a,tt]) and not sameas(e,'Captured CO2')) = yes;
d1EmmE_BU[em,es,e,d,t]$(sameas[em,'CO2ubio'] and d1pEpj_abatement[es,e,d,t] and sameas(e,'Captured CO2')) = yes; # LBS: Change to sameas[em,'CCS']
d1EmmE_BU['CO2e',es,e,d,t]$(d1EmmE_BU['CO2ubio',es,e,d,t]) = yes; # LBS: Add "or d1EmmE_BU['CCS',es,e,d,t]"
d1EmmE_BU_abatement[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t] and not d1EmmE_BU_CGE[em,es,e,d,t]) = yes;

## EMISSION COEFFICIENTS
uEmmE_BU_CGE[em,es,e,d,t] = uEmmE_BU.l[em,es,e,d,t];
uEmmE_BU.l[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_abatement[em,es,e,d,t] and not sameas[em,'CO2e'] and not sameas(e,'Captured CO2')) 
  = sum((es_a,d_a)$(d1EmmE_BU_CGE[em,es_a,e,d_a,t]), qEmmE_BU.l[em,es_a,e,d_a,t])
  / sum((es_a,d_a)$(d1EmmE_BU_CGE[em,es_a,e,d_a,t]), qEpj.l[es_a,e,d_a,t]);
uEmmE_BU.l[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_abatement[em,es,e,d,t] and not sameas[em,'CO2e'] and sameas(e,'Captured CO2')) = 1; 
uEmmE_BU_abatement[em,es,e,d,t]$(uEmmE_BU.l[em,es,e,d,t] and not uEmmE_BU_CGE[em,es,e,d,t]) = uEmmE_BU.l[em,es,e,d,t];

## DOMESTIC CARBON TAX
d1tCO2_E_CGE[em,es,e,d,t]      = d1tCO2_E[em,es,e,d,t];
d1tCO2_E[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_abatement[em,es,e,d,t] and not sameas[em,'CO2e'] and sum((ee), d1tCO2_E_CGE[em,es,ee,d,t])) = yes;
d1tCO2_E[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_abatement[em,es,e,d,t] and not sameas[em,'CO2e'] and sameas(e,'Captured CO2')) = yes;
d1tCO2_E_abatement[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t] and not d1tCO2_E_CGE[em,es,e,d,t]) = yes;

tCO2_Emarg_CGE[em,es,e,i,t] = tCO2_Emarg.l[em,es,e,i,t];
tCO2_Emarg.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_E_abatement[em,es,e,i,t] and sum(ee, d1tCO2_E_CGE[em,es,ee,i,t]) and sum(ee$(d1pEpj_CGE[es,ee,i,t]), qEpj.l[es,ee,i,t])) 
  = sum(ee$(d1pEpj_CGE[es,ee,i,t] and sum(em_a, d1tCO2_E_CGE[em_a,es,ee,i,t])), tCO2_Emarg_CGE[em,es,ee,i,t]*qEpj.l[es,ee,i,t])
  / sum(ee$(d1pEpj_CGE[es,ee,i,t] and sum(em_a, d1tCO2_E_CGE[em_a,es,ee,i,t])), qEpj.l[es,ee,i,t]);
tCO2_Emarg.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_E_abatement[em,es,e,i,t] and not sum(ee, d1tCO2_E_CGE[em,es,ee,i,t]) and sameas(e,'Captured CO2')) = 0.01;
tCO2_Emarg_abatement[em,es,e,i,t]$(tCO2_Emarg.l[em,es,e,i,t] and not tCO2_Emarg_CGE[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];

d1tE_duty_CGE[etaxes,es,e,d,t] = d1tE_duty[etaxes,es,e,d,t];
d1tE_duty[etaxes,es,e,d,t]$(sameas[etaxes,'co2_tax'] and sum(em, d1tCO2_E_abatement[em,es,e,d,t])) = yes;
d1tE_duty_abatement[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t] and not d1tE_duty_CGE[etaxes,es,e,d,t]) = yes;

@update_exist_dummies()

# A random initial value for the new energy use
pREa.l[es,e_a,i,t]$(d1pREa_abatement[es,e_a,i,t]) = 1;

# vtE_duty.l[CO2_tax,es,'Captured CO2',d,t] = 0;