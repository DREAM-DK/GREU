# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  submodel_template_test_variable[t] "Test variable from submodel template."
  test_scalar "Test variable with no indices."
  test_constant[i] "Test variable with no time index."

  pY[t] "Output price"
  pX[t] "Price of x"
  pZ[t] "Price of z"

  qY[t] "Output quantity"
  qX[t] "Quantity of x"
  qZ[t] "Quantity of z"

  mu_x[t] "CES-share for x"
  mu_z[t] "CES-share for z"
  sY[t] "CES-share for output"

  Elas "Elasticity of substitution between x and z"
  ED "Elasticity of demand for output"
;

#We add parameters that, efter static calibration, should be assigned same value for all years
$Group+ G_flat_after_last_data_year 
  mu_x 
  mu_z
  sY
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK template_equations template_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. submodel_template_test_variable[t] =E= 1;

  .. qX[t] =E= mu_x[t] * (pX[t]/pY[t])**(-Elas) * qY[t];
    
  .. qZ[t] =E= mu_z[t] * (pZ[t]/pY[t])**(-Elas) * qY[t];

  .. pY[t] * qY[t] =E= pX[t]*qX[t] + pZ[t] * qZ[t];

  .. qY[t] =E= sY[t] * pY[t]**(-ED);
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
  submodel_template_test_variable[t]
;
# @load(template_data_variables, "../data/data.gdx")
submodel_template_test_variable.l[t] = 1;
$Group+ data_covered_variables template_data_variables;


pY.l[t] =1;
qY.l[t] =1;
pX.l[t] = 1;
qX.l[t] = 0.25;
pZ.l[t] = 1;
qZ.l[t] = 0.75;
Elas.l = 0.5;

ED.l = 2.5;


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
  -qX[t1], mu_x[t1]
  -qZ[t1], mu_z[t1]
  -qY[t1], sY[t1]

  calibration_endogenous
;

$ENDIF # calibration