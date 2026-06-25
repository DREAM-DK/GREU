# ------------------------------------------------------------------------------
# Sector accounts (Layer 1: pure accounting)
# ------------------------------------------------------------------------------
# Mirrors ESA 2010 institutional sector accounts: non-financial budget (B.9)
# closed against financial net transactions (B.9F), with stocks, property income,
# and revaluations by instrument (Equity, Debt) and side (ASS, LIAB).
#
# Behavioural rules (portfolio shares, payout policies, capital structure) belong
# in sector modules on top of this layer. jvNetTrans absorbs the B.9 / B.9F gap
# in data; it is forecast as zero after calibration.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  # -- Sector totals: stocks, flows, and net positions --
  vNetFinAssets[sector,t] "Net financial assets by sector (assets minus liabilities)."
  vNetFinTransactions[sector,t] "Net financial transactions by sector (B.9F)."
  vNetFinReval[sector,t] "Net revaluations of financial assets / liabilities by sector."
  vNetDebtInstruments[sector,t] "Net debt instruments by sector (debt assets minus debt liabilities)."
  vNetEquity[sector,t] "Net equity by sector (equity assets minus equity liabilities)."

  # -- By instrument and asset/liability side --
  vFinAL[sector,f,al,t] "Financial assets (ASS) or liabilities (LIAB) by sector and instrument."
  vFinReval[sector,f,al,t] "Revaluation of financial assets or liabilities by sector, instrument, and side."

  # -- Property income (ESA D.4: D.41 interest + D.42-D.43 distributed income) --
  vFinIncome[sector,f,al,t] "Property income received (ASS) or paid (LIAB) by sector and instrument."
  vNetFinIncome[sector,t] "Net property income by sector (received minus paid)."

  # -- Sector budget components (filled by sector modules or data) --
  vGrossOpSurplusMixedIncome_i[i,t] "Operating surplus and mixed income by industry."
  vNetTransfers2Hh[t] "Net transfers received by households."
  vHhWages[t] "Household wages."
  vHhConsumption[t] "Household consumption."
  vCorrectionNonFinCorp2Hh[t] "Correction of non-financial corporations to households."
  vGrossCapitalFormation[sector,t] "Gross capital formation."
  vGrossOpSurplusMixedIncome[sector,t] "Operating surplus and mixed income by sector."
  vNetTransfers2FinCorp[t] "Net transfers received by financial corporations."
  vNetTransfers2NonFinCorp[t] "Net transfers received by non-financial corporations."
  vGoodsServicesBalance[t] "Goods and services balance, exports minus imports."
  vRoWPrimaryIncomeCurrentBalance[t] "Primary income, current transfers and capital transers other than property income (D.4 net)."
  vRowPrimaryIncomeCurrentBalanceOther[t] "Primary income, current transfers and capital transers other than property income (D.1 net - D.9 net (excl. D.4 net))."
  vNonFinancialNonProducesAssets[sector,t] "Acquisition less disposals of non-financial non-produced assets by sector (NP)."

  # -- Rates --
  rFinIncome[sector,f,al,t] "Property income rate by sector, instrument, and side."
  rFinReval[sector,f,al,t] "Revaluation rate by sector, instrument, and side."
  rNetFinIncome_f[f,t] "Net property income rate by instrument (interest for Debt, dividend for Equity)."
  rNetFinReval_f[f,t] "Net revaluation rate by instrument."
  rHh[t] "Return on household wealth (net property income rate)."

  # -- Portfolio behavioural ratios --
  rFinCorpDebtAssets2DomesticDebtLiabilities[t] "Financial corporate debt assets to domestic debt liabilities ratio."
  rFinCorpDebtLiabilities2EquityLiabilities[t] "Financial corporate debt liabilities to equity liabilities ratio."
  rNonFinCorpEquityAssets2EquityLiabilities[t] "Non-financial corporate equity assets to equity liabilities ratio."
  rNonFinCorpDebtAssets2Expenses[t] "Non-financial corporate debt assets to expenses ratio."
  rNonFinCorpDebtLiabilities2Capital[t] "Non-financial corporate debt liabilities to capital ratio."
  rRoWDebtAssets2TotalDebtLiabilities[t] "Rest-of-world debt assets to total domestic debt liabilities ratio."
  rRoWEquityAssets2DomesticEquityLiabilities[t] "Rest-of-world equity assets to domestic equity liabilities ratio."
  vExports[t] "Exports."
  vImports[t] "Imports."

  # Residual closing the non-financial / financial accounts gap (B.9 vs B.9F).
  jvNetTrans[sector,t] "Residual on sector budget identity."
  jrFinIncome[sector,f,al,t] "Deviation from mean property income rate by sector, instrument, and side."
  jrFinReval[sector,f,al,t] "Deviation from mean revaluation rate by sector, instrument, and side."

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

  # End-of-year net financial assets = previous stock + transactions + revaluations.
  # Other changes in volume (K.1-K.6) are not modelled and fall into the residual in data years.
  # .. vNetFinAssets[sector,t] =E= vNetFinAssets[sector,t-1]/fv + vNetFinTransactions[sector,t] + vNetFinIncome[sector,t] + vNetFinReval[sector,t];

  # # ----- Non-financial / financial closure (B.9 = B.9F) ----- Move to sector modules.
  # # vNetFinTrans (B.9F, financial-accounts net lending) is here equated to
  # # the budget identity (B.9). jvNetTrans absorbs the data discrepancy between the two sides;
  # # it is forecast as zero, but nonzero in historical data. 
  .. vNetFinTransactions['Gov',t] =E= vGovBalance[t]
                             + jvNetTrans['Gov',t];

  .. vNetFinTransactions['Hh',t] =E= vNetFinIncome['Hh',t]
                             + vNetTransfers2Hh[t]
                             + vHhWages[t] # Should use vWages from IO-system
                             - vHhConsumption[t] # Should use vC from IO-system
                             + vCorrectionNonFinCorp2Hh[t]
                             - vGrossCapitalFormation['Hh',t]
                             - vNonFinancialNonProducesAssets['Hh',t]
                             + jvNetTrans['Hh',t];

  .. vNetFinTransactions['FinCorp',t] =E= vNetFinIncome['FinCorp',t]
                             + vNetTransfers2FinCorp[t]
                             - vGrossCapitalFormation['FinCorp',t]
                             - vNonFinancialNonProducesAssets['FinCorp',t]
                             + vGrossOpSurplusMixedIncome['FinCorp',t] # Should use B2A3G from vIO_a
                             + jvNetTrans['FinCorp',t];

  .. vNetFinTransactions['NonFinCorp',t] =E= vNetFinIncome['NonFinCorp',t]
                             + vNetTransfers2NonFinCorp[t]
                             - vGrossCapitalFormation['NonFinCorp',t]
                             - vNonFinancialNonProducesAssets['NonFinCorp',t]
                             + vGrossOpSurplusMixedIncome['NonFinCorp',t] # Should use B2A3G from vIO_a insetad 
                             - vCorrectionNonFinCorp2Hh[t]
                             + jvNetTrans['NonFinCorp',t];

  .. vNetFinTransactions['RoW',t] =E= 
                             - vGoodsServicesBalance[t]
                             + vRoWPrimaryIncomeCurrentBalance[t]
                             - vNonFinancialNonProducesAssets['RoW',t] 
                             + jvNetTrans['RoW',t];

  .. vGoodsServicesBalance[t] =E= vExports[t] - vImports[t]; # should use vX[t] - vM[t] from IO-system
  .. vRoWPrimaryIncomeCurrentBalance[t] =E= vNetFinIncome['RoW',t] # D.4 net
                             + vRoWPrimaryIncomeCurrentBalanceOther[t];

  
  # Net property income by sector, RoW is residual given net property income of other sectors.
  $(not RoW[sector]).. vNetFinIncome[sector,t] =E= sum(f,  vFinIncome[sector,f,'ASS',t] - vFinIncome[sector,f,'LIAB',t]);
  .. vNetFinIncome['RoW',t] =E= -sum(sector$(not RoW[sector]), vNetFinIncome[sector,t]);

  .. vNetFinReval[sector,t] =E= sum(f, vFinReval[sector,f,'ASS',t] - vFinReval[sector,f,'LIAB',t]);

  # Net debt instruments, and equity instruments.
  .. vNetDebtInstruments[sector,t] =E= vFinAL[sector,'Debt','ASS',t] - vFinAL[sector,'Debt','LIAB',t];
  .. vNetEquity[sector,t] =E= vFinAL[sector,'Equity','ASS',t] - vFinAL[sector,'Equity','LIAB',t];
  # .. vNetFinAssets[sector,t] =E= vNetDebtInstruments[sector,t] + vNetEquity[sector,t];

  # -----------------------
  # -- Sector portfolios -- # Move to sector modules 
  # -----------------------
  # -- Government --
  # Government neither buys nor sells equity; 
  .. vFinAL['Gov','Equity',al,t] =E= vFinAL['Gov','Equity',al,t-1]/fv + vFinReval['Gov','Equity',al,t];
  # Government keeps a constant level of debt-instruments
  .. vFinAL['Gov','Debt','ASS',t] =E= vFinAL['Gov','Debt','ASS',t-1]/fv + vFinReval['Gov','Debt','ASS',t];
  # Debt liability is residual given net financial assets.
  vFinAL['Gov','Debt','LIAB',t] .. vNetFinAssets['Gov',t] =E= vNetDebtInstruments['Gov',t] + vNetEquity['Gov',t]; #sum(f, vFinAL['Gov',f ,'ASS',t] - vFinAL['Gov',f ,'LIAB',t]);

  # -- Households --
  # Equity assets and debt liabilities follow revaluation
  .. vFinAL['Hh','Equity','ASS',t] =E= vFinAL['Hh','Equity','ASS',t-1]/fv + vFinReval['Hh','Equity','ASS',t];
  .. vFinAL['Hh','Debt','LIAB',t] =E= vFinAL['Hh','Debt','LIAB',t-1]/fv + vFinReval['Hh','Debt','LIAB',t]; # Should following housing
  # Debt assets are residual given net financial assets
  vFinAL['Hh','Debt','ASS',t] .. vNetFinAssets['Hh',t] =E= vNetDebtInstruments['Hh',t] + vNetEquity['Hh',t]; #sum(f, vFinAL['Hh',f ,'ASS',t] - vFinAL['Hh',f ,'LIAB',t]);

  # -- Financial corporations --
  # Equity assets follow revaluation
  .. vFinAL['FinCorp','Equity','ASS',t] =E= vFinAL['FinCorp','Equity','ASS',t-1]/fv + vFinReval['FinCorp','Equity','ASS',t];
  # Debt assets are modeled as a fixed fraction of the aggregate debt liabilities of all other domestic sectors
  .. vFinAL['FinCorp','Debt','ASS',t] =E= rFinCorpDebtAssets2DomesticDebtLiabilities[t] * sum(sector$(Hh[sector] + NonFinCorp[sector] + Gov[sector]), vFinAL[sector,'Debt','LIAB',t]);
  # Debt liabilities are modeled as a fixed fraction of their equity liabilities (shareholder equity)
  .. vFinAL['FinCorp','Debt','LIAB',t] =E= rFinCorpDebtLiabilities2EquityLiabilities[t] * vFinAL['FinCorp','Equity','LIAB',t];
  # Equity liability is residual given net financial assets
  vFinAL['FinCorp','Equity','LIAB',t] .. vNetFinAssets['FinCorp',t] =E= vNetDebtInstruments['FinCorp',t] + vNetEquity['FinCorp',t]; #sum(f, vFinAL['FinCorp',f ,'ASS',t] - vFinAL['FinCorp',f ,'LIAB',t]);

  # -- Non-financial corporations --
  # Equity assets are modeled as a fixed fraction of their equity liabilities (shareholder equity)
  .. vFinAL['NonFinCorp','Equity','ASS',t] =E= rNonFinCorpEquityAssets2EquityLiabilities[t] * vFinAL['NonFinCorp','Equity','LIAB',t];
  # Debt assets are modeled as a fixed fraction of expenses...
  .. vFinAL['NonFinCorp','Debt','ASS',t] =E= rNonFinCorpDebtAssets2Expenses[t] * sum(i$i_private_nonfin[i], vWages_i[i,t] + vD[i,t] + sum(k, pK_k_i[k,i,t] * qK_k_i[k,i,t-1]/fq));
  # Debt liabilities are modeled as a fixed fraction of capital...
  .. vFinAL['NonFinCorp','Debt','LIAB',t] =E= rNonFinCorpDebtLiabilities2Capital[t] * sum(i$i_private_nonfin[i], sum(k, qK_k_i[k,i,t-1]/fq));
  # Equity liability is residual given net financial assets 
  vFinAL['NonFinCorp','Equity','LIAB',t] .. vNetFinAssets['NonFinCorp',t] =E= vNetDebtInstruments['NonFinCorp',t] + vNetEquity['NonFinCorp',t]; #sum(f, vFinAL['NonFinCorp',f ,'ASS',t] - vFinAL['NonFinCorp',f ,'LIAB',t]);

  # -- Rest of World --
  # Debt assets are modeled as a fixed fraction of the aggregate debt liabilities of all domestic sectors
  .. vFinAL['RoW','Debt','ASS',t] =E= rRoWDebtAssets2TotalDebtLiabilities[t] * sum(sector$(not RoW[sector]), vFinAL[sector,'Debt','LIAB',t]);
  # Debt liabilities are residually given net financial assets
  vFinAL['RoW','Debt','LIAB',t] .. vNetDebtInstruments['RoW',t] =E= -sum(sector$(not RoW[sector]), vNetDebtInstruments[sector, t]);
  # Equity assets are modeled as a fixed fraction of domestic equity liabilities
  .. vFinAL['RoW','Equity','ASS',t] =E= rRoWEquityAssets2DomesticEquityLiabilities[t] * sum(sector$(Hh[sector] + NonFinCorp[sector]), vFinAL[sector,'Equity','LIAB',t]);
  # Equity liabilities are residually given net financial assets
  vFinAL['RoW','Equity','LIAB',t] .. vNetEquity['RoW',t] =E= -sum(sector, vNetEquity[sector, t]);

  .. vNetFinAssets['RoW',t] =E= -sum(sector$(not RoW[sector]), vNetFinAssets[sector, t]);

  # -- Other equations for sector modules --
  .. vI_private_nonfin[t] =E= sum(i$i_private_nonfin[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);
  .. vI_private_fin[t] =E= sum(i$i_private_fin[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);
  .. vI_private[t] =E= sum(i$i_private[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);
  .. vI_public[t] =E= sum(i$i_public[i], sum(k, vI_k_i[k,i,t]) + vInvt_i[i,t] + jvInvt_ene_i[i,t]);

  .. vEBITDA_i[i,t] =E= vY_i[i,t] - vWages_i[i,t] - vD[i,t] - jvE_i[i,t]
                                  - vtY_i_NetTaxSub[i,t] + vNetGov2Corp_xIO[i,t];



  # Property income and revaluations as rate on opening stocks.
  # .. vFinIncome[sector,f,al,t] =E= rFinIncome[sector,f,al,t] * vFinAL[sector,f,al,t-1]/fv;
  # .. vFinReval[sector,f,al,t] =E= rFinReval[sector,f,al,t] * vFinAL[sector,f,al,t-1]/fv;

  # .. rFinIncome[sector,f,al,t] =E= rNetFinIncome_f[f,t] + jrFinIncome[sector,f,al,t];
  # .. rFinReval[sector,f,al,t] =E= rNetFinReval_f[f,t] + jrFinReval[sector,f,al,t];

  # .. rHh[t] =E= vNetFinIncome['Hh',t] / (vNetFinAssets['Hh',t-1]/fv);

  # # Property income paid on liabilities equals property income received on assets (RoW residual).
  # jrFinIncome['RoW','Debt','ASS',t]..
  #   sum(sector, vFinIncome[sector,'Debt','ASS',t] - vFinIncome[sector,'Debt','LIAB',t]) =E= 0;
  # jrFinIncome['RoW','Equity','ASS',t]..
  #   sum(sector, vFinIncome[sector,'Equity','ASS',t] - vFinIncome[sector,'Equity','LIAB',t]) =E= 0;

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
  vFinAL[sector,f,al,t]
  vFinIncome[sector,f,al,t]
  vNetFinTransactions[sector,t]
  vGrossCapitalFormation[sector,t]
  vGrossOpSurplusMixedIncome[sector,t]

  vNetTransfers2Hh[t]
  vNetTransfers2FinCorp[t]
  vHhWages[t]
  vHhConsumption[t]
  vCorrectionNonFinCorp2Hh[t]
  vNetTransfers2NonFinCorp[t]
  vNonFinancialNonProducesAssets[sector,t]
  vExports[t]
  vImports[t]
  vRowPrimaryIncomeCurrentBalanceOther[t]
  
;
@load(financial_data_variables, "../data/data.gdx")
$Group+ data_covered_variables financial_data_variables$(t.val <= %calibration_year%);

# Net positions from loaded balance-sheet stocks.
# vNetDebtInstruments.l[sector,t] = vFinAL.l[sector,'Debt','ASS',t] - vFinAL.l[sector,'Debt','LIAB',t];
# vNetEquity.l[sector,t] = vFinAL.l[sector,'Equity','ASS',t] - vFinAL.l[sector,'Equity','LIAB',t];
# vNetFinAssets.l[sector,t] = sum(f, vFinAL.l[sector,f,'ASS',t] - vFinAL.l[sector,f,'LIAB',t]);

# vNetFinIncome.l[sector,t] = sum(f,
#                                 vFinIncome.l[sector,f,'ASS',t]
#                               - vFinIncome.l[sector,f,'LIAB',t]);

# # Revaluations implied by stock-flow consistency (transactions absorb the residual).
# vFinReval.l[sector,f,al,t]$(vFinAL.l[sector,f,al,t-1])
#   = (vFinAL.l[sector,f,al,t] - vFinAL.l[sector,f,al,t-1]/fv)
#   / vFinAL.l[sector,f,al,t-1];

# vNetFinReval.l[sector,t] = sum(f, vFinReval.l[sector,f,'ASS',t] * vFinAL.l[sector,f,'ASS',t-1]/fv
#                                   - vFinReval.l[sector,f,'LIAB',t] * vFinAL.l[sector,f,'LIAB',t-1]/fv);

# vNetFinTrans.l[sector,t] = vNetFinAssets.l[sector,t]
#                          - vNetFinAssets.l[sector,t-1]/fv
#                          - vNetFinReval.l[sector,t];


# Initialize J-terms for energy-specific variables to zero (allows partial equilibrium when energy modules are off)
jvInvt_ene_i.l[i,t] = 0;
jvE_i.l[i,t] = 0;

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Starting values
# ------------------------------------------------------------------------------
$IF %stage% == "starting_values":

set_time_periods(%calibration_year%, %calibration_year%);

$Group non_default_starting_values
  # Variables that require custom starting values
;

# Set custom starting values for the variables in non_default_starting_values here

$ENDIF # starting_values

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

  -vNetFinTransactions[sector,t1], jvNetTrans[sector,t1]

  -vFinAL['FinCorp','Debt','ASS',t1], rFinCorpDebtAssets2DomesticDebtLiabilities[t1]
  -vFinAL['FinCorp','Debt','LIAB',t1], rFinCorpDebtLiabilities2EquityLiabilities[t1]

  -vFinAL['NonFinCorp','Equity','ASS',t1], rNonFinCorpEquityAssets2EquityLiabilities[t1]
  -vFinAL['NonFinCorp','Debt','ASS',t1], rNonFinCorpDebtAssets2Expenses[t1]
  -vFinAL['NonFinCorp','Debt','LIAB',t1], rNonFinCorpDebtLiabilities2Capital[t1]

  # -vFinIncome[sector,f,al,t1]$(not RoW[sector]), jrFinIncome[sector,f,al,t1]
  # -vFinReval[sector,f,al,t1], jrFinReval[sector,f,al,t1]
  # -jvNetTrans[sector,t1]

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  rNetFinIncome_f[f,t]
  rNetFinReval_f[f,t]
  rFinCorpDebtAssets2DomesticDebtLiabilities[t]
  rFinCorpDebtLiabilities2EquityLiabilities[t]
  rNonFinCorpEquityAssets2EquityLiabilities[t]
  rNonFinCorpDebtAssets2Expenses[t]
  rNonFinCorpDebtLiabilities2Capital[t]
;

$Group+ G_zero_after_last_data_year
  jvNetTrans[sector,t]
;

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
# $IF %stage% == "tests":
#   parameter test_sector_balance_flow[t];
#   parameter test_sector_balance_pos[t,f];
#   $FOR {var} in ["vNetFinAssets", "vNetFinTrans", "vNetFinReval", "vNetFinIncome"]:
#     test_sector_balance_flow[t] = abs(sum(sector, {var}.l[sector,t]));
#     ABORT$(smax(t, test_sector_balance_flow[t]) > 1e-6) "{var} do not sum to zero across sectors.", test_sector_balance_flow;
#   $ENDFOR
#   $FOR {var} in ["vFinAL", "vFinReval", "vFinIncome"]:
#     test_sector_balance_pos[t,f] = abs(
#       sum(sector, {var}.l[sector,f,'ASS',t])
#     - sum(sector, {var}.l[sector,f,'LIAB',t]));
#     ABORT$(smax((t,f), test_sector_balance_pos[t,f]) > 1e-6) "{var} assets do not equal liabilities by instrument.", test_sector_balance_pos;
#   $ENDFOR
# $ENDIF # tests
