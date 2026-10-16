# Compare solved shock paths with the calibrated baseline.
# Use SquareModels settings and the shared DREAM report style.
# Do not solve or change model values.
module ShockReport

using CairoMakie
using DREAMMakieTheme
using SquareModels: ModelDictionary, @plot, @evalexpr,
  set_default_source!, set_default_periods!, set_default_operator!

import GREU.Capital: capital_k_i, pK_k_i, qK_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP, qGVA
import GREU.InputOutput: industry, pC, pG, pI, pM, pX, qC, qG, qI, qM, qX, qY_i
import GREU.Intermediates: intermediate_m_i, qM_m_i
import GREU.Labor: labor_l_i, vW, nL_l_i

# ============================================================================
# Figures
# ============================================================================
function level_figures(baseline, years, shock_title, extra_figures)
  set_default_operator!([:i, :an])
  options = (
    labels=[shock_title, "Baseline"],
    alternating_dash=true,
    ylabel="Index ($(years[1]) = 100)",
    decorate=(ax, series) -> reference_line!(ax, years[1]),
  )
  extras = [figure(baseline, years, options) for figure in extra_figures]
  return [
    "Real GDP" => @plot(qGDP; options...),
    extras...,
    "Real investment" => @plot(qI; options...),
    "Capital stock" => @plot(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i); options...),
  ]
end


# The exact 14 components from BaselineReport.jl.
shock_quantity_panels(years) = [(name=String(name), y=Float64.(values)) for (name, values) in [
  "GDP" => @evalexpr(qGDP),
  "Consumption" => @evalexpr(qC),
  "Investment" => @evalexpr(qI),
  "Capital stock" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i)),
  "Public consumption" => @evalexpr(qG),
  "Exports" => @evalexpr(qX),
  "Imports" => @evalexpr(qM),
]]

# Weight capital user costs by current capital, as in PrintOutput.jl.
shock_price_panels(years) = [(name=String(name), y=Float64.(values)) for (name, values) in [
  "GDP deflator" => @evalexpr(pGDP),
  "Consumption" => @evalexpr(pC),
  "Investment" => @evalexpr(pI),
  "Capital user cost" => @evalexpr(sum(pK_k_i[k,i,:] * qK_k_i[k,i,:] for (k, i) in capital_k_i) /
    sum(qK_k_i[k,i,:] for (k, i) in capital_k_i)),
  "Public consumption" => @evalexpr(pG),
  "Exports" => @evalexpr(pX),
  "Imports" => @evalexpr(pM),
  "Wage per person" => @evalexpr(vW),
]]

function shock_deviations(baseline, scenario, years)
  set_default_periods!(years)
  set_default_operator!(:n)
  set_default_source!(baseline)
  base_q = shock_quantity_panels(years)
  base_p = shock_price_panels(years)
  set_default_source!(scenario)
  scen_q = shock_quantity_panels(years)
  scen_p = shock_price_panels(years)
  function relative(scenario_panels, baseline_panels)
    [(name=s.name,
      y=[isfinite(a) && isfinite(v) && !iszero(v) ?
         100 * (a / v - 1) : NaN for (a, v) in zip(s.y, b.y)])
      for (s, b) in zip(scenario_panels, baseline_panels)]
  end
  set_default_source!(baseline => scenario)
  set_default_operator!(:q)
  return relative(scen_q, base_q), relative(scen_p, base_p)
end

"""Move end labels apart by at least `gap`, keeping their order and centre."""
function shock_spread_labels(y, gap)
  order = sortperm(y)
  placed = y[order]
  for n in 2:length(placed)
    placed[n] = max(placed[n], placed[n-1] + gap)
  end
  placed .-= (sum(placed) - sum(y[order])) / length(placed)
  out = similar(y)
  out[order] = placed
  return out
end

