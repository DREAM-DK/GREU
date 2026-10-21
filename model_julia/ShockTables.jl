# Percentage deviations of the shocked scenario from the no-shock baseline in 2050.
module ShockTables

import GREU.InputOutput: industry, pY_i, qY_i, qC, qI, qG, qX, qM, pC
import GREU.FixedBasePriceAggregates: qGDP, pGDP
import GREU.Capital: qK_k_i
import GREU.Labor: qL_l_i, vW
import GREU.Intermediates: qM_m_i
import GREU.Production: labor_l_i

export write_tables

# English industry labels based on Eurostat NACE Rev. 2 (combined divisions are concatenated).
const INDUSTRY_LABELS = Dict{String,String}(
    "iA01" => "Crop and animal production, hunting and related service activities",
    "iA02" => "Forestry and logging",
    "iA03" => "Fishing and aquaculture",
    "iB" => "Mining and quarrying",
    "iC10_12" => "Manufacture of food products, beverages and tobacco products",
    "iC13_15" => "Manufacture of textiles, wearing apparel and leather products",
    "iC16" => "Manufacture of wood and of products of wood and cork, except furniture; manufacture of articles of straw and plaiting materials",
    "iC17" => "Manufacture of paper and paper products",
    "iC18" => "Printing and reproduction of recorded media",
    "iC19" => "Manufacture of coke and refined petroleum products",
    "iC20" => "Manufacture of chemicals and chemical products",
    "iC21" => "Manufacture of basic pharmaceutical products and pharmaceutical preparations",
    "iC22" => "Manufacture of rubber and plastic products",
    "iC23" => "Manufacture of other non-metallic mineral products",
    "iC24" => "Manufacture of basic metals",
    "iC25" => "Manufacture of fabricated metal products, except machinery and equipment",
    "iC26" => "Manufacture of computer, electronic and optical products",
    "iC27" => "Manufacture of electrical equipment",
    "iC28" => "Manufacture of machinery and equipment n.e.c.",
    "iC29" => "Manufacture of motor vehicles, trailers and semi-trailers",
    "iC30" => "Manufacture of other transport equipment",
    "iC31_32" => "Manufacture of furniture; other manufacturing",
    "iC33" => "Repair and installation of machinery and equipment",
    "iD" => "Electricity, gas, steam and air conditioning supply",
    "iE36" => "Water collection, treatment and supply",
    "iE37_39" => "Sewerage; waste collection, treatment and disposal activities; materials recovery; remediation activities and other waste management services",
    "iF" => "Construction",
    "iG45" => "Wholesale and retail trade and repair of motor vehicles and motorcycles",
    "iG46" => "Wholesale trade, except of motor vehicles and motorcycles",
    "iG47" => "Retail trade, except of motor vehicles and motorcycles",
    "iH49" => "Land transport and transport via pipelines",
    "iH50" => "Water transport",
    "iH51" => "Air transport",
    "iH52" => "Warehousing and support activities for transportation",
    "iH53" => "Postal and courier activities",
    "iI" => "Accommodation and food service activities",
    "iJ58" => "Publishing activities",
    "iJ59_60" => "Motion picture, video and television programme production, sound recording and music publishing activities; programming and broadcasting activities",
    "iJ61" => "Telecommunications",
    "iJ62_63" => "Computer programming, consultancy and related activities; information service activities",
    "iK64" => "Financial service activities, except insurance and pension funding",
    "iK65" => "Insurance, reinsurance and pension funding, except compulsory social security",
    "iK66" => "Activities auxiliary to financial services and insurance activities",
    "iL" => "Real estate activities",
    "iM69_70" => "Legal and accounting activities; activities of head offices; management consultancy activities",
    "iM71" => "Architectural and engineering activities; technical testing and analysis",
    "iM72" => "Scientific research and development",
    "iM73" => "Advertising and market research",
    "iM74_75" => "Other professional, scientific and technical activities; veterinary activities",
    "iN77" => "Rental and leasing activities",
    "iN78" => "Employment activities",
    "iN79" => "Travel agency, tour operator and other reservation service and related activities",
    "iN80_82" => "Security and investigation activities; services to buildings and landscape activities; office administrative, office support and other business support activities",
    "iO" => "Public administration and defence; compulsory social security",
    "iP" => "Education",
    "iQ86" => "Human health activities",
    "iQ87_88" => "Residential care activities; social work activities without accommodation",
    "iR90_92" => "Creative, arts and entertainment activities; libraries, archives, museums and other cultural activities; gambling and betting activities",
    "iR93" => "Sports activities and amusement and recreation activities",
    "iS94" => "Activities of membership organisations",
    "iS95" => "Repair of computers and personal and household goods",
    "iS96" => "Other personal service activities",
    "iT" => "Activities of households as employers of domestic personnel; undifferentiated goods- and services-producing activities of private households for own use",
)


