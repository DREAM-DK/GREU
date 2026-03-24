# ==============================================================================
# Input-Output Module
# ==============================================================================
# Demand for energy, other intermediate inputs, investments, private and public
# consumption, and exports is allocated to imports and output from domestic
# industries. Mirrors model/modules/input_output.gms.
module InputOutput

import JuMP
using SquareModels
using ..GrowthInflationAdjustment
using ..Data: load_set, load_parameter, load_parameter!
import ..db, ..t, ..t1, ..T, ..tBase, ..ForecastConstant

# ==========================================================================
# Indices
# ==========================================================================
const i = load_set(:i)   # Production industries
const d_all = load_set(:d)   # All demand components (including stubs)
const m = load_set(:m)   # Industries with imports
const rx = i             # Non-energy intermediates
const re = load_set(:re) # Energy inputs in production
const k = load_set(:k)   # Capital types
const c = load_set(:c)   # Private consumption types
const g = load_set(:g)   # Government consumption types
const x = load_set(:x)   # Export groups

const d_ene = load_set(:d_ene) # Energy demand components
const d_non_ene = load_set(:d_non_ene) # Non-energy demand components

const invt = first(load_set(:invt)) # Inventories
const invt_ene = first(load_set(:invt_ene)) # Energy inventories

# ==========================================================================
# Sparse (i,d) keys from vY_i_d and vM_i_d data
# ==========================================================================
const (d1Y, d1M) = let
  energy_ind = Set(["19000", "35002", "38393"])
  d_ene_s = Set(string.(d_ene))
  d_non_ene_s = Set(string.(d_non_ene))

  Y_keys = Set{Tuple{Symbol,Symbol}}()
  for (k, v) in load_parameter(:vY_i_d)
    k[1] in energy_ind && k[2] in d_non_ene_s && continue
    abs(v) > 1e-6 && push!(Y_keys, (Symbol(k[1]), Symbol(k[2])))
  end

  M_keys = Set{Tuple{Symbol,Symbol}}()
  for (k, v) in load_parameter(:vM_i_d)
    k[1] != "19000" && k[2] in d_ene_s && continue
    abs(v) > 1e-6 && push!(M_keys, (Symbol(k[1]), Symbol(k[2])))
  end

  Y_keys, M_keys
end
const d1YM = d1Y ∪ d1M

# Demand components with at least one supply pair (drops stubs like res, env, tl)
const d = [d_v for d_v in d_all if any((i_v, d_v) in d1YM for i_v in i)]

# ==========================================================================
# Variables
# ==========================================================================
# Values (growth + inflation adjusted)
@variables db.model :: (GrowthAdjusted, InflationAdjusted) begin
  vGDP[t], "Gross Domestic Product"
  vGVA[t], "Gross value added"
  vR[t], "Non-energy intermediate inputs"
  vE[t], "Energy intermediate inputs"
  vI[t], "Investments"
  vC[t], "Private consumption"
  vG[t], "Public consumption"
  vX[t], "Exports"
  vY[t], "Total output"
  vM[t], "Total imports"
  vY_i[i, t], "Output by industry"
  vM_i[m, t], "Imports by industry"
  vD[d, t], "Demand by demand component"
  vY_i_d[i=i, d=d, t=t; (i, d) in d1Y], "Domestic output by industry and demand"
  vY_i_d_base[i=i, d=d, t=t; (i, d) in d1Y], "Domestic output in base prices"
  vM_i_d[i=i, d=d, t=t; (i, d) in d1M], "Imports by industry and demand"
  vM_i_d_base[i=i, d=d, t=t; (i, d) in d1M], "Imports in base prices"
  vtY_i_d[i=i, d=d, t=t; (i, d) in d1Y], "Net duties on domestic production by (i,d)"
  vtM_i_d[i=i, d=d, t=t; (i, d) in d1M], "Net duties on imports by (i,d)"
  vtY_i[i, t], "Net duties on domestic production by industry"
  vtM_i[m, t], "Net duties on imports by industry"
  vtY[t], "Total net duties on domestic production"
  vtM[t], "Total net duties on imports"
  vtY_i_Sub[i, t], "Production subsidies by industry"
  vtY_i_Tax[i, t], "Production taxes by industry"
  vtY_i_NetTaxSub[i, t], "Net production taxes and subsidies"
  vtY_Tax[t], "Total production taxes"
  vtY_Sub[t], "Total production subsidies"
  vC_WalrasLaw[t], "Walras law residual (stub, from households)"
end

