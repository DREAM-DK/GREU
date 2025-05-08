# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  eCRRA "Coefficient of relative risk aversion."
  rHhDiscount[t] "Discount rate for households."
  qmuC[t] "Marginal utility of consumption."
  rCHabit[t] "Habit formation parameter."
  qCHhxRef[t] "Private consumption net of habits and Keynesian consumption."
  rSurvival[t] "Survival rate."
  qCHh[t] "Private consumption of households."
  pCHh[t] "Usercost of private consumption of households."
  jqChh_ctot[t] "J-term to be endogenized when CES-utility in households_CES_demand.gms is turned on"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK ramsey_household_equations ramsey_household_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. qCHhxRef[t] =E= qCHh[t] - rCHabit[t] * qCHh[t-1]/fq - rMPC[t] * vHhIncome[t] / pCHh[t];

  # Will be replaced by CES utility function
  .. qCHh[t] =E= sum(c, qD[c,t]) + jqChh_ctot[t];
  .. pCHh[t] * qCHh[t] =E= sum(c, vD[c,t]);

  .. qmuC[t] =E= (qCHhxRef[t]/qCHhxRef[tBase])**(-eCRRA);

  rMPCW[t]$(not tEnd[t])..
    qmuC[t] =E= pCHh[t]/(pCHh[t+1]*fp) * (1+mrHhReturn[t+1]) # Real expected return on wealth
              * qmuC[t+1]*fq**(-eCRRA) # Expected marginal utility of consumption
              * rSurvival[t] / (1+rHhDiscount[t+1]); # Survival rate and discount rate
  rMPCW&_tEnd[t]$(tEnd[t] and not t1[t]).. rMPCW[t] =E= rMPCW[t-1];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / ramsey_household_equations /;
$Group+ main_endogenous ramsey_household_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

eCRRA.l = 1/0.8;
rSurvival.l[t] = 0.993;
rHhDiscount.l[t] = 1.04 / fp - 1;

# $Group ramsey_household_data_variables ;
# @load(ramsey_household_data_variables, "../data/data.gdx")
# $Group+ data_covered_variables ramsey_household_data_variables$(t.val <= %calibration_year%);

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK ramsey_household_calibration_equations ramsey_household_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  ramsey_household_equations
  # ramsey_household_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  ramsey_household_endogenous
  ramsey_household_calibration_endogenous
  -rMPCW[t1], rHhDiscount[t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  rHhDiscount[t]
;

$ENDIF # calibration