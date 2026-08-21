# Define capital stocks, investment, and the capital user cost.
# Split fixed investment across assets and input-output products.
# Normalize each capital leaf price in the calibration year.
# Exclude capital adjustment costs, which enter through a zero-cost hook.
module Capital

using SquareModels
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fp, fq
import ..InputOutput:
  industry,
  pPurchaserUse_p_u,
  qPurchaserUse_p_u_o_data,
  qPurchaserUse_p_u,
  qPurchaserUse_u,
  rProductShare,
  vI
import ..InputOutputSettings: cell_tolerance, origin
import ..Production: parent, pProd, qProd
import ..ProductionSettings:
  capital_type,
  production_data_dir,
  production_nesting
import ..Settings: calibration_year
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant, ForecastZero

# ============================================================================
# Checked-in data
# ============================================================================
const capital_file = joinpath(production_data_dir, "production_capital.csv")
const qK_k_i_data = read_cells(capital_file, "qK_k_i")
const vI_k_i_data = read_cells(capital_file, "vI_k_i")

# ============================================================================
# Cell masks and investment split
# ============================================================================
# A capital cell needs a positive current and lagged stock.
const capital_k_i = Set(
  (k, i)
  for ((k, i, year), value) in qK_k_i_data
  if year == calibration_year &&
    value > cell_tolerance &&
    get(qK_k_i_data, (k, i, calibration_year-1), 0.0) > cell_tolerance
)

# The input-output data give products but not capital types. Construction forms
# structures. Split all other products by investment net of construction.
const investment_product = sort(unique(
  p for (p, u, year) in keys(qPurchaserUse_p_u) if u == :K && year == t1
))
@assert :F in investment_product "Capital needs construction investment"
@assert :structures in capital_type "Construction needs a structures capital type"
const investment_product_k = Set(
  (p, k)
  for p in investment_product, k in capital_type
  if p != :F || k == :structures
)
const investment_product_quantity = Dict(
  p => sum(get(qPurchaserUse_p_u_o_data, (p, :K, o, calibration_year), 0.0) for o in origin)
  for p in investment_product
)
const nonconstruction_product_share = let
  total = sum(value for (p, value) in investment_product_quantity if p != :F)
  @assert total > cell_tolerance "Non-construction investment must be positive"
  Dict(
    p => value / total
    for (p, value) in investment_product_quantity if p != :F
  )
end

# ============================================================================
# Variables
# ============================================================================
const CapitalTag = Tag(:Capital)

@variables db.model :: (CapitalTag, GrowthAdjusted) begin
  qK_k_i[k = capital_type, i = industry, t = t; (k, i) in capital_k_i], "Capital stock by type and industry."
  qI_k_i[(k, i, t) = qK_k_i], "Capital flow by type and industry."
  qI_k[k = capital_type, t = t], "Investment by capital type."
  qI_p_k[p = investment_product, k = capital_type, t = t; (p, k) in investment_product_k], "Investment by product and capital type."
end

@variables db.model :: (CapitalTag, InflationAdjusted) begin
  pK_k_i[(k, i, t) = qK_k_i], "User cost of capital by type and industry."
  pI_k[k = capital_type, t = t], "Investment price by capital type."
  pMarginalCapitalTax_k_i[(k, i, t) = qK_k_i], "Marginal corporation tax per unit of capital."
  pCapitalAdjustment_k_i[(k, i, t) = qK_k_i] :: ForecastZero, "Added user cost from capital adjustment by type and industry."
end

@variables db.model :: (CapitalTag, GrowthAdjusted, InflationAdjusted) begin
  vI_k_i[(k, i, t) = qK_k_i], "Investment value by capital type and industry."
end

@variables db.model :: CapitalTag begin
  rKDepr_k_i[(k, i, t) = qK_k_i] :: ForecastConstant, "Capital depreciation rate by type and industry."
  rHurdleRate_i[i = industry, t = t] :: ForecastConstant, "Investment hurdle rate by industry."
  rInvestmentProductShare[(p, k, t) = qI_p_k] :: ForecastConstant, "Fixed product share by capital type."
end

# ============================================================================
# Data
# ============================================================================
function set_data!(db)
  @assert Set(
    (k, i)
    for k in capital_type, i in industry
    if haskey(parent, (k, i)) && !haskey(production_nesting[i], k)
  ) == capital_k_i "Capital data and the industry nest maps must agree"
  @assert Set(first.(capital_k_i)) == Set(capital_type) "Each capital type needs a live stock"
  @assert all(haskey(vI_k_i_data, (k, i, t1)) for (k, i) in capital_k_i) "Each capital stock needs calibration-year investment"
  @assert (:K, t1) in keys(qPurchaserUse_u) "Capital needs fixed investment purchaser use"

  fill_cells!(db, qK_k_i, qK_k_i_data)
  fill_cells!(db, vI_k_i, vI_k_i_data)
  db[[pProd[k, i, t1] for (k, i) in capital_k_i]] .= 1.0
  db[rHurdleRate_i] .= 0.2
  db[pMarginalCapitalTax_k_i] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