"""One steady-state axis: every series indexed to the first year, labelled at its end."""
function shock_component_axis!(cell, panels, years; title)
  shown = [p for p in panels if count(isfinite, p.y) >= 2]
  isempty(shown) && return Axis(cell; title)
  palette = color_palette()
  indexed = [p.y for p in shown]
  finite = filter(isfinite, reduce(vcat, indexed))
  lo, hi = min(minimum(finite), 0.0), max(maximum(finite), 0.0)
  yspan = max(hi - lo, 0.02)
  span = last(years) - first(years)
  x_end = last(years)
  ticks = [first(years); [y for y in years if y % 10 == 0 && y - first(years) >= 4]]

  ax = Axis(cell; title, titlealign=:left, ylabel="Deviation from baseline (%)",
    xticks=ticks, xgridvisible=false, topspinevisible=false, rightspinevisible=false)
  hlines!(ax, [0.0]; color=(colors().DarkGray, 0.5), linestyle=:dash, linewidth=1)

  ends = [y[findlast(isfinite, y)] for y in indexed]
  label_y = shock_spread_labels(ends, 0.065 * yspan)
  for (n, (p, y)) in enumerate(zip(shown, indexed))
    color = palette[mod1(n, length(palette))]
    lines!(ax, years, y; color, linewidth=2.5)
    lines!(ax, [x_end, x_end + 0.025span], [ends[n], label_y[n]]; color, linewidth=1)
    text!(ax, x_end + 0.03span, label_y[n]; text=p.name, color, font=:bold, align=(:left, :center))
  end

  # Leave room on the right for the labels.
  xlims!(ax, first(years), x_end + 0.38span)
  ylims!(ax, min(lo, minimum(label_y)) - 0.06yspan, max(hi, maximum(label_y)) + 0.06yspan)
  return ax
end

"""Quantities and prices indexed to the first reported year. Flat lines at the end mean a steady state."""
function shock_component_figure(years, quantities, prices; stacked::Bool=false)
  return with_dream_theme(:slide_small) do
    fig = Figure(size=stacked ? (1000, 760) : (1250, 430))
    shock_component_axis!(fig[1, 1], quantities, years; title="Quantities")
    shock_component_axis!(stacked ? fig[2, 1] : fig[1, 2], prices, years; title="Prices")
    stacked ? rowgap!(fig.layout, 30) : colgap!(fig.layout, 50)
    fig
  end
end


function gdp_component_figures(baseline, scenario, years)
  quantities, prices = shock_deviations(baseline, scenario, years)
  return ["GDP components — percentage deviation from baseline" =>
    shock_component_figure(years, quantities, prices)]
end

function response_figures(baseline, years)
  set_default_operator!(:q)
  options = (; legend=false,
    decorate=(ax, series) -> reference_line!(ax, years[1]))
  return [
    "Activity — Real GDP" => @plot(qGDP; options...),
    "Activity — Real gross value added" => @plot(qGVA; options...),
    "Final demand — Real exports" => @plot(qX; options...),
    "Final demand — Real investment" => @plot(qI; options...),
    "Labour — Employment" => @plot(sum(nL_l_i[l,i,:] for (l, i) in labor_l_i); options...),
    "Labour — Nominal wage" => @plot(vW; options...),
    "Capital — Stock" => @plot(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i); options...),
    # Hold the capital mix at the baseline value in each year for both sources.
    "Capital — User cost" => @plot(
      sum(pK_k_i[k,i,:] * $(baseline[qK_k_i[k,i,years]]) for (k, i) in capital_k_i) /
      sum($(baseline[qK_k_i[k,i,years]]) for (k, i) in capital_k_i); options...),
    "Prices — GDP price level" => @plot(pGDP; options...),
    "Prices — Investment price level" => @plot(pI; options...),
    "Prices — Export price level" => @plot(pX; options...),
    "Production — Gross output" => @plot(sum(qY_i[i,:] for i in industry); options...),
    "Production — Intermediate inputs" => @plot(sum(qM_m_i[m,i,:] for (m, i) in intermediate_m_i); options...),
  ]
end

# ============================================================================
# Report
# ============================================================================

"""Write a DREAM HTML report. Set the session's source, periods, and operator for this shock."""
function write_report(path::AbstractString, baseline::ModelDictionary, scenario::ModelDictionary;
  extra_figures=(), shock_title="", periods,
)
  years = collect(periods)
  set_default_source!(baseline => scenario)
  set_default_periods!(years)
  return with_dream_theme(:slide_large) do
    sections = [
      report_section("Baseline and shock paths",
        level_figures(baseline, years, shock_title, extra_figures);
        description="Each line uses its value in $(periods[1]) as 100."),
      report_section("GDP components — Scenario vs baseline",
        gdp_component_figures(baseline, scenario, years);
        wide=true, description="All seven quantity and eight price/wage components, as percentage deviations from baseline."),
      report_section("Detailed model responses", response_figures(baseline, years);
        description="Percentage deviations from the calibrated baseline."),
    ]
    write_html_report(path, sections; title="$shock_title report", subtitle="$(periods[1])–$(last(periods))")
  end
end

end # module
