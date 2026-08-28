module ShockReport

using Base64: base64encode
using CairoMakie
using SquareModels: ModelDictionary

export write_report

import ..Capital: capital_k_i, pK_k_i, qK_k_i
import ..FixedBasePriceAggregates: pGDP, qGDP, qGVA
import ..InputOutput: industry, pI, pX, qI, qX, qY_i
import ..Intermediates: intermediate_m_i, qM_m_i
import ..Labor: labor_l_i, pW, qL_l_i

# ============================================================================
# Style
# ============================================================================

const baseline_color = "#666666"
const default_shock_color = "#005F97"

const report_css = """
  body {
    margin: 0 auto;
    max-width: 1500px;
    padding: 32px;
    color: #252525;
    background: #f4f5f7;
    font-family: Arial, sans-serif;
  }
  h1 { margin: 0 0 28px; }
  h2 { margin: 0 0 4px; }
  .report-section { margin-top: 34px; }
  .section-description { margin: 0 0 16px; color: #666; }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(480px, 1fr));
    gap: 20px;
  }
  .card {
    padding: 18px;
    overflow: hidden;
    background: white;
    border: 1px solid #ddd;
    border-radius: 8px;
  }
  .card h3 { margin: 0 0 12px; font-size: 18px; }
  .card img { display: block; width: 100%; height: auto; }
  @media (max-width: 600px) {
    body { padding: 16px; }
    .grid { grid-template-columns: 1fr; }
  }
"""

function report_style(kind)
  kind == :export && return (label="Export shock", color="#0072B2")
  kind in (:labor_supply, :labour_supply) &&
    return (label="Labour-supply shock", color="#D55E00")

  name = titlecase(replace(string(kind), "_" => " "))
  return (label="$name shock", color=default_shock_color)
end

# ============================================================================
# Report series
# ============================================================================

function report_value(db, cell)
  value = db[cell]
  if value === nothing || ismissing(value)
    throw(ArgumentError("Shock report is missing a value for $(cell)."))
  end
  return Float64(value)
end

real_gdp(db, year) = report_value(db, qGDP[year])
real_gva(db, year) = report_value(db, qGVA[year])
real_exports(db, year) = report_value(db, qX[year])
real_investment(db, year) = report_value(db, qI[year])
nominal_wage(db, year) = report_value(db, pW[year])
gdp_price(db, year) = report_value(db, pGDP[year])
investment_price(db, year) = report_value(db, pI[year])
export_price(db, year) = report_value(db, pX[year])

function total_labor(db, year)
  return sum(
    report_value(db, qL_l_i[l,i,year])
    for (l, i) in labor_l_i
  )
end

function total_capital(db, year)
  return sum(
    report_value(db, qK_k_i[k,i,year])
    for (k, i) in capital_k_i
  )
end

function total_gross_output(db, year)
  return sum(report_value(db, qY_i[i,year]) for i in industry)
end

function total_intermediates(db, year)
  return sum(
    report_value(db, qM_m_i[m,i,year])
    for (m, i) in intermediate_m_i
  )
end

# Hold capital composition fixed at its baseline value. The aggregate then
# measures a user-cost change rather than a change in capital composition.
function capital_user_cost(db, baseline, year)
  baseline_quantity = total_capital(baseline, year)
  iszero(baseline_quantity) &&
    throw(ArgumentError("Baseline capital is zero in $(year)."))

  value = sum(
    report_value(db, pK_k_i[k,i,year]) *
    report_value(baseline, qK_k_i[k,i,year])
    for (k, i) in capital_k_i
  )
  return value / baseline_quantity
end

function level_series(kind)
  if kind == :export
    return [
      "Real GDP" => real_gdp,
      "Real exports" => real_exports,
      "Real investment" => real_investment,
      "Capital stock" => total_capital,
    ]
  elseif kind in (:labor_supply, :labour_supply)
    return [
      "Real GDP" => real_gdp,
      "Employment" => total_labor,
      "Real investment" => real_investment,
      "Capital stock" => total_capital,
      "Real exports" => real_exports,
    ]
  end

  return [
    "Real GDP" => real_gdp,
    "Real investment" => real_investment,
    "Capital stock" => total_capital,
  ]
end

function response_series(baseline)
  return [
    "Activity — Real GDP" => real_gdp,
    "Activity — Real gross value added" => real_gva,
    "Final demand — Real exports" => real_exports,
    "Final demand — Real investment" => real_investment,
    "Labour — Employment" => total_labor,
    "Labour — Nominal wage" => nominal_wage,
    "Capital — Stock" => total_capital,
    "Capital — User cost" =>
      ((db, year) -> capital_user_cost(db, baseline, year)),
    "Prices — GDP price level" => gdp_price,
    "Prices — Investment price level" => investment_price,
    "Prices — Export price level" => export_price,
    "Production — Gross output" => total_gross_output,
    "Production — Intermediate inputs" => total_intermediates,
  ]
end

# ============================================================================
# Figures
# ============================================================================

function percent_response(baseline_value, scenario_value)
  iszero(baseline_value) &&
    throw(ArgumentError("Cannot calculate a percentage response from a zero baseline."))
  response = 100 * (scenario_value / baseline_value - 1)
  return abs(response) < 1e-10 ? 0.0 : response
end

function response_values(years, baseline, scenario, getter)
  return [
    percent_response(getter(baseline, year), getter(scenario, year))
    for year in years
  ]
