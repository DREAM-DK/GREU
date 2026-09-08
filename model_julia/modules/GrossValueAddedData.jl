# Fetch and write gross value added by industry for production.
# Map each Eurostat source at the generated common resolution and rebase quantities to calibration-year prices.
# Keep production equations in Production.jl.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module GrossValueAddedData

using CSV
using DataFrames
using DataFramesMeta
import ..EurostatClient
import ..DataUtils: long_format
import ..InputOutputSettings: source_mapping
import ..ProductionSettings:
  gva_dataset,
  gva_deflator_unit,
  gva_na_item,
  gva_unit,
  production_data_dir,
  production_tax_na_item
import ..Settings: calibration_year, country_code, first_data_year

const data_years = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_years]

"""Fetch one nama_10_a64 item using the source-specific tiling of the common resolution."""
function fetch_gva_items(unit, na_item, source_name)
  mapping = source_mapping(source_name, :industry)
  df = EurostatClient.fetch_table(
    gva_dataset,
    "unit" => unit,
    "na_item" => na_item,
    "geo" => country_code,
    year_params...,
  )
  result = @chain df begin
    @rsubset(haskey(mapping, string(:nace_r2)))
    @rtransform begin
      :industry = mapping[string(:nace_r2)]
      :year = parse(Int, :time)
    end
    @by([:industry, :year], :value = sum(skipmissing(:value); init = 0.0))
  end
  @assert Set(result.year) == Set(data_years) "$source_name must report every model data year"
  return result
end

function rebase_to_calibration_prices(current_price, previous_year_price)
  change = innerjoin(
    rename(current_price, :value => :current),
    rename(previous_year_price, :value => :previous),
    on = [:industry, :year],
  )
  function change_factor(row)
    row.previous != 0 && return row.current / row.previous
    @assert row.current == 0 "A zero prior-price GVA needs a zero current-price GVA"
    return 1.0
  end
  price_change = Dict((row.industry, row.year) => change_factor(row) for row in eachrow(change))
  factor(i, year) = get(price_change, (i, year), 1.0)
  rebased = copy(current_price)
  rebased.value = [
    row.value *
      prod(factor(row.industry, year) for year in (row.year + 1):calibration_year; init = 1.0) /
      prod(factor(row.industry, year) for year in (calibration_year + 1):row.year; init = 1.0)
    for row in eachrow(current_price)
  ]
  return rebased
end

function refresh_gross_value_added_data!(dir = production_data_dir)
  mkpath(dir)
  current = fetch_gva_items(gva_unit, gva_na_item, "gva_current")
  previous = fetch_gva_items(gva_deflator_unit, gva_na_item, "gva_previous_prices")
  quantity = rebase_to_calibration_prices(current, previous)
  production_taxes = fetch_gva_items(gva_unit, production_tax_na_item, "production_taxes")
  CSV.write(joinpath(dir, "production_gva.csv"), vcat(
    long_format(:qGVA_i, quantity, [:industry, :year]),
    long_format(:vGVA_i, current, [:industry, :year]),
    long_format(:vntProduction_i, production_taxes, [:industry, :year]),
  ))
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  GrossValueAddedData.refresh_gross_value_added_data!()
end
