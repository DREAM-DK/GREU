# Report baseline closure, aggregate paths, and industry convergence.
# Keep values in growth- and inflation-adjusted model units.
# Use SquareModels trellis plots and DREAM HTML styling.
# Do not solve, calibrate, or change model values.
module BaselineReport

using CairoMakie
using DREAMMakieTheme
using SquareModels: ModelDictionary, plotseries, trellis, labeled, @evalexpr,
  set_default_source!, set_default_periods!, set_default_operator!, default_periods

import GREU.Capital: capital_k_i, pK_k_i, qI_k_i, qK_k_i, rKDepr_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP, qGVA, vGDP
import GREU.GrowthInflationAdjustment: fq, gq
import GREU.InputOutput: industry, pI, pX, qC, qG, qI, qINV, qM, qX, qY_i, vC, vY_i
import GREU.Intermediates: vM_i
import GREU.Labor: labor_l_i, pL_l_i, vW, nL_l_i, qL_l_i, vWages_i
import GREU.PhillipsCurve: rLEmploymentGap, rWInflation
import GREU.SectorAccounts: sector, vFinPosition_s_f, vNetFinAssets, vNetFinTransactions
import GREU.Time

# ============================================================================
# Panels
# ============================================================================
closing_window::Int = 10

"""Model values as plot values. An unassigned cell stays blank."""
plot_values(x) = Float64[v === nothing ? NaN : v for v in x]

"""First reported value of a series."""
opening(y) = first(filter(isfinite, y))

"""Percentage change over the closing window. Blank without a usable start value."""
function closing_change(y)
  observed = findall(isfinite, y)
  length(observed) < 2 && return nothing
  reported, values = default_periods()[observed], y[observed]
  start = searchsortedfirst(reported, last(reported) - closing_window)
  (start == length(reported) || iszero(values[start])) && return nothing
  return 100 * (last(values) / values[start] - 1)
end

"""One report line: values in model units, its closing-window change, and a reference level."""
struct Panel
  name::String
  y::Vector{Float64}
  change::Union{Nothing,Float64}
  target::Float64
  function Panel(name, values, target=NaN)
    y = plot_values(values)
    @assert length(y) == length(default_periods()) "Series '$name' needs one value for each report year."
    return new(String(name), y, closing_change(y), target)
  end
end

# ============================================================================
# Industry series
# ============================================================================
# Sum a factor over the types an industry uses. An industry without that factor has no series.
factor_sum(f, types) = isempty(types) ? fill(NaN, length(default_periods())) : sum(plot_values(f(x)) for x in types)

"""Values that several industry series share. A factor sum stays blank when the industry has no such type."""
function industry_values(i)
  k = [k for (k, ind) in capital_k_i if ind == i]
  l = [l for (l, ind) in labor_l_i if ind == i]
  t0 = first(default_periods())
  vY = plot_values(@evalexpr vY_i[i,:])
  qKBase = sum((@evalexpr qK_k_i[k,i,t0] for k in k); init=0.0)
  vKDepr = sum((@evalexpr rKDepr_k_i[k,i,t0] * qK_k_i[k,i,t0] for k in k); init=0.0)
  return (;
    qY=plot_values(@evalexpr qY_i[i,:]),
    vY,
    vVA=vY .- plot_values(@evalexpr vM_i[i,:]),
    vWages=plot_values(@evalexpr vWages_i[i,:]),
    pI=plot_values(@evalexpr pI),
    nL=factor_sum(l -> @evalexpr(nL_l_i[l,i,:]), l),
    qL=factor_sum(l -> @evalexpr(qL_l_i[l,i,:]), l),
    vL=factor_sum(l -> @evalexpr(pL_l_i[l,i,:] * qL_l_i[l,i,:]), l),
    qK=factor_sum(k -> @evalexpr(qK_k_i[k,i,:]), k),
    qKOpen=factor_sum(k -> @evalexpr([qK_k_i[k,i,t-1]/fq for t in default_periods()]), k),
    qI=factor_sum(k -> @evalexpr(qI_k_i[k,i,:]), k),
    # Hold the capital mix at the first reported year, so only the user cost moves.
    vKMix=factor_sum(k -> @evalexpr(pK_k_i[k,i,:] * qK_k_i[k,i,t0]), k) ./ qKBase,
    rKDepr=vKDepr / qKBase,
  )
end

