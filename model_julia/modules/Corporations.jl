# Define budgets, portfolios, and finance behavior for corporate sectors.
# Link corporation tax and debt finance to the capital user cost.
# Use IndustrySectors shares for corporate sector activity.

module Corporations

using SquareModels
import ..Capital:
  capital_k_i,
  mtCorp_i,
  dvCorpTax2dqK_k_i,
  pI_k,
  qK_k_i,
  rHurdleRate_i,
  rKDepr_k_i,
  vI_k_i
import ..FinancialRevaluations: rFirmRequiredReturn_s
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fq, fv
import ..IndustrySectors:
  rIndustrySector_s_i,
  vK_s,
  vM_s,
  vtProduction_s,
  vWages_s,
  vY_s
import ..InputOutput: industry
import ..model
import ..ProductionSettings: capital_type
import ..SectorAccounts:
  fin_instrument,
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vNetTransfers,
  vNonProducedAssetAcquisitions,
  vI_s,
  vFinIncome_s_f,
  vFinPosition_s_f,
  vFinTransactions_f,
  vNetFinAssets
import ..Taxes:
  corporation_sector,
  tCorp_s,
  vCorpCapitalTaxDeduction_s,
  vCorpDebtTaxDeduction_s
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CorporationsTag = Tag(:Corporations)

@variables model :: (CorporationsTag, ForecastConstant) begin
  rFinCorpDebtAssets2DebtLiabilities[t], "FinCorp share of total debt liabilities held as debt assets."
  rFinCorpDebtLiabilities2EquityLiabilities[t], "FinCorp debt liability ratio relative to equity liabilities."
  rNonFinCorpEquityAssets2EquityLiabilities[t], "NonFinCorp equity asset ratio: equity assets relative to own equity liabilities."
  rNonFinCorpDebtAssets2Expenses[t], "NonFinCorp debt asset ratio: debt assets relative to total expenses."
  rNonFinCorpDebtLiabilities2Capital[t], "NonFinCorp debt liability ratio relative to the replacement value of capital."
end

@variables model :: (CorporationsTag, GrowthAdjusted, InflationAdjusted) begin
  vCapitalTaxValue_k_i[(k,i,t)=qK_k_i], "Capital tax book value by type and industry."
  vCapitalTaxDepr_k_i[(k,i,t)=qK_k_i], "Capital tax depreciation by type and industry."
  vNonFinCorpExpenses[t], "NonFinCorp operating expenses: intermediate inputs, wages, and production taxes."
end

