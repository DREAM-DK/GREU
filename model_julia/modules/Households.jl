# Populate household entries of the SectorAccounts interface.
# Keep the household budget identity, simple portfolio rules, and the
# marginal return on extra saving. Households include NPISH. Allocate
# owner-occupied housing within owner_housing_k and owner_housing_i.

module Households

using SquareModels
import ..Capital: pI_k, qI_k_i, qK_k_i, vI_k_i
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..InputOutput: vC
import ..Labor: vHhWages
import ..model
import ..ProductionSettings: owner_housing_i, owner_housing_k
import ..SectorAccounts:
  fin_instrument,
  vNetFinTransactions,
  vNetFinIncome,
  vFinIncome_f,
  vNetTransfers,
  vNonProducedAssetAcquisitions,
  vI_s,
  vGrossOpSurplusMixedIncome,
  vFinPosition_s_f,
  vFinTransactions_f,
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
  rOwnerHousing2K[t], "Owner-occupied housing share of the owner-housing capital cell."
end

@variables model :: (HouseholdsTag, GrowthAdjusted) begin
  qKOwnerHousing[t], "Owner-occupied housing capital at replacement-cost prices."
end

@variables model :: (HouseholdsTag, GrowthAdjusted, InflationAdjusted) begin
  vKOwnerHousing[t], "Replacement value of owner-occupied housing capital."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[rHhDebtAdjustment] .= 0.2

  @assert (
    0 < db[vI_s[:Hh,t1]] <
      db[pI_k[owner_housing_k,t1]] * db[qI_k_i[owner_housing_k,owner_housing_i,t1]]
  ) "Household investment must fit within owner-housing capital formation"
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
    # Owner-occupied housing stays within the owner-housing capital cell.
    # Treat all household P.5 as housing.
    vI_s[s=[:Hh], t=t1:T],
    vI_s[s,t] == rOwnerHousing2K[t] * vI_k_i[owner_housing_k,owner_housing_i,t]

    qKOwnerHousing[t=t1:T], qKOwnerHousing[t] == rOwnerHousing2K[t] * qK_k_i[owner_housing_k,owner_housing_i,t]
    vKOwnerHousing[t=t1:T], vKOwnerHousing[t] == pI_k[owner_housing_k,t] * qKOwnerHousing[t]

    # Budget identity.
    vNetFinTransactions[s=[:Hh], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t] + vNetTransfers[s,t] + vHhWages[t] - vC[t]
                              + vGrossOpSurplusMixedIncome[s,t] - vI_s[s,t]
                              - vNonProducedAssetAcquisitions[s,t]

    # Portfolio.
    # Equity assets have no transactions.
    vFinPosition_s_f[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T], vFinTransactions_f[s,f,al,t] == 0

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
    mHhReturn[t] * vFinPosition_s_f[:Hh,:Debt,:Assets,t-1]/fv == vFinIncome_f[:Hh,:Debt,:Assets,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    rOwnerHousing2K[t1], vI_s[:Hh,t1]
    rHhDebtLiabilities2Consumption[t1], vFinPosition_s_f[:Hh,:Debt,:Liab,t1]
  end

  return block
end

end # module
