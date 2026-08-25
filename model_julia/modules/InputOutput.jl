# Product, use, origin, margin, and supply accounts.
include(joinpath(@__DIR__, "InputOutputSettings.jl"))

module InputOutput

using SquareModels
import ..DataUtils: fill_cells!, read_cells, read_series
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutputSettings:
  final_uses,
  origin,
  product,
  source_industry,
  cell_tolerance,
  input_output_data_dir,
  margin_services
import ..Settings: calibration_year
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

const domestic = :domestic
const import_origin = :import

# ============================================================================
# Read data
# ============================================================================

const supply_file = joinpath(input_output_data_dir, "input_output_supply.csv")
const purchaser_use_file = joinpath(input_output_data_dir, "input_output_purchaser_use.csv")
const margin_file = joinpath(input_output_data_dir, "input_output_margins.csv")
const net_product_tax_file = joinpath(input_output_data_dir, "input_output_net_product_tax.csv")
const aggregate_totals_file = joinpath(input_output_data_dir, "input_output_aggregate_totals.csv")

const qY_p_i_data = read_cells(supply_file, "qY_p_i")
const qMarginBundle_p_u_data = read_cells(margin_file, "qMarginBundle_p_u")
const qMarginService_s_u_o_data = read_cells(margin_file, "qMarginService_s_u_o")
const qMarginService_s_u_data = read_cells(margin_file, "qMarginService_s_u")
const vNetProductTax_p_u_data = read_cells(net_product_tax_file, "vNetProductTax_p_u")
const vNetProductTax_u_data = read_cells(net_product_tax_file, "vNetProductTax_u")
const qPurchaserUse_p_u_o_data = read_cells(purchaser_use_file, "qPurchaserUse_p_u_o")
const qPurchaserUse_p_u_data = read_cells(purchaser_use_file, "qPurchaserUse_p_u")
const qM_p_i_data = read_cells(purchaser_use_file, "qM_p_i")
const qC_p_data = read_cells(purchaser_use_file, "qC_p")
const qG_p_data = read_cells(purchaser_use_file, "qG_p")
const qI_p_data = read_cells(purchaser_use_file, "qI_p")
const qX_p_data = read_cells(purchaser_use_file, "qX_p")
const qI_data = read_cells(purchaser_use_file, "qI")

# ============================================================================
# Indices
# ============================================================================

# Keep industries with output in the calibration year.
const industry = sort(unique(
  i
  for ((_,i,year),value) in qY_p_i_data
  if year == calibration_year && abs(value) > cell_tolerance
))
@assert industry ⊆ source_industry "Output data contain an unknown industry"

const use = [industry; final_uses]
@assert allunique(use) "Industry and final-use labels must be distinct"
# Inventory changes are signed and exogenous, so they bypass the product-demand links.
const ordinary_uses = setdiff(use, [:INV])

# Each mask is named after the indices it holds. Cells outside a mask have no
# variable and no equation, so a mask change needs a model rebuild.

"""Indices with a non-negligible calibration-year value. The last index is the year."""
calibration_year_indices(cells) = Set(
  key[1:(end-1)]
  for (key,value) in cells
  if key[end] == calibration_year && abs(value) > cell_tolerance
)

const purchaser_use_p_u_o = calibration_year_indices(qPurchaserUse_p_u_o_data)
const margin_s_u_o = calibration_year_indices(qMarginService_s_u_o_data)

# Margin cells outside ordinary purchaser use need their own origin-share swap.
const margin_only_s_u_o = Set(
  (s,u,o)
  for (s,u,o) in margin_s_u_o
  if u ∉ ordinary_uses || (s,u,o) ∉ purchaser_use_p_u_o
)

const purchaser_use_p_u = Set((p, u) for (p, u, _) in purchaser_use_p_u_o)

# ============================================================================
# Variables
# ============================================================================

const InputOutputTag = Tag(:InputOutput)

