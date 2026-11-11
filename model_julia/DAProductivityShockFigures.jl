# Danish bar charts for the DA labor productivity shock in one year, plus one Excel sheet per chart.
# The sections follow the six tables in DAProductivityShockTables.jl and reuse their rows.
# Industry and labor type names come from the caller, which reads them from the shock sheet.
# Charts are HTML and CSS. The workbook stores the same rows as tables.
# Does not solve or change model values.
include("DAProductivityShockTables.jl")

module DAProductivityShockFigures

using Printf: Format, format
using XLSX
import GREU.ProductionSettings: labor_type
import ..ShockTables: html_escape
import ..DAProductivityShockTables: table_data, industry_columns

export write_figures, write_excel

# ============================================================================
# Series and colors
# ============================================================================
const positive = "#126C54"
const negative = "#B13E47"
const type_colors = ["#1565C0", "#EF6C00", "#2E7D32"]
@assert length(type_colors) == length(labor_type)
# One entry per column of the industry table: anchor id, chart name, Excel sheet and color.
# Excel sheet names stop at 31 characters, so the labor sheet is shorter than its chart name.
const inputs = [
    ("P", "Outputdeflator (P)", "04 · Outputdeflator (P)", "#2F6FAD"),
    ("Y", "Produktion (Y)", "04 · Produktion (Y)", "#1E8C4A"),
    ("K", "Udstyrskapital (K)", "04 · Udstyrskapital (K)", "#7A4EA3"),
    ("E", "Energi (E)", "04 · Energi (E)", "#E07A1F"),
    ("L", "Effektive arbejdsenheder (L)", "04 · Arbejdsenheder (L)", "#1A9AAA"),
    ("B", "Bygninger (B)", "04 · Bygninger (B)", "#C6A01E"),
    ("M", "Materialer (M)", "04 · Materialer (M)", "#C2455D"),
    ("X", "Eksport af egen vare (X)", "04 · Eksport af egen vare (X)", "#5D6D7E"),
]
@assert length(inputs) == length(industry_columns)
const total_label = "I alt (alle brancher)"

"""Danish names of the fixed rows in the GDP and price tables, by their English label."""
function row_names(type_name)
    return Dict(
        "GDP, constant prices" => "BNP, faste priser", "Private consumption (C)" => "Privat forbrug (C)",
        "Investment (I)" => "Investeringer (I)", "Government consumption (G)" => "Offentligt forbrug (G)",
        "Exports" => "Eksport", "Imports" => "Import",
        "GDP deflator" => "BNP-deflator", "Wage per employee (W)" => "Løn pr. ansat (W)",
        ["Wage per employee, $(l)" => "Løn pr. ansat, $(type_name[l])" for l in labor_type]...,
        "Consumer prices (pC)" => "Forbrugerpriser (pC)",
    )
end

# ============================================================================
# Formatting
# ============================================================================
px(x) = "$(round(x; digits=2))px"

"""Danish number: comma decimal and a period every three digits. Zero never gets a minus sign."""
function fmt(x, digits)
    body = format(Format("%.$(digits)f"), abs(x))
    int_part = first(split(body, '.'))
    grouped = replace(int_part, r"(?<=\d)(?=(\d{3})+$)" => ".")
    sign = x < 0 && any(c -> c in '1':'9', body) ? "-" : ""
    return sign * grouped * replace(body[length(int_part)+1:end], "." => ",")
end

# ============================================================================
# Axis
# ============================================================================
"""Tick step of 1, 2, 2.5, 5 or 10 times a power of ten that gives about eight ticks."""
function nice_step(span)
    raw = span / 8
    mag = 10.0^floor(log10(raw))
    return mag * first(filter(>=(raw / mag), [1.0, 2.0, 2.5, 5.0, 10.0]))
end

