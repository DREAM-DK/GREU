# Populate household entries of the SectorAccounts interface.
# Allocate owner-occupied housing within real-estate structures.
# Keep the household budget identity and simple portfolio rules.
# Exclude a housing-demand function and a market house price.

module Households

using SquareModels
import ..Capital: pI_k, qI_k_i, qK_k_i, vI_k_i
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..InputOutput: vC
import ..Labor: vHhWages
import ..model
import ..SectorAccounts:
  vNetFinTransactions,
  vNetFinIncome,
  vNetTransfers2sector,
  vGrossCapitalFormation,
  vGrossOpSurplusMixedIncome,
  vNonFinancialNonProducedAssets,
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

const HouseholdsTag = Tag(:Households)

@variables model :: (HouseholdsTag, ForecastConstant) begin
  rHhDebtLiabilities2Consumption[t], "Target household debt liability ratio relative to consumption."
  rHhDebtAdjustment[t], "Annual household debt adjustment rate."
  rOwnerHousing2RealEstateStructures[t], "Owner-occupied housing share of real-estate structures."
end

@variables model :: (HouseholdsTag, GrowthAdjusted) begin
  qKOwnerHousing[t], "Owner-occupied housing capital at replacement-cost prices."
end

@variables model :: (HouseholdsTag, GrowthAdjusted, InflationAdjusted) begin
  vKOwnerHousing[t], "Replacement value of owner-occupied housing capital."
  vHhNetWorth[t], "Household net worth including owner-occupied housing capital."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[rHhDebtAdjustment] .= 0.2

  @assert (
    0 < db[vGrossCapitalFormation[:Hh,t1]] <
      db[pI_k[:structures,t1]] * db[qI_k_i[:structures,:iL,t1]]
  ) "Household capital formation must fit within real-estate structures investment"
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  owner_share = start_values[vGrossCapitalFormation[:Hh,t1]] /
    (start_values[pI_k[:structures,t1]] * start_values[qI_k_i[:structures,:iL,t1]])
  start_values[rOwnerHousing2RealEstateStructures] .= owner_share
  start_values[qKOwnerHousing[t1]] = owner_share * start_values[qK_k_i[:structures,:iL,t1]]
  start_values[vKOwnerHousing[t1]] = start_values[pI_k[:structures,t1]] * start_values[qKOwnerHousing[t1]]
  start_values[vHhNetWorth[t1]] = start_values[vNetFinAssets[:Hh,t1]] + start_values[vKOwnerHousing[t1]]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Owner-occupied housing stays within real-estate production and capital.
    # Treat all household P.5 as housing until sector P.51g data are added.
    vGrossCapitalFormation[s=[:Hh], t=t1:T],
    vGrossCapitalFormation[s,t] == rOwnerHousing2RealEstateStructures[t] * vI_k_i[:structures,:iL,t]

    qKOwnerHousing[t=t1:T],
    qKOwnerHousing[t] == rOwnerHousing2RealEstateStructures[t] * qK_k_i[:structures,:iL,t]

    vKOwnerHousing[t=t1:T], vKOwnerHousing[t] == pI_k[:structures,t] * qKOwnerHousing[t]
    vHhNetWorth[t=t1:T], vHhNetWorth[t] == vNetFinAssets[:Hh,t] + vKOwnerHousing[t]

    # Budget identity.
    vNetFinTransactions[s=[:Hh], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 + vHhWages[t]
                                 - vC[t]
                                 + vGrossOpSurplusMixedIncome[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]

    # Portfolio.
    # Equity assets have no transactions.
    vFinAL[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T], 
    vFinTransactions[s,f,al,t] == 0

    # Debt liabilities move part of the way to a fixed share of consumption.
    vFinAL[s=[:Hh], f=[:Debt], al=[:Liab], t=t1:T], 
    vFinAL[s,f,al,t] == (1 - rHhDebtAdjustment[t]) * vFinAL[s,f,al,t-1]/fv
                          + (rHhDebtAdjustment[t] * rHhDebtLiabilities2Consumption[t] * vC[t])

    # Hh debt assets are residual given net financial assets.
    vFinAL[s=[:Hh], f=[:Debt], al=[:Assets], t=t1:T], 
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]

    @test_constraint("The owner-housing share must be nonnegative")
    rOwnerHousing2RealEstateStructures[t=t1:T], rOwnerHousing2RealEstateStructures[t] >= 0

    @test_constraint("The owner-housing share must not exceed one")
    rOwnerHousing2RealEstateStructures[t=t1:T], 1 - rOwnerHousing2RealEstateStructures[t] >= 0
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    rOwnerHousing2RealEstateStructures[t1], vGrossCapitalFormation[:Hh,t1]
    rHhDebtLiabilities2Consumption[t1], vFinAL[:Hh,:Debt,:Liab,t1]
  end

  return block
end

end # module
