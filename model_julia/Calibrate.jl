# Calibrate selected modules, test them with zero shock, and export the baseline.
# The static result supplies start values for the dynamic solve.
using SquareModels
include("Model.jl")
include("Calibration.jl")
import .Calibration:
  residual_tolerances,
  set_starting_values!,
  endo_exo_residuals!,
  forecast_zeros!,
  forecast_constants!,
  fill_missing_t1_exogenous_start_values!,
  fill_missing_exogenous_forecasts!,
  fill_missing_endogenous_start_values!
import .Tags: DynamicCalibration

data = assign_data!(ModelDictionary(model))

# ============================================================================
# Modules - modify the list to debug calibration
# ============================================================================
modules = [
  ModuleTemplate,
  InputOutput,
  ImportSubstitution,
  Production,
  Labor,
  Capital,
  Intermediates,
  CapitalAdjustmentCosts,
  # SectorAccounts,
  Exports,
]

# The full-horizon model tells calibration which variables are parameters.
Time.T = Time.max_terminal_year
base_block = base_model(modules)

# ============================================================================
# Static calibration
# ============================================================================
# Calibrate parameters and residuals in the calibration year.
Time.T = Settings.calibration_year
exogenous_values, start_values = copy(data), copy(data)
static_calibration_block = sum(m.define_calibration() for m in modules);
static_calibrated_parameters = filter(
  var -> !has_tag(var, DynamicCalibration),
  setdiff(endogenous(static_calibration_block), endogenous(base_block)),
)
endo_exo_residuals!(static_calibration_block, exogenous_values)
set_starting_values!(start_values, modules)
fill_missing_t1_exogenous_start_values!(static_calibration_block, exogenous_values, start_values)
@log_time static_solution = solve(static_calibration_block, exogenous_values; start_values, replace_nothing=1.0)
assert_residuals_small(static_solution; rtol=1e-4, tolerances=residual_tolerances(static_solution, modules), msg="Large residuals after static calibration",)

# ============================================================================
# Dynamic calibration
# ============================================================================
# Solve the full horizon from the static result. Start from the source values again, so
# zeros for hooks that have no equation in the static horizon do not carry over.
Time.T = Time.max_terminal_year
exogenous_values = copy(data)
start_values = copy(static_solution)
dynamic_calibration_block = sum(m.define_calibration() for m in modules);
# Keep the static parameters. Their values make them exogenous in the swap below. The
# residual of each identifying equation then records any conflict with the full horizon.
exogenous_values[static_calibrated_parameters] .= static_solution[static_calibrated_parameters]
forecast_zeros!(dynamic_calibration_block, exogenous_values)
endo_exo_residuals!(dynamic_calibration_block, exogenous_values)
set_starting_values!(start_values, modules)
dynamic_calibration_block = forecast_constants!(dynamic_calibration_block, exogenous_values)
fill_missing_exogenous_forecasts!(dynamic_calibration_block, exogenous_values, start_values)
fill_missing_endogenous_start_values!(dynamic_calibration_block, start_values)
@log_time baseline = solve(dynamic_calibration_block, exogenous_values; start_values, replace_nothing=1.0)
assert_residuals_small(baseline; rtol=1e-4, tolerances=residual_tolerances(baseline, modules), msg="Large residuals after dynamic calibration",)

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
baseline[filter(resid -> isnothing(baseline[resid]), residuals(base_block))] .= 0.0
zero_shock = solve(base_block, baseline)
assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed")

# Module-specific tests: collect failures from every module before raising, since a single
# underlying bug often trips several checks at once (across one or more modules).
test_errors = String[]
for m in model_modules
	isdefined(m, :run_tests) && append!(test_errors, m.run_tests(baseline))
end
isempty(test_errors) || error(
	"$(length(test_errors)) module test(s) failed:\n" * join(("  " * e for e in test_errors), "\n")
)

# ==============================================================================
# Export baseline
# ==============================================================================
const output_dir = joinpath(@__DIR__, "..", "Output")
mkpath(output_dir)
unload(joinpath(output_dir, "baseline.parquet"), baseline)
