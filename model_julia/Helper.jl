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
  static_calibration_block = sum(m.define_calibration() for m in model_modules);
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
function dynamic_calibration(data, static_solution, static_calibrated_parameters; previous_solution=nothing)
  Time.T = Time.max_terminal_year
  exogenous_values = copy(data)
  start_values = copy(static_solution)
  dynamic_calibration_block = sum(m.define_calibration() for m in model_modules);

  exogenous_values[static_calibrated_parameters] .= static_solution[static_calibrated_parameters]
  forecast_zeros!(dynamic_calibration_block, exogenous_values)
  endo_exo_residuals!(dynamic_calibration_block, exogenous_values)
  set_starting_values!(start_values, loaded_modules)
  fill_missing_t1_exogenous_start_values!(dynamic_calibration_block, exogenous_values, start_values)
  dynamic_calibration_block = forecast_constants!(dynamic_calibration_block, exogenous_values)
  fill_missing_exogenous_forecasts!(dynamic_calibration_block, exogenous_values, start_values)

  if !isnothing(previous_solution)
    previous_solution_vars = filter(variables(dynamic_calibration_block)) do var
      year = variable_year(var)
      !isnothing(year) && year > Time.t1 && !isnothing(previous_solution[var])
    end
    start_values[previous_solution_vars] .= previous_solution[previous_solution_vars]
  end

  fill_missing_endogenous_start_values!(dynamic_calibration_block, start_values)
  @log_time baseline = solve(dynamic_calibration_block, exogenous_values; start_values, replace_nothing=1.0)
  return baseline
end

# ============================================================================
# Dynamic calibration step by step
# ============================================================================
# Pass horizon_steps to compare different stage lengths with the same start rules.
function dynamic_calibration_step_by_step(
  data,
  static_solution,
  static_calibrated_parameters;
  horizon_steps=unique([(Settings.calibration_year + 12):5:Time.max_terminal_year..., Time.max_terminal_year]),
)
  baseline = static_solution

  for (solved_through, terminal_year) in zip([Settings.calibration_year; horizon_steps], horizon_steps)
    Time.T = terminal_year
    exogenous_values = copy(data)
    start_values = copy(baseline)
    block = sum(m.define_calibration() for m in model_modules);

    exogenous_values[static_calibrated_parameters] .= static_solution[static_calibrated_parameters]
    forecast_zeros!(block, exogenous_values)
    endo_exo_residuals!(block, exogenous_values)
    set_starting_values!(start_values, loaded_modules)
    fill_missing_t1_exogenous_start_values!(block, exogenous_values, start_values)
    block = forecast_constants!(block, exogenous_values)
    fill_missing_exogenous_forecasts!(block, exogenous_values, start_values)
    extend_start_values!(block, start_values, solved_through)
    fill_missing_endogenous_start_values!(block, start_values)

    baseline = @log_time "dynamic calibration through $terminal_year" solve(block, exogenous_values; start_values, replace_nothing=1.0)
  end

  return baseline
end