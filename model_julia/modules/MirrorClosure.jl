# Let the rest of the world respond to a shock as the home economy does.
# Tie each foreign price and market size to its home counterpart at the baseline ratio.
# Hold the import price index on its baseline path. The ECB rate is the free variable.
# One export market factor steers rest-of-world net lending and net assets to their baseline shares of GDP.
# Let foreign share prices jump with home share prices in t1. This replaces a base equation.
# Load this module only. A shock file adds its equations. Foreign labor supply stays exogenous.
module MirrorClosure

using SquareModels
import ..Exports:
  export_p_t,
  export_product,
  pCTouristForeign,
  pXForeign_p,
  qCTouristMarket,
  qXMarket_p,
  tourist_price_product
import ..FinancialIncome: rECB
import ..FinancialRevaluations: equity_issuer, rFinReval_s_f, rFirmRequiredReturn_s
import ..FixedBasePriceAggregates: vGDP
import ..ImportSubstitution: import_use
import ..InputOutput:
  domestic,
  import_origin,
  pM,
  pPurchaserUse_p_u_o,
  pSupply_p_o,
  qC,
  qPurchaserUse_p_u_o
import ..InputOutputSettings: origin, product
import ..model
import ..SectorAccounts: vFinPosition_s_f, vNetFinAssets, vNetFinTransactions
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================
# Products with a domestic price and an import price.
const mirror_price_product = [p for p in product if all((p,o,t1) in keys(pSupply_p_o) for o in origin)]

# Export products that the home economy also imports for domestic use.
const mirror_market_product = [
  p for p in export_product
  if any((p,u,import_origin,t1) in keys(qPurchaserUse_p_u_o) for u in import_use)
]

const home_equity_issuer = setdiff(equity_issuer, [:RoW])

# ============================================================================
# Variables
# ============================================================================
const MirrorClosureTag = Tag(:MirrorClosure)

@variables model :: MirrorClosureTag begin
  pM2pY_p[p=mirror_price_product, t=t], "Import price relative to the domestic basic price by product."
  pXForeign2pX_p[(p,t)=pXForeign_p], "Competing foreign price relative to the domestic export price by product."
  pCTouristForeign2pC[t], "Competing foreign tourist price relative to the domestic tourist price."
  qXMarket2qM_p[p=mirror_market_product, t=t; (p,t) in export_p_t], "Foreign market size relative to imports for domestic use by product."
  qCTouristMarket2qC[t], "Foreign tourist market size relative to household consumption."
  fXMarket[t], "Common factor on all foreign market sizes. One on the baseline."
  rRoWNetFinTransactions2GDP[t], "Baseline rest-of-world net financial transactions relative to GDP."
  rRoWNetFinAssets2GDP[t], "Baseline rest-of-world net financial assets relative to GDP."
  rRoWNetFinAssetsCorrection, "Share of the gap in rest-of-world net financial assets closed each year."
  pMAnchor[t], "Baseline path of the import price index."
  rEquityPremium_s[s=equity_issuer, t=t], "Required equity return less the ECB rate by issuer."
  rRoWEquityRevalGap[t], "Baseline revaluation rate on rest-of-world equity less the home issuer average."
end

