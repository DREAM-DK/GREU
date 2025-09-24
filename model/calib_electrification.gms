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
vTI.l[l,es,i,t]$(t.val > t1.val and t.val <= 2040 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
  = vTI.l[l,es,i,t] * 0.995**(t.val - t1.val);

# Operating costs decrease by 1 pct. per year
vTC.l[l,es,i,t]$(t.val > t1.val and t.val <= 2040 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
  = vTC.l[l,es,i,t]  * 0.995**(t.val - t1.val);

# Supply Curve Visualization
$import Supply_curves_abatement.gms;

# # Solve partial abatement model
# $FIX all_variables;
# $UNFIX abatement_partial_endogenous;
# Solve abatement_partial_equations using CNS;
# execute_unload 'Output\calibration_electrification_abatement_partial.gdx';

# Solve model
# @add_exist_dummies_to_model(main);
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_electrification.gdx';