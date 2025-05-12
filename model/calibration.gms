

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

PARAMETER qY_i_d_test[i,d,t], qM_i_d_test[i,d,t], pD_test[d,t], vD_energy[d,t], vD_IO[d,t], vS_energy_y[i,t], vS_IO_y[i,t], vS_energy_m[i,t], vS_IO_m[i,t], vD_energy_test[d,t],
 vS_energy_y_test[i,t], vS_energy_m_test[i,t], 
 vD_energy_taxes_and_vat_IO[d,t], vD_energy_taxes_and_vat_energy[d,t], vD_energy_taxes_and_vat_test[d,t],
 implied_importshare[d,e,t],
 pY_i_d_base_neg[i,d,t]
 ;


$FUNCTION compute_tests({turnontests}):
	vS_IO_y[i,t]$(t1[t] and not i_energymargins[i]) = sum(d_ene, qY_i_d_test_var.l[i,d_ene,t]); 
	vS_IO_m[i,t]$(t1[t] and not i_energymargins[i]) = sum(d_ene, qM_i_d_test_var.l[i,d_ene,t]); 

	vD_IO[d,t]$(d_ene[d] and t.val>=t1.val and t.val<=tEnd.val) = sum(i$(not i_energymargins[i]), vY_i_d_base.l[i,d,t]) 
																	+ sum(i$(not i_energymargins[i]), vM_i_d_base.l[i,d,t]);

	vS_IO_y[i,t]$(t.val>=t1.val and t.val<=tEnd.val and not i_energymargins[i]) = sum(d_ene, vY_i_d_base.l[i,d_ene,t]); 
	vS_IO_m[i,t]$(t.val>=t1.val and t.val<=tEnd.val and not i_energymargins[i]) = sum(d_ene, vM_i_d_base.l[i,d_ene,t]); 


	vD_energy[d,t] = sum((es,e,d_a)$es_d2d(es,d_a,d), vEpj_base.l[es,e,d_a,t]);
	vS_energy_y[i,t]$(t.val>=t1.val and t.val<=tEnd.val) = sum(e,vY_CET.l[e,i,t]);
	vS_energy_m[i,t]$(t.val>=t1.val and t.val<=tEnd.val) = sum(e,vM_CET.l[e,i,t]) + sum(e,vDistributionProfits.l[e,t])$(i_refineries[i]);


	vD_energy_test[d,t]   = vD_energy[d,t] - vD_IO[d,t];
	vS_energy_y_test[i,t] = vS_energy_y[i,t] - vS_IO_y[i,t];
	vS_energy_m_test[i,t] = vS_energy_m[i,t] - vS_IO_m[i,t];

	vD_energy_taxes_and_vat_IO[d,t]$(d_ene[d]) = sum(i, vtY_i_d__load__[i,d,t] + vtM_i_d__load__[i,d,t]);
	vD_energy_taxes_and_vat_energy[d,t]$(d_ene[d]) = sum(i,sum((e,es,d_a)$es_d2d(es,d_a,d),  sCorr.l[d,e,i,t] * vte_NAS.l[es,e,d_a,t]))
																									+sum((e,es,d_a)$es_d2d(es,d_a,d),  (1-sum(i_a,sCorr.l[d,e,i_a,t])) * vte_NAS.l[es,e,d_a,t]); 

	vD_energy_taxes_and_vat_test[d,t] = vD_energy_taxes_and_vat_energy[d,t] - vD_energy_taxes_and_vat_IO[d,t];

	implied_importshare[d,e,t]$(d_ene[d] and (sum(i,d1pY_CET[e,i,t]) or sum(i, d1pM_CET[e,i,t])) and sum((es,d_a)$es_d2d(es,d_a,d), d1pEpj_base[es,e,d_a,t]))
	 = (1-sum(i_a, sCorr.l[d,e,i_a,t]));



	pY_i_d_base_neg[i,d,t]$(d1Y_i_d[i,d,t] and pY_i_d.l[i,d,t]<0) = pY_i_d_base.l[i,d,t];

	$IF '{turnontests}'=='1':
		LOOP((d,t)$(t_endoyrs[t] and not tDataEnd[t]),
			ABORT$(abs(vD_energy_test[d,t])>1e-4) 'Difference in value of energy demand between IO and bottom-up energy';
		);
		LOOP((i,t)$(t_endoyrs[t] and not tDataEnd[t]),
			ABORT$(abs(vS_energy_y_test[i,t])>1e-4) 'Difference in value of domestic energy supply between IO and bottom-up energy-data';
		);

		LOOP((i,t)$(t_endoyrs[t] and not tDataEnd[t]),
			ABORT$(abs(vS_energy_m_test[i,t])>1e-4) 'Difference in value of imports of energy between IO and bottom-up energy';
		);

		#Testing that bottom-up energy data on taxes does not differ from IO-data on taxes on energy on the aggregate
		LOOP((d,t)$(tDataEnd[t]),
			ABORT$(abs(vD_energy_taxes_and_vat_test[d,t])>0.1) 'Difference in value of taxes bottom-up energy-data';
		);

		#Testing that no IO-prices or quantities (except from inventories) are negative, when energy-modules are turned on to take over IO-module
			#Domestic prices
			LOOP((i,d,t)$(t_endoyrs[t] and not tDataEnd[t]),
				ABORT$(pY_i_d_base.l[i,d,t]<0) 'IO-prices are negative, when energy-modules are turned on to take over IO-module';
			);

			# #Import prices
			LOOP((i,d,t)$(t_endoyrs[t] and not tDataEnd[t]),
				ABORT$(pM_i_d_base.l[i,d,t]<0) 'IO-prices are negative, when energy-modules are turned on to take over IO-module';
			);

			#Quantities (inventories, and investments may be negative)
			LOOP((i,d,t)$(t_endoyrs[t] and not invt[d] and not invt_ene[d] and not k[d] and not tDataEnd[t]),
				ABORT$(qY_i_d.l[i,d,t]<0) 'IO-quentities from domestic production are negative, when energy-modules are turned on to take over IO-module';
			);

			LOOP((i,d,t)$(t_endoyrs[t] and not invt[d] and not invt_ene[d] and not k[d] and not tDataEnd[t]),
				ABORT$(qM_i_d.l[i,d,t]<0) 'IO-quantities from imports are negative, when energy-modules are turned on to take over IO-module';
			);


	$ENDIF

$ENDFUNCTION 

@compute_tests(1);
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

@unload_previous_difference(data_covered_variables, _difference)
@create_difference_parameters(data_covered_variables, _difference);
@set_difference_parameters(data_covered_variables, _difference);
@load_previous_difference(data_covered_variables, _difference);
@assert_no_difference(data_covered_variables, 1e-6, _difference, _previous_difference, "data_covered_variables does not change more than previously done so by calibration.");
@compute_tests(1);
execute_unloaddi "calibration.gdx";
