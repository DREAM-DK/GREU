# Calibrate the model: solve the baseline (static then dynamic), verify it, and export it
# to Output/baseline.parquet for later use by Shock.jl.
using SquareModels
include("Model.jl")
include("Calibration.jl")
import .Calibration: calibrate_model, residual_tolerances

# ==============================================================================
# Solve calibration (static then dynamic)
# ==============================================================================
# Static: single-period at t1 — calibrates residuals and parameters
Time.T = Settings.calibration_year
@log_time static_solution = calibrate_model(db, ModelDictionary(db.model), submodels)
@log_errors assert_residuals_small(
	static_solution;
	rtol=1e-4,
  tolerances=residual_tolerances(static_solution, submodels),
	msg="Large residuals after static calibration"
)

# Dynamic: full horizon — uses static solution as starting values
Time.T = Time.max_terminal_year
@log_time baseline = calibrate_model(db, static_solution, submodels)
@log_errors assert_residuals_small(
	baseline;
	rtol=1e-4,
  tolerances=residual_tolerances(baseline, submodels),
	msg="Large residuals after dynamic calibration"
)

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
@log_time begin
	base_block = base_model()
	baseline[filter(resid -> isnothing(baseline[resid]), residuals(base_block))] .= 0.0
	zero_shock = solve(base_block, baseline)
	assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed")
end

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
@log_time unload(joinpath(output_dir, "baseline.parquet"), baseline)