# Margin services are products, so the margin variables keep the full product
# domain. Product clearing and import totals index them by any product.
@variables model :: (InputOutputTag, GrowthAdjusted, InflationAdjusted) begin
  vY_p_i[p=product, i=industry, t=t; (p,i) in calibration_year_indices(qY_p_i_data)], "Basic-price output by product and industry"
  vPurchaserUse_p_u_o[p=product, u=use, o=origin, t=t; (p,u,o) in purchaser_use_p_u_o], "Purchaser spend by product, use, and origin"
  vPurchaserUse_p_u[(p,u,t)=select_axes(vPurchaserUse_p_u_o, 1, 2, 4)], "Purchaser spend by product and use"
  vMarginService_s_u_o[s=product, u=use, o=origin, t=t; (s,u,o) in margin_s_u_o], "Margin-service value by service, use, and origin"
  vMarginService_s_u[(s,u,t)=select_axes(vMarginService_s_u_o[margin_services,:,:,:], 1, 2, 4)], "Margin-service value by service and use"
  vMarginBundle_u[(u,t)=select_axes(vMarginService_s_u, 2, 3)], "Margin-bundle value by use"
  vUse_p_u_o[(p,u,o,t)=merge_indices(vPurchaserUse_p_u_o,vMarginService_s_u_o)], "Basic or border value by product, use, and origin"
  vSupply_p_o[(p,o,t)=select_axes(vUse_p_u_o, 1, 3, 4)], "Supply value by product and origin"
  vUse_u_o[(u,o,t)=select_axes(vUse_p_u_o, 2, 3, 4)], "Basic or border value by use and origin"
  vSupply_o[o=origin, t=t], "Supply value by origin"

  vY_i[(i,t)=select_axes(vY_p_i, 2, 3)], "Domestic output by industry"
  vNetProductTax_p_u[p=product, u=use, t=t; (p,u) in calibration_year_indices(vNetProductTax_p_u_data)], "Taxes less subsidies on products by product and use"
  vNetProductTax_u[u=use, t=t], "Taxes less subsidies on products by use"

  vC[t], "Household and non-profit consumption"
  vCTourist[t], "Consumption in the country by non-resident households"
  vG[t], "Government consumption"
  vI[t], "Fixed investment"
  vINV[t], "Change in inventories"
  vX[t], "Total exports"
end

@variables model :: (InputOutputTag, InflationAdjusted) begin
  pY_p_i[(p,i,t)=vY_p_i], "Domestic basic price by product and industry"
  pY_i[(i,t)=vY_i], "Domestic basic price by industry"
  pBasic[(p,u,o,t)=vUse_p_u_o], "Basic or border price by product, use, and origin"
  pSupply_p_o[(p,o,t)=vSupply_p_o], "Supply price by product and origin"
  pUse_u_o[(u,o,t)=vUse_u_o[ordinary_uses,:,:]], "Basic or border price by use and origin"
  pSupply_o[o=origin, t=t], "Supply price by origin"

  pPurchaserUse_p_u_o[(p,u,o,t)=vPurchaserUse_p_u_o], "Purchaser price by product, use, and origin"
  pPurchaserUse_p_u[(p,u,t)=vPurchaserUse_p_u[:,ordinary_uses,:]], "Purchaser price by product and use"
  pMarginBundle_u[(u,t)=vMarginBundle_u], "Margin-bundle price by use"
  pMarginService_s_u[(s,u,t)=vMarginService_s_u], "Margin-service price by service and use"

  pC[t], "Consumption price"
  pG[t], "Government consumption price"
  pI[t], "Fixed investment price"
  pX[t], "Total export price"
end

