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
$IMPORT sets/abatement.sets.gms
$IMPORT sets/subsets.sets.gms

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
    ("abatement.gms", 1),
    ("Report/All.Report.gms", 1),     
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
$Group G_zero_after_last_data_year ; # Variables that are set to zero after last data year
$Group G_zero_t1_after_static_calibration ; # Variables that are set to zero in t1 after static calibration
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

set these_e[out]/
"Other oil products"
"semi_refin_oil"
"Bunkering of Danish operated planes on foreign territory"
"Wood pellets"
"Jet petroleum"
"Natural gas (Extraction)"
"Waste"
"Gasoline for transport"
"Bunkering of Danish operated vessels on foreign territory"
"Waste oil"
"Biogas"
"Refinery gas"
"District heat"
"Renewable energy"
"Firewood and woodchips"
"Straw for energy purposes"
"Crude oil"
"Wood waste"
"Heat pumps"
"Bunkering of Danish operated trucks on foreign territory"
"Coal and coke"
"Diesel for transport"
"Liquid biofuels"
"Natural gas incl. biongas"
"Electricity"
# "Captured CO2"
/;

$IF %exogenous_supply_prices% == 1:
  $GROUP+ main_endogenous 
    -pE_avg[e,t]$(these_e[e] and sum(i,d1pY_CET[e,i,t]) and sum(i,d1pM_CET[e,i,t])) #Average energy price is exogenized if there is both production and imports of energy
    #Mark-up is endogenized 
    rMarkup_out_i[e,i,t]$(d1pY_CET[e,i,t]), -pY_CET[e,i,t]$(d1pY_CEt[e,i,t])
    pM_CET[e,i,t]$(these_e[out] and d1pM_CET[e,i,t] and sum(i_a,d1pY_CET[e,i_a,t]))
  ;
$ENDIF 
# ------------------------------------------------------------------------------
# Import data and set parameters
# ------------------------------------------------------------------------------
@import_from_modules("exogenous_values")
@inf_growth_adjust()
@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration

@update_exist_dummies()

# ------------------------------------------------------------------------------
# Calibrate CGE model
# ------------------------------------------------------------------------------
# We turn the abatement model off while calibrating the CGE-model
d1switch_abatement[t] = 0;

$Group calibration_endogenous ;
@import_from_modules("calibration")
calibration.optfile=1;
$IMPORT calibration.gms

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
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