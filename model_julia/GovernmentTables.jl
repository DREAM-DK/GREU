# Write optional HTML tables and Danish figures of the government balance and its parts.
# Tables show chosen years in million EUR and in percent of GDP. Figures show the path over years.
# Pass a scenario to show the shock less the baseline instead of the baseline.
# Include DAProductivityShockFigures.jl and BaselineTables.jl first; this file uses their helpers.
# Do not solve, calibrate, or change model values.
module GovernmentTables

using SquareModels: ModelDictionary
import ..BaselineTables: value, format_number, html_table, html_escape, style, figure_style, section, scroller
import ..DAProductivityShockFigures: stacked_chart, line_chart, legend_html
import GREU.FixedBasePriceAggregates: vGDP
import GREU.Government:
  vGovPrimaryRevenue,
  vGovPrimaryExpenditure,
  vGovPrimaryBalance,
  vGovSalesRev,
  vGovOthCurrentTransRev,
  vGovCapTransfer,
  vGovSocBenefitExp,
  vGovOthCurrentTransExp,
  vGovPensionEntitlementAdj,
  vGovCapTransExp
import GREU.IndustrySectors: vM_s, vWages_s, vtProduction_s, vsProduction_s
import GREU.SectorAccounts: vGovBalance, vtDirect, vtCap, vFinIncome_s_f, vSocialContributions, vI_s,
  vNonProducedAssetAcquisitions
import GREU.Taxes: vtIndirect, vsProduct, vsRoWProduct, vsProduction, vsRoWProduction
import GREU.Settings: calibration_year
import GREU.Time

# ============================================================================
# Items
# ============================================================================
# English table label, Danish figure label, chart color, and value in year `t`.
item(en, da, color, f) = (; en, da, color, f)

const revenue_items = [
  item("Indirect taxes", "Indirekte skatter", "#2F6FAD", (db, t) -> value(db, vtIndirect[t])),
  item("Direct taxes", "Direkte skatter", "#1A9AAA", (db, t) -> value(db, vtDirect[t])),
  item("Capital taxes", "Kapitalskatter", "#7A4EA3", (db, t) -> value(db, vtCap[t])),
  item("Social contributions", "Sociale bidrag", "#C6A01E", (db, t) -> value(db, vSocialContributions[:Gov,t])),
  item("Sales", "Salg af varer og tjenester", "#E07A1F", (db, t) -> value(db, vGovSalesRev[t])),
  item("Production subsidies received", "Modtagne produktionssubsidier", "#C2455D", (db, t) -> value(db, vsProduction_s[:Gov,t])),
  item("Equity income", "Udbytter", "#126C54", (db, t) -> value(db, vFinIncome_s_f[:Gov,:Equity,:Assets,t])),
  item("Other current transfers", "Andre løbende overførsler", "#8B9BB0", (db, t) -> value(db, vGovOthCurrentTransRev[t])),
  item("Capital transfers", "Kapitaloverførsler", "#5D6D7E", (db, t) -> value(db, vGovCapTransfer[t])),
]

const expenditure_items = [
  item("Intermediate consumption", "Forbrug i produktionen", "#2F6FAD", (db, t) -> value(db, vM_s[:Gov,t])),
  item("Investment", "Investeringer", "#1A9AAA", (db, t) -> value(db, vI_s[:Gov,t])),
  item("Compensation of employees", "Aflønning af ansatte", "#7A4EA3", (db, t) -> value(db, vWages_s[:Gov,t])),
  item("Production taxes paid", "Betalte produktionsskatter", "#C6A01E", (db, t) -> value(db, vtProduction_s[:Gov,t])),
  item("Product subsidies, less those paid by the rest of the world", "Produktsubsidier (ekskl. udlandets)", "#E07A1F",
    (db, t) -> value(db, vsProduct[t]) - value(db, vsRoWProduct[t])),
  item("Production subsidies, less those paid by the rest of the world", "Produktionssubsidier (ekskl. udlandets)", "#C2455D",
    (db, t) -> value(db, vsProduction[t]) - value(db, vsRoWProduction[t])),
  item("Social benefits", "Sociale ydelser", "#126C54", (db, t) -> value(db, vGovSocBenefitExp[t])),
  item("Other current transfers", "Andre løbende overførsler", "#8B9BB0", (db, t) -> value(db, vGovOthCurrentTransExp[t])),
  item("Pension entitlement adjustment", "Regulering af pensionsrettigheder", "#B07AA1", (db, t) -> value(db, vGovPensionEntitlementAdj[t])),
  item("Capital transfers", "Kapitaloverførsler", "#5D6D7E", (db, t) -> value(db, vGovCapTransExp[t])),
  item("Non-produced assets", "Køb af ikke-producerede aktiver", "#3D3D3D", (db, t) -> value(db, vNonProducedAssetAcquisitions[:Gov,t])),
]