@variables model :: (InputOutputTag, GrowthAdjusted) begin
  qY_p_i[(p,i,t)=vY_p_i], "Output by product and industry"
  qPurchaserUse_p_u[(p,u,t)=vPurchaserUse_p_u], "Purchaser use by product and use"
  qPurchaserUse_p_u_o[(p,u,o,t)=vPurchaserUse_p_u_o], "Purchaser use by product, use, and origin"
  qMarginBundle_u[(u,t)=vMarginBundle_u], "Margin-bundle demand by use"
  qMarginBundle_p_u[p=product, u=use, t=t; (p,u) in calibration_year_indices(qMarginBundle_p_u_data)], "Margin-bundle demand by product and use"
  qMarginService_s_u[(s,u,t)=vMarginService_s_u], "Margin-service demand by service and use"
  qMarginService_s_u_o[(s,u,o,t)=vMarginService_s_u_o], "Margin-service demand by service, use, and origin"
  qUse_p_u_o[(p,u,o,t)=vUse_p_u_o], "Basic-price use by product, use, and origin"
  qSupply_p_o[(p,o,t)=vSupply_p_o], "Supply by product and origin"
  qUse_u_o[(u,o,t)=vUse_u_o], "Basic-price use by use and origin"
  qSupply_o[o=origin, t=t], "Supply by origin"

  qY_i[(i,t)=vY_i], "Domestic output by industry"
  qM_p_i[(p,i,t)=qPurchaserUse_p_u[:,industry,:]], "Intermediate input by product and industry."
  qC_p[(p,t)=qPurchaserUse_p_u[:,:C,:]], "Household and non-profit consumption by product."
  qG_p[(p,t)=qPurchaserUse_p_u[:,:G,:]], "Government consumption by product."
  qI_p[(p,t)=qPurchaserUse_p_u[:,:K,:]], "Fixed investment by product."
  qX_p[(p,t)=qPurchaserUse_p_u[:,:X,:]], "Direct exports by product."

  qC[t], "Household and non-profit consumption"
  qCTourist[t] :: ForecastConstant, "Consumption in the country by non-resident households"
  qG[t], "Government consumption"
  qI[t], "Fixed investment"
  qINV[t], "Change in inventories"
  qX[t], "Total exports"
end

# Domestic-output and import names are views of the origin accounts.
const qY_p = qSupply_p_o[:,domestic,:]
const qM_u = qUse_u_o[:,import_origin,:]
const qM = qSupply_o[import_origin,:]

const vY = vSupply_o[domestic,:]
const vM = vSupply_o[import_origin,:]

const pM_p_u = pBasic[:,:,import_origin,:]

@variables model :: InputOutputTag begin
  rIndustryShare[(p,i,t)=qY_p_i] :: ForecastConstant, "Fixed industry share for each product"
  rOriginShare[(p,u,o,t)=merge_indices(qPurchaserUse_p_u_o[:,ordinary_uses,:,:], qMarginService_s_u_o)] :: ForecastConstant, "Fixed origin share"
  rMarginServiceShare[(s,u,t)=qMarginService_s_u] :: ForecastConstant, "Fixed margin-service share"
  rMarginRate[(p,u,t)=qMarginBundle_p_u] :: ForecastConstant, "Margin-bundle units per unit of purchaser use"
  tNetProduct[(p,u,t)=vNetProductTax_p_u] :: ForecastConstant, "Net product tax per unit of purchaser use"
  tVAT[(p,u,o,t)=qPurchaserUse_p_u_o] :: ForecastConstant, "Separate VAT rate; zero while tNetProduct includes VAT"
end

@assert Set(p for (p, _, year) in keys(vY_p_i) if year == calibration_year) ==
  Set(p for (p, o, year) in keys(vSupply_p_o) if o == domestic && year == calibration_year) "Domestic product supply must match industry output"
@assert Set(o for (_, o, year) in keys(vSupply_p_o) if year == calibration_year) == Set(origin) "Each origin needs supply"

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  fill_cells!(db, qY_p_i, qY_p_i_data)
  fill_cells!(db, qMarginService_s_u_o, qMarginService_s_u_o_data)
  fill_cells!(db, qPurchaserUse_p_u_o, qPurchaserUse_p_u_o_data)
  fill_cells!(db, qMarginBundle_p_u, qMarginBundle_p_u_data)
  fill_cells!(db, vNetProductTax_p_u, vNetProductTax_p_u_data)
  fill_cells!(db, qPurchaserUse_p_u, qPurchaserUse_p_u_data)
  fill_cells!(db, qM_p_i, qM_p_i_data)
  fill_cells!(db, qC_p, qC_p_data)
  fill_cells!(db, qG_p, qG_p_data)
  fill_cells!(db, qI_p, qI_p_data)
  fill_cells!(db, qX_p, qX_p_data)
  fill_cells!(db, qI, qI_data)
  fill_cells!(db, qMarginService_s_u, qMarginService_s_u_data)
  fill_cells!(db, vNetProductTax_u, vNetProductTax_u_data)

  # The T1630 split is net of product subsidies and includes VAT, tariffs, and
  # other product taxes. Keep it in tNetProduct until a tax module splits it.
  db[tVAT] .= 0.0
  db[pY_p_i] .= 1.0
  db[pM_p_u] .= 1.0

  db[vCTourist] .= read_series(aggregate_totals_file, "vCTourist", t)
  # The source has no tourist volume before t1. Use its value as the lagged quantity.
  db[qCTourist[t1-1]] = db[vCTourist[t1-1]]
  db[vM] .= read_series(aggregate_totals_file, "vM", t)
  db[vX] .= read_series(aggregate_totals_file, "vX", t)
  db[vY] .= read_series(aggregate_totals_file, "vY", t)
  return nothing
