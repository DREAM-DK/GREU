# Set basic output prices from marginal cost and one markup per industry.
# Take the marginal markup as given and calibrate the fixed cost of Production.
# Hold the fixed cost exogenous in a shock, so it changes no marginal decision.
# Leave product-specific costs to a later CET module.
module Pricing

using SquareModels
import ..InputOutput: industry, pY_i, pY_p_i
import ..IndustrySectors: uIndustrySector_s_i_data
import ..Production: pMarginalCost_i, qFixedCost_i
import ..Settings: calibration_year
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# The accounts report one cost per industry and cannot separate the marginal
# markup from the fixed cost. This assumption sets the markup. The fixed cost of
# each industry then takes the rest of the gap between price and unit cost.
const marginal_markup = 0.20
const mostly_public_industry = sort([
  i for i in industry if uIndustrySector_s_i_data[:Gov,i,calibration_year] > 0.5
])

# ============================================================================
# Variables
# ============================================================================
const PricingTag = Tag(:Pricing)

@variables model :: PricingTag begin
  rMarkup_i[i=industry, t=t] :: ForecastConstant, "Marginal markup rate by industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[rMarkup_i] .= marginal_markup
  db[rMarkup_i[mostly_public_industry,:]] .= 0.0
  db[pY_i[:,t1]] .= 1.0
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    pY_p_i[(p,i,t) in keys(pY_p_i); t in t1:T],
    pY_p_i[p,i,t] == pY_i[i,t]

    pY_i[i=industry, t=t1:T],
    pY_i[i,t] == (1 + rMarkup_i[i,t]) * pMarginalCost_i[i,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    pMarginalCost_i[:,t1], pY_i[:,t1]
  end

  return block
end

end # module
