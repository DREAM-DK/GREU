$onMulti # Allows adding to an already defined set or model with multiple "model" or "set" statements

$IMPORT functions.gms;
$IMPORT settings.gms

$IMPORT sets/time.sets.gms
$IMPORT sets/sectors.sets.gms
$IMPORT sets/input_output.sets.gms
$IMPORT sets/output.sets.gms
$IMPORT sets/production.sets.gms
$IMPORT sets/households.sets.gms
$IMPORT sets/emissions.sets.gms
$IMPORT sets/energy_taxes_and_emissions.sets.gms
$IMPORT sets/households.sets.gms

set_time_periods(%first_data_year%, %terminal_year%);

# ------------------------------------------------------------------------------
# Select modules
# ------------------------------------------------------------------------------
#The function import_from_modules adds modules to the model. 
#A zero in the second column means that the equations and endogenous variables of the module in question are neither 
#added to the calibration-model nor the main-model. Variables from these modules are however still initialized,
# and data is still loaded.
#A one in the second column means that the module will be added to both calibration-model and main-model.
#How the function works is explained in more detail in the GREU-manual.

$FUNCTION import_from_modules({stage_key}):
  $SET stage {stage_key};
  $FOR {module}, {include} in [
    ("submodel_template.gms", 1),
    ("emissions.gms" , 1),
    ("financial_accounts.gms", 1),
    ("labor_market.gms", 1),
    ("energy_markets.gms" , 1),
    ("energy_and_emissions_taxes.gms" , 1),
    ("non_energy_markets.gms", 1),
    ("production_CES_energydemand.gms", 1),
    ("production.gms" , 1),
    ("pricing.gms" , 1),
    ("imports.gms", 1),
    ("production_CET.gms", 1),
    ("input_output.gms", 1),
    ("households.gms", 1),
    ("government.gms", 1),
    ("exports.gms", 1),
    ("factor_demand.gms", 1),
    ("ramsey_household.gms", 1), 
    ("consumption_disaggregated.gms", 1), 
    ("consumption_disaggregated_energy.gms", 1), 
    ("exports_energy.gms", 1),
  ]:
    $IF {include} or {stage_key} not in ["equations", "calibration"]:
      $IMPORT {module}
    $ENDIF
  $ENDFOR
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
@import_from_modules("tests")
# Data check  -  Abort if any data covered variables have been changed by the calibration
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

# Zero shock  -  Abort if a zero shock changes any variables significantly
@set(all_variables, _saved, .l)
$FIX all_variables; $UNFIX main_endogenous;
execute_unload 'main_pre.gdx';
Solve main using CNS;
@assert_no_difference(all_variables, 1e-6, .l, _saved, "Zero shock changed variables significantly.");
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

# ------------------------------------------------------------------------------
# Shock model
# ------------------------------------------------------------------------------
set_time_periods(2020, %terminal_year%);

# tY_i_d.l[i,re,t]$(t.val >= t1.val) = 0.01 + tY_i_d.l[i,re,t];
tEmarg_duty.l['ener_tax',es,e,d,t]$(t.val > t1.val) = 2*tEmarg_duty.l['ener_tax',es,e,d,t]; #Doubling energy-taxes

$FIX all_variables;
$UNFIX main_endogenous;
Solve main using CNS;
execute_unload 'shock.gdx';
@import_from_modules("tests")

