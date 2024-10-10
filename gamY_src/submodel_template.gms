# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$GROUP price_variables price_variables
;
$GROUP quantity_variables quantity_variables
;
$GROUP value_variables quantity_variables
;
$GROUP other_variables other_variables
;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP template_data_variables
;
# @load(template_data_variables, "../data/data.gdx")
$GROUP data_covered_variables data_covered_variables, template_data_variables;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK template
$ENDBLOCK

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK template_calibration
$ENDBLOCK

$GROUP template_calibration_endogenous
  template_endogenous
  template_calibration_endogenous
;

# model template_calibration_model /
#   template_equations
#   template_calibration_equations
# /;