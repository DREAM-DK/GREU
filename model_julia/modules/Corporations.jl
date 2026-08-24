# Populate financial and non-financial corporation entries of the SectorAccounts interface.
# Keep budget identities and portfolio rules for FinCorp and NonFinCorp.

module Corporations

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..model
import ..SectorAccounts:
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vNetTransfers2sector,
  vCorrectionNonFinCorp2Hh,
  vGrossCapitalFormation,
  vNonFinancialNonProducedAssets,
  vGrossOpSurplusMixedIncome,
  vFinAL,
  vFinTransactions,
  vFinReval,
  vNetFinAssets,
  vFinAssets_al
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CorporationsTag = Tag(:Corporations)

@variables model :: (CorporationsTag, ForecastConstant) begin
  rFinCorpDebtAssets2DomesticDebtLiabilities[t], "FinCorp debt asset ratio: debt assets relative to domestic debt liabilities of Hh, NonFinCorp, and Gov."
  rFinCorpDebtLiabilities2EquityLiabilities[t], "FinCorp capital structure: debt liabilities relative to own equity liabilities."
  rNonFinCorpEquityAssets2EquityLiabilities[t], "NonFinCorp equity asset ratio: equity assets relative to own equity liabilities."
  rNonFinCorpDebtAssets2Expenses[t], "NonFinCorp debt asset ratio: debt assets relative to total expenses."
  rNonFinCorpDebtLiabilities2Capital[t], "NonFinCorp debt liability ratio: debt liabilities relative to total capital stock."
end

# Filled by the IO module when it is connected.
@variables model :: (CorporationsTag, GrowthAdjusted, InflationAdjusted) begin
  vNonFinCorpExpenses[t], "NonFinCorp total expenses (wages + depreciation + user cost of capital)."
  vNonFinCorpCapital[t], "NonFinCorp total capital stock."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[vNonFinCorpExpenses] .= 1000.0 # TODO: replace with variable from IO module
  db[vNonFinCorpCapital] .= 1000.0 # TODO: replace with variable from IO module
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Budget identity.
    vNetFinTransactions[s=[:FinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]

    vNetFinTransactions[s=[:NonFinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]
                                 - vCorrectionNonFinCorp2Hh[t]

    # Portfolio.
    # Financial corporations.
    # Equity assets follow revaluation.
    vFinAL[s=[:FinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinTransactions[s,f,al,t] == 0

    # Debt assets are a fixed fraction of the aggregate debt liabilities of domestic sectors.
    vFinAL[s=[:FinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rFinCorpDebtAssets2DomesticDebtLiabilities[t] * ∑(vFinAL[s2,:Debt,:Liab,t] for s2 in sector if s2 in (:Hh, :NonFinCorp, :Gov))

    # Debt liabilities are a fixed fraction of equity liabilities (shareholder equity).
    vFinAL[s=[:FinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinAL[s,f,al,t] == rFinCorpDebtLiabilities2EquityLiabilities[t] * vFinAL[:FinCorp,:Equity,:Liab,t]

    # Equity liabilities are residual given net financial assets.
    vFinAL[s=[:FinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]

    # Non-financial corporations.
    # Equity assets are a fixed fraction of equity liabilities.
    vFinAL[s=[:NonFinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpEquityAssets2EquityLiabilities[t] * vFinAL[:NonFinCorp,:Equity,:Liab,t]

    # Debt assets are a fixed fraction of total expenses (wages + depreciation + user cost of capital).
    # TODO: replace vNonFinCorpExpenses with sum over IO industries once the IO module is connected.
    vFinAL[s=[:NonFinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpDebtAssets2Expenses[t] * vNonFinCorpExpenses[t]

    # Debt liabilities are a fixed fraction of total capital.
    # TODO: replace vNonFinCorpCapital with sum over IO capital types once the IO module is connected.
    vFinAL[s=[:NonFinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpDebtLiabilities2Capital[t] * vNonFinCorpCapital[t]

    # Equity liabilities are residual given net financial assets.
    vFinAL[s=[:NonFinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # At t1, swap each rate endogenous and the corresponding vFinAL cell exogenous,
  # so calibration solves for the ratio implied by observed balance-sheet data.
  @endo_exo_swap! block begin
    rFinCorpDebtAssets2DomesticDebtLiabilities[t1], vFinAL[:FinCorp,:Debt,:Assets,t1]
    rFinCorpDebtLiabilities2EquityLiabilities[t1], vFinAL[:FinCorp,:Debt,:Liab,t1]
    rNonFinCorpEquityAssets2EquityLiabilities[t1], vFinAL[:NonFinCorp,:Equity,:Assets,t1]
    rNonFinCorpDebtAssets2Expenses[t1], vFinAL[:NonFinCorp,:Debt,:Assets,t1]
    rNonFinCorpDebtLiabilities2Capital[t1], vFinAL[:NonFinCorp,:Debt,:Liab,t1]
  end

  return block
end

end # module
