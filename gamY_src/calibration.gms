# ==============================================================================
# Calibration
# ==============================================================================
# Limit the model to only include elements that are not dummied out
model calibration /
  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;

@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration

$GROUP+ calibration_endogenous - nonexisting;

# ------------------------------------------------------------------------------
# Static calibration
# ------------------------------------------------------------------------------
set_time_periods(%calibration_year%, %calibration_year%);
$FIX all_variables, -calibration_endogenous;

# Starting values to hot-start solver
# $GROUP G_do_not_load ;
# $GROUP G_load calibration_endogenous, - G_do_not_load;
# @load_as(G_load, "previous_calibration.gdx", .l);
$LOOP calibration_endogenous: # Set starting values for main_endogenous variables to 1 if no other value is given
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 0.5;
$ENDLOOP

solve calibration using CNS;

# # ------------------------------------------------------------------------------
# # Dynamic calibration
# # ------------------------------------------------------------------------------
# set_time_periods(%calibration_year%, %terminal_year%);
# # Starting values to hot-start solver
# # $GROUP G_do_not_load ;
# # $GROUP G_load calibration_endogenous, - G_do_not_load;
# # @load_as(G_load, "previous_calibration.gdx", .l);
# $LOOP calibration_endogenous: # Set starting values for endogenous variables value in t1
#   {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = {name}.l{sets}{$}[<t>t1];
# $ENDLOOP
# $FIX all_variables, -calibration_endogenous;
# solve calibration using CNS;


execute_unloaddi "calibration.gdx";

@assert_no_difference(data_covered_variables, 1e-6, _data, .l, "Calibration changed variables covered by data.")
