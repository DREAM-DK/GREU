# Fetch and write labor data for production.
# Use employee pay as the labor quantity at the base price.
# Write the labor-type index and the implied supply total.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module LaborData

using CSV
using DataFrames
import ..EurostatClient
import ..DataUtils: long_format, sum_by
import ..InputOutputSettings:
  eurostat_unit,
  eurostat_use_dataset,
  nace_a64_to_a21
import ..ProductionSettings: labor_type, production_data_dir
import ..Settings: calibration_year, country_code, first_data_year

const data_years = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_years]

"""Map employee pay from T1610 to model industries."""
function labor_data(df)
  df = df[
    (df.stk_flow .== "TOTAL") .&
    (df.prd_ava .== "D1") .&
    in.(df.ind_use, Ref(Set(keys(nace_a64_to_a21)))),
    :,
  ]
  df.industry = [nace_a64_to_a21[code] for code in df.ind_use]
  df.year = parse.(Int, df.time)
  return sum_by(df, [:industry, :year])
end

"""Fetch employee pay by industry as the labor quantity at the base price."""
fetch_labor_table() = labor_data(EurostatClient.fetch_table(
  eurostat_use_dataset,
  "unit" => eurostat_unit,
  "stk_flow" => "TOTAL",
  "prd_ava" => "D1",
  "geo" => country_code,
  year_params...,
))

function refresh_labor_data!(labor = fetch_labor_table(), dir = production_data_dir)
  mkpath(dir)
  labor.l .= only(labor_type)
  CSV.write(
    joinpath(dir, "production_labor.csv"),
    vcat(
      long_format(:qL_l_i, labor, [:l, :industry, :year]),
      long_format(:qLSupply, sum_by(labor, [:year]), [:year]),
    ),
  )
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  LaborData.refresh_labor_data!()
end
