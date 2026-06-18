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
import SquareModels: ModelDictionary, solve, solve!, assert_no_diff, assert_residuals_small

include("Settings.jl")
include("Time.jl")
include("Solver.jl")
include("GrowthInflationAdjustment.jl")
include("Tags.jl")

include("Logging.jl")
import .Log: @log_time

# ==============================================================================
# Global model container
# ==============================================================================
db = ModelDictionary(Solver.SquareModel())

# ==============================================================================
# Include submodules
# ==============================================================================
const submodels = [@log_time include(joinpath("modules", "$name.jl")) for name in Settings.enabled_modules]

for m in submodels
	@log_time m.set_data!(db)
end

base_model() = @log_time sum(m.define_equations() for m in submodels)

include("Calibration.jl")

# ==============================================================================
# Solve calibration (static then dynamic)
# ==============================================================================
# Static: single-period at t1 — calibrates residuals and parameters
Time.T = Settings.calibration_year
@log_time static_solution = Calibration.calibrate_model(db, submodels)
assert_residuals_small(baseline; atol=1e-1, msg="Large residuals after static calibration")

# Dynamic: full horizon — uses static solution as starting values
Time.T = Time.max_terminal_year
@log_time baseline = Calibration.calibrate_model(static_solution, submodels)
assert_residuals_small(baseline; atol=1e-1, msg="Large residuals after dynamic calibration")

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
import .Time: T

scenario = copy(baseline)
scenario[SubmodelTemplate.test_forecast[T-5:T]] .+= π
@log_time solve!(base_model(), scenario)

diff = scenario .- baseline
println("Nonzero Differences: ", diff[diff .!= 0])