# Prices (inflation adjusted)
@variables db.model :: InflationAdjusted begin
  pGDP[t], "GDP deflator"
  pGVA[t], "GVA deflator"
  pR[t], "Non-energy intermediates deflator"
  pE[t], "Energy intermediates deflator"
  pI[t], "Investment deflator"
  pC[t], "Consumer price index"
  pG[t], "Government consumption deflator"
  pX[t], "Export deflator"
  pY[t], "Output deflator"
  pM[t], "Import deflator"
  pY_i[i, t], "Price of domestic output by industry"
  pM_i[i, t], "Price of imports by industry"
  pD[d, t], "Deflator of demand component"
  pY_i_d[i=i, d=d, t=t; (i, d) in d1Y], "Price of domestic output by (i,d)"
  pY_i_d_base[i=i, d=d, t=t; (i, d) in d1Y], "Base price of domestic output"
  pM_i_d[i=i, d=d, t=t; (i, d) in d1M], "Price of imports by (i,d)"
  pM_i_d_base[i=i, d=d, t=t; (i, d) in d1M], "Base price of imports"
end

# Quantities (growth adjusted)
@variables db.model :: GrowthAdjusted begin
  qGDP[t], "Real GDP"
  qGVA[t], "Real GVA"
  qR[t], "Real non-energy intermediates"
  qE[t], "Real energy intermediates"
  qI[t], "Real investments"
  qC[t], "Real consumption"
  qG[t], "Real government consumption"
  qX[t], "Real exports"
  qY[t], "Real total output"
  qM[t], "Real imports"
  qY_i[i, t], "Real output by industry"
  qM_i[m, t], "Real imports by industry"
  qD[d, t], "Real demand by demand component"
  qY_i_d[i=i, d=d, t=t; (i, d) in d1Y], "Real domestic output by (i,d)"
  qM_i_d[i=i, d=d, t=t; (i, d) in d1M], "Real imports by (i,d)"
end

# Rates and shares (no adjustment)
@variables db.model begin
  tY_i_d[i=i, d=d, t=t; (i, d) in d1Y] :: ForecastConstant, "Tax rate on domestic output by (i,d)"
  tM_i_d[i=i, d=d, t=t; (i, d) in d1M] :: ForecastConstant, "Tax rate on imports by (i,d)"
  tY_i_sub[i, t] :: ForecastConstant, "Average subsidy rate"
  tY_i_tax[i, t] :: ForecastConstant, "Average production tax rate"
  jfpY_i_d[i=i, d=d, t=t; (i, d) in d1Y], "Price deviation, domestic"
  jfpM_i_d[i=i, d=d, t=t; (i, d) in d1M], "Price deviation, imports"
  rYM[i=i, d=d, t=t; (i, d) in d1YM] :: ForecastConstant, "Industry composition of demand"
  rM[i=i, d=d, t=t; (i, d) in d1YM] :: ForecastConstant, "Import share"
end

# ==========================================================================
# Data
# ==========================================================================
function set_data!(db)
  db[vY_i_d] .= 0.0
  db[vY_i_d_base] .= 0.0
  db[vM_i_d] .= 0.0
  db[vM_i_d_base] .= 0.0
  db[vtY_i_d] .= 0.0
  db[vtM_i_d] .= 0.0
  db[vtY_i_Sub] .= 0.0
  db[vtY_i_Tax] .= 0.0
  db[jfpY_i_d] .= 0.0
  db[jfpM_i_d] .= 0.0

  load_parameter!(db, :vY_i_d, vY_i_d)
  load_parameter!(db, :vY_i_d_base, vY_i_d_base)
  load_parameter!(db, :vtY_i_d, vtY_i_d)
  load_parameter!(db, :vM_i_d, vM_i_d)
  load_parameter!(db, :vM_i_d_base, vM_i_d_base)
  load_parameter!(db, :vtM_i_d, vtM_i_d)
  load_parameter!(db, :vtY_i_Sub, vtY_i_Sub)
  load_parameter!(db, :vtY_i_Tax, vtY_i_Tax)

  # Import shares: 0 for domestic-only, 1 for import-only.
  # Cells in d1Y ∩ d1M are calibrated — leave unset so endo_exo_data_residuals! doesn't re-exogenize.
  for k in keys(rM)
    i_v, d_v = k[1], k[2]
    (i_v, d_v) ∈ d1Y && (i_v, d_v) ∈ d1M && continue
    db[rM[k...]] = (i_v, d_v) ∈ d1Y ? 0.0 : 1.0
  end

  # Real quantities: q = v_base (= v - vt)
  db[qY_i_d] .= 0.0
  db[qM_i_d] .= 0.0
  for (v, vt, q) in ((vY_i_d, vtY_i_d, qY_i_d), (vM_i_d, vtM_i_d, qM_i_d))
    for k in keys(v)
      val = db[v[k...]]
      !isnothing(val) && val > 1e-6 && (db[q[k...]] = val - something(db[vt[k...]], 0.0))
    end
  end

  db[qD] .= 0.0
  for q_id in (qY_i_d, qM_i_d), k in keys(q_id)
    val = db[q_id[k...]]
    !isnothing(val) && (db[qD[k[2], k[3]]] += val)
  end

  # All prices = 1 (inflation adjustment via tags ≡ GAMS fpt[t])
  for p in [pY_i, pM_i, pD, pR, pE, pI, pC, pG, pX, pM, pY, pGDP, pGVA,
            pY_i_d, pM_i_d, pY_i_d_base, pM_i_d_base]
    db[p] .= 1.0
  end

  db[vGDP] .= 2321.0
  db[vC_WalrasLaw] .= 0.0

  return nothing
