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

  vGovPrimaryBalance[t] "Primary balance of government."
  vGovRevenue[t] "Revenue of government."
  vGovExpenditure[t] "Expenditure of government."
  vGovRevenue_fromPublicProduction[t] "Revenue from public production."
  vLumpsum[t] ""
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK government_equations government_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # Government consumption expenditure to GDP ratio
  rG_g[g,t]$(first(g)).. vG[t] =E= vG2vGDP[t] * vGDP[t];
  qD[g,t].. vD[g,t] =E= rG_g[g,t] * vG[t];

  .. vHhTaxes[t] =E= vHhTaxes2vGDP[t] * vGDP[t];


  .. vGovPrimaryBalance[t] =E= vGovRevenue[t] - vGovExpenditure[t];


  .. vGovRevenue[t] =E=   vtY[t] + vtM[t] # Net duties, paid through R, E, I, C, G, and X
                        + vtY_Tax[t]  - vtCO2_ETS_tot[t] #Production taxes minus ETS-revenue
                        # + sum(i,vtCO2e[i,t])
                        + vHhTaxes[t] + vCorpTaxes[t]
                        + vGovRevenue_fromPublicProduction[t];


  .. vGovExpenditure[t] =E= vG[t] + vHhTransfers[t] + vtY_Sub[t] + vLumpsum[t];

  .. vGovRevenue_fromPublicProduction[t] =E= sum(i$i_public[i], vEBITDA_i[i,t]) - vI_public[t];


$ENDBLOCK

# Add equation and endogenous variables to main model
model main / government_equations /;
$Group+ main_endogenous government_endogenous;

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

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK government_calibration_equations government_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # We assume a balanced budget in the baseline for now, adjusting taxes to keep debt-to-GDP ratio constant
  vHhTaxes2vGDP[t].. vNetFinAssets['Gov',t] / vGDP[t] =E= 0;#vNetFinAssets['Gov',t-1] / vGDP[t-1];
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  government_equations
  government_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  government_endogenous
  government_calibration_endogenous
  -qD[g,t1], rG_g[g,t1], vG2vGDP[t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  vG2vGDP[t]
  rG_g[c,t]
;

$ENDIF # calibration