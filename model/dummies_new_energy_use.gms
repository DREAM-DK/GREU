## DUMMIES FOR ENERGY PRICES
# Save energy related dummies from the CGE model
d1pEpj_base_CGE[es,e,d,t]        = d1pEpj_base[es,e,d,t];
d1pEpj_CGE[es,e,d,t]             = d1pEpj[es,e,d,t];
d1pEpj_marg_CGE[es,e,i,t]        = d1pEpj_marg[es,e,i,t];
d1pEpj_marg_inNest_CGE[es,e,i,t] = d1pEpj_marg_inNest[es,e,i,t];
d1tqEpj_CGE[es,e,d,t]            = d1tqEpj[es,e,d,t];
d1qEpj_CGE[es,e,d,t]             = d1qEpj[es,e,d,t];

d1no_energy_price[e]  = yes;
d1no_energy_price[e]$(sum((es,d,t), d1pEpj_base[es,e,d,t]) or sum((es,d,t), d1pEpj_own[es,e,d,t]) or sameas(e,'Captured CO2'))  = no;
# d1no_energy_price[e]$(sum((es,i,t), d1pEpj_marg[es,e,i,t]) or sameas(e,'Captured CO2'))  = no;

# DUMMIES FOR ENERGY PRICES AND QUANTITIES
# There is no base price for captured CO2, so we need to exclude it from d1pEpj_base
d1pEpj_base[es,e,d,t]$(d1pEpj_base[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not (d1no_energy_price(e) or sameas(e,'Captured CO2'))))            = yes;
d1pEpj[es,e,d,t]$(d1pEpj[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not d1no_energy_price(e)))                           = yes;
d1pEpj_marg[es,e,i,t]$(d1pEpj_marg[es,e,i,t] or (sum(l, d1uTE[l,es,e,i,t]) and not d1no_energy_price(e)))                 = yes;
d1pEpj_marg_inNest[es,e,i,t]$(d1pEpj_marg_inNest[es,e,i,t] or (sum(l, d1uTE[l,es,e,i,t]) and not d1no_energy_price(e)))   = yes;
# d1tqEpj is only updated for new energy use that is not priced in pEpj_base or pEpj_own
d1tqEpj[es,e,d,t]$(d1tqEpj[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not (d1no_energy_price(e) or sum((es_a,d_a), d1pEpj_base[es_a,e,d_a,t]) or sum((es_a,d_a), d1pEpj_own[es_a,e,d_a,t]))))                       = yes;
d1qEpj[es,e,d,t]$(d1qEpj[es,e,d,t] or (sum(l, d1uTE[l,es,e,d,t]) and not d1no_energy_price(e)))                           = yes;

# Save dummies containing only the new energy use in the technology model
d1pEpj_base_energy_technology[es,e,d,t]$(d1pEpj_base[es,e,d,t] and not d1pEpj_base_CGE[es,e,d,t])                      = yes;
d1pEpj_energy_technology[es,e,d,t]$(d1pEpj[es,e,d,t] and not d1pEpj_CGE[es,e,d,t])                                     = yes;
d1pEpj_marg_energy_technology[es,e,i,t]$(d1pEpj_marg[es,e,i,t] and not d1pEpj_marg_CGE[es,e,i,t])                      = yes;
d1pEpj_marg_inNest_energy_technology[es,e,i,t]$(d1pEpj_marg_inNest[es,e,i,t] and not d1pEpj_marg_inNest_CGE[es,e,i,t]) = yes;
d1tqEpj_energy_technology[es,e,d,t]$(d1tqEpj[es,e,d,t] and not d1tqEpj_CGE[es,e,d,t])                                  = yes;
d1qEpj_energy_technology[es,e,d,t]$(d1qEpj[es,e,d,t] and not d1qEpj_CGE[es,e,d,t])                                     = yes;

## DUMMIES FOR EMISSIONS (ONLY ON NEW ENERGY USE IN THE ENERGY TECHNOLOGY MODEL COMPARED TO CGE)
d1EmmE_BU_CGE[em,es,e,d,t] = d1EmmE_BU[em,es,e,d,t];
d1EmmE_BU[em,es,e,d,t]$((sameas[em,'CO2ubio'] or sameas[em,'CO2bio']) and d1pEpj_energy_technology[es,e,d,t] and sum((es_a,d_a,tt), d1EmmE_BU[em,es_a,e,d_a,tt]) and not sameas(e,'Captured CO2')) = yes;
d1EmmE_BU[em,es,e,d,t]$(sameas[em,'CO2ubio'] and d1pEpj_energy_technology[es,e,d,t] and sameas(e,'Captured CO2')) = yes; # Consider changing to sameas[em,'CCS']
d1EmmE_BU['CO2e',es,e,d,t]$(d1EmmE_BU['CO2ubio',es,e,d,t]) = yes; # Consider adding "or d1EmmE_BU['CCS',es,e,d,t]"
d1EmmE_BU_energy_technology[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t] and not d1EmmE_BU_CGE[em,es,e,d,t]) = yes;

