# ==============================================================================
# Submodel Template
# ==============================================================================
# Template for creating new submodules. Copy this file and modify as needed.
# See InputOutput.jl for a more complete example.

module SubmodelTemplate
	using JuMP, SquareModels
	# using ..GrowthInflationAdjustment  # Uncomment if using growth/inflation adjustment
	# using ..Data: gdx, load_set        # Uncomment if loading sets from GDX
	import ..db, ..t, ..t1, ..T

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
	end

	# ==========================================================================
	# Data
	# ==========================================================================
	function set_data!(db)
		db[test_variable] .= 1.0
		db[test_scalar] = 1.0
		db[test_constant] .= 1.0
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
		block = define_equations()
		# Add calibration-specific endo-exo swaps here:
		# @endo_exo! block begin
		# 	parameter, observed_variable
		# end
		return block
	end

	# ==========================================================================
	# Tests
	# ==========================================================================
	function run_tests(db)
		# Add module-specific assertions here
		return nothing
	end
end
