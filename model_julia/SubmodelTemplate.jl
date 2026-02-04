# ==============================================================================
# Submodel Template
# ==============================================================================
# Template for creating new submodules. Copy this file and modify as needed.
# See InputOutput.jl for a more complete example.

module SubmodelTemplate
	import JuMP
	using SquareModels
	# using ..GrowthInflationAdjustment  # Uncomment if using growth/inflation adjustment
	# using ..Data: gdx, load_set        # Uncomment if loading sets from GDX
	import ..db, ..t, ..t1, ..T, ..ForecastConstant

	# ==========================================================================
	# Indices (owned by this module)
	# ==========================================================================
	const test_index = [:a, :b, :c]  # Test index

	# ==========================================================================
	# Variables
	# ==========================================================================
	# Use @growth_adjusted and/or @inflation_adjusted for variables that need adjustment
	# @growth_adjusted @inflation_adjusted @variables db.model begin
	# 	vValue[t]     # Nominal value
	# end

	@variables db.model begin
		test_variable[t]  # Test variable from submodel template
		test_scalar       # Test variable with no indices
		test_constant[test_index]  # Test variable with no time index
		test_forecast[t] :: ForecastConstant, "Variable forecast as constant from t1"
	end

	# ==========================================================================
	# Data
	# ==========================================================================
	function set_data!(db)
		db[test_variable] .= 1.0
		db[test_scalar] = 1.0
		db[test_constant] .= 1.0
		db[test_forecast] .= 42.0  # Initial value at t1 that should be forecast forward
		return nothing
	end

	# ==========================================================================
	# Equations
	# ==========================================================================
function define_equations()
		return @block db begin
			test_variable[t = t1:T],
			test_variable[t] == 1
		end
	end

	# ==========================================================================
	# Calibration
	# ==========================================================================
	function define_calibration()
		# test_forecast is calibrated at t1, then forecast_constants() extends it forward
		block = define_equations() + @block db begin
			test_forecast[t = t1:t1],
			test_forecast[t] == 42.0
		end

		return block
	end

	# ==========================================================================
	# Tests
	# ==========================================================================
	function run_tests(db)
		# Test that ForecastConstant variable is constant across all time periods
		all(db[test_forecast] .≈ db[test_forecast[t1]]) || error("test_forecast should be constant")
		return nothing
	end
end
