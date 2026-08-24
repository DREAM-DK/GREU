# Define the common production tree and its CES equations.
# Keep factor data, factor costs, and stock laws in factor modules.
# Let factor modules set the price and quantity links for leaf nodes.
include(joinpath(@__DIR__, "ProductionSettings.jl"))

module Production

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry, qY_i
import ..ProductionSettings: production_nesting
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero, DynamicCalibration

# ============================================================================
# Indices
# ============================================================================
const parent = Dict(
  (child, i) => n
  for i in industry
  for (n, spec) in production_nesting[i]
  for child in spec.children
)
const topNest = Dict(
  i => only(n for n in keys(production_nesting[i]) if !haskey(parent, (n, i)))
  for i in industry
)
const node = sort(unique(
  v
  for i in industry
  for (n, spec) in production_nesting[i]
  for v in (n, spec.children...)
))

# ============================================================================
# Variables
# ============================================================================
const ProductionTag = Tag(:Production)

@variables model :: (ProductionTag, GrowthAdjusted) begin
  qProd[n = node, i = industry, t = t; haskey(parent, (n, i)) || n == topNest[i]], "Quantity by production node and industry."
  qProductionLoss[i = industry, t = t] :: ForecastZero, "Output used by added production costs by industry."
end

@variables model :: (ProductionTag, InflationAdjusted) begin
  pProd[(n, i, t) = qProd], "Price by production node and industry."
  pY0[i = industry, t = t], "Unit production cost by industry."
end

@variables model :: (ProductionTag, GrowthAdjusted, InflationAdjusted) begin
  vProductionTax_i[i = industry, t = t], "Production taxes in marginal cost by industry."
end

@variables model :: ProductionTag begin
  uProd[n = node, i = industry, t = t; haskey(parent, (n, i))] :: (ForecastConstant, DynamicCalibration), "CES share by child node and industry."
  qTop2qY[i = industry, t = t] :: ForecastConstant, "Ratio of top-nest quantity to output by industry."
  eProd[n = node, i = industry; haskey(production_nesting[i], n)], "Substitution elasticity by production nest and industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[eProd] .= [production_nesting[i][n].elasticity for (n, i) in keys(eProd)]
  db[vProductionTax_i] .= 0.0

  # All factor prices are calibrated to 1.0
  db[pProd] .= 1

  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    qProd[n = node, i = industry, t = t1:T; n == topNest[i]],
    qProd[n, i, t] == qTop2qY[i, t] * qY_i[i, t] + qProductionLoss[i, t]

    qProd[n = node, i = industry, t = t1:T; haskey(parent, (n, i))],
    qProd[n, i, t] * pProd[n, i, t]^eProd[parent[n, i], i] ==
      uProd[n, i, t] *
      qProd[parent[n, i], i, t] *
      pProd[parent[n, i], i, t]^eProd[parent[n, i], i]

    pProd[n = node, i = industry, t = t1:T; haskey(production_nesting[i], n)],
    pProd[n, i, t] * qProd[n, i, t] == ∑(pProd[child, i, t] * qProd[child, i, t] for child in production_nesting[i][n].children)

    pY0[i = industry, t = t1:T],
    pY0[i, t] * qTop2qY[i, t] * qY_i[i, t] == pProd[topNest[i], i, t] * qProd[topNest[i], i, t] + vProductionTax_i[i, t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  # Identify nest shares from pProd, leaf shares from qProd, and the top-nest
  # to output ratio from pProd at the top nest.
  block = define_equations()

  @endo_exo_swap! block begin
    uProd[n = node, i = industry, t = t1; haskey(production_nesting[i], n)],
    pProd[(n, i, t) in keys(uProd); haskey(production_nesting[i], n) && t == t1]

    uProd[n = node, i = industry, t = t1; !haskey(production_nesting[i], n)],
    qProd[(n, i, t) in keys(uProd); !haskey(production_nesting[i], n) && t == t1]

    qTop2qY[:,t1],
    pProd[(n, i, t) in keys(pProd); n == topNest[i] && t == t1]
  end

  return block
end
end # module
