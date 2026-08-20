# Industry production costs and factor demand.
include(joinpath(@__DIR__, "ProductionSettings.jl"))

module Production

import JuMP
using SquareModels
import ..CheckedData: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fp, fq
import ..InputOutput:
  pI,
  pPurchaserUse_u,
  qPurchaserUse_u,
  qY_i,
  vI
import ..InputOutputSettings: cell_tolerance, industry
import ..ProductionSettings: capital_type, production_data_dir
import ..Settings: base_year, calibration_year
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Checked-in data
# ============================================================================

const capital_file = joinpath(production_data_dir, "production_capital.csv")
const labor_file = joinpath(production_data_dir, "production_labor.csv")

const qK_k_i_data = read_cells(capital_file, "qK_k_i")
const qI_k_i_data = read_cells(capital_file, "qI_k_i")
const qL_i_data = read_cells(labor_file, "qL_i")

# ============================================================================
# Cell masks and production tree
# ============================================================================

# A capital cell needs a positive current and lagged stock.
const capital_k_i = Set(
  (k, i)
  for (k, i, year) in keys(qK_k_i_data)
  if year == calibration_year &&
    get(qK_k_i_data, (k, i, calibration_year), 0.0) > cell_tolerance &&
    get(qK_k_i_data, (k, i, calibration_year - 1), 0.0) > cell_tolerance
)

const output_industry = Set(i for (i, year) in keys(qY_i) if year == t1)
const production_industry = [
  i for i in industry
  if i in output_industry && get(qL_i_data, (i, calibration_year), 0.0) > cell_tolerance
]
const intermediate_industry = Set(
  i for (i, year) in keys(qPurchaserUse_u)
  if year == t1 && i in production_industry
)

# The tree has no one-child nests. A missing capital or intermediate cell also
# removes that leaf and any nest with no live child.
const children = Dict(
  :equipment_labor => [:equipment, :labor],
  :capital_labor => [:equipment_labor, :structures],
  :production => [:capital_labor, :intermediate],
)
const parent = Dict(child => nest for (nest, nest_children) in children for child in nest_children)
const nest = sort(collect(keys(children)))
const top = only(setdiff(keys(children), keys(parent)))
const node = sort(unique(vcat(collect(keys(children)), collect(Iterators.flatten(values(children))))))
const non_top_nest = setdiff(nest, [top])

const live_leaf_node_i = union(
  Set((:labor, i) for i in production_industry),
  Set((k, i) for (k, i) in capital_k_i if i in production_industry),
  Set((:intermediate, i) for i in intermediate_industry),
)
live(node, i) =
  (node, i) in live_leaf_node_i ||
  (haskey(children, node) && any(live(child, i) for child in children[node]))

const production_node_i = Set(
  (production_node, i)
  for production_node in node, i in production_industry
  if live(production_node, i)
)
const production_child_node_i = Set(
  (production_node, i)
  for (production_node, i) in production_node_i
  if production_node != top
)
const production_nest_i = Set(
  (production_nest, i)
  for (production_nest, i) in production_node_i
  if production_nest in nest
)
const non_top_nest_i = Set(
  (production_nest, i)
  for (production_nest, i) in production_nest_i
  if production_nest != top
)

# ============================================================================
# Variables
# ============================================================================

const ProductionTag = Tag(:Production)

@variables db.model :: (ProductionTag, GrowthAdjusted) begin
  qK_k_i[k = capital_type, i = production_industry, t = t; (k, i) in capital_k_i], "Capital stock by type and industry"
  qI_k_i[(k, i, t) = qK_k_i], "Investment by capital type and industry"
  qInstCost_k_i[(k, i, t) = qK_k_i], "Capital installation cost"
  qL_i[i = production_industry, t = t], "Labor in efficiency units"
  qProd[pf = node, i = production_industry, t = t; (pf, i) in production_node_i], "Quantity at a production node"
  qY0_i[i = production_industry, t = t], "Output net of installation costs"
end

@variables db.model :: (ProductionTag, InflationAdjusted) begin
  pK_k_i[(k, i, t) = qK_k_i], "User cost of capital"
  pL_i[i = production_industry, t = t], "Wage per labor unit"
  pProd[(pf, i, t) = qProd], "Price at a production node"
  pY0_i[i = production_industry, t = t], "Unit production cost"
end

@variables db.model :: (ProductionTag, GrowthAdjusted, InflationAdjusted) begin
  vI_k_i[(k, i, t) = qK_k_i], "Investment by capital type and industry"
end