end

# ==========================================================================
# Starting values (solver hints, not exogenous data)
# ==========================================================================
function set_starting_values!(db)
  db[tY_i_d] .= 0.0
  db[tM_i_d] .= 0.0

  # Import shares for cells with both domestic and import supply
  for k in keys(rM)
    i_v, d_v = k[1], k[2]
    (i_v, d_v) ∈ d1Y && (i_v, d_v) ∈ d1M || continue
    vY = something(db[vY_i_d_base[k...]], 0.0)
    vM = something(db[vM_i_d_base[k...]], 0.0)
    vY + vM > 1e-8 && (db[rM[k...]] = vM / (vY + vM))
  end

  # Composition shares: rYM = q_id / ((1-rM or rM) * qD)
  for k in keys(rYM)
    i_v, d_v, t_v = k
    qD_val = something(db[qD[d_v, t_v]], 0.0)
    abs(qD_val) < 1e-12 && continue
    in_d1Y = (i_v, d_v) in d1Y
    q = something(db[in_d1Y ? qY_i_d[k...] : qM_i_d[k...]], 0.0)
    rM_val = something(db[rM[k...]], in_d1Y ? 0.0 : 1.0)
    share = in_d1Y ? (1 - rM_val) : rM_val
    denom = share * qD_val
    db[rYM[k...]] = abs(denom) > 1e-12 ? q / denom : 0.0
  end
end

