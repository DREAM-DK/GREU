# Set output prices from marginal cost and one markup per industry.
# Use the same industry price for each product that the industry supplies.
module Pricing

using SquareModels
import ..InputOutput: industry, pY_i
import ..Production: pMarginalCost_i, qFixedCost_i
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant, DynamicCalibration

# ============================================================================
# Variables
# ============================================================================
const PricingTag = Tag(:Pricing)

@variables model :: PricingTag begin
  rMarkup_i[i=industry, t=t] :: (ForecastConstant, DynamicCalibration), "Marginal markup rate by industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
# The dynamic calibration reads the static markup here and uses it as its exogenous
# value. A price below unit cost gives a negative markup, which we take to zero.
function set_starting_values!(start_values)
  markup = start_values[rMarkup_i[:,t1]]
  markup .= [isnothing(rate) ? rate : max(rate, 0.0) for rate in markup]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    pY_i[i=industry, t=t1:T],
    pY_i[i,t] == (1 + rMarkup_i[i,t]) * pMarginalCost_i[i,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  if T == t1
    @endo_exo_swap! block begin
      rMarkup_i[:,t1], pY_i[:,t1]
    end
  end

  if T > t1
    @endo_exo_swap! block begin
      pMarginalCost_i[:,t1], pY_i[:,t1]
    end
  end

  return block
end

end # module
