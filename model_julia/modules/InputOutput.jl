# Product, use, origin, margin, and supply accounts.
include(joinpath(@__DIR__, "InputOutputSettings.jl"))

module InputOutput

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutputSettings:
  industry,
  origin,
  product,
  use,
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
const purchaser_use_file = joinpath(input_output_data_dir, "input_output_purchaser_use.csv")
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

"""Copy checked-in cells into a model variable. Years the file omits stay `nothing`."""
fill_cells!(db, var, cells) = db[var] .= [get(cells, key, nothing) for key in keys(var)]

const qY_p_i_data = read_cells(supply_file, "qY_p_i_reported")
const qMarginBundle_p_u_data = read_cells(margin_file, "qMarginBundle_p_u_reported")
const qMarginService_s_u_o_data = read_cells(margin_file, "qMarginService_s_u_o_reclassified")
const vProductTax_u_data = read_cells(adjustment_file, "vProductTax_u_reported")
# The source keeps reported, estimated, and reclassified purchaser use apart.
const qPurchaserUse_p_u_o_data = mergewith(
  +,
  (
    read_cells(purchaser_use_file, variable)
    for variable in
    ("qPurchaserUse_p_u_o_reported", "qPurchaserUse_p_u_o_estimated", "qPurchaserUse_p_u_o_reclassified")
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
const purchaser_use_p_u_o = active_cells(qPurchaserUse_p_u_o_data)
const margin_s_u_o = active_cells(qMarginService_s_u_o_data)
const reported_margin_p_u = active_cells(qMarginBundle_p_u_data)
const product_tax_u = Set(u for (u,) in active_cells(vProductTax_u_data))

const supply_p = Set(p for (p, _) in supply_p_i)
const supply_i = Set(i for (_, i) in supply_p_i)
const purchaser_use_p_u = Set((p, u) for (p, u, _) in purchaser_use_p_u_o)
const purchaser_use_u = Set(u for (_, u) in purchaser_use_p_u)
const margin_s_u = Set((s, u) for (s, u, _) in margin_s_u_o)
const margin_u = Set(u for (_, u) in margin_s_u)

# Use at basic or border prices adds the derived margin services to purchaser
# use. Supply sums over its destination and keeps origin until the account split.
const use_p_u_o = purchaser_use_p_u_o ∪ margin_s_u_o
const supply_p_o = Set((p, o) for (p, _, o) in use_p_u_o)
const use_u_o = Set((u, o) for (_, u, o) in use_p_u_o)
const supply_o = Set(o for (_, o) in supply_p_o)
const ordinary_use_u_o = Set(
  (u, o) for (u, o) in use_u_o if u in ordinary_uses
)

# Fixed product and origin shares cover ordinary uses only. Inventory cells are
# exogenous and keep their reported sign.
const ordinary_p_u_o = Set((p, u, o) for (p, u, o) in purchaser_use_p_u_o if u in ordinary_uses)
const ordinary_p_u = Set((p, u) for (p, u, _) in ordinary_p_u_o)
const inventory_p_u_o = setdiff(purchaser_use_p_u_o, ordinary_p_u_o)
const origin_share_p_u_o = ordinary_p_u_o ∪ margin_s_u_o
const margin_only_s_u_o = setdiff(margin_s_u_o, ordinary_p_u_o)

# ============================================================================
# Variables
# ============================================================================

const InputOutputTag = Tag(:InputOutput)

# Margin services are products, so the margin variables keep the full product
# domain. Product clearing and import totals index them by any product.
@variables db.model :: (InputOutputTag, GrowthAdjusted, InflationAdjusted) begin
  vY_p_i[p = product, i = industry, t = t; (p, i) in supply_p_i], "Basic-price output by product and industry"
  vPurchaserUse_p_u[p = product, u = use, t = t; (p, u) in purchaser_use_p_u], "Purchaser spend by product and use"
  vPurchaserUse_p_u_o[p = product, u = use, o = origin, t = t; (p, u, o) in purchaser_use_p_u_o], "Purchaser spend by product, use, and origin"
  vMarginBundle_u[u = use, t = t; u in margin_u], "Margin-bundle value by use"
  vMarginService_s_u[s = margin_services, u = use, t = t; (s, u) in margin_s_u], "Margin-service value by service and use"
  vMarginService_s_u_o[s = product, u = use, o = origin, t = t; (s, u, o) in margin_s_u_o], "Margin-service value by service, use, and origin"
  vUse_p_u_o[p = product, u = use, o = origin, t = t; (p, u, o) in use_p_u_o], "Basic or border value by product, use, and origin"
  vSupply_p_o[p = product, o = origin, t = t; (p, o) in supply_p_o], "Supply value by product and origin"
  vUse_u_o[u = use, o = origin, t = t; (u, o) in use_u_o], "Basic or border value by use and origin"
  vSupply_o[o = origin, t = t; o in supply_o], "Supply value by origin"

  vY_i[i = industry, t = t; i in supply_i], "Domestic output by industry"
  vPurchaserUse_u[u = use, t = t; u in purchaser_use_u], "Purchaser spend by use"
  vProductTax_u[u = use, t = t; u in product_tax_u], "Product taxes by use"

  vC[t], "Household and non-profit consumption"
  vCTourist[t], "Consumption in the country by non-resident households"
  vG[t], "Government consumption"
  vI[t], "Fixed investment"
  vINV[t], "Change in inventories"
  vX[t], "Total exports"
end

@variables db.model :: (InputOutputTag, InflationAdjusted) begin
  pY_p_i[p = product, i = industry, t = t; (p, i) in supply_p_i], "Domestic basic price by product and industry"
  pY_i[i = industry, t = t; i in supply_i], "Domestic basic price by industry"
  pBasic[p = product, u = use, o = origin, t = t; (p, u, o) in use_p_u_o], "Basic or border price by product, use, and origin"
  pSupply_p_o[p = product, o = origin, t = t; (p, o) in supply_p_o], "Supply price by product and origin"
  pUse_u_o[u = ordinary_uses, o = origin, t = t; (u, o) in ordinary_use_u_o], "Basic or border price by use and origin"
  pSupply_o[o = origin, t = t; o in supply_o], "Supply price by origin"

  pPurchaserUse_p_u_o[p = product, u = use, o = origin, t = t; (p, u, o) in purchaser_use_p_u_o], "Purchaser price by product, use, and origin"
  pPurchaserUse_p_u[p = product, u = ordinary_uses, t = t; (p, u) in ordinary_p_u], "Purchaser price by product and use"
  pPurchaserUse_u[u = ordinary_uses, t = t; u in purchaser_use_u], "Purchaser price by use"

  pMarginBundle_u[u = use, t = t; u in margin_u], "Margin-bundle price by use"
  pMarginService_s_u[s = margin_services, u = use, t = t; (s, u) in margin_s_u], "Margin-service price by service and use"
  pOtherAdjustment[p = product, u = use, o = origin, t = t; (p, u, o) in purchaser_use_p_u_o] :: ForecastConstant, "Other additive purchaser-price adjustment"

  pC[t], "Consumption price"
  pG[t], "Government consumption price"
  pI[t], "Fixed investment price"
  pX[t], "Total export price"
end

@variables db.model :: (InputOutputTag, GrowthAdjusted) begin
  qY_p_i[p = product, i = industry, t = t; (p, i) in supply_p_i], "Output by product and industry"
  qPurchaserUse_p_u[p = product, u = use, t = t; (p, u) in purchaser_use_p_u], "Purchaser use by product and use"
  qPurchaserUse_p_u_o[p = product, u = use, o = origin, t = t; (p, u, o) in purchaser_use_p_u_o], "Purchaser use by product, use, and origin"
  qMarginBundle_u[u = use, t = t; u in margin_u], "Margin-bundle demand by use"
  qMarginBundle_p_u[p = product, u = use, t = t; (p, u) in reported_margin_p_u], "Margin-bundle demand by product and use"
  qMarginService_s_u[s = margin_services, u = use, t = t; (s, u) in margin_s_u], "Margin-service demand by service and use"
  qMarginService_s_u_o[s = product, u = use, o = origin, t = t; (s, u, o) in margin_s_u_o], "Margin-service demand by service, use, and origin"
  qUse_p_u_o[p = product, u = use, o = origin, t = t; (p, u, o) in use_p_u_o], "Basic-price use by product, use, and origin"
  qSupply_p_o[p = product, o = origin, t = t; (p, o) in supply_p_o], "Supply by product and origin"
  qUse_u_o[u = use, o = origin, t = t; (u, o) in use_u_o], "Basic-price use by use and origin"
  qSupply_o[o = origin, t = t; o in supply_o], "Supply by origin"

  qY_i[i = industry, t = t; i in supply_i], "Domestic output by industry"
  qPurchaserUse_u[u = ordinary_uses, t = t; u in purchaser_use_u], "Purchaser use by use"

  qC[t], "Household and non-profit consumption"
  qCTourist[t] :: ForecastConstant, "Consumption in the country by non-resident households"
  qG[t], "Government consumption"
  qI[t], "Fixed investment"
  qINV[t], "Change in inventories"
  qX[t], "Total exports"
end

# Standard domestic-output and import names are views of the origin accounts.
const qY_p_u = qUse_p_u_o[:, :, domestic, :]
const qM_p_u = qUse_p_u_o[:, :, import_origin, :]
const qY_p = qSupply_p_o[:, domestic, :]
const qM_p = qSupply_p_o[:, import_origin, :]
const qY_u = qUse_u_o[:, domestic, :]
const qM_u = qUse_u_o[:, import_origin, :]
const qY = qSupply_o[domestic, :]
const qM = qSupply_o[import_origin, :]

const vY_p_u = vUse_p_u_o[:, :, domestic, :]
const vM_p_u = vUse_p_u_o[:, :, import_origin, :]
const vY_p = vSupply_p_o[:, domestic, :]
const vM_p = vSupply_p_o[:, import_origin, :]
const vY_u = vUse_u_o[:, domestic, :]
const vM_u = vUse_u_o[:, import_origin, :]
const vY = vSupply_o[domestic, :]
const vM = vSupply_o[import_origin, :]

const pY_p_u = pBasic[:, :, domestic, :]
const pM_p_u = pBasic[:, :, import_origin, :]
const pY_p = pSupply_p_o[:, domestic, :]
const pM_p = pSupply_p_o[:, import_origin, :]
const pY_u = pUse_u_o[:, domestic, :]
const pM_u = pUse_u_o[:, import_origin, :]
const pY = pSupply_o[domestic, :]
const pM = pSupply_o[import_origin, :]

@variables db.model :: InputOutputTag begin
  rIndustryShare[p = product, i = industry, t = t; (p, i) in supply_p_i] :: ForecastConstant, "Fixed industry share for each product"
  rProductShare[p = product, u = use, t = t; (p, u) in ordinary_p_u] :: ForecastConstant, "Fixed product share for each purchaser use"
  rOriginShare[p = product, u = use, o = origin, t = t; (p, u, o) in origin_share_p_u_o] :: ForecastConstant, "Fixed origin share"
  rMarginServiceShare[s = margin_services, u = use, t = t; (s, u) in margin_s_u] :: ForecastConstant, "Fixed margin-service share"
  rMarginRate[p = product, u = use, t = t; (p, u) in reported_margin_p_u] :: ForecastConstant, "Margin-bundle units per unit of purchaser use"
  tProduct[u = use, t = t; u in product_tax_u] :: ForecastConstant, "Product tax per unit of purchaser use"
  tVAT[p = product, u = use, o = origin, t = t; (p, u, o) in purchaser_use_p_u_o] :: ForecastConstant, "VAT rate"
end

# ============================================================================
# Data
# ============================================================================

function set_data!(db)
  @assert reported_margin_p_u ⊆ purchaser_use_p_u "Each reported margin needs purchaser use"
  @assert Set((p, domestic) for p in supply_p) == Set(
    (p, o) for (p, o) in supply_p_o if o == domestic
  ) "Domestic product supply must match industry output"
  @assert supply_o == Set(origin) "Each origin needs supply"
  @assert all(
    abs(sum(benchmark(qPurchaserUse_p_u_o_data, p, u, o) for p in product for o in origin)) > cell_tolerance
    for u in (purchaser_use_u ∩ ordinary_uses) ∪ product_tax_u
  ) "Each use with a fixed product share or a product tax needs non-zero demand"
  @assert all(
    abs(sum(benchmark(qPurchaserUse_p_u_o_data, p, u, o) for o in origin)) > cell_tolerance
    for (p, u) in reported_margin_p_u
  ) "Each margin rate needs non-zero purchaser use"

  fill_cells!(db, qY_p_i, qY_p_i_data)
  fill_cells!(db, qMarginService_s_u_o, qMarginService_s_u_o_data)
  fill_cells!(db, qPurchaserUse_p_u_o, qPurchaserUse_p_u_o_data)
  fill_cells!(db, qMarginBundle_p_u, qMarginBundle_p_u_data)
  fill_cells!(db, vProductTax_u, vProductTax_u_data)

  # Totals implied by the cell data. Calibration holds them fixed so residuals
  # absorb inconsistent source totals and the solver hits the data exactly.
  for p in supply_p
    db[qY_p[p, calibration_year]] = sum(benchmark(qY_p_i_data, p, i) for i in industry)
  end
  for i in supply_i
    db[qY_i[i, calibration_year]] = sum(benchmark(qY_p_i_data, p, i) for p in product)
  end
  for (p, u) in purchaser_use_p_u
    db[qPurchaserUse_p_u[p, u, calibration_year]] =
      sum(benchmark(qPurchaserUse_p_u_o_data, p, u, o) for o in origin)
  end
  for u in purchaser_use_u ∩ ordinary_uses
    db[qPurchaserUse_u[u, calibration_year]] =
      sum(benchmark(qPurchaserUse_p_u_o_data, p, u, o) for p in product for o in origin)
  end
  for (s, u) in margin_s_u
    db[qMarginService_s_u[s, u, calibration_year]] =
      sum(benchmark(qMarginService_s_u_o_data, s, u, o) for o in origin)
  end
  for u in margin_u
    db[qMarginBundle_u[u, calibration_year]] =
      sum(benchmark(qMarginService_s_u_o_data, s, u, o) for s in margin_services for o in origin)
  end

  for (p, u, o) in inventory_p_u_o, tt in (calibration_year + 1):last(t)
    db[qPurchaserUse_p_u_o[p, u, o, tt]] = 0.0
  end

  # D21X31 does not split VAT from other product taxes. The default closure
  # treats the full value as an additive product tax and sets VAT to zero.
  db[tVAT] .= 0.0
  db[pOtherAdjustment] .= 0.0
  db[pY_p_i] .= 1.0
  db[pM_p_u] .= 1.0

  db[vPurchaserUse_u] .= read_variable(check_file, vPurchaserUse_u; variable = "vPurchaserUse_u_reported")
  db[qCTourist] .= read_variable(check_file, qCTourist; variable = "qCTourist_reported")
  db[vM] .= read_variable(check_file, vM; variable = "vM_reported")
  db[vX] .= read_variable(check_file, vX; variable = "vX_reported")
  db[vY] .= read_variable(check_file, vY; variable = "vY_reported")
  return nothing
end

function set_residual_tolerances!(tolerances)
  tolerances[vPurchaserUse_u] = 1e-6
  # T1620 rounds the carried-product and service sides to EUR 0.01 million.
  tolerances[qMarginBundle_u] = 0.1
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
    qPurchaserUse_p_u[(p, u, t) in keys(qPurchaserUse_p_u); t in t1:T && u in ordinary_uses],
    qPurchaserUse_p_u[p, u, t] == rProductShare[p, u, t] * qPurchaserUse_u[u, t]

    qPurchaserUse_p_u[(p, u, t) in keys(qPurchaserUse_p_u); t in t1:T && u == :INV],
    qPurchaserUse_p_u[p, u, t] == ∑(qPurchaserUse_p_u_o[p, u, o, t] for o in origin)

    qPurchaserUse_p_u_o[(p, u, o, t) in keys(qPurchaserUse_p_u_o); t in t1:T && u in ordinary_uses],
    qPurchaserUse_p_u_o[p, u, o, t] == rOriginShare[p, u, o, t] * qPurchaserUse_p_u[p, u, t]

    # Derived margin demand. Only uses with reported margins carry a bundle.
    qMarginBundle_p_u[(p, u, t) in keys(qMarginBundle_p_u); t in t1:T],
    qMarginBundle_p_u[p, u, t] == rMarginRate[p, u, t] * qPurchaserUse_p_u[p, u, t]

    qMarginBundle_u[(u, t) in keys(qMarginBundle_u); t in t1:T],
    qMarginBundle_u[u, t] == ∑(qMarginBundle_p_u[p, u, t] for p in product)

    qMarginService_s_u[(s, u, t) in keys(qMarginService_s_u); t in t1:T],
    qMarginService_s_u[s, u, t] == rMarginServiceShare[s, u, t] * qMarginBundle_u[u, t]

    qMarginService_s_u_o[(s, u, o, t) in keys(qMarginService_s_u_o); t in t1:T],
    qMarginService_s_u_o[s, u, o, t] == rOriginShare[s, u, o, t] * qMarginService_s_u[s, u, t]

    # Use at basic or border prices adds margin services.
    qUse_p_u_o[(p, u, o, t) in keys(qUse_p_u_o); t in t1:T],
    qUse_p_u_o[p, u, o, t] == qPurchaserUse_p_u_o[p, u, o, t] + qMarginService_s_u_o[p, u, o, t]

    qSupply_p_o[(p, o, t) in keys(qSupply_p_o); t in t1:T],
    qSupply_p_o[p, o, t] == ∑(qUse_p_u_o[p, u, o, t] for u in use)

    qUse_u_o[(u, o, t) in keys(qUse_u_o); t in t1:T],
    qUse_u_o[u, o, t] == ∑(qUse_p_u_o[p, u, o, t] for p in product)

    qSupply_o[(o, t) in keys(qSupply_o); t in t1:T],
    qSupply_o[o, t] == ∑(qSupply_p_o[p, o, t] for p in product)

    qY_p_i[(p, i, t) in keys(qY_p_i); t in t1:T],
    qY_p_i[p, i, t] == rIndustryShare[p, i, t] * qY_p[p, t]

    qY_i[(i, t) in keys(qY_i); t in t1:T],
    qY_i[i, t] == ∑(qY_p_i[p, i, t] for p in product)

    # Export and final-use totals.
    qX[t = t1:T], qX[t] == qPurchaserUse_u[:X, t] + qCTourist[t]
    qC[t = t1:T], qC[t] == qPurchaserUse_u[:C, t] - qCTourist[t]
    qG[t = t1:T], qG[t] == qPurchaserUse_u[:G, t]
    qI[t = t1:T], qI[t] == qPurchaserUse_u[:K, t]
    qINV[t = t1:T], qINV[t] == ∑(qPurchaserUse_p_u[p, :INV, t] for p in product)

    # Basic, border, margin, and purchaser prices.
    pBasic[(p, u, o, t) in keys(pBasic); t in t1:T && o == domestic],
    pBasic[p, u, o, t] == pSupply_p_o[p, o, t]

    pMarginService_s_u[(s, u, t) in keys(pMarginService_s_u); t in t1:T],
    pMarginService_s_u[s, u, t] == ∑(rOriginShare[s, u, o, t] * pBasic[s, u, o, t] for o in origin)

    pMarginBundle_u[(u, t) in keys(pMarginBundle_u); t in t1:T],
    pMarginBundle_u[u, t] == ∑(rMarginServiceShare[s, u, t] * pMarginService_s_u[s, u, t] for s in margin_services)

    pPurchaserUse_p_u_o[(p, u, o, t) in keys(pPurchaserUse_p_u_o); t in t1:T],
    pPurchaserUse_p_u_o[p, u, o, t] == (
      pBasic[p, u, o, t] +
      tProduct[u, t] +
      pOtherAdjustment[p, u, o, t] +
      rMarginRate[p, u, t] * pMarginBundle_u[u, t]
    ) * (1 + tVAT[p, u, o, t])

    pPurchaserUse_p_u[(p, u, t) in keys(pPurchaserUse_p_u); t in t1:T],
    pPurchaserUse_p_u[p, u, t] == ∑(rOriginShare[p, u, o, t] * pPurchaserUse_p_u_o[p, u, o, t] for o in origin)

    pPurchaserUse_u[(u, t) in keys(pPurchaserUse_u); t in t1:T],
    pPurchaserUse_u[u, t] == ∑(rProductShare[p, u, t] * pPurchaserUse_p_u[p, u, t] for p in product)

    # Purchaser values include margin spend once through the purchaser price.
    vPurchaserUse_p_u_o[(p, u, o, t) in keys(vPurchaserUse_p_u_o); t in t1:T],
    vPurchaserUse_p_u_o[p, u, o, t] == pPurchaserUse_p_u_o[p, u, o, t] * qPurchaserUse_p_u_o[p, u, o, t]

    vPurchaserUse_p_u[(p, u, t) in keys(vPurchaserUse_p_u); t in t1:T],
    vPurchaserUse_p_u[p, u, t] == ∑(vPurchaserUse_p_u_o[p, u, o, t] for o in origin)

    vPurchaserUse_u[(u, t) in keys(vPurchaserUse_u); t in t1:T],
    vPurchaserUse_u[u, t] == ∑(vPurchaserUse_p_u[p, u, t] for p in product)

    vProductTax_u[(u, t) in keys(vProductTax_u); t in t1:T],
    vProductTax_u[u, t] ==
      tProduct[u, t] * ∑(qPurchaserUse_p_u_o[p, u, o, t] for p in product for o in origin)

    vMarginService_s_u_o[(s, u, o, t) in keys(vMarginService_s_u_o); t in t1:T],
    vMarginService_s_u_o[s, u, o, t] == pBasic[s, u, o, t] * qMarginService_s_u_o[s, u, o, t]

    vMarginService_s_u[(s, u, t) in keys(vMarginService_s_u); t in t1:T],
    vMarginService_s_u[s, u, t] == ∑(vMarginService_s_u_o[s, u, o, t] for o in origin)

    vMarginBundle_u[(u, t) in keys(vMarginBundle_u); t in t1:T],
    vMarginBundle_u[u, t] == ∑(vMarginService_s_u[s, u, t] for s in margin_services)

    vUse_p_u_o[(p, u, o, t) in keys(vUse_p_u_o); t in t1:T],
    vUse_p_u_o[p, u, o, t] == pBasic[p, u, o, t] * qUse_p_u_o[p, u, o, t]

    vY_p_i[(p, i, t) in keys(vY_p_i); t in t1:T],
    vY_p_i[p, i, t] == pY_p_i[p, i, t] * qY_p_i[p, i, t]

    vSupply_p_o[(p, o, t) in keys(vSupply_p_o); t in t1:T && o == domestic],
    vSupply_p_o[p, o, t] == ∑(vY_p_i[p, i, t] for i in industry)

    vSupply_p_o[(p, o, t) in keys(vSupply_p_o); t in t1:T && o == import_origin],
    vSupply_p_o[p, o, t] == ∑(vUse_p_u_o[p, u, o, t] for u in use)

    pSupply_p_o[(p, o, t) in keys(pSupply_p_o); t in t1:T],
    pSupply_p_o[p, o, t] * qSupply_p_o[p, o, t] == vSupply_p_o[p, o, t]

    vY_i[(i, t) in keys(vY_i); t in t1:T],
    vY_i[i, t] == ∑(vY_p_i[p, i, t] for p in product)

    pY_i[(i, t) in keys(pY_i); t in t1:T],
    pY_i[i, t] * qY_i[i, t] == vY_i[i, t]

    vUse_u_o[(u, o, t) in keys(vUse_u_o); t in t1:T],
    vUse_u_o[u, o, t] == ∑(vUse_p_u_o[p, u, o, t] for p in product)

    pUse_u_o[(u, o, t) in keys(pUse_u_o); t in t1:T],
    pUse_u_o[u, o, t] * qUse_u_o[u, o, t] == vUse_u_o[u, o, t]

    vSupply_o[(o, t) in keys(vSupply_o); t in t1:T],
    vSupply_o[o, t] == ∑(vSupply_p_o[p, o, t] for p in product)

    pSupply_o[(o, t) in keys(pSupply_o); t in t1:T],
    pSupply_o[o, t] * qSupply_o[o, t] == vSupply_o[o, t]

    vX[t = t1:T], vX[t] == vPurchaserUse_u[:X, t] + vCTourist[t]
    pX[t = t1:T], pX[t] * qX[t] == vX[t]

    pC[t = t1:T], pC[t] == pPurchaserUse_u[:C, t]
    vC[t = t1:T], vC[t] == pC[t] * qC[t]
    vCTourist[t = t1:T], vCTourist[t] == pC[t] * qCTourist[t]
    vG[t = t1:T], vG[t] == vPurchaserUse_u[:G, t]
    pG[t = t1:T], pG[t] * qG[t] == vG[t]
    vI[t = t1:T], vI[t] == vPurchaserUse_u[:K, t]
    pI[t = t1:T], pI[t] * qI[t] == vI[t]
    vINV[t = t1:T], vINV[t] == vPurchaserUse_u[:INV, t]

    # Post-solve accounts that do not add rows to the square system.
    @test_constraint "Supply shares reproduce product output" qY_p[(p, t) in keys(qY_p); t in t1:T],
      qY_p[p, t] == ∑(qY_p_i[p, i, t] for i in industry)

    @test_constraint "Purchaser-use shares sum to total use" qPurchaserUse_u[(u, t) in keys(qPurchaserUse_u); t in t1:T],
      qPurchaserUse_u[u, t] == ∑(qPurchaserUse_p_u[p, u, t] for p in product)

    @test_constraint "Origin shares sum to product use" qPurchaserUse_p_u[(p, u, t) in keys(qPurchaserUse_p_u); t in t1:T && u in ordinary_uses],
      qPurchaserUse_p_u[p, u, t] == ∑(qPurchaserUse_p_u_o[p, u, o, t] for o in origin)

    @test_constraint "Margin-service shares sum to the margin bundle" qMarginBundle_u[(u, t) in keys(qMarginBundle_u); t in t1:T],
      qMarginBundle_u[u, t] == ∑(qMarginService_s_u[s, u, t] for s in margin_services)

    @test_constraint "Margin origin shares sum to service demand" qMarginService_s_u[(s, u, t) in keys(qMarginService_s_u); t in t1:T],
      qMarginService_s_u[s, u, t] == ∑(qMarginService_s_u_o[s, u, o, t] for o in origin)

    @test_constraint "Purchaser spend excludes separate margin spending" vPurchaserUse_u[(u, t) in keys(vPurchaserUse_u); t in t1:T],
      vPurchaserUse_u[u, t] == ∑(vPurchaserUse_p_u_o[p, u, o, t] for p in product for o in origin)

    @test_constraint "Imports sum by product and use" qM[t = t1:T],
      qM[t] == ∑(qM_u[u, t] for u in use)
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    [rIndustryShare[p, i, t1] for (p, i) in supply_p_i],
    [qY_p_i[p, i, t1] for (p, i) in supply_p_i]

    [rProductShare[p, u, t1] for (p, u) in ordinary_p_u],
    [qPurchaserUse_p_u[p, u, t1] for (p, u) in ordinary_p_u]

    [rOriginShare[p, u, o, t1] for (p, u, o) in ordinary_p_u_o],
    [qPurchaserUse_p_u_o[p, u, o, t1] for (p, u, o) in ordinary_p_u_o]

    [rMarginServiceShare[s, u, t1] for (s, u) in margin_s_u],
    [qMarginService_s_u[s, u, t1] for (s, u) in margin_s_u]

    [rMarginRate[p, u, t1] for (p, u) in reported_margin_p_u],
    [qMarginBundle_p_u[p, u, t1] for (p, u) in reported_margin_p_u]

    [rOriginShare[s, u, o, t1] for (s, u, o) in margin_only_s_u_o],
    [qMarginService_s_u_o[s, u, o, t1] for (s, u, o) in margin_only_s_u_o]

    [tProduct[u, t1] for u in product_tax_u],
    [vProductTax_u[u, t1] for u in product_tax_u]
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
