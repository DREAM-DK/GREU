# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------

	$IF %stage% == "variables":

			$Group+ all_variables
				adj_jfpY_i_d[i,t]$(d1Y_i_nepnei[i,t] and not i_energymargins[i]) "" 
		;
	$ENDIF 
  
  # ------------------------------------------------------------------------------
	# Equations
	# ------------------------------------------------------------------------------

	$IF %stage% == "equations":

    
    $BLOCK non_energy_markets_clearing non_energy_markets_clearing_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

				#Total demand is linked to CET-supply from the top of production function (see production_CET.gms). Energy-clearing with CET-production is handled in "energy_markets.gms"
				 ..qY_CET[out_other,i,t] =E= sum(d_non_ene,qY_i_d[i,d_non_ene,t]/ (1+tY_i_d[i,d_non_ene,tBase])) + qD_WMA[t]$(i_wholesale[i]) + qD_CMA[t]$(i_cardealers[i]) + qD_RMA[t]$(i_retail[i]);

				 ..qM_CET[out_other,i,t] =E= sum(d_non_ene,qM_i_d[i,d_non_ene,t]/ (1+tM_i_d[i,d_non_ene,tBase]));


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
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":

	model calibration /
           non_energy_markets_clearing
          /;

  $Group calibration_endogenous
  	
    non_energy_markets_clearing_endogenous

    calibration_endogenous
  ;

# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO non_energy_markets_calibration_starting_values

$ENDIF


