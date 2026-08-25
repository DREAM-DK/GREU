# Populate rest-of-world entries of the SectorAccounts interface.
# Keep the RoW budget identity and portfolio rules.
# RoW has no final consumption and no gross capital formation.

module RestOfWorld

using SquareModels
import ..InputOutput: vM, vX
import ..Labor: vRoWNetWages
import ..model
import ..SectorAccounts:
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vNonFinancialNonProducedAssets,
  vRoWPrimaryIncomeCurrentBalanceOther,
  vFinPosition_f
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const RestOfWorldTag = Tag(:RestOfWorld)

@variables model :: (RestOfWorldTag, ForecastConstant) begin
  rRoWDebtLiabilities2FinCorpDebtAssets[t], "RoW debt liability ratio relative to FinCorp debt assets."
  rRoWEquityLiabilities2DomesticEquityAssets[t], "RoW equity liability ratio: RoW equity liabilities relative to total domestic equity assets."
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
    # Budget identity.
    vNetFinTransactions[s=[:RoW], t=t1:T],
    vNetFinTransactions[s,t] == (vM[t] - vX[t] + vRoWNetWages[t] + vNetFinIncome[s,t]
                                 + vRoWPrimaryIncomeCurrentBalanceOther[t]
                                 - vNonFinancialNonProducedAssets[s,t])

    # Nonwage income closes net financial transactions across sectors.
    vRoWPrimaryIncomeCurrentBalanceOther[t=t1:T], ∑(vNetFinTransactions[s,t] for s in sector) == 0.0

    # Portfolio.
    # Debt assets clear the debt market.
    vFinPosition_f[s=[:RoW], f=[:Debt], al=[:Assets], t=t1:T],
    vFinPosition_f[s,f,al,t] == ∑(vFinPosition_f[s2,:Debt,:Liab,t] for s2 in sector)
                                    - ∑(vFinPosition_f[s2,:Debt,:Assets,t] for s2 in sector if s2 != :RoW)

    # Debt liabilities are a fixed share of FinCorp debt assets.
    vFinPosition_f[s=[:RoW], f=[:Debt], al=[:Liab], t=t1:T],
    vFinPosition_f[s,f,al,t] ==
      rRoWDebtLiabilities2FinCorpDebtAssets[t] * vFinPosition_f[:FinCorp,:Debt,:Assets,t]

    @test_constraint("Debt assets equal debt liabilities"; atol=2.0, rtol=1e-6)
    vFinPosition_f[s=[:RoW], f=[:Debt], al=[:Liab], t=t1:T],
    ∑(vFinPosition_f[s2,:Debt,:Assets,t] for s2 in sector) ==
      ∑(vFinPosition_f[s2,:Debt,:Liab,t] for s2 in sector)

    # Equity liabilities are a fixed share of domestic equity assets.
    vFinPosition_f[s=[:RoW], f=[:Equity], al=[:Liab], t=t1:T],
    vFinPosition_f[s,f,al,t] == rRoWEquityLiabilities2DomesticEquityAssets[t] *
      ∑(vFinPosition_f[s2,:Equity,:Assets,t] for s2 in sector if s2 != :RoW)

    # RoW equity assets clear the equity market.
    vFinPosition_f[s=[:RoW], f=[:Equity], al=[:Assets], t=t1:T],
    ∑(vFinPosition_f[s2,:Equity,:Assets,t] for s2 in sector) ==
      ∑(vFinPosition_f[s2,:Equity,:Liab,t] for s2 in sector)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # At t1, swap each ratio endogenous and the corresponding financial asset cell exogenous,
  # so calibration solves for the ratio implied by observed balance-sheet data.
  @endo_exo_swap! block begin
    rRoWDebtLiabilities2FinCorpDebtAssets[t1], vFinPosition_f[:RoW,:Debt,:Liab,t1]
    rRoWEquityLiabilities2DomesticEquityAssets[t1], vFinPosition_f[:RoW,:Equity,:Liab,t1]
  end

  return block
end

end # module
