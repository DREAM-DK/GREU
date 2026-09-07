# Build the baseline check report from a solved baseline.
# Sections run closure, aggregates, a screening table, spaghetti overviews, and
# per-industry grids for production, labour, capital, and investment.
# Read a solved database only. Do not solve, calibrate, or write model files.
#
# Values stay in growth- and inflation-adjusted coordinates, so a panel shows
# movement relative to trend rather than the level path. See the notes in
# GrowthInflationAdjustment.jl.
module BaselineReport

using Base64: base64encode
using CairoMakie
using Printf: @sprintf
using SquareModels: ModelDictionary

# ----------------------------------------------------------------------------
# Model imports.
#
# The closure block is the least certain part of this list. If the module set in
# Settings.jl omits PhillipsCurve or SectorAccounts, drop the matching import
# and the matching entries in `closure_series()`.
# ----------------------------------------------------------------------------
import GREU.Capital: capital_k_i, pK_k_i, qI_k_i, qK_k_i, rKDepr_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP, qGVA, vGDP
import GREU.GrowthInflationAdjustment: fq, gq
import GREU.InputOutput:
  industry, pI, pX, qC, qG, qI, qINV, qM, qX, qY_i, vC, vY_i
import GREU.Intermediates: vM_i
import GREU.Labor: labor_l_i, pL_l_i, pW, qL_l_i, vWages_i
import GREU.PhillipsCurve: rLEmploymentGap, rWInflation
import GREU.SectorAccounts:
  sector, vFinPosition_s_f, vNetFinAssets, vNetFinTransactions
  import GREU.Time

export write_report

# ============================================================================
# Industry names
# ============================================================================
# Industry symbols are NACE A21 sections with an `i` prefix, per
# InputOutputSettings.section_to_industry. Short names keep the screening table
# readable; pass `industry_names` to write_report to override.
const a21_names = Dict{Symbol,String}(
  :iA => "Agriculture, forestry, fishing",
  :iB => "Mining and quarrying",
  :iC => "Manufacturing",
  :iD => "Electricity, gas, steam",
  :iE => "Water, waste",
  :iF => "Construction",
  :iG => "Wholesale and retail trade",
  :iH => "Transport and storage",
  :iI => "Accommodation and food",
  :iJ => "Information and communication",
  :iK => "Finance and insurance",
  :iL => "Real estate",
  :iM => "Professional, scientific, technical",
  :iN => "Administrative and support",
  :iO => "Public administration and defence",
  :iP => "Education",
  :iQ => "Health and social work",
  :iR => "Arts and recreation",
  :iS => "Other services",
  :iT => "Households as employers",
  :iU => "Extraterritorial organisations",
)

# ============================================================================
# Style
# ============================================================================

const line_color = "#005F97"
const reference_color = (:black, 0.30)
const target_color = ("#B03A2E", 0.65)
const highlight_colors = ["#B03A2E", "#B8860B", "#2E7D32"]

const report_css = """
  body {
    margin: 0 auto;
    max-width: 1500px;
    padding: 32px;
    color: #252525;
    background: #f4f5f7;
    font-family: Arial, sans-serif;
  }
  h1 { margin: 0 0 6px; }
  h2 { margin: 0 0 4px; }
  .subtitle { margin: 0 0 28px; color: #666; }
  .report-section { margin-top: 34px; }
  .section-description { margin: 0 0 16px; color: #666; max-width: 70ch; }
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
  .card.wide { grid-column: 1 / -1; }
  .card h3 { margin: 0 0 12px; font-size: 18px; }
  .card img { display: block; width: 100%; height: auto; }
  table.screening {
    border-collapse: collapse;
    font-size: 13px;
    width: 100%;
  }
  table.screening th, table.screening td {
    padding: 5px 8px;
    text-align: right;
    border-bottom: 1px solid #eee;
    white-space: nowrap;
  }
  table.screening th.block {
    text-align: center;
    background: #ececef;
    font-size: 13px;
  }
  table.screening th.name, table.screening td.name {
    text-align: left;
    font-weight: normal;
  }
  table.screening td.name { color: #444; }
  table.screening .rule { border-left: 2px solid #b9b9bf; }
  table.screening td.rowmax { font-weight: bold; }
  table.screening tr:hover td { background: #f7f7fa; }
  .legend { margin: 10px 0 0; color: #666; font-size: 13px; }
  .missing { color: #999; }
  @media (max-width: 600px) {
    body { padding: 16px; }
    .grid { grid-template-columns: 1fr; }
  }
"""

