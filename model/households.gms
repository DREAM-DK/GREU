# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vHhIncome[t] "Household income."

  vC[t] "Household and non-profit (NPISH) consumption expenditure."

  rMPC[t] "Marginal propensity to consume out of income."
  rMPCW[t] "Marginal propensity to consume out of wealth."
  rC_c[c,t] "Share of total consumption expenditure by purpose."

  vNetInterests[sector,t] "Interests by sector."
  vNetRevaluations[sector,t] "Revaluations by sector."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK households_equations households_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  rC_c[c,t]$(first(c)).. vC[t] =E= rMPC[t] * vHhIncome[t] + rMPCW[t] * vNetFinAssets['Hh',t-1]/fv;

  # Link to input-output model - households choose private consumption by purpose
  qD[c,t].. vD[c,t] =E= rC_c[c,t] * vC[t];

  .. vHhIncome[t] =E= vWages[t]
                    + vHhTransfers[t]
                    - vHhTaxes[t]
                    + vNetInterests['Hh',t] + vNetRevaluations['Hh',t];
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / households_equations /;
$Group+ main_endogenous households_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

rMPC.l[t] = 0.5;

$Group households_data_variables
  qD[c,t]
;
@load(households_data_variables, "../data/data.gdx")
$Group+ data_covered_variables households_data_variables$(t.val <= %calibration_year%);

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK households_calibration_equations households_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  households_equations
  # households_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  households_endogenous
  households_calibration_endogenous
  -qD[c,t1], rC_c[c,t1], rMPCW[t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  rMPCW[t]
  rC_c[c,t]
;

$ENDIF # calibration