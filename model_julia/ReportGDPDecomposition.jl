# Report GDP quantity and price aggregates from one saved solution.
# Set the parquet file name in the first section.
# Do not solve or change model values.

using CairoMakie
using DREAMMakieTheme
using SquareModels: LabeledSeries, load, plotseries, @evalexpr,
  set_default_source!, set_default_periods!, set_default_operator!

import GREU: model
import GREU.Capital: capital_k_i, qK_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP
import GREU.InputOutput: pC, pG, pI, pM, pX, qC, qG, qI, qM, qX
import GREU.Time: T

# ==============================================================================
# Files
# ==============================================================================
report_dir = joinpath(@__DIR__, "..", "Output")
t1 = 2026
report_title = "GDP quantities and prices"

parquet_file = "baseline.parquet"
report_file = "gdp_decomposition_baseline.html"

# ==============================================================================
# Figure
# ==============================================================================

# One line per aggregate, divided by its value in the first plotted year.
function unit_index(name, values, years)
  y = [value isa Real && isfinite(value) ? Float64(value) : NaN for value in values]
  @assert length(y) == length(years) "$name must have one value per plotted year."
  i = findfirst(isfinite, y)
  @assert i !== nothing && !iszero(y[i]) "$name has no finite opening value."
  return LabeledSeries(years, y ./ y[i], name)
end

"""Quantities and prices on two panels. Each line uses its value in the first plotted year as 1."""
function aggregate_figure(years)
  set_default_operator!(:n)
  quantities = [
    "qGDP" => @evalexpr(qGDP),
    "qC" => @evalexpr(qC),
    "qI" => @evalexpr(qI),
    "qK" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i)),
    "qG" => @evalexpr(qG),
    "qX" => @evalexpr(qX),
    "qM" => @evalexpr(qM),
  ]
  prices = [
    "pGDP" => @evalexpr(pGDP),
    "pC" => @evalexpr(pC),
    "pI" => @evalexpr(pI),
    "pG" => @evalexpr(pG),
    "pX" => @evalexpr(pX),
    "pM" => @evalexpr(pM),
  ]
  fig = Figure(; size=(1400, 500))
  options = (
    decorate=(ax, series) -> reference_line!(ax, years[1]),
    ylabel="Index ($(years[1]) = 1)",
  )
  plotseries([unit_index(name, values, years) for (name, values) in quantities];
    position=fig[1, 1],
    legend=(fig, ax, series) -> colored_text_legend!(fig, ax; columns=length(quantities)),
    options...)
  plotseries([unit_index(name, values, years) for (name, values) in prices];
    position=fig[1, 2],
    legend=(fig, ax, series) -> colored_text_legend!(fig, ax; columns=length(prices)),
    options...)
  return fig
end

# ==============================================================================
# Report
# ==============================================================================
parquet_path = joinpath(report_dir, parquet_file)
@assert isfile(parquet_path) "Missing $parquet_path."
solution = load(parquet_path, model)

years = collect((t1-1):T)
set_default_source!(solution)
set_default_periods!(years)
report_path = joinpath(report_dir, report_file)
with_dream_theme(:slide_large) do
  sections = [
    report_section("Quantities and prices",
      ["Aggregates" => aggregate_figure(years)]; wide=true,
      description="Each line uses its value in $(years[1]) as 1."),
  ]
  write_html_report(report_path, sections;
    title="$report_title report",
    subtitle="$(years[1])–$(last(years))")
end
println("Wrote $report_path")
