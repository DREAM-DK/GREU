module Calibration

using SquareModels
import ..Log: @log_time
import ..Time: at_year, variable_year, t1, T
import ..Tags: ForecastConstant

"""
Stopover: assert_residuals_small with per-residual tolerance overrides collected
from the submodules. Each submodule may define an optional `residual_tolerances()`
returning a Dict from variable (or base-name string) to its allowed residual
magnitude; all other residuals must be below `atol`.
"""
function SquareModels.assert_residuals_small(data::ModelDictionary, submodels::AbstractVector{Module};
		atol::Real=1e-6, msg::String="", exclude=())
	as_residual_name(b) = endswith(b, RESIDUAL_SUFFIX) ? b : b * RESIDUAL_SUFFIX
	normalize(k) = as_residual_name(k isa AbstractString ? String(k) : SquareModels.base_name(k))
	atol_overrides = mapreduce(merge, submodels; init=Dict{Any, Float64}()) do m
		isdefined(m, :residual_tolerances) ? m.residual_tolerances() : Dict{Any, Float64}()
	end
	overrides = Dict{String, Float64}(normalize(k) => Float64(v) for (k, v) in atol_overrides)
	excluded = Set(SquareModels._excluded_base_name(e) for e in exclude)

	violations = Tuple{String, Float64}[]
	for r in residuals(data.model)
		b = SquareModels.base_name(r)
		b in excluded && continue
		v = data[r]
		isnothing(v) && continue
		tol = get(overrides, b, Float64(atol))
		abs(v) > tol && push!(violations, (SquareModels.name(r), abs(v)))
	end
	isempty(violations) && return true
	sort!(violations, by=x -> -x[2])
	throw(ResidualError(violations, Float64(atol), msg))
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

end