# ============================================================================
# Values
# ============================================================================
"""Parts, then the model total."""
component_values(db, items, total, t) = [[it.f(db, t) for it in items]; value(db, total[t])]
revenue_values(db, t) = component_values(db, revenue_items, vGovPrimaryRevenue, t)
expenditure_values(db, t) = component_values(db, expenditure_items, vGovPrimaryExpenditure, t)

"""Primary revenue, less primary expenditure, primary balance, interest income, less interest payments, and the balance."""
balance_values(db, t) = [
  value(db, vGovPrimaryRevenue[t]),
  -value(db, vGovPrimaryExpenditure[t]),
  value(db, vGovPrimaryBalance[t]),
  value(db, vFinIncome_s_f[:Gov,:Debt,:Assets,t]),
  -value(db, vFinIncome_s_f[:Gov,:Debt,:Liab,t]),
  value(db, vGovBalance[t]),
]

const balance_labels = ["Primary revenue", "− Primary expenditure", "= Primary balance", "+ Interest income",
                        "− Interest payments", "= Balance"]

in_years(years) = @assert all(in(calibration_year:Time.max_terminal_year), years) "Pick years from $calibration_year to $(Time.max_terminal_year)"

"""Values of `f(db, t)` by year: the baseline, or the shock less the baseline."""
reported(baseline, ::Nothing, f) = t -> f(baseline, t)
reported(baseline, scenario::ModelDictionary, f) = t -> f(scenario, t) .- f(baseline, t)

"""Values in percent of baseline GDP. The changes in the parts then sum to the change in the total."""
percent_of_gdp(baseline, values_at) = t -> 100 .* values_at(t) ./ value(baseline, vGDP[t])

# Words that differ between the baseline and the shock report.
wording(::Nothing) = (;
  eyebrow="Baseline", level="mio. EUR", share="% of GDP", change="",
  subject="Government net lending and its parts in the calibrated baseline.",
  da_eyebrow="Baseline", da_share="Procent af BNP", da_unit="procent af BNP", da_change="",
  da_subject="Figurerne viser den offentlige saldo og dens dele i procent af BNP i baseline.",
)
wording(::ModelDictionary) = (;
  eyebrow="Scenario analysis", level="Δ mio. EUR", share="Δ % of baseline GDP", change="the change in ",
  subject="Change in government net lending and its parts: shock less baseline.",
  da_eyebrow="Scenarieanalyse", da_share="Ændring i pct. af BNP", da_unit="ændring i pct. af BNP", da_change="ændringen i ",
  da_subject="Figurerne viser ændringen i den offentlige saldo og dens dele, stød minus baseline, i procent af BNP i baseline.",
)

# ============================================================================
# Tables
# ============================================================================
"""One row per label. Columns are the years in million EUR, then the years in percent of GDP."""
function year_table(labels, values_at, share_at, years, w; emphasis)
  levels, shares = values_at.(years), share_at.(years)
  cells(k) = [format_number.(getindex.(levels, k), 0); format_number.(getindex.(shares, k), 1)]
  headers = ["Item"; ["$t ($(w.level))" for t in years]; ["$t ($(w.share))" for t in years]]
  return html_table(headers, [label => cells(k) for (k, label) in enumerate(labels)]; emphasis)
end

"""Write the government tables for `years` to `path`. With a `scenario`, show the shock less the baseline."""
function write_tables(path::AbstractString, baseline::ModelDictionary; years, scenario=nothing, title="Government balance")
  in_years(years)
  w = wording(scenario)
  function table(labels, f; emphasis)
    values_at = reported(baseline, scenario, f)
    return year_table(labels, values_at, percent_of_gdp(baseline, values_at), years, w; emphasis)
  end
  component_labels(items, total) = [[it.en for it in items]; "= $total"]
  mkpath(dirname(path))
  open(path, "w") do io
    print(io, """<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | $(html_escape(title))</title><style>$style</style></head><body><main>
<header><div class="eyebrow">GREU · $(w.eyebrow)</div><h1>$(html_escape(title)) – $(join(years, ", "))</h1>
<p>$(w.subject)</p></header>
<section><h2>01 · Balance</h2><p>The primary balance is primary revenue less primary expenditure. The balance adds interest income and subtracts interest payments.</p>
""")
    print(io, table(balance_labels, balance_values; emphasis=(3, 6)))
    print(io, """</section><section><h2>02 · Primary revenue</h2><p>Primary revenue by type. The types sum to $(w.change)primary revenue.</p>""")
    print(io, table(component_labels(revenue_items, "Primary revenue"), revenue_values; emphasis=(length(revenue_items) + 1,)))
    print(io, """</section><section><h2>03 · Primary expenditure</h2><p>Primary expenditure by type. The types sum to $(w.change)primary expenditure.</p>""")
    print(io, table(component_labels(expenditure_items, "Primary expenditure"), expenditure_values;
      emphasis=(length(expenditure_items) + 1,)))
    print(io, """</section><footer>Values in million EUR are growth- and inflation-adjusted to $(Time.tBase). Shares of GDP use baseline nominal GDP in the same year.</footer></main></body></html>""")
  end
  return path
