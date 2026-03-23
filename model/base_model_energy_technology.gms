# First the base model is included and executed
$IMPORT base_model.gms

# ------------------------------------------------------------------------------
# Run the energy technology choice model integrated with the CGE-model
# ------------------------------------------------------------------------------
# We turn the energy technology model on to integrate it with the CGE-model
d1switch_energy_technology[t] = 1;
d1switch_integrate_energy_technology[t] = 1;

# Get starting values for the energy technology model
$import pre_models_energy_technology.gms 
$import initial_values_energy_technology.gms;

# Solve partial energy technology model
# $FIX all_variables; $UNFIX energy_technology_partial_endogenous;
# Solve energy_technology_partial_equations using CNS;

# Solve full model
$FIX all_variables; $UNFIX calibration_endogenous;
# execute_unload 'Output/pre_calibration_energy_technology.gdx';
solve calibration using CNS;
execute_unload 'Output/calibration_energy_technology.gdx';

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