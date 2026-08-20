# Industry production costs and factor demand.
include(joinpath(@__DIR__, "ProductionSettings.jl"))

module Production

import JuMP
using SquareModels
import ..CheckedData: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fp, fq
import ..InputOutput:
  pPurchaserUse_p_u,
  pPurchaserUse_u,
  qPurchaserUse_p_u,
  qPurchaserUse_p_u_o_data,
  qPurchaserUse_u,
  qY_i,
  rProductShare,
  vI
import ..InputOutputSettings: cell_tolerance, industry, origin, product
import ..ProductionSettings:
  capital_type,
  intermediate_type,
  investment_product_capital_weight,
  labor_type,
  production_data_dir,
  production_nesting
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
const qL_i_source_data = read_cells(labor_file, "qL_i")
const qL_l_i_data = Dict(
  (only(labor_type), i, year) => value
  for ((i, year), value) in qL_i_source_data
)

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
  if i in output_industry && get(qL_i_source_data, (i, calibration_year), 0.0) > cell_tolerance
]
const intermediate_industry = Set(
  i for (i, year) in keys(qPurchaserUse_u)
  if year == t1 && i in production_industry
)

# The input-output data give products but not capital types. Allocate each
# product with the dummy weights in ProductionSettings, then infer the product
# shares and the unit conversion for each capital type.
const qInvestment_p_data = Dict(
  p => sum(get(qPurchaserUse_p_u_o_data, (p, :K, o, calibration_year), 0.0) for o in origin)
  for p in product
  if abs(sum(get(qPurchaserUse_p_u_o_data, (p, :K, o, calibration_year), 0.0) for o in origin)) > cell_tolerance
)
const investment_product = sort(collect(keys(qInvestment_p_data)))
const qCapitalFlow_k_data = Dict(
  k => sum(get(qI_k_i_data, (k, i, calibration_year), 0.0) for (kk, i) in capital_k_i if kk == k)
  for k in capital_type
)
@assert all(>(cell_tolerance), values(qCapitalFlow_k_data)) "Each capital type needs positive investment"
@assert all(
  sum(investment_product_capital_weight[p, k] * qCapitalFlow_k_data[k] for k in capital_type) > cell_tolerance
  for p in investment_product
) "Each investment product needs a positive capital-allocation weight"

const qInvestment_p_k_data = Dict(
  (p, k) => qInvestment_p_data[p] *
    investment_product_capital_weight[p, k] * qCapitalFlow_k_data[k] /
    sum(investment_product_capital_weight[p, kk] * qCapitalFlow_k_data[kk] for kk in capital_type)
  for p in investment_product, k in capital_type
  if investment_product_capital_weight[p, k] > 0
)
const investment_product_k = Set(keys(qInvestment_p_k_data))
const qInvestment_k_data = Dict(
  k => sum(value for ((_, kk), value) in qInvestment_p_k_data if kk == k)
  for k in capital_type
)
const rInvestmentProductShare_p_k_data = Dict(
  (p, k) => value / qInvestment_k_data[k]
  for ((p, k), value) in qInvestment_p_k_data
)
const rInvestmentScale_k_data = Dict(
  k => qInvestment_k_data[k] / qCapitalFlow_k_data[k]
  for k in capital_type
)

# ProductionSettings gives one full tree for each industry. The data masks and
# settings must agree so that a missing factor cannot change the tree silently.
const children = Dict(
  (n, i) => spec.children
  for i in production_industry for (n, spec) in production_nesting[i]
)
const parent = Dict(
  (child, i) => n
  for ((n, i), nest_children) in children for child in nest_children
)
const production_nest_i = Set(keys(children))
const production_node_i = Set(
  (production_node, i)
  for ((n, i), nest_children) in children for production_node in [n; nest_children]
)
const top_i = Dict(
  i => only(setdiff(
    Set(n for (n, ii) in production_nest_i if ii == i),
    Set(child for ((_, ii), nest_children) in children if ii == i for child in nest_children),
  ))
  for i in production_industry
)
const nest = sort(unique(first.(production_nest_i)))
const node = sort(unique(first.(production_node_i)))
const production_child_node_i = Set(
  (production_node, i)
  for (production_node, i) in production_node_i
  if production_node != top_i[i]
)
const non_top_nest_i = Set(
  (production_nest, i)
  for (production_nest, i) in production_nest_i
  if production_nest != top_i[i]
)

