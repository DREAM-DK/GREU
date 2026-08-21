# Calibrate the model: solve the baseline (static then dynamic), verify it, and export it
# to Output/baseline.parquet for later use by Shock.jl.
using SquareModels
include("Model.jl")
import .Time: at_year, variable_year, t1, T
import .Tags: ForecastConstant, ForecastZero

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
