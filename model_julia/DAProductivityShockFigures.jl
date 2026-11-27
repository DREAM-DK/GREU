# Danish bar charts for the DA labor productivity shock, plus one Excel sheet per chart.
# Figure 02 shows the price per employed person in DKK when `include_fee` is true.
# `k_shock` adds the capital productivity shock immediately after figure 01. Both options shift later numbers.
# `include_total_employment` adds figure 05, total employment by labor type, in percent,
# and the next figure, the same change in persons.
# One separate HTML file shows persons by labor type over time, and wage per person as lines.
# Industry and labor type names come from the caller, which reads them from the shock sheet.
# Charts are HTML, CSS and SVG. The workbook stores the one-year rows as tables.
# Does not solve or change model values.
include("DAProductivityShockTables.jl")

module DAProductivityShockFigures

using Printf: Format, format
using XLSX
import GREU.InputOutput: industry
import GREU.Labor: vW_l
import GREU.Production: labor_l_i
import GREU.ProductionSettings: labor_type
import ..ShockTables: html_escape, model_value, total_employment, total_employment_change
import ..DAProductivityShockTables: table_data, industry_columns

export write_figures, write_excel, write_labor_types

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
    ("P", "Outputdeflator (P)", "Outputdeflator (P)", "#2F6FAD"),
    ("Y", "Produktion (Y)", "Produktion (Y)", "#1E8C4A"),
    ("K", "Udstyrskapital (K)", "Udstyrskapital (K)", "#7A4EA3"),
    ("E", "Energi (E)", "Energi (E)", "#E07A1F"),
    ("L", "Effektive arbejdsenheder (L)", "Arbejdsenheder (L)", "#1A9AAA"),
    ("B", "Bygninger (B)", "Bygninger (B)", "#C6A01E"),
    ("M", "Materialer (M)", "Materialer (M)", "#C2455D"),
    ("X", "Eksport af egen vare (X)", "Eksport af egen vare (X)", "#5D6D7E"),
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

"""Decimals needed to show a tick step of 1, 2, 2.5 or 5 times a power of ten."""
function step_digits(step)
    isinteger(step) && return 0
    for d in 1:8
        scaled = step * 10.0^d
        abs(scaled - round(scaled)) < 1e-6 || continue
        finer = step * 10.0^(d - 1)
        abs(finer - round(finer)) < 1e-6 && continue
        return d
    end
    return 8
end

"""Axis around the finite values, with one tick step of padding. `y(v)` is the pixel offset from the top."""
function data_axis(values, height)
    finite = [Float64(v) for v in values if v isa Real && isfinite(v)]
    lo0, hi0 = minimum(finite), maximum(finite)
    span = hi0 > lo0 ? hi0 - lo0 : max(abs(hi0), 1.0)
    step = nice_step(span)
    lo, hi = floor(lo0 / step) * step - step, ceil(hi0 / step) * step + step
    ticks = [round(lo + k * step; digits=10) for k in 0:round(Int, (hi - lo) / step)]
    return (; ticks, digits=step_digits(step), y=v -> height * (hi - v) / (hi - lo))
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

"""Diamond at `value` in the middle of a slot of width `slot`. A missing value gives no diamond."""
function marker_html(ax, value, slot, label, name, digits)
    value isa Real && isfinite(value) || return ""
    return "<div class=\"marker\" title=\"$(html_escape(tip(label, name, value, digits)))\" " *
           "style=\"top:$(px(ax.y(value)));left:$(px(slot / 2))\"></div>"
end

function column_html(ax, label, values, series, slot, fill, height, label_class, digits, group_end, marker, marker_name)
    bars = join(bar_html(ax, v, k, length(values), slot, fill, label, name, color, digits)
                for (k, (v, (name, color))) in enumerate(zip(values, series)))
    return "<div class=\"col$(group_end ? " group-end" : "")\" style=\"width:$(slot)px\">" *
           "<div class=\"slot\" style=\"height:$(height)px\">$(bars)$(marker_html(ax, marker, slot, label, marker_name, digits))</div>" *
           "<div class=\"$(label_class)\">$(html_escape(label))</div></div>"
end

