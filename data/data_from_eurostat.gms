### Overview
#
# This file processes Eurostat data (produced by load_eurostat_data.py) into derived parameters for the model.
#
# Structure:
#   1) Declare and load sets and raw parameters from data.gdx
#   2) Compute derived parameters
#   3) Export to GDX
#
# To add a new module:
#   - Add the Python data module in data/modules/{name}_data.py
#   - Register it in load_eurostat_data.py
#   - Add set declarations, raw parameter declarations, and $load statements in section 1
###

# =============================================================================
# 1) Declare and load sets and raw parameters from data.gdx
# =============================================================================

# --- Time ---
Set t;
Set t1(t);

# --- Input-output ---
Set d;
Set i(d); alias(i, i_a);
Set d_non_ene(d);
Set d_ene(d);
Set energy(d);
Set a_rows_;
Set k(d);
Set c(d);
Set x(d);
Set g(d);
Set rx(i);
Set re(i);
Set invt(d);
Set invt_ene(d);
Set m(i);

# --- Financial accounts ---
Set sector;
Set finpos;
Set i_public(i);
Set i_private(i);
Set i_private_fin(i);
Set i_private_nonfin(i);

# --- Factors of production ---
Set factors_of_production;

Parameters # Parameters read from data_eurostat.gdx
  # --- Input-output ---
  vIO_y[i,d,t] "Production IO, domestic supply"
  vIO_m[i,d,t] "Production IO, imports"
  vIO_a[a_rows_,d,t] "Production IO, decomposition of GVA"
  # --- Labor market ---
  nEmployed[t] "Total labor supply data"
  hSalEmployed[t] "Total hours worked by salaried employees"
  hSelfEmployed[t] "Total hours worked by self-employed employees"
  # --- Factor demand ---
  qK_k_i[k,i,t] "Capital stock by capital type and industry."
  qI_k_i[k,i,t] "Capital investments by capital type and industry."
  # qInvt_i[i,t] "Inventory investments by industry." # Take a closer look at this...
  # --- Financial accounts ---
  vFinAssets[sector, finpos,t] "Financial assets by sector and assets and liabilities."
  vDebtInstruments[sector, finpos,t] "Debt instruments by sector and assets and liabilities."
  vEquity[sector, finpos,t] "Equity instruments by sector and assets and liabilities."

  vNetLending_s[sector,t] "Net lending by sector."
  vGrossSavings_s[sector,t] "Gross savings by sector."
  vNetCapTransfers_s[sector,t] "Net capital transfers by sector."
  vGrossCapFormation_s[sector,t] "Gross capital formation by sector."
  vNetAcquisitions_s[sector,t] "Net acquisitions by sector."
  vGrossPrimIncome_s[sector,t] "Gross primary income by sector."
  vGrossDispIncome_s[sector,t] "Gross disposable income by sector."
  vConsExp_s[sector,t] "Consumption expenditure by sector."
  vNetPensEntitlementAdj_s[sector,t] "Net pensions entitlement adjustments by sector."
  vNetCurrentIncomeWealthTax_s[sector,t] "Net current income and wealth tax by sector."
  vNetSocialContributions_s[sector,t] "Net social contributions by sector."
  vNetOtherCurrentTrans_s[sector,t] "Net other current transactions by sector."
  vNetSocialTransfersKind_s[sector,t] "Net social transfers in kind by sector."
  vGrossOpSurplusMixedIncome_s[sector,t] "Operating surplus mixed income by sector, gross."
  vWagesRec_s[sector,t] "Wages received by sector."
  vProductionImportTaxRec_s[sector,t] "Production import tax received by sector."
  vSubsidiesExp_s[sector,t] "Subsidies expenditure by sector."
  vNetPropertyIncome_s[sector,t] "Net property income by sector."
  vNetInterests_s[sector,t] "Net interests by sector."
  vNetDividends_s[sector,t] "Net dividends by sector."
  vNetReinvestedEarningsFDI_s[sector,t] "Net reinvested earnings on FDI by sector."
  vNetOtherInvestmentIncome_s[sector,t] "Net other investment income by sector."
  vNetRents_s[sector,t] "Net rents by sector."

  vInterestsPaid_s[sector,t] "Net interests paid by sector."
  vInterestsReceived_s[sector,t] "Net interests received by sector."
  vDividendsPaid_s[sector,t] "Net dividends paid by sector."
  vDividendsReceived_s[sector,t] "Net dividends received by sector."
  vReinvestedEarningsFDIPaid_s[sector,t] "Net reinvested earnings on FDI paid by sector."
  vReinvestedEarningsFDIReceived_s[sector,t] "Net reinvested earnings on FDI received by sector."
  vOtherInvestmentIncomePaid_s[sector,t] "Net other investment income paid by sector."
  vOtherInvestmentIncomeReceived_s[sector,t] "Net other investment income received by sector."

  # --- Government ---
  vGovBalance[t] "Government balance."
  vGovRevenue[t] "Government revenue."
  vGovExpenditure[t] "Government expenditure."

  vtIndirect[t] "Revenue from indirect taxes."
  vtDirect[t] "Revenue from direct taxes."
  vGovSalesRev[t] "Government sales revenue."
  vGovOthSubRev[t] "Government other subsidies revenue."
  vGovPropertyIncome[t] "Government property income revenue."
  vGovSocialContRev[t] "Government social contributions revenue."
  vGovOthCurrentTransRev[t] "Government other current transfers revenue."
  vtCap[t] "Revenue from capital taxes."
  vGovCapRev[t] "Government capital transfers revenue."

  vtHhIncome[t] "Revenue from households income taxes."
  vtCorp[t] "Revenue from corporate income taxes."
  
  vGovIntermediateCons[t] "Government intermediate consumption."
  vGovCapInv[t] "Government capital investment."
  vGovDepr[t] "Government depreciation."
  vGovEmplComp[t] "Government employment compensation."
  vGovOthProdTax[t] "Government other production taxes."
  vGovSub[t] "Government subsidies."
  vGovInterestPayments[t] "Government interest payments."
  vGovSocBenefitExp[t] "Government social benefit expenditure."
  vSocTransKind[t] "Social transfer kind."
  vGovOthCurrentTransExp[t] "Government other current transfers expenditure."
  vGovAdjExp[t] "Government adjustments."
  vGovCapTransExp[t] "Government capital transfers expenditure."
  vGovNetAcquisitions[t] "Government net acquisitions of non-produced non-financial assets."