"""Axis that covers zero and every finite value. `y(v)` is the pixel offset from the top."""
function axis(values, height)
    finite = [Float64(v) for v in values if v isa Real && isfinite(v)]
    lo, hi = min(0.0, minimum(finite; init=0.0)), max(0.0, maximum(finite; init=0.0))
    step = nice_step(hi > lo ? hi - lo : 1.0)
    lo, hi = floor(lo / step) * step, ceil(hi / step) * step
    ticks = [round(lo + k * step; digits=10) for k in 0:round(Int, (hi - lo) / step)]
    return (; ticks, digits=isinteger(step) ? 0 : 2, y=v -> height * (hi - v) / (hi - lo))
end

# ============================================================================
# Chart HTML
# ============================================================================
bar_color(color::Nothing, value) = value < 0 ? negative : positive
bar_color(color::AbstractString, value) = color

tip(label, name, value, digits) = isempty(name) ? "$(label): $(fmt(value, digits))" :
                                                  "$(label), $(name): $(fmt(value, digits))"

"""Bar `k` of `n` in a slot of width `slot`, from zero to `value`. A missing value gives no bar."""
function bar_html(ax, value, k, n, slot, fill, label, name, color, digits)
    value isa Real && isfinite(value) || return ""
    y0, y1 = ax.y(0.0), ax.y(value)
    stride = fill * slot / n
    left = (1 - fill) / 2 * slot + (k - 1) * stride + 0.08stride
    return "<div class=\"bar\" title=\"$(html_escape(tip(label, name, value, digits)))\" " *
           "style=\"top:$(px(min(y0, y1)));height:$(px(abs(y1 - y0)));left:$(px(left));" *
           "width:$(px(0.84stride));background:$(bar_color(color, value))\"></div>"
end

function column_html(ax, label, values, series, slot, fill, height, label_class, digits, group_end)
    bars = join(bar_html(ax, v, k, length(values), slot, fill, label, name, color, digits)
                for (k, (v, (name, color))) in enumerate(zip(values, series)))
    return "<div class=\"col$(group_end ? " group-end" : "")\" style=\"width:$(slot)px\">" *
           "<div class=\"slot\" style=\"height:$(height)px\">$(bars)</div>" *
           "<div class=\"$(label_class)\">$(html_escape(label))</div></div>"
end

"""
    chart(groups, series; height, slot, fill, ytitle, digits, group_every=0, total_last=false, label_class="lab")

`groups` is a vector of `label => values` with one value per series. `series` is a vector of
`name => color`; a `nothing` color colors each bar by sign. A thin line follows every
`group_every` columns and sits before a total in the last column.
"""
function chart(groups, series; height, slot, fill, ytitle, digits, group_every=0, total_last=false, label_class="lab")
    ax = axis(reduce(vcat, last.(groups)), height)
    ticks = join("<div class=\"tick\" style=\"top:$(px(ax.y(t)))\">$(fmt(t, ax.digits))</div>" for t in ax.ticks)
    grid = join("<div class=\"grid$(iszero(t) ? " zero" : "")\" style=\"top:$(px(ax.y(t)))\"></div>" for t in ax.ticks)
    group_end(n) = n < length(groups) && (group_every > 0 && n % group_every == 0 || total_last && n == length(groups) - 1)
    cols = join(column_html(ax, label, values, series, slot, fill, height, label_class, digits, group_end(n))
                for (n, (label, values)) in enumerate(groups))
    return """<div class="chart-flex">
<div class="ycol"><div class="ytitle" style="height:$(height)px"><span>$(ytitle)</span></div><div class="yaxis" style="height:$(height)px">$(ticks)</div></div>
<div class="series"><div class="gridlayer" style="height:$(height)px">$(grid)</div><div class="cols">$(cols)</div></div>
</div>"""
end

legend_html(series) = "<div class=\"legend\">" *
    join("<span><i style=\"background:$(c)\"></i>$(html_escape(n))</span>" for (n, c) in series) * "</div>"

"""Two-column table of label and value with Danish numbers."""
function table_html(headers, rows, digits)
    cell(v) = v isa Real && isfinite(v) ?
        "<td class=\"$(v < 0 ? "negative" : v > 0 ? "positive" : "neutral")\">$(fmt(v, digits))</td>" :
        "<td class=\"na\">—</td>"
    head = join("<th>$(html_escape(h))</th>" for h in headers)
    body = join("<tr><th scope=\"row\">$(html_escape(row[1]))</th>$(join(cell.(row[2:end])))</tr>" for row in rows)
    return "<table><thead><tr>$(head)</tr></thead><tbody>$(body)</tbody></table>"
