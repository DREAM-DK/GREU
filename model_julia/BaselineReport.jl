# Report baseline closure, aggregate paths, and industry convergence.
# Keep values in growth- and inflation-adjusted model units.
# Use SquareModels trellis plots and DREAM HTML styling.
# Do not solve, calibrate, or change model values.
module BaselineReport

using CairoMakie
using DREAMMakieTheme
using SquareModels: ModelDictionary, LabeledSeries, plotseries, @evalexpr,
  set_default_source!, set_default_periods!, set_default_operator!

import GREU.Capital: capital_k_i, pK_k_i, qI_k_i, qK_k_i, rKDepr_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP, qGVA, vGDP
import GREU.GrowthInflationAdjustment: fq, gq
import GREU.InputOutput: industry, pI, pX, qC, qG, qI, qINV, qM, qX, qY_i, vC, vY_i
import GREU.Intermediates: vM_i
import GREU.Labor: labor_l_i, pL_l_i, pW, qL_l_i, vWages_i
import GREU.PhillipsCurve: rLEmploymentGap, rWInflation
import GREU.SectorAccounts: sector, vFinPosition_s_f, vNetFinAssets, vNetFinTransactions
import GREU.Time

# ============================================================================
# Series and diagnostics
# ============================================================================

const a21_names = Dict(
  :iA => "Agriculture, forestry, fishing", :iB => "Mining and quarrying",
  :iC => "Manufacturing", :iD => "Electricity, gas, steam", :iE => "Water, waste",
  :iF => "Construction", :iG => "Wholesale and retail trade", :iH => "Transport and storage",
  :iI => "Accommodation and food", :iJ => "Information and communication",
  :iK => "Finance and insurance", :iL => "Real estate",
  :iM => "Professional, scientific, technical", :iN => "Administrative and support",
  :iO => "Public administration and defence", :iP => "Education", :iQ => "Health and social work",
  :iR => "Arts and recreation", :iS => "Other services", :iT => "Households as employers",
  :iU => "Extraterritorial organisations",
)

checked_values(::Nothing, name) = nothing
report_number(::Nothing, name) = NaN
function report_number(value::Real, name)
  @assert isfinite(value) "Baseline series '$name' has invalid values."
  return Float64(value)
end
checked_values(values, name) = report_number.(vec(Array(values)), Ref(name))

late_change(years, ::Nothing; window=10) = nothing
function late_change(years, values; window=10)
  @assert window > 0 "The closing window must be positive."
  keep = findall(isfinite, values)
  length(keep) < 2 && return nothing
  years, values = years[keep], values[keep]
  index = searchsortedfirst(years, last(years) - window)
  (index == length(years) || iszero(values[index])) && return nothing
  change = 100 * (last(values) / values[index] - 1)
  @assert isfinite(change) "The closing-window change must be finite."
  return change
end

function entry(name, values, years; window=10, target=nothing)
  values = checked_values(values, name)
  target === nothing || @assert isfinite(target) "The reference value must be finite."
  return (; name, values, metric=late_change(years, values; window), target)
end

# A missing factor type has no series. Missing observations stay blank.
function industry_values(i, years)
  k = [k for (k, ind) in capital_k_i if ind == i]
  l = [l for (l, ind) in labor_l_i if ind == i]
  first_year = first(years)
  output = @evalexpr qY_i[i,:]
  value_added = @evalexpr vY_i[i,:] - vM_i[i,:]
  capital = isempty(k) ? nothing : @evalexpr sum(qK_k_i[k,i,:] for k in k)
  investment = isempty(k) ? nothing : @evalexpr sum(qI_k_i[k,i,:] for k in k)
  return (;
    output, value_added,
    output_price=@evalexpr(vY_i[i,:] / qY_i[i,:]),
    employment=isempty(l) ? nothing : @evalexpr(sum(qL_l_i[l,i,:] for l in l)),
    labor_share=@evalexpr(vWages_i[i,:] / (vY_i[i,:] - vM_i[i,:])),
    labor_cost=isempty(l) ? nothing : @evalexpr(
      sum(pL_l_i[l,i,:] * qL_l_i[l,i,:] for l in l) / sum(qL_l_i[l,i,:] for l in l)),
    capital, capital_output=isempty(k) ? nothing : @evalexpr(sum(qK_k_i[k,i,:] for k in k) / qY_i[i,:]),
    capital_cost=isempty(k) ? nothing : @evalexpr(
      sum(pK_k_i[k,i,:] * qK_k_i[k,i,first_year] for k in k) / sum(qK_k_i[k,i,first_year] for k in k)),
    investment,
    investment_rate=isempty(k) ? nothing : @evalexpr([
      sum(qI_k_i[k,i,t] for k in k) / (sum(qK_k_i[k,i,t-1] for k in k) / fq) for t in years]),
    investment_value=isempty(k) ? nothing : @evalexpr(sum(qI_k_i[k,i,:] for k in k) * pI),
    investment_target=isempty(k) ? nothing : @evalexpr(
      sum(rKDepr_k_i[k,i,first_year] * qK_k_i[k,i,first_year] for k in k) /
      sum(qK_k_i[k,i,first_year] for k in k) + gq),
  )
