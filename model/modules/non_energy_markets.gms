# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------

	$IF %stage% == "variables":

			$Group+ all_variables
				adj_jfpY_i_d[i,t]$(d1Y_i_nepnei[i,t] and not i_energymargins[i]) "" 
				jqY_CET_tDataEnd[out,i] ""
				jqM_CET_tDataEnd[out,i] ""
		;
	$ENDIF 
  
  # ------------------------------------------------------------------------------
	# Equations
	# ------------------------------------------------------------------------------

	$IF %stage% == "equations":

    
    $BLOCK non_energy_markets_clearing non_energy_markets_clearing_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

				#Total demand is linked to CET-supply from the top of production function (see production_CET.gms). Energy-clearing with CET-production is handled in "energy_markets.gms"
				 ..qY_CET[out_other,i,t] =E= sum(d_non_ene,qY_i_d[i,d_non_ene,t]/ (1+tY_i_d[i,d_non_ene,tBase])) + qD_E_margins[i,t] + jqY_CET_tDataEnd[out_other,i]$(tDataEnd[t]);

				 ..qM_CET[out_other,i,t] =E= sum(d_non_ene,qM_i_d[i,d_non_ene,t]/ (1+tM_i_d[i,d_non_ene,tBase])) + jqM_CET_tDataEnd[out_other,i]$(tDataEnd[t]);


				#Non-energy production in energy-producing sectors
					jfpY_i_d[i,d,t]$(d1Y_i_nepnei[i,t] and d1Y_i_d[i,d,t] and d_non_ene[d] and not i_energymargins[i] and t.val>t1.val)..
							jfpY_i_d[i,d,t] =E= adj_jfpY_i_d[i,t];

					adj_jfpY_i_d[i,t]$(d1Y_i_nepnei[i,t] and not i_energymargins[i] and t.val>t1.val)..
							sum(d_non_ene, pY_i_d_base[i,d_non_ene,t] * qY_i_d[i,d_non_ene,t]) =E= vY_CET['out_other',i,t];
			

				#Computing value of non-energy products in producer prices.
				 .. vY_CET[out_other,i,t] =E= pY_CET[out_other,i,t]*qY_CET[out_other,i,t];

				 .. vM_CET[out_other,i,t] =E= pM_CET[out_other,i,t]*qM_CET[out_other,i,t];

    $ENDBLOCK 


    model  main/
           non_energy_markets_clearing
           /

    $Group+ main_endogenous 
      non_energy_markets_clearing_endogenous
    ;


$ENDIF


# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------

	$IF %stage% == "exogenous_values":

	$ENDIF

# ------------------------------------------------------------------------------
# Starting values
# ------------------------------------------------------------------------------
$IF %stage% == "starting_values":

set_time_periods(%calibration_year%, %calibration_year%);

$Group non_default_starting_values
  # Variables that require custom starting values
;

# Set custom starting values for the variables in non_default_starting_values here

$ENDIF # starting_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":

	model calibration /
           non_energy_markets_clearing
          /;

  $Group calibration_endogenous
  	
    non_energy_markets_clearing_endogenous
		-qY_CET[out_other,i,t1], jqY_CET_tDataEnd
		-qM_CET[out_other,i,t1], jqM_CET_tDataEnd

    calibration_endogenous
  ;


$ENDIF

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":

LOOP((out_other,i)$(sum(tDataEnd,d1pY_CET[out_other,i,tDataEnd])), 
	ABORT$(ABS(jqY_CET_tDataEnd.l[out_other,i])> 1e-4$(not sameas[i,'02000']) + 0.06$(sameas[i,'02000'])) 'Too large changes in qY_CET from calibration. Tolerance set relatively high for 02000. Otherwise should be low '
);
LOOP((out_other,i)$(sum(tDataEnd,d1pM_CET[out_other,i,tDataEnd])), 
	ABORT$(ABS(jqM_CET_tDataEnd.l[out_other,i])> 1e-4) 'Too large changes in qY_CET from calibration. Tolerance set very high on already because of 02000. Otherwise should be low '
);

$ENDIF


