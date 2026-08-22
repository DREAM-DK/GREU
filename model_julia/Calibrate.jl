# Calibrate selected modules, check the full model, and export the baseline.
# The static result supplies start values for the dynamic solve.
using SquareModels
include("Model.jl")
include("Calibration.jl")
import .Calibration: calibrate_model, residual_tolerances

# ============================================================================
# Calibration modules - modify the list to debug calibration
# ============================================================================
calibration_modules = [
  SubmodelTemplate,
  InputOutput,
  Production,
  Labor,
  Capital,
  Intermediates,
  # CapitalAdjustmentCosts,
  # SectorAccounts,
]

# ============================================================================
# Run calibration
# ============================================================================
# Calibrate parameters and residuals in the calibration year.
Time.T = Settings.calibration_year
@log_time static_solution = calibrate_model(db, copy(db), calibration_modules)
assert_residuals_small(static_solution; rtol=1e-4, tolerances=residual_tolerances(static_solution, calibration_modules), msg="Large residuals after static calibration",)

# Solve the full horizon from the static result.
Time.T = Time.max_terminal_year
@log_time baseline = calibrate_model(db, static_solution, calibration_modules)
assert_residuals_small(baseline; rtol=1e-4, tolerances=residual_tolerances(baseline, calibration_modules), msg="Large residuals after dynamic calibration",)

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
base_block = base_model()
baseline[filter(resid -> isnothing(baseline[resid]), residuals(base_block))] .= 0.0
zero_shock = solve(base_block, baseline)
assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed")

# Module-specific tests: collect failures from every module before raising, since a single
# underlying bug often trips several checks at once (across one or more modules).
test_errors = String[]
for m in submodels
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
