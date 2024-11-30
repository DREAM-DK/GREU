set foo /1*10/;

# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$Group+ price_variables
  pM[t] "Aggregate imports deflator."

  pC[t] "Aggregate private consumption deflator."
  pG[t] "Aggregate government consumption deflator."
  pX[t] "Aggregate exports deflator."
  pI[t] "Aggregate investments deflator."

  pGDP[t] "GDP deflator."
;
$Group+ quantity_variables
  qM[t] "Real aggregate imports."

  qC[t] "Real aggregate private consumption."
  qG[t] "Real aggregate government consumption."
  qX[t] "Real aggregate exports."
  qI[t] "Real aggregate investments."

  qGDP[t] "Real GDP."

  qTest[foo,t]$(foo.val > 5) "Test var"
;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK test_module $(t1.val <= t.val and t.val <= tEnd.val)
  qTest[foo,t]$(t.val>6).. qTest[foo,t] =E= 1;

  pGDP[t].. pGDP[t] * qGDP[t] =E= pC[t] * qC[t]
                                + pG[t] * qG[t]
                                + pI[t] * qI[t]
                                + pX[t] * qX[t]
                                - pM[t] * qM[t];

  qGDP[t].. pGDP[t-1]/fp * qGDP[t] =E= pC[t-1]/fp * qC[t]
                                     + pG[t-1]/fp * qG[t]
                                     + pI[t-1]/fp * qI[t]
                                     + pX[t-1]/fp * qX[t]
                                     - pM[t-1]/fp * qM[t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / test_module_equations /;
$Group+ main_endogenous test_module_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$Group test_module_data_variables
  pC, qC
  pG, qG
  pI, qI
  pX, qX

  pM, qM

  pGDP, qGDP
;
@load(test_module_data_variables, "../data/MAKRO_data.gdx");
$Group+ data_covered_variables test_module_data_variables;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK test_module_calibration
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  test_module_equations
  # test_module_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  test_module_calibration_endogenous
  test_module_endogenous
  -pGDP[tBase], pGDP[t0]

  calibration_endogenous
;