## EMISSION COEFFICIENTS
uEmmE_BU_CGE[em,es,e,d,t] = uEmmE_BU.l[em,es,e,d,t];
uEmmE_BU.l[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_energy_technology[em,es,e,d,t] and not sameas[em,'CO2e'] and not sameas(e,'Captured CO2')) 
  = sum((es_a,d_a)$(d1EmmE_BU_CGE[em,es_a,e,d_a,t]), qEmmE_BU.l[em,es_a,e,d_a,t])
  / sum((es_a,d_a)$(d1EmmE_BU_CGE[em,es_a,e,d_a,t]), qEpj.l[es_a,e,d_a,t]);
uEmmE_BU.l[em,es,e,d,t]$(t.val>=t1.val and d1EmmE_BU_energy_technology[em,es,e,d,t] and not sameas[em,'CO2e'] and sameas(e,'Captured CO2')) = 1; 
uEmmE_BU_energy_technology[em,es,e,d,t]$(uEmmE_BU.l[em,es,e,d,t] and not uEmmE_BU_CGE[em,es,e,d,t]) = uEmmE_BU.l[em,es,e,d,t];

## DOMESTIC CARBON TAX
d1tCO2_E_CGE[em,es,e,d,t]      = d1tCO2_E[em,es,e,d,t];
d1tCO2_E[em,es,e,d,t]$(d1EmmE_BU_energy_technology[em,es,e,d,t] and not sameas[em,'CO2e'] and sum((ee), d1tCO2_E_CGE[em,es,ee,d,t])) = yes;
d1tCO2_E[em,es,e,d,t]$(d1EmmE_BU_energy_technology[em,es,e,d,t] and not sameas[em,'CO2e'] and sameas(e,'Captured CO2')) = yes;
d1tCO2_E_energy_technology[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t] and not d1tCO2_E_CGE[em,es,e,d,t]) = yes;

tCO2_Emarg_CGE[em,es,e,i,t] = tCO2_Emarg.l[em,es,e,i,t];
tCO2_Emarg.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_E_energy_technology[em,es,e,i,t] and sum(ee, d1tCO2_E_CGE[em,es,ee,i,t]) and sum(ee$(d1pEpj_CGE[es,ee,i,t]), qEpj.l[es,ee,i,t])) 
  = sum(ee$(d1pEpj_CGE[es,ee,i,t] and sum(em_a, d1tCO2_E_CGE[em_a,es,ee,i,t])), tCO2_Emarg_CGE[em,es,ee,i,t]*qEpj.l[es,ee,i,t])
  / sum(ee$(d1pEpj_CGE[es,ee,i,t] and sum(em_a, d1tCO2_E_CGE[em_a,es,ee,i,t])), qEpj.l[es,ee,i,t]);
tCO2_Emarg.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_E_energy_technology[em,es,e,i,t] and not sum(ee, d1tCO2_E_CGE[em,es,ee,i,t]) and sameas(e,'Captured CO2')) = 0.01;
tCO2_Emarg_energy_technology[em,es,e,i,t]$(tCO2_Emarg.l[em,es,e,i,t] and not tCO2_Emarg_CGE[em,es,e,i,t]) = tCO2_Emarg.l[em,es,e,i,t];

d1tE_duty_CGE[etaxes,es,e,d,t] = d1tE_duty[etaxes,es,e,d,t];
d1tE_duty[etaxes,es,e,d,t]$(sameas[etaxes,'co2_tax'] and sum(em, d1tCO2_E_energy_technology[em,es,e,d,t])) = yes;
d1tE_duty_energy_technology[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t] and not d1tE_duty_CGE[etaxes,es,e,d,t]) = yes;

## ETS1 ON NEW ENERGY USE IN QUOTA-COVERED PURPOSES
# Same coverage as the CGE dummy: CO2ubio, and CO2bio only for natural gas. Captured CO2 is not a combustion fuel.
d1tCO2_ETS_E_CGE[em,es,e,d,t] = d1tCO2_ETS_E[em,es,e,d,t];
d1tCO2_ETS_E[em,es,e,d,t]$(d1EmmE_BU_energy_technology[em,es,e,d,t] and CO2ubio[em] and in_ETS[es] and not sameas(e,'Captured CO2')) = yes;
d1tCO2_ETS_E[em,es,e,d,t]$(d1EmmE_BU_energy_technology[em,es,e,d,t] and CO2bio[em] and in_ETS[es] and natgas[e]) = yes;
d1tCO2_ETS_E_energy_technology[em,es,e,d,t]$(d1tCO2_ETS_E[em,es,e,d,t] and not d1tCO2_ETS_E_CGE[em,es,e,d,t]) = yes;

