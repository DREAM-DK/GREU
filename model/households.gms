# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vHhIncome[t] "Household income."
  vC_CMP[t] "Household consumption with constant marginal propensities"
  rMPC[t] "Marginal propensity to consume out of income."
  rMPCW[t] "Marginal propensity to consume out of wealth."
  rC_c[c,t] "Share of total consumption expenditure by purpose."

  vNetInterests[sector,t] "Interests by sector."
  vNetRevaluations[sector,t] "Revaluations by sector."

  mrHhReturn[t] "Expected marginal after-tax return on household wealth."
  vC_WalrasLaw[t] "Equal to zero implying that Walras law regarding the sum of demand for private consumption equal to the sum of supply of private consumption is fulfilled."

;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK households_equations households_endogenous $(t1.val <= t.val and t.val <= tEnd.val)


# In this modul we have a simple aggregate consumption function with constant marginal propensities
  .. vC_CMP[t] =E= rMPC[t] * vHhIncome[t] + rMPCW[t] * vNetFinAssets['Hh',t-1]/fv;

  .. vHhIncome[t] =E= vWages[t]
                    + vHhTransfers[t] + vLumpsum[t]
                    - vHhTaxes[t]
                    + vNetInterests['Hh',t] + vNetRevaluations['Hh',t];

#  and a simple disaggregated consumption function with constant share of total consumption by purpose
  qD[c,t]$(not t1[t]).. vD[c,t]/vC[t] =E= vD[c,t-1]/vC[t-1] + jD_c[c,t];

# When consumption is determined in other modules the j-terms becomes endogenous
  vC_WalrasLaw[t]$(not t1[t]).. vC[t] =E= vC_CMP[t] + jC_ramsey[t];
  # vC_WalrasLaw[t].. vC[t] =E= vC_CMP[t] + jC_ramsey[t];


  # Marginal return is calculated ex-ante
  # and not in the first period, where information shocks can cause realized returns to differ from expectations
  # $(not t1[t])..
  #   mrHhReturn[t] =E= (vNetDividends["Hh",t] + vNetInterests["Hh",t]) / (vNetFinAssets["Hh",t-1]/fv);
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / households_equations /;
$Group+ main_endogenous households_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

rMPC.l[t] = 0.4;

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
  rMPCW[t]$(t1[t]).. vC_CMP[t] =E= vC[t];
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  households_equations
  households_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  households_endogenous

  rMPCW[t1]
  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  rMPCW[t]
;

$ENDIF # calibration