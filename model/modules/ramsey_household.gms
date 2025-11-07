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
  jC_ramsey[t] "Adjustment of consumption due to behavior"
  qC_ramsey[t] "Total consumption in Ramsey model"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK ramsey_household_equations ramsey_household_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
# In this module aggregate consumption is determined by the Ramsey model.
  jC_ramsey[t]$(not t1[t]).. qC[t] =E= qC_ramsey[t]; # This is the link to the rest of the model


# This is the Ramsey model for aggregate consumption
 .. qCHhxRef[t] =E= qC_ramsey[t] - rCHabit[t] * qC_ramsey[t-1]/fq - rMPC[t] * vHhIncome[t] / pC[t];
  
  .. qmuC[t] =E= (qCHhxRef[t]/qCHhxRef[tBase])**(-eCRRA);

  qC_ramsey[t]$(not tEnd[t])..
    qmuC[t] =E= pC[t]/(pC[t+1]*fp) * (1+rHh[t+1]*(1-trHh[t+1])) # Real expected return on wealth
              * qmuC[t+1]*fq**(-eCRRA) # Expected marginal utility of consumption
              * rSurvival[t] / (1+rHhDiscount[t+1]); # Survival rate and discount rate

  qC_ramsey&_tEnd[t]$(tEnd[t] and not t1[t]).. vNetFinAssets['Hh',t] =E= vNetFinAssets['Hh',t-1]; # Terminal condition
 



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


$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK ramsey_household_calibration_equations ramsey_household_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

  qC_ramsey&_t1[t]$(t1[t]).. qC_ramsey[t] =E= qC[t];

$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  ramsey_household_equations
  ramsey_household_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  ramsey_household_endogenous
  ramsey_household_calibration_endogenous

  rHhDiscount[t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  rHhDiscount[t]
;

$ENDIF # calibration