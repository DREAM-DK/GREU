# Set Armington demand for domestic direct exports and tourist demand.
# Provide a zero price hook for an optional export-rigidity module.
# Link imports for re-export to the same foreign market size.
# Keep the tourist product split and value in the input-output accounts.
module Exports

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  domestic,
  import_origin,
  pPurchaserUse_p_u_o,
  qCTourist,
  qPurchaserUse_p_u_o,
  qX_p,
  rOriginShare
import ..InputOutputSettings: product
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero

# ============================================================================
# Indices
# ============================================================================
const export_p_t = Set((p,year) for (p,u,o,year) in keys(qPurchaserUse_p_u_o) if u == :X && o == domestic)
const export_product = sort(unique(first.(export_p_t)))
const reexport_p_t = Set((p,year) for (p,year) in export_p_t if (p,:X,import_origin,year) in keys(qPurchaserUse_p_u_o))
const reexport_product = sort(unique(first.(reexport_p_t)))
const domestic_only_export_p_t = setdiff(export_p_t, reexport_p_t)

# CPA I covers accommodation and food services. Its domestic household price
# is the best A21 proxy for the price faced by inbound tourists.
const tourist_price_product = :I
@assert all((tourist_price_product,:C,domestic,year) in keys(qPurchaserUse_p_u_o) for year in t) "The tourist price product needs domestic household use"

# ============================================================================
# Variables
# ============================================================================
const ExportsTag = Tag(:Exports)

@variables model :: (ExportsTag, GrowthAdjusted) begin
  qXMarket_p[p=export_product, t=t; (p,t) in export_p_t] :: ForecastConstant, "Foreign demand for domestic direct exports by product."
  qXReexport_p[p=reexport_product, t=t; (p,t) in reexport_p_t], "Imports for re-export by product."
  qCTouristMarket[t] :: ForecastConstant, "Foreign market size for tourist demand."
end

@variables model :: (ExportsTag, InflationAdjusted) begin
  pXForeign_p[(p,t)=qXMarket_p] :: ForecastConstant, "Price of competing foreign goods by product."
  jXrigidity[p=export_product, t=t; (p,t1+1) in export_p_t] :: ForecastZero, "Added price signal for products with forecast exports."
  pCTouristForeign[t] :: ForecastConstant, "Price of competing foreign tourist services."
end

@variables model :: ExportsTag begin
  eX_p[p=export_product], "Price elasticity of direct exports by product."
  eCTourist, "Price elasticity of tourist demand."
  uXReexport_p[(p,t)=qXReexport_p] :: ForecastConstant, "Re-export scale relative to the foreign market by product."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[pXForeign_p] .= 1.0
  db[pCTouristForeign] .= 1.0
  db[eX_p] .= 5.0
  db[eCTourist] = 5.0
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[jXrigidity] .= 0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  pX_p = pPurchaserUse_p_u_o[:,:X,domestic,:]

  return @block model begin
    # Armington demand for domestic goods in the direct export column.
    rOriginShare[p=export_product, u=:X, o=domestic, t=t1:T; (p,t) in export_p_t],
    qPurchaserUse_p_u_o[p,u,o,t] * (pX_p[p,t] + jXrigidity[p,t])^eX_p[p] == pXForeign_p[p,t]^eX_p[p] * qXMarket_p[p,t]

    # Imports for re-export do not respond to relative prices.
    rOriginShare[p=reexport_product, u=:X, o=import_origin, t=t1:T; (p,t) in reexport_p_t], qPurchaserUse_p_u_o[p,u,o,t] == qXReexport_p[p,t]

    qXReexport_p[p=reexport_product, t=t1:T], qXReexport_p[p,t] == uXReexport_p[p,t] * qXMarket_p[p,t]

    # Tourist products stay in private consumption. Product I supplies the
    # domestic price signal for total inbound tourist demand.
    qCTourist[t=t1:T],
    qCTourist[t] * pPurchaserUse_p_u_o[tourist_price_product,:C,domestic,t]^eCTourist ==
      qCTouristMarket[t] * pCTouristForeign[t]^eCTourist

    # Direct exports include domestic goods and imports for re-export.
    qX_p[p=product, t=t1:T; (p,t) in reexport_p_t],
    qX_p[p,t] == qPurchaserUse_p_u_o[p,:X,domestic,t] + qPurchaserUse_p_u_o[p,:X,import_origin,t]

    qX_p[p=product, t=t1:T; (p,t) in domestic_only_export_p_t], qX_p[p,t] == qPurchaserUse_p_u_o[p,:X,domestic,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qXMarket_p[:,t1],
    rOriginShare[p=export_product, u=:X, o=domestic, t=t1]

    uXReexport_p[:,t1], qXReexport_p[:,t1]

    qXReexport_p[:,t1],
    rOriginShare[p=reexport_product, u=:X, o=import_origin, t=t1]

    qCTouristMarket[t1], qCTourist[t1]
  end

  return block
end

end # module
