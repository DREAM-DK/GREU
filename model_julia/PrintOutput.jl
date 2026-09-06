# Print real GDP and government finances from the calibrated baseline.
# Read Output/baseline.parquet and report the stored values without change.
# The values stay in adjusted model units, so each series is stationary.
# Report the years the file holds, which can be shorter than the current horizon.
using Printf
using SquareModels
import GREU: Settings, model
import GREU.FixedBasePriceAggregates: qGDP
import GREU.Government: vGovPrimaryBalance, vGovPrimaryExpenditure, vGovPrimaryRevenue
import GREU.SectorAccounts: vNetFinAssets
import GREU.Time: t

const labels = ["qGDP", "PrimaryBalance", "PrimaryRevenue", "PrimaryExpense", "GovNetFinAssets"]

baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), model)

years = [year for year in t if !isnothing(baseline[qGDP[year]])]
cells(year) = [
  qGDP[year], vGovPrimaryBalance[year], vGovPrimaryRevenue[year], vGovPrimaryExpenditure[year], vNetFinAssets[:Gov,year],
]

println("Adjusted model units: MEUR detrended to $(Settings.base_year).")
println(@sprintf("%4s", "Year"), join(@sprintf("%16s", label) for label in labels))
println(join(
  [@sprintf("%4d", year) * join(@sprintf("%16.1f", baseline[cell]) for cell in cells(year)) for year in years],
  "\n",
))
