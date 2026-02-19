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
# $IF %stage% == "calibration":
# Add equations and calibration equations to calibration model
$BLOCK exports_energy_calibration_equations exports_energy_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  #In this equation we fix energy-exports to the value in data-year. Consider changing if you want baseline-forecast to produce varying energy-exports.
  .. pEpj_foreign[es,e,t] =E= pEpj[es,e,'xEne',t];
$ENDBLOCK

model calibration /
  exports_energy_equations
  exports_energy_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  exports_energy_endogenous
  -qEpj[es,e,xEne,t1], uEpj_xEne[es,e,t1]

  exports_energy_calibration_endogenous
  calibration_endogenous
;

$GROUP+ G_flat_after_last_data_year
  uEpj_xEne
;

# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO exports_energy_calibration_starting_values

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
$ENDIF # tests