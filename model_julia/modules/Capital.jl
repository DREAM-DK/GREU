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
  product,
  pPurchaserUse_p_u,
  qI,
  qI_p,
  vI
import ..InputOutputSettings: cell_tolerance
import ..Production: pProd, qProd
import ..ProductionSettings:
  capital_type,
  production_data_dir
import ..Settings: calibration_year
import ..model
import ..Time: t, t1, T
import ..Tags: DynamicCalibration, ForecastConstant, ForecastZero

# ============================================================================
# Read data
# ============================================================================
const capital_file = joinpath(production_data_dir, "production_capital.csv")
const investment_product_split_file = joinpath(production_data_dir, "production_investment_product_split.csv")
const qK_k_i_data = read_cells(capital_file, "qK_k_i")
const qI_k_i_data = read_cells(capital_file, "qI_k_i")
const qI_p_k_data = read_cells(investment_product_split_file, "qI_p_k")
const qI_k_data = read_cells(investment_product_split_file, "qI_k")
const pI_k_data = read_cells(investment_product_split_file, "pI_k")

# ============================================================================
# Indices
# ============================================================================
# A capital cell needs a positive current and lagged stock.
const capital_k_i = Set(
  (k, i)
  for ((k,i,year), value) in qK_k_i_data
  if year == calibration_year &&
    value > cell_tolerance &&
    get(qK_k_i_data, (k,i,calibration_year-1), 0.0) > cell_tolerance
)

# The input-output data give products but not capital types. A separate table
# gives the product split for each capital type.
const investment_product_k = Set((p, k) for (p, k, _) in keys(qI_p_k_data))

# ============================================================================
# Variables
# ============================================================================
const CapitalTag = Tag(:Capital)

@variables model :: (CapitalTag, GrowthAdjusted) begin
  qK_k_i[k=capital_type, i=industry, t=t; (k,i) in capital_k_i], "Capital stock by type and industry."
  qI_k_i[(k,i,t)=qK_k_i], "Capital flow by type and industry."
  qI_k[k=capital_type, t=t], "Investment by capital type."
  qI_p_k[p=product, k=capital_type, t=t; (p,k) in investment_product_k], "Investment by product and capital type."
end

@variables model :: (CapitalTag, InflationAdjusted) begin
  pK_k_i[(k,i,t)=qK_k_i], "User cost of capital by type and industry."
  pI_k[k=capital_type, t=t], "Investment price by capital type."
  tK_k_i[(k,i,t)=qK_k_i] :: ForecastConstant, "Production tax less subsidy per unit of capital stock."
  pMarginalCapitalTax_k_i[(k,i,t)=qK_k_i], "Marginal corporation tax per unit of capital."
  pKAdjCost_k_i[(k,i,t)=qK_k_i] :: (ForecastZero, DynamicCalibration), "Added user cost from capital adjustment by type and industry."
  pInvestmentShock_k_i[(k,i,t)=qK_k_i] :: (ForecastZero, DynamicCalibration), "Shock that increases investment by type and industry."
end

@variables model :: (CapitalTag, GrowthAdjusted, InflationAdjusted) begin
  vI_k_i[(k,i,t)=qK_k_i], "Investment value by capital type and industry."
end

@variables model :: CapitalTag begin
  rKDepr_k_i[(k,i,t)=qK_k_i] :: ForecastConstant, "Capital depreciation rate by type and industry."
  rHurdleRate_i[i=industry, t=t] :: ForecastConstant, "Investment hurdle rate by industry."
  rInvestmentProductShare[(p,k,t)=qI_p_k] :: ForecastConstant, "Fixed product share by capital type."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, qK_k_i, qK_k_i_data)
  fill_cells!(db, qI_k_i, qI_k_i_data)
  fill_cells!(db, qI_p_k, qI_p_k_data)
  fill_cells!(db, qI_k, qI_k_data)
  fill_cells!(db, pI_k, pI_k_data)
  db[[pProd[k,i,t1] for (k,i) in capital_k_i]] .= 1.0
  # A perceived cost of capital, so it covers debt as well as equity finance.
  db[rHurdleRate_i] .= 0.10
  db[pMarginalCapitalTax_k_i] .= 0.0
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[qProd[capital_type,:,:]] .= start_values[qK_k_i][capital_type,:,:]
  start_values[tK_k_i] .= 0
  start_values[pKAdjCost_k_i] .= 0
  start_values[pInvestmentShock_k_i] .= 0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # One-year time to build. Installed stock sets the shadow price.
    pProd[k=capital_type, i=industry, t=t1:T], qProd[k,i,t] == pK_k_i[k,i,t1] * qK_k_i[k,i,t-1]/fq

    # Expected user cost sets lagged capital. A positive shock raises investment.
    qK_k_i[k=capital_type, i=industry, t=t1:(T-1)],
    pProd[k,i,t+1] * pK_k_i[k,i,t1] == pK_k_i[k,i,t+1] - pInvestmentShock_k_i[k,i,t+1]

    # Terminal condition
    qK_k_i[k=capital_type, i=industry, t=T; T > t1], qK_k_i[k,i,t] == qK_k_i[k,i,t-1]

    # Capital accumulation
    qI_k_i[k=capital_type, i=industry, t=t1:T],
    qI_k_i[k,i,t] == qK_k_i[k,i,t] - (1 - rKDepr_k_i[k,i,t]) * qK_k_i[k,i,t-1]/fq

    qI_k[k=capital_type, t=t1:T], qI_k[k,t] == ∑(qI_k_i[k,i,t] for i in industry)

    # Product split.
    qI_p_k[p=product, k=capital_type, t=t1:T], qI_p_k[p,k,t] == rInvestmentProductShare[p,k,t] * qI_k[k,t]

    qI_p[(p,t) in keys(qI_p); t in t1:T], qI_p[p,t] == ∑(qI_p_k[p,k,t] for k in capital_type)

    qI[t=t1:T], qI[t] == ∑(qI_k[k,t] for k in capital_type)

    pI_k[k=capital_type, t=t1:T], pI_k[k,t] * qI_k[k,t] == ∑(pPurchaserUse_p_u[p,:K,t] * qI_p_k[p,k,t] for p in product)

    vI_k_i[k=capital_type, i=industry, t=t1:T], vI_k_i[k,i,t] == pI_k[k,t] * qI_k_i[k,i,t]

    # Lagged investment sets the user cost of capital installed for this period.
    pK_k_i[k=capital_type, i=industry, t=t1:T],
    pK_k_i[k,i,t] == pI_k[k,t-1] + pMarginalCapitalTax_k_i[k,i,t-1]
      - (1 - rKDepr_k_i[k,i,t]) / (1 + rHurdleRate_i[i,t]) * (pI_k[k,t]*fp - pMarginalCapitalTax_k_i[k,i,t]*fp)
      + tK_k_i[k,i,t]
      + pKAdjCost_k_i[k,i,t]

    @test_constraint("Capital investment values sum to fixed investment"; rtol = 1e-3)
    vI[t=t1:T], vI[t] == ∑(vI_k_i[k,i,t] for k in capital_type, i in industry)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qProd[k=capital_type, i=industry, t=t1], pProd[k=capital_type, i=industry, t=t1]
    rKDepr_k_i[:,:,t1], qI_k_i[:,:,t1]

    rInvestmentProductShare[p=product, k=capital_type, t=t1], qI_p_k[p=product, k=capital_type, t=t1]

    pInvestmentShock_k_i[k=capital_type, i=industry, t=t1+1; T > t1],
    qK_k_i[k=capital_type, i=industry, t=t1; T > t1]
  end

  return block
end
end # module
