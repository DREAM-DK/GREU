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
  vNetTransfers,
  vNonProducedAssetAcquisitions,
  vFinPosition_s_f
import ..Taxes: vRoWProductionSubsidy, vtRoWProduct
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const RestOfWorldTag = Tag(:RestOfWorld)

@variables model :: (RestOfWorldTag, ForecastConstant) begin
  rForeignDebt[t], "Share of financial corporation lending going abroad."
  rForeignEquity[t], "Share of equity portfolios that are foreign."
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
    vNetFinTransactions[s,t] == vM[t] - vX[t] + vRoWNetWages[t] + vNetFinIncome[s,t]
                                + vNetTransfers[s,t] + vtRoWProduct[t] - vRoWProductionSubsidy[t]
                                - vNonProducedAssetAcquisitions[s,t]

    # Portfolio.
    # Debt assets clear the debt market. RoW is residual lender.
    vFinPosition_s_f[s=[:RoW], f=[:Debt], al=[:Assets], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == ∑(vFinPosition_s_f[s2,:Debt,:Liab,t] for s2 in sector)
                              - ∑(vFinPosition_s_f[s2,:Debt,:Assets,t] for s2 in sector if s2 != :RoW)

    # Debt liabilities are a fixed share of FinCorp debt assets.
    vFinPosition_s_f[s=[:RoW], f=[:Debt], al=[:Liab], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == rForeignDebt[t] * vFinPosition_s_f[:FinCorp,:Debt,:Assets,t]

    # Equity liabilities are a fixed share of domestic equity assets.
    vFinPosition_s_f[s=[:RoW], f=[:Equity], al=[:Liab], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == rForeignEquity[t] * ∑(vFinPosition_s_f[s2,:Equity,:Assets,t] for s2 in sector if s2 != :RoW)

    # RoW equity assets clear the equity market. RoW is residual buyer/seller of domestic equity.
    vFinPosition_s_f[s=[:RoW], f=[:Equity], al=[:Assets], t=t1:T],
    ∑(vFinPosition_s_f[s2,:Equity,:Assets,t] for s2 in sector) == ∑(vFinPosition_s_f[s2,:Equity,:Liab,t] for s2 in sector)
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
    rForeignDebt[t1], vFinPosition_s_f[:RoW,:Debt,:Liab,t1]
    rForeignEquity[t1], vFinPosition_s_f[:RoW,:Equity,:Liab,t1]
  end

  return block
end

end # module
