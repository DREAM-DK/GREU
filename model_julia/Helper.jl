# Helper functions used by Calibrate.jl.
using SquareModels

import GREU: Settings, Time
import GREU.Log: @log_time
import GREU.Calibration:
  set_starting_values!,
  endo_exo_residuals!,
  forecast_zeros!,
  forecast_constants!,
  fill_missing_t1_exogenous_start_values!,
  fill_missing_exogenous_forecasts!,
  extend_start_values!,
  fill_missing_endogenous_start_values!
import GREU.Time: variable_year
import GREU.Tags: DynamicCalibration

# ============================================================================
# Static calibration
# ============================================================================
function static_calibration(data, base_block)
  Time.T = Settings.calibration_year
  exogenous_values, start_values = copy(data), copy(data)
  static_calibration_block = sum([m.define_calibration() for m in model_modules]);
  static_calibrated_parameters = filter(var -> !has_tag(var, DynamicCalibration), setdiff(endogenous(static_calibration_block), endogenous(base_block)))

  forecast_zeros!(static_calibration_block, exogenous_values)
  endo_exo_residuals!(static_calibration_block, exogenous_values)
  set_starting_values!(start_values, loaded_modules)
  fill_missing_t1_exogenous_start_values!(static_calibration_block, exogenous_values, start_values)

  @log_time static_solution = solve(static_calibration_block, exogenous_values; start_values, replace_nothing=1.0)
  return static_solution, static_calibrated_parameters
end

# ============================================================================
# Dynamic calibration
# ============================================================================
"""
Solve the dynamic calibration.

- Default: one solve over the full horizon, starting from the static solution.
- `step=5`: solve in stages that end every 5 years, each starting from the previous stage.
- `previous_solution`: start from an earlier baseline instead of the static solution.
"""
function dynamic_calibration(data, static_solution, static_calibrated_parameters;
                             base_blocks=nothing, previous_solution=nothing, step=nothing)
  t0 = Settings.calibration_year
  horizons = isnothing(step) ? [Time.max_terminal_year] :
    unique([(t0+step):step:Time.max_terminal_year..., Time.max_terminal_year])

  baseline = static_solution
  for (solved_through, terminal_year) in zip([t0; horizons], horizons)
    Time.T = terminal_year
    # The prebuilt base blocks cover the full horizon only.
    block = isnothing(base_blocks) || terminal_year != Time.max_terminal_year ?
      sum([m.define_calibration() for m in model_modules]) :
      sum([m.define_calibration(b) for (m, b) in zip(model_modules, base_blocks)])
    exogenous_values, start_values = copy(data), copy(baseline)

    exogenous_values[static_calibrated_parameters] .= static_solution[static_calibrated_parameters]
    forecast_zeros!(block, exogenous_values)
    endo_exo_residuals!(block, exogenous_values)
    set_starting_values!(start_values, loaded_modules)
    fill_missing_t1_exogenous_start_values!(block, exogenous_values, start_values)
    block = forecast_constants!(block, exogenous_values)
    fill_missing_exogenous_forecasts!(block, exogenous_values, start_values, setdiff(loaded_modules, model_modules))

    if isnothing(previous_solution)
      # Start the new years at the last solved year (flat in growth- and inflation-adjusted terms).
      extend_start_values!(block, start_values, solved_through)
      set_forecast_start_values!(block, start_values, solved_through)
    else
      previous_solution_vars = filter(variables(block)) do var
        year = variable_year(var)
        !isnothing(year) && year > Time.t1 && !isnothing(previous_solution[var])
      end
      start_values[previous_solution_vars] .= previous_solution[previous_solution_vars]
    end

    fill_missing_endogenous_start_values!(block, start_values)
    baseline = @log_time "dynamic calibration through $terminal_year" solve(block, exogenous_values; start_values, replace_nothing=1.0)
  end

  return baseline
end

# ============================================================================
# Forecast start values
# ============================================================================
import JuMP
import GREU.GrowthInflationAdjustment: fq, fv

# Flows that the forecast rules set to zero. 2019 has one-off revaluations and volume changes.
const zero_start_variables = Set([
  "vFinReval_s_f", "rFinReval_s_f", "rFinReval_f", "vNetFinReval",
  "vOtherChangesInVolume_f", "vNetOtherChangesInVolume",
])
# Inventory changes halve each year in the forecast.
const fading_start_variables = Set(["vINV", "qINV", "vINV_s"])
is_inventory_cell(name) = occursin(r"[\[,]INV,", name)

"""
Improve flat start values for forecast years where the static solution is far from the
forecast path: zero for one-off financial flows, a fading path for inventories, trend wage
inflation, and investment that keeps each capital stock flat.
"""
function set_forecast_start_values!(block, start_values, t0)
  model = block.model
  for v in variables(block)
    year = variable_year(v)
    (isnothing(year) || year <= t0) && continue
    name = JuMP.name(v)
    base = first(split(name, '['))
    if base in zero_start_variables
      start_values[v] = 0.0
    elseif base in fading_start_variables || is_inventory_cell(name)
      start_values[v] = something(start_values[Time.at_year(v, t0)], 0.0) * 0.5^(year - t0)
    elseif base == "rWInflation"
      start_values[v] = fv - 1
    elseif base == "qI_k_i"
      key = name[length("qI_k_i[")+1:findlast(',', name)-1]
      qK = start_values[SquareModels.variable_by_name(model, "qK_k_i[$key,$t0]")]
      depr = start_values[SquareModels.variable_by_name(model, "rKDepr_k_i[$key,$t0]")]
      (isnothing(qK) || isnothing(depr)) && continue
      start_values[v] = qK * (1 - (1 - depr) / fq)
    end
  end
  return nothing
end