# Green Reform EU Model - Julia/JuMP/SquareModels Implementation
#
# A modular dynamic general equilibrium model for
# - fiscal sustainability
# - climate policy
# This is a minimal implementation to establish the architecture.
#
# Structure:
# - Main file (this): Model container, time indices, submodel assembly
# - Submodules: Each in separate files, following SquareModels patterns

import JuMP
using JuMP: Model, set_silent
using Ipopt
using SquareModels
using GAMS

# ==============================================================================
# Load data from GDX (thin layer, modules extract their own sets)
# ==============================================================================
include("Data.jl")

# ==============================================================================
# Global model container and time configuration
# ==============================================================================
db = ModelDictionary(Model(Ipopt.Optimizer))
set_silent(db.model)

const first_data_year = 2015 # Base year (configurable)
const calibration_year = 2020
const max_terminal_year = 2050
const t = first_data_year:max_terminal_year

t1::Int = calibration_year # First endogenous year (configurable)
T::Int = max_terminal_year # Terminal year (configurable)

# ==============================================================================
# Growth and inflation adjustment
# ==============================================================================
include("GrowthInflationAdjustment.jl")

# Tag for variables that should be forecast as constant in calibration
const ForecastConstant = Tag(:forecast_constant)

# ==============================================================================
# Include submodules
# ==============================================================================
include("InputOutput.jl")
include("SubmodelTemplate.jl")

# ==============================================================================
# Model Assembly
# ==============================================================================
submodels = [
	InputOutput,
	SubmodelTemplate,
]

for m in submodels
	m.set_data!(db)
end

base_model() = sum(m.define_equations() for m in submodels)

"""
For calibration: exogenize endogenous variables that have data and endogenize their residuals.
This allows the residuals to absorb any discrepancy between the data and the model equations.
This is useful for checking for inconsistencies in the data itself, as well as for debugging the model.

The @block macro transforms each equation `endo[t] == RHS` into `(endo[t] + endo_J[t]) == RHS`,
where `endo_J` is the residual. Swapping makes endo_J endogenous while endo stays at its data value.
"""
function endo_exo_data_residuals!(block::Block, data::ModelDictionary)
	for (endo, resid) in zip(endogenous(block), residuals(block))
		has_data = !isnothing(data[endo])
		has_data && @endo_exo!(block, resid, endo)
	end
end

"""
Handle ForecastConstant-tagged variables for calibration.

For endogenous variables at t > t1: create equations var[t] == var[t1]
For exogenous variables at t > t1: copy the t1 value in the data.

Returns a Block with forecast constraints (to be merged with the main block).
"""
function forecast_constants!(block::Block, data::ModelDictionary)
	forecast_block = Block(block.model)

	for var in filter(v -> has_tag(v, ForecastConstant), variables(block))
		var_t1 = _get_t1_var(block.model, var)
		var_t1 == var && continue  # Already at t1, no forecast needed

		if is_endogenous(var_t1, block)
			# var_t1 is endogenous: add forecast constraint var[t] == var[t1]
			forecast_block = forecast_block + add_equation(block.model, var, var, var_t1)
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

"""Get the t1 version of a variable by replacing the last index with t1."""
function _get_t1_var(model, var)
	var_name = JuMP.name(var)
	t1_name = replace(var_name, r",(\d+)\]$" => ",$t1]", r"\[(\d+)\]$" => "[$t1]")
	return JuMP.variable_by_name(model, t1_name)
end

function calibrate_model(db)
	block = sum(m.define_calibration() for m in submodels)
	block = forecast_constants!(block, db)
	endo_exo_data_residuals!(block, db)
	baseline = solve(block, db; replace_nothing=1.0)
	return baseline
end

# ==============================================================================
# Solve calibration
# ==============================================================================
baseline = calibrate_model(db)

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
zero_shock = solve(base_model(), baseline)
assert_no_diff(baseline, zero_shock; atol=1e-6, msg="Zero shock test failed")

# Module-specific tests
for m in submodels
	isdefined(m, :run_tests) && m.run_tests(baseline)
end

# ==============================================================================
# Scenario example
# ==============================================================================
# scenario = copy(baseline)
# # Apply shock here
# solve!(base_model(), scenario)
