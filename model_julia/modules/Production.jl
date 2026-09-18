# Define production trees from retained forecast inputs and their CES equations.
# Provide one hook for taxes not assigned to a factor input.
# Keep factor tax rates and tax data in their own modules.
include(joinpath(@__DIR__, "ProductionSettings.jl"))

module Production

using SquareModels
import JuMP
import ..DataUtils: read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry, qY_i, qM_p_i
import ..InputOutputSettings: cell_tolerance
import ..ProductionSettings: production_data_dir, full_nesting, prune_nesting, product_to_intermediate_type
import ..Settings: calibration_year
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero, DynamicCalibration

# ============================================================================
# Read data
# ============================================================================
const capital_file = joinpath(production_data_dir, "production_capital.csv")
const labor_file = joinpath(production_data_dir, "production_labor.csv")
const intermediate_product_split_file = joinpath(production_data_dir, "production_intermediate_product_split.csv")
const qK_k_i_data = read_cells(capital_file, "qK_k_i")
const nL_l_i_data = read_cells(labor_file, "nL_l_i")
const qM_p_m_i_data = read_cells(intermediate_product_split_file, "qM_p_m_i")
const qM_m_i_data = read_cells(intermediate_product_split_file, "qM_m_i")

# ============================================================================
# Indices
# ============================================================================
# Each factor module uses these same source values and retained cells.
const capital_k_i = Set(
  (k, i) for ((k, i, year), value) in qK_k_i_data
  if i in industry && year == calibration_year && value > cell_tolerance &&
    get(qK_k_i_data, (k, i, calibration_year-1), 0.0) > cell_tolerance
)
const labor_l_i = Set(
  (l, i) for ((l, i, year), value) in nL_l_i_data
  if i in industry && year == calibration_year && value > cell_tolerance
)
const intermediate_product_m_i = Set(
  (p, m, i) for (p, m, i, _) in keys(qM_p_m_i_data) if (p, i, calibration_year+1) in keys(qM_p_i)
)
@assert all(m == product_to_intermediate_type[p] for (p, m, _) in intermediate_product_m_i) "Refresh intermediate data for the current product groups"
const intermediate_m_i = Set((m, i) for (_, m, i) in intermediate_product_m_i)
const factor_i = union(capital_k_i, labor_l_i, intermediate_m_i)
const production_nesting = Dict(
  i => prune_nesting(full_nesting, Set(f for (f, ind) in factor_i if ind == i)) for i in industry
)
@assert all(!isempty(nests) for nests in values(production_nesting)) "Each active industry needs production factors"

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
  qProd[n=node, i=industry, t=t; haskey(parent, (n,i)) || n == topNest[i]], "Quantity by production node and industry."
  qProductionLoss[i=industry, t=t] :: ForecastZero, "Output used by added production costs by industry."
  qFixedCost_i[i=industry, t=t] :: ForecastConstant, "Fixed use of the input bundle by industry."
end

@variables model :: (ProductionTag, InflationAdjusted) begin
  pProd[(n,i,t)=qProd], "Price by production node and industry."
  pMarginalCost_i[i=industry, t=t], "Marginal production cost by industry."
end

@variables model :: (ProductionTag, GrowthAdjusted, InflationAdjusted) begin
  vntProductionOther_i[i=industry, t=t] :: ForecastConstant, "Net production taxes not assigned to a factor input."
end

@variables model :: ProductionTag begin
  uProd[n=node, i=industry, t=t; haskey(parent, (n,i))] :: (ForecastConstant, DynamicCalibration), "CES share by child node and industry."
  qTop2qY[i=industry, t=t] :: ForecastConstant, "Marginal top-nest use per unit of output by industry."
  eProd[n=node, i=industry; haskey(production_nesting[i], n)], "Substitution elasticity by production nest and industry."
end

# A node price is value per unit and is positive. CES demand raises it to the nest
# elasticity, so a negative trial value stops the solver with a domain error. The bound keeps
# the search in the domain. Prices calibrate to 1.0, so an active bound means a real error.
JuMP.set_lower_bound.([pProd[key...] for key in keys(pProd)], 1e-4)

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[eProd] .= [production_nesting[i][n].elasticity for (n, i) in keys(eProd)]

  # All factor prices are calibrated to 1.0
  db[pProd] .= 1

  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    qProd[n=node, i=industry, t=t1:T; n == topNest[i]],
    qProd[n,i,t] - qFixedCost_i[i,t] - qProductionLoss[i,t] == qTop2qY[i,t] * qY_i[i,t]

    qProd[n=node, i=industry, t=t1:T; haskey(parent, (n,i))],
    qProd[n,i,t] * pProd[n,i,t]^eProd[parent[n, i],i] ==
      uProd[n,i,t] * qProd[parent[n, i],i,t] * pProd[parent[n, i],i,t]^eProd[parent[n, i],i]

    pProd[n=node, i=industry, t=t1:T; haskey(production_nesting[i], n)],
    pProd[n,i,t] * qProd[n,i,t] == ∑(pProd[child,i,t] * qProd[child,i,t] for child in production_nesting[i][n].children)

    pMarginalCost_i[i=industry, t=t1:T],
    pMarginalCost_i[i,t] * qY_i[i,t] ==
      pProd[topNest[i],i,t] * qTop2qY[i,t] * qY_i[i,t] + vntProductionOther_i[i,t]
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
    uProd[n=node, i=industry, t=t1; haskey(production_nesting[i], n)],
    pProd[(n,i,t) in keys(uProd); haskey(production_nesting[i], n) && t == t1]

    uProd[n=node, i=industry, t=t1; !haskey(production_nesting[i], n)],
    qProd[(n,i,t) in keys(uProd); !haskey(production_nesting[i], n) && t == t1]

    qTop2qY[:,t1],
    pProd[(n,i,t) in keys(pProd); n == topNest[i] && t == t1]

    # We use an exogenous marginal markup and calibrate an ad-hoc fixed cost to match cost/output in data
    # A model of firm entry can endogenize the fixed cost.
    qFixedCost_i[:,t1], pMarginalCost_i[:,t1]
  end

  return block
end
end # module
