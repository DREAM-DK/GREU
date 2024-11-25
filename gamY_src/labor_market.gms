# ------------------------------------------------------------------------------
# Variable definitions
# ------------------------------------------------------------------------------
$Group+ price_variables
  pL[t] "Usercost of labor."
  pW[t] "Wage pr. efficiency unit of labor."
  pLfrictions[t] "Effect of real and nominal frictions on usercost of labor."
;
$Group+ quantity_variables
  qProductivity[t] "Labor augmenting productivity."
  qL[t] "Labor in efficiency units."
  qL_i[i,t] "Labor in efficiency units by industry."
  qLfrictions[t] "Effect of real frictions on efficiency units of labor"
;
$Group+ value_variables
  vWages_i[i,t] "Compensation of employees by industry."
;
$Group+ other_variables
  nL[t] "Total employment."
;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK labor_market labor_market_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Aggregating labor demand from industries
  qL[t].. qL[t] =E= sum(i, qL_i[i,t]);

  # Equilibrium condition: labor demand = labor supply
  pW[t].. qL[t] =E= qProductivity[t] * nL[t] - qLfrictions[t];

  # Usercost of labor is wage + any frictions
  pL[t].. pL[t] =E= pW[t] + pLfrictions[t];

  # Mapping between efficiency units and actual employees and wages
  vWages_i[i,t].. vWages_i[i,t] =E= pW[t] * qL_i[i,t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / labor_market_equations /;
$Group+ main_endogenous labor_market_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$Group labor_market_data_variables
  vWages_i[i,t]
  nL[t]
;
@load(labor_market_data_variables, "../data/data.gdx")

pW.l[tBase] = 1;

$Group+ data_covered_variables
  labor_market_data_variables
;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$BLOCK labor_market_calibration labor_market_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  qProductivity[t]$(t.val > t1.val).. qProductivity[t] =E= qProductivity[t1];
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  labor_market_equations
  labor_market_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  labor_market_calibration_endogenous
  labor_market_endogenous
  -vWages_i[i,t1], qL_i[i,t1]
  -pW[t1], qProductivity[t1]

  calibration_endogenous
;