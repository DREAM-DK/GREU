# Define the common production tree and its CES equations.
# Keep factor data, factor costs, and stock laws in factor modules.
# Let factor modules set the price and quantity links for leaf nodes.
include(joinpath(@__DIR__, "ProductionSettings.jl"))

module Production

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry, qY_i, qY_p_i_data
import ..ProductionSettings: production_nesting
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero

# ============================================================================
# Production tree
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

@variables db.model :: (ProductionTag, GrowthAdjusted) begin
  qProd[n = node, i = industry, t = t; haskey(parent, (n, i)) || n == topNest[i]], "Quantity by production node and industry."
  qProductionLoss[i = industry, t = t] :: ForecastZero, "Output used by added production costs by industry."
end

@variables db.model :: (ProductionTag, InflationAdjusted) begin
  pProd[(n, i, t) = qProd], "Price by production node and industry."
  pY0[i = industry, t = t], "Unit production cost by industry."
end

@variables db.model :: (ProductionTag, GrowthAdjusted, InflationAdjusted) begin
  vProductionTax_i[i = industry, t = t], "Production taxes in marginal cost by industry."
end

@variables db.model :: ProductionTag begin
  uProd[n = node, i = industry, t = t; haskey(parent, (n, i))] :: ForecastConstant, "CES share by child node and industry."
  eProd[n = node, i = industry; haskey(production_nesting[i], n)], "Substitution elasticity by production nest and industry."
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
# Starting values
# ============================================================================
function qProd_start(n, i)
  if n == topNest[i]
    output = sum(cell for ((_, ii, year), cell) in qY_p_i_data if ii == i && year == t1)
    @assert isfinite(output) && output > 0 "Production output starts must be finite and positive"
    return output
  end
  return qProd_start(parent[n, i], i) / length(production_nesting[i][parent[n, i]].children)
end

function set_starting_values!(start_values)
  # Use observed output, equal child shares, and unit prices at t1.
  q_keys = [
    (n, i, year)
    for (n, i, year) in keys(qProd)
    if year == t1 && isnothing(start_values[qProd[n, i, year]])
  ]
  start_values[[qProd[key...] for key in q_keys]] .= [qProd_start(n, i) for (n, i, _) in q_keys]

  p_keys = [
    (n, i, year)
    for (n, i, year) in keys(pProd)
    if year == t1 && isnothing(start_values[pProd[n, i, year]])
  ]
  start_values[[pProd[key...] for key in p_keys]] .= 1.0

  u_keys = [
    (n, i, year)
    for (n, i, year) in keys(uProd)
    if year == t1 && isnothing(start_values[uProd[n, i, year]])
  ]
  start_values[[uProd[key...] for key in u_keys]] .= [
    1 / length(production_nesting[i][parent[n, i]].children)
    for (n, i, _) in u_keys
  ]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block db begin
    qProd[(n, i, t) in keys(qProd); n == topNest[i] && t in t1:T],
    qProd[n, i, t] == qY_i[i, t] + qProductionLoss[i, t]

    qProd[(n, i, t) in keys(qProd); haskey(parent, (n, i)) && t in t1:T],
    qProd[n, i, t] * pProd[n, i, t]^eProd[parent[n, i], i] ==
      uProd[n, i, t] *
      qProd[parent[n, i], i, t] *
      pProd[parent[n, i], i, t]^eProd[parent[n, i], i]

    pProd[n = node, i = industry, t = t1:T; haskey(production_nesting[i], n)],
    pProd[n, i, t] * qProd[n, i, t] ==
      ∑(pProd[child, i, t] * qProd[child, i, t] for child in production_nesting[i][n].children)

    pY0[i = industry, t = t1:T],
    pY0[i, t] * qY_i[i, t] ==
      pProd[topNest[i], i, t] * qY_i[i, t] + vProductionTax_i[i, t]
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
    pProd[(n, i, t) in keys(uProd); haskey(production_nesting[i], n) && t == t1]

    uProd[(n, i, t) in keys(uProd); !haskey(production_nesting[i], n) && t == t1],
    qProd[(n, i, t) in keys(uProd); !haskey(production_nesting[i], n) && t == t1]
  end

  return block
end
end # module