function industry_series()
  data = industry_values.(industry)
  panels(value, target=v -> NaN) =
    [Panel(i, value(v), target(v)) for (i, v) in zip(industry, data)]
  return [
    (block="Production", label="Gross output", column="qY",
      description="Real gross output by industry.", panels=panels(v -> v.qY)),
    (block="Production", label="Value added", column="VA",
      description="Output less intermediate input spend, before production taxes.", panels=panels(v -> v.vVA)),
    (block="Production", label="Output price", column="pY",
      description="Basic-price output price.", panels=panels(v -> v.vY ./ v.qY)),
    (block="Labour", label="Persons", column="nL",
      description="Persons, summed over labour types.", panels=panels(v -> v.nL)),
    (block="Labour", label="Employment", column="qL",
      description="Labour in efficiency units, summed over labour types.", panels=panels(v -> v.qL)),
    (block="Labour", label="Labour share", column="wL/VA",
      description="Wages over value added.", panels=panels(v -> v.vWages ./ v.vVA)),
    (block="Labour", label="Labour user cost", column="pL",
      description="Quantity-weighted user cost of labour.", panels=panels(v -> v.vL ./ v.qL)),
    (block="Capital", label="Capital stock", column="qK",
      description="Capital stock, summed over capital types.", panels=panels(v -> v.qK)),
    (block="Capital", label="Capital-output ratio", column="K/Y",
      description="Capital over gross output.", panels=panels(v -> v.qK ./ v.qY)),
    (block="Capital", label="Capital user cost", column="pK",
      description="User cost with the capital mix held at the first reported year.", panels=panels(v -> v.vKMix)),
    (block="Investment", label="Investment", column="qI",
      description="Gross fixed investment, summed over capital types.", panels=panels(v -> v.qI)),
    (block="Investment", label="Investment rate", column="I/K",
      description="Investment over opening capital. The dotted line marks depreciation plus trend growth.",
      panels=panels(v -> v.qI ./ v.qKOpen, v -> v.rKDepr + gq)),
    (block="Investment", label="Investment value", column="vI",
      description="Nominal investment by industry.", panels=panels(v -> v.qI .* v.pI)),
  ]
end

# ============================================================================
# Closure and aggregate series
# ============================================================================
closure_panels() = [Panel(name, values) for (name, values) in [
  "Government debt over GDP" => @evalexpr(vFinPosition_s_f[:Gov,:Debt,:Liab,:] / vGDP),
  "Rest-of-world net financial assets over GDP" => @evalexpr(vNetFinAssets[:RoW,:] / vGDP),
  "Household debt over consumption" => @evalexpr(vFinPosition_s_f[:Hh,:Debt,:Liab,:] / vC),
  "Employment gap" => @evalexpr(rLEmploymentGap),
  "Wage inflation" => @evalexpr(rWInflation),
  ["Net lending over GDP: $s" => @evalexpr(vNetFinTransactions[s,:] / vGDP) for s in sector]...,
  "Net lending over GDP: all sectors" => @evalexpr(sum(vNetFinTransactions[s,:] for s in sector) / vGDP),
]]

aggregate_panels() = [Panel(name, values) for (name, values) in [
  "Real GDP" => @evalexpr(qGDP),
  "Real gross value added" => @evalexpr(qGVA),
  "Household consumption" => @evalexpr(qC),
  "Government consumption" => @evalexpr(qG),
  "Fixed investment" => @evalexpr(qI),
  "Inventory investment" => @evalexpr(qINV),
  "Exports" => @evalexpr(qX),
  "Imports" => @evalexpr(qM),
  "Gross output" => @evalexpr(sum(qY_i[i,:] for i in industry)),
  "Persons" => @evalexpr(sum(nL_l_i[l,i,:] for (l, i) in labor_l_i)),
  "Employment" => @evalexpr(sum(qL_l_i[l,i,:] for (l, i) in labor_l_i)),
  "Capital stock" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i)),
  "Investment" => @evalexpr(sum(qI_k_i[k,i,:] for (k, i) in capital_k_i)),
  "Value added over gross output" => @evalexpr(sum(vY_i[i,:] - vM_i[i,:] for i in industry) / sum(qY_i[i,:] for i in industry)),
  "Labour share" => @evalexpr(sum(vWages_i[i,:] for i in industry) / sum(vY_i[i,:] - vM_i[i,:] for i in industry)),
  "Capital-output ratio" => @evalexpr(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i) / sum(qY_i[i,:] for i in industry)),
  "Investment rate" => @evalexpr([sum(qI_k_i[k,i,t] for (k, i) in capital_k_i) /
    (sum(qK_k_i[k,i,t-1] for (k, i) in capital_k_i) / fq) for t in default_periods()]),
  "GDP price level" => @evalexpr(pGDP),
  "Wage" => @evalexpr(vW),
  "Investment price level" => @evalexpr(pI),
  "Export price level" => @evalexpr(pX),
]]

# ============================================================================
# Figures and table
# ============================================================================
"""One line per panel, indexed to its first reported value. The largest movers have coloured labels."""
function overview(panels; highlight=3)
  ranked = sort([p for p in panels if p.change !== nothing]; by=p -> abs(p.change), rev=true)
  movers = [p.name for p in first(ranked, highlight)]
  shown = [p for p in panels if count(isfinite, p.y) >= 2 && !iszero(opening(p.y))]
  styles = [p.name in movers ?
    (color=color_palette()[findfirst(==(p.name), movers)], linewidth=2.5) :
    (color=(colors().DarkGray, 0.25), linewidth=1) for p in shown]
  return plotseries([labeled(100 .* p.y ./ opening(p.y), p.name) for p in shown];
    labels=[p.name in movers ? p.name : nothing for p in shown], styles,
    ylabel="Index (first reported year = 100)",
    legend=(fig, ax, series) -> colored_text_legend!(fig, ax; columns=3),
    decorate=(ax, series) -> hlines!(ax, [100]; color=(colors().DarkGray, 0.3), linestyle=:dash))
