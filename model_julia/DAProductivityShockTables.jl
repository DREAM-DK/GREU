# Tables for the DA labor productivity shock: the shock by industry and labor type,
# then percentage deviations of the scenario from the baseline in one year.
# Reuses the labels, deviation helpers and HTML helpers from ShockTables.jl.
include("ShockTables.jl")

module DAProductivityShockTables

import GREU.InputOutput: industry, pY_i, qY_i, qX_p, qC, qI, qG, qX, qM, pC
import GREU.FixedBasePriceAggregates: qGDP, pGDP
import GREU.Capital: qK_k_i
import GREU.Labor: vW, vW_l, nL_l_i
import GREU.ProductionSettings: labor_type
import GREU.Intermediates: qM_m_i
import GREU.Production: labor_l_i
import ..ShockTables: industry_label, product_of_industry, model_value, pct_deviation,
                      labour_deviation, employment_change, total_employment_change,
                      html_escape, html_table

export write_tables

# Persons by type and industry; percentage deviation.
function employment_deviation(baseline, scenario, l, i, year)
    (l, i) in labor_l_i || return missing
    return pct_deviation(baseline, scenario, nL_l_i[l,i,:], year)
end

# Persons by type summed over the industries that employ the type; percentage deviation.
function total_employment_deviation(baseline, scenario, l, year)
    cells = [(model_value(baseline, nL_l_i[l,i,year]), model_value(scenario, nL_l_i[l,i,year]))
             for (k, i) in labor_l_i if k == l]
    (isempty(cells) || any(cell -> any(ismissing, cell), cells)) && return missing
    b = sum(first, cells)
    s = sum(last, cells)
    return abs(b) < 1e-12 ? missing : 100 * (s / b - 1)
end

# Column headers of the industry table after the industry label.
const industry_columns = ["Output deflator", "Y", "K", "E", "L", "B", "M", "X"]

"""
    table_data(baseline, scenario; shock, year, label=industry_label)

Rows of the six tables, in table order. Each row starts with its label; `label(i)` names industry `i`.
`shock(l, i)` returns the fractional productivity increase for labor type `l` in industry `i`.
"""
function table_data(baseline, scenario; shock, year, label=industry_label)
    industries = sort(collect(industry); by=string)
    shock_rows = [Any[label(i),
                      [(l, i) in labor_l_i ? 100 * shock(l, i) : missing for l in labor_type]...]
                  for i in industries]
    totals = [("GDP, constant prices", qGDP), ("Private consumption (C)", qC),
              ("Investment (I)", qI), ("Government consumption (G)", qG),
              ("Exports", qX), ("Imports", qM)]
    total_rows = [Any[label, pct_deviation(baseline, scenario, var, year)] for (label, var) in totals]
    # Type wages are not industry specific, so they sit under the total wage.
    prices = [("GDP deflator", pGDP), ("Wage per employee (W)", vW),
              [("Wage per employee, $(l)", vW_l[l,:]) for l in labor_type]...,
              ("Consumer prices (pC)", pC)]
    price_rows = [Any[label, pct_deviation(baseline, scenario, var, year)] for (label, var) in prices]
    industry_rows = Vector{Any}[]
    labor_rows = Vector{Any}[]
    headcount_rows = Vector{Any}[]
    for i in industries
        variables = (
            pY_i[i,:], qY_i[i,:], qK_k_i[:equipment,i,:],
            qM_m_i[:energy,i,:], nothing, qK_k_i[:structures,i,:],
            qM_m_i[:materials,i,:], qX_p[product_of_industry[i],:]
        )
        values = [j == 5 ? labour_deviation(baseline, scenario, i, year) :
                  pct_deviation(baseline, scenario, var, year)
                  for (j, var) in enumerate(variables)]
        push!(industry_rows, Any[label(i), values...])
        push!(labor_rows, Any[label(i),
                              [employment_deviation(baseline, scenario, l, i, year) for l in labor_type]...])
        push!(headcount_rows, Any[label(i),
                                  [employment_change(baseline, scenario, l, i, year) for l in labor_type]...])
    end
    push!(labor_rows, Any["Total (all industries)",
                          [total_employment_deviation(baseline, scenario, l, year) for l in labor_type]...])
    push!(headcount_rows, Any["Total (all industries)",
                              [total_employment_change(baseline, scenario, l, year) for l in labor_type]...])
    return (; shock_rows, total_rows, price_rows, industry_rows, labor_rows, headcount_rows)
end

