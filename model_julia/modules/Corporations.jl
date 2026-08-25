# Populate financial and non-financial corporation entries of the SectorAccounts interface.
# Keep budget identities and portfolio rules for FinCorp and NonFinCorp.

module Corporations

using SquareModels
import ..Capital: pI_k, qK_k_i, vI_k_i
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..Households: vKOwnerHousing
import ..InputOutput: industry, vY_i
import ..Intermediates: vM_i
import ..Labor: vWages_i
import ..model
import ..Production: vProductionTax_i
import ..ProductionSettings: capital_type
import ..SectorAccounts:
  fin_instrument,
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vNetTransfers,
  vI_s,
  vNonFinancialNonProducedAssets,
  vGrossOpSurplusMixedIncome,
  vFinPosition_f,
  vFinTransactions_f,
  vNetFinAssets
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CorporationsTag = Tag(:Corporations)
const corporation_sector = [:FinCorp, :NonFinCorp]
const fin_corp_industry = [:iK]
const public_industry = [:iO, :iP, :iQ]
const non_fin_corp_industry = setdiff(industry, [fin_corp_industry; public_industry])

@assert fin_corp_industry ⊆ industry "The financial corporation industry must be in the input-output data"
@assert public_industry ⊆ industry "Each public industry must be in the input-output data"

@variables model :: (CorporationsTag, ForecastConstant) begin
  rFinCorpDebtAssets2DebtLiabilities[t], "FinCorp share of total debt liabilities held as debt assets."
  rNonFinCorpEquityAssets2EquityLiabilities[t], "NonFinCorp equity asset ratio: equity assets relative to own equity liabilities."
  rNonFinCorpDebtAssets2Expenses[t], "NonFinCorp debt asset ratio: debt assets relative to total expenses."
  rNonFinCorpDebtLiabilities2Capital[t], "NonFinCorp debt liability ratio relative to the replacement value of capital."
  fGrossOpSurplus_s[s=corporation_sector, t=t], "Factor from modeled industry operating surplus to sector gross operating surplus."
end

@variables model :: (CorporationsTag, GrowthAdjusted, InflationAdjusted) begin
  vGrossOpSurplus_i[i=industry, t=t], "Gross operating surplus by industry."
  vNonFinCorpExpenses[t], "NonFinCorp operating expenses: intermediate inputs, wages, and production taxes."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  return nothing
end