"""
    chart(groups, series; height, slot, fill, ytitle, digits, group_every=0, total_last=false, label_class="lab", markers, marker_name="")

`groups` is a vector of `label => values` with one value per series. `series` is a vector of
`name => color`; a `nothing` color colors each bar by sign. A thin line follows every
`group_every` columns and sits before a total in the last column.
`markers` holds one value per group, drawn as a diamond named `marker_name`. A missing value gives no diamond.
The page must style the `marker` class.
"""
function chart(groups, series; height, slot, fill, ytitle, digits, group_every=0, total_last=false, label_class="lab",
               markers=Base.fill(missing, length(groups)), marker_name="")
    @assert length(markers) == length(groups)
    ax = axis([reduce(vcat, last.(groups)); markers], height)
    ticks = join("<div class=\"tick\" style=\"top:$(px(ax.y(t)))\">$(fmt(t, ax.digits))</div>" for t in ax.ticks)
    grid = join("<div class=\"grid$(iszero(t) ? " zero" : "")\" style=\"top:$(px(ax.y(t)))\"></div>" for t in ax.ticks)
    group_end(n) = n < length(groups) && (group_every > 0 && n % group_every == 0 || total_last && n == length(groups) - 1)
    cols = join(column_html(ax, label, values, series, slot, fill, height, label_class, digits, group_end(n),
                            marker, marker_name)
                for (n, ((label, values), marker)) in enumerate(zip(groups, markers)))
    return """<div class="chart-flex">
<div class="ycol"><div class="ytitle" style="height:$(height)px"><span>$(ytitle)</span></div><div class="yaxis" style="height:$(height)px">$(ticks)</div></div>
<div class="series"><div class="gridlayer" style="height:$(height)px">$(grid)</div><div class="cols">$(cols)</div></div>
</div>"""
end

legend_html(series) = "<div class=\"legend\">" *
    join("<span><i style=\"background:$(c)\"></i>$(html_escape(n))</span>" for (n, c) in series) * "</div>"

# Stacked bars. Positive values stack up from zero. Negative values stack down from zero.
function stack_bounds(values)
    pos = neg = 0.0
    for v in values
        v isa Real && isfinite(v) || continue
        if v < 0
            neg += Float64(v)
        else
            pos += Float64(v)
        end
    end
    return (neg, pos)
end

"""One segment. A zero or missing value gives no segment."""
function stack_segment_html(ax, base, value, slot, fill, label, name, color, digits)
    value isa Real && isfinite(value) && value != 0 || return ""
    y0, y1 = ax.y(base), ax.y(base + value)
    width = 0.84 * fill * slot
    left = (slot - width) / 2
    return "<div class=\"bar\" title=\"$(html_escape(tip(label, name, value, digits)))\" " *
           "style=\"top:$(px(min(y0, y1)));height:$(px(abs(y1 - y0)));left:$(px(left));" *
           "width:$(px(width));background:$(color)\"></div>"
end

function stack_column_html(ax, label, values, series, slot, fill, height, digits, group_end)
    pos = neg = 0.0
    parts = String[]
    for (value, (name, color)) in zip(values, series)
        base = value isa Real && value < 0 ? neg : pos
        push!(parts, stack_segment_html(ax, base, value, slot, fill, label, name, color, digits))
        value isa Real && isfinite(value) || continue
        if value < 0
            neg += Float64(value)
        else
            pos += Float64(value)
        end
    end
    return "<div class=\"col$(group_end ? " group-end" : "")\" style=\"width:$(slot)px\">" *
           "<div class=\"slot\" style=\"height:$(height)px\">$(join(parts))</div>" *
           "<div class=\"lab\">$(html_escape(label))</div></div>"
end

"""
    stacked_chart(groups, series; height, slot, fill, ytitle, digits, group_every=0)

One stacked bar per group. `groups` is `label => values` with one value per series.
A thin line follows every `group_every` columns.
"""
function stacked_chart(groups, series; height, slot, fill, ytitle, digits, group_every=0)
    @assert all(length(values) == length(series) for (_, values) in groups)
    ax = axis([b for (_, values) in groups for b in stack_bounds(values)], height)
    ticks = join("<div class=\"tick\" style=\"top:$(px(ax.y(t)))\">$(fmt(t, ax.digits))</div>" for t in ax.ticks)
    grid = join("<div class=\"grid$(iszero(t) ? " zero" : "")\" style=\"top:$(px(ax.y(t)))\"></div>" for t in ax.ticks)
    group_end(n) = group_every > 0 && n % group_every == 0 && n < length(groups)
    cols = join(stack_column_html(ax, label, values, series, slot, fill, height, digits, group_end(n))
                for (n, (label, values)) in enumerate(groups))
    return """<div class="chart-flex">
<div class="ycol"><div class="ytitle" style="height:$(height)px"><span>$(ytitle)</span></div><div class="yaxis" style="height:$(height)px">$(ticks)</div></div>
<div class="series"><div class="gridlayer" style="height:$(height)px">$(grid)</div><div class="cols">$(cols)</div></div>
</div>"""
end

