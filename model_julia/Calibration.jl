# Build and solve one calibration horizon.
# Set exogenous forecast values and solver start values.
# Do not run checks or write output files.
module Calibration

using SquareModels

import ..Tags: ForecastConstant, ForecastZero
import ..Time: at_year, variable_year, t1

# ============================================================================
# Residual settings
# ============================================================================

function residual_tolerances(values::ModelDictionary, modules)
  tolerances = ModelDictionary(values.model)
  for m in modules
    isdefined(m, :set_residual_tolerances!) && m.set_residual_tolerances!(tolerances)
  end
  return tolerances
end

"""
For calibration: fix endogenous variables that have exogenous values and solve their residuals.
The values can come from a source or an earlier calibration. Equations calculate model totals
from source cells. If the source also reports a total, load it and let its residual record the gap.

Parameters should already have been swapped for source values in `define_calibration`. This
step covers the remaining endogenous variables that have exogenous values.

The @block macro transforms each equation `endo[t] == RHS` into `(endo[t] + endo_J[t]) == RHS`,
where `endo_J` is the residual. Swapping solves endo_J and fixes endo at its exogenous value.
"""
function endo_exo_residuals!(block::Block, exogenous_values::ModelDictionary)
  has_exogenous_value(endo) =
    !isnothing(exogenous_values[endo]) &&
    (isnothing(variable_year(endo)) || variable_year(endo) <= t1)
  pairs = [
    (resid, endo)
    for (endo, resid) in zip(endogenous(block), residuals(block))
    if has_exogenous_value(endo)
  ]
  SquareModels._endo_exo_swap!(block, first.(pairs), last.(pairs), "endo_exo_residuals!")
end

# ============================================================================
# Forecast setup
# ============================================================================

"""
Handle ForecastConstant-tagged variables for calibration.

For endogenous variables at t > t1: create equations var[t] == var[t1]
For exogenous variables at t > t1: copy the t1 exogenous value.

Returns a Block with forecast constraints (to be merged with the main block).
"""
function forecast_constants!(block::Block, exogenous_values::ModelDictionary)
  forecast_block = Block(block.model)

  for var in variables(block)
    has_tag(var, ForecastConstant) || continue
    var_t1 = at_year(var, t1)
    var_t1 == var && continue  # Already at t1, no forecast needed.

    if is_endogenous(var_t1, block)
      add_equation!(forecast_block, var, var, var_t1)
    else
      exogenous_values[var] = exogenous_values[var_t1]
    end
  end

  for resid in residuals(forecast_block)
    exogenous_values[resid] = 0.0
  end

  return block + forecast_block
end

"""
Set ForecastZero variables to zero when the full model leaves them exogenous.

An optional module can make a zero hook endogenous and add its equation. In
that case, this function does not add an exogenous value that fixes the hook at zero.
"""
function forecast_zeros!(block::Block, exogenous_values::ModelDictionary)
  zero_vars = filter(exogenous(block)) do var
    has_tag(var, ForecastZero)
  end
  exogenous_values[zero_vars] .= 0.0
  return nothing
end

"""
Fill missing future exogenous values with the period-one start value.

This is the default for exogenous variables without a forecast rule. It also supports
smaller model setups: if an omitted module would make a variable endogenous, the
active model keeps that variable at its period-one value. It does not overwrite
forecast values set by a module or a source.
"""
function fill_missing_exogenous_forecasts!(
  block::Block,
  exogenous_values::ModelDictionary,
  start_values::ModelDictionary,
)
  forecast_vars = filter(exogenous(block)) do var
    year = variable_year(var)
    !isnothing(year) && year > t1 && isnothing(exogenous_values[var])
  end
  exogenous_values[forecast_vars] .= start_values[at_year.(forecast_vars, t1)]
  return nothing
end

"""
Use start values for missing exogenous values at t1.

The same value stays a solver hot start when the combined block makes the
variable endogenous. Values before t1 and values without a year must be exogenous.
"""
function fill_missing_t1_exogenous_start_values!(
  block::Block,
  exogenous_values::ModelDictionary,
  start_values::ModelDictionary,
)
  vars = filter(exogenous(block)) do var
    variable_year(var) == t1 && isnothing(exogenous_values[var]) && !isnothing(start_values[var])
  end
  exogenous_values[vars] .= start_values[vars]
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
"""
Call the set_starting_values! function of each module.
"""
function set_starting_values!(start_values::ModelDictionary, modules)
  for m in modules
    isdefined(m, :set_starting_values!) && m.set_starting_values!(start_values)
  end
  return nothing
end

"""
Fill missing future endogenous start values with the period-one value.

These values are solver hints. They do not make the variables exogenous. Values set
by a module take precedence over this fallback.
"""
function fill_missing_endogenous_start_values!(block::Block, start_values::ModelDictionary)
  forecast_vars = filter(endogenous(block)) do var
    year = variable_year(var)
    !isnothing(year) && year > t1 && isnothing(start_values[var])
  end
  start_values[forecast_vars] .= start_values[at_year.(forecast_vars, t1)]
  return nothing
end


end # module
