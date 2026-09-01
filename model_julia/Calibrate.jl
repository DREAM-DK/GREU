# Calibrate selected modules, test them with zero shock, and export the baseline.
# The static result supplies start values for the dynamic solve.
# Load Revise before GREU in an interactive session.
using SquareModels
import GREU:
  Settings,
  Time,
  model,
  loaded_modules,
  loaded_module_by_name,
  assign_data!,
  base_model
import GREU.Log: @log_time
import GREU.GrowthInflationAdjustment: adjust_growth_inflation!
import GREU.Calibration:
  residual_tolerances,
  set_starting_values!,
  endo_exo_residuals!,
  forecast_zeros!,
  forecast_constants!,
  fill_missing_t1_exogenous_start_values!,
  fill_missing_exogenous_forecasts!,
  fill_missing_endogenous_start_values!
import GREU.Tags: DynamicCalibration

data = assign_data!(ModelDictionary(model))
@log_time adjust_growth_inflation!(data)

# ============================================================================
# Model modules
# ============================================================================
model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]

# The full-horizon model tells calibration which variables are parameters.
Time.T = Time.max_terminal_year
base_block = base_model(model_modules)

# ============================================================================
# Static calibration
# ============================================================================
# Calibrate parameters and residuals in the calibration year.
Time.T = Settings.calibration_year
exogenous_values, start_values = copy(data), copy(data)
static_calibration_block = sum(m.define_calibration() for m in model_modules);
static_calibrated_parameters = filter(
  var -> !has_tag(var, DynamicCalibration),
  setdiff(endogenous(static_calibration_block), endogenous(base_block)),
)
forecast_zeros!(static_calibration_block, exogenous_values) # Sets t1 values to zero if they are not calibrated.
endo_exo_residuals!(static_calibration_block, exogenous_values)
# A loaded module can supply an exogenous start value without adding equations.
set_starting_values!(start_values, loaded_modules)
fill_missing_t1_exogenous_start_values!(static_calibration_block,exogenous_values,start_values)
@log_time static_solution = solve(static_calibration_block, exogenous_values; start_values, replace_nothing=1.0)
assert_residuals_small(static_solution; rtol=1e-4, tolerances=residual_tolerances(static_solution, model_modules), msg="Large residuals after static calibration",)

# ============================================================================
# Dynamic calibration
# ============================================================================
# Solve the full horizon from the static result. Start from the source values again, so
# zeros for hooks that have no equation in the static horizon do not carry over.
Time.T = Time.max_terminal_year
exogenous_values = copy(data)
start_values = copy(static_solution)
dynamic_calibration_block = sum(m.define_calibration() for m in model_modules);
# Keep the static parameters. Their values make them exogenous in the swap below. The
# residual of each identifying equation then records any conflict with the full horizon.
exogenous_values[static_calibrated_parameters] .= static_solution[static_calibrated_parameters]
forecast_zeros!(dynamic_calibration_block, exogenous_values)
endo_exo_residuals!(dynamic_calibration_block, exogenous_values)
set_starting_values!(start_values, loaded_modules)
fill_missing_t1_exogenous_start_values!(dynamic_calibration_block, exogenous_values, start_values)
dynamic_calibration_block = forecast_constants!(dynamic_calibration_block, exogenous_values)
fill_missing_exogenous_forecasts!(dynamic_calibration_block, exogenous_values, start_values)
fill_missing_endogenous_start_values!(dynamic_calibration_block, start_values)
@log_time baseline = solve(dynamic_calibration_block, exogenous_values; start_values, replace_nothing=1.0)
assert_residuals_small(baseline; rtol=1e-4, tolerances=residual_tolerances(baseline, model_modules), msg="Large residuals after dynamic calibration",)

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
baseline[filter(resid -> isnothing(baseline[resid]), residuals(base_block))] .= 0.0
zero_shock = solve(base_block, baseline)
assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed")

# ==============================================================================
# Export baseline
# ==============================================================================
const output_dir = joinpath(@__DIR__, "..", "Output")
mkpath(output_dir)
unload(joinpath(output_dir, "baseline.parquet"), baseline)
