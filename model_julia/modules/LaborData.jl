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
using DataFramesMeta
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
  return @chain df begin
    @rsubset(haskey(nace_a64_to_a21, :ind_use))
    @rtransform begin
      :industry = nace_a64_to_a21[:ind_use]
      :year = parse(Int, :time)
    end
    @by([:industry, :year], :value = sum(skipmissing(:value); init = 0.0))
  end
end

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
