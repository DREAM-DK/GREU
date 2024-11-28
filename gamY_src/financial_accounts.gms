# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vNetFinAssets[sector,t] "Net financial assets by sector."
  vNetInterests[sector,t] "Interests by sector."

  rInterests[t] "Interest rate."
  rInterests_s[sector,t] "Interest rate by sector."
  jrInterests_s[sector,t] "Deviation from average interest rate by sector."

  vNetRevaluations[sector,t] "Revaluations by sector."
  rRevaluations_s[t] "Revaluations rate."

  # vTransfers[from_sector,to_sector,t] "Transfers between sectors."
  # vTransfersTo[sector,t] "Total transfers to sector."
  # vTransfersFrom[sector,t] "Total transfers from sector."

  # Will be moved to other modules:
  vG[t] "Government consumption."
  vHhTaxes[t] "Taxes on income and wealth of households and non-profits."
  vHhTransfers[t] "Transfers to households and non-profits from government."
  vCorpTaxes[t] "Taxes on corporations, excluding net duties paid through investments and intermediate goods purchases."
  vX[t] "Exports."
  vI_i[i,t] "Investments by industry."
  vR_i[i,t] "Non-energy intermediate goods purchases by industry."
  vE_i[i,t] "Energy intermediate goods purchases by industry."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK financial_equations financial_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. vNetFinAssets[Hh,t] =E= vNetFinAssets[Hh,t-1]/fv
                           + vNetInterests[Hh,t]
                           + vNetRevaluations[Hh,t]
                           + vWages[t] + vHhTransfers[t]
                           - vC[t]
                           - vHhTaxes[t];

  .. vNetFinAssets[Corp,t] =E= vNetFinAssets[Corp,t-1]/fv
                             + vNetInterests[Corp,t] + vNetRevaluations[Corp,t]
                             - sum(i$i_private[i], vY_i[i,t] - vR_i[i,t] - vE_i[i,t] - vWages_i[i,t] - vI_i[i,t])
                             - vCorpTaxes[t];

  .. vNetFinAssets[Gov,t] =E= vNetFinAssets[Gov,t-1]/fv
                            + vNetInterests[Gov,t] + vNetRevaluations[Gov,t]
                            - vG[t] - vHhTransfers[t]
                            + sum(i$i_public[i], vY_i[i,t] - vR_i[i,t] - vE_i[i,t] - vWages_i[i,t] - vI_i[i,t])
                            + vtY[t] + vtM[t] # Net duties, paid through R, E, I, C, G, and X
                            + vHhTaxes[t] + vCorpTaxes[t];

  .. vNetFinAssets[RoW,t] =E= vNetFinAssets[RoW,t-1]/fv
                            + vNetInterests[RoW,t]
                            + vNetRevaluations[RoW,t]
                            + vM[t]
                            - vX[t];

  # .. vGVA_i[i,t] =E= vY_i[i,t] - vR_i[i,t] - vE_i[i,t];

  .. vNetInterests[sector,t] =E= rInterests_s[sector,t] * vNetFinAssets[sector,t-1]/fv;
  .. vNetRevaluations[sector,t] =E= rRevaluations_s[t] * vNetFinAssets[sector,t-1]/fv;

  .. rInterests_s[sector,t] =E= rInterests[t] + jrInterests_s[sector,t];

  # Interests of sectors sum to zero. Rest of World is residual.
  jrInterests_s[RoW,t].. sum(sector, vNetInterests[sector,t]) =E= 0; 
$ENDBLOCK

# Add equation and endogenous variables to main model
model main / financial_equations /;
$Group+ main_endogenous financial_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$Group financial_data_variables
  vNetFinAssets[sector,t]
  vNetInterests[sector,t]
  vNetRevaluations[sector,t]
  rInterests[t]
;
# @load(financial_data_variables, "../data/data.gdx")
$Group+ data_covered_variables financial_data_variables;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

$BLOCK financial_calibration_equations financial_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  financial_equations
  # financial_calibration_equations
/;
# Add endogenous variables to calibration model
$Group calibration_endogenous
  financial_endogenous
  financial_calibration_endogenous
  -vNetInterests[sector,t1]$(not RoW[sector]), jrInterests_s[sector,t1]
  -vNetRevaluations[sector,t1], rRevaluations_s[t1]

  calibration_endogenous
;

$ENDIF # calibration