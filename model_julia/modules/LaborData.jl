# Fetch and write labor data for production.
# Use employee pay as the labor quantity at the base price.
# Keep capital data in CapitalData.jl.
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
import ..ProductionSettings: production_data_dir
import ..Settings: calibration_year, country_code

const data_years = (calibration_year - 1):calibration_year
const year_params = ["time" => string(year) for year in data_years]

# ============================================================================
# Eurostat data
# ============================================================================

"""Fetch employee pay by industry as the labor quantity at the base price."""
function fetch_labor_table()
  df = EurostatClient.fetch_table(
    eurostat_use_dataset,
    "unit" => eurostat_unit,
    "stk_flow" => "TOTAL",
    "prd_ava" => "D1",
    "geo" => country_code,
    year_params...,
  )
  df = df[in.(df.ind_use, Ref(Set(keys(nace_a64_to_a21)))), :]
  df.industry = [nace_a64_to_a21[code] for code in df.ind_use]
  df.year = parse.(Int, df.time)
  return sum_by(df, [:industry, :year])
end

# ============================================================================
# Checked-in data
# ============================================================================

function refresh_labor_data!(dir = production_data_dir)
  mkpath(dir)
  labor = fetch_labor_table()
  CSV.write(
    joinpath(dir, "production_labor.csv"),
    long_format(:qL_i, labor, [:industry, :year]),
  )
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  LaborData.refresh_labor_data!()
end
