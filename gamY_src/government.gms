# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vG[t] "Government consumption expenditure."
  rG_g[g,t] "Share of total government consumption expenditure by purpose."
  vG2vGDP[t] "Government consumption expenditure to GDP ratio."

  vHhTaxes[t] "Taxes on income and wealth of households and non-profits."
  vHhTransfers[t] "Transfers to households and non-profits from government."
  vHhTaxes2vGDP[t] "Household taxes to GDP ratio"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK government_equations government_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Government consumption expenditure to GDP ratio
  qD&_Gtotal[g,t]$(first(g)).. vG[t] =E= vG2vGDP[t] * vGDP[t];
  qD[g,t]$(not first(g)).. vD[g,t] =E= rG_g[g,t] * vG[t];

  vHhTaxes[t].. vHhTaxes[t] =E= vHhTaxes2vGDP[t] * vGDP[t];
$ENDBLOCK

# Add equation and endogenous variables to main model
# model main / government_equations /;
# $Group+ main_endogenous government_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group government_data_variables
  qD[g,t]
;
@load(government_data_variables, "../data/data.gdx")
$Group+ data_covered_variables government_data_variables$(t.val <= %calibration_year%);
vHhTaxes2vGDP.l[t] = 0.0;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK government_calibration_equations government_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
# model calibration /
#   government_equations
#   # government_calibration_equations
# /;
# # Add endogenous variables to calibration model
# $Group calibration_endogenous
#   government_endogenous
#   government_calibration_endogenous
#   -qD[g,t1], rG_g[g,t1], vG2vGDP[t1]
#   # -vHhTaxes[t1], vHhTaxes2vGDP[t1]

#   calibration_endogenous
# ;

$Group G_flat_after_last_data_year
  vG2vGDP[t]
  rG_g[c,t]
;

$ENDIF # calibration