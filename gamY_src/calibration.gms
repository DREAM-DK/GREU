# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IMPORT settings.gms
$IMPORT base_model.gms

set_time_periods(%first_data_year%+1, %terminal_year%);

@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration

model calibration_model /
  input_output_calibration_model
  aggregates_calibration_model
  # households_calibration_model

  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;

$GROUP calibration_endogenous
  input_output_calibration_endogenous
  aggregates_calibration_endogenous
  # households_calibration_endogenous
;

$FIX all_variables, -calibration_endogenous;

$LOOP calibration_endogenous: # Set starting values for endogenous variables to 1 if no other value is given
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 1;
$ENDLOOP

solve calibration_model using CNS;

execute_unloaddi "calibration.gdx";

@assert_no_difference(data_covered_variables, 1e-6, _data, .l, "Calibration changed variables covered by data.")