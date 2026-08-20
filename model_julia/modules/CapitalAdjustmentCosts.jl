# Define costs from a change in the capital stock.
# Add output loss and a marginal term through Production and Capital hooks.
# Exclude capital accumulation, investment shares, and the base user cost.
module CapitalAdjustmentCosts

using SquareModels
import ..Capital:
  capital_k_i,
  pCapitalAdjustment_k_i,
  qI_k_i,
  qK_k_i,
  rHurdleRate_i,
  rKDepr_k_i
import ..GrowthInflationAdjustment: GrowthAdjusted, fp, fq
import ..Production: pProd, qProductionLoss_i, top_i
import ..ProductionSettings: capital_type
import ..db
import ..Time: t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CapitalAdjustmentCostsTag = Tag(:CapitalAdjustmentCosts)

@variables db.model :: (CapitalAdjustmentCostsTag, GrowthAdjusted) begin
  qInstCost_k_i[(k, i, t) = qK_k_i], "Capital installation cost by type and industry."
end

@variables db.model :: CapitalAdjustmentCostsTag begin
  fInstCost_k_i[(k, i, t) = qK_k_i] :: ForecastConstant, "Installation-cost factor by capital type and industry."
  dInstCost2dK_k_i[(k, i, t) = qK_k_i], "Installation-cost derivative for current capital by type and industry."
  dInstCost2dKLag_k_i[(k, i, t) = qK_k_i], "Installation-cost derivative for lagged capital by type and industry."
end

# ============================================================================
# Data
# ============================================================================
function set_data!(db)
  db[fInstCost_k_i] .= 0.5
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block db begin
    qInstCost_k_i[(k, i, t) in keys(qInstCost_k_i); t in t1:T],
    qInstCost_k_i[k, i, t] ==
      fInstCost_k_i[k, i, t] *
      (qI_k_i[k, i, t] / qK_k_i[k, i, t-1])^2 *
      qK_k_i[k, i, t-1]

    dInstCost2dK_k_i[(k, i, t) in keys(dInstCost2dK_k_i); t in t1:T],
    dInstCost2dK_k_i[k, i, t] ==
      2 * fInstCost_k_i[k, i, t] * qI_k_i[k, i, t] /
      (qK_k_i[k, i, t-1]/fq)

    dInstCost2dKLag_k_i[(k, i, t) in keys(dInstCost2dKLag_k_i); t in t1:(T-1)],
    dInstCost2dKLag_k_i[k, i, t] ==
      -fInstCost_k_i[k, i, t] *
      (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t+1] * fq / qK_k_i[k, i, t]) *
      (qI_k_i[k, i, t+1] * fq / qK_k_i[k, i, t])

    dInstCost2dKLag_k_i[(k, i, t) in keys(dInstCost2dKLag_k_i); t == T],
    dInstCost2dKLag_k_i[k, i, t] ==
      -fInstCost_k_i[k, i, t] *
      (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t] * fq / qK_k_i[k, i, t]) *
      (qI_k_i[k, i, t] * fq / qK_k_i[k, i, t])

    qProductionLoss_i[(i, t) in keys(qProductionLoss_i); t in t1:T],
    qProductionLoss_i[i, t] ==
      ∑(qInstCost_k_i[k, i, t] for k in capital_type if (k, i) in capital_k_i)

    pCapitalAdjustment_k_i[(k, i, t) in keys(pCapitalAdjustment_k_i); t in t1:(T-1)],
    pCapitalAdjustment_k_i[k, i, t] ==
      pProd[top_i[i], i, t] * dInstCost2dK_k_i[k, i, t]
      + (dInstCost2dKLag_k_i[k, i, t] /
        (1 + rHurdleRate_i[i, t+1]) * pProd[top_i[i], i, t+1] * fp)

    pCapitalAdjustment_k_i[(k, i, t) in keys(pCapitalAdjustment_k_i); t == T],
    pCapitalAdjustment_k_i[k, i, t] ==
      pProd[top_i[i], i, t] * dInstCost2dK_k_i[k, i, t]
      + (dInstCost2dKLag_k_i[k, i, t] /
        (1 + rHurdleRate_i[i, t]) * pProd[top_i[i], i, t] * fp)
  end
end

define_calibration() = define_equations()
end # module
