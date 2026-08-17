# Product, use, origin, margin, and supply accounts.
include(joinpath(@__DIR__, "InputOutputSettings.jl"))

module InputOutput

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutputSettings:
  I,
  O,
  P,
  U,
  cell_tolerance,
  input_output_data_dir,
  margin_services,
  ordinary_uses
import ..Settings: calibration_year
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant

const domestic = :domestic
const import_origin = :import

# ============================================================================
# Checked-in benchmark data
# ============================================================================

const supply_file = joinpath(input_output_data_dir, "input_output_supply.csv")
const direct_file = joinpath(input_output_data_dir, "input_output_direct_use.csv")
const margin_file = joinpath(input_output_data_dir, "input_output_margins.csv")
const adjustment_file = joinpath(input_output_data_dir, "input_output_price_adjustments.csv")
const check_file = joinpath(input_output_data_dir, "input_output_checks.csv")

"""Read one variable from a checked-in file into a dictionary keyed by index tuple."""
function read_cells(file, variable)
  data = read_sparse_array(file; variable)
  cells = Dict(key => data[key...] for key in eachindex(data))
  @assert all(isfinite, values(cells)) "$variable in $file must be finite"
  return cells
end

"""Benchmark-year value of one cell. Cells the source does not report are zero."""
benchmark(cells, index...) = get(cells, (index..., calibration_year), 0.0)

const qY_p_i_data = read_cells(supply_file, "qY_p_i_reported")
const qMargin_p_u_data = read_cells(margin_file, "qMargin_p_u_reported")
const qS_s_u_o_data = read_cells(margin_file, "qS_s_u_o_reclassified")
const vProductTax_u_data = read_cells(adjustment_file, "vProductTax_u_reported")
# The source keeps reported, estimated, and reclassified direct use apart.
const qD_p_u_o_data = mergewith(
  +,
  (
    read_cells(direct_file, variable)
    for variable in
    ("qD_p_u_o_reported", "qD_p_u_o_estimated", "qD_p_u_o_reclassified")
  )...,
)

# ============================================================================
# Cell masks
# ============================================================================
# Each mask is named after the indices it holds. Cells outside a mask have no
# variable and no equation, so a mask change needs a model rebuild.

"""Cells with a non-negligible benchmark value. The last index is the year."""
active_cells(cells) = Set(
  key[1:(end - 1)]
  for (key, value) in cells
  if key[end] == calibration_year && abs(value) > cell_tolerance
)

const supply_p_i = active_cells(qY_p_i_data)
const direct_p_u_o = active_cells(qD_p_u_o_data)
const margin_s_u_o = active_cells(qS_s_u_o_data)
const reported_margin_p_u = active_cells(qMargin_p_u_data)
const product_tax_u = Set(u for (u,) in active_cells(vProductTax_u_data))

const supply_p = Set(p for (p, _) in supply_p_i)
const supply_i = Set(i for (_, i) in supply_p_i)
const direct_p_u = Set((p, u) for (p, u, _) in direct_p_u_o)
const direct_u = Set(u for (_, u) in direct_p_u)
const margin_s_u = Set((s, u) for (s, u, _) in margin_s_u_o)
const margin_u = Set(u for (_, u) in margin_s_u)

# A product reaches a use as direct demand or as a derived margin service.
const delivery_p_u_o = direct_p_u_o ∪ margin_s_u_o
const domestic_p_u = Set((p, u) for (p, u, o) in delivery_p_u_o if o == domestic)
const import_p_u = Set((p, u) for (p, u, o) in delivery_p_u_o if o == import_origin)
const domestic_u = Set(u for (_, u) in domestic_p_u)
const import_p = Set(p for (p, _) in import_p_u)
const import_u = Set(u for (_, u) in import_p_u)

# Fixed product and origin shares cover ordinary uses only. Inventory cells are
# exogenous and keep their reported sign.
const ordinary_p_u_o = Set((p, u, o) for (p, u, o) in direct_p_u_o if u in ordinary_uses)
const ordinary_p_u = Set((p, u) for (p, u, _) in ordinary_p_u_o)
const inventory_p_u_o = setdiff(direct_p_u_o, ordinary_p_u_o)
const origin_share_p_u_o = ordinary_p_u_o ∪ margin_s_u_o
const margin_only_s_u_o = setdiff(margin_s_u_o, ordinary_p_u_o)
# Direct demand in a use with margin services carries the reported product-use margin.
const carried_p_u = Set((p, u) for (p, u) in direct_p_u if u in margin_u)

