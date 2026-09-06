# Print real aggregates, government finances, and the real wage from the calibrated baseline.
# Read Output/baseline.parquet and report the stored values without change.
# The values stay in adjusted model units, so each series is stationary.
# Report the years the file holds, which can be shorter than the current horizon.
# Also write the same table to Output/baseline_summary.csv at full precision.
using Printf
using SquareModels
import GREU: Settings, model
import GREU.FixedBasePriceAggregates: qGDP
import GREU.Government: vGovPrimaryBalance, vGovPrimaryExpenditure, vGovPrimaryRevenue
import GREU.InputOutput: pC, qC, qI, qX
import GREU.Labor: pW
import GREU.SectorAccounts: vNetFinAssets
import GREU.Time: t

const summary_file = joinpath(@__DIR__, "..", "Output", "baseline_summary.csv")

# Levels run to six digits. Payroll per employee is a fraction of a million euro.
show_level(value) = @sprintf("%16.1f", value)
show_wage(value) = @sprintf("%16.5f", value)

baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), model)

# Each column pairs a header with the value for a year and the console format for its scale.
# The real wage divides payroll per employee by the consumption price, so it reads two cells.
columns = [
  ("qGDP", year -> baseline[qGDP[year]], show_level),
  ("qC", year -> baseline[qC[year]], show_level),
  ("qI", year -> baseline[qI[year]], show_level),
  ("qX", year -> baseline[qX[year]], show_level),
  ("PrimaryBalance", year -> baseline[vGovPrimaryBalance[year]], show_level),
  ("PrimaryRevenue", year -> baseline[vGovPrimaryRevenue[year]], show_level),
  ("PrimaryExpense", year -> baseline[vGovPrimaryExpenditure[year]], show_level),
  ("GovNetFinAssets", year -> baseline[vNetFinAssets[:Gov,year]], show_level),
  ("RealWage", year -> baseline[pW[year]] / baseline[pC[year]], show_wage),
]

years = [year for year in t if !isnothing(baseline[qGDP[year]])]

println("Adjusted model units: MEUR detrended to $(Settings.base_year).")
println(@sprintf("%4s", "Year"), join(@sprintf("%16s", label) for (label, _, _) in columns))
println(join(
  [@sprintf("%4d", year) * join(fmt(value(year)) for (_, value, fmt) in columns) for year in years],
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
