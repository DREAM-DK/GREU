# Fetch and write gross value added by industry for production.
# Map direct A21 rows from nama_10_a64 and rebase quantities to calibration-year prices.
# Keep production equations in Production.jl.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module GrossValueAddedData

using CSV
using DataFrames
import ..EurostatClient
import ..DataUtils: long_format, sum_by
import ..ProductionSettings:
  gva_dataset,
  gva_deflator_unit,
  gva_na_item,
  gva_nace_to_industry,
  gva_unit,
  production_data_dir,
  production_tax_na_item
import ..Settings: calibration_year, country_code, first_data_year

const data_years = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_years]

# ============================================================================
# Gross value added and production taxes less subsidies
# ============================================================================

"""Fetch one nama_10_a64 item and map direct A21 rows to model industries."""
function fetch_gva_items(unit, na_item)
  df = EurostatClient.fetch_table(
    gva_dataset,
    "unit" => unit,
    "na_item" => na_item,
    "geo" => country_code,
    year_params...,
  )
  @assert all(
    isapprox(
      sum(
        row.value
        for row in eachrow(df)
        if row.nace_r2 in keys(gva_nace_to_industry) &&
          row.time == string(year)
      ),
      only(
        row.value
        for row in eachrow(df)
        if row.nace_r2 == "TOTAL" && row.time == string(year)
      );
      atol = 1.1,
      rtol = 0,
    )
    for year in data_years
  ) "GVA A21 rows must sum to each source total"
  df = df[in.(df.nace_r2, Ref(Set(keys(gva_nace_to_industry)))), :]
  df.industry = [gva_nace_to_industry[code] for code in df.nace_r2]
  df.year = parse.(Int, df.time)
  return sum_by(df, [:industry, :year])
end

# CP values GVA at current prices. PYP values the same GVA at last year's
# prices. Their ratio gives the industry price change.
"""Express gross value added in calibration-year prices."""
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
  price_change = Dict(
    (row.industry, row.year) => change_factor(row)
    for row in eachrow(change)
  )
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
  current = fetch_gva_items(gva_unit, gva_na_item)
  quantity = rebase_to_calibration_prices(current, fetch_gva_items(gva_deflator_unit, gva_na_item))
  production_taxes = fetch_gva_items(gva_unit, production_tax_na_item)
  CSV.write(joinpath(dir, "production_gva.csv"), vcat(
    long_format(:qGVA_i, quantity, [:industry, :year]),
    long_format(:vGVA_i, current, [:industry, :year]),
    long_format(:vProductionTax_i, production_taxes, [:industry, :year]),
  ))
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  GrossValueAddedData.refresh_gross_value_added_data!()
end
