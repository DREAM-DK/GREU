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

$FIX all_variables; $UNFIX calibration_endogenous;

execute_unload 'static_calibration_pre.gdx';
solve calibration using CNS;
PARAMETER qY_i_d_test[i,d,t], qM_i_d_test[i,d,t];
qY_i_d_test[i,d_non_ene,tBase] = qY_i_d.l[i,d_non_ene,tBase]/(1+tY_i_d.l[i,d_non_ene,tBase]) - qY_i_d_non_ene.l[i,d_non_ene,tBase];
qM_i_d_test[i,d_non_ene,tBase] = qM_i_d.l[i,d_non_ene,tBase]/(1+tM_i_d.l[i,d_non_ene,tBase]) - qM_i_d_non_ene.l[i,d_non_ene,tBase];
ABORT$(abs((sum((i,d_non_ene,t)$(tBase[t] and not sameas[d_non_ene,'invt']), qY_i_d_test[i,d_non_ene,t] + qM_i_d_test[i,d_non_ene,t]))>1e-6)) 'IO doesnt match';

# PARAMETER testvRE[re,t];
# testvRE[re,t] = sum(i, vY_i_d.l[i,re,t] + vM_i_d.l[i,re,t]) - sum((e,es,i_a)$es2re(es,re), vEpj.l[es,e,i_a,t]);
# ABORT$(abs(sum((re,t)$(tBase[t]), testvRE[re,t]))>1e-2) 'RE doesnt match';

execute_unload 'static_calibration.gdx';
# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");
# $exit
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
execute_unloaddi "calibration.gdx";