# ============================================================================
# Assign data
# ============================================================================
# The baseline sets all other values. See define_calibration.
function assign_data!(db)
  db[fXMarket] .= 1.0
  db[rRoWNetFinAssetsCorrection] = 0.1
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  pX_p = pPurchaserUse_p_u_o[:,:X,domestic,:]
  pCTourist = pPurchaserUse_p_u_o[tourist_price_product,:C,domestic,:]

  return @block model begin
    # Foreign prices follow the home price of the same product.
    pSupply_p_o[p=mirror_price_product, o=import_origin, t=t1:T],
    pSupply_p_o[p,o,t] == pM2pY_p[p,t] * pSupply_p_o[p,domestic,t]

    pXForeign_p[p=export_product, t=t1:T], pXForeign_p[p,t] == pXForeign2pX_p[p,t] * pX_p[p,t]

    pCTouristForeign[t=t1:T], pCTouristForeign[t] == pCTouristForeign2pC[t] * pCTourist[t]

    # Foreign demand for home products follows home demand for foreign products.
    qXMarket_p[p=mirror_market_product, t=t1:T],
    qXMarket_p[p,t] ==
      fXMarket[t] * qXMarket2qM_p[p,t] * ∑(qPurchaserUse_p_u_o[p,u,import_origin,t] for u in import_use)

    qCTouristMarket[t=t1:T], qCTouristMarket[t] == fXMarket[t] * qCTouristMarket2qC[t] * qC[t]

    # External balance. Like countries cannot lend more to each other. Mirrored trade
    # alone does not respond to net foreign assets, so they would drift. One factor on
    # all foreign markets holds rest-of-world net lending at its baseline share of GDP.
    # A gap between net assets and their baseline share of GDP in the prior year moves
    # net lending. The gap then closes at a fixed rate.
    fXMarket[t=t1:T],
    vNetFinTransactions[:RoW,t] ==
      rRoWNetFinTransactions2GDP[t] * vGDP[t]
      + rRoWNetFinAssetsCorrection * (rRoWNetFinAssets2GDP[t-1] - vNetFinAssets[:RoW,t-1] / vGDP[t-1]) * vGDP[t]

    # Nominal anchor. Foreign prices now move with home prices, so they no longer set the
    # price level. The rate for year t is set in year t-1. It holds the import price
    # index of year t-1 on the baseline path. The rate in t1 was set before the shock.
    # No rate holds the index in year T, so the index can move in that year.
    rECB[t=(t1+1):T], pM[t-1] == pMAnchor[t-1]

    # The required equity return follows the ECB rate, for home and foreign issuers.
    rFirmRequiredReturn_s[s=equity_issuer, t=(t1+1):T],
    rFirmRequiredReturn_s[s,t] == rECB[t] + rEquityPremium_s[s,t]

    # Share price jump in t1. The required return sets the revaluation rate from t1+1.
    # In the base model, the terminal value equation of the rest of the world sets its
    # rate in t1. Net foreign assets move slowly, so a small terminal gap needs a large
    # jump. Here the foreign rate in t1 follows the home issuer average, weighted by
    # opening equity. This equation replaces that terminal value equation.
    rFinReval_s_f[s=[:RoW], f=[:Equity], al=[:Liab], t=[T]; T > t1],
    ∑((rFinReval_s_f[s,f,al,t1] - rRoWEquityRevalGap[t1] - rFinReval_s_f[s2,f,al,t1]) *
      vFinPosition_s_f[s2,f,al,t1-1] for s2 in home_equity_issuer) == 0
  end
end

# ============================================================================
# Calibration
# ============================================================================
# Solve this block alone on a baseline. All other variables keep their baseline values.
function define_calibration(base=define_equations())
  # The baseline sets the net asset target. The gap is then zero on the baseline.
  block = base + @block model begin
    rRoWNetFinAssets2GDP[t=(t1-1):(T-1)], rRoWNetFinAssets2GDP[t] * vGDP[t] == vNetFinAssets[:RoW,t]
  end

  # The baseline path of each foreign variable sets its ratio to the home variable.
  @endo_exo_swap! block begin
    pM2pY_p[p=mirror_price_product, t=t1:T],
    pSupply_p_o[p=mirror_price_product, o=import_origin, t=t1:T]

    pXForeign2pX_p[p=export_product, t=t1:T], pXForeign_p[p=export_product, t=t1:T]

    pCTouristForeign2pC[t=t1:T], pCTouristForeign[t=t1:T]

    qXMarket2qM_p[p=mirror_market_product, t=t1:T], qXMarket_p[p=mirror_market_product, t=t1:T]

    qCTouristMarket2qC[t=t1:T], qCTouristMarket[t=t1:T]

    rRoWNetFinTransactions2GDP[t=t1:T], fXMarket[t=t1:T]

    pMAnchor[t=t1:(T-1)], rECB[t=(t1+1):T]

    rEquityPremium_s[s=equity_issuer, t=(t1+1):T], rFirmRequiredReturn_s[s=equity_issuer, t=(t1+1):T]

    rRoWEquityRevalGap[t1], rFinReval_s_f[:RoW,:Equity,:Liab,T]
  end

  return block
end

end # module
