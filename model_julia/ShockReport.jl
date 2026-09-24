# Compare solved shock paths with the calibrated baseline.
# Use SquareModels settings and the shared DREAM report style.
# Do not solve or change model values.
module ShockReport

using CairoMakie
using DREAMMakieTheme
using SquareModels: ModelDictionary, @plot,
  set_default_source!, set_default_periods!, set_default_operator!

import GREU.Capital: capital_k_i, pK_k_i, qK_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP, qGVA
import GREU.InputOutput: industry, pI, pX, qI, qX, qY_i
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
      report_section("Detailed model responses", response_figures(baseline, years);
        description="Percentage deviations from the calibrated baseline."),
    ]
    write_html_report(path, sections; title="$shock_title report", subtitle="$(periods[1])–$(last(periods))")
  end
end

end # module
