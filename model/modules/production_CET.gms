# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

  $Group+ all_variables
    pY0_CET[out,i,t]$(d1pY_CET[out,i,t]) "Cost price CET index of production in CET-split"
    rMarkup_out_i[out,i,t]$(d1pY_CET[out,i,t]) "Markup on production"
    uY_CET[out,i,t]$(d1pY_CET[out,i,t]) "Share of production in CET-split"
    eCET[i] "Elasticity of substitution in CET-split"
    rMarkup_out_i_calib[i,t]$(d1Y_i[i,t]) "Markup on production, used in calibration"
    jvY_i[i,t]$(d1Y_i[i,t]) ""
    jvM_i[i,t]$(d1M_i[i,t]) ""
    qY_CETown[out,i,t]$(d1pY_CET[out,i,t]) "Production for own-consumption, not in NAS"
    qY_CETgross[out,i,t]$(d1pY_CET[out,i,t]) "Gross-production, including production for own-consumption"
  ;
  

$ENDIF # variables


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":
  
  $BLOCK production_CET production_CET_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    .. pY_CET[out,i,t] =E= pY0_CET[out,i,t] * (1 + rMarkup_out_i[out,i,t]);

    pY0_CET[out,i,t].. 
      qY_CETgross[out,i,t] =E= uY_CET[out,i,t] * (pY0_CET[out,i,t]/pY0_i[i,t])**eCET[i] * qY0_i[i,t];  

    .. qY_CETgross[out,i,t] =E= qY_CET[out,i,t] + qY_CETown[out,i,t];

    .. qY_CETown[e,i,t] =E= sum((es,d)$(d1pEpj_own[es,e,d,t]), qEpj[es,e,d,t]) * qY_CETgross[e,i,t]/sum(i_a, qY_CETgross[e,i_a,t]);
  $ENDBLOCK

  $BLOCK production_CET_links production_CET_links_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    #Link to production function - this equation determines demand for qY0_i by disconnecting qY0_i from qY_i from input-output model
    qPFtop2qY[i,t]..
      pY0_i[i,t] * qY0_i[i,t] =E= sum(out, pY0_CET[out,i,t] * qY_CETgross[out,i,t]); 
    

    #Link to pricing
    # rMarkup_i[i,t]$(t.val > tDataEnd.val)..
    #      (1+rMarkup_i[i,t])* pY0_i[i,t]*qY0_i[i,t] =E= sum(out, vY_CET[out,i,t]);

    #Just for testing. Should herpahs not have its own equations
    jvY_i[i,t]..
         vY_i[i,t] =E= sum(out, pY_CET[out,i,t]*qY_CET[out,i,t]) + jvY_i[i,t]; 

    jvM_i[i,t]..
         vM_i[i,t] =E= sum(out, pM_CET[out,i,t]*qM_CET[out,i,t]) + sum(e,vDistributionProfits[e,t])$(i_refineries[i]) + jvM_i[i,t]; 

  $ENDBLOCK

  # Add equation and endogenous variables to main model
  model main /production_CET
              production_CET_links
              /;
  $Group+ main_endogenous 
          production_CET_endogenous 
          production_CET_links_endogenous
          ;

$ENDIF # equations



# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":
  # ------------------------------------------------------------------------------
  # Data 
  # ------------------------------------------------------------------------------

  $Group production_CET_data_variables
    qY_CETgross, qY_CETown 
  ;
    $Group+ data_covered_variables production_CET_data_variables$(t.val <= %calibration_year%); 

  @load(production_CET_data_variables, "../data/data.gdx")



  # ------------------------------------------------------------------------------
  # Exogenous variables 
  # ------------------------------------------------------------------------------
  eCET.l[i] = 5;
  pY0_CET.l[out,i,t] = pY_CET.l[out,i,t]; #Initial value to help solver


$ENDIF # exogenous_values


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":
  $BLOCK production_CET_calibration production_CET_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    rMarkup_out_i[out,i,t]
    .. rMarkup_out_i[out,i,t] =E= rMarkup_out_i_calib[i,t1];   

    # jvY_i&_calib[i,t]$(t.val>t1.val)..
    #   jvY_i[i,t] =E= 0;
  $ENDBLOCK

  # Add equations and calibration equations to calibration model
  model calibration /
    production_CET
    production_CET_links
    production_CET_calibration
  /;

  # Add endogenous variables to calibration model
  $Group calibration_endogenous
    production_CET_endogenous
    -pY_CET[out,i,t1], uY_CET[out,i,t1]
    -pY0_i[i,t1], rMarkup_out_i_calib[i,t1]

    production_CET_links_endogenous
    jvY_i[i,t1]

    production_CET_calibration_endogenous

    calibration_endogenous
  ;

  $GROUP+ G_flat_after_last_data_year
    uY_CET
  ;

# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO production_CET_calibration_starting_values

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Model tests
# ------------------------------------------------------------------------------

$IF %stage%=='tests':
  LOOP((t,i)$(t.val>tDataEnd.val),
  ABORT$(abs(jvY_i.l[i,t])>1e-6) 'Production value vY_i computed in input_out.gms does not align with production value in CET-split';
  );

  #This test should be adjusted to handle distribution profits (which is why the test does not work )
  LOOP((t,i)$(t.val>tDataEnd.val),
  ABORT$(abs(jvM_i.l[i,t])>1e-6) 'Import value vM_i computed in input_out.gms does not align with production value in CET-split';
  );
$ENDIF