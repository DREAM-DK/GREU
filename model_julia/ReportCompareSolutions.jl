# Compare saved shock solutions with the calibrated baseline or other solutions.
# Set the parquet file names in the first section.
# Do not solve or change model values.

using SquareModels: load

import GREU: model
import GREU.ConsumptionSavingsDecision: dU2dC, qCxRef, qHhWealth, vHtMIncome
import GREU.FixedBasePriceAggregates: qGDP
import GREU.InputOutput: qC, qI
import GREU.Time: T

isdefined(@__MODULE__, :ShockReport) || include(joinpath(@__DIR__, "ShockReport.jl"))

# ==============================================================================
# Files
# ==============================================================================
comparison_dir = joinpath(@__DIR__, "..", "Output")
t1 = 2026
comparison_title = "rHtM comparison"

baseline_file = "baseline.parquet"
solution_files = [
  "scenario_rHtM_0.15.parquet",
]

# ==============================================================================
# Series
# ==============================================================================
comparison_series = [
  "qC" => qC,
  "qGDP" => qGDP,
  "qI" => qI,
  "qHhWealth" => qHhWealth,
  "qCxRef" => qCxRef,
  "dU2dC" => dU2dC,
  "vHtMIncome" => vHtMIncome,
]

# ==============================================================================
# Comparison
# ==============================================================================
baseline_path = joinpath(comparison_dir, baseline_file)
@assert isfile(baseline_path) "Missing $baseline_path."
baseline = load(baseline_path, model)

solution_paths = joinpath.(comparison_dir, solution_files)
@assert all(isfile, solution_paths) "Missing $(filter(!isfile, solution_paths))."
solutions = [split(splitext(basename(file))[1], "_")[end] => load(path, model)
  for (file, path) in zip(solution_files, solution_paths)]

# Keep years stored in every file. A shorter solution, such as baseline_2040, ends before T.
cell_finite(db, var, year) = (value = db[var][year]; value isa Real && isfinite(value))
sources = ["Baseline" => baseline; solutions]
requested = (t1-1):T
year_covered(year) = all(sources) do (_, db)
  all(comparison_series) do (_, var)
    cell_finite(db, var, year)
  end
end
years = [year for year in requested if year_covered(year)]
@assert !isempty(years) "No year in $requested is finite for every series in every file."
missing = setdiff(first(years):last(years), years)
@assert isempty(missing) "Year $(missing[1]) is not finite in every file."

ShockReport.write_comparison(
  joinpath(comparison_dir, "shock_comparison.html"), baseline, solutions, comparison_series;
  title=comparison_title,
  periods=first(years):last(years),
)