# ============================================================================
# Value access
# ============================================================================

"""
Read one cell and return `nothing` instead of throwing.

A baseline can legitimately lack a cell: `capital_k_i` and `labor_l_i` are
masked to indices with a positive calibration-year value, so an industry such
as `iT` has no capital variables at all. A report should draw an empty panel
for those rather than fail the run.
"""
function cell_value(db, cell)
  value = try
    db[cell]
  catch
    return nothing
  end
  (value === nothing || ismissing(value)) && return nothing
  number = Float64(value)
  return isfinite(number) ? number : nothing
end

"""Evaluate a getter across years, collecting `nothing` for unavailable points."""
function series_values(db, years, getter)
  out = Vector{Union{Float64,Nothing}}(undef, length(years))
  for (n, year) in enumerate(years)
    value = try
      getter(db, year)
    catch
      nothing
    end
    out[n] = (value === nothing || ismissing(value) || !isfinite(value)) ?
      nothing : Float64(value)
  end
  return out
end

"""Drop unavailable points, returning parallel year and value vectors."""
function defined_points(years, values)
  keep = [n for n in eachindex(values) if values[n] !== nothing]
  return Float64.(years[keep]), Float64[values[n] for n in keep]
end

"""Year-on-year percentage change. The first point has no predecessor."""
function growth_transform(values)
  out = Vector{Union{Float64,Nothing}}(undef, length(values))
  out[1] = nothing
  for n in 2:length(values)
    previous, current = values[n-1], values[n]
    out[n] = (previous === nothing || current === nothing || iszero(previous)) ?
      nothing : 100 * (current / previous - 1)
  end
  return out
end

apply_view(values, view) = view == :growth ? growth_transform(values) : values

# ============================================================================
# Screening metrics
# ============================================================================

"""
Percentage change over the closing window.

The baseline is a convergence path from calibration-year stocks toward the
balanced growth path, so movement early on is expected. What matters is whether
a series has settled by the end. A large closing-window change means it has not.
"""
function late_change(years, values; window::Integer=10)
  points_years, points_values = defined_points(years, values)
  length(points_values) < 2 && return nothing
  target_year = last(points_years) - window
  index = findfirst(>=(target_year), points_years)
  index === nothing && return nothing
  base = points_values[index]
  iszero(base) && return nothing
  return 100 * (last(points_values) / base - 1)
end

"""Percentage change across the whole reported horizon."""
function total_drift(years, values)
  points_years, points_values = defined_points(years, values)
  length(points_values) < 2 && return nothing
  base = first(points_values)
  iszero(base) && return nothing
  return 100 * (last(points_values) / base - 1)
end

metric_function(metric) =
  metric == :drift ? total_drift :
  metric == :late ? late_change :
  throw(ArgumentError("Unknown screening metric $(metric). Use :late or :drift."))

format_metric(::Nothing) = "—"
format_metric(value::Real) = @sprintf("%+.1f%%", value)

# ============================================================================
# Series definitions
# ============================================================================

"""One reported series for every industry."""
struct IndustrySeries
  block::String
  label::String
  column::String
  description::String
  getter::Function                      # (db, industry, year) -> value
  target::Union{Nothing,Function}       # (db, industry) -> reference level
end

IndustrySeries(block, label, column, description, getter) =
  IndustrySeries(block, label, column, description, getter, nothing)

capital_types(i) = sort([k for (k, ind) in capital_k_i if ind == i])
labor_types(i) = sort([l for (l, ind) in labor_l_i if ind == i])

sum_or_nothing(parts) = any(isnothing, parts) ? nothing : sum(parts)

function industry_capital(db, i, year)
  types = capital_types(i)
  isempty(types) && return nothing
  return sum_or_nothing([cell_value(db, qK_k_i[k, i, year]) for k in types])
end

function industry_investment(db, i, year)
  types = capital_types(i)
  isempty(types) && return nothing
  return sum_or_nothing([cell_value(db, qI_k_i[k, i, year]) for k in types])
