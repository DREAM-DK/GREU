# Define the household budget, portfolio rules, and marginal return.
# Households include NPISH. IndustrySectors allocates their activity and capital.

module Households

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..InputOutput: vC
import ..Labor: vHhWages
import ..model
import ..SectorAccounts:
  fin_instrument,
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vFinIncome_s_f,
  vNetTransfers,
  vNonProducedAssetAcquisitions,
  vI_s,
  vGrossOpSurplusMixedIncome,
  vFinPosition_s_f,
  vNetFinAssets
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================

const HouseholdsTag = Tag(:Households)

@variables model :: HouseholdsTag begin
  mHhReturn[t], "Marginal household return, equal to the yield on household debt assets."
end

@variables model :: (HouseholdsTag, ForecastConstant) begin
  rHhDebtLiabilities2Consumption[t], "Target household debt liability ratio relative to consumption."
  rHhDebtAdjustment[t], "Annual household debt adjustment rate."
  rHhEquityAssets2TotalEquity[t], "Household equity assets relative to all issued equity."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[rHhDebtAdjustment] .= 0.2
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Budget identity.
    vNetFinTransactions[s=[:Hh], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t] + vNetTransfers[s,t] + vHhWages[t] - vC[t]
                              + vGrossOpSurplusMixedIncome[s,t] - vI_s[s,t]
                              - vNonProducedAssetAcquisitions[s,t]

    # Portfolio.
    # Equity assets are a fixed share of all issued equity. Households buy their
    # share of new issues, so issuance leaves the value of their holding alone.
    # Transactions are then the residual of the stock change identity, which is
    # what those purchases are. Zero transactions would instead give the adjusted
    # stock a unit root, because the revaluation rate only offsets fv.
    vFinPosition_s_f[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T],
    vFinPosition_s_f[s,f,al,t] ==
      rHhEquityAssets2TotalEquity[t] * ∑(vFinPosition_s_f[s2,f,:Liab,t] for s2 in sector)

    # Debt liabilities move part of the way to a fixed share of consumption.
    vFinPosition_s_f[s=[:Hh], f=[:Debt], al=[:Liab], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == (1 - rHhDebtAdjustment[t]) * vFinPosition_s_f[s,f,al,t-1]/fv
                              + rHhDebtAdjustment[t] * rHhDebtLiabilities2Consumption[t] * vC[t]

    # Hh debt assets are residual given net financial assets.
    vFinPosition_s_f[s=[:Hh], f=[:Debt], al=[:Assets], t=t1:T],
    vNetFinAssets[s,t] == ∑(vFinPosition_s_f[s,f,:Assets,t] for f in fin_instrument)
                        - ∑(vFinPosition_s_f[s,f,:Liab,t] for f in fin_instrument)

    # Extra household saving is held in debt assets.
    mHhReturn[t=t1:T],
    mHhReturn[t] * vFinPosition_s_f[:Hh,:Debt,:Assets,t-1]/fv == vFinIncome_s_f[:Hh,:Debt,:Assets,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    rHhDebtLiabilities2Consumption[t1], vFinPosition_s_f[:Hh,:Debt,:Liab,t1]
    rHhEquityAssets2TotalEquity[t1], vFinPosition_s_f[:Hh,:Equity,:Assets,t1]
  end

  return block
end

end # module
