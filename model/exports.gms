# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  eX[x] "Price elasticity of export demand."
  pRoW_x[x,t] "Price index of goods from the rest of the world competing with exports."
  pX2pRoW_x[x,t] "Ratio of export prices and competing goods from the rest of the world."
  qXMarket[x,t] "Market size for exports of type x."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK exports_market_equations exports_market_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. qD[x,t] =E= pX2pRoW_x[x,t]**(-eX[x]) * qXMarket[x,t];
  .. pX2pRoW_x[x,t] =E= pD[x,t] / pRoW_x[x,t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / exports_market_equations /;
$Group+ main_endogenous exports_market_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":
eX.l[x] = 0.5;
pRoW_x.l[x,t] = 1;

$Group exports_market_data_variables
  qD[x,t]
;
@load(exports_market_data_variables, "../data/data.gdx")
$GROUP+ data_covered_variables exports_market_data_variables$(t.val <= %calibration_year%);

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK exports_market_calibration_equations exports_market_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  exports_market_equations
  # exports_market_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  exports_market_calibration_endogenous
  exports_market_endogenous
  -qD[x,t1], qXMarket[x,t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  qXMarket[t]
;

$ENDIF # equations