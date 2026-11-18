# Write HTML tables of the baseline in one year: input quantities over output, and the parts of
# output value, by industry. Then wages, and persons by labor type and industry in numbers and shares.
# Write the same numbers as Danish bar charts in a second HTML file.
# Values are growth- and inflation-adjusted model units in million EUR.
# Include DAProductivityShockFigures.jl first; this file uses its charts.
# Do not solve, calibrate, or change model values.
module BaselineTables

using SquareModels: ModelDictionary
import ..DAProductivityShockFigures: chart, stacked_chart, legend_html, fmt, type_colors
import GREU.InputOutput: industry, industry_label, qY_i, vY_i
import GREU.Capital: qK_k_i
import GREU.Intermediates: qM_m_i
import GREU.Labor: nL_l_i, qL_l_i, vW_l
import GREU.Production: factor_i, labor_l_i, pProd, qProd, topNest, pMarginalCost_i, qFixedCost_i, qProductionLoss,
  vntProductionOther_i
import GREU.Pricing: rMarkup_i
import GREU.ProductionSettings: labor_type
import GREU.Settings: calibration_year
import GREU.Time

# ============================================================================
# Values
# ============================================================================
# Each input is a quantity variable and the production leaves it sums over.
const inputs = [
  "K" => (qK_k_i, [:equipment]),
  "E" => (qM_m_i, [:energy]),
  "L" => (qL_l_i, labor_type),
  "B" => (qK_k_i, [:structures]),
  "M" => (qM_m_i, [:materials]),
]

function value(db, ref)
  x = db[ref]
  @assert x isa Real && isfinite(x) "$ref has no finite baseline value"
  return x
end

average(xs) = (live = collect(skipmissing(xs)); sum(live) / length(live))

"""Quantity of an input over output. Missing when industry `i` uses none of its leaves."""
function input_ratio(db, (q, leaves), i, year)
  live = [n for n in leaves if (n, i) in factor_i]
  isempty(live) && return missing
  return sum(value(db, q[n,i,year]) for n in live) / value(db, qY_i[i,year])
end

industry_row(db, i, year) = [value(db, qY_i[i,year]); [input_ratio(db, input, i, year) for input in last.(inputs)]]

"""Cost of an input in percent of output value. Capital cost is the user cost. Labor cost includes production taxes."""
function input_cost_share(db, (_, leaves), i, year)
  live = [n for n in leaves if (n, i) in factor_i]
  isempty(live) && return missing
  return 100 * sum(value(db, pProd[n,i,year]) * value(db, qProd[n,i,year]) for n in live) / value(db, vY_i[i,year])
end

"""
Output value, then its parts in percent: input costs, markup, other production taxes,
less the fixed cost and the production loss, and their sum. Input costs include the use of
the input bundle for the fixed cost and the production loss, so these two enter with a minus.
"""
function value_row(db, i, year)
  vY = value(db, vY_i[i,year])
  bundle_share(q) = -100 * value(db, pProd[topNest[i],i,year]) * value(db, q[i,year]) / vY
  parts = [
    [input_cost_share(db, input, i, year) for input in last.(inputs)];
    100 * value(db, rMarkup_i[i,year]) * value(db, pMarginalCost_i[i,year]) * value(db, qY_i[i,year]) / vY;
    100 * value(db, vntProductionOther_i[i,year]) / vY;
    bundle_share(qFixedCost_i);
    bundle_share(qProductionLoss)
  ]
  return [vY; parts; sum(skipmissing(parts))]
end

persons(db, l, i, year) = (l, i) in labor_l_i ? value(db, nL_l_i[l,i,year]) : missing

column_averages(rows) = [average(getindex.(rows, j)) for j in eachindex(first(rows))]

"""Numbers behind the tables and figures. Each field holds one row per industry, except `wage`."""
function table_data(db, year)
  @assert year in calibration_year:Time.max_terminal_year "Pick a year from $calibration_year to $(Time.max_terminal_year)"
  headcount = [[persons(db, l, i, year) for l in labor_type] for i in industry]
  return (;
    production=[industry_row(db, i, year) for i in industry],
    output_value=[value_row(db, i, year) for i in industry],
    wage=[1000 * value(db, vW_l[l,year]) for l in labor_type],
    headcount,
    shares=[100 .* row ./ sum(skipmissing(row)) for row in headcount],
  )
end

