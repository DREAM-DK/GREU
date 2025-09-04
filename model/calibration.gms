

# ==============================================================================
# Calibration
# ==============================================================================
@add_exist_dummies_to_model(calibration) # Limit the main model to only include elements that are not dummied out
$Group+ calibration_endogenous - nonexisting; # Remove any non-existing elements from the calibration_endogenous group

# ------------------------------------------------------------------------------
# Static calibration
# ------------------------------------------------------------------------------
set_time_periods(%calibration_year%, %calibration_year%);

# Set starting values for main_endogenous variables if no other value is given
$LOOP calibration_endogenous:
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 0.99;
$ENDLOOP

pE_avg.l[e,t] = 1;

# £ temporary for debugging: calculation of instances where vars pEpj_base and pE_avg don't match.
Parameter baseprice_no_avg[es,e,d,t];
baseprice_no_avg[es,e,d,t] = yes$(pEpj_base.l[es,e,d,t] and not (sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t])));

Parameter avgprice_no_base[es,e,d,t];
avgprice_no_base[es,e,d,t] = yes$(not pEpj_base.l[es,e,d,t] and (sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t])));

# £ temporary for debugging: calculation of instances where vars vY_i_d_base and vEpj_base don't match.
Parameter IObasevalue_no_EnEbasevalue[i,d,t];
IObasevalue_no_EnEbasevalue[i,d,t] = yes$(d1Y_i_d[i,d,t] and not (sum((e,es,d_a),d1pEpj_base[es,e,d_a,t])));

# £ temporary for debugging: calculation of instances where vars vY_i_d_base and sSupply_d_e_i_adj don't match.
Parameter IObasevalue_no_adjsupply[i,d,t];
IObasevalue_no_adjsupply[i,d,t] = yes$((d1Y_i_d[i,d,t] and d_ene[d]) and not
(d1Y_i_d[i,d,t] and d_ene[d] and sum(e,d1pY_CET[e,i,t] and sum(es, sum(d_a, es_d2d(es,d_a,d) and d1pEpj_base[es,e,d_a,t])))));

# £ temporary for debugging: calculation of instances where vars jfpY_i_d and sSupply_d_e_i_adj don't match.
Parameter IObasevalue_no_adjsupply2[i,d,t];
IObasevalue_no_adjsupply2[i,d,t] = yes$(jfpY_i_d.l[i,d,t] and not
(d1Y_i_d[i,d,t] and d_ene[d] and sum(e,d1pY_CET[e,i,t] and sum(es, sum(d_a, es_d2d(es,d_a,d) and d1pEpj_base[es,e,d_a,t])))));

# £ temporary for debugging: calculation of instances where vars vY_i_d_base and sSupply_d_e_i_adj don't match.
Parameter IObasevalue_no_adjsupply3[e,d,t];
IObasevalue_no_adjsupply3[e,d,t] = sum((d_a, es), yes$( es_d2d(es,d_a,d) and not d1pEpj_base[es,e,d_a,t]));


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

# Create a block with equations for extending variables with "flat forecast" after last data year
# This is useful where parameters need to be dynamically calibrated due to forward-looking expectations
$Group+ G_flat_after_last_data_year - calibration_endogenous;
$BLOCK flat_after_last_data_year_equations flat_after_last_data_year_endogenous $(t1.val < t.val and t.val <= tEnd.val)
	$LOOP G_flat_after_last_data_year:
		{name}&_flat{sets}$({conditions}).. {name}{sets} =E= {name}{sets}{$}[<t>t1];
	$ENDLOOP
$ENDBLOCK
model calibration / flat_after_last_data_year_equations /;
$Group+ calibration_endogenous flat_after_last_data_year_endogenous;

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
	{name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 0.99;
$ENDLOOP

$FIX all_variables; $UNFIX calibration_endogenous;
execute_unloaddi "calibration_pre.gdx";
solve calibration using CNS;

# @unload_previous_difference(data_covered_variables, _difference); # This one unloads the previous differences to previous_calibration.gdx file. Only do this if you are certain that differences are tolerable.
#Consider bunching three below into single function
# @create_difference_parameters(data_covered_variables, _difference); #This one creates parameters with suffix _difference of all data covered variables
# @set_difference_parameters(data_covered_variables, _difference);    #This one sets the difference parameters to the difference between the current values and the values loaded from data
# @load_previous_difference(data_covered_variables, _difference);     #This one loads previous differences from the previous_calibration.gdx file
# @assert_no_difference(data_covered_variables, 1e-6, _difference, _previous_difference, "data_covered_variables does not change more than previously done so by calibration.");
# @assert_no_difference(data_covered_variables, 1e-6, _data,.l, "data_covered_variables does not change more than previously done so by calibration."); #Ideally this check should be done rather than "diff-in-diff" above
execute_unloaddi "calibration.gdx";