@variables db.model :: ProductionTag begin
  qK2qY_k_i[(k, i, t) = qK_k_i], "Capital per unit of output"
  qL2qY_i[i = production_industry, t = t], "Labor per unit of output"
  qIntermediate2qY_i[i = production_industry, t = t; i in intermediate_industry], "Intermediate input per unit of output"
  qTop2qY_i[i = production_industry, t = t] :: ForecastConstant, "Top-node units per unit of output"

  uProd[pf = node, i = production_industry, t = t; (pf, i) in production_child_node_i] :: ForecastConstant, "CES share at a production node"
  pProd2pNest[pf = node, i = production_industry, t = t; (pf, i) in production_child_node_i], "Child price relative to its parent price"
  eProd[n = nest, i = production_industry; (n, i) in production_nest_i], "Substitution elasticity in a production nest"

  rKDepr_k_i[(k, i, t) = qK_k_i] :: ForecastConstant, "Capital depreciation rate"
  rHurdleRate_i[i = production_industry, t = t] :: ForecastConstant, "Investment hurdle rate"
  rInvestmentScale[t = t] :: ForecastConstant, "Purchaser investment units per capital-flow unit"
  fInstCost_k_i[(k, i, t) = qK_k_i] :: ForecastConstant, "Installation-cost factor"
  dInstCost2dK_k_i[(k, i, t) = qK_k_i], "Installation-cost derivative for current capital"
  dInstCost2dKLag_k_i[(k, i, t) = qK_k_i], "Installation-cost derivative for lagged capital"
  jpK_k_i[(k, i, t) = qK_k_i], "User-cost addition"
end

JuMP.set_lower_bound.(
  [pProd2pNest[pf, i, year] for (pf, i, year) in keys(pProd2pNest)],
  1e-4,
)

# ============================================================================
# Data
# ============================================================================

