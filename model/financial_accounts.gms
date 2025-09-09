# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  vNetFinAssets[sector,t] "Net financial assets by sector."
  vNetDebtInstruments[sector,t] "Net debt instruments by sector."
  vNetEquity[sector,t] "Net equity instruments by sector."

  vNetInterests[sector,t] "Net interests received by sector."
  rInterests[t] "Interest rate."
  rInterests_s[sector,t] "Interest rate by sector."
  jrInterests_s[sector,t] "Deviation from average interest rate by sector."

  vNetRevaluations[sector,t] "Revaluations by sector."
  rRevaluations_s[sector,t] "Revaluations rate."

  vNetDividends[sector,t] "Net dividends received by sector."
  rDividends[t] "Dividends rate."

  # vTransfers[from_sector,to_sector,t] "Transfers between sectors."
  # vTransfersTo[sector,t] "Total transfers to sector."
  # vTransfersFrom[sector,t] "Total transfers from sector."

  # Will be moved to other modules:
  vEBITDA_i[i,t] "Earnings before interests, taxes, depreciation, and amortization by industry."
  vHhTaxes[t] "Taxes on income and wealth of households and non-profits."
  vHhTransfers[t] "Transfers to households and non-profits from government."
  vCorpTaxes[t] "Taxes on corporations, excluding net duties paid through investments and intermediate goods purchases."
  vI_private[t] "Total capital investments in private sector."
  vI_public[t] "Total capital investments in public sector."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK financial_equations financial_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. vI_private[t] =E= sum(i$i_private[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + vInvt_ene_i[i,t]);
  .. vI_public[t] =E= sum(i$i_public[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + vInvt_ene_i[i,t]);

  .. vNetFinAssets[Hh,t] =E= vNetFinAssets[Hh,t-1]/fv
                           + vNetInterests[Hh,t] + vNetDividends[hh,t] + vNetRevaluations[Hh,t]
                           + vWages[t]
                           + vHhTransfers[t]
                           + vLumpsum[t]
                           - vC[t]
                           - vHhTaxes[t];

  .. vNetFinAssets[Corp,t] =E= vNetFinAssets[Corp,t-1]/fv
                             + vNetInterests[Corp,t] + vNetDividends[corp,t] + vNetRevaluations[Corp,t]
                             + sum(i$i_private[i], vEBITDA_i[i,t]) - vI_private[t]
                             - vCorpTaxes[t];

  .. vNetFinAssets[Gov,t] =E= vNetFinAssets[Gov,t-1]/fv
                            + vNetInterests[Gov,t] + vNetDividends[Gov,t] + vNetRevaluations[Gov,t]
                            + vGovPrimaryBalance[t];

  .. vNetFinAssets[RoW,t] =E= vNetFinAssets[RoW,t-1]/fv
                            + vNetInterests[RoW,t] + vNetDividends[RoW,t] + vNetRevaluations[RoW,t]
                            + vM[t]
                            - vX[t]
                            + vtCO2_ETS_tot[t];

  .. vEBITDA_i[i,t] =E= vY_i[i,t] - vWages_i[i,t] - vD[i,t] - vE_i[i,t] - vtY_i_NetTaxSub[i,t] - vtCO2e_non_energy[i,t]; # Net duties should be subtracted here - AKB: What? They are contained in vD and vE_i

  # For now, we assume that households own all domestic equity going forward
  .. vNetEquity[Gov,t] =E= 0;
  .. vNetEquity[RoW,t] =E= 0;
  .. vNetEquity[Hh,t] =E= -vNetEquity['Corp',t];
  # And we set corporate debt to zero
  vNetEquity[Corp,t].. vNetDebtInstruments['Corp',t] =E= 0;

  # Debt instruments are residual given net financial assets and equity
  .. vNetDebtInstruments[sector,t] =E= vNetFinAssets[sector,t] - vNetEquity[sector,t];

  # Fow now we assume that corporations pay out any excess cash as dividends (issue stocks)
  # And we do not calculate value of the firm for endogenous revaluations
  rDividends[t]..
    -vNetDividends['Corp',t] =E= sum(i$i_private[i], vEBITDA_i[i,t]) - vI_private[t]
                               + vNetInterests['Corp',t] # is negative
                               - vCorpTaxes[t]
                               - (vNetDebtInstruments['Corp',t] - vNetDebtInstruments['Corp',t-1]/fv); # Purchasing securities or repaying debt (issuing debt or selling securities)

    # For now assume no non-domestic equities
  .. vNetDividends[sector,t] =E= rDividends[t] * vNetEquity[sector,t-1]/fv;

  .. vNetInterests[sector,t] =E= rInterests_s[sector,t] * vNetDebtInstruments[sector,t-1]/fv;
  .. vNetRevaluations[sector,t] =E= rRevaluations_s[sector,t] * vNetFinAssets[sector,t-1]/fv;

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
;

# We use rough values for financial accounts based on MAKRO for now
vNetDebtInstruments.l['Hh',t] = 670;
vNetDebtInstruments.l['Corp',t] = 200;
vNetDebtInstruments.l['Gov',t] = -440;
vNetDebtInstruments.l['RoW',t] = -sum(sector, vNetDebtInstruments.l[sector,t]);

vNetFinAssets.l['Hh',t] = 6690;
vNetFinAssets.l['Corp',t] = -5570;
vNetFinAssets.l['Gov',t] = 270;
vNetFinAssets.l['RoW',t] = - sum(sector, vNetFinAssets.l[sector,t]);

vNetEquity.l[sector,t] = vNetFinAssets.l[sector,t] - vNetDebtInstruments.l[sector,t];

# And set interests to 4% for all sectors, and revaluations to zero
rInterests.l[t] = 0.04;
vNetInterests.l[sector,t] = rInterests.l[t] * vNetDebtInstruments.l[sector,t-1];

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
  -vNetRevaluations[sector,t1], rRevaluations_s[sector,t1]

  calibration_endogenous
;

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
  parameter test_sector_balance[t];
  $FOR {var} in ["vNetInterests", "vNetDividends", "vNetRevaluations", "vNetDebtInstruments", "vNetEquity", "vNetFinAssets"]:
    test_sector_balance[t] = abs(sum(sector, {var}.l[sector,t]));
    ABORT$(smax(t, test_sector_balance[t]) > 1e-6) "{var} do not sum to zero.", test_sector_balance;
  $ENDFOR
$ENDIF # tests