end

function industry_labor(db, i, year)
  types = labor_types(i)
  isempty(types) && return nothing
  return sum_or_nothing([cell_value(db, qL_l_i[l, i, year]) for l in types])
end

function industry_value_added(db, i, year)
  output = cell_value(db, vY_i[i, year])
  intermediates = cell_value(db, vM_i[i, year])
  (output === nothing || intermediates === nothing) && return nothing
  return output - intermediates
end

"""
User cost with the capital mix held at its first reported year.

Weighting by current stocks would let a shift between equipment and structures
read as a price change. `ShockReport.capital_user_cost` fixes composition for
the same reason.
"""
function industry_user_cost(db, i, year, weight_year)
  types = capital_types(i)
  isempty(types) && return nothing
  weights = [cell_value(db, qK_k_i[k, i, weight_year]) for k in types]
  prices = [cell_value(db, pK_k_i[k, i, year]) for k in types]
  (any(isnothing, weights) || any(isnothing, prices)) && return nothing
  total = sum(weights)
  iszero(total) && return nothing
  return sum(price * weight for (price, weight) in zip(prices, weights)) / total
end

"""Wage-bill-weighted user cost of labour."""
function industry_labor_cost(db, i, year)
  types = labor_types(i)
  isempty(types) && return nothing
  quantities = [cell_value(db, qL_l_i[l, i, year]) for l in types]
  prices = [cell_value(db, pL_l_i[l, i, year]) for l in types]
  (any(isnothing, quantities) || any(isnothing, prices)) && return nothing
  total = sum(quantities)
  iszero(total) && return nothing
  return sum(price * quantity for (price, quantity) in zip(prices, quantities)) / total
end

function industry_investment_rate(db, i, year)
  investment = industry_investment(db, i, year)
  opening = industry_capital(db, i, year - 1)
  (investment === nothing || opening === nothing) && return nothing
  # Growth adjustment: the accumulation equation carries the lagged stock as
  # qK[t-1]/fq, so the ratio settles on depreciation plus trend growth.
  base = opening / fq
  iszero(base) && return nothing
  return investment / base
end

"""
Steady-state investment rate: stock-weighted depreciation plus trend growth.

From the accumulation equation with a constant adjusted stock, qI/(qK/fq)
settles on `gq + δ`. Drawing it lets a panel be read against theory rather than
against its own starting point.
"""
function investment_rate_target(db, i, weight_year)
  types = capital_types(i)
  isempty(types) && return nothing
  weights = [cell_value(db, qK_k_i[k, i, weight_year]) for k in types]
  rates = [cell_value(db, rKDepr_k_i[k, i, weight_year]) for k in types]
  (any(isnothing, weights) || any(isnothing, rates)) && return nothing
  total = sum(weights)
  iszero(total) && return nothing
  depreciation = sum(rate * weight for (rate, weight) in zip(rates, weights)) / total
  return depreciation + gq
end

"""Evaluate a panel target, returning `nothing` if it is absent or unavailable."""
function safe_target(target, db, i)
  target === nothing && return nothing
  value = try
    target(db, i)
  catch
    return nothing
  end
  return (value === nothing || !isfinite(value)) ? nothing : Float64(value)
end

ratio(numerator, denominator) =
  (numerator === nothing || denominator === nothing || iszero(denominator)) ?
    nothing : numerator / denominator