industry_label(i) = begin
    code = string(i)
    name = get(INDUSTRY_LABELS, code, nothing)
    isnothing(name) ? code : "$(name) ($(code))"
end


# Sparse model arrays can contain structural zero placeholders. These are not
# valid ModelDictionary keys, so resolve only genuine variable references.
function model_value(db, ref)
    if ref === nothing || ref isa Number || occursin("Zero", string(typeof(ref)))
        return missing
    end
    if !applicable(getindex, db, ref)
        return missing
    end
    value = db[ref]
    return value isa Real && isfinite(value) ? value : missing
end

function pct_deviation(baseline, scenario, variable, year)
    ref = variable[year]
    b = model_value(baseline, ref)
    s = model_value(scenario, ref)
    return (ismissing(b) || ismissing(s) || abs(b) < 1e-12) ?
        missing : 100 * (s / b - 1)
end

function labour_deviation(baseline, scenario, i, year)
    types = [l for (l, j) in labor_l_i if j == i]
    isempty(types) && return missing
    pairs = [(model_value(baseline, qL_l_i[l,i,year]),
              model_value(scenario, qL_l_i[l,i,year])) for l in types]
    any(pair -> any(ismissing, pair), pairs) && return missing
    b = sum(pair[1] for pair in pairs)
    s = sum(pair[2] for pair in pairs)
    return abs(b) < 1e-12 ? missing : 100 * (s / b - 1)
end

# Escape labels so the generated HTML is safe and self-contained.
function html_escape(value)
    return replace(string(value), "&" => "&amp;", "<" => "&lt;",
                   ">" => "&gt;", "\"" => "&quot;", "'" => "&#39;")
end

function html_number(x)
    if x === missing || x === nothing || !(x isa Real) || !isfinite(x)
        return "<span class=\"na\">—</span>"
    end
    value = round(x; digits=2)
    abs(value) < 0.005 && (value = 0.0)
    formatted = string(round(value; digits=2))
    cls = value > 0 ? "positive" : value < 0 ? "negative" : "neutral"
    return "<span class=\"$(cls)\">$(formatted)</span>"
end

function html_table(headers, rows)
    io = IOBuffer()
    println(io, "<div class=\"table-scroll\"><table><thead><tr>")
    for header in headers
        println(io, "<th>", html_escape(header), "</th>")
    end
    println(io, "</tr></thead><tbody>")
    for row in rows
        println(io, "<tr><th scope=\"row\">", html_escape(row[1]), "</th>")
        for value in row[2:end]
            println(io, "<td>", html_number(value), "</td>")
        end
        println(io, "</tr>")
    end
    println(io, "</tbody></table></div>")
    return String(take!(io))
end

