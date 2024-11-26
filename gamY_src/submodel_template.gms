# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  submodel_template_test_variable[t] "Test variable from submodel template."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK template_equations template_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. submodel_template_test_variable[t] =E= 1;
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
  submodel_template_test_variable
;
# @load(template_data_variables, "../data/data.gdx")
submodel_template_test_variable.l[t] = 1;
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
  # template_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  template_endogenous
  template_calibration_endogenous

  calibration_endogenous
;

$ENDIF # calibration