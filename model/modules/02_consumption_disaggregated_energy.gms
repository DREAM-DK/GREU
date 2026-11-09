# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

  $Group+ all_variables
      uChh_Epj[es,e,c,t]$(d1pEpj_base[es,e,c,t]) ""
      eChh_cEne[cf_ene] "Elasticity of substitution between energy goods for housing energy and car energy respectively"
      pEpj2pChh[es,e,c,cf_ene,t] ""
    ;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":
  $BLOCK consumption_disaggregated_energy_equations consumption_disaggregated_energy_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    #CES-demand based on marginal energy prices
      qEpj[es,e,c,t]$(d1pEpj[es,e,c,t])..
        qEpj[es,e,c,t] =E= uChh_Epj[es,e,c,t] * sum(cf_ene$es2cf2d(es,cf_ene,c),
                                                    pEpj2pChh[es,e,c,cf_ene,t] **(-eChh_cEne[cf_ene]) * qChh[cf_ene,t]
                                                    );

    #Relative price
    pEpj2pChh[es,e,c,cf_ene,t]$(es2cf2d(es,cf_ene,c) and d1pEpj_base[es,e,c,t])..
      pEpj2pChh[es,e,c,cf_ene,t] * pChh[cf_ene,t] =E= pEpj_marg[es,e,c,t];

    #Price of energy in the consumption nesting is based on marginal prices. Differences to payments are captured by bottom deductions in the top
    jpCHh[cf_ene,t]..
      pCHh[cf_ene,t] * qCHh[cf_ene,t] =E= sum((es,e,c)$es2cf2d(es,cf_ene,c), pEpj_marg[es,e,c,t] * qEpj[es,e,c,t]);

# Epj2pChh.lo[es,e,c,cf_ene,t]$((((t1.val <= t.val and t.val <= tEnd.val) and (es2cf2d(es,cf,d))) and pEpj2pChh_exists_dummy[es,e,c,cf_ene,t])) = -inf;
  $ENDBLOCK

  model main / consumption_disaggregated_energy_equations /;
  $Group+ main_endogenous consumption_disaggregated_energy_endogenous;
$ENDIF 


# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":
  
  eChh_cEne.l['cHouEne'] = 0.5;
  eChh_cEne.l['cCarEne'] = 0.5;

$ENDIF # exogenous_values

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

# Add equations and calibration equations to calibration model
model calibration /
  consumption_disaggregated_energy_equations
/;


# Add endogenous variables to calibration model
$Group calibration_endogenous
  consumption_disaggregated_energy_endogenous

  -qEpj[es,e,c,t1], uChh_Epj[es,e,c,t1]
  calibration_endogenous
;

$GROUP+ G_flat_after_last_data_year
  uChh_Epj 
;


$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
$ENDIF # tests