"""
Series for the per-industry grids, in page order.

Each block leads with its level and follows with its diagnostic ratio. The
third entry in each block is a price or nominal view: all three are driven by
economy-wide objects with constant markups and constant tax rates, so they tend
to look alike across industries. Delete those three lines to cut the report
from twelve pages to eight.
"""
function industry_series(weight_year)
  return [
    IndustrySeries(
      "Production", "Gross output", "qY",
      "Real gross output by industry.",
      (db, i, year) -> cell_value(db, qY_i[i, year]),
    ),
    IndustrySeries(
      "Production", "Value added", "VA",
      "Output less intermediate input spend, before production taxes.",
      (db, i, year) -> industry_value_added(db, i, year),
    ),
    IndustrySeries(
      "Production", "Output price", "pY",
      "Basic-price output price. Constant markups make this a null panel.",
      (db, i, year) -> cell_value(db, qY_i[i, year]) === nothing ? nothing :
        cell_value(db, vY_i[i, year]) === nothing ? nothing :
        ratio(cell_value(db, vY_i[i, year]), cell_value(db, qY_i[i, year])),
    ),
    IndustrySeries(
      "Labour", "Employment", "qL",
      "Labour in efficiency units, summed over labour types.",
      (db, i, year) -> industry_labor(db, i, year),
    ),
    IndustrySeries(
      "Labour", "Labour share", "wL/VA",
      "Wages over value added. A trendless ratio, so slow drift is visible.",
      (db, i, year) -> ratio(
        cell_value(db, vWages_i[i, year]),
        industry_value_added(db, i, year),
      ),
    ),
    IndustrySeries(
      "Labour", "Labour user cost", "pL",
      "Quantity-weighted user cost of labour. Driven by the common wage.",
      (db, i, year) -> industry_labor_cost(db, i, year),
    ),
    IndustrySeries(
      "Capital", "Capital stock", "qK",
      "Capital stock, summed over capital types.",
      (db, i, year) -> industry_capital(db, i, year),
    ),
    IndustrySeries(
      "Capital", "Capital-output ratio", "K/Y",
      "Capital over gross output. Sensitive to a badly behaved long horizon.",
      (db, i, year) -> ratio(
        industry_capital(db, i, year),
        cell_value(db, qY_i[i, year]),
      ),
    ),
    IndustrySeries(
      "Capital", "Capital user cost", "pK",
      "User cost with the capital mix held at the first reported year.",
      (db, i, year) -> industry_user_cost(db, i, year, weight_year),
    ),
    IndustrySeries(
      "Investment", "Investment", "qI",
      "Gross fixed investment, summed over capital types.",
      (db, i, year) -> industry_investment(db, i, year),
    ),
    IndustrySeries(
      "Investment", "Investment rate", "I/K",
      "Investment over the opening stock. The dotted line is depreciation plus trend growth.",
      (db, i, year) -> industry_investment_rate(db, i, year),
      (db, i) -> investment_rate_target(db, i, weight_year),
    ),
    IndustrySeries(
      "Investment", "Investment value", "vI",
      "Nominal investment. The investment price has no industry dimension.",
      (db, i, year) -> industry_investment_value(db, i, year),
    ),
  ]
end

# ============================================================================
# Aggregate series
# ============================================================================

total_over(db, year, cells) = sum_or_nothing([cell_value(db, cell) for cell in cells])

total_output(db, year) = total_over(db, year, [qY_i[i, year] for i in industry])
total_labor(db, year) = total_over(db, year, [qL_l_i[l, i, year] for (l, i) in labor_l_i])
total_capital(db, year) = total_over(db, year, [qK_k_i[k, i, year] for (k, i) in capital_k_i])
total_investment(db, year) = total_over(db, year, [qI_k_i[k, i, year] for (k, i) in capital_k_i])
total_value_added(db, year) =
  sum_or_nothing([industry_value_added(db, i, year) for i in industry])
total_wages(db, year) = total_over(db, year, [vWages_i[i, year] for i in industry])



"""Nominal investment by industry. The investment price has no industry dimension."""
function industry_investment_value(db, i, year)
  quantity = industry_investment(db, i, year)
  price = cell_value(db, pI[year])
  (quantity === nothing || price === nothing) && return nothing
  return quantity * price
end

"""Net lending summed over sectors, as a share of GDP. Should be zero every year."""
function total_net_lending_ratio(db, year)
  parts = [cell_value(db, vNetFinTransactions[s, year]) for s in sector]
  gdp = cell_value(db, vGDP[year])
  (any(isnothing, parts) || gdp === nothing || iszero(gdp)) && return nothing
  return sum(parts) / gdp
end

"""Economy-wide investment over the opening stock, carried as qK[t-1]/fq."""
function total_investment_rate(db, year)
  opening = total_capital(db, year - 1)
  investment = total_investment(db, year)
  (opening === nothing || investment === nothing || iszero(opening)) && return nothing
  return investment / (opening / fq)
end

