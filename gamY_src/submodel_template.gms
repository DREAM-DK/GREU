# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$GROUP+ price_variables
;
$GROUP+ quantity_variables
;
$GROUP+ other_variables
;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK template $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / template_equations /;
$GROUP+ main_endogenous template_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP template_data_variables
;
@load(template_data_variables, "../data/data.gdx")
$GROUP data_covered_variables data_covered_variables, template_data_variables;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK template_calibration $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  template_equations
  template_calibration_equations
/;
# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  template_calibration_endogenous
  template_endogenous

  calibration_endogenous
;