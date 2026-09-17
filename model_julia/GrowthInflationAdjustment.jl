# Adjust variables to make the model roughly stationary.
# A constant adjusted price means that the raw price grows at the long-run rate.
# p[t] ≡ p̂[t] / (1+gp)^(t-base_year)
# q[t] ≡ q̂[t] / (1+gq)^(t-base_year)
# v[t] ≡ v̂[t] / [(1+gp)(1+gq)]^(t-base_year)
# Hats mark raw values. Model output stays adjusted.
module GrowthInflationAdjustment

import JuMP: all_variables
import SquareModels: ModelDictionary, Tag, has_tag
import ..Time: tBase, variable_year

# ============================================================================
# Factors and tags
# ============================================================================
const gq = 0.01 # Long-run real growth rate.
const gp = 0.02 # Long-run inflation rate.
const fq = 1 + gq # Quantity growth factor.
const fp = 1 + gp # Price growth factor.
const fv = fq * fp # Value growth factor.

const GrowthAdjusted = Tag(:growth_adjusted)
const InflationAdjusted = Tag(:inflation_adjusted)

# ============================================================================
# Data adjustment
# ============================================================================
adjustment_factor(var, year) =
  (has_tag(var, GrowthAdjusted) ? fq^(year-tBase) : 1.0) *
  (has_tag(var, InflationAdjusted) ? fp^(year-tBase) : 1.0)

"""Adjust all assigned source values from raw units to stationary model units."""
function adjust_growth_inflation!(db::ModelDictionary)
  adjusted_variables = filter(all_variables(db.model)) do var
    !isnothing(db[var]) &&
      !isnothing(variable_year(var)) &&
      (has_tag(var, GrowthAdjusted) || has_tag(var, InflationAdjusted))
  end
  years = variable_year.(adjusted_variables)
  db[adjusted_variables] .= db[adjusted_variables] ./ adjustment_factor.(adjusted_variables, years)
  @assert all(isfinite(db[var]) for var in adjusted_variables) "Adjusted source values must be finite"
  return db
end

end # module