end

function industry_series(years; window=10)
  data = industry_values.(industry, Ref(years))
  function series(block, label, column, description, field; targets=fill(nothing, length(industry)))
    entries = [entry(String(i), getproperty(d, field), years; window, target)
      for (i, d, target) in zip(industry, data, targets)]
    return (; block, label, column, description, entries)
  end
  return [
    series("Production", "Gross output", "qY", "Real gross output by industry.", :output),
    series("Production", "Value added", "VA", "Output less intermediate input spend, before production taxes.", :value_added),
    series("Production", "Output price", "pY", "Basic-price output price.", :output_price),
    series("Labour", "Employment", "qL", "Labour in efficiency units, summed over labour types.", :employment),
    series("Labour", "Labour share", "wL/VA", "Wages over value added.", :labor_share),
    series("Labour", "Labour user cost", "pL", "Quantity-weighted user cost of labour.", :labor_cost),
    series("Capital", "Capital stock", "qK", "Capital stock, summed over capital types.", :capital),
    series("Capital", "Capital-output ratio", "K/Y", "Capital over gross output.", :capital_output),
    series("Capital", "Capital user cost", "pK", "User cost with the capital mix held at the first reported year.", :capital_cost),
    series("Investment", "Investment", "qI", "Gross fixed investment, summed over capital types.", :investment),
    series("Investment", "Investment rate", "I/K", "Investment over opening capital. The dotted line marks depreciation plus trend growth.",
      :investment_rate; targets=getproperty.(data, :investment_target)),
    series("Investment", "Investment value", "vI", "Nominal investment by industry.", :investment_value),
  ]
end

function closure_series()
  return [
    "Government debt over GDP" => @evalexpr(vFinPosition_s_f[:Gov,:Debt,:Liab,:] / vGDP),
    "Rest-of-world net financial assets over GDP" => @evalexpr(vNetFinAssets[:RoW,:] / vGDP),
    "Household debt over consumption" => @evalexpr(vFinPosition_s_f[:Hh,:Debt,:Liab,:] / vC),
    "Employment gap" => @evalexpr(rLEmploymentGap),
    "Wage inflation" => @evalexpr(rWInflation),
    ["Net lending over GDP: $s" => @evalexpr(vNetFinTransactions[s,:] / vGDP) for s in sector]...,
    "Net lending over GDP: all sectors" => @evalexpr(sum(vNetFinTransactions[s,:] for s in sector) / vGDP),
  ]
end

function aggregate_series(years)
  return [
    "Real GDP" => @evalexpr(qGDP),
    "Real gross value added" => @evalexpr(qGVA),
    "Household consumption" => @evalexpr(qC),
    "Government consumption" => @evalexpr(qG),
    "Fixed investment" => @evalexpr(qI),
    "Inventory investment" => @evalexpr(qINV),
    "Exports" => @evalexpr(qX),
    "Imports" => @evalexpr(qM),
    "Gross output" => @evalexpr(sum(qY_i[i,:] for i in industry)),
    "Employment" => @evalexpr(sum(qL_l_i[l,i,:] for (l, i) in labor_l_i)),
    "Capital stock" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i)),
    "Investment" => @evalexpr(sum(qI_k_i[k,i,:] for (k, i) in capital_k_i)),
    "Value added over gross output" => @evalexpr(sum(vY_i[i,:] - vM_i[i,:] for i in industry) / sum(qY_i[i,:] for i in industry)),
    "Labour share" => @evalexpr(sum(vWages_i[i,:] for i in industry) / sum(vY_i[i,:] - vM_i[i,:] for i in industry)),
    "Capital-output ratio" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i) / sum(qY_i[i,:] for i in industry)),
    "Investment rate" => @evalexpr([sum(qI_k_i[k,i,t] for (k, i) in capital_k_i) /
      (sum(qK_k_i[k,i,t-1] for (k, i) in capital_k_i) / fq) for t in years]),
    "GDP price level" => @evalexpr(pGDP),
    "Wage" => @evalexpr(pW),
    "Investment price level" => @evalexpr(pI),
    "Export price level" => @evalexpr(pX),
  ]
end

# ============================================================================
# Figures and table
# ============================================================================

function reference_axes!(axis, series, targets)
  s = only(series)
  if all(isnan, s.y)
    hidedecorations!(axis)
    hidespines!(axis)
    text!(axis, 0.5, 0.5; text="no data", space=:relative, align=(:center, :center))
    return
  end
  hlines!(axis, [first(filter(isfinite, s.y))]; color=(colors().DarkGray, 0.3), linestyle=:dash)
  target = targets[s.label]
  target === nothing || hlines!(axis, [target]; color=colors().DREAM, linestyle=:dot)
end