"""
Closure checks: do the stocks settle?

The architecture notes say there is no fiscal closure by default and government
debt drifts. Over six years that is cosmetic. Over thirty it compounds through
FinancialIncome into sector incomes and consumption, so an unbounded stock
turns the rest of the report into an artefact. Read this section first.
"""
function closure_series()
  series = Pair{String,Function}[
    "Government debt over GDP" =>
      ((db, year) -> ratio(
        cell_value(db, vFinPosition_s_f[:Gov, :Debt, :Liab, year]),
        cell_value(db, vGDP[year]),
      )),
    "Rest-of-world net financial assets over GDP" =>
      ((db, year) -> ratio(
        cell_value(db, vNetFinAssets[:RoW, year]),
        cell_value(db, vGDP[year]),
      )),
    "Household debt over consumption" =>
      ((db, year) -> ratio(
        cell_value(db, vFinPosition_s_f[:Hh, :Debt, :Liab, year]),
        cell_value(db, vC[year]),
      )),
    "Employment gap" => ((db, year) -> cell_value(db, rLEmploymentGap[year])),
    "Wage inflation" => ((db, year) -> cell_value(db, rWInflation[year])),
  ]
  for s in sector
    push!(
      series,
      "Net lending over GDP: $(s)" =>
        ((db, year) -> ratio(
          cell_value(db, vNetFinTransactions[s, year]),
          cell_value(db, vGDP[year]),
        )),
    )
  end
  push!(
    series,
    "Net lending over GDP: all sectors" => total_net_lending_ratio,
  )
  return series
end

"""Macro overview: the expenditure frame, block totals, ratios, and prices."""
function aggregate_series()
  return Pair{String,Function}[
    "Real GDP" => ((db, year) -> cell_value(db, qGDP[year])),
    "Real gross value added" => ((db, year) -> cell_value(db, qGVA[year])),
    "Household consumption" => ((db, year) -> cell_value(db, qC[year])),
    "Government consumption" => ((db, year) -> cell_value(db, qG[year])),
    "Fixed investment" => ((db, year) -> cell_value(db, qI[year])),
    "Inventory investment" => ((db, year) -> cell_value(db, qINV[year])),
    "Exports" => ((db, year) -> cell_value(db, qX[year])),
    "Imports" => ((db, year) -> cell_value(db, qM[year])),
    "Gross output" => total_output,
    "Employment" => total_labor,
    "Capital stock" => total_capital,
    "Investment" => total_investment,
    "Value added over gross output" =>
      ((db, year) -> ratio(total_value_added(db, year), total_output(db, year))),
    "Labour share" =>
      ((db, year) -> ratio(total_wages(db, year), total_value_added(db, year))),
    "Capital-output ratio" =>
      ((db, year) -> ratio(total_capital(db, year), total_output(db, year))),
    "Investment rate" => total_investment_rate,
    "GDP price level" => ((db, year) -> cell_value(db, pGDP[year])),
    "Wage" => ((db, year) -> cell_value(db, pW[year])),
    "Investment price level" => ((db, year) -> cell_value(db, pI[year])),
    "Export price level" => ((db, year) -> cell_value(db, pX[year])),
  ]
end

# ============================================================================
# Panels
# ============================================================================

function panel_axis(figure, position, title)
  return Axis(
    figure[position...];
    title,
    titlesize=13,
    titlealign=:left,
    xticklabelsize=10,
    yticklabelsize=10,
    xgridvisible=false,
    ygridcolor=(:black, 0.06),
  )
end

"""
Draw one panel.

Axes are free per panel, so the reference line at the opening value and the
metric in the title carry the magnitude the shared axis would have given.
"""
function draw_panel!(figure, position, years, values, title; target=nothing)
  axis = panel_axis(figure, position, title)
  point_years, point_values = defined_points(years, values)

  if isempty(point_values)
    hidedecorations!(axis)
    hidespines!(axis)
    text!(
      axis, 0.5, 0.5;
      text="no data", space=:relative, align=(:center, :center),
      color=(:black, 0.35), fontsize=11,
    )
    return axis
  end

  hlines!(axis, [first(point_values)]; color=reference_color, linewidth=1, linestyle=:dash)
  if target !== nothing && isfinite(target)
    hlines!(axis, [target]; color=target_color, linewidth=1, linestyle=:dot)
  end
  lines!(axis, point_years, point_values; color=line_color, linewidth=2)
  return axis
