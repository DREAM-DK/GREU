# Fetch and write employee counts and payroll for production.
# Map A21 employment and A64 payroll to model industries.
# Exclude hours, self-employment, and labor productivity.
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
  nace_a64_to_a21,
  section_to_industry
import ..ProductionSettings: labor_type, production_data_dir
import ..Settings: calibration_year, country_code, first_data_year

const data_years = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_years]

"""Fetch compensation of employees by industry."""
function fetch_payroll_table()
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

"""Fetch the number of employees by industry."""
function fetch_employment_table()
  df = EurostatClient.fetch_table(
    "nama_10_a64_e",
    "unit" => "THS_PER",
    "na_item" => "SAL_DC",
    "geo" => country_code,
    year_params...,
  )
  @assert all(
    isapprox(
      sum(
        row.value
        for row in eachrow(df)
        if haskey(section_to_industry, Symbol(row.nace_r2)) && row.time == string(year)
      ),
      only(
        row.value
        for row in eachrow(df)
        if row.nace_r2 == "TOTAL" && row.time == string(year)
      );
      atol = 0.1,
      rtol = 0,
    )
    for year in data_years
  ) "Employment A21 rows must sum to each source total"
  return @chain df begin
    @rsubset(haskey(section_to_industry, Symbol(:nace_r2)))
    @rtransform begin
      :industry = section_to_industry[Symbol(:nace_r2)]
      :year = parse(Int, :time)
      :value = 1000 * :value
    end
    @select(:industry, :year, :value)
  end
end

function refresh_labor_data!(
  employment = fetch_employment_table(),
  payroll = fetch_payroll_table(),
  dir = production_data_dir,
)
  mkpath(dir)
  employment.l .= only(labor_type)
  CSV.write(
    joinpath(dir, "production_labor.csv"),
    vcat(
      long_format(:qL_l_i, employment, [:l, :industry, :year]),
      long_format(:qLSupply, sum_by(employment, [:year]), [:year]),
      long_format(:vWages_i, payroll, [:industry, :year]),
    ),
  )
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  LaborData.refresh_labor_data!()
end
