# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  eM_i_d[i,d] "Elasticity of substitution between domestic and imported goods."
  rM0[i,d,t]$(d1Y_i_d[i,d,t] and d1M_i_d[i,d,t]) "Import share parameter. Equal to import share when relative price is 1."
  pY2pM_i_d[i,d,t]$(d1Y_i_d[i,d,t] and d1M_i_d[i,d,t]) "Relative price of imports to domestic output."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK imports_equations imports_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. pY2pM_i_d[i,d,t] =E= pY_i_d[i,d,t] / pM_i_d[i,d,t];

  rM[i,d,t]$(d1Y_i_d[i,d,t] and d1M_i_d[i,d,t])..
    qM_i_d[i,d,t] * (1-rM0[i,d,t]) =E= qY_i_d[i,d,t] * rM0[i,d,t] * pY2pM_i_d[i,d,t] **eM_i_d[i,d];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / imports_equations /;
$Group+ main_endogenous imports_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

# $Group imports_data_variables
# ;
# @load(imports_data_variables, %path_data%)
# $Group+ data_covered_variables imports_data_variables;
eM_i_d.l[i,d] = 2;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK imports_calibration_equations imports_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  imports_equations
  # imports_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  imports_endogenous
  imports_calibration_endogenous
  -rM[i,d,t1], rM0[i,d,t1]

  calibration_endogenous
;

$GROUP+ G_flat_after_last_data_year
  rM0[i,d,t]
;

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
$ENDIF # tests