const configured_capital_k_i = Set((pf, i) for (pf, i) in production_node_i if pf in capital_type)
const configured_intermediate_m_i = Set((pf, i) for (pf, i) in production_node_i if pf in intermediate_type)
@assert configured_capital_k_i == capital_k_i "Capital data and the industry nest maps must agree"
@assert all((l, i) in production_node_i for l in labor_type, i in production_industry) "Each production industry needs each labor type"
@assert configured_intermediate_m_i == Set((m, i) for m in intermediate_type, i in intermediate_industry) "Intermediate data and the industry nest maps must agree"

# ============================================================================
# Variables
# ============================================================================

const ProductionTag = Tag(:Production)

@variables db.model :: (ProductionTag, GrowthAdjusted) begin
  qK_k_i[k = capital_type, i = production_industry, t = t; (k, i) in capital_k_i], "Capital stock by type and industry"
  qI_k_i[(k, i, t) = qK_k_i], "Investment by capital type and industry"
  qI_k[k = capital_type, t = t], "Investment by capital type in purchaser units"
  qI_p_k[p = investment_product, k = capital_type, t = t; (p, k) in investment_product_k], "Investment by product and capital type"
  qInstCost_k_i[(k, i, t) = qK_k_i], "Capital installation cost"
  qL_l_i[l = labor_type, i = production_industry, t = t], "Labor in efficiency units by type and industry"
  qM_m_i[m = intermediate_type, i = production_industry, t = t; i in intermediate_industry], "Intermediate input by type and industry"
  qProd[pf = node, i = production_industry, t = t; (pf, i) in production_node_i], "Quantity at a production node"
end

@variables db.model :: (ProductionTag, InflationAdjusted) begin
  pK_k_i[(k, i, t) = qK_k_i], "User cost of capital"
  pI_k[k = capital_type, t = t], "Investment price by capital type"
  pL_l_i[l = labor_type, i = production_industry, t = t], "Wage per labor unit by type and industry"
  pM_m_i[m = intermediate_type, i = production_industry, t = t; i in intermediate_industry], "Intermediate input price by type and industry"
  pMarginalCapitalTax_k_i[(k, i, t) = qK_k_i], "Marginal corporation tax per unit of capital"
  pProd[(pf, i, t) = qProd], "Price at a production node"
  pY0_i[i = production_industry, t = t], "Unit production cost"
end

@variables db.model :: (ProductionTag, GrowthAdjusted, InflationAdjusted) begin
  vI_k_i[(k, i, t) = qK_k_i], "Investment by capital type and industry"
  vProductionTax_i[i = production_industry, t = t], "Production taxes in marginal production cost"
end

@variables db.model :: ProductionTag begin
  qK2qY_k_i[(k, i, t) = qK_k_i], "Capital per unit of output"
  qL2qY_l_i[l = labor_type, i = production_industry, t = t], "Labor per unit of output by type and industry"
  qM2qY_m_i[m = intermediate_type, i = production_industry, t = t; i in intermediate_industry], "Intermediate input per unit of output by type and industry"

  uProd[pf = node, i = production_industry, t = t; (pf, i) in production_child_node_i] :: ForecastConstant, "CES share at a production node"
  pProd2pNest[pf = node, i = production_industry, t = t; (pf, i) in production_child_node_i], "Child price relative to its parent price"
  eProd[n = nest, i = production_industry; (n, i) in production_nest_i], "Substitution elasticity in a production nest"

  rKDepr_k_i[(k, i, t) = qK_k_i] :: ForecastConstant, "Capital depreciation rate"
  rHurdleRate_i[i = production_industry, t = t] :: ForecastConstant, "Investment hurdle rate"
  rInvestmentScale_k[k = capital_type, t = t] :: ForecastConstant, "Purchaser investment units per capital-flow unit by capital type"
  rInvestmentProductShare_p_k[(p, k, t) = qI_p_k] :: ForecastConstant, "Fixed product share for each capital type"
  fInstCost_k_i[(k, i, t) = qK_k_i] :: ForecastConstant, "Installation-cost factor"
  dInstCost2dK_k_i[(k, i, t) = qK_k_i], "Installation-cost derivative for current capital"
  dInstCost2dKLag_k_i[(k, i, t) = qK_k_i], "Installation-cost derivative for lagged capital"
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
  @assert Set(investment_product) == Set(p for (p, u, year) in keys(qPurchaserUse_p_u) if u == :K && year == t1) "Dummy investment products must match input-output cells"

  fill_cells!(db, qK_k_i, qK_k_i_data)
  fill_cells!(db, qI_k_i, qI_k_i_data)
  fill_cells!(db, qL_l_i, qL_l_i_data)

  db[pL_l_i] .= 1.0
  db[eProd] .= [production_nesting[i][n].elasticity for (n, i) in keys(eProd)]
  db[rHurdleRate_i] .= 0.2
  db[fInstCost_k_i] .= 0.5
  db[pMarginalCapitalTax_k_i] .= 0.0
  db[vProductionTax_i] .= 0.0
  db[rInvestmentScale_k] .= [
    year == t1 ? rInvestmentScale_k_data[k] : nothing
    for k in capital_type, year in t
  ]
  db[rInvestmentProductShare_p_k] .= [
    year == t1 ? rInvestmentProductShare_p_k_data[p, k] : nothing
    for (p, k, year) in keys(rInvestmentProductShare_p_k)
  ]

  # Calibration fixes non-top nest prices and solves for their CES shares. The
  # top price follows from the nest budget and the leaf prices.
  db[pProd] .= [
    (production_node, i) in non_top_nest_i && year == t1 ? 1.0 : nothing
    for (production_node, i, year) in keys(pProd)
  ]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

