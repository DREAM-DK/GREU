# Let foreign prices and foreign demand follow the home economy in a shock.
# Each import price and each competing export price follows the home price of the same product.
# Each export market follows home imports of the same product. Tourist demand has matching rules.
# The ECB rate holds the consumer price index on its baseline path.
# Load this module only. A shock file adds its equations and sets the ratios from the baseline.
module ForeignClosure

using SquareModels
import ..Exports:
  export_product,
  pCTouristForeign,
  pXForeign_p,
  qCTouristMarket,
  qXMarket_p,
  tourist_price_product
import ..FinancialIncome: rECB
import ..InputOutput:
  domestic,
  import_origin,
  pC,
  pM_p,
  pPurchaserUse_p_u_o,
  pSupply_p_o,
  qC,
  qSupply_p_o
import ..InputOutputSettings: product
import ..model
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================
const ForeignClosureTag = Tag(:ForeignClosure)

@variables model :: ForeignClosureTag begin
  pM2pY_p[(p,t)=pM_p], "Import price relative to the domestic basic price by product."
  pXForeign2pX_p[(p,t)=pXForeign_p], "Competing foreign price relative to the domestic export price by product."
  qXMarket2qM_p[(p,t)=qXMarket_p], "Foreign market size relative to imports by product."
  pCTouristForeign2pCTourist[t], "Competing foreign tourist price relative to the domestic tourist price."
  qCTouristMarket2qC[t], "Foreign tourist market size relative to household consumption."
  pCAnchor[t], "Baseline path of the consumer price index."
end

# ============================================================================
# Assign data
# ============================================================================
# The module has no source data. The baseline sets all values. See define_calibration.
function assign_data!(db)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  pX_p = pPurchaserUse_p_u_o[:,:X,domestic,:]
  pCTourist = pPurchaserUse_p_u_o[tourist_price_product,:C,domestic,:]

  return @block model begin
    # Import prices follow the domestic basic price of the same product.
    pSupply_p_o[p=product, o=import_origin, t=t1:T],
    pSupply_p_o[p,o,t] == pM2pY_p[p,t] * pSupply_p_o[p,domestic,t]

    # Competing foreign prices follow the domestic export price. The relative export price
    # is then fixed, so exports follow the foreign market.
    pXForeign_p[p=export_product, t=t1:T], pXForeign_p[p,t] == pXForeign2pX_p[p,t] * pX_p[p,t]

    # The foreign market follows imports of the same product. Imports include imports for
    # re-export, which follow the same market.
    qXMarket_p[p=export_product, t=t1:T],
    qXMarket_p[p,t] == qXMarket2qM_p[p,t] * qSupply_p_o[p,import_origin,t]

    # Tourist exports are not a product. The foreign tourist price follows the domestic
    # tourist price. The model has no tourist imports, so the market follows household
    # consumption.
    pCTouristForeign[t=t1:T], pCTouristForeign[t] == pCTouristForeign2pCTourist[t] * pCTourist[t]

    qCTouristMarket[t=t1:T], qCTouristMarket[t] == qCTouristMarket2qC[t] * qC[t]

    # Nominal anchor. Foreign prices now move with home prices, so they no longer set the
    # price level. The rate for year t is set in year t-1. It holds the consumer price
    # index of year t-1 on the baseline path. The rate in t1 was set before the shock.
    # No rate holds the index in year T, so the index can move in that year.
    rECB[t=(t1+1):T], pC[t-1] == pCAnchor[t-1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
# Solve this block alone on a baseline. All other variables keep their baseline values.
function define_calibration(base=define_equations())
  block = copy(base)

  # The baseline path of each foreign variable sets its ratio to the home variable.
  @endo_exo_swap! block begin
    pM2pY_p[p=product, t=t1:T], pSupply_p_o[p=product, o=import_origin, t=t1:T]

    pXForeign2pX_p[p=export_product, t=t1:T], pXForeign_p[p=export_product, t=t1:T]

    qXMarket2qM_p[p=export_product, t=t1:T], qXMarket_p[p=export_product, t=t1:T]

    pCTouristForeign2pCTourist[t=t1:T], pCTouristForeign[t=t1:T]

    qCTouristMarket2qC[t=t1:T], qCTouristMarket[t=t1:T]

    pCAnchor[t=t1:(T-1)], rECB[t=(t1+1):T]
  end

  return block
end

end # module
