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

using JuMP
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

# ==============================================================================
# Include submodules
# ==============================================================================
include("InputOutput.jl")

# ==============================================================================
# Model Assembly
# ==============================================================================
submodels = [
	InputOutput,
]

for m in submodels
	m.set_data!(db)
end

base_model() = sum(m.define_equations() for m in submodels)
calibration_model() = sum(m.define_calibration() for m in submodels)

# ==============================================================================
# Solve calibration
# ==============================================================================
baseline = solve(calibration_model(), db; replace_nothing=1.0)

println("Calibration complete.")
println("GDP: ", baseline[InputOutput.vGDP[InputOutput.t1]])

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
