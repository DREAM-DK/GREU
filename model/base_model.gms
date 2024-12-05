$onMulti # Allows adding to an already defined set or model with multiple "model" or "set" statements

$IMPORT functions.gms;
$IMPORT settings.gms

$IMPORT sets/time.sets.gms
$IMPORT sets/sectors.sets.gms
$IMPORT sets/input_output.sets.gms
$IMPORT sets/output.sets.gms
$IMPORT sets/production.sets.gms
$IMPORT sets/emissions.sets.gms
$IMPORT sets/energy_taxes_and_emissions.sets.gms

set_time_periods(%first_data_year%, %terminal_year%);

# ------------------------------------------------------------------------------
# Select modules
# ------------------------------------------------------------------------------
$FUNCTION import_from_modules(stage_key):
  $SETGLOBAL stage stage_key;
  $IMPORT submodel_template.gms
  $IMPORT financial_accounts.gms
  # $IMPORT test_module.gms
  $IMPORT labor_market.gms
  # $IMPORT energy_markets.gms; 
  # $IMPORT industries_CES_energydemand.gms; 
  $IMPORT production.gms; 
  $IMPORT pricing.gms; 
  $IMPORT imports.gms
  # $IMPORT production_CET.gms;
  # $IMPORT emissions.gms; 
  # $IMPORT energy_and_emissions_taxes.gms; 
  $IMPORT input_output.gms
  $IMPORT households.gms
  $IMPORT government.gms
  $IMPORT exports.gms
  $IMPORT factor_demand.gms
  # $IMPORT aggregates.gms
  # $IMPORT imports.gms
  $IMPORT perpetual_youth.gms
$ENDFUNCTION

# ------------------------------------------------------------------------------
# Define variables and dummies
# ------------------------------------------------------------------------------
# Group of all variables, identical to ALL group, except containing only elements that exist (not dummied out)
$Group all_variables ; # All variables in the model
$Group main_endogenous ;
$Group data_covered_variables ; # Variables that are covered by data
$Group G_flat_after_last_data_year ; # Variables that are extended with "flat forecast" after last data year
$SetGroup SG_flat_after_last_data_year ; # Dummies that are extended with "flat forecast" after last data year
@import_from_modules("variables")
$IMPORT variable_groups.gms
$IMPORT growth_adjustments.gms

# ------------------------------------------------------------------------------
# Define equations
# ------------------------------------------------------------------------------
model main;
model calibration;
@import_from_modules("equations")
@add_exist_dummies_to_model(main) # Limit the main model to only include elements that are not dummied out
main.optfile=1;

# ------------------------------------------------------------------------------
# Import data and set parameters
# ------------------------------------------------------------------------------
@import_from_modules("exogenous_values")
@inf_growth_adjust()
@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration
@update_exist_dummies()

# ------------------------------------------------------------------------------
# Calibrate model
# ------------------------------------------------------------------------------
$Group calibration_endogenous ;
@import_from_modules("calibration")
calibration.optfile=1;
$IMPORT calibration.gms

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
# $import sanitychecks.gms
@import_from_modules("tests")
# Data check  -  Abort if any data covered variables have been changed by the calibration
@assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.")

# Zero shock  -  Abort if a zero shock changes any variables significantly
@set(all_variables, _saved, .l)
$FIX all_variables; $UNFIX main_endogenous;
Solve main using CNS;
@assert_no_difference(all_variables, 1e-6, .l, _saved, "Zero shock changed variables significantly.");

# ------------------------------------------------------------------------------
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2020, %terminal_year%);

tY_i_d.l[i,re,t]$(t.val >= t1.val) = 0.01 + tY_i_d.l[i,re,t];


$FIX all_variables;
# $UNFIX main_endogenous, vHhTaxes2vGDP[t], -vNetFinAssets[Gov,t];
$UNFIX main_endogenous;
Solve main using CNS;
execute_unload 'shock.gdx';