d1tCO2_ETS_CGE[i,t] = d1tCO2_ETS[i,t];
d1tCO2_ETS[i,t]$(sum((em,es,e), d1tCO2_ETS_E[em,es,e,i,t])) = yes;
d1tCO2_ETS_energy_technology[i,t]$(d1tCO2_ETS[i,t] and not d1tCO2_ETS_CGE[i,t]) = yes;

# Quota price per PJ. tCO2_ETS is the economy-wide price, already set in the tax module.
tCO2_ETS_pj.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_ETS_E_energy_technology[em,es,e,i,t] and not natgas[e])
  = tCO2_ETS.l[t]/10**6 * uEmmE_BU.l[em,es,e,i,t];
tCO2_ETS_pj.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_ETS_E_energy_technology[em,es,e,i,t] and natgas[e] and CO2bio[em])
  = tCO2_ETS.l[t]/10**6 * uEmmE_BU.l[em,es,e,i,t] * sBioNatGas.l[t];
tCO2_ETS_pj.l[em,es,e,i,t]$(t.val>=t1.val and d1tCO2_ETS_E_energy_technology[em,es,e,i,t] and natgas[e] and CO2ubio[em])
  = tCO2_ETS.l[t]/10**6 * uEmmE_BU.l[em,es,e,i,t] * (1-sBioNatGas.l[t]);

## ETS2 ON NEW ENERGY USE OUTSIDE THE QUOTA SECTOR, FROM 2028
d1tCO2_ETS2_E_CGE[em,es,e,d,t] = d1tCO2_ETS2_E[em,es,e,d,t];
d1tCO2_ETS2_E[em,es,e,d,t]$(t.val>=2028 and d1EmmE_BU_energy_technology[em,es,e,d,t] and CO2ubio[em] and not in_ETS[es] and tCO2_ETS2.l[t] and not sameas(e,'Captured CO2')) = yes;
d1tCO2_ETS2_E[em,es,e,d,t]$(t.val>=2028 and d1EmmE_BU_energy_technology[em,es,e,d,t] and CO2bio[em] and not in_ETS[es] and natgas[e] and tCO2_ETS2.l[t]) = yes;
d1tCO2_ETS2_E_energy_technology[em,es,e,d,t]$(d1tCO2_ETS2_E[em,es,e,d,t] and not d1tCO2_ETS2_E_CGE[em,es,e,d,t]) = yes;

d1tCO2_ETS2_CGE[d,t] = d1tCO2_ETS2[d,t];
d1tCO2_ETS2[d,t]$(t.val>=2028 and sum((em,es,e), d1tCO2_ETS2_E[em,es,e,d,t])) = yes;
d1tCO2_ETS2_energy_technology[d,t]$(d1tCO2_ETS2[d,t] and not d1tCO2_ETS2_CGE[d,t]) = yes;

# Quota price per PJ. tCO2_ETS2 is the economy-wide price, already set in the tax module.
tCO2_ETS2_pj.l[em,es,e,d,t]$(t.val>=2028 and d1tCO2_ETS2_E_energy_technology[em,es,e,d,t] and not natgas[e])
  = tCO2_ETS2.l[t]/10**6 * uEmmE_BU.l[em,es,e,d,t];
tCO2_ETS2_pj.l[em,es,e,d,t]$(t.val>=2028 and d1tCO2_ETS2_E_energy_technology[em,es,e,d,t] and natgas[e] and CO2bio[em])
  = tCO2_ETS2.l[t]/10**6 * uEmmE_BU.l[em,es,e,d,t] * sBioNatGas.l[t];
tCO2_ETS2_pj.l[em,es,e,d,t]$(t.val>=2028 and d1tCO2_ETS2_E_energy_technology[em,es,e,d,t] and natgas[e] and CO2ubio[em])
  = tCO2_ETS2.l[t]/10**6 * uEmmE_BU.l[em,es,e,d,t] * (1-sBioNatGas.l[t]);

execute_unload 'Output/pre_exists_dummies.gdx';
@update_exist_dummies()

# A random initial value for the new energy use
pEpj_marg.l[es,e,i,t]$(d1pEpj_marg_energy_technology[es,e,i,t]) = 1;

# vtE_duty.l[CO2_tax,es,'Captured CO2',d,t] = 0;
execute_unload 'Output/exists_dummies.gdx';