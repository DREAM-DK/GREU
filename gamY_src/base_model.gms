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
$IMPORT growth_adjustments.gms

set_time_periods(%first_data_year%, %terminal_year%);

$GROUP price_variables empty_group_dummy[t];
$GROUP quantity_variables empty_group_dummy[t];
$GROUP value_variables empty_group_dummy[t];
$GROUP other_variables empty_group_dummy[t];

$IMPORT input_output.gms

@inf_growth_adjust()

$GROUP all_variables
  price_variables
  quantity_variables
  other_variables
;

$GROUP data_covered_variables # Variables that are covered by data
  io_data_variables
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

  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;

$GROUP calibration_endogenous
  input_output_calibration_endogenous
  -nonexisting
;

$FIX all_variables, -calibration_endogenous;

$LOOP calibration_endogenous: # Set starting values for endogenous variables to 1 if no other value is given
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 1;
$ENDLOOP

solve calibration_model using CNS;

execute_unloaddi "calibration.gdx";

@assert_no_difference(data_covered_variables, 1e-6, _data, .l, "Calibration changed variables covered by data.")