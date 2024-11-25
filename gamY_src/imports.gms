# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
# Variables used from other modules:
# input-output: pY_i_d, pM_i_d, qM_i_d, qY_i_d, rM

$GROUP+ price_variables ;
$GROUP+ quantity_variables ;
$GROUP+ other_variables
  eM[i,d] "Elasticity of substitution between domestic and imported goods."
  uM[i,d,t]$(d1Y_i_d[i,d,t] and d1M_i_d[i,d,t]) "Import share parameter. Equal to import share when relative price is 1."
  pY2pM_i_d[i,d,t]$(d1Y_i_d[i,d,t] and d1M_i_d[i,d,t]) "Relative price of imports to domestic output."
;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK imports_equations imports_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  ..
    pY2pM_i_d[i,d,t] =E= pY_i_d[i,d,t] / pM_i_d[i,d,t];

  rM[i,d,t]$(d1Y_i_d[i,d,t] and d1M_i_d[i,d,t])..
    qM_i_d[i,d,t] * (1-uM[i,d,t]) =E= qY_i_d[i,d,t] * uM[i,d,t] * pY2pM_i_d[i,d,t]**eM[i,d];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / imports_equations /;
$GROUP+ main_endogenous imports_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP imports_data_variables
;
# @load(imports_data_variables, "../data/data.gdx")
# $GROUP data_covered_variables data_covered_variables, imports_data_variables;
eM.l[i,d] = 2;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK imports_calibration_equations imports_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  imports_equations
  # imports_calibration_equations
/;
# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  imports_endogenous
  imports_calibration_endogenous
  -rM[i,d,t], uM[i,d,t]

  calibration_endogenous
;
