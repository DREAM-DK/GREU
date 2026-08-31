# Fetch and write general-government accounts.
# Map Eurostat items directly to model variables.
# Keep government equations in Government.jl.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("GovernmentSettings.jl")
include("EurostatClient.jl")

module GovernmentData

using CSV
using DataFramesMeta
import ..EurostatClient
using ..Settings: calibration_year, country_code
import ..GovernmentSettings:
  all_na_items,
  government_data_dir,
  government_dataset_code,
  government_sector,
  government_unit,
  na_item_to_var

"""Fetch and map general government accounts to model variables."""
function fetch_government_variables()
  df = EurostatClient.fetch_table(government_dataset_code,
    "unit"        => government_unit,
    "geo"         => country_code,
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    "sector"      => government_sector,
    ("na_item" => it for it in all_na_items)...,
  )
  return @chain df begin
    @rtransform(:variable = string(na_item_to_var[:na_item]))
    @select(:variable, :indices = :time, :value)
  end
end

function refresh_government_data!(dir = government_data_dir)
  mkpath(dir)
  variables = fetch_government_variables()
  CSV.write(joinpath(dir, "government_variables.csv"), variables)
  return variables
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  GovernmentData.refresh_government_data!()
end
