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

# ==============================================================================
# Global model container and time configuration
# ==============================================================================
db = ModelDictionary(Model(Ipopt.Optimizer))
set_silent(db.model)

# Time configuration
const t₀ = 2018    # Base year (data year)
const max_T = 2100 # Maximum terminal year for variable definitions
const t = t₀:max_T

t₁::Int = 2019    # First endogenous year
T::Int = 2030     # Terminal year

# ==============================================================================
# Growth and inflation adjustment
# ==============================================================================
include("GrowthInflationAdjustment.jl")
using .GrowthInflationAdjustment

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
println("GDP: ", baseline[InputOutput.vGDP[t₁]])

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
