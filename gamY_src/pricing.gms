# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  pY_i[i,t]$(d1Y_i[i,t]) "Price of output by industry."
  rMarkup_i[i,t]$(d1Y_i[i,t]) "Markup by industry."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK pricing_equations pricing_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. pY_i[i,t] =E= (1+rMarkup_i[i,t]) * pY0_i[i,t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / pricing_equations /;
$Group+ main_endogenous pricing_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group pricing_data_variables
;
# @load(pricing_data_variables, "../data/data.gdx")
$Group+ data_covered_variables pricing_data_variables;

pY_i.l[i,t] = 1;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK pricing_calibration_equations pricing_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  pricing_equations
  # pricing_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  pricing_endogenous
  pricing_calibration_endogenous
  -pY_i[i,t1], rMarkup_i[i,t1]

  calibration_endogenous
;

$GROUP+ G_flat_after_last_data_year
  rMarkup_i[i,t]
;

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
$ENDIF # tests