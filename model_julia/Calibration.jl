# Build and solve one calibration horizon.
# Set forecast data and solver start values.
# Do not run checks or write output files.
module Calibration

using SquareModels

import ..Log: @log_time
import ..Tags: ForecastConstant, ForecastZero
import ..Time: at_year, variable_year, t1, T

# ============================================================================
# Residual settings
# ============================================================================

function residual_tolerances(data::ModelDictionary, submodels)
  tolerances = ModelDictionary(data.model)
  for m in submodels
    isdefined(m, :set_residual_tolerances!) && m.set_residual_tolerances!(tolerances)
  end
  return tolerances
end

"""
For calibration: exogenize endogenous variables that have data and endogenize their residuals.
This includes only values read from a source. Equations calculate model totals from source
cells. If the source also reports a total, load it and let its residual record the gap.

Parameters should already have been swapped for data in `define_calibration`. This step
covers remaining endogenous variables that have data.

The @block macro transforms each equation `endo[t] == RHS` into `(endo[t] + endo_J[t]) == RHS`,
where `endo_J` is the residual. Swapping makes endo_J endogenous while endo stays at its data value.
"""
function endo_exo_data_residuals!(block::Block, data::ModelDictionary)
  has_data(endo) = !isnothing(data[endo]) && (isnothing(variable_year(endo)) || variable_year(endo) <= t1)
  pairs = [(resid, endo) for (endo, resid) in zip(endogenous(block), residuals(block)) if has_data(endo)]
  SquareModels._endo_exo_swap!(block, first.(pairs), last.(pairs), "endo_exo_data_residuals!")
end

# ============================================================================
# Forecast setup
# ============================================================================

"""
Handle ForecastConstant-tagged variables for calibration.

For endogenous variables at t > t1: create equations var[t] == var[t1]
For exogenous variables at t > t1: copy the t1 value in the data.

Returns a Block with forecast constraints (to be merged with the main block).
"""
function forecast_constants!(block::Block, data::ModelDictionary)
  forecast_block = Block(block.model)

  for var in variables(block)
    has_tag(var, ForecastConstant) || continue
    var_t1 = at_year(var, t1)
    var_t1 == var && continue  # Already at t1, no forecast needed.

    if is_endogenous(var_t1, block)
      add_equation!(forecast_block, var, var, var_t1)
    else
      data[var] = data[var_t1]  # Copy the exogenous calibration value.
    end
  end

  for resid in residuals(forecast_block)
    data[resid] = 0.0
  end

  return block + forecast_block
end

"""
Set ForecastZero variables to zero when the full model leaves them exogenous.

An optional module can make a zero hook endogenous and add its equation. In
that case, this function does not add data that would fix the hook at zero.
"""
function forecast_zeros!(block::Block, data::ModelDictionary)
  zero_vars = filter(exogenous(block)) do var
    has_tag(var, ForecastZero)
  end
  data[zero_vars] .= 0.0
  return nothing
end

"""
Fill missing future exogenous data with the period-one calibration value.

This is the default for exogenous variables without a forecast rule. It also supports
smaller model setups: if an omitted module would make a variable endogenous, the
active model keeps that variable at its period-one value. It does not overwrite
forecast data set by a module or a source.
"""
function fill_missing_exogenous_forecasts!(block::Block, data::ModelDictionary, calibration::ModelDictionary)
  forecast_vars = filter(exogenous(block)) do var
    year = variable_year(var)
    !isnothing(year) && year > t1 && isnothing(data[var])
  end
  data[forecast_vars] .= calibration[at_year.(forecast_vars, t1)]
  return nothing
end

"""
Use hot starts for missing exogenous values at t1.

The same value stays a solver hot start when the combined block makes the
variable endogenous. Values before t1 and values without a year need data.
"""
function fill_missing_t1_exogenous_start_values!(block::Block, data::ModelDictionary, start_values::ModelDictionary)
  vars = filter(exogenous(block)) do var
    variable_year(var) == t1 && isnothing(data[var]) && !isnothing(start_values[var])
  end
  data[vars] .= start_values[vars]
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

# ============================================================================
# Solve
# ============================================================================

function calibrate_model(data, start_values, submodels)
  @info "Calibration (T=$T):"
  @log_time block = sum(m.define_calibration() for m in submodels)
  @log_time forecast_zeros!(block, data)
  @log_time block = forecast_constants!(block, data)
  @log_time endo_exo_data_residuals!(block, data)
  for m in submodels
    isdefined(m, :set_starting_values!) && m.set_starting_values!(start_values)
  end
  @log_time fill_missing_t1_exogenous_start_values!(block, data, start_values)
  @log_time fill_missing_exogenous_forecasts!(block, data, start_values)
  @log_time fill_missing_endogenous_start_values!(block, start_values)
  return @log_time solve(block, data; start_values, replace_nothing=1.0)
end

end # module
