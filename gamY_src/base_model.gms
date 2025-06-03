$onMulti # Allows adding to an already defined set or model with multiple "model" or "set" statements

$IMPORT functions.gms;
$IMPORT settings.gms

$IMPORT sets/time.sets.gms
$IMPORT sets/abatement.sets.gms

set_time_periods(%first_data_year%, %terminal_year%);

# ------------------------------------------------------------------------------
# Select modules
# ------------------------------------------------------------------------------
$FUNCTION import_from_modules(stage_key):
  $SETGLOBAL stage stage_key;
  $IMPORT abatement.gms
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
# @inf_growth_adjust()
@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration
@update_exist_dummies()

# ------------------------------------------------------------------------------
# Depicting discrete and smooth supply curves
# ------------------------------------------------------------------------------
$import premodel_abatement.gms
$import Supply_curves_abatement.gms

# ------------------------------------------------------------------------------
# Calibrate model
# ------------------------------------------------------------------------------
$Group calibration_endogenous ;
@import_from_modules("calibration")
calibration.optfile=1;
$IMPORT calibration.gms
$IMPORT report_abatement.gms
execute_unloaddi "calibration.gdx";

# ------------------------------------------------------------------------------
# Increasing capital costs for one technology
# ------------------------------------------------------------------------------

uTKexp.l['t1','heating','10030',t]$(d1sTPotential['t1','heating','10030',t]) 
  = uTKexp.l['t1','heating','10030',t] * 100;

$import Supply_curves_abatement.gms

$FIX all_variables;
$UNFIX main_endogenous;
@Setbounds_abatement();
Solve main using CNS;
$IMPORT report_abatement.gms
execute_unload 'shock_capital_cost.gdx';


# # ------------------------------------------------------------------------------
# # Increasing carbon tax
# # ------------------------------------------------------------------------------

# # Re-setting capital costs to original values
# uTKexp.l['t1','heating','10030',t]$(d1sTPotential['t1','heating','10030',t]) 
#   = uTKexp_data['t1','heating','10030',t];

# # Carbon tax
# pTE_tax.l[es,e,d,t]$(sameas[e,'Gasoline for transport'] or sameas[e,'Diesel for transport'] or sameas[e,'Natural gas incl. biongas'] or sameas[e,'Coal and coke'] or sameas[e,'Waste'])
#     = pTE.l[es,e,d,t]*30;

# $import Supply_curves_abatement.gms

# $FIX all_variables;
# $UNFIX main_endogenous;
# @Setbounds_abatement();
# Solve main using CNS;
# $IMPORT report_abatement.gms
# execute_unload 'shock_carbon_tax.gdx';

# ------------------------------------------------------------------------------
# Module for plotting the cdf_log_norm function
# ------------------------------------------------------------------------------

$import cdf_log_norm.gms