coord(x) = round(Float64(x); digits=2)

"""
    line_chart(groups, series; height, slot, ytitle) -> (html, digits)

One line per series. `groups` is `label => values` with one value per series.
The axis fits the values. A thin line follows every fifth group.
"""
function line_chart(groups, series; height, slot, ytitle)
    @assert all(length(values) == length(series) for (_, values) in groups)
    ax = data_axis([v for (_, values) in groups for v in values], height)
    n = length(groups)
    width = n * slot
    xs = [(i - 0.5) * slot for i in 1:n]
    guides = join("<line x1=\"$(i * slot)\" y1=\"0\" x2=\"$(i * slot)\" y2=\"$(height)\" stroke=\"#8b9bb0\" stroke-width=\"1\"/>"
                  for i in 1:n if i % 5 == 0 && i < n)
    lines = String[]
    dots = String[]
    for (k, (name, color)) in enumerate(series)
        pts = String[]
        for (i, (label, values)) in enumerate(groups)
            value = values[k]
            value isa Real && isfinite(value) || continue
            x, y = xs[i], ax.y(value)
            push!(pts, "$(coord(x)),$(coord(y))")
            push!(dots, "<circle cx=\"$(coord(x))\" cy=\"$(coord(y))\" r=\"4\" fill=\"$(color)\"><title>$(html_escape(tip(string(label), name, value, ax.digits)))</title></circle>")
        end
        push!(lines, "<polyline points=\"$(join(pts, " "))\" fill=\"none\" stroke=\"$(color)\" stroke-width=\"2\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>")
    end
    ticks = join("<div class=\"tick\" style=\"top:$(px(ax.y(t)))\">$(fmt(t, ax.digits))</div>" for t in ax.ticks)
    grid = join("<div class=\"grid$(iszero(t) ? " zero" : "")\" style=\"top:$(px(ax.y(t)))\"></div>" for t in ax.ticks)
    labels = join("<div class=\"col$(i % 5 == 0 && i < n ? " group-end" : "")\" style=\"width:$(slot)px\"><div class=\"lab\">$(html_escape(string(label)))</div></div>"
                  for (i, (label, _)) in enumerate(groups))
    svg = "<svg class=\"line-svg\" width=\"$(width)\" height=\"$(height)\" viewBox=\"0 0 $(width) $(height)\">$(guides)$(join(lines))$(join(dots))</svg>"
    html = """<div class="chart-flex">
<div class="ycol"><div class="ytitle" style="height:$(height)px"><span>$(html_escape(ytitle))</span></div><div class="yaxis" style="height:$(height)px">$(ticks)</div></div>
<div class="series"><div class="gridlayer" style="height:$(height)px">$(grid)</div>$(svg)<div class="cols">$(labels)</div></div>
</div>"""
    return html, ax.digits
end

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

"""Unit in the Excel column header, by the y-axis title of the chart."""
const unit_suffix = Dict("Procent" => " (%)", "Personer" => " (personer)", "Andel" => " (andel)", "Kr. pr. person" => " (kr.)")

"""Column headers after the row label. One series uses the deviation header; a group names each series."""
function column_headers(series, ytitle)
    length(series) == 1 && return [ytitle == "Personer" ? "Ændring (personer)" : "Afvigelse (%)"]
    return [first(item) * unit_suffix[ytitle] for item in series]
end

"""The chart body for one figure specification."""
function chart_html(spec)
    spec.kind == :keycard && return keycard(spec.rows, spec.label; ytitle=spec.ytitle, digits=spec.digits)
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
function keycard(rows, label="Variabel"; ytitle="Procent", digits=2)
    groups = [row[1] => row[2:end] for row in rows]
    value_header = ytitle == "Personer" ? "Ændring (personer)" : "Afvigelse (%)"
    return "<article class=\"keycard\">" *
           chart(groups, ["" => nothing]; height=300, slot=110, fill=0.6, ytitle, digits, label_class="hlab") *
           table_html([label, value_header], rows, digits) * "</article>"