define_equations() = define_equations(t1:T)

function define_equations(investment_link_years)
  return @block db begin
    # Factor-output links.
    qK_k_i[(k, i, t) in keys(qK_k_i); t in t1:T],
    qK_k_i[k, i, t] == qK2qY_k_i[k, i, t] * qY_i[i, t]

    qL_l_i[l = labor_type, i = production_industry, t = t1:T],
    qL_l_i[l, i, t] == qL2qY_l_i[l, i, t] * qY_i[i, t]

    qM_m_i[(m, i, t) in keys(qM_m_i); t in t1:T],
    qM_m_i[m, i, t] == qM2qY_m_i[m, i, t] * qY_i[i, t]

    qPurchaserUse_u[i = production_industry, t = t1:T; i in intermediate_industry],
    qPurchaserUse_u[i, t] == ∑(qM_m_i[m, i, t] for m in intermediate_type)

    # Capital accumulation and the fixed-investment product split.
    qI_k_i[(k, i, t) in keys(qI_k_i); t in t1:T],
    qI_k_i[k, i, t] ==
      qK_k_i[k, i, t] -
      (1 - rKDepr_k_i[k, i, t]) * qK_k_i[k, i, t - 1] / fq

    qI_k[k = capital_type, t = t1:T],
    qI_k[k, t] ==
      rInvestmentScale_k[k, t] *
      ∑(qI_k_i[k, i, t] for i in production_industry if (k, i) in capital_k_i)

    qI_p_k[(p, k, t) in keys(qI_p_k); t in t1:T],
    qI_p_k[p, k, t] == rInvestmentProductShare_p_k[p, k, t] * qI_k[k, t]

    rProductShare[(p, u, t) in keys(rProductShare); u == :K && t in investment_link_years],
    qPurchaserUse_p_u[p, u, t] ==
      ∑(qI_p_k[p, k, t] for k in capital_type if (p, k) in investment_product_k)

    qPurchaserUse_u[u = [:K], t = investment_link_years],
    qPurchaserUse_u[u, t] == ∑(qI_k[k, t] for k in capital_type)

    pI_k[k = capital_type, t = t1:T],
    pI_k[k, t] ==
      ∑(
        rInvestmentProductShare_p_k[p, k, t] * pPurchaserUse_p_u[p, :K, t]
        for p in investment_product if (p, k) in investment_product_k
      )

    vI_k_i[(k, i, t) in keys(vI_k_i); t in t1:T],
    vI_k_i[k, i, t] ==
      pI_k[k, t] * rInvestmentScale_k[k, t] * qI_k_i[k, i, t]

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
    pProd2pNest[pf, i, t] == pProd[pf, i, t] / pProd[parent[pf, i], i, t]

    qProd[(pf, i, t) in keys(qProd); pf == top_i[i] && t in t1:T],
    qProd[pf, i, t] ==
      qY_i[i, t] + ∑(qInstCost_k_i[k, i, t] for k in capital_type if (k, i) in capital_k_i)

    qProd[(pf, i, t) in keys(qProd); pf != top_i[i] && t in t1:T],
    qProd[pf, i, t] ==
      uProd[pf, i, t] *
      pProd2pNest[pf, i, t]^(-eProd[parent[pf, i], i]) *
      qProd[parent[pf, i], i, t]

    pProd[n = nest, i = production_industry, t = t1:T; (n, i) in production_nest_i],
    pProd[n, i, t] * qProd[n, i, t] ==
      ∑(pProd[child, i, t] * qProd[child, i, t] for child in children[n, i])

    pY0_i[i = production_industry, t = t1:T],
    pY0_i[i, t] * qY_i[i, t] ==
      pProd[top_i[i], i, t] * qY_i[i, t] + vProductionTax_i[i, t]

    # Prices and quantities at the tree leaves.
    pM_m_i[(m, i, t) in keys(pM_m_i); t in t1:T],
    pM_m_i[m, i, t] == pPurchaserUse_u[i, t]

    pProd[(pf, i, t) in keys(pProd); pf in intermediate_type && i in intermediate_industry && t in t1:T],
    pProd[pf, i, t] == pM_m_i[pf, i, t]

    pProd[(pf, i, t) in keys(pProd); pf in labor_type && t in t1:T],
    pProd[pf, i, t] == pL_l_i[pf, i, t]

    pProd[(pf, i, t) in keys(pProd); pf in capital_type && (pf, i) in capital_k_i && t in t1:T],
    pProd[pf, i, t] == pK_k_i[pf, i, t] / pK_k_i[pf, i, base_year]

    qM2qY_m_i[(m, i, t) in keys(qM2qY_m_i); t in t1:T],
    qM_m_i[m, i, t] == qProd[m, i, t]

    qL2qY_l_i[l = labor_type, i = production_industry, t = t1:T],
    qL_l_i[l, i, t] == qProd[l, i, t]

    qK2qY_k_i[(k, i, t) in keys(qK2qY_k_i); t in t1:T],
    qProd[k, i, t] == qK_k_i[k, i, t] * pK_k_i[k, i, base_year]

    # User cost of capital.
    pK_k_i[(k, i, t) in keys(pK_k_i); t in t1:(T - 1)],
    pK_k_i[k, i, t] ==
      pI_k[k, t] * rInvestmentScale_k[k, t] +
      pMarginalCapitalTax_k_i[k, i, t] -
      (1 - rKDepr_k_i[k, i, t + 1]) /
      (1 + rHurdleRate_i[i, t + 1]) *
      (pI_k[k, t + 1] * rInvestmentScale_k[k, t + 1] - pMarginalCapitalTax_k_i[k, i, t + 1]) * fp +
      pProd[top_i[i], i, t] * dInstCost2dK_k_i[k, i, t] +
      dInstCost2dKLag_k_i[k, i, t] /
      (1 + rHurdleRate_i[i, t + 1]) * pProd[top_i[i], i, t + 1] * fp

    pK_k_i[(k, i, t) in keys(pK_k_i); t == T],
    pK_k_i[k, i, t] ==
      pI_k[k, t] * rInvestmentScale_k[k, t] +
      pMarginalCapitalTax_k_i[k, i, t] -
      (1 - rKDepr_k_i[k, i, t]) /
      (1 + rHurdleRate_i[i, t]) *
      (pI_k[k, t] * rInvestmentScale_k[k, t] - pMarginalCapitalTax_k_i[k, i, t]) * fp +
      pProd[top_i[i], i, t] * dInstCost2dK_k_i[k, i, t] +
      dInstCost2dKLag_k_i[k, i, t] /
      (1 + rHurdleRate_i[i, t]) * pProd[top_i[i], i, t] * fp

    @test_constraint("Capital investment values sum to fixed investment"; rtol = 1e-3)
    vI[t = t1:T], vI[t] == ∑(vI_k_i[k, i, t] for (k, i) in capital_k_i)
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  # InputOutput calibrates its reported base-year product cells and use total.
  # Production replaces those closures in later years and in the base model.
  block = define_equations((t1 + 1):T)

  @endo_exo_swap! block begin
    [rKDepr_k_i[k, i, t1] for (k, i) in capital_k_i],
    [qI_k_i[k, i, t1] for (k, i) in capital_k_i]

    [uProd[n, i, t1] for (n, i) in non_top_nest_i],
    [pProd[n, i, t1] for (n, i) in non_top_nest_i]

    [uProd[m, i, t1] for m in intermediate_type, i in intermediate_industry],
    [qPurchaserUse_u[i, t1] for i in intermediate_industry]

    [uProd[k, i, t1] for (k, i) in capital_k_i if i in production_industry],
    [qK_k_i[k, i, t1] for (k, i) in capital_k_i if i in production_industry]

    [uProd[l, i, t1] for l in labor_type, i in production_industry],
    [qL_l_i[l, i, t1] for l in labor_type, i in production_industry]
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
