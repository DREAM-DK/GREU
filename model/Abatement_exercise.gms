# ------------------------------------------------------------------------------
# Calibrate decreasing capital costs for electrification technologies
# ------------------------------------------------------------------------------
# Define the electrification technologies
set electrification_techs[l] /
  't26'
  't27'
  't28'
  't29'
  /;

# Investment costs decrease by 1 pct. per year
vTI.l[l,es,i,t]$(t.val > t1.val and t.val <= 2050 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
  = vTI.l[l,es,i,t] * 0.99**(t.val - t1.val);

# vTI.l[l,es,i,t]$(t.val > 2030 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
#   = vTI.l[l,es,i,'2030'];

# Operating costs decrease by 1 pct. per year
vTC.l[l,es,i,t]$(t.val > t1.val and t.val <= 2050 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
  = vTC.l[l,es,i,t]  * 0.99**(t.val - t1.val);

# vTC.l[l,es,i,t]$(t.val > 2030 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
#   = vTC.l[l,es,i,'2030'];

# Supply Curve Visualization
$import Supply_curves_abatement.gms;

# Solve partial abatement model
# $FIX all_variables;
# $UNFIX abatement_partial_endogenous;
# Solve abatement_partial_equations using CNS;
# execute_unload 'Output\calibration_capital_costs_abatement_partial.gdx';

# Solve model
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_capital_costs.gdx';

# ------------------------------------------------------------------------------
# Calibrate decreasing capital costs for CCS technologies
# ------------------------------------------------------------------------------

# Define the electrification technologies
# set CCS_techs[l] /
#   't30'
#   't31'
#   't32'
#   't33'
#   /;

# # Technology potentials
# sqTPotential.l['t30','process_special','23001',t]$(t.val > 2025) = sqTPotential_new.l['t1','process_special','23001',t];
# sqTPotential.l['t31','process_special','23001',t]$(t.val > 2025) = sqTPotential_new.l['t5','process_special','23001',t];
# sqTPotential.l['t32','process_special','23001',t]$(t.val > 2025) = sqTPotential_new.l['t6','process_special','23001',t];
# sqTPotential.l['t33','process_special','23001',t]$(t.val > 2025) = sqTPotential_new.l['t7','process_special','23001',t];

# # Investment costs
# vTI.l['t30','process_special','23001',t]$(t.val > 2025) = 1.65;
# vTI.l['t31','process_special','23001',t]$(t.val > 2025) = 1.725;
# vTI.l['t32','process_special','23001',t]$(t.val > 2025) = 1.8;
# vTI.l['t33','process_special','23001',t]$(t.val > 2025) = 1.875;

# # Operating costs
# vTC.l[CCS_techs,'process_special','23001',t]$(t.val > 2025) = vTI.l[CCS_techs,'process_special','23001',t]/10;

# # Energy input
# uTE.l[CCS_techs,'process_special',e,'23001',t]$(t.val > 2025) = uTE.l[CCS_techs,'process_special',e,'23001',t];
# uTE.l[CCS_techs,'process_special','Electricity','23001',t]$(t.val > 2025) = 0.1;
# uTE.l[CCS_techs,'process_special','Captured CO2','23001',t]$(t.val > 2025) = -84.1;

# # Life span
# LifeSpan[CCS_techs,'process_special','23001',t]$(t.val > 2025) = 5;

# # Set discount rate
# DiscountRate[CCS_techs,'process_special','23001'] = 0.05;

# # Set smoothing parameters
# eP.l[CCS_techs,'process_special','23001',t]$(sqTPotential.l[CCS_techs,'process_special','23001',t]) = eP.l['t1','process_special','23001',t];

# # Set dummy determining the existence of technology potentials
# d1sqTPotential[l,es,d,t] = yes$(sqTPotential.l[l,es,d,t]);
# d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
# d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));

# Define the electrification technologies
set CCS_techs[l] /
  't30'
  't31'
  't32'
  't33'
  /;

vTI.l[l,es,i,t]$(t.val > t1.val and t.val <= 2050 and d1sqTPotential[l,es,i,t] and CCS_techs[l])
  = vTI.l[l,es,i,t] * 0.75; 

vTC.l[l,es,i,t]$(t.val > t1.val and t.val <= 2050 and d1sqTPotential[l,es,i,t] and CCS_techs[l])
  = vTC.l[l,es,i,t] * 0.75;

# Supply Curve Visualization
$import Supply_curves_abatement.gms;

# # Solve partial abatement model
# $FIX all_variables;
# $UNFIX abatement_partial_endogenous;
# Solve abatement_partial_equations using CNS;
# execute_unload 'Output\calibration_CCS_abatement_partial.gdx';

# Solve model
# @add_exist_dummies_to_model(main);
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_CCS.gdx';