@variables model :: CorporationsTag begin
  rCapitalTaxDepr_k[k=capital_type, t=t] :: ForecastConstant, "Tax depreciation rate on the opening capital tax value."
  rWACC[t], "Weighted average cost of non-financial corporate capital."
  rHurdleRatePremium_i[i=industry, t=t] :: ForecastConstant, "Capital hurdle rate premium by industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[[vCapitalTaxValue_k_i[k,i,t1-1] for (k,i) in capital_k_i]] .= [
    db[pI_k[k,t1-1]] * db[qK_k_i[k,i,t1-1]]
    for (k,i) in capital_k_i
  ]
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[mtCorp_i] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    vNonFinCorpExpenses[t=t1:T],
    vNonFinCorpExpenses[t] == vM_s[:NonFinCorp,t]
                            + vWages_s[:NonFinCorp,t]
                            + vtProduction_s[:NonFinCorp,t]

    # Budget identity. Net financial transactions include asset purchases less
    # debt and equity issues. A positive equity issue adds corporate funding;
    # a negative issue is a buy-back and uses corporate funds.
    vNetFinTransactions[s=[:FinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                              + vNetTransfers[s,t] - vNonProducedAssetAcquisitions[s,t]
                              - vI_s[s,t] + vY_s[s,t] - vM_s[s,t]
                              - vWages_s[s,t] - vtProduction_s[s,t]

    vNetFinTransactions[s=[:NonFinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                              + vNetTransfers[s,t] - vNonProducedAssetAcquisitions[s,t]
                              - vI_s[s,t] + vY_s[s,t] - vM_s[s,t]
                              - vWages_s[s,t] - vtProduction_s[s,t]

    # Portfolio.
    # Financial corporations.
    # Equity assets follow revaluation.
    vFinPosition_s_f[s=[:FinCorp], f=[:Equity], al=[:Assets], t=t1:T], vFinTransactions_f[s,f,al,t] == 0

    # Debt assets are a fixed share of all debt liabilities, including interbank liabilities.
    vFinPosition_s_f[s=[:FinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinPosition_s_f[s,f,al,t] ==
      rFinCorpDebtAssets2DebtLiabilities[t] * ∑(vFinPosition_s_f[s2,:Debt,:Liab,t] for s2 in sector)

    # Debt liabilities are a fixed share of equity liabilities.
    vFinPosition_s_f[s=[:FinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == rFinCorpDebtLiabilities2EquityLiabilities[t] * vFinPosition_s_f[s,:Equity,al,t]

    # Equity liabilities are residual given net financial assets.
    vFinPosition_s_f[s=[:FinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == ∑(vFinPosition_s_f[s,f,:Assets,t] for f in fin_instrument)
                        - ∑(vFinPosition_s_f[s,f,:Liab,t] for f in fin_instrument)

    # Non-financial corporations.
    # Equity assets are a fixed fraction of equity liabilities.
    vFinPosition_s_f[s=[:NonFinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinPosition_s_f[s,f,al,t] ==
      rNonFinCorpEquityAssets2EquityLiabilities[t] * vFinPosition_s_f[:NonFinCorp,:Equity,:Liab,t]

    # Debt assets are a fixed fraction of operating expenses.
    vFinPosition_s_f[s=[:NonFinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == rNonFinCorpDebtAssets2Expenses[t] * vNonFinCorpExpenses[t]

    # Debt liabilities are a fixed fraction of the replacement value of capital.
    vFinPosition_s_f[s=[:NonFinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == rNonFinCorpDebtLiabilities2Capital[t] * vK_s[:NonFinCorp,t]

    # Equity liabilities are residual given net financial assets.
    vFinPosition_s_f[s=[:NonFinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == ∑(vFinPosition_s_f[s,f,:Assets,t] for f in fin_instrument)
                        - ∑(vFinPosition_s_f[s,f,:Liab,t] for f in fin_instrument)

    # Tax and financing behavior.
    # Current-price investment adds to the tax value. Tax depreciation applies
    # to the opening tax value and does not use the user cost.
    vCapitalTaxDepr_k_i[k=capital_type, i=industry, t=t1:T; (k,i) in capital_k_i],
    vCapitalTaxDepr_k_i[k,i,t] == rCapitalTaxDepr_k[k,t] * vCapitalTaxValue_k_i[k,i,t-1]/fv

    vCapitalTaxValue_k_i[k=capital_type, i=industry, t=t1:T; (k,i) in capital_k_i],
    vCapitalTaxValue_k_i[k,i,t] == vCapitalTaxValue_k_i[k,i,t-1]/fv + vI_k_i[k,i,t] - vCapitalTaxDepr_k_i[k,i,t]

    vCorpCapitalTaxDeduction_s[s=corporation_sector, t=t1:T],
    vCorpCapitalTaxDeduction_s[s,t] == ∑(
      rIndustrySector_s_i[s,i,t] * vCapitalTaxDepr_k_i[k,i,t]
      for k in capital_type, i in industry
    )

    # Debt liability income reduces taxable income. Revaluations do not.
    vCorpDebtTaxDeduction_s[s=[:NonFinCorp], t=t1:T],
    vCorpDebtTaxDeduction_s[s,t] == vFinIncome_s_f[s,:Debt,:Liab,t]

    # Debt receives the corporation tax shield. Equity receives the required return.
    rWACC[t=t1:T],
    rWACC[t] * vK_s[:NonFinCorp,t-1]/fv ==
      (1 - tCorp_s[:NonFinCorp,t]) * vFinIncome_s_f[:NonFinCorp,:Debt,:Liab,t]
      + rFirmRequiredReturn_s[:NonFinCorp,t] *
        (vK_s[:NonFinCorp,t-1] - vFinPosition_s_f[:NonFinCorp,:Debt,:Liab,t-1])/fv

    # A hurdle premium is applied to the investment decisions
    rHurdleRate_i[i=industry, t=t1:T], rHurdleRate_i[i,t] == rWACC[t] + rHurdleRatePremium_i[i,t]

    # Gross up required capital income by the marginal corporation tax rate.
    mtCorp_i[i=industry, t=t1:T],
    mtCorp_i[i,t] == ∑(tCorp_s[s,t] * rIndustrySector_s_i[s,i,t] for s in corporation_sector)

    # Opening tax value gives the later tax depreciation deduction.
    dvCorpTax2dqK_k_i[k=capital_type, i=industry, t=t1:T],
    dvCorpTax2dqK_k_i[k,i,t] * qK_k_i[k,i,t-1]/fq ==
      -mtCorp_i[i,t] * rCapitalTaxDepr_k[k,t] * vCapitalTaxValue_k_i[k,i,t-1]/fv
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  # Match the tax rate by capital type to the capital-value-weighted physical
  # depreciation rate in corporate sectors in the calibration year.
  block = define_equations() + @block model begin
    rCapitalTaxDepr_k[k=capital_type, t=[t1]],
    rCapitalTaxDepr_k[k,t] * ∑(
      rIndustrySector_s_i[s,i,t] * pI_k[k,t] * qK_k_i[k,i,t-1]/fq
      for s in corporation_sector, i in industry
    ) == ∑(
      rIndustrySector_s_i[s,i,t] * pI_k[k,t]
      * rKDepr_k_i[k,i,t] * qK_k_i[k,i,t-1]/fq
      for s in corporation_sector, i in industry
    )
  end

  # At t1, use source values to identify portfolio ratios.
  @endo_exo_swap! block begin
    rFinCorpDebtAssets2DebtLiabilities[t1], vFinPosition_s_f[:FinCorp,:Debt,:Assets,t1]
    rFinCorpDebtLiabilities2EquityLiabilities[t1], vFinPosition_s_f[:FinCorp,:Debt,:Liab,t1]
    rNonFinCorpEquityAssets2EquityLiabilities[t1], vFinPosition_s_f[:NonFinCorp,:Equity,:Assets,t1]
    rNonFinCorpDebtAssets2Expenses[t1], vFinPosition_s_f[:NonFinCorp,:Debt,:Assets,t1]
    rNonFinCorpDebtLiabilities2Capital[t1], vFinPosition_s_f[:NonFinCorp,:Debt,:Liab,t1]
    rHurdleRatePremium_i[:,t1], rHurdleRate_i[:,t1]
  end

  return block
end

end # module
