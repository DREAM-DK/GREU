# First the base model is included and executed
$IMPORT base_model.gms


# ------------------------------------------------------------------------------
# Run the abatement model alongside the CGE-model (no integration)
# ------------------------------------------------------------------------------
# We turn the abatement model on to integrate it with the CGE-model
d1switch_abatement[t] = 1;
d1switch_integrate_abatement[t] = 0;

# Import new dummy data for the abatement model (For the moment it is just a CCS technology in 10030)
# $import Import_abatement_dummy_data.gms;
# execute_unload 'update_dummy.gdx';

# Set share parameters
uES.l[es,i,t]$(qES.l[es,i,t] and qREes.l[es,i,t]) = qES.l[es,i,t]/qREes.l[es,i,t];
jpTK.l[i,t]$(d1pTK[i,t] and d1K_k_i['iM',i,t]) = pTK.l[i,t]/pK_k_i.l['iM',i,t];

# Supply Curve Visualization
$import premodel_abatement.gms
$import energy_price_partial.gms
$import Supply_curves_abatement.gms;

# Solve partial abatement model
@add_exist_dummies_to_model(abatement_partial_equations);
# $FIX all_variables;
# $UNFIX abatement_partial_endogenous;
# # @Setbounds_abatement();
# Solve abatement_partial_equations using CNS;

@add_exist_dummies_to_model(main);
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_abatement.gdx';
# $exit
# ------------------------------------------------------------------------------
# Integrate the abatement model with the CGE-model
# ------------------------------------------------------------------------------
# We turn the abatement model on to integrate it with the CGE-model
d1switch_abatement[t] = 1;
d1switch_integrate_abatement[t] = 1;

# Create baseline values for the abatement model
$import create_baseline_values.gms;

$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_abatement_integrated.gdx';

# We switch jqESE and uREa when starting to shock the model (could be made more elegant)
$GROUP main_endogenous
  main_endogenous
  uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), -jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
;

# qREa.l[es,e_a,i,t]$(sameas(e_a,'Captured CO2')) = qESE.l[es,e_a,i,t];
# jqESE.l[es,e_a,i,t]$(sameas(e_a,'Captured CO2')) = 0;

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
  $FIX all_variables;
  $UNFIX abatement_partial_endogenous;
  # @Setbounds_abatement();
  Solve abatement_partial_equations using CNS;

  execute_unload 'Output\calibration_capital_costs_abatement_partial.gdx';

# Solve model
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_capital_costs.gdx';

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %test_abatement%:

@import_from_modules("tests")
# Data check  -  Abort if any data covered variables have been changed by the calibration
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

# Zero shock  -  Abort if a zero shock changes any variables significantly
@set(all_variables, _saved, .l)
$FIX all_variables; $UNFIX main_endogenous;
execute_unload 'Output\main_pre.gdx';
Solve main using CNS;
@assert_no_difference(all_variables, 1e-6, .l, _saved, "Zero shock changed variables significantly.");
execute_unload 'Output\main_abatement.gdx';
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

$ENDIF # test_abatement