end

"""Closing-window change for each industry and series. Rows follow the largest absolute change."""
function screening_table(series; color_scale=5.0)
  changes = [s.panels[n].change for n in eachindex(industry), s in series]
  largest = [maximum(change === nothing ? -Inf : abs(change) for change in row) for row in eachrow(changes)]
  order = sortperm(largest; rev=true)
  data = hcat(changes, [isfinite(v) ? v : nothing for v in largest])[order, :]
  return report_table(data;
    column_labels=[[[s.block for s in series]; "Maximum"], [[s.column for s in series]; "Max"]],
    merge_column_label_cells=:auto, stubhead_label="Industry", row_labels=string.(industry[order]),
    format=format_percent, shade_scale=color_scale,
    shade=(data, i, j) -> data[i, j] === nothing ? nothing : abs(data[i, j]))
end

# ============================================================================
# Report
# ============================================================================
default_path() = joinpath(@__DIR__, "..", "Output", "baseline_report.html")

# The terminal condition binds in the last solved years, so leave them out.
function report_periods()
  last_year = Time.max_terminal_year - 10
  return Time.t1:(last_year <= Time.t1 ? Time.max_terminal_year : last_year)
end

"""
Write a DREAM baseline report. Rank industries by their change over the closing
`window` years. Exclude the last ten solved years by default. Set the session's
source, periods, and operator to this baseline. A structural gap, such as an
industry with no capital, keeps its table row and has no figure panel.
"""
function write_report(baseline::ModelDictionary; path::AbstractString=default_path(),
  periods=report_periods(), window::Integer=10, color_scale::Real=5.0,
)
  @assert window > 0 && !isempty(periods) && issorted(periods) && allunique(periods) "Report periods must increase and the closing window must be positive."
  global closing_window = window
  set_default_source!(baseline)
  set_default_periods!(collect(periods))
  set_default_operator!(:n)
  series = industry_series()
  return with_dream_theme(:slide_large) do
    closure = closure_panels()
    aggregates = aggregate_panels()
    sections = [
      report_section("Closure", ["Stocks, gaps, and net lending" => with_dream_theme(:slide_small) do
        trellis([replace(p.name, " over " => "\nover ") => p.y for p in closure];
          columns=3, ylabel="", legend=false,
          decorate=(ax, lines) -> hlines!(ax, [opening(only(lines).y)];
            color=(colors().DarkGray, 0.3), linestyle=:dash))
      end]; wide=true,
        description="Check whether stocks settle. Sector net lending must sum to zero in each year."),
      report_section("Aggregates", ["Macro overview" => with_dream_theme(:slide_small) do
        trellis([replace(p.name, " over " => "\nover ") => p.y for p in aggregates];
          columns=3, ylabel="", legend=false,
          decorate=(ax, lines) -> hlines!(ax, [opening(only(lines).y)];
            color=(colors().DarkGray, 0.3), linestyle=:dash))
      end]; wide=true,
        description="Aggregate activity, expenditure, factor inputs, ratios, and prices."),
      report_section("Screening", ["Change by industry and series" => screening_table(series; color_scale)]; wide=true,
        description="Percentage change over the closing $window years. Rows follow the largest absolute change. Blank cells have no applicable series or percentage change."),
      [report_section("$(s.block): $(s.label)", [
        "All industries" => overview(s.panels),
        "By industry" => let
          panels = sort(filter(p -> any(isfinite, p.y), s.panels);
            by=p -> p.change === nothing ? -Inf : abs(p.change), rev=true)
          targets = Dict(p.name => p.target for p in panels)
          with_dream_theme(:slide_small) do
            trellis([p.name => p.y for p in panels]; columns=3,
              panel_titles=["$(p.name)  $(format_percent(p.change))" for p in panels],
              ylabel="", legend=false,
              decorate=(ax, lines) -> begin
                line = only(lines)
                hlines!(ax, [opening(line.y)]; color=(colors().DarkGray, 0.3), linestyle=:dash)
                isfinite(targets[line.label]) &&
                  hlines!(ax, [targets[line.label]]; color=colors().DREAM, linestyle=:dot)
              end)
          end
        end,
      ]; wide=true,
        description="$(s.description) Industries use the first reported value as 100, and the three largest movers have coloured labels. Panels follow the largest closing-window change, and the dashed line marks the opening value.")
        for s in series]...,
    ]
    write_html_report(path, sections; title="Baseline check report",
      subtitle="$(first(default_periods()))–$(last(default_periods())). Values are growth- and inflation-adjusted; each panel shows change relative to trend.")
  end
end

end # module
