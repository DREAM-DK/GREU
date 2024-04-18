$IMPORT functions.gms;

OPTION
  SYSOUT=OFF
  SOLPRINT=OFF
  LIMROW=0
  LIMCOL=0
  DECIMALS=6
  PROFILE = 1
  PROFILETOL = 0.01

  CNS=CONOPT4  # Choose solver
;

$SETLOCAL first_data_year 2000;
$SETLOCAL terminal_year 2023;
$SETLOCAL base_year 2010;

$IMPORT sets.gms
set_time_periods(%first_data_year%, %terminal_year%);

$GROUP price_variables empty_group_dummy[t]$(0);
$GROUP quantity_variables empty_group_dummy[t]$(0);
$GROUP value_variables empty_group_dummy[t]$(0);
$GROUP other_variables empty_group_dummy[t]$(0);

$GROUP data_covered_variables empty_group_dummy[t]$(0);

$IMPORT growth_adjustments.gms

$IMPORT input_output.gms
$IMPORT aggregates.gms

@inf_growth_adjust()

$GROUP all_variables
  price_variables
  quantity_variables
  value_variables
  other_variables
;

# For each variable, create a dummy that is 1 if the variable exists for the combination of set elements
$LOOP all_variables:
  set {name}_exists_dummy{sets};
  {name}_exists_dummy{sets}$({conditions}) = yes;
$ENDLOOP

$GROUP nonexisting
  All, -all_variables
;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
set_time_periods(%first_data_year%+1, %terminal_year%);

@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration

model calibration_model /
  input_output_calibration_model
  aggregates_calibration_model

  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;

$GROUP calibration_endogenous
  input_output_calibration_endogenous
  aggregates_calibration_endogenous

  -nonexisting
;

$FIX all_variables, -calibration_endogenous;

$LOOP calibration_endogenous: # Set starting values for endogenous variables to 1 if no other value is given
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 1;
$ENDLOOP

solve calibration_model using CNS;

execute_unloaddi "calibration.gdx";

@assert_no_difference(data_covered_variables, 1e-6, _data, .l, "Calibration changed variables covered by data.")