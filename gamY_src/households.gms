# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vHhIncome[t] "Household income."

  vC[t] "Household and non-profit (NPISH) consumption expenditure."

  rC[t] "Consumption to income ratio."
  rC_c[c,t] "Share of total consumption expenditure by purpose."

  vHhTaxes[t] "Taxes on income and wealth of households and non-profits."
  vHhTransfers[t] "Transfers to households and non-profits from government."
  vNetInterests[sector,t] "Interests by sector."
  vNetRevaluations[sector,t] "Revaluations by sector."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK households_equations households_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. vC[t] =E= rC[t] * vHhIncome[t];

  # Link to input-output model - households choose private consumption by purpose
  .. vD_d[c,t] =E= rC_c[c,t] * vC[t];

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

$Group households_data_variables
;
# @load(households_data_variables, "../data/data.gdx")
$Group+ data_covered_variables households_data_variables;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK households_calibration_equations households_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  rC[t]$(t1[t]).. sum(c, rC_c[c,t]) =E= 1;
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  households_equations
  households_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  households_endogenous
  households_calibration_endogenous
  -vD_d[c,t1], rC_c[c,t1]

  calibration_endogenous
;

$Group G_flat_after_last_data_year
  rC[t]
  rC_c[c,t]
;

$ENDIF # calibration