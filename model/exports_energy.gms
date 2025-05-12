# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  uEpj_xEne[es,e,t]$(d1pEpj_base[es,e,'xEne',t]) "Armington-share for exports of energy"
  pEpj_foreign[es,e,t]$(d1pEpj_base[es,e,'xEne',t]) "Price on energy on international export market for energy"
  eX_ene[e] "Price elasticity of exports of energy"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK exports_energy_equations exports_energy_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. qEpj[es,e,xEne,t] =E= uEpj_xEne[es,e,t] * (pEpj[es,e,xEne,t]/pEpj_foreign[es,e,t])**(-eX_ene[e]); 
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / exports_energy_equations /;
$Group+ main_endogenous exports_energy_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

pEpj_foreign.l[es,e,t] = fpt[t];

eX_ene.l[e] = 5;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

# Add equations and calibration equations to calibration model
model calibration /
  exports_energy_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  exports_energy_endogenous
  -qEpj[es,e,xEne,t1], uEpj_xEne[es,e,t1]

  calibration_endogenous
;

$GROUP+ G_flat_after_last_data_year
  uEpj_xEne
;

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
$ENDIF # tests