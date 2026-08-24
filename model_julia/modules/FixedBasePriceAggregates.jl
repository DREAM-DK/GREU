# Define GDP and gross value added at current and fixed-base prices.
# Use expenditure for GDP and output less intermediate use for value added.
# Exclude totals that their source modules already define.
module FixedBasePriceAggregates

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  domestic,
  industry,
  product,
  qC,
  qG,
  qI,
  qINV,
  qM,
  qPurchaserUse_p_u,
  qSupply_o,
  qX,
  vC,
  vG,
  vI,
  vINV,
  vM,
  vPurchaserUse_p_u,
  vX,
  vY
import ..model
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================
const FixedBasePriceAggregatesTag = Tag(:FixedBasePriceAggregates)

@variables model :: (FixedBasePriceAggregatesTag, GrowthAdjusted, InflationAdjusted) begin
  vGDP[t], "Gross domestic product."
  vGVA[t], "Gross value added."
end

@variables model :: (FixedBasePriceAggregatesTag, InflationAdjusted) begin
  pGDP[t], "GDP deflator."
  pGVA[t], "Gross value added deflator."
end

@variables model :: (FixedBasePriceAggregatesTag, GrowthAdjusted) begin
  qGDP[t], "Real gross domestic product."
  qGVA[t], "Real gross value added."
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
    # Expenditure-side GDP.
    vGDP[t=t1:T], vGDP[t] == vC[t] + vI[t] + vINV[t] + vG[t] + vX[t] - vM[t]
    qGDP[t=t1:T], qGDP[t] == qC[t] + qI[t] + qINV[t] + qG[t] + qX[t] - qM[t]
    pGDP[t=t1:T], pGDP[t] * qGDP[t] == vGDP[t]

    # Gross value added at basic prices.
    vGVA[t=t1:T],
    vGVA[t] == vY[t] - ∑(vPurchaserUse_p_u[p,i,t] for p in product, i in industry)

    qGVA[t=t1:T],
    qGVA[t] == qSupply_o[domestic,t] - ∑(qPurchaserUse_p_u[p,i,t] for p in product, i in industry)

    pGVA[t=t1:T], pGVA[t] * qGVA[t] == vGVA[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations()
end

end # module
