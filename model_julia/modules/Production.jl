# Define the common production tree and its CES equations.
# Keep factor data, factor costs, and stock laws in factor modules.
# Let factor modules set the price and quantity links for leaf nodes.
include(joinpath(@__DIR__, "ProductionSettings.jl"))

module Production

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: qY_i
import ..InputOutputSettings: industry
import ..ProductionSettings: production_nesting
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero

# ============================================================================
# Production tree
# ============================================================================
const parent = Dict(
  (child, i) => n
  for i in industry if (i, t1) in keys(qY_i)
  for (n, spec) in production_nesting[i]
  for child in spec.children
)
const top_i = Dict(
  i => only(n for n in keys(production_nesting[i]) if !haskey(parent, (n, i)))
  for i in industry if (i, t1) in keys(qY_i)
)
const node = sort(unique(
  v
  for i in keys(top_i)
  for (n, spec) in production_nesting[i]
  for v in (n, spec.children...)
))

# ============================================================================
# Variables
# ============================================================================
const ProductionTag = Tag(:Production)

@variables db.model :: (ProductionTag, GrowthAdjusted) begin
  qProd[n = node, i = industry, t = t; haskey(top_i, i) && (haskey(parent, (n, i)) || n == top_i[i])], "Quantity by production node and industry."
  qProductionLoss_i[i = industry, t = t; haskey(top_i, i)] :: ForecastZero, "Output used by added production costs by industry."
end

@variables db.model :: (ProductionTag, InflationAdjusted) begin
  pProd[(n, i, t) = qProd], "Price by production node and industry."
  pY0_i[i = industry, t = t; haskey(top_i, i)], "Unit production cost by industry."
end

@variables db.model :: (ProductionTag, GrowthAdjusted, InflationAdjusted) begin
  vProductionTax_i[i = industry, t = t; haskey(top_i, i)], "Production taxes in marginal cost by industry."
end

@variables db.model :: ProductionTag begin
  uProd[n = node, i = industry, t = t; haskey(parent, (n, i))] :: ForecastConstant, "CES share by child node and industry."
  eProd[n = node, i = industry; haskey(top_i, i) && haskey(production_nesting[i], n)], "Substitution elasticity by production nest and industry."
end

# ============================================================================
# Data
# ============================================================================
function set_data!(db)
  db[eProd] .= [production_nesting[i][n].elasticity for (n, i) in keys(eProd)]
  db[vProductionTax_i] .= 0.0

  # Non-top nest prices identify their CES shares in calibration.
  db[pProd] .= [
    haskey(production_nesting[i], n) && haskey(parent, (n, i)) && year == t1 ? 1.0 : nothing
    for (n, i, year) in keys(pProd)
  ]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block db begin
    qProd[(n, i, t) in keys(qProd); n == top_i[i] && t in t1:T],
    qProd[n, i, t] == qY_i[i, t] + qProductionLoss_i[i, t]

    qProd[(n, i, t) in keys(qProd); haskey(parent, (n, i)) && t in t1:T],
    qProd[n, i, t] * pProd[n, i, t]^eProd[parent[n, i], i] ==
      uProd[n, i, t] *
      qProd[parent[n, i], i, t] *
      pProd[parent[n, i], i, t]^eProd[parent[n, i], i]

    pProd[n = node, i = industry, t = t1:T; haskey(top_i, i) && haskey(production_nesting[i], n)],
    pProd[n, i, t] * qProd[n, i, t] ==
      ∑(pProd[child, i, t] * qProd[child, i, t] for child in production_nesting[i][n].children)

    pY0_i[(i, t) in keys(pY0_i); t in t1:T],
    pY0_i[i, t] * qY_i[i, t] ==
      pProd[top_i[i], i, t] * qY_i[i, t] + vProductionTax_i[i, t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  # Identify nest shares from pProd and leaf shares from qProd. Factor modules
  # make qProd endogenous from factor data.
  block = define_equations()

  @endo_exo_swap! block begin
    uProd[(n, i, t) in keys(uProd); haskey(production_nesting[i], n) && t == t1],
    pProd[n, i, t]

    uProd[(n, i, t) in keys(uProd); !haskey(production_nesting[i], n) && t == t1],
    qProd[n, i, t]
  end

  return block
end
end # module
