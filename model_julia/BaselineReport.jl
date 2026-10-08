# Report baseline closure, aggregate paths, and industry convergence.
# Compare one or more labelled solutions; the first one sets rankings and reference lines.
# Keep values in growth- and inflation-adjusted model units.
# Do not solve, calibrate, or change model values.
module BaselineReport

using CairoMakie
using DREAMMakieTheme
using SquareModels: ModelDictionary, LabeledSeries, plotseries, @plot, @evalexpr,
  set_default_source!, set_default_periods!, set_default_operator!

import GREU.Capital: capital_k_i, pK_k_i, qI_k_i, qK_k_i, rKDepr_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP, qGVA, vGDP, vGVA
import GREU.GrowthInflationAdjustment: fq, gq
import GREU.InputOutput: industry, pC, pG, pI, pM, pX, qC, qG, qI, qINV, qM, qX, qY_i, vC, vY, vY_i
import GREU.Intermediates: vM_i
import GREU.Labor: labor_l_i, pL_l_i, vW, vWages, nL_l_i, qL_l_i, vWages_i
import GREU.PhillipsCurve: rLEmploymentGap, rWInflation
import GREU.SectorAccounts: sector, vFinPosition_s_f, vNetFinAssets, vNetFinTransactions
import GREU.Settings: calibration_year
import GREU.Time

# ============================================================================
# Series
# ============================================================================
closure_series(years) = [LabeledSeries(years, y, name) for (name, y) in [
  "Government debt over GDP" => @evalexpr(vFinPosition_s_f[:Gov,:Debt,:Liab,:] / vGDP),
  "Rest-of-world net financial assets over GDP" => @evalexpr(vNetFinAssets[:RoW,:] / vGDP),
  "Household debt over consumption" => @evalexpr(vFinPosition_s_f[:Hh,:Debt,:Liab,:] / vC),
  "Employment gap" => @evalexpr(rLEmploymentGap),
  "Wage inflation" => @evalexpr(rWInflation),
  ["Net lending over GDP: $s" => @evalexpr(vNetFinTransactions[s,:] / vGDP) for s in sector]...,
  "Net lending over GDP: all sectors" => @evalexpr(sum(vNetFinTransactions[s,:] for s in sector) / vGDP),
]]

aggregate_series(years) = [LabeledSeries(years, y, name) for (name, y) in [
  "Real GDP" => @evalexpr(qGDP),
  "Real gross value added" => @evalexpr(qGVA),
  "Household consumption" => @evalexpr(qC),
  "Government consumption" => @evalexpr(qG),
  "Fixed investment" => @evalexpr(qI),
  "Inventory investment" => @evalexpr(qINV),
  "Exports" => @evalexpr(qX),
  "Imports" => @evalexpr(qM),
  "Gross output" => @evalexpr(sum(qY_i[i,:] for i in industry)),
  "Employed persons" => @evalexpr(sum(nL_l_i[l,i,:] for (l, i) in labor_l_i)),
  "Employment" => @evalexpr(sum(qL_l_i[l,i,:] for (l, i) in labor_l_i)),
  "Capital stock" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i)),
  "Investment" => @evalexpr(sum(qI_k_i[k,i,:] for (k, i) in capital_k_i)),
  "Value added over gross output" => @evalexpr(vGVA / vY),
  "Labour share" => @evalexpr(vWages / vGVA),
  "Capital-output ratio" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i) / sum(qY_i[i,:] for i in industry)),
  "Investment rate" => @evalexpr([sum(qI_k_i[k,i,t] for (k, i) in capital_k_i) /
    (sum(qK_k_i[k,i,t-1] for (k, i) in capital_k_i) / fq) for t in years]),
  "GDP price level" => @evalexpr(pGDP),
  "Wage" => @evalexpr(vW),
  "Investment price level" => @evalexpr(pI),
  "Export price level" => @evalexpr(pX),
]]

"""Title and description of each industry series, keyed as in `industry_values`."""
const industry_series = (
  qY=("Gross output", "Real gross output by industry."),
  vVA=("Value added", "Output less intermediate input spend, before production taxes."),
  pY=("Output price", "Basic-price output price."),
  nL=("Employed persons", "Employed persons, summed over labour types."),
  qL=("Employment", "Labour in efficiency units, summed over labour types."),
  vWages2vVA=("Labour share", "Wages over value added."),
  pL=("Labour user cost", "Quantity-weighted user cost of labour."),
  qK=("Capital stock", "Capital stock, summed over capital types."),
  qK2qY=("Capital-output ratio", "Capital over gross output."),
  pK=("Capital user cost", "User cost with the capital mix held at the first reported year."),
  qI=("Investment", "Gross fixed investment, summed over capital types."),
  qI2qK=("Investment rate", "Investment over opening capital. The dotted line marks depreciation plus trend growth."),
  vI=("Investment value", "Nominal investment by industry."),
)

