# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  nL[t] "Total employment."

  pL_i[i,t] "Usercost of labor, by industry."
  qL[t] "Labor in efficiency units."

  pLWedge_i[i,t] "Wedge between wage and usercost of labor (e.g. matching costs), by industry."

  pW[t] "Wage pr. efficiency unit of labor."
  qProductivity[t] "Labor augmenting productivity."
  vWages_i[i,t] "Compensation of employees by industry."
  vWages[t] "Total compensation of employees."
  vW[t] "Compensation pr. employee."
  rWageInflation[t] "Wage inflation, based on vW."

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
  .. pL_i[i,t] =E= pW[t] + pLWedge_i[i,t];

  # Mapping between efficiency units and actual employees and wages
  .. vWages_i[i,t] =E= pW[t] * qL_i[i,t];
  .. vWages[t] =E= sum(i, vWages_i[i,t]);
  .. vW[t] =E= pW[t] * qProductivity[t];

  .. rWageInflation[t] =E= vW[t] / (vW[t-1]/fv) - 1;

  # Phillips curve
  nL[t]$(not tEnd[t])..
    rWageInflation[t] =E= rWageInflation[t-1]
                        + uPhillipsCurveEmpl[t] * (nL[t] / snL[t] - 1)
                        + uPhillipsCurveExpWage[t] * (rWageInflation[t+1] - rWageInflation[t-1])
                        + jnL[t];
  nL&_tEnd[t]$(tEnd[t])..
    rWageInflation[t] =E= rWageInflation[t-1]
                        + uPhillipsCurveEmpl[t] * (nL[t] / snL[t] - 1)
                        + jnL[t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / labor_market_equations /;
$Group+ main_endogenous labor_market_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":
uPhillipsCurveEmpl.l[t] = 5;
uPhillipsCurveExpWage.l[t] = 0.3;

$Group labor_market_data_variables
  vWages_i[i,t]
  nL[t]
  vW[t]
;
$GROUP+ data_covered_variables labor_market_data_variables$(t.val <= %calibration_year%);

@load(labor_market_data_variables, "../data/data.gdx")
pW.l[t] = fpt[t];
pL_i.l[i,t] = fpt[t];
qL_i.l[i,t] = vWages_i.l[i,t];
rWageInflation.l[t] = fv-1;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK labor_market_calibration_equations labor_market_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  $(not t1[t]).. snL[t] =E= snL[t1];
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
  -nL[t1], snL[t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  qProductivity[t]
;

# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO labor_market_calibration_starting_values

$ENDIF # calibration