function set_data!(db)
  @assert Set(first.(capital_k_i)) == Set(capital_type) "Each capital type needs a live stock"
  @assert all(haskey(qI_k_i_data, (k, i, t1)) for (k, i) in capital_k_i) "Each capital stock needs calibration-year investment"
  @assert all((i, t1) in keys(qY_i) for i in production_industry) "Each production industry needs output"
  @assert all((i, t1) in keys(qPurchaserUse_u) for i in intermediate_industry) "Each intermediate leaf needs purchaser use"
  @assert (:K, t1) in keys(qPurchaserUse_u) "Production needs fixed investment purchaser use"

  fill_cells!(db, qK_k_i, qK_k_i_data)
  fill_cells!(db, qI_k_i, qI_k_i_data)
  fill_cells!(db, qL_i, qL_i_data)

  db[pL_i] .= 1.0
  db[eProd] .= 0.7
  db[rHurdleRate_i] .= 0.2
  db[fInstCost_k_i] .= 0.5
  db[jpK_k_i] .= 0.0

  # Calibration fixes nest prices at one and solves for their CES shares.
  db[pProd] .= [
    production_node in nest && year == t1 ? 1.0 : nothing
    for (production_node, _, year) in keys(pProd)
  ]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block db begin
    # Fixed factor-output links.
    qK_k_i[(k, i, t) in keys(qK_k_i); t in t1:T],
    qK_k_i[k, i, t] == qK2qY_k_i[k, i, t] * qY_i[i, t]

    qL_i[i = production_industry, t = t1:T],
    qL_i[i, t] == qL2qY_i[i, t] * qY_i[i, t]

    qPurchaserUse_u[i = production_industry, t = t1:T; i in intermediate_industry],
    qPurchaserUse_u[i, t] == qIntermediate2qY_i[i, t] * qY_i[i, t]

    # Capital accumulation and its fixed-investment link.
    qI_k_i[(k, i, t) in keys(qI_k_i); t in t1:T],
    qI_k_i[k, i, t] ==
      qK_k_i[k, i, t] -
      (1 - rKDepr_k_i[k, i, t]) * qK_k_i[k, i, t - 1] / fq

    qPurchaserUse_u[u = [:K], t = t1:T],
    qPurchaserUse_u[u, t] ==
      rInvestmentScale[t] * ∑(qI_k_i[k, i, t] for (k, i) in capital_k_i)

    vI_k_i[(k, i, t) in keys(vI_k_i); t in t1:T],
    vI_k_i[k, i, t] == pI[t] * rInvestmentScale[t] * qI_k_i[k, i, t]

    # Capital installation costs.
    qInstCost_k_i[(k, i, t) in keys(qInstCost_k_i); t in t1:T],
    qInstCost_k_i[k, i, t] ==
      fInstCost_k_i[k, i, t] *
      (qI_k_i[k, i, t] / qK_k_i[k, i, t - 1])^2 *
      qK_k_i[k, i, t - 1]

    dInstCost2dK_k_i[(k, i, t) in keys(dInstCost2dK_k_i); t in t1:T],
    dInstCost2dK_k_i[k, i, t] ==
      2 * fInstCost_k_i[k, i, t] * qI_k_i[k, i, t] /
      (qK_k_i[k, i, t - 1] / fq)

    dInstCost2dKLag_k_i[(k, i, t) in keys(dInstCost2dKLag_k_i); t in t1:(T - 1)],
    dInstCost2dKLag_k_i[k, i, t] ==
      -fInstCost_k_i[k, i, t] *
      (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t + 1] * fq / qK_k_i[k, i, t]) *
      (qI_k_i[k, i, t + 1] * fq / qK_k_i[k, i, t])

    dInstCost2dKLag_k_i[(k, i, t) in keys(dInstCost2dKLag_k_i); t == T],
    dInstCost2dKLag_k_i[k, i, t] ==
      -fInstCost_k_i[k, i, t] *
      (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t] * fq / qK_k_i[k, i, t]) *
      (qI_k_i[k, i, t] * fq / qK_k_i[k, i, t])

    # Nested CES production costs and factor demand.
    pProd2pNest[(pf, i, t) in keys(pProd2pNest); t in t1:T],
    pProd2pNest[pf, i, t] == pProd[pf, i, t] / pProd[parent[pf], i, t]

    qProd[pf = [top], i = production_industry, t = t1:T],
    qProd[pf, i, t] ==
      qY0_i[i, t] + ∑(qInstCost_k_i[k, i, t] for k in capital_type if (k, i) in capital_k_i)

    qProd[(pf, i, t) in keys(qProd); pf != top && t in t1:T],
    qProd[pf, i, t] ==
      uProd[pf, i, t] *
      pProd2pNest[pf, i, t]^(-eProd[parent[pf], i]) *
      qProd[parent[pf], i, t]

    pProd[n = nest, i = production_industry, t = t1:T; (n, i) in production_nest_i],
    pProd[n, i, t] * qProd[n, i, t] ==
      ∑(pProd[child, i, t] * qProd[child, i, t] for child in children[n] if (child, i) in production_node_i)

    qY0_i[i = production_industry, t = t1:T],
    qY0_i[i, t] == qTop2qY_i[i, t] * qY_i[i, t]

    pY0_i[i = production_industry, t = t1:T],
    pY0_i[i, t] * qY0_i[i, t] == pProd[top, i, t] * qProd[top, i, t]

    # Prices and quantities at the tree leaves.
    pProd[pf = [:intermediate], i = production_industry, t = t1:T; i in intermediate_industry],
    pProd[pf, i, t] == pPurchaserUse_u[i, t]

    pProd[pf = [:labor], i = production_industry, t = t1:T],
    pProd[pf, i, t] == pL_i[i, t]

    pProd[pf = capital_type, i = production_industry, t = t1:T; (pf, i) in capital_k_i],
    pProd[pf, i, t] == pK_k_i[pf, i, t] / pK_k_i[pf, i, base_year]

    qIntermediate2qY_i[i = production_industry, t = t1:T; i in intermediate_industry],
    qPurchaserUse_u[i, t] == qProd[:intermediate, i, t]

    qL2qY_i[i = production_industry, t = t1:T],
    qL_i[i, t] == qProd[:labor, i, t]

    qK2qY_k_i[(k, i, t) in keys(qK2qY_k_i); t in t1:T],
    qProd[k, i, t] == qK_k_i[k, i, t] * pK_k_i[k, i, base_year]

    # User cost of capital.
    pK_k_i[(k, i, t) in keys(pK_k_i); t in t1:(T - 1)],
    pK_k_i[k, i, t] ==
      pI[t] * rInvestmentScale[t] -
      (1 - rKDepr_k_i[k, i, t]) /
      (1 + rHurdleRate_i[i, t + 1]) * pI[t + 1] * rInvestmentScale[t + 1] * fp +
      pProd[top, i, t] * dInstCost2dK_k_i[k, i, t] +
      dInstCost2dKLag_k_i[k, i, t] /
      (1 + rHurdleRate_i[i, t + 1]) * pProd[top, i, t + 1] * fp +
      jpK_k_i[k, i, t]

    pK_k_i[(k, i, t) in keys(pK_k_i); t == T],
    pK_k_i[k, i, t] ==
      pI[t] * rInvestmentScale[t] -
      (1 - rKDepr_k_i[k, i, t]) /
      (1 + rHurdleRate_i[i, t]) * pI[t] * rInvestmentScale[t] * fp +
      pProd[top, i, t] * dInstCost2dK_k_i[k, i, t] +
      dInstCost2dKLag_k_i[k, i, t] /
      (1 + rHurdleRate_i[i, t]) * pProd[top, i, t] * fp +
      jpK_k_i[k, i, t]

    @test_constraint("Capital investment values sum to fixed investment"; rtol = 1e-3)
    vI[t = t1:T], vI[t] == ∑(vI_k_i[k, i, t] for (k, i) in capital_k_i)
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    [rKDepr_k_i[k, i, t1] for (k, i) in capital_k_i],
    [qI_k_i[k, i, t1] for (k, i) in capital_k_i]

    [uProd[n, i, t1] for (n, i) in non_top_nest_i],
    [pProd[n, i, t1] for (n, i) in non_top_nest_i]

    [uProd[:intermediate, i, t1] for i in intermediate_industry],
    [qPurchaserUse_u[i, t1] for i in intermediate_industry]

    [uProd[k, i, t1] for (k, i) in capital_k_i if i in production_industry],
    [qK_k_i[k, i, t1] for (k, i) in capital_k_i if i in production_industry]

    [uProd[:labor, i, t1] for i in production_industry],
    [qL_i[i, t1] for i in production_industry]

    [qTop2qY_i[i, t1] for i in production_industry],
    [pProd[top, i, t1] for i in production_industry]

    rInvestmentScale[t1], qPurchaserUse_u[:K, t1]
  end

  return block
end

# ============================================================================
# Tests
# ============================================================================

function run_tests(db)
  errors = String[]
  return errors
end

end # module