;

$gdxin data_eurostat.gdx
#  --- Time ---
$load t, t1
#  --- Input-output sets ---
$load d, d_non_ene, d_ene, energy
$load i, m
$load k, c, x, g, rx, re, invt, invt_ene
$load a_rows_
#  --- Input-output parameters ---
$load vIO_y, vIO_m, vIO_a
#  --- Labor market --- 
$load nEmployed, hSalEmployed, hSelfEmployed
#  --- Factor demand ---
$load factors_of_production
$load qK_k_i, qI_k_i  #, qInvt_i
#  --- Financial accounts ---
$load sector, finpos, i_public, i_private, i_private_fin, i_private_nonfin
$load vFinAssets, vDebtInstruments, vEquity
$load vInterestsPaid_s, vInterestsReceived_s, vDividendsPaid_s, vDividendsReceived_s, vReinvestedEarningsFDIPaid_s, vReinvestedEarningsFDIReceived_s, vOtherInvestmentIncomePaid_s, vOtherInvestmentIncomeReceived_s
$load vNetLending_s, vGrossSavings_s, vNetCapTransfers_s, vGrossCapFormation_s, vNetAcquisitions_s, vGrossPrimIncome_s, vGrossDispIncome_s,
$load vConsExp_s, vNetPensEntitlementAdj_s, vNetCurrentIncomeWealthTax_s, vNetSocialContributions_s, vNetSocialTransfersKind_s, vNetOtherCurrentTrans_s, 
$load vGrossOpSurplusMixedIncome_s, vWagesRec_s, vProductionImportTaxRec_s, vSubsidiesExp_s, vNetPropertyIncome_s, vNetInterests_s, 
$load vNetDividends_s, vNetReinvestedEarningsFDI_s, vNetOtherInvestmentIncome_s, vNetRents_s
# #  --- Government ---
$load vGovBalance, vGovRevenue, vGovExpenditure
$load vtIndirect, vtDirect, vGovSalesRev, vGovOthSubRev, vGovPropertyIncome, vGovSocialContRev, vGovOthCurrentTransRev, vtCap, vGovCapRev, vtHhIncome, vtCorp,
$load vGovIntermediateCons, vGovCapInv, vGovDepr, vGovEmplComp, vGovOthProdTax, vGovSub, vGovInterestPayments, vGovSocBenefitExp, vSocTransKind, vGovOthCurrentTransExp, vGovAdjExp, vGovCapTransExp, vGovNetAcquisitions
$gdxin