# ============================================================================
# Variables
# ============================================================================

const InputOutputTag = Tag(:InputOutput)

# Margin services are products, so the margin variables keep the full product
# domain. Product clearing and import totals index them by any product.
@variables db.model :: (InputOutputTag, GrowthAdjusted, InflationAdjusted) begin
  vY_p_i[p = P, i = I, t = t; (p, i) in supply_p_i], "Basic-price output by product and industry"
  vD_p_u[p = P, u = U, t = t; (p, u) in direct_p_u], "Direct purchaser spend by product and use"
  vD_p_u_o[p = P, u = U, o = O, t = t; (p, u, o) in direct_p_u_o], "Direct purchaser spend by product, use, and origin"
  vS_u[u = U, t = t; u in margin_u], "Margin-bundle value by use"
  vS_s_u[s = margin_services, u = U, t = t; (s, u) in margin_s_u], "Margin-service value by service and use"
  vS_s_u_o[s = P, u = U, o = O, t = t; (s, u, o) in margin_s_u_o], "Margin-service value by service, use, and origin"
  vY_p_u[p = P, u = U, t = t; (p, u) in domestic_p_u], "Domestic deliveries by product and use"
  vM_p_u[p = P, u = U, t = t; (p, u) in import_p_u], "Imports by product and use"

  vY_p[p = P, t = t; p in supply_p], "Domestic output by product"
  vY_i[i = I, t = t; i in supply_i], "Domestic output by industry"
  vY_u[u = U, t = t; u in domestic_u], "Domestic output by use"
  vD_u[u = U, t = t; u in direct_u], "Direct purchaser spend by use"
  vProductTax_u[u = U, t = t; u in product_tax_u], "Product taxes by use"
  vM_p[p = P, t = t; p in import_p], "Imports by product"
  vM_u[u = U, t = t; u in import_u], "Imports by use"

  vC[t], "Household and non-profit consumption"
  vCTourist[t], "Consumption in the country by non-resident households"
  vG[t], "Government consumption"
  vI[t], "Fixed investment"
  vINV[t], "Change in inventories"
  vX[t], "Total exports"
  vY[t], "Total domestic output"
  vM[t], "Total imports"
end

@variables db.model :: (InputOutputTag, InflationAdjusted) begin
  pY_p_i[p = P, i = I, t = t; (p, i) in supply_p_i], "Domestic basic price by product and industry"
  pY_p[p = P, t = t; p in supply_p], "Domestic basic price by product"
  pY_i[i = I, t = t; i in supply_i], "Domestic basic price by industry"
  pY_p_u[p = P, u = U, t = t; (p, u) in domestic_p_u], "Domestic basic price by product and use"
  pY_u[u = ordinary_uses, t = t; u in domestic_u], "Domestic output price by use"

  pM_p_u[p = P, u = U, t = t; (p, u) in import_p_u], "Import border price by product and use"
  pB_p_u_o[p = P, u = U, o = O, t = t; (p, u, o) in direct_p_u_o], "Basic or border price by product, use, and origin"
  pD_p_u_o[p = P, u = U, o = O, t = t; (p, u, o) in direct_p_u_o], "Purchaser price by product, use, and origin"
  pD_p_u[p = P, u = ordinary_uses, t = t; (p, u) in ordinary_p_u], "Purchaser price by product and use"
  pD_u[u = ordinary_uses, t = t; u in direct_u], "Purchaser price by use"

  pS_u[u = U, t = t; u in margin_u], "Margin-bundle price by use"
  pS_s_u[s = margin_services, u = U, t = t; (s, u) in margin_s_u], "Margin-service price by service and use"
  pS_s_u_o[s = P, u = U, o = O, t = t; (s, u, o) in margin_s_u_o], "Margin-service price by service, use, and origin"
  pOtherAdjustment_p_u_o[p = P, u = U, o = O, t = t; (p, u, o) in direct_p_u_o] :: ForecastConstant, "Other additive purchaser-price adjustment"

  pM_p[p = P, t = t; p in import_p], "Import price by product"
  pM_u[u = ordinary_uses, t = t; u in import_u], "Import price by use"
  pC[t], "Consumption price"
  pG[t], "Government consumption price"
  pI[t], "Fixed investment price"
  pX[t], "Total export price"
  pY[t], "Domestic output price"
  pM[t], "Import price"