# ==========================================================================
# Equations
# ==========================================================================
function define_equations()
  return @block db begin
    # -- GDP identity and chain price index --
    vGDP[t = t1:T],
    vGDP[t] == vC[t] + vI[t] + vG[t] + vX[t] - vM[t]

    pGDP[t = t1:T],
    pGDP[t] * qGDP[t] == vGDP[t]

    qGDP[t = t1:T],
    qGDP[t] * pGDP[t-1] == pC[t-1]*qC[t] + pI[t-1]*qI[t] + pG[t-1]*qG[t] + pX[t-1]*qX[t] - pM[t-1]*qM[t]

    # -- GVA identity and chain price index --
    vGVA[t = t1:T],
    vGVA[t] == vY[t] - vR[t] - vE[t]

    pGVA[t = t1:T],
    pGVA[t] * qGVA[t] == vGVA[t]

    qGVA[t = t1:T],
    qGVA[t] * pGVA[t-1] == pY[t-1]*qY[t] - pR[t-1]*qR[t] - pE[t-1]*qE[t]

    # -- Demand aggregates --
    vR[t = t1:T], vR[t] == ∑(vD[s, t] for s in rx)
    vE[t = t1:T], vE[t] == ∑(vD[s, t] for s in re)
    vI[t = t1:T], vI[t] == ∑(vD[s, t] for s in k) + vD[invt, t]
    vC[t = t1:T], vC[t] == ∑(vD[s, t] for s in c) + vC_WalrasLaw[t]
    vG[t = t1:T], vG[t] == ∑(vD[s, t] for s in g)
    vX[t = t1:T], vX[t] == ∑(vD[s, t] for s in x)

    # -- Deflator identities --
    pR[t = t1:T], pR[t] * qR[t] == vR[t]
    pE[t = t1:T], pE[t] * qE[t] == vE[t]
    pI[t = t1:T], pI[t] * qI[t] == vI[t]
    pC[t = t1:T], pC[t] * qC[t] == vC[t]
    pG[t = t1:T], pG[t] * qG[t] == vG[t]
    pX[t = t1:T], pX[t] * qX[t] == vX[t]

    # -- Chain price indices for demand aggregates --
    qR[t = t1:T],
    qR[t] * pR[t-1] == ∑(pD[s, t-1] * qD[s, t] for s in rx)

    qE[t = t1:T],
    qE[t] * pE[t-1] == ∑(pD[s, t-1] * qD[s, t] for s in re)

    qI[t = t1:T],
    qI[t] * pI[t-1] == ∑(pD[s, t-1] * qD[s, t] for s in k) + pD[invt, t-1]*qD[invt, t] + pD[invt_ene, t-1]*qD[invt_ene, t]

    qC[t = t1:T],
    qC[t] * pC[t-1] == ∑(pD[s, t-1] * qD[s, t] for s in c)

    qG[t = t1:T],
    qG[t] * pG[t-1] == ∑(pD[s, t-1] * qD[s, t] for s in g)

    qX[t = t1:T],
    qX[t] * pX[t-1] == ∑(pD[s, t-1] * qD[s, t] for s in x)

    # -- Supply equilibrium --
    vY_i[i = i, t = t1:T],
    vY_i[i, t] + vtY_i[i, t] == ∑(vY_i_d[i, d, t] for d in d if (i, d) in d1Y)

    vY[t = t1:T], vY[t] == ∑(vY_i[s, t] for s in i)
    pY[t = t1:T], pY[t] * qY[t] == vY[t]

    qY[t = t1:T],
    qY[t] * pY[t-1] == ∑(pY_i[s, t-1] * qY_i[s, t] for s in i)

    # -- Industry quantity aggregation (base-year tax correction) --
    qY_i[i = i, t = t1:T],
    qY_i[i, t] == ∑(qY_i_d[i, d, t] / (1 + tY_i_d[i, d, tBase]) for d in d if (i, d) in d1Y)

    qM_i[m = m, t = t1:T],
    qM_i[m, t] == ∑(qM_i_d[m, d, t] / (1 + tM_i_d[m, d, tBase]) for d in d if (m, d) in d1M)

    # -- Import aggregation --
    vM_i[m = m, t = t1:T],
    vM_i[m, t] + vtM_i[m, t] == ∑(vM_i_d[m, d, t] for d in d if (m, d) in d1M)

    vM[t = t1:T], vM[t] == ∑(vM_i[s, t] for s in m)
    pM[t = t1:T], pM[t] * qM[t] == vM[t]

    qM[t = t1:T],
    qM[t] * pM[t-1] == ∑(pM_i[s, t-1] * qM_i[s, t] for s in m)

    # -- Net duties --
    vtY_i_d[i = i, d = d, t = t1:T; (i, d) in d1Y],
    vtY_i_d[i, d, t] == tY_i_d[i, d, t] * vY_i_d_base[i, d, t]

    vtM_i_d[i = i, d = d, t = t1:T; (i, d) in d1M],
    vtM_i_d[i, d, t] == tM_i_d[i, d, t] * vM_i_d_base[i, d, t]

    vtY_i[i = i, t = t1:T],
    vtY_i[i, t] == ∑(vtY_i_d[i, d, t] for d in d if (i, d) in d1Y)

    vtM_i[m = m, t = t1:T],
    vtM_i[m, t] == ∑(vtM_i_d[m, d, t] for d in d if (m, d) in d1M)

    vtY[t = t1:T], vtY[t] == ∑(vtY_i[s, t] for s in i)
    vtM[t = t1:T], vtM[t] == ∑(vtM_i[s, t] for s in m)

    # -- Production taxes and subsidies --
    vtY_i_Sub[i = i, t = t1:T],
    vtY_i_Sub[i, t] == tY_i_sub[i, t] * qY_i[i, t]

    vtY_i_Tax[i = i, t = t1:T],
    vtY_i_Tax[i, t] == tY_i_tax[i, t] * qY_i[i, t]

    vtY_i_NetTaxSub[i = i, t = t1:T],
    vtY_i_NetTaxSub[i, t] == vtY_i_Tax[i, t] - vtY_i_Sub[i, t]

    vtY_Tax[t = t1:T], vtY_Tax[t] == ∑(vtY_i_Tax[s, t] for s in i)
    vtY_Sub[t = t1:T], vtY_Sub[t] == ∑(vtY_i_Sub[s, t] for s in i)

    # -- Demand composition and deflator --
    vD[d = d, t = t1:T],
    vD[d, t] == ∑(vY_i_d[i, d, t] for i in i if (i, d) in d1Y) + ∑(vM_i_d[i, d, t] for i in i if (i, d) in d1M)

    pD[d = d, t = t1:T],
    pD[d, t] * qD[d, t] == vD[d, t]

    # -- IO price equations --
    pY_i_d[i = i, d = d, t = t1:T; (i, d) in d1Y],
    pY_i_d[i, d, t] == (1 + tY_i_d[i, d, t]) * pY_i_d_base[i, d, t]

    pM_i_d[i = i, d = d, t = t1:T; (i, d) in d1M],
    pM_i_d[i, d, t] == (1 + tM_i_d[i, d, t]) * pM_i_d_base[i, d, t]

    pY_i_d_base[i = i, d = d, t = t1:T; (i, d) in d1Y],
    pY_i_d_base[i, d, t] == (1 + jfpY_i_d[i, d, t]) / (1 + tY_i_d[i, d, tBase]) * pY_i[i, t]

    pM_i_d_base[i = i, d = d, t = t1:T; (i, d) in d1M],
    pM_i_d_base[i, d, t] == (1 + jfpM_i_d[i, d, t]) / (1 + tM_i_d[i, d, tBase]) * pM_i[i, t]

    # -- Quantity allocation --
    qY_i_d[i = i, d = d, t = t1:T; (i, d) in d1Y],
    qY_i_d[i, d, t] == (1 - rM[i, d, t]) * rYM[i, d, t] * qD[d, t]

    qM_i_d[i = i, d = d, t = t1:T; (i, d) in d1M],
    qM_i_d[i, d, t] == rM[i, d, t] * rYM[i, d, t] * qD[d, t]

    # -- Value identities at IO-cell level --
    vY_i_d[i = i, d = d, t = t1:T; (i, d) in d1Y],
    vY_i_d[i, d, t] == pY_i_d[i, d, t] * qY_i_d[i, d, t]

    vM_i_d[i = i, d = d, t = t1:T; (i, d) in d1M],
    vM_i_d[i, d, t] == pM_i_d[i, d, t] * qM_i_d[i, d, t]

    vY_i_d_base[i = i, d = d, t = t1:T; (i, d) in d1Y],
    vY_i_d_base[i, d, t] == pY_i_d_base[i, d, t] * qY_i_d[i, d, t]

    vM_i_d_base[i = i, d = d, t = t1:T; (i, d) in d1M],
    vM_i_d_base[i, d, t] == pM_i_d_base[i, d, t] * qM_i_d[i, d, t]
  end
