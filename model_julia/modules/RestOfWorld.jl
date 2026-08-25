# Populate rest-of-world entries of the SectorAccounts interface.
# Keep the RoW budget identity and portfolio rules.
# RoW has no final consumption and no gross capital formation.

module RestOfWorld

using SquareModels
import ..InputOutput: vM, vX
import ..model
import ..SectorAccounts:
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vNonFinancialNonProducedAssets,
  vRoWPrimaryIncome,
  vNetTransfers2sector,
  vGoodsServicesBalance,
  vRoWPrimaryIncomeCurrentBalance,
  vFinAL
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const RestOfWorldTag = Tag(:RestOfWorld)

@variables model :: (RestOfWorldTag, ForecastConstant) begin
  rRoWDebtAssets2TotalDebtLiabilities[t], "RoW debt asset ratio: RoW debt assets relative to total domestic debt liabilities."
  rRoWEquityAssets2DomesticEquityLiabilities[t], "RoW equity asset ratio: RoW equity assets relative to domestic equity liabilities of Hh and NonFinCorp."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[rRoWDebtAssets2TotalDebtLiabilities] .= 0.0
  db[rRoWEquityAssets2DomesticEquityLiabilities] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Budget identity.
    vNetFinTransactions[s=[:RoW], t=t1:T],
    vNetFinTransactions[s,t] == vGoodsServicesBalance[t]
                                 + vRoWPrimaryIncomeCurrentBalance[t]
                                 - vNonFinancialNonProducedAssets[s,t]

    # Goods and services balance.
    vGoodsServicesBalance[t=t1:T],
    vGoodsServicesBalance[t] == vX[t] - vM[t]

    # Primary and current income balance.
    vRoWPrimaryIncomeCurrentBalance[t=t1:T],
    vRoWPrimaryIncomeCurrentBalance[t] == vNetFinIncome[:RoW,t]
                                           + vRoWPrimaryIncome[t]
                                           + vNetTransfers2sector[:RoW,t]

    # Portfolio.

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
  end

  return block
end

end # module