end

@variables db.model :: (InputOutputTag, GrowthAdjusted) begin
  qY_p_i[p = P, i = I, t = t; (p, i) in supply_p_i], "Output by product and industry"
  qD_p_u[p = P, u = U, t = t; (p, u) in direct_p_u], "Direct demand by product and use"
  qD_p_u_o[p = P, u = U, o = O, t = t; (p, u, o) in direct_p_u_o], "Direct demand by product, use, and origin"
  qS_u[u = U, t = t; u in margin_u], "Margin-bundle demand by use"
  qS_s_u[s = margin_services, u = U, t = t; (s, u) in margin_s_u], "Margin-service demand by service and use"
  qS_s_u_o[s = P, u = U, o = O, t = t; (s, u, o) in margin_s_u_o], "Margin-service demand by service, use, and origin"
  qY_p_u[p = P, u = U, t = t; (p, u) in domestic_p_u], "Domestic deliveries by product and use"
  qM_p_u[p = P, u = U, t = t; (p, u) in import_p_u], "Imports by product and use"

  qY_p[p = P, t = t; p in supply_p], "Domestic output by product"
  qY_i[i = I, t = t; i in supply_i], "Domestic output by industry"
  qY_u[u = U, t = t; u in domestic_u], "Domestic output by use"
  qD_u[u = ordinary_uses, t = t; u in direct_u], "Direct demand by use"
  qM_p[p = P, t = t; p in import_p], "Imports by product"
  qM_u[u = U, t = t; u in import_u], "Imports by use"

  qC[t], "Household and non-profit consumption"
  qCTourist[t] :: ForecastConstant, "Consumption in the country by non-resident households"
  qG[t], "Government consumption"
  qI[t], "Fixed investment"
  qINV[t], "Change in inventories"
  qX[t], "Total exports"
  qY[t], "Total domestic output"
  qM[t], "Total imports"
end

@variables db.model :: InputOutputTag begin
  rY_p_i[p = P, i = I, t = t; (p, i) in supply_p_i] :: ForecastConstant, "Fixed industry share for each product"
  rD_p_u[p = P, u = U, t = t; (p, u) in ordinary_p_u] :: ForecastConstant, "Fixed product share for each direct use"
  rO_p_u_o[p = P, u = U, o = O, t = t; (p, u, o) in origin_share_p_u_o] :: ForecastConstant, "Fixed origin share"
  rS_s_u[s = margin_services, u = U, t = t; (s, u) in margin_s_u] :: ForecastConstant, "Fixed margin-service share"
  rS_p_u[p = P, u = U, t = t; (p, u) in carried_p_u] :: ForecastConstant, "Margin-bundle units per unit of direct demand"
  tProduct_u[u = U, t = t; u in product_tax_u] :: ForecastConstant, "Product tax per unit of direct demand"
  tVAT_p_u_o[p = P, u = U, o = O, t = t; (p, u, o) in direct_p_u_o] :: ForecastConstant, "VAT rate"
end

# ============================================================================
# Data
# ============================================================================