# =============================================================================
# 2) Derived parameters
# =============================================================================

$PGROUP PG_data # Initialize intermediate parameters for computations below
  # --- Input-output ---
  vY_i_d[i,d,t] "Output by industry and demand component."
  vY_i_d_base[i,d,t] "Output by industry and demand component in base prices."
  vM_i_d[i,d,t] "Imports by industry and demand component."
  vM_i_d_base[i,d,t] "Imports by industry and demand component in base prices."
  vtY_i_d[i,d,t] "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t] "Net duties on imports by industry and demand component."
  vtY_i_Sub[i,t] "Production subsidies by industry."
  vtY_i_Tax[i,t] "Production taxes by industry."
  vtY_i_NetTaxSub[i,t] "Net production taxes and subsidies by industry."
  vD_base[d,t] "Demand components in base-prices"
  vtYM_d[d,t] "Net product taxes by demand component"
  vD[d,t] "Demand components in purchasing prices."
  qD[d,t] "Real demand by demand component."
  qInvt_i[i,t] "Inventory investments by industry."
  qInvt_ene_i[i,t] "Inventory investments by industry."
  qE_re_i[energy,i,t] "Energy demand from industry i, split on energy-types re"
  # --- Labor market ---
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."
  vW[t] "Compensation pr. employee."
  # --- Production ---
  qL_i[i,t] "Labor in efficiency units by industry."
  qProd[factors_of_production,i,t] "Factors of production, value"
  pProd[factors_of_production,i,t] "Factors of production, price"
  # --- Financial accounts ---
  vPaidInterests_s[sector,t] "Paid interests by sector and financial position."
  vReceivedInterests_s[sector,t] "Received interests by sector and financial position."
  vPaidDividends_s[sector,t] "Paid dividends by sector and financial position."
  vReceivedDividends_s[sector,t] "Received dividends by sector and financial position."

  vNetFinAssets[sector,t] "Net financial assets by sector."
  vNetDebtInstruments[sector,t] "Net debt instruments by sector."
  vNetEquity[sector,t] "Net equity instruments by sector."

;

# -----------------------------------------------------------------------------
# Compute parameters
# -----------------------------------------------------------------------------
# --- Input-output ---
vY_i_d_base[i,d,t] = vIO_y[i,d,t]; # Base prices from raw IO
vM_i_d_base[i,d,t] = vIO_m[i,d,t]; # Base prices from raw IO

vY_i_d_base[re,'energy',t] = sum(i,vIO_y[re,i,t]);
vM_i_d_base[re,'energy',t] = sum(i,vIO_m[re,i,t]);

vD_base[d,t] = sum(i, vY_i_d_base[i,d,t] + vM_i_d_base[i,d,t]); # Total demand in base prices

vtYM_d[d,t] = vIO_a["vNetProductTax",d,t]; # Net product taxes (Eurostat D21X31 = "Taxes less subsidies on products")