# Unassigned cells become missing, so sums and ratios keep the gap.
report_values(x) = [something(v, missing) for v in x]

# Sum a factor over the types an industry uses. An industry without that factor has no series.
factor_sum(f, types, years) = isempty(types) ? fill(missing, length(years)) : sum(report_values(f(x)) for x in types)

"""The `industry_series` of industry `i`, and its steady-state investment rate `sqI2qK`."""
function industry_values(i, years)
  k = [k for (k, ind) in capital_k_i if ind == i]
  l = [l for (l, ind) in labor_l_i if ind == i]
  t0 = first(years)
  qY = report_values(@evalexpr qY_i[i,:])
  vVA = report_values(@evalexpr vY_i[i,:]) .- report_values(@evalexpr vM_i[i,:])
  qL = factor_sum(l -> @evalexpr(qL_l_i[l,i,:]), l, years)
  qK = factor_sum(k -> @evalexpr(qK_k_i[k,i,:]), k, years)
  qI = factor_sum(k -> @evalexpr(qI_k_i[k,i,:]), k, years)
  qKBase = sum((@evalexpr(qK_k_i[k,i,t0]) for k in k); init=0.0)
  series = (;
    qY, vVA,
    pY=report_values(@evalexpr vY_i[i,:]) ./ qY,
    nL=factor_sum(l -> @evalexpr(nL_l_i[l,i,:]), l, years),
    qL,
    vWages2vVA=report_values(@evalexpr vWages_i[i,:]) ./ vVA,
    pL=factor_sum(l -> @evalexpr(pL_l_i[l,i,:] * qL_l_i[l,i,:]), l, years) ./ qL,
    qK,
    qK2qY=qK ./ qY,
    # Hold the capital mix at the first reported year, so only the user cost moves.
    pK=factor_sum(k -> @evalexpr(pK_k_i[k,i,:] * qK_k_i[k,i,t0]), k, years) ./ qKBase,
    qI,
    qI2qK=qI ./ factor_sum(k -> @evalexpr([qK_k_i[k,i,t-1]/fq for t in years]), k, years),
    vI=qI .* report_values(@evalexpr pI),
  )
  sqI2qK = isempty(k) ? missing : sum(@evalexpr(rKDepr_k_i[k,i,t0] * qK_k_i[k,i,t0]) for k in k) / qKBase + gq
  return (; map(y -> LabeledSeries(years, y, string(i)), series)..., sqI2qK)
end

# ============================================================================
# Figures and table
# ============================================================================
const window = 10

"""Percentage change over the closing window. Blank without a usable start value."""
function closing_change(s::LabeledSeries)
  observed = findall(isfinite, s.y)
  length(observed) < 2 && return nothing
  years, y = s.x[observed], s.y[observed]
  start = searchsortedfirst(years, last(years) - window)
  (start == length(years) || iszero(y[start])) && return nothing
  change = 100 * (last(y) / y[start] - 1)
  @assert isfinite(change) "The closing-window change must be finite."
  return change
end

# Series without a closing-window change rank last.
change_size(s) = (change = closing_change(s); change === nothing ? -Inf : abs(change))

# SquareModels gives repeated labels one colour and cycles these line styles in source order.
const line_styles = ["Solid", "Dotted", "Dashed", "Dash-dotted"]

# The first line in a panel belongs to the first solution.
function reference_lines!(axis, lines, target)
  all(s -> all(isnan, s.y), lines) && return
  hlines!(axis, [first(first(lines).y)]; color=(colors().DarkGray, 0.3), linestyle=:dash)
  ismissing(target) || hlines!(axis, [target]; color=colors().DREAM, linestyle=:dot)
end

"""One panel per series in the first set, with one line per solution. All sets share the series order."""
function panel_figure(sets; titles=[replace(s.label, " over " => "\nover ") for s in first(sets)], targets=Dict())
  return with_dream_theme(; size=(440, 330)) do
    plotseries(reduce(vcat, sets); layout=:trellis, columns=3, panel_titles=titles, ylabel="", legend=false,
      decorate=(axis, lines) -> reference_lines!(axis, lines, get(targets, first(lines).label, missing)))
  end
end

"""One line per series, indexed to its first value. The three largest movers have coloured labels."""
function overview(series)
  movers = [s.label for s in first(sort(filter(!isnothing ∘ closing_change, series); by=change_size, rev=true), 3)]
  shown = filter(s -> !isnan(first(s.y)), series)
  styles = [s.label in movers ?
    (color=color_palette()[findfirst(==(s.label), movers)], linewidth=2.5) :
    (color=(colors().DarkGray, 0.25), linewidth=1) for s in shown]
  return plotseries([LabeledSeries(s.x, 100 .* s.y ./ first(s.y), s.label) for s in shown];
    figure=(size=(1320, 500),),
    labels=[s.label in movers ? s.label : nothing for s in shown], styles,
    ylabel="Index (first reported year = 100)",
    legend=(fig, ax, series) -> colored_text_legend!(fig, ax; columns=3),
    decorate=(ax, series) -> hlines!(ax, [100]; color=(colors().DarkGray, 0.3), linestyle=:dash))