end

function year_ticks(years)
  if length(years) <= 12
    ticks = years
  else
    tick_step = ceil(Int, (length(years) - 1) / 10)
    ticks = collect(first(years):tick_step:last(years))
    last(ticks) == last(years) || push!(ticks, last(years))
  end
  return ticks, string.(Int.(ticks))
end

percent_tick_labels(values) =
  ["$(round(value; digits=2))%" for value in values]

function report_axis(figure, years, ylabel)
  ticks, labels = year_ticks(years)
  return Axis(
    figure[1, 1];
    xlabel="Year",
    ylabel,
    xticks=(ticks, labels),
    xgridvisible=false,
    ygridcolor=(:black, 0.08),
  )
end

function add_shock_year!(axis, shock_year)
  vlines!(
    axis,
    [shock_year];
    color=(:black, 0.45),
    linestyle=:dash,
    linewidth=1.5,
  )
  return nothing
end

function response_figure(years, baseline, scenario, getter, color, shock_year)
  response = response_values(years, baseline, scenario, getter)

  figure = Figure(size=(700, 400))
  axis = report_axis(figure, years, "Percent deviation from baseline")
  axis.ytickformat[] = percent_tick_labels

  hlines!(axis, [0.0]; color=(:black, 0.25), linewidth=1)
  add_shock_year!(axis, shock_year)
  lines!(axis, years, response; color, linewidth=3)

  limit = max(1.15 * maximum(abs, response), 0.05)
  ylims!(axis, -limit, limit)
  return figure
end

function level_figure(
  years,
  baseline,
  scenario,
  getter,
  scenario_label,
  color,
  shock_year,
)
  reference_value = getter(baseline, first(years))
  iszero(reference_value) &&
    throw(ArgumentError("Cannot index a level path from a zero baseline."))

  baseline_index = [100 * getter(baseline, year) / reference_value for year in years]
  scenario_index = [100 * getter(scenario, year) / reference_value for year in years]

  figure = Figure(size=(700, 400))
  axis = report_axis(
    figure,
    years,
    "Index (baseline $(first(years)) = 100)",
  )

  add_shock_year!(axis, shock_year)
  lines!(
    axis,
    years,
    baseline_index;
    color=baseline_color,
    linestyle=:dash,
    linewidth=2.5,
    label="Baseline",
  )
  lines!(
    axis,
    years,
    scenario_index;
    color,
    linewidth=3,
    label=scenario_label,
  )
  axislegend(axis; position=:rt, framevisible=false)
  return figure
end

function report_sections(kind, years, shock_year, baseline, scenario)
  style = report_style(kind)
  return [
    (
      title="Baseline and shock paths",
      description="Both lines use the baseline value in $(first(years)) as 100, so anticipatory movements are preserved.",
      figures=[
        title => level_figure(
          years,
          baseline,
          scenario,
          getter,
          style.label,
          style.color,
          shock_year,
        )
        for (title, getter) in level_series(kind)
      ],
    ),
    (
      title="Detailed model responses",
      description="Each figure shows the percentage deviation from the calibrated baseline.",
      figures=[
        title => response_figure(
          years,
          baseline,
          scenario,
          getter,
          style.color,
          shock_year,
        )
        for (title, getter) in response_series(baseline)
      ],
    ),
  ]
end

# ============================================================================
# HTML
# ============================================================================

function render_sections(sections)
  section_html = String[]

  mktempdir() do temporary_dir
    figure_index = 0
    for section in sections
      cards = String[]
      for (title, figure) in section.figures
        figure_index += 1
        svg_path = joinpath(temporary_dir, "figure_$(figure_index).svg")
        save(svg_path, figure)
        svg = base64encode(read(svg_path))

        push!(cards, """
          <article class="card">
            <h3>$title</h3>
            <img src="data:image/svg+xml;base64,$svg" alt="$title">
          </article>
        """)
      end

      push!(section_html, """
        <section class="report-section">
          <h2>$(section.title)</h2>
          <p class="section-description">$(section.description)</p>
          <div class="grid">
            $(join(cards, "\n"))
          </div>
        </section>
      """)
    end
  end

  return join(section_html, "\n")
end

function report_html(browser_title, sections)
  return """<!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>$browser_title</title>
    <style>
    $report_css
    </style>
  </head>
  <body>
    <h1>Shock report</h1>
    $sections
  </body>
  </html>
  """
end

# ============================================================================
# Public interface
# ============================================================================

"""
Write one self-contained HTML report comparing a solved shock scenario with
the calibrated baseline.

`kind` controls the report label, colour, and overview figures. Use `:export`
or `:labor_supply` for the tailored reports, or another symbol for the standard
overview.
"""
function write_report(
  path::AbstractString,
  baseline::ModelDictionary,
  scenario::ModelDictionary;
  periods,
  shock_year::Integer,
  kind::Symbol=:standard,
)
  years = collect(periods)
  isempty(years) && throw(ArgumentError("Shock report periods cannot be empty."))
  shock_year in years ||
    throw(ArgumentError("Shock year $(shock_year) must be included in report periods."))

  style = report_style(kind)
  sections = render_sections(
    report_sections(kind, years, shock_year, baseline, scenario),
  )
  html = report_html("$(style.label) report", sections)

  mkpath(dirname(path))
  write(path, html)
  @info "Wrote HTML shock report" path=abspath(path)
  return String(path)
end

end # module