function set_data!(db)
  @assert reported_margin_p_u ⊆ direct_p_u "Each reported margin needs direct demand"
  # Calibration divides by the benchmark use total to get shares and tax rates.
  @assert all(
    abs(sum(benchmark(qD_p_u_o_data, p, u, o) for p in P for o in O)) > cell_tolerance
    for u in (direct_u ∩ ordinary_uses) ∪ product_tax_u
  ) "Each use with a fixed product share or a product tax needs non-zero demand"

  db[qY_p_i] .= read_variable(supply_file, qY_p_i; variable = "qY_p_i_reported")
  db[qS_s_u_o] .=
    read_variable(margin_file, qS_s_u_o; variable = "qS_s_u_o_reclassified")
  db[qD_p_u_o] .= [get(qD_p_u_o_data, key, nothing) for key in keys(qD_p_u_o)]

  # Benchmark totals. Calibration holds them fixed while it solves for shares.
  for (p, u) in direct_p_u
    db[qD_p_u[p, u, calibration_year]] =
      sum(benchmark(qD_p_u_o_data, p, u, o) for o in O)
  end
  for (p, u) in carried_p_u
    demand = sum(benchmark(qD_p_u_o_data, p, u, o) for o in O)
    @assert abs(demand) > cell_tolerance "Each margin rate needs non-zero direct demand"
    db[rS_p_u[p, u, calibration_year]] = benchmark(qMargin_p_u_data, p, u) / demand
  end
  for u in direct_u ∩ ordinary_uses
    db[qD_u[u, calibration_year]] =
      sum(benchmark(qD_p_u_o_data, p, u, o) for p in P for o in O)
  end
  for (s, u) in margin_s_u
    db[qS_s_u[s, u, calibration_year]] =
      sum(benchmark(qS_s_u_o_data, s, u, o) for o in O)
  end
  for u in margin_u
    db[qS_u[u, calibration_year]] =
      sum(benchmark(qS_s_u_o_data, s, u, o) for s in margin_services for o in O)
  end

  for (p, u, o) in inventory_p_u_o, tt in (calibration_year + 1):last(t)
    db[qD_p_u_o[p, u, o, tt]] = 0.0
  end

  # D21X31 does not split VAT from other product taxes. The default closure
  # treats the full value as an additive product tax and sets VAT to zero.
  db[tVAT_p_u_o] .= 0.0
  db[pOtherAdjustment_p_u_o] .= 0.0
  db[pY_p_i] .= 1.0
  db[pM_p_u] .= 1.0

  db[vProductTax_u] .= read_variable(
    adjustment_file,
    vProductTax_u;
    variable = "vProductTax_u_reported",
  )
  db[vD_u] .= read_variable(check_file, vD_u; variable = "vD_u_reported")
  db[qCTourist] .= read_variable(check_file, qCTourist; variable = "qCTourist_reported")
  db[vM] .= read_variable(check_file, vM; variable = "vM_reported")
  db[vX] .= read_variable(check_file, vX; variable = "vX_reported")
  db[vY] .= read_variable(check_file, vY; variable = "vY_reported")
  return nothing
end