function write_tables(path::AbstractString, baseline, scenario; shock_title, year=2050)
    industry_rows = Vector{Any}[]
    for i in sort(collect(industry); by=string)
        variables = (
            pY_i[i,:], qY_i[i,:], qK_k_i[:equipment,i,:],
            qM_m_i[:energy,i,:], nothing, qK_k_i[:structures,i,:],
            qM_m_i[:materials,i,:]
        )
        values = [j == 5 ? labour_deviation(baseline, scenario, i, year) :
                  pct_deviation(baseline, scenario, var, year)
                  for (j, var) in enumerate(variables)]
        push!(industry_rows, Any[industry_label(i), values...])
    end
    totals = [("GDP, constant prices", qGDP), ("Private consumption (C)", qC),
              ("Investment (I)", qI), ("Government consumption (G)", qG),
              ("Exports", qX), ("Imports", qM)]
    total_rows = [Any[label, pct_deviation(baseline, scenario, var, year)] for (label,var) in totals]
    prices = [("GDP deflator", pGDP), ("Wage per employee (W)", vW),
              ("Consumer prices (pC)", pC)]
    price_rows = [Any[label, pct_deviation(baseline, scenario, var, year)] for (label,var) in prices]

    title = html_escape(shock_title)
    mkpath(dirname(path))
    open(path, "w") do io
        print(io, """<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | $(title) in $(year)</title>
<style>
:root{color-scheme:light;--ink:#16233c;--muted:#637187;--line:#e1e8f0;--bg:#f4f7fb;--blue:#1c416d}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font:15px/1.55 system-ui,-apple-system,Segoe UI,Arial,sans-serif;color:var(--ink)}
main{max-width:1160px;margin:42px auto;padding:0 24px 55px}header{padding:34px 38px;background:#142c4b;color:#fff;border-radius:16px;margin-bottom:24px}
header .eyebrow{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:#bed2eb;font-weight:700}h1{font-size:30px;margin:8px 0}header p{margin:0;color:#d4e0ee}
section{background:white;border:1px solid var(--line);border-radius:14px;padding:25px 26px;margin:20px 0;box-shadow:0 4px 18px #16233c08}
h2{font-size:19px;margin:0 0 5px}section>p{margin:0 0 18px;color:var(--muted);font-size:13px}
.table-scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;white-space:nowrap}thead{background:#eaf0f7}
th,td{padding:11px 13px;border-bottom:1px solid var(--line);text-align:right}thead th{font-size:12px;color:#344c69;font-weight:700}
th:first-child{text-align:left}tbody th:first-child{white-space:normal;min-width:300px;max-width:490px}tbody th{font-weight:550}tbody tr:nth-child(even){background:#f8fafd}tbody tr:hover{background:#edf4fb}
.positive{color:#126c54}.negative{color:#b13e47}.neutral{color:#35445c}.na{color:#9aa6b7}
footer{font-size:12px;color:var(--muted);padding:4px 5px}code{background:#edf2f8;padding:2px 5px;border-radius:4px}
@media print{body{background:white}main{max-width:none;margin:0;padding:0}header{print-color-adjust:exact}section{break-inside:avoid;box-shadow:none}}
</style></head><body><main>
<header><div class="eyebrow">GREU · Scenario analysis</div><h1>$(title) – $(year)</h1>
<p>Percentage deviation from the no-shock baseline in the same year.</p></header>
<section><h2>01 · Industries and production inputs</h2><p>Output deflator, output (Y), equipment capital (K), effective labour units (L), energy (E), structures (B) and materials (M). All figures in percent.</p>
""")
        print(io, html_table(["Industry", "Output deflator", "Y", "K", "E", "L", "B", "M"], industry_rows))
        print(io, """</section><section><h2>02 · GDP and expenditure components</h2><p>Real quantities; percentage deviation.</p>""")
        print(io, html_table(["Variable", "Deviation in $(year) (%)"], total_rows))
        print(io, """</section><section><h2>03 · Prices and wages</h2><p>Price indices and wage per employee; percentage deviation.</p>""")
        print(io, html_table(["Variable", "Deviation in $(year) (%)"], price_rows))
        print(io, """</section><footer>Method: 100 × (scenario[$(year)] / baseline[$(year)] − 1). Missing or invalid values are shown as —. The report is generated automatically when the model is run.</footer></main></body></html>""")
    end
    return path
end

end