end

section_html(b) = """<section id="$(b.id)"><h2 class="chart-title">$(html_escape(b.title))</h2><p class="note">$(b.note)</p>$(b.body)</section>
"""

"""Rows by industry with one value per labor type. A type that the industry does not employ is missing."""
function type_rows(value, industry_name)
    return [Any[industry_name(i), [(l, i) in labor_l_i ? value(l, i) : missing for l in labor_type]...]
            for i in sort(collect(industry); by=string)]
end

"""One percent per industry. A missing shock leaves an empty bar."""
function industry_percent_rows(value, industry_name)
    return [Any[industry_name(i), ismissing(value(i)) ? missing : 100 * value(i)]
            for i in sort(collect(industry); by=string)]
end

"""
    figure_specs(baseline, scenario; shock, fee, fee_base_dkk, year, industry_name, type_name, include_total_employment=true, include_fee=true, k_shock=nothing)

One entry per chart, in chart order. Each row starts with the label printed on the chart.
Figure 02 shows the price in DKK when `include_fee` is true: the share `fee(l, i)` times `fee_base_dkk`.
`k_shock(i)` adds the capital productivity shock, in percent, immediately after figure 01.
Later figure numbers then move up by one, including the price chart. Leaving the price out moves later numbers down by one.
`include_total_employment` adds the charts of total employment by labor type as figures 05 and 06 when the price chart is included and the capital chart is not.
Figure 05 is the percentage deviation. Figure 06 is the change in persons.
The industry and employment charts then take the next numbers.
"""
function figure_specs(baseline, scenario; shock, fee, fee_base_dkk, year, industry_name, type_name, include_total_employment=true, include_fee=true, k_shock=nothing)
    (; shock_rows, total_rows, price_rows, industry_rows, labor_rows, headcount_rows) =
        table_data(baseline, scenario; shock, year, label=industry_name)
    names = row_names(type_name)
    rename(rows) = [Any[names[row[1]], row[2:end]...] for row in rows]
    type_series = [uppercasefirst(type_name[l]) => c for (l, c) in zip(labor_type, type_colors)]
    totals = labor_rows[end]
    headcounts = headcount_rows[end]
    @assert first(totals) == "Total (all industries)" && first(headcounts) == "Total (all industries)"
    employment_total_rows = [Any[uppercasefirst(type_name[l]), totals[k + 1]] for (k, l) in enumerate(labor_type)]
    employment_total_persons_rows = [Any[uppercasefirst(type_name[l]), headcounts[k + 1]] for (k, l) in enumerate(labor_type)]
    input_series = [name => color for (_, name, _, color) in inputs]
    deviation = "procentvis afvigelse fra baseline"
    input_n = include_total_employment ? 7 : 5
    # The capital chart takes number 02. The price chart takes the next number.
    # `no` is for charts that follow the price in the full set, so leaving the price out moves them down by one.
    k_shift = isnothing(k_shock) ? 0 : 1
    k_no = lpad(1 + k_shift, 2, '0')
    no(k) = lpad(k + k_shift - (include_fee ? 0 : 1), 2, '0')
    spec(; id, sheet, nav, title, note, rows, series, digits=2, ytitle="Procent",
         total_last=false, label="Branche", kind=:industry) =
        (; id, sheet, nav, title, note, rows, series, digits, ytitle, total_last, label, kind)
    employment_total = spec(; id="employment-total", sheet="$(no(5)) · Beskæftigelse i alt", nav="$(no(5)) · Beskæftigelse i alt",
                             title="$(no(5)) · Samlet beskæftigelse efter arbejdskrafttype – $(deviation)",
                             note="Personer efter type, summeret over de brancher, der beskæftiger typen.",
                             rows=employment_total_rows, series=["" => nothing], label="Arbejdskrafttype", kind=:keycard)
    employment_total_persons = spec(; id="employment-total-persons", sheet="$(no(6)) · Beskæftigelse, personer", nav="$(no(6)) · Beskæftigelse, personer",
                             title="$(no(6)) · Samlet beskæftigelse efter arbejdskrafttype – ændring i antal personer i forhold til baseline",
                             note="Stød minus baseline. Personer efter type, summeret over de brancher, der beskæftiger typen.",
                             rows=employment_total_persons_rows, series=["" => nothing], digits=0, ytitle="Personer",
                             label="Arbejdskrafttype", kind=:keycard)
    specs = [
        spec(; id="shock", sheet="01 · Stød", nav=isnothing(k_shock) ? "01 · Stød" : "01 · Stød, L",
             title="01 · Arbejdskraftsproduktivitetsstød efter branche og arbejdskrafttype",
             note="Stigning i arbejdskraftsproduktiviteten (aProd) i hvert stødår, i procent af baselineniveauet. En type, som branchen ikke beskæftiger, har ingen søjle.",
             rows=numbered_rows(shock_rows), series=type_series),
        (isnothing(k_shock) ? [] : [spec(; id="k-shock", sheet="$(k_no) · Kapitalstød", nav="$(k_no) · Stød, K",
             title="$(k_no) · Kapitalproduktivitetsstød efter branche",
             note="Stigning i kapitalproduktiviteten (aProd for equipment) i hvert stødår, i procent af baselineniveauet. En branche uden værdi har ingen søjle. Bygninger indgår ikke.",
             rows=numbered_rows(industry_percent_rows(k_shock, industry_name)), series=["" => nothing])])...,
        (include_fee ? [spec(; id="fee-dkk", sheet="$(no(2)) · Pris (kr. pr. person)", nav="$(no(2)) · Pris i kroner",
             title="$(no(2)) · Pris pr. beskæftiget i kroner efter branche og arbejdskrafttype",
             note="Andelen fra fanen Pris gange prisgrundlaget på $(fmt(fee_base_dkk, 0)) kr. pr. person i første stødår. Beløbet vokser derefter med den nominelle vækst. Når flere NACE-koder danner én branche, er andelen et simpelt gennemsnit over de koder, der har beskæftigede. En type, som branchen ikke beskæftiger, har ingen søjle.",
             rows=numbered_rows(type_rows((l, i) -> fee(l, i) * fee_base_dkk, industry_name)), series=type_series,
             digits=0, ytitle="Kr. pr. person")] : [])...,
        spec(; id="gdp", sheet="$(no(3)) · BNP og efterspørgsel", nav="$(no(3)) · BNP og efterspørgsel",
             title="$(no(3)) · BNP og efterspørgselskomponenter – $(deviation)",
             note="Reale mængder.",
             rows=rename(total_rows), series=["" => nothing], label="Variabel", kind=:keycard),
        spec(; id="prices", sheet="$(no(4)) · Priser og løn", nav="$(no(4)) · Priser og løn",
             title="$(no(4)) · Priser og løn – $(deviation)",
             note="Prisindeks og løn pr. ansat i alt og efter arbejdskrafttype.",
             rows=rename(price_rows), series=["" => nothing], label="Variabel", kind=:keycard),
        (include_total_employment ? [employment_total, employment_total_persons] : [])...,
        [spec(; id="input-$(id)", sheet="$(no(input_n)) · $(sheet)", nav="$(no(input_n)) · $(name)",
              title="$(no(input_n)) · $(name) – $(deviation)",
              note="En søjle pr. branche. Positive søjler er grønne og negative røde.",
              rows=input_column_rows(industry_rows, j), series=[name => nothing])
         for (j, (id, name, sheet, _)) in enumerate(inputs)]...,
        spec(; id="input-all", sheet="$(no(input_n)) · Alle input", nav="$(no(input_n)) · Alle input",
             title="$(no(input_n)) · Brancher og produktionsinput – $(deviation)",
             note="Outputdeflator, produktion, udstyrskapital, energi, effektive arbejdsenheder, bygninger, materialer og direkte eksport af den vare, branchen producerer.",
             rows=numbered_rows(industry_rows), series=input_series),
        spec(; id="employment-pct", sheet="$(no(input_n + 1)) · Beskæftigelse (%)", nav="$(no(input_n + 1)) · Beskæftigelse (%)",
             title="$(no(input_n + 1)) · Beskæftigelse efter arbejdskrafttype – $(deviation)",
             note="Personer efter type og branche. Sidste søjle er personer efter type summeret over brancher.",
             rows=with_total_rows(labor_rows), series=type_series, total_last=true),
        spec(; id="employment-persons", sheet="$(no(input_n + 2)) · Beskæftigelse (personer)",
             nav="$(no(input_n + 2)) · Beskæftigelse (personer)",
             title="$(no(input_n + 2)) · Beskæftigelse efter arbejdskrafttype – ændring i antal personer i forhold til baseline",
             note="Stød minus baseline. Sidste søjle summerer ændringerne i antal personer over brancher.",
             rows=with_total_rows(headcount_rows), series=type_series, digits=0, ytitle="Personer", total_last=true),
    ]
    sheets = [s.sheet for s in specs]
    @assert all(s -> 1 <= length(s) <= 31 && !occursin(r"[:\\/?*\[\]]", s), sheets) "Excel sheet name is empty, too long, or contains : \\ / ? * [ ]"
    @assert allunique(sheets)
    return specs
