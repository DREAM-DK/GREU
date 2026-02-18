$onMulti # Allows adding to an already defined set or model with multiple "model" or "set" statements

# =============================================================================
# IMPORTS and initialization
# =============================================================================
$IMPORT settings.gms
$IMPORT functions.gms;
$IMPORT conditional_logic_config.gms

$IMPORT sets/time.sets.gms
$IMPORT sets/sectors.sets.gms
$IMPORT sets/input_output.sets.gms
$IMPORT sets/output.sets.gms
$IMPORT sets/production.sets.gms
$IMPORT sets/households.sets.gms
$IMPORT sets/emissions.sets.gms
$IMPORT sets/energy_taxes_and_emissions.sets.gms
$IMPORT sets/abatement.sets.gms
$IMPORT sets/subsets.sets.gms
$IMPORT sets/energy_outputs.sets.gms

set_time_periods(%first_data_year%, %terminal_year%);

# =============================================================================
# MODULE REGISTRATION FUNCTION
# =============================================================================
# This function imports modules at different stages of model construction
# - variables: Import variable declarations
# - equations: Import equation definitions  
# - calibration: Import calibration-specific logic
# - exogenous_values: Import exogenous data
# - tests: Import test procedures

#A zero in the second column means that the equations and endogenous variables of the module in question are neither 
#added to the calibration-model nor the main-model. Variables from these modules are however still initialized,
# and data is still loaded.
#A one in the second column means that the module will be added to both calibration-model and main-model.
#How the function works is explained in more detail in the GREU-manual.

$FUNCTION import_from_modules({stage_key}):
  $SET stage {stage_key};
  $FOR {module}, {include} in [
    ## CORE MODULES
    ("modules/submodel_template.gms", 1),
    ("modules/input_output.gms", 1),
    ("modules/labor_market.gms", 1),
    ("modules/factor_demand.gms", 1),
    ("modules/pricing.gms" , 1),
    ("modules/households.gms", 1),
    ("modules/financial_accounts.gms", 1),
    ("modules/government.gms", 1),
    ("modules/imports.gms", 1),
    ("modules/exports.gms", 1),

    ("modules/ramsey_household.gms", 1), 
    ("modules/consumption_disaggregated.gms", 1), 

    ## GREEN TRANSITION MODULES
    ("modules/emissions.gms" , 1),
    ("modules/energy_markets.gms" , 1),
    ("modules/energy_and_emissions_taxes.gms" , 1),
    ("modules/non_energy_markets.gms", 1),
    ("modules/production_CES_energydemand.gms", 1),
    ("modules/production.gms" , 1),
    ("modules/production_CET.gms", 1),
    ("modules/factor_demand_energy.gms", 1),
    ("modules/consumption_disaggregated_energy.gms", 1),
    ("modules/exports_energy.gms", 1),
    ("modules/abatement.gms", 1),

    ## REPORTING MODULES
    ("Report/All.Report.gms", 1),     
  ]:
    $IF {include} or {stage_key} in ["variables", "exogenous_values"]:
      $IMPORT {module}
    $ENDIF
  $ENDFOR
$ENDFUNCTION

# =============================================================================
# VARIABLE DEFINITIONS
# =============================================================================
# Group of all variables, identical to ALL group, except containing only elements that exist (not dummied out)
$Group all_variables ; # All variables in the model
$Group main_endogenous ;
$Group data_covered_variables ; # Variables that are covered by data
$Group G_flat_after_last_data_year ; # Variables that are extended with "flat forecast" after last data year
$Group G_zero_after_last_data_year ; # Variables that are set to zero after last data year
$Group G_zero_t1_after_static_calibration ; # Variables that are set to zero in t1 after static calibration
$SetGroup SG_flat_after_last_data_year ; # Dummies that are extended with "flat forecast" after last data year

@import_from_modules("variables")
$IMPORT variable_groups.gms
$IMPORT growth_adjustments.gms

# =============================================================================
# EQUATION DEFINITIONS
# =============================================================================
model main;
model calibration;
@import_from_modules("equations")
@add_exist_dummies_to_model(main) # Limit the main model to only include elements that are not dummied out
main.optfile=1;

@apply_exogenous_supply_prices_logic() # Apply conditional model modifications

# =============================================================================
# DATA IMPORT AND SET PARAMETERS
# =============================================================================
@import_from_modules("exogenous_values")
@inf_growth_adjust()
@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration

@update_exist_dummies()

# =============================================================================
# CALIBRATION
# =============================================================================
d1switch_abatement[t] = 0; # We turn the abatement model off while calibrating the CGE-model

$Group calibration_endogenous ;
@import_from_modules("calibration")
calibration.optfile=1;
$IMPORT calibration.gms

# =============================================================================
# MODEL TESTS (OPTIONAL)
# =============================================================================
$IF %test_CGE%:

@import_from_modules("tests")
# Data check  -  Abort if any data covered variables have been changed by the calibration
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

# Zero shock  -  Abort if a zero shock changes any variables significantly
@set(all_variables, _saved, .l)
$FIX all_variables; $UNFIX main_endogenous;
execute_unload 'Output/main_pre.gdx';
Solve main using CNS;
execute_unload 'Output/main_CGE.gdx';
@assert_no_difference(all_variables, 1e-6, .l, _saved, "Zero shock changed variables significantly.");
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");

$ENDIF # test_CGE