# Calibrate selected modules, test them with zero shock, and export the baseline.
# The static result supplies start values for the dynamic solve.
using Revise
using SquareModels
import GREU:
  Settings,
  Time,
  model,
  loaded_modules,
  loaded_module_by_name,
  assign_data!,
  base_model
import GREU.Log: @log_time
import GREU.GrowthInflationAdjustment: adjust_growth_inflation!
import GREU.Calibration:
  residual_tolerances

include("helper.jl") # Helper functions

const output_dir = joinpath(@__DIR__, "..", "Output")

# ==============================================================================
# Data
# ==============================================================================
data = assign_data!(ModelDictionary(model))
@log_time adjust_growth_inflation!(data)

# ============================================================================
# Model modules
# ============================================================================
model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]

# The full-horizon model tells calibration which variables are parameters.
Time.T = Time.max_terminal_year
base_block = base_model(model_modules)

# ============================================================================
# Static calibration
# ============================================================================
static_solution, static_calibrated_parameters = static_calibration(
                      data,
                      base_block
                    )

assert_residuals_small(static_solution; rtol=1e-4, residual_tolerances(static_solution, model_modules)...,
  msg="Large residuals after static calibration")

# ==============================================================================
# Dynamic calibration
# ==============================================================================
previous_solution_path = joinpath(output_dir, "previous_baseline.parquet")
previous_solution = isfile(previous_solution_path) ? load(previous_solution_path, model) : nothing

# Step by step is used only when no previous solution is available as start values.
baseline = isnothing(previous_solution) ?
  dynamic_calibration_step_by_step(data, static_solution, static_calibrated_parameters) :
  dynamic_calibration(data, static_solution, static_calibrated_parameters; previous_solution)

assert_residuals_small(baseline; rtol=1e-4, residual_tolerances(baseline, model_modules)...,
  msg="Large residuals after dynamic calibration")

# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
Time.t1 = 2026
zero_shock = solve(base_model(model_modules), baseline; run_test_constraints=false)
assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed")

# ==============================================================================
# Export baseline
# ==============================================================================
mkpath(output_dir)
unload(joinpath(output_dir, "baseline.parquet"), baseline)

# ==============================================================================
# Write baseline report
# ==============================================================================
include("BaselineReport.jl"); BaselineReport.write_report(baseline)