end

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

"""Closing-window change for each industry and series. Rows follow the largest absolute change."""
function screening_table(industries)
  series = [getproperty(v, key) for v in industries, key in keys(industry_series)]
  largest = vec(maximum(change_size.(series); dims=2))
  order = sortperm(largest; rev=true)
  return report_table(hcat(closing_change.(series), [isfinite(v) ? v : nothing for v in largest])[order, :];
    column_labels=[[collect(string.(keys(industry_series))); "Max"]], stubhead_label="Industry",
    row_labels=[haskey(a21_names, i) ? "$i · $(a21_names[i])" : string(i) for i in industry[order]],
    format=format_percent, shade_scale=5.0,
    shade=(data, i, j) -> data[i, j] === nothing ? nothing : abs(data[i, j]))
end

"""All industries on one axis, then one panel per industry with data, by size of the closing-window change."""
function industry_section(key, industries)
  title, description = industry_series[key]
  sets = [getproperty.(set, key) for set in industries]
  order = filter(n -> any(isfinite, first(sets)[n].y), sortperm(first(sets); by=change_size, rev=true))
  targets = key == :qI2qK ? Dict(string(i) => v.sqI2qK for (i, v) in zip(industry, first(industries))) : Dict()
  return report_section(title, [
    "All industries" => overview(first(sets)),
    "By industry" => panel_figure([set[order] for set in sets]; targets,
      titles=["$(s.label)  $(format_percent(closing_change(s)))" for s in first(sets)[order]]),
  ]; wide=true,
    description="$description Industries use the first reported value as 100, and the three largest movers have coloured labels. Panels follow the largest closing-window change, and the dashed line marks the opening value.")
end

# ============================================================================
# Report
# ============================================================================
"""
Write `Output/baseline_report.html` for one or more `label => solution` pairs.
Each panel draws one line per solution. The first solution sets the industry
ranking, the screening table, the overviews, and the reference lines. Set the
session's periods and operator, and leave all solutions as default sources. A
structural gap, such as an industry with no capital, keeps its table row and has
no figure panel.
"""
function write_report(sources::Pair{<:AbstractString,<:ModelDictionary}...)
  @assert 1 <= length(sources) <= length(line_styles) "Pass 1 to $(length(line_styles)) solutions, one per line style."
  # The terminal condition binds in the last solved years, so leave them out.
  last_year = Time.max_terminal_year - 10
  years = collect(calibration_year:(last_year <= calibration_year ? Time.max_terminal_year : last_year))
  set_default_periods!(years)
  set_default_operator!(:n)
  sets = [(set_default_source!(db); (closure=closure_series(years), aggregates=aggregate_series(years),
    industries=industry_values.(industry, Ref(years)))) for db in last.(sources)]
  set_default_source!(last.(sources)...)
  # Only the first solution has legend labels.
  gdp_options = (; ylabel="Index ($(first(years)) = 100)", labels=[
    ["GDP", "Household consumption", "Government consumption", "Fixed investment", "Exports", "Imports"];
    fill(nothing, 6 * (length(sources) - 1))])
  industries = getproperty.(sets, :industries)
  return with_dream_theme() do
    sections = [
      report_section("Closure", ["Stocks, gaps, and net lending" => panel_figure(getproperty.(sets, :closure))]; wide=true,
        description="Check whether stocks settle. Sector net lending must sum to zero in each year."),
      report_section("GDP components", [
        "Quantities" => @plot(:i, [qGDP, qC, qG, qI, qX, qM]; gdp_options...),
        "Prices" => @plot(:i, [pGDP, pC, pG, pI, pX, pM]; gdp_options...),
      ]; description="Expenditure quantities and prices, indexed to the first report year. Flat lines at the end mean a steady state."),
      report_section("Aggregates", ["Macro overview" => panel_figure(getproperty.(sets, :aggregates))]; wide=true,
        description="Aggregate activity, expenditure, factor inputs, ratios, and prices."),
      report_section("Screening", ["Change by industry and series" => screening_table(first(industries))]; wide=true,
        description="Percentage change over the closing $window years in $(first(first(sources))). Rows follow the largest absolute change. Blank cells have no applicable series or percentage change."),
      [industry_section(key, industries) for key in keys(industry_series)]...,
    ]
    source_note = join(("$style line: $name." for (style, name) in zip(line_styles, first.(sources))), " ")
    write_html_report(joinpath(@__DIR__, "..", "Output", "baseline_report.html"), sections; title="Baseline check report",
      subtitle="$(first(years))–$(last(years)). Values are growth- and inflation-adjusted; each panel shows change relative to trend. $source_note")
  end
end

end # module