end

panel_title(name, metric) = "$(name)  $(format_metric(metric))"

"""
Grid of one series across every industry, three columns wide.

Panels are ordered by the screening metric so the largest movers sit in the top
row and the rest of the page is confirmation.
"""
function grid_figure(years, entries; columns::Integer=3)
  rows = max(1, cld(length(entries), columns))
  figure = Figure(size=(columns * 340, rows * 205))
  for (n, entry) in enumerate(entries)
    row = cld(n, columns)
    column = mod(n - 1, columns) + 1
    draw_panel!(
      figure, (row, column), years, entry.values,
      panel_title(entry.name, entry.metric);
      target=entry.target,
    )
  end
  return figure
end

"""
Every industry on one set of axes, indexed to the opening year.

Individual lines are not readable and are not meant to be. The envelope is:
if one line leaves the bundle, the screening table names it.
"""
function spaghetti_figure(years, entries)
  figure = Figure(size=(760, 440))
  axis = Axis(
    figure[1, 1];
    xlabel="Year",
    ylabel="Index (first reported year = 100)",
    xgridvisible=false,
    ygridcolor=(:black, 0.06),
  )

  ranked = sort(
    [e for e in entries if e.metric !== nothing];
    by=e -> -abs(e.metric),
  )
  highlighted = Set(e.name for e in first(ranked, min(3, length(ranked))))

  for entry in entries
    point_years, point_values = defined_points(years, entry.values)
    (length(point_values) < 2 || iszero(first(point_values))) && continue
    indexed = 100 .* point_values ./ first(point_values)
    if entry.name in highlighted
      order = findfirst(==(entry.name), [e.name for e in ranked])
      color = highlight_colors[min(order, length(highlight_colors))]
      lines!(axis, point_years, indexed; color, linewidth=2.5, label=entry.name)
    else
      lines!(axis, point_years, indexed; color=(:black, 0.28), linewidth=1)
    end
  end

  hlines!(axis, [100.0]; color=reference_color, linewidth=1, linestyle=:dash)
  isempty(highlighted) || axislegend(axis; position=:lt, framevisible=false, labelsize=11)
  return figure
end

# ============================================================================
# Screening table
# ============================================================================

"""Shade a cell from white to red by the absolute metric, capped at `scale`."""
function cell_style(value, scale)
  value === nothing && return ""
  intensity = min(abs(value) / scale, 1.0)
  red = 255
  green = round(Int, 255 - 120 * intensity)
  blue = round(Int, 255 - 130 * intensity)
  return " style=\"background: rgb($red,$green,$blue)\""
end

function screening_table_html(series_list, industries, metrics, industry_names, scale)
  blocks = String[]
  for s in series_list
    (isempty(blocks) || last(blocks) != s.block) && push!(blocks, s.block)
  end

  block_header = ["<th class=\"name\" rowspan=\"2\">Industry</th>"]
  for block in blocks
    span = count(s -> s.block == block, series_list)
    push!(block_header, "<th class=\"block rule\" colspan=\"$span\">$block</th>")
  end
  push!(block_header, "<th class=\"rule\" rowspan=\"2\">Max</th>")

  column_header = String[]
  previous_block = ""
  for s in series_list
    class = s.block == previous_block ? "" : " class=\"rule\""
    push!(column_header, "<th$class>$(s.column)</th>")
    previous_block = s.block
  end

  rows = String[]
  for i in industries
    cells = String[]
    row_values = Union{Float64,Nothing}[]
    previous_block = ""
    for s in series_list
      value = get(metrics, (s.label, i), nothing)
      push!(row_values, value)
      class = s.block == previous_block ? "" : " class=\"rule\""
      push!(cells, "<td$class$(cell_style(value, scale))>$(format_metric(value))</td>")
      previous_block = s.block
    end
    present = [abs(v) for v in row_values if v !== nothing]
    row_max = isempty(present) ? nothing : maximum(present)
    name = get(industry_names, i, "")
    label = isempty(name) ? String(i) : "$(i) &middot; $name"
    push!(rows, """
      <tr>
        <td class="name">$label</td>
        $(join(cells, "\n        "))
        <td class="rule rowmax">$(format_metric(row_max))</td>
      </tr>
    """)
  end

  return """
    <table class="screening">
      <thead>
        <tr>$(join(block_header, ""))</tr>
        <tr>$(join(column_header, ""))</tr>
      </thead>
      <tbody>
        $(join(rows, "\n"))
      </tbody>
    </table>
  """
