# Calibrate selected modules, test them with zero shock, and export the baseline.
# The static result supplies start values for the dynamic solve.
# Load Revise before GREU in an interactive session.
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
# Keep each module's equations so dynamic calibration does not build them again
module_blocks = @log_time "define_equations" Dict(m => m.define_equations() for m in model_modules)
base_block = sum(copy(module_blocks[m]) for m in model_modules)
shared_solution_dir = raw"P:\GREU"
previous_solution_file = joinpath(shared_solution_dir, "previous_baseline.parquet")

previous_solution = isfile(previous_solution_file) ?
                    load(previous_solution_file, model) :
                    nothing

# ============================================================================
# Static calibration
# ============================================================================
static_solution, static_calibrated_parameters = static_calibration(
                      data, 
                      base_block
                    )

assert_residuals_small(static_solution; rtol=1e-4, tolerances=residual_tolerances(static_solution, model_modules), msg="Large residuals after static calibration",)

# ============================================================================
# Dynamic calibration
# ============================================================================
share_define_equations!(model_modules) 
baseline = dynamic_calibration(
                      data,
                      static_solution,
                      static_calibrated_parameters;
                      previous_solution,
                      module_blocks,
                    )


# ==============================================================================
# Dynamic calibration step by step
# ==============================================================================
# Use this if needed to calibrate step by step:
# baseline = dynamic_calibration_step_by_step(
#                      data,
#                      static_solution,
#                      static_calibrated_parameters,
#                    )


assert_residuals_small(baseline; rtol=1e-4, tolerances=residual_tolerances(baseline, model_modules), msg="Large residuals after dynamic calibration",)


# ==============================================================================
# Tests
# ==============================================================================
# Zero shock test: After calibration, solving the base model with no changes should give identical results
# baseline[filter(resid -> isnothing(baseline[resid]), residuals(base_block))] .= 0.0
# block_time("Zero shock: residuals")
# zero_shock = solve(base_block, baseline)
# block_time("Zero shock: solve")
# assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed")
# block_time("Zero shock: check")

# ==============================================================================
# Export baseline
# ==============================================================================
const output_dir = joinpath(@__DIR__, "..", "Output")
mkpath(output_dir)
unload(joinpath(output_dir, "baseline.parquet"), baseline)

# ==============================================================================
# Write baseline report
# ==============================================================================
include("BaselineReport.jl"); BaselineReport.write_report(baseline)