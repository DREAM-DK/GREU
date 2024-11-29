# ==============================================================================
# Calibration
# ==============================================================================
@add_exist_dummies_to_model(calibration) # Limit the main model to only include elements that are not dummied out

# ------------------------------------------------------------------------------
# Static calibration
# ------------------------------------------------------------------------------
set_time_periods(%calibration_year%, %calibration_year%);

# Set starting values for main_endogenous variables if no other value is given
$LOOP calibration_endogenous:
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 0.5;
$ENDLOOP

$FIX all_variables; $UNFIX calibration_endogenous;

execute_unload 'static_calibration_pre.gdx';
solve calibration using CNS;
execute_unload 'static_calibration.gdx';

# ------------------------------------------------------------------------------
# Dynamic calibration
# ------------------------------------------------------------------------------
set_time_periods(%calibration_year%, %terminal_year%);

# Extending dummies with "flat forecast" after last data year
$LOOP SG_flat_after_last_data_year: #Extending model dummies 
	{name}{sets}$(t.val > t1.val) = {name}{sets}{$}[<t>t1];
$ENDLOOP 

@update_exist_dummies()

# For testing partial models only, we extend all data covered variables with "flat forecast" after last data year
$Group+ G_flat_after_last_data_year all_variables_except_constants;

# Extending variables with "flat forecast" after last data year
$LOOP G_flat_after_last_data_year:
	{name}.l{sets}$({conditions} and t.val > t1.val) = {name}.l{sets}{$}[<t>t1];
$ENDLOOP

# Starting values to hot-start solver
# $Group G_do_not_load ;
# $Group G_load calibration_endogenous, - G_do_not_load;
# @load_as(G_load, "previous_calibration.gdx", .l);

# Set starting values for endogenous variables value in t1
$LOOP calibration_endogenous: 
	{name}.l{sets}$({conditions} and {name}.l{sets} = 0) = {name}.l{sets}{$}[<t>t1];
$ENDLOOP

$FIX all_variables; $UNFIX calibration_endogenous;
execute_unloaddi "calibration_pre.gdx";
solve calibration using CNS;
solve calibration using CNS;
execute_unloaddi "calibration.gdx";
