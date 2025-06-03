# ======================================================================================================================
# Model Calibration for GreenREFORM EU
# ======================================================================================================================
# This file handles both static and dynamic calibration of the model.
# It includes procedures for initializing variables and extending forecasts.

# ----------------------------------------------------------------------------------------------------------------------
# 1. Model Setup
# ----------------------------------------------------------------------------------------------------------------------
# 1.1 Model Configuration
@add_exist_dummies_to_model(calibration) # Limit the main model to only include elements that are not dummied out

# ----------------------------------------------------------------------------------------------------------------------
# 2. Static Calibration
# ----------------------------------------------------------------------------------------------------------------------
# 2.1 Time Period Setup
set_time_periods(%calibration_year%, %calibration_year%);

# 2.2 Initial Value Assignment
# Set starting values for main_endogenous variables if no other value is given
$LOOP calibration_endogenous:
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 0.5;
$ENDLOOP

# 2.3 Static Model Solution
$FIX all_variables; 
$UNFIX calibration_endogenous;

execute_unload 'static_calibration_pre.gdx';
@Setbounds_abatement();
solve calibration using CNS;
execute_unload 'static_calibration.gdx';

# ----------------------------------------------------------------------------------------------------------------------
# 3. Dynamic Calibration
# ----------------------------------------------------------------------------------------------------------------------
# 3.1 Time Period Setup
set_time_periods(%calibration_year%, %terminal_year%);

# 3.2 Dummy Variable Extension
# Extending dummies with "flat forecast" after last data year
$LOOP SG_flat_after_last_data_year: #Extending model dummies 
  {name}{sets}$(t.val > t1.val) = {name}{sets}{$}[<t>t1];
$ENDLOOP 

@update_exist_dummies()

# 3.3 Variable Extension
# For testing partial models only, we extend all data covered variables with "flat forecast" after last data year
# $Group+ G_flat_after_last_data_year all_variables_except_constants;

# Extending variables with "flat forecast" after last data year
$LOOP G_flat_after_last_data_year:
  {name}.l{sets}$({conditions} and t.val > t1.val) = {name}.l{sets}{$}[<t>t1];
$ENDLOOP

# 3.4 Starting Value Management
# Starting values to hot-start solver
# $Group G_do_not_load ;
# $Group G_load calibration_endogenous, - G_do_not_load;
# @load_as(G_load, "previous_calibration.gdx", .l);

# Set starting values for endogenous variables value in t1
$LOOP calibration_endogenous: 
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = {name}.l{sets}{$}[<t>t1];
$ENDLOOP

# 3.5 Dynamic Model Solution
$FIX all_variables; 
$UNFIX calibration_endogenous;
execute_unloaddi "calibration_pre.gdx";
@Setbounds_abatement();
solve calibration using CNS;
# execute_unloaddi "calibration.gdx";