function set_residual_tolerances!(tolerances)
  tolerances[vD_u] = 1e-6
  # T1620 rounds the carried-product and service sides to EUR 0.01 million.
  tolerances[qS_u] = 0.1
  # The IO and national-account import totals differ by EUR 0.059 million.
  tolerances[vM] = 0.06
  tolerances[vX] = 1e-6
  tolerances[vY] = 1e-6
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block db begin
    # Fixed product and origin shares. Inventories bypass them.
    qD_p_u[(p, u, t) in keys(qD_p_u); t in t1:T && u in ordinary_uses],
    qD_p_u[p, u, t] == rD_p_u[p, u, t] * qD_u[u, t]

    qD_p_u[(p, u, t) in keys(qD_p_u); t in t1:T && u == :INV],
    qD_p_u[p, u, t] == ∑(qD_p_u_o[p, u, o, t] for o in O)

    qD_p_u_o[(p, u, o, t) in keys(qD_p_u_o); t in t1:T && u in ordinary_uses],
    qD_p_u_o[p, u, o, t] == rO_p_u_o[p, u, o, t] * qD_p_u[p, u, t]

    # Derived margin demand. Only uses with reported margins carry a bundle.
    qS_u[(u, t) in keys(qS_u); t in t1:T],
    qS_u[u, t] == ∑(rS_p_u[p, u, t] * qD_p_u[p, u, t] for p in P)

    qS_s_u[(s, u, t) in keys(qS_s_u); t in t1:T],
    qS_s_u[s, u, t] == rS_s_u[s, u, t] * qS_u[u, t]

    qS_s_u_o[(s, u, o, t) in keys(qS_s_u_o); t in t1:T],
    qS_s_u_o[s, u, o, t] == rO_p_u_o[s, u, o, t] * qS_s_u[s, u, t]

    # Product clearing includes domestic margin services.
    qY_p_u[(p, u, t) in keys(qY_p_u); t in t1:T],
    qY_p_u[p, u, t] == qD_p_u_o[p, u, domestic, t] + qS_s_u_o[p, u, domestic, t]

    qY_p[(p, t) in keys(qY_p); t in t1:T],
    qY_p[p, t] == ∑(qY_p_u[p, u, t] for u in U)

    qY_p_i[(p, i, t) in keys(qY_p_i); t in t1:T],
    qY_p_i[p, i, t] == rY_p_i[p, i, t] * qY_p[p, t]

    qY_i[(i, t) in keys(qY_i); t in t1:T],
    qY_i[i, t] == ∑(qY_p_i[p, i, t] for p in P)

    qY_u[(u, t) in keys(qY_u); t in t1:T],
    qY_u[u, t] == ∑(qY_p_u[p, u, t] for p in P)

    # Imports mirror domestic deliveries and include imported margin services.
    qM_p_u[(p, u, t) in keys(qM_p_u); t in t1:T],
    qM_p_u[p, u, t] ==
      qD_p_u_o[p, u, import_origin, t] + qS_s_u_o[p, u, import_origin, t]

    qM_p[(p, t) in keys(qM_p); t in t1:T],
    qM_p[p, t] == ∑(qM_p_u[p, u, t] for u in U)

    qM_u[(u, t) in keys(qM_u); t in t1:T],
    qM_u[u, t] == ∑(qM_p_u[p, u, t] for p in P)

    # Export, final-use, and output totals.
    qM[t = t1:T], qM[t] == ∑(qM_p[p, t] for p in P)
    qX[t = t1:T], qX[t] == qD_u[:X, t] + qCTourist[t]
    qC[t = t1:T], qC[t] == qD_u[:C, t] - qCTourist[t]
    qG[t = t1:T], qG[t] == qD_u[:G, t]
    qI[t = t1:T], qI[t] == qD_u[:K, t]
    qINV[t = t1:T], qINV[t] == ∑(qD_p_u[p, :INV, t] for p in P)
    qY[t = t1:T], qY[t] == ∑(qY_p[p, t] for p in P)

    # Basic, border, margin, and purchaser prices.
    pB_p_u_o[(p, u, o, t) in keys(pB_p_u_o); t in t1:T],
    pB_p_u_o[p, u, o, t] == (o == domestic ? pY_p[p, t] : pM_p_u[p, u, t])

    pS_s_u_o[(s, u, o, t) in keys(pS_s_u_o); t in t1:T],
    pS_s_u_o[s, u, o, t] == (o == domestic ? pY_p[s, t] : pM_p_u[s, u, t])

    pS_s_u[(s, u, t) in keys(pS_s_u); t in t1:T],
    pS_s_u[s, u, t] == ∑(rO_p_u_o[s, u, o, t] * pS_s_u_o[s, u, o, t] for o in O)

    pS_u[(u, t) in keys(pS_u); t in t1:T],
    pS_u[u, t] == ∑(rS_s_u[s, u, t] * pS_s_u[s, u, t] for s in margin_services)

    pD_p_u_o[(p, u, o, t) in keys(pD_p_u_o); t in t1:T],
    pD_p_u_o[p, u, o, t] == (
      pB_p_u_o[p, u, o, t] +
      tProduct_u[u, t] +
      pOtherAdjustment_p_u_o[p, u, o, t] +
      rS_p_u[p, u, t] * pS_u[u, t]
    ) * (1 + tVAT_p_u_o[p, u, o, t])

    pD_p_u[(p, u, t) in keys(pD_p_u); t in t1:T],
    pD_p_u[p, u, t] == ∑(rO_p_u_o[p, u, o, t] * pD_p_u_o[p, u, o, t] for o in O)

    pD_u[(u, t) in keys(pD_u); t in t1:T],
    pD_u[u, t] == ∑(rD_p_u[p, u, t] * pD_p_u[p, u, t] for p in P)

    # Cell values and value totals. Margin value does not enter vD twice.
    vD_p_u_o[(p, u, o, t) in keys(vD_p_u_o); t in t1:T],
    vD_p_u_o[p, u, o, t] == pD_p_u_o[p, u, o, t] * qD_p_u_o[p, u, o, t]

    vD_p_u[(p, u, t) in keys(vD_p_u); t in t1:T],
    vD_p_u[p, u, t] == ∑(vD_p_u_o[p, u, o, t] for o in O)

    vD_u[(u, t) in keys(vD_u); t in t1:T],
    vD_u[u, t] == ∑(vD_p_u[p, u, t] for p in P)

    vProductTax_u[(u, t) in keys(vProductTax_u); t in t1:T],
    vProductTax_u[u, t] ==
      tProduct_u[u, t] * ∑(qD_p_u_o[p, u, o, t] for p in P for o in O)

    vS_s_u_o[(s, u, o, t) in keys(vS_s_u_o); t in t1:T],
    vS_s_u_o[s, u, o, t] == pS_s_u_o[s, u, o, t] * qS_s_u_o[s, u, o, t]

    vS_s_u[(s, u, t) in keys(vS_s_u); t in t1:T],
    vS_s_u[s, u, t] == ∑(vS_s_u_o[s, u, o, t] for o in O)

    vS_u[(u, t) in keys(vS_u); t in t1:T],
    vS_u[u, t] == ∑(vS_s_u[s, u, t] for s in margin_services)

    vY_p_i[(p, i, t) in keys(vY_p_i); t in t1:T],
    vY_p_i[p, i, t] == pY_p_i[p, i, t] * qY_p_i[p, i, t]

    vY_p[(p, t) in keys(vY_p); t in t1:T],
    vY_p[p, t] == ∑(vY_p_i[p, i, t] for i in I)

    pY_p[(p, t) in keys(pY_p); t in t1:T],
    pY_p[p, t] * qY_p[p, t] == vY_p[p, t]

    pY_p_u[(p, u, t) in keys(pY_p_u); t in t1:T],
    pY_p_u[p, u, t] == pY_p[p, t]

    vY_p_u[(p, u, t) in keys(vY_p_u); t in t1:T],
    vY_p_u[p, u, t] == pY_p_u[p, u, t] * qY_p_u[p, u, t]

    vY_i[(i, t) in keys(vY_i); t in t1:T],
    vY_i[i, t] == ∑(vY_p_i[p, i, t] for p in P)

    pY_i[(i, t) in keys(pY_i); t in t1:T],
    pY_i[i, t] * qY_i[i, t] == vY_i[i, t]

    vY_u[(u, t) in keys(vY_u); t in t1:T],
    vY_u[u, t] == ∑(vY_p_u[p, u, t] for p in P)

    pY_u[(u, t) in keys(pY_u); t in t1:T],
    pY_u[u, t] * qY_u[u, t] == vY_u[u, t]

    vM_p_u[(p, u, t) in keys(vM_p_u); t in t1:T],
    vM_p_u[p, u, t] == pM_p_u[p, u, t] * qM_p_u[p, u, t]

    vM_p[(p, t) in keys(vM_p); t in t1:T],
    vM_p[p, t] == ∑(vM_p_u[p, u, t] for u in U)

    pM_p[(p, t) in keys(pM_p); t in t1:T],
    pM_p[p, t] * qM_p[p, t] == vM_p[p, t]

    vM_u[(u, t) in keys(vM_u); t in t1:T],
    vM_u[u, t] == ∑(vM_p_u[p, u, t] for p in P)

    pM_u[(u, t) in keys(pM_u); t in t1:T],
    pM_u[u, t] * qM_u[u, t] == vM_u[u, t]

    vM[t = t1:T], vM[t] == ∑(vM_p[p, t] for p in P)
    pM[t = t1:T], pM[t] * qM[t] == vM[t]

    vX[t = t1:T], vX[t] == vD_u[:X, t] + vCTourist[t]
    pX[t = t1:T], pX[t] * qX[t] == vX[t]

    pC[t = t1:T], pC[t] == pD_u[:C, t]
    vC[t = t1:T], vC[t] == pC[t] * qC[t]
    vCTourist[t = t1:T], vCTourist[t] == pC[t] * qCTourist[t]
    vG[t = t1:T], vG[t] == vD_u[:G, t]
    pG[t = t1:T], pG[t] * qG[t] == vG[t]
    vI[t = t1:T], vI[t] == vD_u[:K, t]
    pI[t = t1:T], pI[t] * qI[t] == vI[t]
    vINV[t = t1:T], vINV[t] == vD_u[:INV, t]

    vY[t = t1:T], vY[t] == ∑(vY_p[p, t] for p in P)
    pY[t = t1:T], pY[t] * qY[t] == vY[t]

    # Post-solve accounts that do not add rows to the square system.
    @test_constraint "Supply shares reproduce product output" qY_p[(p, t) in keys(qY_p); t in t1:T],
      qY_p[p, t] == ∑(qY_p_i[p, i, t] for i in I)

    @test_constraint "Direct-use shares sum to total demand" qD_u[(u, t) in keys(qD_u); t in t1:T],
      qD_u[u, t] == ∑(qD_p_u[p, u, t] for p in P)

    @test_constraint "Origin shares sum to product demand" qD_p_u[(p, u, t) in keys(qD_p_u); t in t1:T && u in ordinary_uses],
      qD_p_u[p, u, t] == ∑(qD_p_u_o[p, u, o, t] for o in O)

    @test_constraint "Margin-service shares sum to the margin bundle" qS_u[(u, t) in keys(qS_u); t in t1:T],
      qS_u[u, t] == ∑(qS_s_u[s, u, t] for s in margin_services)

    @test_constraint "Margin origin shares sum to service demand" qS_s_u[(s, u, t) in keys(qS_s_u); t in t1:T],
      qS_s_u[s, u, t] == ∑(qS_s_u_o[s, u, o, t] for o in O)

    @test_constraint "Purchaser spend excludes separate margin spending" vD_u[(u, t) in keys(vD_u); t in t1:T],
      vD_u[u, t] == ∑(vD_p_u_o[p, u, o, t] for p in P for o in O)

    @test_constraint "Imports sum by product and use" qM[t = t1:T],
      qM[t] == ∑(qM_u[u, t] for u in U)
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    [rY_p_i[p, i, t1] for (p, i) in supply_p_i],
    [qY_p_i[p, i, t1] for (p, i) in supply_p_i]

    [rD_p_u[p, u, t1] for (p, u) in ordinary_p_u],
    [qD_p_u[p, u, t1] for (p, u) in ordinary_p_u]

    [rO_p_u_o[p, u, o, t1] for (p, u, o) in ordinary_p_u_o],
    [qD_p_u_o[p, u, o, t1] for (p, u, o) in ordinary_p_u_o]

    [rS_s_u[s, u, t1] for (s, u) in margin_s_u],
    [qS_s_u[s, u, t1] for (s, u) in margin_s_u]

    [rO_p_u_o[s, u, o, t1] for (s, u, o) in margin_only_s_u_o],
    [qS_s_u_o[s, u, o, t1] for (s, u, o) in margin_only_s_u_o]

    [tProduct_u[u, t1] for u in product_tax_u],
    [vProductTax_u[u, t1] for u in product_tax_u]
  end

  return block
