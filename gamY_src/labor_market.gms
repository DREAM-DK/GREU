# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  nL[t] "Total employment."

  pL[t] "Usercost of labor."
  qL[t] "Labor in efficiency units."
  qL_i[i,t] "Labor in efficiency units by industry."

  pLWedge[t] "Wedge between wage and usercost of labor (e.g. matching costs)."

  pW[t] "Wage pr. efficiency unit of labor."
  qProductivity[t] "Labor augmenting productivity."
  vWages_i[i,t] "Compensation of employees by industry."
  vWages[t] "Total compensation of employees."
  vW[t] "Compensation pr. employee."

  # Phillips curve
  snL[t] "Structural employment."
  uPhillipsCurveEmpl[t] "Sensitivity of wages to deviations from structural employment."
  uPhillipsCurveExpWage[t] "Sensitivity of wages to expected future wages."
  jnL[t] "Deviations from Phillips curve. Can be used to override the Phillips curve model."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK labor_market_equations labor_market_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Aggregating labor demand from industries
  .. qL[t] =E= sum(i, qL_i[i,t]);

  # Equilibrium condition: labor demand = labor supply
  pW[t].. qL[t] =E= qProductivity[t] * nL[t];

  # Usercost of labor is wage + any frictions
  .. pL[t] =E= pW[t] + pLWedge[t];

  # Mapping between efficiency units and actual employees and wages
  .. vWages_i[i,t] =E= pW[t] * qL_i[i,t];
  .. vWages[t] =E= sum(i, vWages_i[i,t]);
  .. vW[t] =E= pW[t] * qProductivity[t];

  # Phillips curve
  nL[t]$(not tEnd[t])..
    pW[t] / pW[t-1]*fp =E= uPhillipsCurveEmpl[t] * nL[t] / snL[t]
                         + uPhillipsCurveExpWage[t] * pW[t+1]*fp / pW[t]
                         + jnL[t];
  nL&_tEnd[t]$(tEnd[t]).. nL[t] =E= snL[t] + jnL[t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / labor_market_equations /;
$Group+ main_endogenous labor_market_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":
uPhillipsCurveEmpl.l[t] = 0.5;
uPhillipsCurveExpWage.l[t] = 0.3;

$Group labor_market_data_variables
  vWages_i[i,t]
  nL[t]
  vW[t]
;
$GROUP+ data_covered_variables labor_market_data_variables$(t.val <= %calibration_year%);

@load(labor_market_data_variables, "../data/data.gdx")
pW.l[t] = fpt[t];

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK labor_market_calibration_equations labor_market_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  labor_market_equations
  # labor_market_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  labor_market_calibration_endogenous
  labor_market_endogenous
  -vWages_i[i,t1], qL_i[i,t1]
  -pW[t1], qProductivity[t1]
  -nL[t], snL[t]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  qProductivity[t]
;

$ENDIF # equations