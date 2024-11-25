# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK template_equations template_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / template_equations /;
$Group+ main_endogenous template_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group template_data_variables
;
@load(template_data_variables, "../data/data.gdx")
$Group+ data_covered_variables template_data_variables;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK template_calibration_equations template_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  template_equations
  template_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  template_calibration_endogenous
  template_endogenous

  calibration_endogenous
;

$ENDIF # calibration