function grid_figure(years, entries; show_metric=false)
  targets = Dict(e.name => e.target for e in entries)
  series = [LabeledSeries(years, e.values === nothing ? fill(NaN, length(years)) : e.values, e.name) for e in entries]
  titles = [show_metric ? "$(e.name)  $(format_percent(e.metric))" : replace(e.name, " over " => "\nover ") for e in entries]
  return with_dream_theme(:slide_small) do
    plotseries(series; layout=:trellis, columns=3, panel_titles=titles, ylabel="", legend=false,
      decorate=(ax, series) -> reference_axes!(ax, series, targets))
  end
end

movement(::Nothing) = -Inf
movement(value::Real) = abs(value)

function overview_figure(years, entries)
  ranked = sort([e for e in entries if e.metric !== nothing]; by=e -> -abs(e.metric))
  highlighted = [e.name for e in first(ranked, min(3, length(ranked)))]
  present = [e for e in entries if e.values !== nothing && count(isfinite, e.values) >= 2 &&
    !iszero(first(filter(isfinite, e.values)))]
  series = [LabeledSeries(years, 100 .* e.values ./ first(filter(isfinite, e.values)), e.name) for e in present]
  labels = [e.name in highlighted ? e.name : nothing for e in present]
  styles = [e.name in highlighted ? (color=color_palette()[findfirst(==(e.name), highlighted)], linewidth=2.5) :
    (color=(colors().DarkGray, 0.25), linewidth=1) for e in present]
  return plotseries(series; labels, styles, ylabel="Index (first reported year = 100)",
    legend=(fig, ax, series) -> colored_text_legend!(fig, ax; columns=3),
    decorate=(ax, series) -> hlines!(ax, [100]; color=(colors().DarkGray, 0.3), linestyle=:dash))
end

function screening_table(series; color_scale=5.0)
  metrics = [e.metric for e in first(series).entries]
  values = [s.entries[i].metric for i in eachindex(metrics), s in series]
  row_max = [maximum(movement, row) for row in eachrow(values)]
  order = sortperm(row_max; rev=true)
  data = hcat(values, [isfinite(v) ? v : nothing for v in row_max])[order, :]
  labels = [[s.block for s in series]; "Maximum"]
  columns = [[s.column for s in series]; "Max"]
  return report_table(data; column_labels=[labels, columns], merge_column_label_cells=:auto,
    row_labels=["$i · $(a21_names[i])" for i in collect(industry)[order]], stubhead_label="Industry",
    format=format_percent, shade=(data, i, j) -> data[i, j] === nothing ? nothing : abs(data[i, j]),
    shade_scale=color_scale)
end

# ============================================================================
# Report
# ============================================================================

default_path() = joinpath(@__DIR__, "..", "Output", "baseline_report.html")
function default_periods()
  last_year = Time.max_terminal_year - 10
  return Time.t1:(last_year <= Time.t1 ? Time.max_terminal_year : last_year)
end

"""
Write a DREAM baseline report. Rank industries by their change over the closing
`late_window` years. Exclude the last ten solved years by default. Set the session's
source, periods, and operator to this baseline. Structural gaps stay blank.
"""
function write_report(baseline::ModelDictionary; path::AbstractString=default_path(),
  periods=default_periods(), late_window::Integer=10, color_scale::Real=5.0,
)
  years = collect(periods)
  @assert !isempty(years) && issorted(years) && allunique(years) "Report years must be nonempty, unique, and increasing."
  @assert late_window > 0 "The closing window must be positive."
  set_default_source!(baseline)
  set_default_periods!(years)
  set_default_operator!(:n)
  series = industry_series(years; window=late_window)
  closure = [entry(name, values, years) for (name, values) in closure_series()]
  aggregates = [entry(name, values, years) for (name, values) in aggregate_series(years)]
  return with_dream_theme(:slide_large) do
    sections = [
      report_section("Closure", ["Stocks, gaps, and net lending" => grid_figure(years, closure)]; wide=true,
        description="Check whether stocks settle. Sector net lending must sum to zero in each year."),
      report_section("Aggregates", ["Macro overview" => grid_figure(years, aggregates)]; wide=true,
        description="Aggregate activity, expenditure, factor inputs, ratios, and prices."),
      report_section("Screening", ["Movement by industry and series" => screening_table(series; color_scale)]; wide=true,
        description="Percentage change over the closing $late_window years. Rows follow the largest absolute change. Blank cells have no applicable series or percentage change."),
      report_section("Overview by series", ["$(s.block): $(s.label)" => overview_figure(years, s.entries) for s in series];
        description="Industries use the first reported value as 100. The three largest movers have coloured labels."),
      [report_section("$(s.block): $(s.label)",
        ["$(s.label) by industry" => grid_figure(years, sort(s.entries; by=e -> -movement(e.metric)); show_metric=true)];
        wide=true, description="$(s.description) Panels follow the largest closing-window change. The dashed line marks the opening value.")
        for s in series]...,
    ]
    write_html_report(path, sections; title="Baseline check report",
      subtitle="$(first(years))–$(last(years)). Values are growth- and inflation-adjusted; each panel shows movement relative to trend.")
  end
end

end # module
