# First the base model is included and executed
# $IMPORT base_model.gms # LBS ONLY COMMENTED OUT FOR NOW TO SAVE TIME


# ------------------------------------------------------------------------------
# Run the energy technology choice model alongside the CGE-model (no integration)
# ------------------------------------------------------------------------------
# We turn the energy technology choice model running alongside the CGE-model (no integration)
d1switch_energy_technology[t] = 1;
d1switch_integrate_energy_technology[t] = 0;

# Supply Curve Visualization
# Laver en energy-technology model med udvidede dimensioner. 
# Kan denne laves i et separat modul - måske i energy_technology.gms?
$import premodel_energy_technology.gms 

# execute_unload 'Output/pre_energy_price_partial.gdx';
$import Supply_curve_energy_technology.gms;

# Solve partial energy technology model
# I shock_CO2_tax.gms løses først en partiel model af energy_technology_partial_equations. 
# Jeg er ikke sikker på, om det er nødvendigt, men erfaringen siger, at det gør systemet mere robust.
# Den partielle model laves i energy_technology.gms
@add_exist_dummies_to_model(energy_technology_partial_equations);
# $FIX all_variables; $UNFIX energy_technology_partial_endogenous;
# Solve energy_technology_partial_equations using CNS;

# Solve the full calibration model
$FIX all_variables; $UNFIX calibration_endogenous;
# execute_unload 'Output/pre_calibration_energy_technology.gdx';
solve calibration using CNS;
# execute_unload 'Output/calibration_energy_technology.gdx';

# ------------------------------------------------------------------------------
# Integrate the energy technology choice model with the CGE-model
# ------------------------------------------------------------------------------
# We turn the energy technology model on to integrate it with the CGE-model
d1switch_energy_technology[t] = 1;
d1switch_integrate_energy_technology[t] = 1;

# Create baseline values for the energy technology model
# Lige nu er nogle af integrationsligningerne defineret som absolutte forskelle mellem shock og baseline.
$import create_baseline_values.gms;

$FIX all_variables; $UNFIX calibration_endogenous;
solve calibration using CNS;
execute_unload 'Output/calibration_energy_technology_integrated.gdx';

# We switch jqESE and uREa when starting to shock the model (could be made more elegant)
# Dette kan måske indgå i kalibreringsligninger?
$GROUP main_endogenous
  main_endogenous
  uREa$(d1qES_e[es,e_a,i,t] and d1pREa[es,e_a,i,t]), -jqESE$(d1qES_e[es,e,i,t] and d1pREa[es,e,i,t])
;

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %test_energy_technology%:

@import_from_modules("tests")
# Data check  -  Abort if any data covered variables have been changed by the calibration
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

# Zero shock  -  Abort if a zero shock changes any variables significantly
@set(all_variables, _saved, .l)
$FIX all_variables; $UNFIX main_endogenous;
# execute_unload 'Output/main_pre.gdx';
Solve main using CNS;
@assert_no_difference(all_variables, 1e-6, .l, _saved, "Zero shock changed variables significantly.");
execute_unload 'Output/main_energy_technology.gdx';
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

$ENDIF # test_energy_technology