end

# ============================================================================
# HTML assembly
# ============================================================================

function figure_card(title, figure, temporary_dir, index; wide::Bool=false)
  path = joinpath(temporary_dir, "figure_$(index).svg")
  save(path, figure)
  svg = base64encode(read(path))
  class = wide ? "card wide" : "card"
  return """
    <article class="$class">
      <h3>$title</h3>
      <img src="data:image/svg+xml;base64,$svg" alt="$title">
    </article>
  """
end

function section_html(title, description, cards)
  return """
    <section class="report-section">
      <h2>$title</h2>
      <p class="section-description">$description</p>
      <div class="grid">
        $(join(cards, "\n"))
      </div>
    </section>
  """
end

function report_html(title, subtitle, sections)
  return """<!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>$title</title>
    <style>
    $report_css
    </style>
  </head>
  <body>
    <h1>$title</h1>
    <p class="subtitle">$subtitle</p>
    $(join(sections, "\n"))
  </body>
  </html>
  """
end

# ============================================================================
# Public interface
# ============================================================================
"""Default output path, beside the baseline the calibration writes."""
default_path() = joinpath(@__DIR__, "..", "Output", "baseline_report.html")

"""
Default reported horizon: the solved horizon less a terminal buffer.

The capital terminal condition (`qK[T] == qK[T-1]`) and the Phillips-curve
terminal equation distort the closing years. Keeping them off the page stops
them being read as model behaviour. A short horizon has no room for the buffer,
so it falls back to the full span.
"""
function default_periods(; terminal_buffer::Integer=10)
  first_year = Time.t1
  last_year = Time.max_terminal_year - terminal_buffer
  last_year <= first_year && return first_year:Time.max_terminal_year
  return first_year:last_year
end

