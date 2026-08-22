include(joinpath(@__DIR__, "..", "Settings.jl"))
include("GovernmentSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module GovernmentData

using CSV
using DataFrames
import ..EurostatClient
import ..DataUtils: long_format
using ..Settings: calibration_year, country_code
import ..GovernmentSettings:
  all_na_items,
  government_data_dir,
  government_dataset_code,
  government_sector,
  government_unit,
  na_item_to_var

"""Fetch general government (S13) national accounts from gov_10a_main."""
function fetch_government_accounts()
  df = EurostatClient.fetch_table(government_dataset_code,
    "unit"        => government_unit,
    "geo"         => country_code,
    "sector"      => government_sector,
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("na_item" => it for it in all_na_items)...,
  )
  rename!(df, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:na_item, :year, :value]]
end

"""All government account variables in a single file, one row per (variable, year)."""
function write_government_variables(dir, df)
  CSV.write(joinpath(dir, "government_variables.csv"), vcat([
    long_format(na_item_to_var[code], df[df.na_item .== code, [:year, :value]], [:year])
    for code in all_na_items
  ]...))
end

function refresh_government_data!(dir = government_data_dir)
  mkpath(dir)
  df = fetch_government_accounts()
  write_government_variables(dir, df)
  return df
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  GovernmentData.refresh_government_data!()
end
