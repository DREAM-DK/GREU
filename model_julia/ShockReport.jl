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
import GREU.InputOutput: industry, pI, pX, qI, qX, qY_i
import GREU.Intermediates: intermediate_m_i, qM_m_i
import GREU.Labor: labor_l_i, pW, qL_l_i

# ============================================================================
# Figures
# ============================================================================

function shock_axes!(axis, series, shock_year; response=false)
  @assert all(s -> all(isfinite, s.y), series) "Shock paths must be finite; percentage responses need a nonzero baseline."
  reference_line!(axis, shock_year)
  if response
    hlines!(axis, [0]; color=(colors().DarkGray, 0.3))
  end
end

function level_figures(kind, baseline, years, shock_year, label, color)
  first_year = first(years)
  capital = @evalexpr :n baseline sum(qK_k_i[k,i,first_year] for (k, i) in capital_k_i)
  options = (
    labels=[label, "Baseline"],
    styles=[(color=color,), (color=colors().DarkGray, linestyle=:dash)],
    ylabel="Index (baseline $first_year = 100)",
    decorate=(ax, series) -> shock_axes!(ax, series, shock_year),
  )
  figures = [
    "Real GDP" => @plot(:an, 100 * qGDP / $(baseline[qGDP[first_year]]); options...),
    "Real investment" => @plot(:an, 100 * qI / $(baseline[qI[first_year]]); options...),
    "Capital stock" => @plot(:an, 100 * sum(qK_k_i[k,i,:] for (k, i) in capital_k_i) / $capital; options...),
  ]
  if kind in (:export, :labor_supply, :labour_supply)
    push!(figures, "Real exports" => @plot(:an, 100 * qX / $(baseline[qX[first_year]]); options...))
  end
  if kind in (:labor_supply, :labour_supply)
    labor = @evalexpr :n baseline sum(qL_l_i[l,i,first_year] for (l, i) in labor_l_i)
    push!(figures, "Employment" => @plot(:an, 100 * sum(qL_l_i[l,i,:] for (l, i) in labor_l_i) / $labor; options...))
    return figures[[1, 5, 2, 3, 4]]
  end
  return kind == :export ? figures[[1, 4, 2, 3]] : figures
end

function response_figures(baseline, years, shock_year, color)
  options = (; legend=false, color,
    decorate=(ax, series) -> shock_axes!(ax, series, shock_year; response=true))
  return [
    "Activity — Real GDP" => @plot(qGDP; options...),
    "Activity — Real gross value added" => @plot(qGVA; options...),
    "Final demand — Real exports" => @plot(qX; options...),
    "Final demand — Real investment" => @plot(qI; options...),
    "Labour — Employment" => @plot(sum(qL_l_i[l,i,:] for (l, i) in labor_l_i); options...),
    "Labour — Nominal wage" => @plot(pW; options...),
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
  periods, shock_year::Integer, kind::Symbol=:standard,
)
  years = collect(periods)
  @assert !isempty(years) "Shock report periods cannot be empty."
  @assert shock_year in years "The shock year must be in the report periods."
  set_default_source!(baseline => scenario)
  set_default_periods!(years)
  set_default_operator!(:q)
  labor = kind in (:labor_supply, :labour_supply)
  label = labor ? "Labour-supply shock" : "$(titlecase(replace(string(kind), "_" => " "))) shock"
  color = labor ? colors().SMILE : colors().REFORM
  return with_dream_theme(:slide_large) do
    sections = [
      report_section("Baseline and shock paths", level_figures(kind, baseline, years, shock_year, label, color);
        description="Both lines use the baseline value in $(first(years)) as 100. This preserves anticipatory movements."),
      report_section("Detailed model responses", response_figures(baseline, years, shock_year, color);
        description="Percentage deviations from the calibrated baseline."),
    ]
    write_html_report(path, sections; title="$label report", subtitle="$(first(years))–$(last(years))")
  end
end

end # module