end

# ============================================================================
# Tests
# ============================================================================

function run_tests(db)
  errors = String[]

  all(
    db[qD_p_u_o[p, u, o, calibration_year]] ≈ benchmark(qD_p_u_o_data, p, u, o)
    for (p, u, o) in inventory_p_u_o
  ) || push!(errors, "The benchmark must keep the sign of each inventory cell")

  all(
    db[qD_p_u_o[p, u, o, tt]] == 0
    for (p, u, o) in inventory_p_u_o, tt in (calibration_year + 1):T
  ) || push!(errors, "All inventory cells must be zero after the benchmark year")

  all(
    db[rS_p_u[p, u, calibration_year]] * db[qD_p_u[p, u, calibration_year]] ≈
      benchmark(qMargin_p_u_data, p, u)
    for (p, u) in carried_p_u
  ) || push!(errors, "Margin rates must reproduce reported product-use margins")

  all(
    db[qD_u[:C, tt]] ≈ db[qC[tt]] + db[qCTourist[tt]]
    for tt in t1:T
  ) || push!(errors, "Private-consumption demand must include tourist demand once")

  all(
    db[vX[tt]] ≈ db[vD_u[:X, tt]] + db[vCTourist[tt]]
    for tt in t1:T
  ) || push!(errors, "Total exports must include tourist demand")

  return errors
end

end # module