end

"""
    write_figures(path, baseline, scenario; shock, fee, fee_base_dkk, shock_title, year, industry_name, type_name, include_total_employment=true, include_fee=true, k_shock=nothing)

`shock(l, i)` returns the fractional productivity increase for labor type `l` in industry `i`.
`fee(l, i)` returns the fee share for labor type `l` in industry `i`, and `fee_base_dkk` is the fee base
per person in DKK in the first shocked year.
`industry_name(i)` is the Danish label of industry `i`. `type_name[l]` is the Danish name of labor type `l`.
`include_total_employment` adds the percentage change in total employment by labor type, then the same change in persons.
`include_fee` adds the price chart. Set it false to leave it out.
`k_shock(i)` adds the capital productivity shock immediately after figure 01. Pass `nothing` to leave it out.
"""
function write_figures(path::AbstractString, baseline, scenario; shock, fee, fee_base_dkk, shock_title, year=2050, industry_name, type_name, include_total_employment=true, include_fee=true, k_shock=nothing)
    specs = figure_specs(baseline, scenario; shock, fee, fee_base_dkk, year, industry_name, type_name, include_total_employment, include_fee, k_shock)
    fee_no = isnothing(k_shock) ? "02" : "03"
    employment_no = lpad(5 + (isnothing(k_shock) ? 0 : 1) - (include_fee ? 0 : 1), 2, '0')
    persons_no = lpad(6 + (isnothing(k_shock) ? 0 : 1) - (include_fee ? 0 : 1), 2, '0')
    fee_lead = include_fee ? "Figur $(fee_no) viser prisen pr. beskæftiget i kroner." : ""
    capital_lead = isnothing(k_shock) ? "" : "Figur 02 er kapitalproduktivitetsstødet efter branche. "
    lead = include_total_employment ?
        "Søjlediagrammer. $(capital_lead)$(fee_lead) Figur $(employment_no) er samlet beskæftigelse efter arbejdskrafttype, i procent. Figur $(persons_no) er ændringen i antal personer. De andre figurer følger de seks tabeller i samme rækkefølge." :
        "Søjlediagrammer. $(capital_lead)$(fee_lead) De andre figurer følger de seks tabeller i tabelrapporten, i samme rækkefølge."
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
<p>$(lead) Tallene er procentvis afvigelse fra baseline uden stød, bortset fra selve stødet, prisen og beskæftigelsesændringen i personer. Hold musen over en søjle for at se værdien. Brede figurer kan rulles sidelæns. En enkelt serie er grøn, når den er positiv, og rød, når den er negativ; grupperede serier har hver sin farve. Manglende værdier har ingen søjle.</p></header>
<nav>$(nav)</nav>
<main>
$(join(section_html.(blocks)))<footer>Metode: Procentvise afvigelser = 100 × (scenarie / baseline − 1); beskæftigelsesændringer i personer = scenarie − baseline. Stødfiguren viser 100 × den relative stigning i aProd. Prisen i kroner = andel × prisgrundlag. Rapporten dannes automatisk, når modellen køres.</footer>
</main></body></html>""")
    end
    return path
end

# One row per year: the label, one number per labor type, then the sum across types.
function labor_type_year_rows(years, value_at)
    rows = Vector{Any}[]
    for year in years
        values = [value_at(l, year) for l in labor_type]
        @assert all(v -> v isa Real && isfinite(v), values) "Employment by type is missing in $(year)."
        push!(rows, Any[string(year), values..., sum(values)])
    end
    return rows
end

# Wage per person by labor type for each year. No total: the sum of wage rates is not a wage.
function wage_rows(scenario, years)
    rows = Vector{Any}[]
    for year in years
        values = [model_value(scenario, vW_l[l, year]) for l in labor_type]
        @assert all(v -> v isa Real && isfinite(v), values) "Wage per person is missing in $(year)."
        push!(rows, Any[string(year), values...])
    end
    return rows
end

"""One chart on the labor-type page: heading, note, the chart and the same rows as a table."""
function labor_section(id, title, note, chart_body, headers, rows; digits=0)
    return """<section id="$(id)"><h2>$(html_escape(title))</h2><p class="note">$(html_escape(note))</p>
