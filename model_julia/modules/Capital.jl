# Define capital stocks, investment, and the capital user cost.
# Split fixed investment across assets and input-output products.
# Normalize each capital leaf price in the calibration year.
# Exclude capital adjustment costs, which enter through a zero-cost hook.
module Capital

using SquareModels
import ..CheckedData: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fp, fq
import ..InputOutput:
  pPurchaserUse_p_u,
  qPurchaserUse_p_u,
  qPurchaserUse_p_u_o_data,
  qPurchaserUse_u,
  rProductShare,
  vI
import ..InputOutputSettings: cell_tolerance, industry, origin
import ..Production: parent, pProd, qProd, top_i
import ..ProductionSettings:
  capital_type,
  investment_product_capital_weight,
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
const qI_k_i_data = read_cells(capital_file, "qI_k_i")

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

# The input-output data give products but not capital types. Allocate each
# product with fixed weights, then get its share for each capital type.
const investment_product = sort(unique(
  p for (p, u, year) in keys(qPurchaserUse_p_u) if u == :K && year == t1
))
const qInvestment_p = Dict(
  p => sum(get(qPurchaserUse_p_u_o_data, (p, :K, o, calibration_year), 0.0) for o in origin)
  for p in investment_product
)
const qCapitalFlow_k = Dict(
  k => sum(qI_k_i_data[(k, i, calibration_year)] for (kk, i) in capital_k_i if kk == k)
  for k in capital_type
)
@assert all(>(cell_tolerance), values(qCapitalFlow_k)) "Each capital type needs positive investment"
@assert all(
  sum(investment_product_capital_weight[p, k] * qCapitalFlow_k[k] for k in capital_type) > cell_tolerance
  for p in investment_product
) "Each investment product needs a positive capital-allocation weight"

const qInvestment_p_k = Dict(
  (p, k) => qInvestment_p[p] *
    investment_product_capital_weight[p, k] * qCapitalFlow_k[k] /
    sum(investment_product_capital_weight[p, kk] * qCapitalFlow_k[kk] for kk in capital_type)
  for p in investment_product, k in capital_type
  if investment_product_capital_weight[p, k] > 0
)
const investment_product_k = Set(keys(qInvestment_p_k))
const rInvestmentProductShare_p_k_data = Dict(
  (p, k) => value / sum(v for ((_, kk), v) in qInvestment_p_k if kk == k)
  for ((p, k), value) in qInvestment_p_k
)
const rInvestmentScale_k_data = Dict(
  k => sum(v for ((_, kk), v) in qInvestment_p_k if kk == k) / qCapitalFlow_k[k]
  for k in capital_type
)

# ============================================================================
# Variables
# ============================================================================
const CapitalTag = Tag(:Capital)

@variables db.model :: (CapitalTag, GrowthAdjusted) begin
  qK_k_i[k = capital_type, i = industry, t = t; (k, i) in capital_k_i], "Capital stock by type and industry."
  qI_k_i[(k, i, t) = qK_k_i], "Capital flow by type and industry."
  qI_k[k = capital_type, t = t], "Investment by capital type in purchaser units."
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
  rHurdleRate_i[i = industry, t = t; haskey(top_i, i)] :: ForecastConstant, "Investment hurdle rate by industry."
  rInvestmentScale_k[k = capital_type, t = t] :: ForecastConstant, "Purchaser investment units per capital-flow unit by type."
  rInvestmentProductShare_p_k[(p, k, t) = qI_p_k] :: ForecastConstant, "Fixed product share by capital type."
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
  @assert all(haskey(qI_k_i_data, (k, i, t1)) for (k, i) in capital_k_i) "Each capital stock needs calibration-year investment"
  @assert (:K, t1) in keys(qPurchaserUse_u) "Capital needs fixed investment purchaser use"

  fill_cells!(db, qK_k_i, qK_k_i_data)
  fill_cells!(db, qI_k_i, qI_k_i_data)
  db[rHurdleRate_i] .= 0.2
  db[pMarginalCapitalTax_k_i] .= 0.0
  db[rInvestmentScale_k] .= [
    year == t1 ? rInvestmentScale_k_data[k] : nothing
    for k in capital_type, year in t
  ]
  db[rInvestmentProductShare_p_k] .= [
    year == t1 ? rInvestmentProductShare_p_k_data[p, k] : nothing
    for (p, k, year) in keys(rInvestmentProductShare_p_k)
  ]
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

    qK_k_i[(k, i, t) in keys(qK_k_i); t == T && T > t1],
    qK_k_i[k, i, t] == qK_k_i[k, i, t-1]

    # Capital accumulation and the fixed-investment product split.
    qI_k_i[(k, i, t) in keys(qI_k_i); t in t1:T],
    qI_k_i[k, i, t] ==
      qK_k_i[k, i, t]
      - ((1 - rKDepr_k_i[k, i, t]) * qK_k_i[k, i, t-1]/fq)

    qI_k[k = capital_type, t = t1:T],
    qI_k[k, t] ==
      rInvestmentScale_k[k, t] *
      ∑(qI_k_i[k, i, t] for i in industry if (k, i) in capital_k_i)

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
    vI_k_i[k, i, t] == pI_k[k, t] * rInvestmentScale_k[k, t] * qI_k_i[k, i, t]

    # Capital user cost. The adjustment term stays zero without its module.
    pK_k_i[(k, i, t) in keys(pK_k_i); t in t1:(T-1)],
    pK_k_i[k, i, t] ==
      pI_k[k, t] * rInvestmentScale_k[k, t]
      + pMarginalCapitalTax_k_i[k, i, t]
      - ((1 - rKDepr_k_i[k, i, t+1]) /
        (1 + rHurdleRate_i[i, t+1]) *
        (pI_k[k, t+1] * rInvestmentScale_k[k, t+1] - pMarginalCapitalTax_k_i[k, i, t+1]) * fp)
      + pCapitalAdjustment_k_i[k, i, t]

    pK_k_i[(k, i, t) in keys(pK_k_i); t == T],
    pK_k_i[k, i, t] ==
      pI_k[k, t] * rInvestmentScale_k[k, t]
      + pMarginalCapitalTax_k_i[k, i, t]
      - ((1 - rKDepr_k_i[k, i, t]) /
        (1 + rHurdleRate_i[i, t]) *
        (pI_k[k, t] * rInvestmentScale_k[k, t] - pMarginalCapitalTax_k_i[k, i, t]) * fp)
      + pCapitalAdjustment_k_i[k, i, t]

    @test_constraint("Capital investment values sum to fixed investment"; rtol = 1e-3)
    vI[t = t1:T], vI[t] == ∑(vI_k_i[k, i, t] for (k, i) in capital_k_i)
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
    rKDepr_k_i[:,:,t1], qI_k_i[:,:,t1]
  end

  return block
end
end # module