end

# ============================================================================
# Sections
# ============================================================================
"""Chart rows. Each row is a label and then one number per series. Industries are numbered."""
numbered_rows(rows) = [Any["$(n). $(row[1])", row[2:end]...] for (n, row) in enumerate(rows)]

"""Numbered industry rows, with the last row renamed to the total label."""
function with_total_rows(rows)
    out = numbered_rows(rows[1:end-1])
    push!(out, Any[total_label, rows[end][2:end]...])
    return out
end

"""One input column, numbered like its chart."""
input_column_rows(rows, j) = [Any[row[1], row[j+1]] for row in numbered_rows(rows)]

"""Column headers after the row label. One series uses the deviation header; a group names each series."""
function column_headers(series, ytitle)
    length(series) == 1 && return ["Afvigelse (%)"]
    suffix = ytitle == "Personer" ? " (personer)" : " (%)"
    return [first(item) * suffix for item in series]
end

"""The chart body for one figure specification."""
function chart_html(spec)
    spec.kind == :keycard && return keycard(spec.rows)
    groups = [row[1] => row[2:end] for row in spec.rows]
    return industry_chart(groups, spec.series; digits=spec.digits, ytitle=spec.ytitle, total_last=spec.total_last)
end

"""One column per industry. Grouped series get wider slots."""
function industry_chart(groups, series; digits, ytitle, total_last=false)
    single = length(series) == 1
    body = chart(groups, series; height=420, slot=single ? 26 : 32, fill=single ? 0.6 : 0.9,
                 ytitle, digits, group_every=5, total_last)
    return (single ? "" : legend_html(series)) * "<div class=\"scroller\">$(body)</div>"
end

"""A bar per row, labels below, and the table under the chart."""
function keycard(rows)
    groups = [row[1] => row[2:end] for row in rows]
    return "<article class=\"keycard\">" *
           chart(groups, ["" => nothing]; height=300, slot=110, fill=0.6, ytitle="Procent", digits=2, label_class="hlab") *
           table_html(["Variabel", "Afvigelse (%)"], rows, 2) * "</article>"
end

section_html(b) = """<section id="$(b.id)"><h2 class="chart-title">$(html_escape(b.title))</h2><p class="note">$(b.note)</p>$(b.body)</section>
"""

