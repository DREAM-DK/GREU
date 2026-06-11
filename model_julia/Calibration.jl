module Calibration

using SquareModels
import JuMP
import ..Log: @log_time
import ..Time: at_year, variable_year, t1, T
import ..Tags: ForecastConstant

"""
For calibration: exogenize endogenous variables that have data and endogenize their residuals.
This allows the residuals to absorb any discrepancy between the data and the model equations.
This is useful for checking for inconsistencies in the data itself, as well as for debugging the model.

The @block macro transforms each equation `endo[t] == RHS` into `(endo[t] + endo_J[t]) == RHS`,
where `endo_J` is the residual. Swapping makes endo_J endogenous while endo stays at its data value.
"""
function endo_exo_data_residuals!(block::Block, data::ModelDictionary)
	new_endos = VariableRef[]
	old_endos = VariableRef[]
	for (endo, resid) in zip(endogenous(block), residuals(block))
		year = variable_year(endo)
		if !isnothing(data[endo]) && (isnothing(year) || year <= t1)
			push!(new_endos, resid)
			push!(old_endos, endo)
		end
	end
	SquareModels._endo_exo_swap!(block, new_endos, old_endos, "endo_exo_data_residuals!")
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
