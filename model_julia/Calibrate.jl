# Calibrate the model: solve the baseline (static then dynamic), verify it, and export it
# to Output/baseline.parquet for later use by Shock.jl.
using SquareModels
include("Model.jl")
import .Time: at_year, variable_year, t1, T
import .Tags: ForecastConstant

function residual_tolerances(data::ModelDictionary, submodels)
	tolerances = ModelDictionary(data.model)
	for m in submodels
		isdefined(m, :set_residual_tolerances!) && m.set_residual_tolerances!(tolerances)
	end
	return tolerances
end

"""
For calibration: exogenize endogenous variables that have data and endogenize their residuals.
This allows the residuals to absorb any discrepancy between the data and the model equations.
This is useful for checking for inconsistencies in the data itself, as well as for debugging the model.

The @block macro transforms each equation `endo[t] == RHS` into `(endo[t] + endo_J[t]) == RHS`,
where `endo_J` is the residual. Swapping makes endo_J endogenous while endo stays at its data value.
"""
function endo_exo_data_residuals!(block::Block, data::ModelDictionary)
	has_data(endo) = !isnothing(data[endo]) && (isnothing(variable_year(endo)) || variable_year(endo) <= t1)
	pairs = [(resid, endo) for (endo, resid) in zip(endogenous(block), residuals(block)) if has_data(endo)]
	SquareModels._endo_exo_swap!(block, first.(pairs), last.(pairs), "endo_exo_data_residuals!")
end

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
		var_t1 == var && continue  # Already at t1, no forecast needed

		if is_endogenous(var_t1, block)
			add_equation!(forecast_block, var, var, var_t1)
		else
			# var_t1 is exogenous (calibrated from data): copy its value
			data[var] = data[var_t1]
		end
	end

	# Initialize residuals in data
	for resid in residuals(forecast_block)
		data[resid] = 0.0
	end

	return block + forecast_block
end

function exogenous_constant_forecast!(block::Block, data::ModelDictionary)
	endo_set = Set(endogenous(block))
	for var in variables(block)
		var in endo_set && continue
		year = variable_year(var)
		isnothing(year) || year <= t1 && continue
		isnothing(data[var]) || continue
		var_t1 = at_year(var, t1)
		v_t1 = data[var_t1]
		if isnothing(v_t1)
			data[var_t1] = 0.0
			v_t1 = 0.0
		end
		data[var] = v_t1
	end
	return nothing
end

function calibrate_model(db, submodels)
	@info "Calibration (T=$T):"
	@log_time block = sum(m.define_calibration() for m in submodels)
	@log_time block = forecast_constants!(block, db)
	@log_time endo_exo_data_residuals!(block, db)
	@log_time exogenous_constant_forecast!(block, db)
	for m in submodels
		isdefined(m, :set_starting_values!) && m.set_starting_values!(db)
	end
	return @log_time solve(block, db; replace_nothing=1.0)
end

# ==============================================================================
# Solve calibration (static then dynamic)
# ==============================================================================
# Static: single-period at t1 — calibrates residuals and parameters
Time.T = Settings.calibration_year
@log_time static_solution = calibrate_model(db, submodels)
@log_errors assert_residuals_small(
	static_solution;
	atol=1e-1,
  tolerances=residual_tolerances(static_solution, submodels),
	msg="Large residuals after static calibration"
)

# Dynamic: full horizon — uses static solution as starting values
Time.T = Time.max_terminal_year
@log_time baseline = calibrate_model(static_solution, submodels)
@log_errors assert_residuals_small(
	baseline;
	atol=1e-1,
  tolerances=residual_tolerances(baseline, submodels),
	msg="Large residuals after dynamic calibration"
)

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
@log_time begin
	zero_shock = solve(base_model(), baseline)
	assert_no_diff(baseline, zero_shock; atol=1e-6, msg="Zero shock test failed")
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
