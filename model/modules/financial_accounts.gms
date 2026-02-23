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
  rHh[t] "Return on household wealth."  

  rFinCorpDebt2Equity[t] "Financial corporate debt to net equity ratio."
  rNonFinCorpDebt2Equity[t] "Non-financial corporate debt to net equity ratio."
  rHhEquity2FinAssets[t] "Household equity (shares) to net financial assets ratio."

  # Will be moved to other modules:
  vEBITDA_i[i,t] "Earnings before interests, taxes, depreciation, and amortization by industry."
  vI_private_fin[t] "Total capital investments in private financial sector."
  vI_private_nonfin[t] "Total capital investments in private non-financial sector."
  vI_private[t] "Total capital investments in private sector."
  vI_public[t] "Total capital investments in public sector."

  # J-terms for energy-specific variables (endogenized by factor_demand module when energy is active)
  jvInvt_ene_i[i,t] "Energy inventory investments (endogenized by factor_demand module when energy is active)."
  jvE_i[i,t] "Energy inputs by industry (endogenized by factor_demand module when energy is active)."
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK financial_equations financial_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  .. vI_private[t] =E= sum(i$i_private[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);
  .. vI_private_nonfin[t] =E= sum(i$i_private_nonfin[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);
  .. vI_private_fin[t] =E= sum(i$i_private_fin[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);
  .. vI_public[t] =E= sum(i$i_public[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);

  .. vNetFinAssets[Hh,t] =E= vNetFinAssets[Hh,t-1]/fv
                           + vNetInterests[Hh,t] + vNetDividends[Hh,t] + vNetRevaluations[Hh,t]
                           + vWages[t]
                           - vC[t]
                           - vNetHh2Gov[t]
                           ;

  .. vNetFinAssets[NonFinCorp,t] =E= vNetFinAssets[NonFinCorp,t-1]/fv
                             + vNetInterests[NonFinCorp,t] + vNetDividends[NonFinCorp,t] + vNetRevaluations[NonFinCorp,t]
                             + sum(i$i_private_nonfin[i], vEBITDA_i[i,t]) - vI_private_nonfin[t]
                             ;

  .. vNetFinAssets[FinCorp,t] =E= vNetFinAssets[FinCorp,t-1]/fv
                             + vNetInterests[FinCorp,t] + vNetDividends[FinCorp,t] + vNetRevaluations[FinCorp,t]
                             + sum(i$i_private_fin[i], vEBITDA_i[i,t]) - vI_private_fin[t]
                             ;

  .. vNetFinAssets[Gov,t] =E= vNetFinAssets[Gov,t-1]/fv
                            + vNetInterests[Gov,t] + vNetDividends[Gov,t] + vNetRevaluations[Gov,t]
                            + vGovPrimaryBalance[t];

  .. vNetFinAssets[RoW,t] =E= vNetFinAssets[RoW,t-1]/fv
                            + vNetInterests[RoW,t] + vNetDividends[RoW,t] + vNetRevaluations[RoW,t]
                            + vM[t]
                            - vX[t]
                            + vNetGov2Foreign[t];

  .. vEBITDA_i[i,t] =E= vY_i[i,t] - vWages_i[i,t] - vD[i,t] - jvE_i[i,t]
                                  - vtY_i_NetTaxSub[i,t] + vNetGov2Corp_xIO[i,t]; # Net duties should be subtracted here - AKB: What? They are contained in vD and vE_i

  # Government maintains equity at a constant level
  .. vNetEquity[Gov,t] =E= vNetEquity[Gov,t-1]/fv * fv; # Use equity price change instead of fv, when available

  # Households allocate their net financial assets between shares (equity) and deposits (debt instruments) in fixed shares
  .. vNetEquity[Hh,t] =E= rHhEquity2FinAssets[t] * vNetFinAssets[Hh,t];

  # Corporate debt is a fraction of net equity
  vNetEquity[FinCorp,t].. vNetDebtInstruments[FinCorp,t] =E= rFinCorpDebt2Equity[t] * vNetEquity[FinCorp,t];
  vNetEquity[NonFinCorp,t].. vNetDebtInstruments[NonFinCorp,t] =E= rNonFinCorpDebt2Equity[t] * vNetEquity[NonFinCorp,t];

  # Rest of World is residual investor - net equity sum to zero across all sectors
  .. vNetEquity[RoW,t] =E= -sum(sector$(not RoW[sector]), vNetEquity[sector,t]);

  # Debt instruments are residual given net financial assets and equity
  .. vNetDebtInstruments[sector,t] =E= vNetFinAssets[sector,t] - vNetEquity[sector,t];

  # Fow now we assume that corporations pay out any excess cash as dividends (issue stocks)
  # And we do not calculate value of the firm for endogenous revaluations
  rDividends[t]..
      -vNetDividends['NonFinCorp',t] =E= (sum(i$i_private_nonfin[i], vEBITDA_i[i,t]) - vI_private_nonfin[t] 
                                       + vNetInterests['NonFinCorp',t] 
                                       - (vNetDebtInstruments['NonFinCorp',t] - vNetDebtInstruments['NonFinCorp',t-1]/fv)); # Purchasing securities or repaying debt (issuing debt or selling securities)

    # For now assume no non-domestic equities
  .. vNetDividends[sector,t] =E= rDividends[t] * vNetEquity[sector,t-1]/fv;

  .. vNetInterests[sector,t] =E= rInterests_s[sector,t] * vNetDebtInstruments[sector,t-1]/fv;
  .. vNetRevaluations[sector,t] =E= rRevaluations_s[sector,t] * vNetFinAssets[sector,t-1]/fv;

  .. rInterests_s[sector,t] =E= rInterests[t] + jrInterests_s[sector,t];

  .. rHh[t] =E= (vNetInterests['Hh',t] + vNetDividends['Hh',t]) / vNetFinAssets['Hh',t-1]/fv;  

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
  vNetDebtInstruments[sector,t]
  rInterests[t]
  # vNetRevaluations[sector,t]
;
@load(financial_data_variables, "../data/data.gdx")
$Group+ data_covered_variables financial_data_variables$(t.val <= %calibration_year%);


vNetEquity.l[sector,t] = vNetFinAssets.l[sector,t] - vNetDebtInstruments.l[sector,t];

# And set interests to 4% for all sectors, and revaluations to zero
rInterests.l[t] = 0.04;
vNetInterests.l[sector,t] = rInterests.l[t] * vNetDebtInstruments.l[sector,t-1];

# Initialize J-terms for energy-specific variables to zero (allows partial equilibrium when energy modules are off)
jvInvt_ene_i.l[i,t] = 0;
jvE_i.l[i,t] = 0;

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
  -vNetDebtInstruments['FinCorp',t1], rFinCorpDebt2Equity[t1]
  -vNetDebtInstruments['NonFinCorp',t1], rNonFinCorpDebt2Equity[t1]
  -vNetEquity['Hh',t1], rHhEquity2FinAssets[t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  rFinCorpDebt2Equity[t]
  rNonFinCorpDebt2Equity[t]
  rHhEquity2FinAssets[t]
  # rRevaluations_s[sector,t]
;

# These are excluded from default_starting_values in calibration.gms
$Group non_default_starting_values
;

# Macro to set custom starting values for the variables in non_default_starting_values (called from calibration.gms)
$MACRO financial_accounts_calibration_starting_values

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