"""
    write_tables(path, baseline, scenario; shock, shock_title, year)

`shock(l, i)` returns the fractional productivity increase for labor type `l` in industry `i`.
"""
function write_tables(path::AbstractString, baseline, scenario; shock, shock_title, year=2050)
    (; shock_rows, total_rows, price_rows, industry_rows, labor_rows, headcount_rows) =
        table_data(baseline, scenario; shock, year)
    title = html_escape(shock_title)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, """<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | $(title)</title>
<style>
:root{color-scheme:light;--ink:#16233c;--muted:#637187;--line:#e1e8f0;--bg:#f4f7fb;--blue:#1c416d}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font:15px/1.55 system-ui,-apple-system,Segoe UI,Arial,sans-serif;color:var(--ink)}
main{max-width:1160px;margin:42px auto;padding:0 24px 55px}header{padding:34px 38px;background:#142c4b;color:#fff;border-radius:16px;margin-bottom:24px}
header .eyebrow{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:#bed2eb;font-weight:700}h1{font-size:30px;margin:8px 0}header p{margin:0;color:#d4e0ee}
section{background:white;border:1px solid var(--line);border-radius:14px;padding:25px 26px;margin:20px 0;box-shadow:0 4px 18px #16233c08}
h2{font-size:19px;margin:0 0 5px}section>p{margin:0 0 18px;color:var(--muted);font-size:13px}
.table-scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;white-space:nowrap}thead{background:#eaf0f7}
th,td{padding:11px 13px;border-bottom:1px solid var(--line);text-align:right}thead th{font-size:12px;color:#344c69;font-weight:700}
th:first-child{text-align:left}tbody th:first-child{white-space:normal;min-width:300px;max-width:490px}tbody th{font-weight:550}tbody tr:nth-child(even){background:#f8fafd}tbody tr:hover{background:#edf4fb}.labor-total th,.labor-total td{font-weight:750;border-top:2px solid var(--blue);background:#eaf0f7}
th.sep,td.sep{border-left:2px solid var(--blue);padding-left:22px}
.positive{color:#126c54}.negative{color:#b13e47}.neutral{color:#35445c}.na{color:#9aa6b7}
footer{font-size:12px;color:var(--muted);padding:4px 5px}code{background:#edf2f8;padding:2px 5px;border-radius:4px}
@media print{body{background:white}main{max-width:none;margin:0;padding:0}header{print-color-adjust:exact}section{break-inside:avoid;box-shadow:none}}
</style></head><body><main>
<header><div class="eyebrow">GREU · Scenario analysis</div><h1>$(title)</h1>
<p>Scenario comparison against the no-shock baseline in the same year.</p></header>
<section><h2>01 · Labor productivity shock by industry and labor type</h2><p>Increase in labor productivity (aProd) in every shocked year, in percent of the baseline level. A dash marks a type the industry does not employ.</p>
""")
        print(io, html_table(vcat(["Industry"], ["Shock $(l) (%)" for l in labor_type]), shock_rows))
        print(io, """</section><section><h2>02 · GDP and expenditure components</h2><p>Real quantities; percentage deviation.</p>""")
        print(io, html_table(["Variable", "Deviation in $(year) (%)"], total_rows))
        print(io, """</section><section><h2>03 · Prices and wages</h2><p>Price indices, wage per employee in total and by labor type; percentage deviation.</p>""")
        print(io, html_table(["Variable", "Deviation in $(year) (%)"], price_rows))
        print(io, """</section><section><h2>04 · Industries and production inputs</h2><p>Output deflator, output (Y), equipment capital (K), effective labour units (L), energy (E), structures (B) and materials (M). The last column is direct exports of the product that the industry produces (X). All figures in percent.</p>""")
        print(io, html_table(vcat(["Industry"], industry_columns), industry_rows; separator=9))
        print(io, """</section><section><h2>05 · Employment by labor type</h2><p>Persons by type and industry; percentage deviation. The total row is the deviation in persons by type summed across industries.</p>""")
        print(io, html_table(vcat(["Industry"], ["Employment $(l) (%)" for l in labor_type]), labor_rows; total_last=true))
        print(io, """</section><section><h2>06 · Employment by labor type, persons</h2><p>Change in number of persons (shock minus baseline). The total row sums changes in persons across industries.</p>""")
        print(io, html_table(vcat(["Industry"], ["Employment $(l) (persons Δ)" for l in labor_type]), headcount_rows; total_last=true))
        print(io, """</section><footer>Method: Percent deviations = 100 × (scenario[$(year)] / baseline[$(year)] − 1); employment changes in persons = scenario[$(year)] − baseline[$(year)]. The shock table shows 100 × the fractional increase in aProd. Missing or invalid values are shown as —. The report is generated automatically when the model is run.</footer></main></body></html>""")
    end
    return path
end

end # module