function set_residual_tolerances!(tolerances)
  # Activity and sector investment data can differ after the housing allocation.
  tolerances[vI_s] = 1100.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Production and investment links.
    vGrossOpSurplus_i[i=industry, t=t1:T],
    vGrossOpSurplus_i[i,t] == vY_i[i,t] - vM_i[i,t] - vWages_i[i,t] - vProductionTax_i[i,t]

    vGrossOpSurplusMixedIncome[s=[:FinCorp], t=t1:T],
    vGrossOpSurplusMixedIncome[s,t] == fGrossOpSurplus_s[s,t] * ∑(vGrossOpSurplus_i[i,t] for i in fin_corp_industry)

    vGrossOpSurplusMixedIncome[s=[:NonFinCorp], t=t1:T],
    vGrossOpSurplusMixedIncome[s,t] == fGrossOpSurplus_s[s,t] * (
      ∑(vGrossOpSurplus_i[i,t] for i in non_fin_corp_industry) - vGrossOpSurplusMixedIncome[:Hh,t])

    vI_s[s=[:FinCorp], t=t1:T],
    vI_s[s,t] == ∑(vI_k_i[k,i,t] for k in capital_type, i in fin_corp_industry)

    vI_s[s=[:NonFinCorp], t=t1:T],
    vI_s[s,t] == ∑(vI_k_i[k,i,t] for k in capital_type, i in non_fin_corp_industry)
                                    - vI_s[:Hh,t]

    vNonFinCorpExpenses[t=t1:T],
    vNonFinCorpExpenses[t] == ∑(vM_i[i,t] for i in non_fin_corp_industry)
                            + ∑(vWages_i[i,t] for i in non_fin_corp_industry)
                            + ∑(vProductionTax_i[i,t] for i in non_fin_corp_industry)

    # Budget identity. Net financial transactions include asset purchases less
    # debt and equity issues. A positive equity issue adds corporate funding;
    # a negative issue is a buy-back and uses corporate funds.
    vNetFinTransactions[s=[:FinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                              + vNetTransfers[s,t] - vI_s[s,t]
                              - vNonFinancialNonProducedAssets[s,t] + vGrossOpSurplusMixedIncome[s,t]

    vNetFinTransactions[s=[:NonFinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                + vNetTransfers[s,t] - vI_s[s,t]
                                - vNonFinancialNonProducedAssets[s,t] + vGrossOpSurplusMixedIncome[s,t]

    # Portfolio.
    # Financial corporations.
    # Equity assets follow revaluation.
    vFinPosition_f[s=[:FinCorp], f=[:Equity], al=[:Assets], t=t1:T], vFinTransactions_f[s,f,al,t] == 0

    # Debt assets are a fixed share of all debt liabilities, including interbank liabilities.
    vFinPosition_f[s=[:FinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinPosition_f[s,f,al,t] ==
      rFinCorpDebtAssets2DebtLiabilities[t] * ∑(vFinPosition_f[s2,:Debt,:Liab,t] for s2 in sector)

    # Equity liabilities have no issues or buy-backs.
    vFinPosition_f[s=[:FinCorp], f=[:Equity], al=[:Liab], t=t1:T], vFinTransactions_f[s,f,al,t] == 0

    # Debt liabilities are residual given net financial assets.
    vFinPosition_f[s=[:FinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == ∑(vFinPosition_f[s,f,:Assets,t] for f in fin_instrument)
                           - ∑(vFinPosition_f[s,f,:Liab,t] for f in fin_instrument)

    # Non-financial corporations.
    # Equity assets are a fixed fraction of equity liabilities.
    vFinPosition_f[s=[:NonFinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinPosition_f[s,f,al,t] ==
      rNonFinCorpEquityAssets2EquityLiabilities[t] * vFinPosition_f[:NonFinCorp,:Equity,:Liab,t]

    # Debt assets are a fixed fraction of operating expenses.
    vFinPosition_f[s=[:NonFinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinPosition_f[s,f,al,t] == rNonFinCorpDebtAssets2Expenses[t] * vNonFinCorpExpenses[t]

    # Debt liabilities are a fixed fraction of the replacement value of capital.
    vFinPosition_f[s=[:NonFinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinPosition_f[s,f,al,t] == rNonFinCorpDebtLiabilities2Capital[t] * (
      ∑(pI_k[k,t] * qK_k_i[k,i,t] for k in capital_type, i in non_fin_corp_industry) - vKOwnerHousing[t])

    # Equity liabilities are residual given net financial assets.
    vFinPosition_f[s=[:NonFinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == ∑(vFinPosition_f[s,f,:Assets,t] for f in fin_instrument)
                        - ∑(vFinPosition_f[s,f,:Liab,t] for f in fin_instrument)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # At t1, use source values to identify scale factors and portfolio ratios.
  @endo_exo_swap! block begin
    fGrossOpSurplus_s[s=corporation_sector, t=[t1]], vGrossOpSurplusMixedIncome[s=corporation_sector, t=[t1]]

    rFinCorpDebtAssets2DebtLiabilities[t1], vFinPosition_f[:FinCorp,:Debt,:Assets,t1]
    rNonFinCorpEquityAssets2EquityLiabilities[t1], vFinPosition_f[:NonFinCorp,:Equity,:Assets,t1]
    rNonFinCorpDebtAssets2Expenses[t1], vFinPosition_f[:NonFinCorp,:Debt,:Assets,t1]
    rNonFinCorpDebtLiabilities2Capital[t1], vFinPosition_f[:NonFinCorp,:Debt,:Liab,t1]
  end

  return block
end

end # module
