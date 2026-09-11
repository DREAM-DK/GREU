# Print real aggregates, prices, government finances, employment, and the real wage.
# Read Output/baseline.parquet and keep the adjusted model units.
# Report only years with stored GDP values and set the session defaults.
# Write the same series to Output/baseline_summary.csv with six decimals.
# Show absent values as nothing in the table and empty cells in the CSV.
using CSV
using Printf: @sprintf
using SquareModels: load, select_axes, @evalexpr, @prt,
  set_default_source!, set_default_periods!, set_default_operator!

import GREU: Settings, model
import GREU.Capital: capital_k_i, pK_k_i, qK_k_i
import GREU.Government: vGovPrimaryBalance, vGovPrimaryExpenditure, vGovPrimaryRevenue
import GREU.IndustrySectors: qL_s
import GREU.InputOutput: pC, pM, qM
import GREU.Labor: pW
import GREU.SectorAccounts: vNetFinAssets
import GREU.Time: t

baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), model)
years = [year for (year, value) in zip(t, @evalexpr(:n, t, baseline, qGDP)) if !isnothing(value)]
set_default_source!(baseline)
set_default_periods!(years)
set_default_operator!(:n)

# Symbolic aliases set column labels and still read values from the active source.
qK = reduce(.+, (qK_k_i[k,i,:] for (k, i) in capital_k_i))
pK = reduce(.+, (pK_k_i[k,i,:] .* qK_k_i[k,i,:] for (k, i) in capital_k_i)) ./ qK
PrimaryBalance = vGovPrimaryBalance
PrimaryRevenue = vGovPrimaryRevenue
PrimaryExpense = vGovPrimaryExpenditure
GovNetFinAssets = vNetFinAssets[:Gov,:]
GovEmployment = qL_s[:Gov,:]
PrivEmployment = reduce(.+, (qL_s[s,:] for (s,) in select_axes(qL_s, 1))) .- GovEmployment
RealWage = pW ./ pC

report = @evalexpr (
  qGDP, qC, qI, qK, qG, qX, qM,
  pGDP, pC, pI, pK, pG, pX, pM,
  PrimaryBalance, PrimaryRevenue, PrimaryExpense, GovNetFinAssets,
  GovEmployment, PrivEmployment, RealWage,
)
println("Adjusted model units: MEUR detrended to $(Settings.base_year). Employment in persons.")
@prt $report

# Format value columns only. CSV handles headers, quotes, and absent values.
csv_value(value::Real) = @sprintf("%.6f", value)
csv_value(::Missing) = missing
summary_file = joinpath(@__DIR__, "..", "Output", "baseline_summary.csv")
CSV.write(summary_file, report; header=["Year"; report.names],
  transform=(column, value) -> column == 1 ? value : csv_value(value))
println("\nWrote $summary_file")
