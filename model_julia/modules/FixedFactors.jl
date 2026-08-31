# Define one fixed production factor for land, resources, and zoning limits.
# Hold its supply fixed and solve its normalized production shadow price.
# Link the asset price to the expected user cost after the first period.
# Normalize quantity with the calibration-year user cost, as for capital.
module FixedFactors

using SquareModels
import ..Capital: rHurdleRate_i
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fp
import ..InputOutput: industry
import ..Production: pProd, qProd
import ..ProductionSettings: fixed_factor_type
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Indices
# ============================================================================
const fixed_factor = only(fixed_factor_type)

# ============================================================================
# Variables
# ============================================================================
const FixedFactorsTag = Tag(:FixedFactors)

@variables model :: (FixedFactorsTag, GrowthAdjusted) begin
  qFixedFactor_i[i=industry, t=t] :: ForecastConstant, "Fixed factor supply by industry."
end

@variables model :: (FixedFactorsTag, InflationAdjusted) begin
  pFixedFactor_i[i=industry, t=t], "Asset price of the fixed factor by industry."
  pFixedFactorUserCost_i[i=industry, t=t], "User cost of the fixed factor by industry."
  tFixedFactor_i[i=industry, t=t] :: ForecastConstant, "Production tax less subsidy per unit of fixed factor."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[qFixedFactor_i] .= 1.0
  db[tFixedFactor_i] .= 0.0
  db[pFixedFactor_i[:,t1-1]] .= 1.0
  db[pProd[fixed_factor,:,t1]] .= 1.0
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[qProd[fixed_factor,:,:]] .= start_values[qFixedFactor_i]
  start_values[pFixedFactor_i] .= 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Fixed supply sets the normalized production shadow price.
    pProd[f=[fixed_factor], i=industry, t=t1:T],
    qProd[f,i,t] == pFixedFactorUserCost_i[i,t1] * qFixedFactor_i[i,t]

    # The asset price, its expected change, and production tax set user cost.
    pFixedFactorUserCost_i[i=industry, t=t1:T],
    pFixedFactorUserCost_i[i,t] == pFixedFactor_i[i,t-1]/fp
      - pFixedFactor_i[i,t] / (1 + rHurdleRate_i[i,t])
      + tFixedFactor_i[i,t]

    # New information can change the first shadow price. Later normalized prices satisfy arbitrage.
    pFixedFactor_i[i=industry, t=t1:(T-1); T > t1],
    pProd[fixed_factor,i,t+1] * pFixedFactorUserCost_i[i,t1] == pFixedFactorUserCost_i[i,t+1]

    # Use a flat adjusted asset price as the terminal condition.
    pFixedFactor_i[i=industry, t=[T]; T > t1], pFixedFactor_i[i,t] == pFixedFactor_i[i,t-1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qProd[f=[fixed_factor], i=industry, t=[t1]], pProd[f=[fixed_factor], i=industry, t=[t1]]
  end

  return block
end
end # module
