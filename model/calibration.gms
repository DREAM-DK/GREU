

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
execute_unload 'static_calibration.gdx';

PARAMETER qY_i_d_test[i,d,t], qM_i_d_test[i,d,t], pD_test[d,t], vD_energy[d,t], vD_IO[d,t], vS_energy_y[i,t], vS_IO_y[i,t], vS_energy_m[i,t], vS_IO_m[i,t], vD_energy_test[d,t],
 vS_energy_y_test[i,t], vS_energy_m_test[i,t];


$FUNCTION compute_tests():
	vD_IO[d,t]$(d_ene[d] and t.val>=t1.val and t.val<=tEnd.val) = sum(i$(not i_energymargins[i]), qY_i_d_test_var.l[i,d,t])+ sum(i$(not i_energymargins[i]), qM_i_d_test_var.l[i,d,t]); 

	vS_IO_y[i,t]$(t1[t] and not i_energymargins[i]) = sum(d$d_ene[d], qY_i_d_test_var.l[i,d,t]); 
	vS_IO_m[i,t]$(t1[t] and not i_energymargins[i]) = sum(d$d_ene[d], qM_i_d_test_var.l[i,d,t]); 

	vD_IO[d,t]$(d_ene[d] and t.val>=t1.val and t.val<=tEnd.val) = sum(i$(not i_energymargins[i]), qY_i_d.l[i,d,t]*pY_i_d.l[i,d,tBase]/(1+tY_i_d.l[i,d,t])) 
																	+ sum(i$(not i_energymargins[i]), qM_i_d.l[i,d,t]*pM_i_d.l[i,d,tBase]/(1+tM_i_d.l[i,d,t]));

	vS_IO_y[i,t]$(t.val>=t1.val and t.val<=tEnd.val and not i_energymargins[i]) = sum(d$d_ene[d], qY_i_d.l[i,d,t]*pY_i_d.l[i,d,tBase]/(1+tY_i_d.l[i,d,tBase])); 
	vS_IO_m[i,t]$(t.val>=t1.val and t.val<=tEnd.val and not i_energymargins[i]) = sum(d$d_ene[d], qM_i_d.l[i,d,t]*pM_i_d.l[i,d,tBase]/(1+tM_i_d.l[i,d,tBase])); 


	vD_energy[d,t] = sum((es,e,d_a)$es_d2d(es,d_a,d), pEpj_base.l[es,e,d_a,tBase] * qEpj.l[es,e,d_a,t]);
	vS_energy_y[i,t]$(t.val>=t1.val and t.val<=tEnd.val) = sum(e,pY_CET.l[e,i,t]*qY_CET.l[e,i,t]);
	vS_energy_m[i,t]$(t.val>=t1.val and t.val<=tEnd.val) = sum(e,pM_CET.l[e,i,t]*qM_CET.l[e,i,t]);

	qY_i_d_test[i,d_non_ene,tBase] = qY_i_d.l[i,d_non_ene,tBase]/(1+tY_i_d.l[i,d_non_ene,tBase]) - qY_i_d_non_ene.l[i,d_non_ene,tBase];
	qM_i_d_test[i,d_non_ene,tBase] = qM_i_d.l[i,d_non_ene,tBase]/(1+tM_i_d.l[i,d_non_ene,tBase]) - qM_i_d_non_ene.l[i,d_non_ene,tBase];

	vD_energy_test[d,t]   = vD_energy[d,t] - vD_IO[d,t];
	vS_energy_y_test[i,t] = vS_energy_y[i,t] - vS_IO_y[i,t];
	vS_energy_m_test[i,t] = vS_energy_m[i,t] - vS_IO_m[i,t];

	pD_test[d_non_ene,t] = pD.l[d_non_ene,t] - pD_non_ene.l[d_non_ene,t];

	# LOOP((i,d,t)$(t1[t] and jqM_i_d.l[i,d,t] and d_ene[d] and not invt_ene[d]),
	# 	ABORT$(abs(jqM_i_d.l[i,d,t])/abs(qM_i_d.l[i,d,t]/(1-tM_i_d.l[i,d,tBase]))>0.01) 'Difference in value of energy imports vary too much between IO and bottom-up energy-data, tolerance set at 1 pct.';
	# );

	# LOOP((i,d,t)$(t1[t] and jqY_i_d.l[i,d,t] and d_ene[d] and not invt_ene[d]),
	# 	ABORT$(abs(jqY_i_d.l[i,d,t])/abs(qY_i_d.l[i,d,t]/(1-tY_i_d[i,d,tBase]))>0.03) 'Difference in value of energy production vary too much between IO and bottom-up energy-data, tolerance set at 25 pct.';
	# );

$ENDFUNCTION 

@compute_tests();

# @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "data_covered_variables was changed by calibration.");
# $exit
# ABORT$(abs((sum((i,d_non_ene,t)$(tBase[t] and not (sameas[i,'35002'] and sameas[d_non_ene,'im'])), qY_i_d_test[i,d_non_ene,t] + qM_i_d_test[i,d_non_ene,t]))>1-4)) 'IO doesnt match';

# PARAMETER testvRE[re,t];
# testvRE[re,t] = sum(i, vY_i_d.l[i,re,t] + vM_i_d.l[i,re,t]) - sum((e,es,i_a)$es2re(es,re), vEpj.l[es,e,i_a,t]);
# ABORT$(abs(sum((re,t)$(tBase[t]), testvRE[re,t]))>1e-2) 'RE doesnt match';

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
@compute_tests();
execute_unloaddi "calibration.gdx";