"""
    figure_specs(baseline, scenario; shock, year, industry_name, type_name)

One entry per chart, in chart order. Each row starts with the label printed on the chart.
"""
function figure_specs(baseline, scenario; shock, year, industry_name, type_name)
    (; shock_rows, total_rows, price_rows, industry_rows, labor_rows, headcount_rows) =
        table_data(baseline, scenario; shock, year, label=industry_name)
    names = row_names(type_name)
    rename(rows) = [Any[names[row[1]], row[2:end]...] for row in rows]
    type_series = [uppercasefirst(type_name[l]) => c for (l, c) in zip(labor_type, type_colors)]
    input_series = [name => color for (_, name, _, color) in inputs]
    deviation = "procentvis afvigelse fra baseline"
    spec(; id, sheet, nav, title, note, rows, series, digits=2, ytitle="Procent",
         total_last=false, label="Branche", kind=:industry) =
        (; id, sheet, nav, title, note, rows, series, digits, ytitle, total_last, label, kind)
    specs = [
        spec(; id="shock", sheet="01 · Stød", nav="01 · Stød",
             title="01 · Arbejdskraftsproduktivitetsstød efter branche og arbejdskrafttype",
             note="Stigning i arbejdskraftsproduktiviteten (aProd) i hvert stødår, i procent af baselineniveauet. En type, som branchen ikke beskæftiger, har ingen søjle.",
             rows=numbered_rows(shock_rows), series=type_series),
        spec(; id="gdp", sheet="02 · BNP og efterspørgsel", nav="02 · BNP og efterspørgsel",
             title="02 · BNP og efterspørgselskomponenter – $(deviation)",
             note="Reale mængder.",
             rows=rename(total_rows), series=["" => nothing], label="Variabel", kind=:keycard),
        spec(; id="prices", sheet="03 · Priser og løn", nav="03 · Priser og løn",
             title="03 · Priser og løn – $(deviation)",
             note="Prisindeks og løn pr. ansat i alt og efter arbejdskrafttype.",
             rows=rename(price_rows), series=["" => nothing], label="Variabel", kind=:keycard),
        [spec(; id="input-$(id)", sheet, nav="04 · $(name)",
              title="04 · $(name) – $(deviation)",
              note="En søjle pr. branche. Positive søjler er grønne og negative røde.",
              rows=input_column_rows(industry_rows, j), series=[name => nothing])
         for (j, (id, name, sheet, _)) in enumerate(inputs)]...,
        spec(; id="input-all", sheet="04 · Alle input", nav="04 · Alle input",
             title="04 · Brancher og produktionsinput – $(deviation)",
             note="Outputdeflator, produktion, udstyrskapital, energi, effektive arbejdsenheder, bygninger, materialer og direkte eksport af den vare, branchen producerer.",
             rows=numbered_rows(industry_rows), series=input_series),
        spec(; id="employment-pct", sheet="05 · Beskæftigelse (%)", nav="05 · Beskæftigelse (%)",
             title="05 · Beskæftigelse efter arbejdskrafttype – $(deviation)",
             note="Personer efter type og branche. Sidste søjle er personer efter type summeret over brancher.",
             rows=with_total_rows(labor_rows), series=type_series, total_last=true),
        spec(; id="employment-persons", sheet="06 · Beskæftigelse (personer)", nav="06 · Beskæftigelse (personer)",
             title="06 · Beskæftigelse efter arbejdskrafttype – ændring i antal personer i forhold til baseline",
             note="Stød minus baseline. Sidste søjle summerer ændringerne i antal personer over brancher.",
             rows=with_total_rows(headcount_rows), series=type_series, digits=0, ytitle="Personer", total_last=true),
    ]
    sheets = [s.sheet for s in specs]
    @assert all(s -> 1 <= length(s) <= 31 && !occursin(r"[:\\/?*\[\]]", s), sheets) "Excel sheet name is empty, too long, or contains : \\ / ? * [ ]"
    @assert allunique(sheets)
    return specs
end

"""
    write_figures(path, baseline, scenario; shock, shock_title, year, industry_name, type_name)

`shock(l, i)` returns the fractional productivity increase for labor type `l` in industry `i`.
`industry_name(i)` is the Danish label of industry `i`. `type_name[l]` is the Danish name of labor type `l`.
"""
function write_figures(path::AbstractString, baseline, scenario; shock, shock_title, year=2050, industry_name, type_name)
    specs = figure_specs(baseline, scenario; shock, year, industry_name, type_name)
    blocks = [(id=s.id, nav=s.nav, title=s.title, note=s.note, body=chart_html(s)) for s in specs]
    nav = join("<a href=\"#$(b.id)\">$(html_escape(b.nav))</a>" for b in blocks)
    title = html_escape(shock_title)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, """<!DOCTYPE html>
<html lang="da"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | $(title) – figurer</title>
<style>
:root{color-scheme:light;--ink:#16233c;--muted:#637187;--line:#e1e8f0;--grid:#e6edf4;--bg:#f4f7fb;--blue:#1c416d}
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
.keycard{display:inline-block;background:#fff;border:1px solid var(--line);border-radius:12px;padding:16px 16px 8px;max-width:100%;overflow-x:auto}
table{border-collapse:collapse;margin:16px 0 8px;font-size:14px;font-variant-numeric:tabular-nums}th,td{padding:7px 12px;border-bottom:1px solid var(--line);text-align:right}
th:first-child{text-align:left}tbody th{font-weight:550}thead{background:#eaf0f7}thead th{font-size:12px;color:#344c69}
.positive{color:#126c54}.negative{color:#b13e47}.neutral{color:#35445c}.na{color:#9aa6b7}
footer{font-size:12px;color:var(--muted);padding:12px 4px}
@media print{body{background:#fff}nav{display:none}header.page{print-color-adjust:exact}.scroller,.keycard{overflow:visible;border:none}section{break-inside:avoid}}
</style></head><body>
<header class="page"><div class="eyebrow">GREU · Scenarieanalyse</div><h1>$(title)</h1>
<p>Søjlediagrammer af de seks tabeller i tabelrapporten, i samme rækkefølge. Tallene er procentvis afvigelse fra baseline uden stød, bortset fra selve stødet og beskæftigelsesændringen i personer. Hold musen over en søjle for at se værdien. Brede figurer kan rulles sidelæns. En enkelt serie er grøn, når den er positiv, og rød, når den er negativ; grupperede serier har hver sin farve. Manglende værdier har ingen søjle.</p></header>
<nav>$(nav)</nav>
<main>
$(join(section_html.(blocks)))<footer>Metode: Procentvise afvigelser = 100 × (scenarie / baseline − 1); beskæftigelsesændringer i personer = scenarie − baseline. Stødfiguren viser 100 × den relative stigning i aProd. Rapporten dannes automatisk, når modellen køres.</footer>
</main></body></html>""")
    end
    return path
