# Set Armington demand for domestic direct exports and tourist demand.
# Link imports for re-export to the same foreign market size.
# Keep the tourist product split and value in the input-output accounts.
module Exports

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  domestic,
  import_origin,
  pPurchaserUse_p_u_o,
  purchaser_use_p_u_o,
  qCTourist,
  qPurchaserUse_p_u_o,
  qX_p,
  rOriginShare
import ..InputOutputSettings: product
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Indices
# ============================================================================
const export_product = [p for p in product if (p, :X, domestic) in purchaser_use_p_u_o]
const reexport_product = [p for p in export_product if (p, :X, import_origin) in purchaser_use_p_u_o]
const domestic_only_export_product = setdiff(export_product, reexport_product)

# CPA I covers accommodation and food services. Its domestic household price
# is the best A21 proxy for the price faced by inbound tourists.
const tourist_price_product = :I
@assert (tourist_price_product, :C, domestic) in purchaser_use_p_u_o "The tourist price product needs domestic household use"

# ============================================================================
# Variables
# ============================================================================
const ExportsTag = Tag(:Exports)

@variables model :: (ExportsTag, GrowthAdjusted) begin
  qXMarket_p[p=export_product, t=t] :: ForecastConstant, "Foreign demand for domestic direct exports by product."
  qXReexport_p[p=reexport_product, t=t], "Imports for re-export by product."
  qCTouristMarket[t] :: ForecastConstant, "Foreign market size for tourist demand."
end

@variables model :: (ExportsTag, InflationAdjusted) begin
  pXForeign_p[p=export_product, t=t] :: ForecastConstant, "Price of competing foreign goods by product."
  pCTouristForeign[t] :: ForecastConstant, "Price of competing foreign tourist services."
end

@variables model :: ExportsTag begin
  eX_p[p=export_product], "Price elasticity of direct exports by product."
  eCTourist, "Price elasticity of tourist demand."
  uXReexport_p[p=reexport_product, t=t] :: ForecastConstant, "Re-export scale relative to the foreign market by product."
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
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Armington demand for domestic goods in the direct export column.
    rOriginShare[p=export_product, u=:X, o=domestic, t=t1:T],
    qPurchaserUse_p_u_o[p,u,o,t] * pPurchaserUse_p_u_o[p,u,o,t]^eX_p[p] == qXMarket_p[p,t] * pXForeign_p[p,t]^eX_p[p]

    # Imports for re-export do not respond to relative prices.
    rOriginShare[p=reexport_product, u=:X, o=import_origin, t=t1:T], qPurchaserUse_p_u_o[p,u,o,t] == qXReexport_p[p,t]

    qXReexport_p[p=reexport_product, t=t1:T], qXReexport_p[p,t] == uXReexport_p[p,t] * qXMarket_p[p,t]

    # Tourist products stay in private consumption. Product I supplies the
    # domestic price signal for total inbound tourist demand.
    qCTourist[t=t1:T],
    qCTourist[t] * pPurchaserUse_p_u_o[tourist_price_product,:C,domestic,t]^eCTourist ==
      qCTouristMarket[t] * pCTouristForeign[t]^eCTourist

    # Direct exports include domestic goods and imports for re-export.
    qX_p[p=reexport_product, t=t1:T],
    qX_p[p,t] == qPurchaserUse_p_u_o[p,:X,domestic,t] + qPurchaserUse_p_u_o[p,:X,import_origin,t]

    qX_p[p=domestic_only_export_product, t=t1:T], qX_p[p,t] == qPurchaserUse_p_u_o[p,:X,domestic,t]
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