# ============================================================================
# HTML
# ============================================================================
html_escape(x) = replace(string(x), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

group_thousands(s) = replace(s, r"\d(?=(\d{3})+$)" => s"\0,")
function format_number(x::Real, digits)
  scaled = round(Int, abs(x) * 10^digits)
  fraction = digits == 0 ? "" : "." * lpad(string(scaled % 10^digits), digits, '0')
  return (x < 0 && scaled > 0 ? "-" : "") * group_thousands(string(scaled ÷ 10^digits)) * fraction
end
format_number(::Missing, digits) = "<span class=\"na\">—</span>"

"""Table with one `label => cells` pair per row. Rows in `emphasis` get a top border and bold text."""
function html_table(headers, rows; emphasis=())
  io = IOBuffer()
  print(io, "<div class=\"table-scroll\"><table><thead><tr>")
  foreach(h -> print(io, "<th>", html_escape(h), "</th>"), headers)
  print(io, "</tr></thead><tbody>\n")
  for (idx, (label, cells)) in enumerate(rows)
    print(io, idx in emphasis ? "<tr class=\"total\">" : "<tr>", "<th scope=\"row\">", html_escape(label), "</th>")
    foreach(c -> print(io, "<td>", c, "</td>"), cells)
    print(io, "</tr>\n")
  end
  print(io, "</tbody></table></div>")
  return String(take!(io))
end

const style = """
:root{--ink:#16233c;--muted:#637187;--line:#e1e8f0;--bg:#f4f7fb;--blue:#1c416d}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font:15px/1.55 system-ui,-apple-system,Segoe UI,Arial,sans-serif;color:var(--ink)}
main{max-width:1160px;margin:42px auto;padding:0 24px 55px}header{padding:34px 38px;background:#142c4b;color:#fff;border-radius:16px;margin-bottom:24px}
header .eyebrow{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:#bed2eb;font-weight:700}h1{font-size:30px;margin:8px 0}header p{margin:0;color:#d4e0ee}
section{background:white;border:1px solid var(--line);border-radius:14px;padding:25px 26px;margin:20px 0;box-shadow:0 4px 18px #16233c08}
h2{font-size:19px;margin:0 0 5px}section>p{margin:0 0 18px;color:var(--muted);font-size:13px}
.table-scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;white-space:nowrap}thead{background:#eaf0f7}
th,td{padding:11px 13px;border-bottom:1px solid var(--line);text-align:right}thead th{font-size:12px;color:#344c69;font-weight:700}
th:first-child{text-align:left}tbody th:first-child{white-space:normal;min-width:300px;max-width:490px}tbody th{font-weight:550}
tbody tr:nth-child(even){background:#f8fafd}tbody tr:hover{background:#edf4fb}
.total th,.total td{font-weight:750;border-top:2px solid var(--blue);background:#eaf0f7}.na{color:#9aa6b7}
footer{font-size:12px;color:var(--muted);padding:4px 5px}
@media print{body{background:white}main{max-width:none;margin:0;padding:0}header{print-color-adjust:exact}section{break-inside:avoid;box-shadow:none}}
"""

# ============================================================================
# Report
# ============================================================================
"""Write the baseline tables for `year` to `path`."""
function write_tables(path::AbstractString, baseline::ModelDictionary; year::Int)
  (; production, output_value, wage, headcount, shares) = table_data(baseline, year)
  labels = [industry_label[i] for i in industry]
  formatted_rows(rows, digits) = [
    [label => format_number.(row, digits) for (label, row) in zip(labels, rows)];
    "Average across industries" => format_number.(column_averages(rows), digits)
  ]
  production_rows = formatted_rows(production, [0; fill(2, length(inputs))])
  value_rows = formatted_rows(output_value, [0; fill(1, length(first(output_value)) - 1)])
  wage_rows = ["Wage per person (1,000 EUR)" => format_number.(wage, 1)]
  headcount_rows = formatted_rows(headcount, 0)
  share_rows = formatted_rows(shares, 1)

  type_headers = ["Industry"; string.(labor_type)]
  mkpath(dirname(path))
  open(path, "w") do io
    print(io, """<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | Baseline $year</title><style>$style</style></head><body><main>
<header><div class="eyebrow">GREU · Baseline</div><h1>Baseline – $year</h1>
<p>Production and employment by industry in the calibrated baseline.</p></header>
<section><h2>01 · Industries and production inputs</h2><p>Output (Y) in million EUR at $(Time.tBase) prices. Quantities of equipment capital (K), energy (E), labour (L), structures (B) and materials (M) over output. K and B are end-of-year capital stocks. L is efficiency units summed over labour types. The last row is the simple average across industries.</p>
""")
    print(io, html_table(["Industry", "Y (mio. EUR)", "K/Y", "E/Y", "L/Y", "B/Y", "M/Y"], production_rows;
      emphasis=(length(production_rows),)))
    print(io, """</section><section><h2>02 · Decomposition of output value</h2><p>Output value (vY) in million EUR. The other columns are in percent of vY. Cost of equipment capital (vK), energy (vE), labour (vL), structures (vB) and materials (vM). Capital cost is the user cost. Labour cost includes production taxes. The markup is the markup rate times marginal cost times output. Other production taxes are those not assigned to an input. Input costs include the input bundle for the fixed cost and the production loss, so these two enter with a minus. The sum is 100 when the parts add up to vY. The last row is the simple average across industries.</p>""")
    print(io, html_table(["Industry", "vY (mio. EUR)", "vK/vY", "vE/vY", "vL/vY", "vB/vY", "vM/vY", "Markup/vY",
      "Other taxes/vY", "−Fixed cost/vY", "−Prod. loss/vY", "Sum"], value_rows; emphasis=(length(value_rows),)))
    print(io, """</section><section><h2>03 · Wage by labour type</h2><p>Wage per person by type, the same in all industries.</p>""")
    print(io, html_table(["Variable"; string.(labor_type)], wage_rows))
    print(io, """</section><section><h2>04 · Persons by labour type</h2><p>Persons by type and industry. The last row is the simple average across the industries that employ the type.</p>""")
    print(io, html_table(type_headers, headcount_rows; emphasis=(length(headcount_rows),)))
    print(io, """</section><section><h2>05 · Labour type shares by industry</h2><p>Persons of each type in percent of persons in the industry. Each row sums to 100. The last row is the simple average across industries.</p>""")
    print(io, html_table(type_headers, share_rows; emphasis=(length(share_rows),)))
    print(io, """</section><footer>Values are growth- and inflation-adjusted to $(Time.tBase). Missing cells (—) mark inputs or labour types that the industry does not use.</footer></main></body></html>""")
  end
  return path
end

# ============================================================================
# Figures
# ============================================================================
# Danish names and colors, in the order of the table columns.
const input_names = ["Maskinkapital", "Energi", "Effektive arbejdsenheder", "Bygninger", "Materialer"]
const input_colors = ["#7A4EA3", "#E07A1F", "#1A9AAA", "#C6A01E", "#C2455D"]
const ratio_series = ["$name ($(first(input))/Y)" => color for (name, input, color) in zip(input_names, inputs, input_colors)]
const value_series = [
  ["$name (v$(first(input)))" => color for (name, input, color) in zip(input_names, inputs, input_colors)];
  "Markup" => "#2F6FAD";
  "Øvrige produktionsskatter" => "#5D6D7E";
  "Faste omkostninger (−)" => "#8B9BB0";
  "Produktionstab (−)" => "#3D3D3D"
]
const type_names = Dict(:unskilled => "Ufaglært", :skilled => "Faglært", :tertiary => "Videregående uddannelse")
const type_series = [type_names[l] => color for (l, color) in zip(labor_type, type_colors)]

scroller(body) = "<div class=\"scroller\">$body</div>"

"""Industry columns. One series gets green and red bars by sign. More series get a legend."""
function industry_chart(groups, series; digits, ytitle)
  single = length(series) == 1
  body = chart(groups, series; height=420, slot=single ? 26 : 32, fill=single ? 0.6 : 0.9, ytitle, digits, group_every=5)
  return (single ? "" : legend_html(series)) * scroller(body)
end

stacked_industry_chart(groups, series; digits, ytitle) =
  legend_html(series) * scroller(stacked_chart(groups, series; height=420, slot=30, fill=0.72, ytitle, digits, group_every=5))

"""A card with one bar per name, then the same numbers as a table. `extra` adds `header => values` columns."""
function keycard(title, names, values; ytitle, digits, extra=())
  bars = chart([n => [v] for (n, v) in zip(names, values)], ["" => nothing];
    height=300, slot=110, fill=0.6, ytitle, digits, label_class="hlab")
  headers = ["Variabel", "Gennemsnit", first.(extra)...]
  columns = [[fmt.(values, digits)]; [fmt.(v, 1) for v in last.(extra)]]
  head = join("<th>$(html_escape(h))</th>" for h in headers)
  body = join("<tr><th scope=\"row\">$(html_escape(n))</th>$(join("<td>$(c[k])</td>" for c in columns))</tr>"
              for (k, n) in enumerate(names))
  return "<article class=\"keycard\"><h3>$(html_escape(title))</h3>$bars<table><thead><tr>$head</tr></thead><tbody>$body</tbody></table></article>"
end

section(id, title, note, body) =
  "<section id=\"$id\"><h2 class=\"chart-title\">$(html_escape(title))</h2><p class=\"note\">$note</p>$body</section>\n"

const figure_style = """
:root{color-scheme:light;--ink:#16233c;--muted:#637187;--line:#e1e8f0;--grid:#e6edf4;--bg:#f4f7fb}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 system-ui,-apple-system,Segoe UI,Arial,sans-serif}
header.page{background:#142c4b;color:#fff;padding:28px 32px 22px}header.page .eyebrow{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:#bed2eb;font-weight:700}
header.page h1{margin:6px 0 8px;font-size:28px;font-weight:700}header.page p{margin:0;color:#d4e0ee;max-width:980px}
nav{position:sticky;top:0;z-index:5;display:flex;flex-wrap:wrap;gap:8px;background:#fff;border-bottom:1px solid var(--line);padding:10px 24px}
nav a{color:var(--ink);text-decoration:none;font-size:14px;padding:4px 8px;border-radius:6px}nav a:hover{background:#eaf0f7}
main{padding:8px 20px 48px}section{margin:22px 0;scroll-margin-top:64px}
.chart-title{margin:0 0 6px;font-size:18px;font-weight:700}.note{margin:0 0 10px;color:var(--muted);font-size:13px}
.scroller{overflow-x:auto;background:#fff;border:1px solid var(--line);border-radius:12px;padding:16px 12px 20px}
.chart-flex{display:flex;align-items:flex-start;min-width:max-content}
.ycol{position:sticky;left:0;z-index:3;display:flex;background:#fff;padding-right:8px}
.ytitle{width:28px;display:flex;align-items:center;justify-content:center;font-size:10pt}.ytitle span{writing-mode:vertical-rl;transform:rotate(180deg);white-space:nowrap}
.yaxis{position:relative;width:64px;border-right:1px solid var(--ink)}
.tick{position:absolute;right:6px;transform:translateY(-50%);white-space:nowrap;line-height:1;font-size:9pt}
.series{position:relative}.gridlayer{position:absolute;left:0;right:0;top:0;z-index:0;pointer-events:none}
.grid{position:absolute;left:0;right:0;border-top:1px solid var(--grid)}.grid.zero{border-top:1.5px solid var(--ink);z-index:1}
.cols{display:flex;position:relative;z-index:1}.col{display:flex;flex-direction:column;align-items:center;flex:0 0 auto;position:relative}
.col.group-end::after{content:"";position:absolute;top:0;right:0;width:1px;height:100%;background:#8b9bb0;z-index:2;pointer-events:none}
.slot{position:relative;width:100%}.bar{position:absolute}.bar:hover{filter:brightness(1.25)}
.lab{writing-mode:vertical-rl;text-orientation:mixed;margin-top:18px;white-space:nowrap;line-height:1;font-size:8pt}
.hlab{margin-top:10px;font-size:9pt;text-align:center;line-height:1.25;min-height:2.5em;padding:0 4px}
.legend{display:flex;flex-wrap:wrap;gap:8px 18px;margin:0 0 12px;font-size:14px}.legend i{display:inline-block;width:14px;height:14px;margin-right:6px;vertical-align:-1px}
.keys{display:flex;flex-wrap:wrap;gap:28px;align-items:flex-start}
.keycard{background:#fff;border:1px solid var(--line);border-radius:12px;padding:16px 16px 8px;max-width:100%;overflow-x:auto}.keycard h3{margin:0 0 12px;font-size:15px}
table{border-collapse:collapse;margin:16px 0 8px;font-size:14px;font-variant-numeric:tabular-nums}th,td{padding:7px 12px;border-bottom:1px solid var(--line);text-align:right}
th:first-child{text-align:left}tbody th{font-weight:550}thead{background:#eaf0f7}thead th{font-size:12px;color:#344c69}
footer{font-size:12px;color:var(--muted);padding:12px 4px}
@media print{body{background:#fff}nav{display:none}header.page{print-color-adjust:exact}.scroller,.keycard{overflow:visible;border:none}section{break-inside:avoid}}
"""

"""Write Danish bar charts of the baseline tables for `year` to `path`. The average row is in its own cards."""
function write_figures(path::AbstractString, baseline::ModelDictionary; year::Int)
  (; production, output_value, wage, headcount, shares) = table_data(baseline, year)
  labels = ["$n. " * replace(industry_label[i], " · " => ", ") for (n, i) in enumerate(industry)]
  groups(rows, columns) = [label => row[columns] for (label, row) in zip(labels, rows)]
  ratios = 2:length(inputs)+1
  parts = 2:length(value_series)+1
  ids = ["$(first(input))Y" for input in inputs]

  sections = [
    ("Y", "Produktion (Y)", section("Y", "Produktion (Y) – mio. EUR, $year", "Realt output i $(Time.tBase)-priser.",
      industry_chart(groups(production, 1:1), ["" => nothing]; digits=0, ytitle="Mio. EUR")));
    [(id, name, section(id, "$name – input pr. produktionsenhed, $year", "Mængde af input over realt output.",
      industry_chart(groups(production, j:j), ["" => nothing]; digits=2, ytitle="Kvote")))
     for (id, (name, _), j) in zip(ids, ratio_series, ratios)];
    ("Samlet", "Samlet", section("Samlet", "Inputkvoter – mængde pr. produktionsenhed, $year",
      "Søjlerne har fælles skala. Et input, som branchen ikke bruger, har ingen søjle.",
      industry_chart(groups(production, ratios), ratio_series; digits=2, ytitle="Kvote")));
    ("Vaerdi", "Produktionsværdi", section("Vaerdi", "Dekomponering af produktionsværdien – procent af vY, $year",
      "Positive dele stables op fra nul, og negative dele stables ned. Inputomkostningerne dækker også den del af input-bundtet, der går til faste omkostninger og produktionstab, så de to indgår med minus. Summen af alle dele er 100.",
      stacked_industry_chart(groups(output_value, parts), value_series; digits=1, ytitle="Procent af vY")));
    ("Andele", "Arbejdskraftandele", section("Andele", "Arbejdskraftandele efter type – procent af beskæftigede i branchen, $year",
      "Personer af hver type i procent af personerne i branchen. Hver søjle summerer til 100.",
      stacked_industry_chart(groups(shares, eachindex(labor_type)), type_series; digits=1, ytitle="Procent")));
    ("Personer", "Personer", section("Personer", "Beskæftigelse efter type – antal personer, $year",
      "Antal personer i branchen. En type, som branchen ikke beskæftiger, har ingen søjle.",
      industry_chart(groups(headcount, eachindex(labor_type)), type_series; digits=0, ytitle="Personer")));
    ("Gennemsnit", "Gennemsnit og løn", section("Gennemsnit", "Gennemsnit på tværs af brancher og løn, $year",
      "Simpelt gennemsnit fra tabellernes sidste række. Løn pr. person er ens i alle brancher. Positive søjler er grønne og negative røde.",
      "<div class=\"keys\">" *
      keycard("Inputkvoter", first.(ratio_series), column_averages(production)[ratios]; ytitle="Kvote", digits=2) *
      keycard("Produktionsværdi", first.(value_series), column_averages(output_value)[parts]; ytitle="Procent af vY", digits=1) *
      keycard("Arbejdskraftandele", first.(type_series), column_averages(shares); ytitle="Procent", digits=1,
        extra=("Løn pr. person (1.000 EUR)" => wage,)) *
      keycard("Personer", first.(type_series), column_averages(headcount); ytitle="Personer", digits=0) *
      "</div>"))
  ]

  nav = join("<a href=\"#$id\">$(html_escape(name))</a>" for (id, name, _) in sections)
  mkpath(dirname(path))
  open(path, "w") do io
    print(io, """<!DOCTYPE html>
<html lang="da"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | Baseline $year – figurer</title><style>$figure_style</style></head><body>
<header class="page"><div class="eyebrow">GREU · Baseline</div><h1>Produktion og beskæftigelse – $year</h1>
<p>Figurerne viser tabellerne for baseline. En inputkvote er mængden af input pr. produktionsenhed. Dekomponeringen viser dele af produktionsværdien i procent. Hold musen over en søjle for at se værdien. Brede figurer kan rulles sidelæns. Manglende værdier har ingen søjle.</p></header>
<nav>$nav</nav>
<main>
$(join(last.(sections)))<footer>Værdierne er vækst- og inflationskorrigeret til $(Time.tBase).</footer>
</main></body></html>""")
  end
  return path
end

end # module