end

# ============================================================================
# Figures
# ============================================================================
"""Stacked bars of the parts, one bar per year. The last value of `share_at(t)` is the total and has no bar."""
function stacked_years(share_at, series, years, ytitle)
  groups = [string(t) => share_at(t)[1:end-1] for t in years]
  return legend_html(series) *
    scroller(stacked_chart(groups, series; height=420, slot=30, fill=0.72, ytitle, digits=1, group_every=5))
end

"""Write Danish figures of the government balance and its parts for `years` to `path`. With a `scenario`, show the shock less the baseline."""
function write_figures(path::AbstractString, baseline::ModelDictionary; years, scenario=nothing, title="Offentlig saldo")
  in_years(years)
  w = wording(scenario)
  share_at(f) = percent_of_gdp(baseline, reported(baseline, scenario, f))
  balance = [string(t) => share_at(balance_values)(t) for t in years]
  balance_series = ["Saldo" => "#142C4B", "Primær saldo" => "#1A9AAA"]
  balance_lines, _ = line_chart([label => v[[6, 3]] for (label, v) in balance], balance_series;
    height=420, slot=30, ytitle=w.da_share)
  split_series = ["Primær saldo" => "#1A9AAA", "Nettorenter" => "#E07A1F"]
  split_groups = [label => [v[3], v[4] + v[5]] for (label, v) in balance]
  span = "$(first(years))–$(last(years))"
  unit = w.da_unit

  sections = [
    ("Saldo", "Saldo", section("Saldo", "Offentlig saldo og primær saldo – $unit, $span",
      "Saldoen er den primære saldo plus renteindtægter og minus renteudgifter.",
      legend_html(balance_series) * scroller(balance_lines))),
    ("Opdeling", "Opdeling af saldoen", section("Opdeling", "Opdeling af saldoen – $unit, $span",
      "Positive dele stables op fra nul, og negative dele stables ned. Summen af delene er $(w.da_change)saldoen.",
      legend_html(split_series) * scroller(stacked_chart(split_groups, split_series;
        height=420, slot=30, fill=0.72, ytitle=w.da_share, digits=1, group_every=5)))),
    ("Indtaegter", "Primære indtægter", section("Indtaegter", "Primære indtægter efter type – $unit, $span",
      "Summen af søjlen er $(w.da_change)de primære indtægter. Negative poster stables ned fra nul.",
      stacked_years(share_at(revenue_values), [it.da => it.color for it in revenue_items], years, w.da_share))),
    ("Udgifter", "Primære udgifter", section("Udgifter", "Primære udgifter efter type – $unit, $span",
      "Summen af søjlen er $(w.da_change)de primære udgifter. Negative poster stables ned fra nul.",
      stacked_years(share_at(expenditure_values), [it.da => it.color for it in expenditure_items], years, w.da_share))),
  ]

  nav = join("<a href=\"#$id\">$(html_escape(name))</a>" for (id, name, _) in sections)
  mkpath(dirname(path))
  open(path, "w") do io
    print(io, """<!DOCTYPE html>
<html lang="da"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GREU | $(html_escape(title)) – figurer</title><style>$figure_style.line-svg{display:block;position:relative;z-index:1}</style></head><body>
<header class="page"><div class="eyebrow">GREU · $(w.da_eyebrow)</div><h1>$(html_escape(title)) – $span</h1>
<p>$(w.da_subject) Hold musen over en søjle eller et punkt for at se værdien. Brede figurer kan rulles sidelæns. En tynd streg følger hvert femte år.</p></header>
<nav>$nav</nav>
<main>
$(join(last.(sections)))<footer>Andele af BNP bruger nominelt BNP i baseline i samme år.</footer>
</main></body></html>""")
  end
  return path
end

end # module
