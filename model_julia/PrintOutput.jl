# Print real aggregates, prices, government finances, employment, and the real wage.
# Read Output/baseline.parquet and report the stored values without change.
# The values stay in adjusted model units, so each series is stationary.
# Report the years the file holds, which can be shorter than the current horizon.
# Also write the same table to Output/baseline_summary.csv at full precision.
using Printf
using SquareModels
import GREU: Settings, model
import GREU.Capital: capital_k_i, pK_k_i, qK_k_i
import GREU.FixedBasePriceAggregates: pGDP, qGDP
import GREU.Government: vGovPrimaryBalance, vGovPrimaryExpenditure, vGovPrimaryRevenue
import GREU.IndustrySectors: mapped_sector, qL_s
import GREU.InputOutput: pC, pG, pI, pM, pX, qC, qG, qI, qM, qX
import GREU.Labor: pW
import GREU.SectorAccounts: vNetFinAssets
import GREU.Time: t

const summary_file = joinpath(@__DIR__, "..", "Output", "baseline_summary.csv")

# Levels run to seven digits. Prices sit near one, and payroll per employee is a fraction of
# a million euro, so both need decimals the level format would drop.
show_level(value) = @sprintf("%.1f", value)
show_price(value) = @sprintf("%.5f", value)
column_width(label) = max(length(label), 11) + 2

baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), model)

# The model holds capital by type and industry only. Sum the stock, and weight the user cost
# by that stock, so pK stays the price that pairs with qK in the capital cost.
capital(year) = sum(baseline[qK_k_i[k,i,year]] for (k, i) in capital_k_i)
capital_cost(year) = sum(
  baseline[pK_k_i[k,i,year]] * baseline[qK_k_i[k,i,year]] for (k, i) in capital_k_i
)

# Sector employment splits every industry by its sector shares. The rest is private.
gov_employment(year) = baseline[qL_s[:Gov,year]]
priv_employment(year) = sum(baseline[qL_s[s,year]] for s in mapped_sector) - gov_employment(year)

# Each column pairs a header with the value for a year and the console format for its scale.
# The real wage divides payroll per employee by the consumption price, so it reads two cells.
columns = [
  ("qGDP", year -> baseline[qGDP[year]], show_level),
  ("qC", year -> baseline[qC[year]], show_level),
  ("qI", year -> baseline[qI[year]], show_level),
  ("qK", capital, show_level),
  ("qG", year -> baseline[qG[year]], show_level),
  ("qX", year -> baseline[qX[year]], show_level),
  ("qM", year -> baseline[qM[year]], show_level),
  ("pGDP", year -> baseline[pGDP[year]], show_price),
  ("pC", year -> baseline[pC[year]], show_price),
  ("pI", year -> baseline[pI[year]], show_price),
  ("pK", year -> capital_cost(year) / capital(year), show_price),
  ("pG", year -> baseline[pG[year]], show_price),
  ("pX", year -> baseline[pX[year]], show_price),
  ("pM", year -> baseline[pM[year]], show_price),
  ("PrimaryBalance", year -> baseline[vGovPrimaryBalance[year]], show_level),
  ("PrimaryRevenue", year -> baseline[vGovPrimaryRevenue[year]], show_level),
  ("PrimaryExpense", year -> baseline[vGovPrimaryExpenditure[year]], show_level),
  ("GovNetFinAssets", year -> baseline[vNetFinAssets[:Gov,year]], show_level),
  ("GovEmployment", gov_employment, show_level),
  ("PrivEmployment", priv_employment, show_level),
  ("RealWage", year -> baseline[pW[year]] / baseline[pC[year]], show_price),
]

years = [year for year in t if !isnothing(baseline[qGDP[year]])]

println("Adjusted model units: MEUR detrended to $(Settings.base_year). Employment in persons.")
println(lpad("Year", 4), join(lpad(label, column_width(label)) for (label, _, _) in columns))
println(join(
  [
    lpad(year, 4) * join(lpad(fmt(value(year)), column_width(label)) for (label, value, fmt) in columns)
    for year in years
  ],
  "\n",
))

# The console view rounds each column to its own scale. The file holds six decimals for every
# column, which is far below the precision of the source, and keeps out exponent notation.
write(summary_file, join(
  [
    join(["Year"; [label for (label, _, _) in columns]], ",")
    [join([string(year); [@sprintf("%.6f", value(year)) for (_, value, _) in columns]], ",") for year in years]
  ],
  "\n",
) * "\n")
println("\nWrote $summary_file")
