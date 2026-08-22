# Define costs from a change in the capital stock.
# Add output loss and a marginal term through Production and Capital hooks.
# Exclude capital accumulation, investment shares, and the base user cost.
module CapitalAdjustmentCosts

using SquareModels
import ..Capital:
  capital_k_i,
  pKAdjCost_k_i,
  qI_k_i,
  qK_k_i,
  rHurdleRate_i,
  rKDepr_k_i
import ..GrowthInflationAdjustment: GrowthAdjusted, fp, fq
import ..InputOutput: industry
import ..Production: pProd, qProductionLoss, topNest
import ..ProductionSettings: capital_type
import ..db
import ..Time: t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CapitalAdjustmentCostsTag = Tag(:CapitalAdjustmentCosts)

@variables db.model :: (CapitalAdjustmentCostsTag, GrowthAdjusted) begin
  qKAdjCost_k_i[(k, i, t) = qK_k_i], "Capital adjustment cost by type and industry."
end

@variables db.model :: CapitalAdjustmentCostsTag begin
  fKAdjCost[(k, i, t) = qK_k_i] :: ForecastConstant, "Adjustment-cost factor by capital type and industry."
  dKAdjCost2dK[(k, i, t) = qK_k_i], "Adjustment-cost derivative for current capital by type and industry."
  dKAdjCost2dKLag[(k, i, t) = qK_k_i], "Adjustment-cost derivative for lagged capital by type and industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[fKAdjCost] .= 0.5
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block db begin
    qKAdjCost_k_i[k = capital_type, i = industry, t = t1:T],
    qKAdjCost_k_i[k, i, t] ==
      fKAdjCost[k, i, t] *
      (qI_k_i[k, i, t] / qK_k_i[k, i, t-1])^2 *
      qK_k_i[k, i, t-1]

    dKAdjCost2dK[k = capital_type, i = industry, t = t1:T],
    dKAdjCost2dK[k, i, t] ==
      2 * fKAdjCost[k, i, t] * qI_k_i[k, i, t] /
      (qK_k_i[k, i, t-1]/fq)

    dKAdjCost2dKLag[k = capital_type, i = industry, t = t1:(T-1)],
    dKAdjCost2dKLag[k, i, t] ==
      -fKAdjCost[k, i, t] *
      (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t+1] * fq / qK_k_i[k, i, t]) *
      (qI_k_i[k, i, t+1] * fq / qK_k_i[k, i, t])

    dKAdjCost2dKLag[k = capital_type, i = industry, t = T],
    dKAdjCost2dKLag[k, i, t] ==
      -fKAdjCost[k, i, t] *
      (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t] * fq / qK_k_i[k, i, t]) *
      (qI_k_i[k, i, t] * fq / qK_k_i[k, i, t])

    qProductionLoss[i = industry, t = t1:T],
    qProductionLoss[i, t] ==
      ∑(qKAdjCost_k_i[k, i, t] for k in capital_type)

    pKAdjCost_k_i[k = capital_type, i = industry, t = t1:(T-1)],
    pKAdjCost_k_i[k, i, t] ==
      pProd[topNest[i], i, t] * dKAdjCost2dK[k, i, t]
      + (dKAdjCost2dKLag[k, i, t] /
        (1 + rHurdleRate_i[i, t+1]) * pProd[topNest[i], i, t+1] * fp)

    pKAdjCost_k_i[k = capital_type, i = industry, t = T],
    pKAdjCost_k_i[k, i, t] ==
      pProd[topNest[i], i, t] * dKAdjCost2dK[k, i, t]
      + (dKAdjCost2dKLag[k, i, t] /
        (1 + rHurdleRate_i[i, t]) * pProd[topNest[i], i, t] * fp)
  end
end

define_calibration() = define_equations()
end # module
