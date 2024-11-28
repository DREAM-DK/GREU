# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

  $Group+ all_variables
    pY0_CET[out,i,t]$(d1pY_CET[out,i,t]) "Cost price CET index of production in CET-split"
    markup[out,i,t]$(d1pY_CET[out,i,t]) "Markup on production"
    uY_CET[out,i,t]$(d1pY_CET[out,i,t]) "Share of production in CET-split"
    eCET[i] "Elasticity of substitution in CET-split"
    markup_calib[i,t]$(d1Y_i[i,t]) "Markup on production, used in calibration"
  ;

$ENDIF # variables


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":
  
  $BLOCK production_cet production_cet_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    pY_CET[out,i,t]$(d1pY_CET[out,i,t]).. 
      pY_CET[out,i,t] =E= pY0_CET[out,i,t] * (1 + markup[out,i,t]);

    pY0_CET[out,i,t]$(d1pY_CET[out,i,t]).. 
      qY_CET[out,i,t] =E= uY_CET[out,i,t] * (pY0_CET[out,i,t]/pY0[i,t])**eCET[i] *qY[i,t];  

    qY&_inproductiongms[i,t]$(d1Y_i[i,t]).. 
      pY0[i,t] * qY[i,t] =E= sum(out$d1pY_CET[out,i,t], pY0_CET[out,i,t] * qY_CET[out,i,t]); 
  $ENDBLOCK

  # Add equation and endogenous variables to main model
  model main / 
              production_cet
              /;
  $Group+ main_endogenous 
    production_cet_endogenous
    ;

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

  # ------------------------------------------------------------------------------
  # Initial values  
  # ------------------------------------------------------------------------------
    pY0_CET.l[out,i,t]$(d1pY_CET[out,i,t]) = pY_CET.l[out,i,t]; 


$ENDIF # exogenous_values


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

  $BLOCK production_cet_calibration production_cet_calibration_endogenous $(t1[t])
    .. markup[out,i,t] =E= markup_calib[i,t];   
  $ENDBLOCK

  # Add equations and calibration equations to calibration model
  model calibration /
    production_cet
    production_cet_calibration
  /;

  # Add endogenous variables to calibration model
  $Group calibration_endogenous
    production_cet_endogenous

    -pY_CET[out,i,t1], uY_CET[out,i,t1]
    -qY[i,t1], markup_calib[i,t1]
    production_cet_calibration_endogenous

    calibration_endogenous
  ;

$ENDIF # calibration