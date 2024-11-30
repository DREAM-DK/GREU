# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

  $Group+ all_variables
    pY0_CET[out,i,t]$(d1pY_CET[out,i,t]) "Cost price CET index of production in CET-split"
    rMarkup_out_i[out,i,t]$(d1pY_CET[out,i,t]) "Markup on production"
    uY_CET[out,i,t]$(d1pY_CET[out,i,t]) "Share of production in CET-split"
    eCET[i] "Elasticity of substitution in CET-split"
    rMarkup_calib[i,t]$(d1Y_i[i,t]) "Markup on production, used in calibration"
  ;

$ENDIF # variables


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":
  
  $BLOCK production_CET production_CET_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    .. pY_CET[out,i,t] =E= pY0_CET[out,i,t] * (1 + rMarkup_out_i[out,i,t]);

    pY0_CET[out,i,t].. 
      qY_CET[out,i,t] =E= uY_CET[out,i,t] * (pY0_CET[out,i,t]/pY0_i[i,t])**eCET[i] * qY_i[i,t];  

    qY_i&_inproductiongms[i,t]..
      pY0_i[i,t] * qY_i[i,t] =E= sum(out, pY0_CET[out,i,t] * qY_CET[out,i,t]); 
  $ENDBLOCK

  # Add equation and endogenous variables to main model
  model main /production_CET/;
  $Group+ main_endogenous production_CET_endogenous;

$ENDIF # equations



# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":
  # ------------------------------------------------------------------------------
  # Data 
  # ------------------------------------------------------------------------------

  # ------------------------------------------------------------------------------
  # Exogenous variables 
  # ------------------------------------------------------------------------------
  eCET.l[i] = 5;

$ENDIF # exogenous_values


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":
  $BLOCK production_CET_calibration production_CET_calibration_endogenous $(t1[t])
    .. rMarkup_out_i[out,i,t] =E= rMarkup_calib[i,t];   
  $ENDBLOCK

  # Add equations and calibration equations to calibration model
  model calibration /
    production_CET
    production_CET_calibration
  /;

  # Add endogenous variables to calibration model
  $Group calibration_endogenous
    production_CET_endogenous
    production_CET_calibration_endogenous

    -pY_CET[out,i,t1], uY_CET[out,i,t1]
    -qY_i[i,t1], rMarkup_calib[i,t1]
    
    calibration_endogenous
  ;

$ENDIF # calibration