end

# ==========================================================================
# Calibration
# ==========================================================================
function define_calibration()
  block = define_equations()

  # Tax rates only for cells with non-zero base values (rate is indeterminate when base is zero)
  tY_cal = [(i_v, d_v) for (i_v, d_v) in d1Y if something(db[vY_i_d_base[i_v, d_v, t1]], 0.0) > 1e-8]
  tM_cal = [(i_v, d_v) for (i_v, d_v) in d1M if something(db[vM_i_d_base[i_v, d_v, t1]], 0.0) > 1e-8]

  @endo_exo! block begin
    [tY_i_d[i, d, t1] for (i, d) in tY_cal], [vtY_i_d[i, d, t1] for (i, d) in tY_cal]
    [tM_i_d[i, d, t1] for (i, d) in tM_cal], [vtM_i_d[i, d, t1] for (i, d) in tM_cal]
    tY_i_sub[:, t1], vtY_i_Sub[:, t1]
    tY_i_tax[:, t1], vtY_i_Tax[:, t1]
    [rYM[i, d, t1] for (i, d) in d1YM], [((i, d) in d1Y ? qY_i_d[i, d, t1] : qM_i_d[i, d, t1]) for (i, d) in d1YM]
    [rM[i, d, t1] for (i, d) in d1Y ∩ d1M], [vM_i_d_base[i, d, t1] for (i, d) in d1Y ∩ d1M]
  end

  # Base-price continuity: p_base at t0 (= t1-1) equals p_base at t1
  block = block + @block db begin
    pY_i_d_base[i = i, d = d, t = (t1-1):(t1-1); (i, d) in d1Y],
    pY_i_d_base[i, d, t] == pY_i_d_base[i, d, t1]

    pM_i_d_base[i = i, d = d, t = (t1-1):(t1-1); (i, d) in d1M],
    pM_i_d_base[i, d, t] == pM_i_d_base[i, d, t1]
  end

  return block
end

# ==========================================================================
# Tests
# ==========================================================================
function run_tests(db)
  return nothing
end

end # module
