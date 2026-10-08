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
# Report
# ============================================================================
"""
Write a DREAM report to `path` that compares `scenario` with `baseline` over
`periods`. Each function in `extra_figures` takes the level-plot options and
returns a `title => figure` pair. Leave `baseline => scenario` as the default
source, with the report periods and the `:q` operator.
"""
function write_report(path::AbstractString, baseline::ModelDictionary, scenario::ModelDictionary;
  extra_figures=(), shock_title="", periods,
)
  years = collect(periods)
  set_default_source!(baseline => scenario)
  set_default_periods!(years)
  decorate = (ax, series) -> reference_line!(ax, first(years))
  return with_dream_theme() do
    set_default_operator!([:i, :an])
    options = (; labels=[shock_title, "Baseline"], alternating_dash=true, ylabel="Index ($(first(years)) = 100)", decorate)
    levels = [
      "Real GDP" => @plot(qGDP; options...),
      (figure(options) for figure in extra_figures)...,
      "Fixed investment" => @plot(qI; options...),
      "Capital stock" => @plot(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i); options...),
    ]
    set_default_operator!(:q)
    options = (; legend=false, decorate)
    responses = [
      "Real GDP" => @plot(qGDP; options...),
      "Real gross value added" => @plot(qGVA; options...),
      "Exports" => @plot(qX; options...),
      "Fixed investment" => @plot(qI; options...),
      "Employed persons" => @plot(sum(nL_l_i[l,i,:] for (l, i) in labor_l_i); options...),
      "Wage" => @plot(vW; options...),
      "Capital stock" => @plot(sum(qK_k_i[k,i,:] for (k, i) in capital_k_i); options...),
      # Hold the capital mix at the baseline value in each year for both sources.
      "Capital user cost" => @plot(
        sum(pK_k_i[k,i,:] * $(baseline[qK_k_i[k,i,years]]) for (k, i) in capital_k_i) /
        sum($(baseline[qK_k_i[k,i,years]]) for (k, i) in capital_k_i); options...),
      "GDP price level" => @plot(pGDP; options...),
      "Investment price level" => @plot(pI; options...),
      "Export price level" => @plot(pX; options...),
      "Gross output" => @plot(sum(qY_i[i,:] for i in industry); options...),
      "Intermediate inputs" => @plot(sum(qM_m_i[m,i,:] for (m, i) in intermediate_m_i); options...),
    ]
    write_html_report(path, [
      report_section("Baseline and shock paths", levels; description="Each line uses its value in $(first(years)) as 100."),
      report_section("Detailed model responses", responses; description="Percentage deviations from the calibrated baseline."),
    ]; title="$shock_title report", subtitle="$(first(years))–$(last(years))")
  end
end

end # module
