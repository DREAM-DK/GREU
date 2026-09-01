# Define costs from a change in the capital growth rate.
# Add output loss and exact marginal terms through Production and Capital hooks.
# Exclude capital accumulation, investment shares, and the base user cost.
module CapitalAdjustmentCosts

using SquareModels
import ..Capital:
  pKAdjCost_k_i,
  qK_k_i,
  rHurdleRate_i
import ..GrowthInflationAdjustment: GrowthAdjusted, fp, fq
import ..InputOutput: industry
import ..Production: pProd, qProductionLoss, topNest
import ..ProductionSettings: capital_type
import ..model
import ..Time: t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CapitalAdjustmentCostsTag = Tag(:CapitalAdjustmentCosts)

@variables model :: (CapitalAdjustmentCostsTag, GrowthAdjusted) begin
  qKAdjCost_k_i[(k,i,t)=qK_k_i], "Capital adjustment cost by type and industry."
end

@variables model :: CapitalAdjustmentCostsTag begin
  fKAdjCost[(k,i,t)=qK_k_i] :: ForecastConstant, "Adjustment-cost factor by capital type and industry."
  rKCapitalGrowthChange[(k,i,t)=qK_k_i], "Change in the capital growth rate by type and industry."
  dKAdjCost2dK[(k,i,t)=qK_k_i], "Adjustment-cost derivative for current capital by type and industry."
  dKAdjCost2dKLag[(k,i,t)=qK_k_i], "One-period-ahead adjustment-cost derivative by type and industry."
  dKAdjCost2dKLag2[(k,i,t)=qK_k_i], "Two-period-ahead adjustment-cost derivative by type and industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[fKAdjCost] .= 0.01
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[tagged(model, CapitalAdjustmentCostsTag)] = 0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    rKCapitalGrowthChange[k=capital_type, i=industry, t=t1:T],
    rKCapitalGrowthChange[k,i,t] == qK_k_i[k,i,t] / qK_k_i[k,i,t-1]*fq - qK_k_i[k,i,t-1] / qK_k_i[k,i,t-2]*fq

    qKAdjCost_k_i[k=capital_type, i=industry, t=t1:T],
    qKAdjCost_k_i[k,i,t] == fKAdjCost[k,i,t] / 2 * rKCapitalGrowthChange[k,i,t]^2 * qK_k_i[k,i,t-1]/fq

    dKAdjCost2dK[k=capital_type, i=industry, t=t1:T],
    dKAdjCost2dK[k,i,t] == fKAdjCost[k,i,t] * rKCapitalGrowthChange[k,i,t]

    dKAdjCost2dKLag[k=capital_type, i=industry, t=t1:(T-1)],
    dKAdjCost2dKLag[k,i,t] == fKAdjCost[k,i,t+1] * (rKCapitalGrowthChange[k,i,t+1]^2 / 2
                                   - rKCapitalGrowthChange[k,i,t+1] * (
                                     qK_k_i[k,i,t+1] / qK_k_i[k,i,t]*fq
                                     + qK_k_i[k,i,t] / qK_k_i[k,i,t-1]*fq))

    dKAdjCost2dKLag2[k=capital_type, i=industry, t=t1:(T-2)],
    dKAdjCost2dKLag2[k,i,t] ==
      fKAdjCost[k,i,t+2] * rKCapitalGrowthChange[k,i,t+2] * (qK_k_i[k,i,t+1] / qK_k_i[k,i,t]*fq)^2

    qProductionLoss[i=industry, t=t1:T], qProductionLoss[i,t] == ∑(qKAdjCost_k_i[k,i,t] for k in capital_type)

    pKAdjCost_k_i[k=capital_type, i=industry, t=(t1+1):(T-1)],
    pKAdjCost_k_i[k,i,t] == pProd[topNest[i],i,t-1]/fp * dKAdjCost2dK[k,i,t-1]
                              + dKAdjCost2dKLag[k,i,t-1] / (1 + rHurdleRate_i[i,t]) *
                                pProd[topNest[i],i,t]
                              + dKAdjCost2dKLag2[k,i,t-1] /
                                ((1 + rHurdleRate_i[i,t]) * (1 + rHurdleRate_i[i,t+1])) *
                                pProd[topNest[i],i,t+1]*fp

    pKAdjCost_k_i[k=capital_type, i=industry, t=T; T > t1], pKAdjCost_k_i[k,i,t] == 0
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations()
end
end # module