<div class="scroller">$(chart_body)</div>
<div class="scroller">$(table_html(headers, rows, digits))</div></section>"""
end

"""HTML page with the labor-type charts, a shared legend and the same rows as tables."""
function labor_type_page(; title, intro, footer, series, nav, sections)
    title = html_escape(title)
    intro = html_escape(intro)
    nav_html = join("<a href=\"#$(id)\">$(html_escape(label))</a>" for (id, label) in nav)
    return """<!DOCTYPE html>
<html lang="da"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | $(title)</title>
<style>
:root{color-scheme:light;--ink:#16233c;--muted:#637187;--line:#e1e8f0;--grid:#e6edf4;--bg:#f4f7fb}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 system-ui,-apple-system,Segoe UI,Arial,sans-serif}
header.page{background:#142c4b;color:#fff;padding:28px 32px 22px}header.page .eyebrow{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:#bed2eb;font-weight:700}
header.page h1{margin:6px 0 8px;font-size:28px;font-weight:700}header.page p{margin:0;color:#d4e0ee;max-width:980px}
nav{position:sticky;top:0;z-index:5;display:flex;flex-wrap:wrap;gap:8px;background:#fff;border-bottom:1px solid var(--line);padding:10px 24px}
nav a{color:var(--ink);text-decoration:none;font-size:14px;padding:4px 8px;border-radius:6px}nav a:hover{background:#eaf0f7}
main{padding:22px 20px 48px}section{margin:8px 0 28px;scroll-margin-top:64px}
h2{margin:0 0 6px;font-size:18px;font-weight:700}.note{margin:0 0 10px;color:var(--muted);font-size:13px}
.scroller{overflow-x:auto;background:#fff;border:1px solid var(--line);border-radius:12px;padding:16px 12px 20px;margin:0 0 16px}
.chart-flex{display:flex;align-items:flex-start;min-width:max-content}
.ycol{position:sticky;left:0;z-index:3;display:flex;background:#fff;padding-right:8px}
.ytitle{width:28px;display:flex;align-items:center;justify-content:center;font-size:10pt}.ytitle span{writing-mode:vertical-rl;transform:rotate(180deg);white-space:nowrap}
.yaxis{position:relative;width:84px;border-right:1px solid var(--ink)}
.tick{position:absolute;right:6px;transform:translateY(-50%);white-space:nowrap;line-height:1;font-size:9pt}
.series{position:relative}.gridlayer{position:absolute;left:0;right:0;top:0;z-index:0;pointer-events:none}
.grid{position:absolute;left:0;right:0;border-top:1px solid var(--grid)}.grid.zero{border-top:1.5px solid var(--ink);z-index:1}
.cols{display:flex;position:relative;z-index:1}.col{display:flex;flex-direction:column;align-items:center;flex:0 0 auto;position:relative}
.col.group-end::after{content:"";position:absolute;top:0;right:0;width:1px;height:100%;background:#8b9bb0;z-index:2;pointer-events:none}
.slot{position:relative;width:100%}.bar{position:absolute}.bar:hover{filter:brightness(1.25)}
.line-svg{display:block;position:relative;z-index:1}
.lab{writing-mode:vertical-rl;text-orientation:mixed;margin-top:18px;white-space:nowrap;line-height:1;font-size:8pt}
.legend{display:flex;flex-wrap:wrap;gap:8px 18px;margin:0 0 12px;font-size:14px}.legend i{display:inline-block;width:14px;height:14px;margin-right:6px;vertical-align:-1px}
table{border-collapse:collapse;margin:0;font-size:14px;font-variant-numeric:tabular-nums}th,td{padding:7px 12px;border-bottom:1px solid var(--line);text-align:right}
th:first-child{text-align:left}tbody th{font-weight:550}thead{background:#eaf0f7}thead th{font-size:12px;color:#344c69}
.positive{color:#126c54}.negative{color:#b13e47}.neutral{color:#35445c}.na{color:#9aa6b7}
footer{font-size:12px;color:var(--muted);padding:12px 4px}
@media print{body{background:#fff}nav{display:none}header.page{print-color-adjust:exact}.scroller{overflow:visible;border:none}}
</style></head><body>
<header class="page"><div class="eyebrow">GREU · Scenarieanalyse</div><h1>$(title)</h1>
<p>$(intro)</p></header>
<nav>$(nav_html)</nav>
<main>
$(legend_html(series))
$(join(sections))
<footer>$(footer)</footer>
</main></body></html>"""
end

function type_series(type_name)
    return [uppercasefirst(type_name[l]) => c for (l, c) in zip(labor_type, type_colors)]
end

function type_groups(rows, nseries)
    return [row[1] => row[2:nseries+1] for row in rows]
end

function labor_chart(rows, series)
    return stacked_chart(type_groups(rows, length(series)), series; height=420, slot=30, fill=0.72,
                         ytitle="Personer", digits=0, group_every=5)
end

function write_labor_type_file(path, page)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, page)
    end
    return path
end

"""
    write_labor_types(path, baseline, scenario; shock_title, type_name, years)

Write one HTML file. Two stacked charts show persons by labor type: the scenario level, then the
change from baseline. A line chart shows the wage per person of each type in the scenario.
Each bar or point is one year. Persons are summed over the industries that employ the type.
`type_name[l]` is the Danish name of labor type `l`.
"""
function write_labor_types(path::AbstractString, baseline, scenario; shock_title, type_name, years)
    series = type_series(type_name)
    headers = vcat("År", [name * " (personer)" for (name, _) in series], "I alt (personer)")
    level_rows = labor_type_year_rows(years, (l, year) -> total_employment(scenario, l, year))
    change_rows = labor_type_year_rows(years, (l, year) -> total_employment_change(baseline, scenario, l, year))
    wages = wage_rows(scenario, years)
    wage_body, wage_digits = line_chart([row[1] => row[2:end] for row in wages], series;
                                        height=420, slot=30, ytitle="Løn pr. person")
    span = "fra $(first(years)) til $(last(years))"
    sections = [
        labor_section("levels", "Antal personer",
                      "Antal personer i scenariet, $(span). Søjlehøjden er summen over typer.",
                      labor_chart(level_rows, series), headers, level_rows),
        labor_section("change", "Ændring i personer",
                      "Ændring i antal personer i forhold til baseline, $(span). Positive ændringer stables op fra nul, og negative ændringer stables ned fra nul.",
                      labor_chart(change_rows, series), headers, change_rows),
        labor_section("wages", "Løn pr. person",
                      "Løn pr. person i scenariet for hver arbejdskrafttype, $(span).",
                      wage_body, vcat("År", first.(series)), wages; digits=wage_digits),
    ]
    intro = "$(shock_title). Beskæftigelse og løn pr. person efter arbejdskrafttype. Hold musen over en søjle eller et punkt for at se værdien. En tynd streg følger hvert femte år."
    footer = "Metode: Personer er scenariets beskæftigelse. Ændring i personer = scenarie − baseline. Begge er summeret over de brancher, der beskæftiger typen. Løn pr. person er lønnen i scenariet. Filen dannes automatisk, når modellen køres."
    return write_labor_type_file(path, labor_type_page(;
        title="Beskæftigelse og løn efter arbejdskrafttype over tid",
        intro, footer, series,
        nav=[("levels", "Antal personer"), ("change", "Ændring i personer"), ("wages", "Løn pr. person")],
        sections,
    ))
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
    fmt = digits == 0 ? "#,##0" : "#,##0." * "0"^digits
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
    write_excel(path, baseline, scenario; shock, fee, fee_base_dkk, year, industry_name, type_name, include_total_employment=true, include_fee=true, k_shock=nothing)

One worksheet per chart, in the same order as `write_figures`. The sheet holds the chart rows as a table.
`include_total_employment`, `include_fee` and `k_shock` must match the values passed to `write_figures`.
"""
function write_excel(path::AbstractString, baseline, scenario; shock, fee, fee_base_dkk, year=2050, industry_name, type_name, include_total_employment=true, include_fee=true, k_shock=nothing)
    specs = figure_specs(baseline, scenario; shock, fee, fee_base_dkk, year, industry_name, type_name, include_total_employment, include_fee, k_shock)
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
