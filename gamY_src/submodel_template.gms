# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$GROUP price_variables price_variables
  empty_group_dummy[t]
;
$GROUP quantity_variables quantity_variables
  empty_group_dummy[t]
;
$GROUP value_variables quantity_variables
  empty_group_dummy[t]
;
$GROUP other_variables other_variables
  empty_group_dummy[t]
;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP template_data_variables
  empty_group_dummy[t]
;
@load(template_data_variables, "../data/data.gdx")


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK template
$ENDBLOCK

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK template_calibration
  empty_group_dummy[t]$(0).. 0 =E= 0;
$ENDBLOCK

$GROUP template_calibration_endogenous
  template_endogenous
  template_calibration_endogenous
;

model template_calibration_model /
  template_equations
  template_calibration_equations
/;