define_equations() = define_equations(t1:T)

function define_equations(investment_link_years)
  return @block db begin
    # One-year time to build. Installed stock sets the shadow price.
    pProd[(k, i, t) in keys(pProd); (k, i) in capital_k_i && t in t1:T],
    qProd[k, i, t] == pK_k_i[k, i, t1] * qK_k_i[k, i, t-1]/fq

    # User cost equals the shadow price in expectation. This sets lagged capital.
    qK_k_i[(k, i, t) in keys(qK_k_i); t in t1:(T-1)],
    pProd[k, i, t+1] == pK_k_i[k, i, t+1] / pK_k_i[k, i, t1]

    # Terminal condition
    qK_k_i[(k, i, t) in keys(qK_k_i); t == T && T > t1],
    qK_k_i[k, i, t] == qK_k_i[k, i, t-1]

    # Capital accumulation and the fixed-investment product split.
    qI_k_i[(k, i, t) in keys(qI_k_i); t in t1:T],
    qI_k_i[k, i, t] == qK_k_i[k, i, t] - (1 - rKDepr_k_i[k, i, t]) * qK_k_i[k, i, t-1]/fq

    qI_k[k = capital_type, t = t1:T],
    qI_k[k, t] == ∑(qI_k_i[k, i, t] for i in industry)

    # Construction forms structures in the calibration year.
    qI_p_k[(p, k, t) in keys(qI_p_k); p == :F && t == t1],
    qI_p_k[p, k, t] == qPurchaserUse_p_u[p, :K, t]

    # Split other products by investment net of construction.
    qI_p_k[(p, k, t) in keys(qI_p_k); p != :F && t == t1],
    qI_p_k[p, k, t] == nonconstruction_product_share[p] *
      (qI_k[k, t] - ∑(
        qI_p_k[pp, kk, t]
        for (pp, kk) in investment_product_k if pp == :F && kk == k
      ))

    # Hold each capital type's calibrated product mix fixed.
    qI_p_k[(p, k, t) in keys(qI_p_k); t in (t1+1):T], qI_p_k[p, k, t] == rInvestmentProductShare[p, k, t] * qI_k[k, t]

    rInvestmentProductShare[(p, k, t) in keys(rInvestmentProductShare); t == t1],
    rInvestmentProductShare[p, k, t] * qI_k[k, t] == qI_p_k[p, k, t]

    rProductShare[(p, u, t) in keys(rProductShare); u == :K && t in investment_link_years],
    qPurchaserUse_p_u[p, u, t] ==
      ∑(qI_p_k[p, k, t] for k in capital_type if (p, k) in investment_product_k)

    qPurchaserUse_u[u = [:K], t = investment_link_years],
    qPurchaserUse_u[u, t] == ∑(qI_k[k, t] for k in capital_type)

    pI_k[k = capital_type, t = t1:T],
    pI_k[k, t] * qI_k[k, t] ==
      ∑(
        pPurchaserUse_p_u[p, :K, t] * qI_p_k[p, k, t]
        for p in investment_product if (p, k) in investment_product_k
      )

    vI_k_i[(k, i, t) in keys(vI_k_i); t in t1:T], vI_k_i[k, i, t] == pI_k[k, t] * qI_k_i[k, i, t]

    # Capital user cost. The adjustment term stays zero without its module.
    pK_k_i[(k, i, t) in keys(pK_k_i); t in t1:(T-1)],
    pK_k_i[k, i, t] ==
      pI_k[k, t]
      + pMarginalCapitalTax_k_i[k, i, t]
      - ((1 - rKDepr_k_i[k, i, t+1]) /
        (1 + rHurdleRate_i[i, t+1]) *
        (pI_k[k, t+1] - pMarginalCapitalTax_k_i[k, i, t+1]) * fp)
      + pCapitalAdjustment_k_i[k, i, t]

    pK_k_i[(k, i, t) in keys(pK_k_i); t == T],
    pK_k_i[k, i, t] ==
      pI_k[k, t]
      + pMarginalCapitalTax_k_i[k, i, t]
      - ((1 - rKDepr_k_i[k, i, t]) /
        (1 + rHurdleRate_i[i, t]) *
        (pI_k[k, t] - pMarginalCapitalTax_k_i[k, i, t]) * fp)
      + pCapitalAdjustment_k_i[k, i, t]

    @test_constraint("Capital investment values sum to fixed investment"; rtol = 1e-3)
    vI[t = t1:T], vI[t] == ∑(vI_k_i[k, i, t] for k in capital_type, i in industry)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  # InputOutput calibrates the base-year product cells and use total. Capital
  # replaces those closures in later years and in the base model.
  block = define_equations((t1+1):T)

  @endo_exo_swap! block begin
    qProd[(k,i,t) in keys(qI_k_i); t == t1], pProd[(k,i,t) in keys(qI_k_i); t == t1]
    rKDepr_k_i[:,:,t1], vI_k_i[:,:,t1]
  end

  return block
end
end # module
