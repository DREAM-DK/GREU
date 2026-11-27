# Calibrate selected modules, test them with zero shock, and export the baseline.
# The static result supplies start values for the dynamic solve.
using Revise
using SquareModels
include("sqm_patch.jl")
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
base_blocks = [m.define_equations() for m in model_modules]
base_block = sum(base_blocks)

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
previous_solution = (isfile(previous_solution_path) ? load(previous_solution_path, model) : nothing)

# Default: one solve, starting from the static solution.
baseline = @log_time "dynamic calibration" dynamic_calibration(
  data, static_solution, static_calibrated_parameters; base_blocks)

# Step by step, in stages of `step` years:
# baseline = @log_time "dynamic calibration" dynamic_calibration(
#   data, static_solution, static_calibrated_parameters; base_blocks, step=5)

# Starting from the previous baseline:
# baseline = @log_time "dynamic calibration" dynamic_calibration(
#   data, static_solution, static_calibrated_parameters; base_blocks, previous_solution)

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

# Load the baseline from a previous run instead of calibrating again (run the sections up to Model modules first):
# baseline = load(joinpath(output_dir, "baseline.parquet"), base_block.model)

# ==============================================================================
# Write baseline report
# ==============================================================================
include("BaselineReport.jl")
isnothing(previous_solution) ?
  BaselineReport.write_report("Baseline" => baseline) :
  BaselineReport.write_report("Baseline" => baseline, "Previous baseline" => previous_solution)

# ==============================================================================
# Write baseline tables (optional)
# ==============================================================================
# Production inputs and persons by labor type for each industry in one year, as tables and figures.
# Figures 1-7 also show the comparison year as a diamond.
# The government balance and its parts: tables for chosen years, figures for a range of years.
write_baseline_tables = true
baseline_tables_year = 2050
baseline_tables_compare_year = 2019
write_government_tables = true
government_table_years = [2019, 2025, 2030, 2040, 2050, 2060]
government_figure_years = 2019:2065
if write_baseline_tables || write_government_tables
  include("DAProductivityShockFigures.jl")
  include("BaselineTables.jl")
end
if write_baseline_tables
  BaselineTables.write_tables(joinpath(output_dir, "baseline_tables_$(baseline_tables_year).html"), baseline;
    year=baseline_tables_year)
  BaselineTables.write_figures(joinpath(output_dir, "baseline_figures_$(baseline_tables_year).html"), baseline;
    year=baseline_tables_year, compare_year=baseline_tables_compare_year)
end
if write_government_tables
  include("GovernmentTables.jl")
  GovernmentTables.write_tables(joinpath(output_dir, "government_tables.html"), baseline; years=government_table_years)
  GovernmentTables.write_figures(joinpath(output_dir, "government_figures.html"), baseline; years=government_figure_years)
end