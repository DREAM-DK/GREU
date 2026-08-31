# Define budget identities and portfolio rules for corporate sectors.
# Use IndustrySectors shares for non-financial corporation activity.

module Corporations

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..IndustrySectors:
  vK_s,
  vM_s,
  vtProduction_s,
  vWages_s,
  vY_s
import ..model
import ..SectorAccounts:
  fin_instrument,
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vNetTransfers,
  vNonProducedAssetAcquisitions,
  vI_s,
  vFinPosition_s_f,
  vFinTransactions_f,
  vNetFinAssets
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
  vNonFinCorpExpenses[t], "NonFinCorp operating expenses: intermediate inputs, wages, and production taxes."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
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
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # At t1, use source values to identify portfolio ratios.
  @endo_exo_swap! block begin
    rFinCorpDebtAssets2DebtLiabilities[t1], vFinPosition_s_f[:FinCorp,:Debt,:Assets,t1]
    rFinCorpDebtLiabilities2EquityLiabilities[t1], vFinPosition_s_f[:FinCorp,:Debt,:Liab,t1]
    rNonFinCorpEquityAssets2EquityLiabilities[t1], vFinPosition_s_f[:NonFinCorp,:Equity,:Assets,t1]
    rNonFinCorpDebtAssets2Expenses[t1], vFinPosition_s_f[:NonFinCorp,:Debt,:Assets,t1]
    rNonFinCorpDebtLiabilities2Capital[t1], vFinPosition_s_f[:NonFinCorp,:Debt,:Liab,t1]
  end

  return block
end

end # module
