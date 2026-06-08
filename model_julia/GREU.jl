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
using SquareModels

include("Settings.jl")
using .Settings: first_data_year, base_year, calibration_year, terminal_year
using .Settings: enabled_modules

include("Logging.jl")
using .Log: @log_time
Log.setup!(file=joinpath(@__DIR__, "..", "greu.log"))

include("Solver.jl")
using .Solver: SquareModel

# ==============================================================================
# Global model container and time configuration
# ==============================================================================
db = ModelDictionary(SquareModel())

const tBase = base_year # Statistical index year where prices are set to 1
const max_terminal_year = terminal_year
const t = first_data_year:max_terminal_year

t1::Int = calibration_year # First endogenous year (configurable)
T::Int = max_terminal_year # Terminal year (configurable)

# ==============================================================================
# Growth and inflation adjustment
# ==============================================================================
include("GrowthInflationAdjustment.jl")

# Tag for variables that should be forecast as constant in calibration
const ForecastConstant = Tag(:forecast_constant)
const ForecastZero = Tag(:forecast_zero)

# ==============================================================================
# Include submodules
# ==============================================================================
const submodels = Module[]

function load_submodel!(name::Symbol)
  path = joinpath("modules", string(name) * ".jl")
  isfile(joinpath(@__DIR__, path)) || error("Unknown Julia module file: $name")
  submodel = @log_time include(path)
  push!(submodels, submodel)
  return nothing
end

foreach(load_submodel!, enabled_modules)

for m in submodels
	@log_time m.set_data!(db)
end

function base_model()
	@log_time sum(m.define_equations() for m in submodels)
end

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
	SquareModels._endo_exo!(block, new_endos, old_endos, "endo_exo_data_residuals!")
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
Return the same variable at a chosen year by replacing the last index.

Examples:
- `x[2025] -> x[2030]`
- `x[i,2025] -> x[i,2030]`
"""
@inline at_year(var, year::Integer) = at_year(JuMP.owner_model(var), var, year)
function at_year(model, var, year::Integer)
	var_name = JuMP.name(var)
	open_bracket = findlast(==('['), var_name)
	isnothing(open_bracket) && return var
	last_comma = findlast(==(','), var_name)
	year_name = isnothing(last_comma) || last_comma < open_bracket ?
		string(SubString(var_name, 1, open_bracket), year, ']') :
		string(SubString(var_name, 1, last_comma), year, ']')
	return SquareModels.variable_by_name(model, year_name)
end

function variable_year(var)
	var_name = JuMP.name(var)
	open_bracket = findlast(==('['), var_name)
	isnothing(open_bracket) && return nothing
	last_comma = findlast(==(','), var_name)
	year_txt = isnothing(last_comma) || last_comma < open_bracket ?
		SubString(var_name, open_bracket + 1, lastindex(var_name) - 1) :
		SubString(var_name, last_comma + 1, lastindex(var_name) - 1)
	tryparse(Int, String(year_txt))
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

function calibrate_model(db)
	@info "Calibration (T=$T):"
	@log_time block = sum(m.define_calibration() for m in submodels)
	@log_time block = forecast_constants!(block, db)
	@log_time endo_exo_data_residuals!(block, db)
	@log_time exogenous_constant_forecast!(block, db)
	for m in submodels
		isdefined(m, :set_starting_values!) && m.set_starting_values!(db)
	end
	@log_time solve(block, db; replace_nothing=1.0)
end

# ==============================================================================
# Solve calibration (static then dynamic)
# ==============================================================================
# Static: single-period at t1 — calibrates residuals and parameters
global T = calibration_year
@log_time static_solution = calibrate_model(db)

# Dynamic: full horizon — uses static solution as starting values
global T = max_terminal_year
@log_time baseline = calibrate_model(static_solution)

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
@log_time begin
	zero_shock = solve(base_model(), baseline)
	assert_no_diff(baseline, zero_shock; atol=1e-6, msg="Zero shock test failed")
end

# Module-specific tests
for m in submodels
	isdefined(m, :run_tests) && m.run_tests(baseline)
end

# ==============================================================================
# Scenario example
# ==============================================================================
scenario = copy(baseline)
if isdefined(@__MODULE__, :SubmodelTemplate)
	scenario[SubmodelTemplate.test_forecast[T-5:T]] .+= π
end

# Apply shock here
@log_time solve!(base_model(), scenario)

diff = scenario .- baseline
println("Nonzero Differences: ", diff[diff .!= 0])
