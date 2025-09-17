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
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_CCS.gdx';