end

function set_residual_tolerances!(tolerances)
  # T1610 and T1630 can differ by EUR 0.01 million in each A64 cell.
  tolerances[vNetProductTax_u] = 0.15
  tolerances[vM] = 0.15
  tolerances[vY] = 0.15
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    # Direct product demand. Inventories bypass the module links.
    qPurchaserUse_p_u[(p,i,t) in keys(qM_p_i); t in t1:T], qPurchaserUse_p_u[p,i,t] == qM_p_i[p,i,t]
    qPurchaserUse_p_u[p=product, u=:C, t=t1:T], qPurchaserUse_p_u[p,u,t] == qC_p[p,t]
    qPurchaserUse_p_u[p=product, u=:G, t=t1:T], qPurchaserUse_p_u[p,u,t] == qG_p[p,t]
    qPurchaserUse_p_u[p=product, u=:K, t=t1:T], qPurchaserUse_p_u[p,u,t] == qI_p[p,t]
    qPurchaserUse_p_u[p=product, u=:X, t=t1:T], qPurchaserUse_p_u[p,u,t] == qX_p[p,t]

    qPurchaserUse_p_u[p=product, u=:INV, t=t1:T],
    qPurchaserUse_p_u[p,u,t] == ∑(qPurchaserUse_p_u_o[p,u,o,t] for o in origin)

    qPurchaserUse_p_u_o[p=product, u=ordinary_uses, o=origin, t=t1:T],
    qPurchaserUse_p_u_o[p,u,o,t] == rOriginShare[p,u,o,t] * qPurchaserUse_p_u[p,u,t]

    qPurchaserUse_p_u_o[p=product, u=:INV, o=origin, t=(t1+1):T], qPurchaserUse_p_u_o[p,u,o,t] == 0

    # Derived margin demand. Only uses with reported margins carry a bundle.
    qMarginBundle_p_u[p=product, u=use, t=t1:T],
    qMarginBundle_p_u[p,u,t] == rMarginRate[p,u,t] * qPurchaserUse_p_u[p,u,t]

    qMarginBundle_u[u=use, t=t1:T], qMarginBundle_u[u,t] == ∑(qMarginBundle_p_u[p,u,t] for p in product)

    qMarginService_s_u[s=margin_services, u=use, t=t1:T],
    qMarginService_s_u[s,u,t] == rMarginServiceShare[s,u,t] * qMarginBundle_u[u,t]

    qMarginService_s_u_o[s=product, u=use, o=origin, t=t1:T],
    qMarginService_s_u_o[s,u,o,t] == rOriginShare[s,u,o,t] * qMarginService_s_u[s,u,t]

    # Use at basic or border prices adds margin services.
    qUse_p_u_o[p=product, u=use, o=origin, t=t1:T],
    qUse_p_u_o[p,u,o,t] == qPurchaserUse_p_u_o[p,u,o,t] + qMarginService_s_u_o[p,u,o,t]

    qSupply_p_o[p=product, o=origin, t=t1:T], qSupply_p_o[p,o,t] == ∑(qUse_p_u_o[p,u,o,t] for u in use)

    qUse_u_o[u=use, o=origin, t=t1:T], qUse_u_o[u,o,t] == ∑(qUse_p_u_o[p,u,o,t] for p in product)

    qSupply_o[o=origin, t=t1:T], qSupply_o[o,t] == ∑(qSupply_p_o[p,o,t] for p in product)

    qY_p_i[p=product, i=industry, t=t1:T], qY_p_i[p,i,t] == rIndustryShare[p,i,t] * qY_p[p,t]

    qY_i[i=industry, t=t1:T], qY_i[i,t] == ∑(qY_p_i[p,i,t] for p in product)

    # Final-use totals.
    qX[t=t1:T], qX[t] == ∑(qX_p[p,t] for p in product) + qCTourist[t]
    qG[t=t1:T], qG[t] == ∑(qG_p[p,t] for p in product)
    qINV[t=t1:T], qINV[t] == ∑(qPurchaserUse_p_u[p,:INV,t] for p in product)

    # Basic, border, margin, and purchaser prices.
    pBasic[p=product, u=use, o=domestic, t=t1:T], pBasic[p,u,o,t] == pSupply_p_o[p,o,t]

    pMarginService_s_u[s=margin_services, u=use, t=t1:T],
    pMarginService_s_u[s,u,t] == ∑(rOriginShare[s,u,o,t] * pBasic[s,u,o,t] for o in origin)

    pMarginBundle_u[u=use, t=t1:T],
    pMarginBundle_u[u,t] == ∑(rMarginServiceShare[s,u,t] * pMarginService_s_u[s,u,t] for s in margin_services)

    pPurchaserUse_p_u_o[p=product, u=use, o=origin, t=t1:T],
    pPurchaserUse_p_u_o[p,u,o,t] == (pBasic[p,u,o,t] + tNetProduct[p,u,t]
      + rMarginRate[p,u,t] * pMarginBundle_u[u,t]) * (1 + tVAT[p,u,o,t])

    pPurchaserUse_p_u[p=product, u=ordinary_uses, t=t1:T],
    pPurchaserUse_p_u[p,u,t] == ∑(rOriginShare[p,u,o,t] * pPurchaserUse_p_u_o[p,u,o,t] for o in origin)

    # Purchaser values include margin spend once through the purchaser price.
    vPurchaserUse_p_u_o[p=product, u=use, o=origin, t=t1:T],
    vPurchaserUse_p_u_o[p,u,o,t] == pPurchaserUse_p_u_o[p,u,o,t] * qPurchaserUse_p_u_o[p,u,o,t]

    vPurchaserUse_p_u[p=product, u=use, t=t1:T],
    vPurchaserUse_p_u[p,u,t] == ∑(vPurchaserUse_p_u_o[p,u,o,t] for o in origin)

    vNetProductTax_p_u[p=product, u=use, t=t1:T],
    vNetProductTax_p_u[p,u,t] ==
      tNetProduct[p,u,t] * ∑(qPurchaserUse_p_u_o[p,u,o,t] for o in origin)

    vNetProductTax_u[u=use, t=t1:T], vNetProductTax_u[u,t] == ∑(vNetProductTax_p_u[p,u,t] for p in product)

    vMarginService_s_u_o[s=product, u=use, o=origin, t=t1:T],
    vMarginService_s_u_o[s,u,o,t] == pBasic[s,u,o,t] * qMarginService_s_u_o[s,u,o,t]

    vMarginService_s_u[s=margin_services, u=use, t=t1:T],
    vMarginService_s_u[s,u,t] == ∑(vMarginService_s_u_o[s,u,o,t] for o in origin)

    vMarginBundle_u[u=use, t=t1:T], vMarginBundle_u[u,t] == ∑(vMarginService_s_u[s,u,t] for s in margin_services)

    vUse_p_u_o[p=product, u=use, o=origin, t=t1:T], vUse_p_u_o[p,u,o,t] == pBasic[p,u,o,t] * qUse_p_u_o[p,u,o,t]

    vY_p_i[p=product, i=industry, t=t1:T], vY_p_i[p,i,t] == pY_p_i[p,i,t] * qY_p_i[p,i,t]

    vSupply_p_o[p=product, o=domestic, t=t1:T], vSupply_p_o[p,o,t] == ∑(vY_p_i[p,i,t] for i in industry)

    vSupply_p_o[p=product, o=import_origin, t=t1:T], vSupply_p_o[p,o,t] == ∑(vUse_p_u_o[p,u,o,t] for u in use)

    pSupply_p_o[p=product, o=origin, t=t1:T], pSupply_p_o[p,o,t] * qSupply_p_o[p,o,t] == vSupply_p_o[p,o,t]

    vY_i[i=industry, t=t1:T], vY_i[i,t] == ∑(vY_p_i[p,i,t] for p in product)

    pY_i[i=industry, t=t1:T], pY_i[i,t] * qY_i[i,t] == vY_i[i,t]

    vUse_u_o[u=use, o=origin, t=t1:T], vUse_u_o[u,o,t] == ∑(vUse_p_u_o[p,u,o,t] for p in product)

    pUse_u_o[u=ordinary_uses, o=origin, t=t1:T], pUse_u_o[u,o,t] * qUse_u_o[u,o,t] == vUse_u_o[u,o,t]

    vSupply_o[o=origin, t=t1:T], vSupply_o[o,t] == ∑(vSupply_p_o[p,o,t] for p in product)

    pSupply_o[o=origin, t=t1:T], pSupply_o[o,t] * qSupply_o[o,t] == vSupply_o[o,t]

    vX[t=t1:T], vX[t] == ∑(vPurchaserUse_p_u[p,:X,t] for p in product) + vCTourist[t]
    pX[t=t1:T], pX[t] * qX[t] == vX[t]

    vC[t=t1:T], vC[t] == pC[t] * qC[t]
    vG[t=t1:T], vG[t] == ∑(vPurchaserUse_p_u[p,:G,t] for p in product)
    pG[t=t1:T], pG[t] * qG[t] == vG[t]
    vI[t=t1:T], vI[t] == ∑(vPurchaserUse_p_u[p,:K,t] for p in product)
    pI[t=t1:T], pI[t] * qI[t] == vI[t]
    vINV[t=t1:T], vINV[t] == ∑(vPurchaserUse_p_u[p,:INV,t] for p in product)

    # Post-solve accounts that do not add rows to the square system.
    @test_constraint("Supply shares reproduce product output"; rtol=1e-3)
    qSupply_p_o[p=product, o=domestic, t=t1:T], qSupply_p_o[p,o,t] == ∑(qY_p_i[p,i,t] for i in industry)

    @test_constraint("Origin values sum to product use"; rtol=1e-3)
    qPurchaserUse_p_u[p=product, u=ordinary_uses, t=t1:T],
    pPurchaserUse_p_u[p,u,t] * qPurchaserUse_p_u[p,u,t] ==
        ∑(vPurchaserUse_p_u_o[p,u,o,t] for o in origin)

    @test_constraint("Margin-service shares sum to the margin bundle"; rtol=1e-3)
    qMarginBundle_u[u=use, t=t1:T], qMarginBundle_u[u,t] == ∑(qMarginService_s_u[s,u,t] for s in margin_services)

    @test_constraint("Margin origin shares sum to service demand"; rtol=1e-3)
    qMarginService_s_u[s=margin_services, u=use, t=t1:T],
      qMarginService_s_u[s,u,t] == ∑(qMarginService_s_u_o[s,u,o,t] for o in origin)

    @test_constraint("Imports sum by product and use"; rtol=1e-3)
    qM[t=t1:T], qM[t] == ∑(qM_u[u,t] for u in use)
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    rIndustryShare[:,:,t1], qY_p_i[:,:,t1]

    rOriginShare[(p,u,o,t) in keys(qPurchaserUse_p_u_o); u in ordinary_uses && t == t1],
    qPurchaserUse_p_u_o[p=product, u=ordinary_uses, o=origin, t=t1]

    rMarginServiceShare[:,:,t1], qMarginService_s_u[:,:,t1]

    rMarginRate[:,:,t1], qMarginBundle_p_u[:,:,t1]

    rOriginShare[(s,u,o,t) in keys(qMarginService_s_u_o); (s,u,o) in margin_only_s_u_o && t == t1],
    qMarginService_s_u_o[s=product, u=use, o=origin, t=t1; (s,u,o) in margin_only_s_u_o]

    tNetProduct[:,:,t1], vNetProductTax_p_u[:,:,t1]

  end

  return block
end

end # module
