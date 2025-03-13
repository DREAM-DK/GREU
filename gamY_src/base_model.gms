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
$IMPORT report_abatement.gms
execute_unloaddi "calibration.gdx";

# ------------------------------------------------------------------------------
# Calibrate model with lower variance on technology costs
# ------------------------------------------------------------------------------

# eP.l[l,es,i,t] = 0.05;
# $IMPORT calibration.gms
# $IMPORT report_abatement.gms

# execute_unloaddi "Abatement_partial.gdx";


# ------------------------------------------------------------------------------
# Calibration of electrification in the baseline
# ------------------------------------------------------------------------------

# uTK.l['t_Electricity_calib','heating','10030','2020'] = 2.2;
# uTK.l['t_Electricity_calib','heating','10030','2021'] = 2;
# uTK.l['t_Electricity_calib','heating','10030','2022'] = 1.5;
# uTK.l['t_Electricity_calib','heating','10030','2023'] = 1.2;
# uTK.l['t_Electricity_calib','heating','10030','2024'] = 1.2;
# uTK.l['t_Electricity_calib','heating','10030',t]$(t.val>2024) = 1.2;

# uTK.l['t_Electricity_calib_2','heating','10030','2020'] = 2.8;
# uTK.l['t_Electricity_calib_2','heating','10030','2021'] = 2.5;
# uTK.l['t_Electricity_calib_2','heating','10030','2022'] = 2.2;
# uTK.l['t_Electricity_calib_2','heating','10030','2023'] = 2;
# uTK.l['t_Electricity_calib_2','heating','10030',t]$(t.val>2023) = 2;

# $FIX all_variables;
# $UNFIX main_endogenous;
# Solve main using CNS;
# $IMPORT report_abatement.gms
# execute_unload 'Abatement_partial_elec.gdx';

# ------------------------------------------------------------------------------
# Increasing carbon tax
# ------------------------------------------------------------------------------

# Carbon tax
# tCO2_Emarg.l[em,es,e,i,t] = 5 * tCO2_Emarg.l[em,es,e,i,t]; #Increase in CO2-tax of 10%

# $FIX all_variables;
# $UNFIX main_endogenous;
# Solve main using CNS;
# $IMPORT report_abatement.gms
# execute_unload 'Abatement_partial_carbon_tax.gdx';