"""
    write_report(baseline; kwargs...)

Write one self-contained HTML check report for a solved baseline.

Call it as the last line of `Calibrate.jl`, where `baseline` is already in
scope. Every setting has a default, so the call needs no arguments.

Sections run in reading order: closure first, because an unbounded stock makes
the rest of the report an artefact of that stock; then the macro aggregates;
then a screening table and spaghetti overviews that say which industries to
look at; then the per-industry grids.

Keyword arguments:

- `path`: output file.
- `periods`: years to report. Defaults to the solved horizon less ten years.
- `views`: `[:level]`, `[:growth]`, or both. The growth view shows year-on-year
  percentage change, in which a settling series decays toward zero.
- `metric`: `:late` ranks by movement over the closing window and is the
  convergence check. `:drift` ranks by change across the whole horizon.
- `late_window`: length of the closing window, in years.
- `color_scale`: metric magnitude, in percent, at which a table cell is fully
  shaded.
- `industry_names`: `Symbol => String` map, so rows read as names rather than
  section codes.
"""
function write_report(
  baseline::ModelDictionary;
  path::AbstractString=default_path(),
  periods=default_periods(),
  views::Vector{Symbol}=[:level],
  metric::Symbol=:late,
  late_window::Integer=10,
  color_scale::Real=5.0,
  industry_names::Dict{Symbol,String}=a21_names,
)
  years = collect(periods)
  isempty(years) && throw(ArgumentError("Baseline report periods cannot be empty."))
  all(v -> v in (:level, :growth), views) ||
    throw(ArgumentError("Views must be :level or :growth."))

  weight_year = first(years)
  series_list = industry_series(weight_year)
  score = metric_function(metric)
  industries = collect(industry)

  # Evaluate once. Panels, the table, and the spaghetti charts share the values.
  levels = Dict{Tuple{String,Symbol},Vector{Union{Float64,Nothing}}}()
  metrics = Dict{Tuple{String,Symbol},Union{Float64,Nothing}}()
  for s in series_list, i in industries
    values = series_values(baseline, years, (db, year) -> s.getter(db, i, year))
    levels[(s.label, i)] = values
    metrics[(s.label, i)] = metric === :late ?
      score(years, values; window=late_window) : score(years, values)
  end

  sections = String[]
  mktempdir() do temporary_dir
    index = 0
    next_index() = (index += 1)

    # ---- Closure -----------------------------------------------------------
    for view in views
      cards = [
        figure_card(
          label,
          begin
            values = apply_view(series_values(baseline, years, getter), view)
            figure = Figure(size=(480, 300))
            draw_panel!(figure, (1, 1), years, values, label)
            figure
          end,
          temporary_dir, next_index(),
        )
        for (label, getter) in closure_series()
      ]
      push!(sections, section_html(
        "Closure$(view == :growth ? " (year-on-year)" : "")",
        "Do the stocks settle? Nothing forces the fiscal or external gaps to " *
        "average out, so a stock can walk without bound over a long horizon. " *
        "Sector net lending must sum to zero every year.",
        cards,
      ))
    end

    # ---- Aggregates --------------------------------------------------------
    for view in views
      entries = [
        (name=label, values=apply_view(series_values(baseline, years, getter), view),
         metric=nothing, target=nothing)
        for (label, getter) in aggregate_series()
      ]
      figure = grid_figure(years, entries)
      push!(sections, section_html(
        "Aggregates$(view == :growth ? " (year-on-year)" : "")",
        "The expenditure frame, the four block totals and their economy-wide " *
        "ratios, and prices. These are the paths the industry panels deviate from.",
        [figure_card("Macro overview", figure, temporary_dir, next_index(); wide=true)],
      ))
    end

    # ---- Screening table ---------------------------------------------------
    window_text = metric === :late ?
      "change over the closing $(late_window) years" :
      "change across the reported horizon"
    push!(sections, section_html(
      "Screening",
      "One number per industry and series: $window_text. The baseline is a " *
      "convergence path from calibration-year stocks, so early movement is " *
      "expected and a series that is still moving at the end is not. Cells " *
      "shade toward red with magnitude; the Max column carries the sort key.",
      ["""
        <article class="card wide">
          <h3>Movement by industry and series</h3>
          $(screening_table_html(series_list, industries, metrics, industry_names, color_scale))
          <p class="legend">Blank cells have no variable for that industry. Capital
          and labour indices are masked to cells with a positive calibration-year
          value, so an industry can legitimately have no capital at all.</p>
        </article>
      """],
    ))

    # ---- Spaghetti ---------------------------------------------------------
    spaghetti_cards = [
      figure_card(
        "$(s.block): $(s.label)",
        spaghetti_figure(years, [
          (name=String(i), values=levels[(s.label, i)],
           metric=metrics[(s.label, i)], target=nothing)
          for i in industries
        ]),
        temporary_dir, next_index(),
      )
      for s in series_list
    ]
    push!(sections, section_html(
      "Overview by series",
      "Every industry on one set of axes, indexed to the first reported year. " *
      "Read the envelope, not the lines. The three largest movers are drawn in " *
      "colour and named.",
      spaghetti_cards,
    ))

    # ---- Industry grids ----------------------------------------------------
    for view in views, s in series_list
      entries = [
        (
          name=String(i),
          values=apply_view(levels[(s.label, i)], view),
          metric=metrics[(s.label, i)],
          target=view == :level ? safe_target(s.target, baseline, i) : nothing,
        )
        for i in industries
      ]
      sort!(entries; by=e -> e.metric === nothing ? -Inf : -abs(e.metric))
      figure = grid_figure(years, entries)
      push!(sections, section_html(
        "$(s.block): $(s.label)$(view == :growth ? " (year-on-year)" : "")",
        "$(s.description) Panels are ordered by movement, largest first. The " *
        "dashed line marks the first reported value; axes are free per panel, " *
        "so the figure in each title carries the magnitude.",
        [figure_card(
          "$(s.label) by industry", figure, temporary_dir, next_index(); wide=true,
        )],
      ))
    end
  end

  html = report_html(
    "Baseline check report",
    "$(first(years))–$(last(years)). Values are growth- and inflation-adjusted, " *
    "so a panel shows movement relative to trend.",
    sections,
  )

  mkpath(dirname(path))
  write(path, html)
  @info "Wrote HTML baseline report" path = abspath(path)
  return String(path)
end

end # module