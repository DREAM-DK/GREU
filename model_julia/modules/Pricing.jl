# Set basic output prices from unit cost and one markup per industry.
# Use the same unit cost for each product in the default production split.
# Leave product-specific costs to a later CET module.
module Pricing

using SquareModels
import ..InputOutput: industry, pY_p_i
import ..InputOutputSettings: product, section_to_industry
import ..Production: pY0
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const PricingTag = Tag(:Pricing)

@variables model :: PricingTag begin
  rMarkup_i[i=industry, t=t] :: ForecastConstant, "Markup rate by industry."
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
function set_starting_values!(start_values)
  start_values[rMarkup_i] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    pY_p_i[(p,i,t) in keys(pY_p_i); t in t1:T], pY_p_i[p,i,t] == (1 + rMarkup_i[i,t]) * pY0[i,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # The matching CPA product identifies the common markup for each NACE industry.
  @endo_exo_swap! block begin
    rMarkup_i[i=industry, t=[t1]],
    pY_p_i[p=product, i=industry, t=[t1]; section_to_industry[p] == i]
  end

  return block
end

end # module