vtY_i_d[i,d,t]$(vD_base[d,t]) = vY_i_d_base[i,d,t] / vD_base[d,t] * vtYM_d[d,t]; # Distribute product taxes across IO cells proportional to base values
vtM_i_d[i,d,t]$(vD_base[d,t]) = vM_i_d_base[i,d,t] / vD_base[d,t] * vtYM_d[d,t]; # Distribute product taxes across IO cells proportional to base values

# Production taxes and subsidies. NOTE: Only net taxes are available in the eurostat dataset.
# Both variables are kept such that the user can populate both if data is available.
vtY_i_Tax[i,t] = vIO_a['vNetOtherProductionTax',i,t]; # Other production taxes and subsidies (Eurostat D29X39 - only net available)
vtY_i_Sub[i,t] = 0; # Only net taxes are available, so we set subsidies to zero. 
vtY_i_NetTaxSub[i,t] = vtY_i_Tax[i,t] - vtY_i_Sub[i,t];

vY_i_d[i,d,t] = vY_i_d_base[i,d,t] + vtY_i_d[i,d,t]; # IO including taxes
vM_i_d[i,d,t] = vM_i_d_base[i,d,t] + vtM_i_d[i,d,t]; # IO including taxes

vD[d,t] = sum(i, vY_i_d[i,d,t] + vM_i_d[i,d,t]); # Compute demand components in purchasing prices
qD[d,t] = vD[d,t]; # Normalize prices to 1 and load quantities into model

qInvt_i[i,t] = vY_i_d[i,'invt',t] + vM_i_d[i,'invt',t];  
qInvt_ene_i[i,t] = vY_i_d[i,'invt_ene',t] + vM_i_d[i,'invt_ene',t];

# --- Labor market ---
vWages_i[i,t] = vIO_a['CompEmpl',i,t];
nL[t] = nEmployed[t];
vW[t]$(nL[t]) = sum(i, vWages_i[i,t]) / nL[t];

# --- Production ---
qK_k_i[k,i,t] = qK_k_i[k,i,'2019']; # To avoid problems in capital accumulation equation.

qL_i[i,t] = vWages_i[i,t]*(1 + hSelfEmployed[t]/hSalEmployed[t]);

qProd['RxE',i,t]       = sum(rx,vY_i_d[rx,i,t] + vM_i_d[rx,i,t]); 
qProd['labor',i,t]     = qL_i[i,t];
qProd['iM',i,t]        = qK_k_i['iM',i,t]; 
qProd['iB',i,t]        = qK_k_i['iB',i,t];
qProd['energy',i,t]    = sum(re,vY_i_d[re,i,t] + vM_i_d[re,i,t]);
pProd[factors_of_production,i,t] = 1;

qE_re_i[energy,i,t] = qProd['energy',i,t];

# --- Financial accounts ---
vNetSocialContributions_s[sector,t] = vNetSocialContributions_s[sector,t] - vNetSocialTransfersKind_s[sector,t];

vPaidInterests_s[sector,t]      = vInterestsPaid_s[sector,t];
vReceivedInterests_s[sector,t]  = vInterestsReceived_s[sector,t];
vPaidDividends_s[sector,t]      = vDividendsPaid_s[sector,t] + vReinvestedEarningsFDIPaid_s[sector,t] + vOtherInvestmentIncomePaid_s[sector,t];
vReceivedDividends_s[sector,t]  = vDividendsReceived_s[sector,t] + vReinvestedEarningsFDIReceived_s[sector,t] + vOtherInvestmentIncomeReceived_s[sector,t];

vNetFinAssets[sector,t]         = vFinAssets[sector,'ASS',t] - vFinAssets[sector,'LIAB',t];
vNetDebtInstruments[sector,t]   = vDebtInstruments[sector,'ASS',t] - vDebtInstruments[sector,'LIAB',t];
vNetEquity[sector,t]            = vEquity[sector,'ASS',t] - vEquity[sector,'LIAB',t];


# =============================================================================
# 3) Export to GDX
# =============================================================================
execute_unload 'data'