end

# ============================================================================
# Excel workbook
# ============================================================================
"""Columns of a figure table. A value that is not a finite number is left empty."""
function table_columns(rows, ncols)
    cols = [Vector{Any}(undef, length(rows)) for _ in 1:ncols]
    for (r, row) in enumerate(rows)
        @assert length(row) == ncols "Row $(row[1]) has $(length(row)) cells, expected $(ncols)."
        cols[1][r] = row[1]
        for c in 2:ncols
            value = row[c]
            cols[c][r] = value isa Real && isfinite(value) ? Float64(value) : missing
        end
    end
    return cols
end

"""Number format for finite cells. Empty cells stay empty."""
function format_values!(sheet, rows, digits)
    fmt = digits == 0 ? "#,##0" : "#,##0.00"
    for (r, row) in enumerate(rows)
        for c in 2:length(row)
            value = row[c]
            value isa Real && isfinite(value) || continue
            XLSX.setFormat(sheet, XLSX.CellRef(4 + r, c); format=fmt)
        end
    end
end

"""Write one chart as a table: title, note, then the rows."""
function write_sheet!(sheet, spec)
    sheet["A1"] = spec.title
    sheet["A2"] = spec.note
    headers = [spec.label; column_headers(spec.series, spec.ytitle)]
    XLSX.writetable!(sheet, table_columns(spec.rows, length(headers)), headers; anchor_cell=XLSX.CellRef(4, 1))
    ncols = length(headers)
    XLSX.setFont(sheet, "A1"; bold=true, size=14)
    XLSX.setAlignment(sheet, "A2"; wrapText=true)
    XLSX.setRowHeight(sheet, 2; height=36)
    XLSX.setFont(sheet, 4, 1:ncols; bold=true)
    format_values!(sheet, spec.rows, spec.digits)
    for (r, row) in enumerate(spec.rows)
        row[1] == total_label || continue
        XLSX.setFont(sheet, 4 + r, 1:ncols; bold=true)
    end
    for (c, header) in enumerate(headers)
        XLSX.setColumnWidth(sheet, c; width=c == 1 ? 80 : max(14, min(36, length(header) + 2)))
    end
    return sheet
end

"""
    write_excel(path, baseline, scenario; shock, year, industry_name, type_name)

One worksheet per chart, in the same order as `write_figures`. The sheet holds the chart rows as a table.
"""
function write_excel(path::AbstractString, baseline, scenario; shock, year=2050, industry_name, type_name)
    specs = figure_specs(baseline, scenario; shock, year, industry_name, type_name)
    mkpath(dirname(path))
    XLSX.openxlsx(path, mode="w") do xf
        for (n, spec) in enumerate(specs)
            sheet = n == 1 ? xf[1] : XLSX.addsheet!(xf, spec.sheet)
            n == 1 && XLSX.renamesheet!(sheet, spec.sheet)
            write_sheet!(sheet, spec)
        end
    end
    return path
end

end # module
