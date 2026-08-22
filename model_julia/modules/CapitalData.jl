# Fetch and write capital data for production.
# Include capital stocks, flows, and the investment-product split.
# Use InputOutput's fixed-investment quantity and value contract.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module CapitalData

using CSV
using DataFrames
import ..EurostatClient
import ..DataUtils: long_format, read_cells, sum_by
import ..InputOutputSettings:
  cell_tolerance,
  input_output_data_dir,
  section_to_industry
import ..ProductionSettings:
  capital_flow_dataset,
  capital_stock_dataset,
  flow_asset_to_capital_type,
  flow_unit,
  production_data_dir,
  stock_asset_to_capital_type,
  stock_deflator_unit,
  stock_unit
import ..Settings: calibration_year, country_code

const data_years = (calibration_year - 1):calibration_year
const year_params = ["time" => string(year) for year in data_years]
const capital_nace_to_industry = Dict(string(section) => i for (section, i) in section_to_industry)
const fixed_investment_file = joinpath(input_output_data_dir, "input_output_fixed_investment.csv")

# ============================================================================
# Capital stocks and flows
# ============================================================================

"""Fetch one capital table and map direct A21 rows to model industries."""
function fetch_capital_table(dataset, unit, asset_map, params...)
  df = EurostatClient.fetch_table(
    dataset,
    "unit" => unit,
    "geo" => country_code,
    year_params...,
    params...,
  )
  @assert all(
    isapprox(
      sum(
        row.value
        for row in eachrow(df)
        if row.asset10 == asset &&
          row.nace_r2 in keys(capital_nace_to_industry) &&
          row.time == string(year)
      ),
      only(
        row.value
        for row in eachrow(df)
        if row.asset10 == asset && row.nace_r2 == "TOTAL" && row.time == string(year)
      );
      atol = 1.1,
      rtol = 0,
    )
    for asset in keys(asset_map), year in data_years
  ) "Capital A21 rows must sum to each source total"
  df = df[
    in.(df.asset10, Ref(Set(keys(asset_map)))) .&
    in.(df.nace_r2, Ref(Set(keys(capital_nace_to_industry)))),
    :,
  ]
  df.k = [asset_map[asset] for asset in df.asset10]
  df.industry = [capital_nace_to_industry[code] for code in df.nace_r2]
  df.year = parse.(Int, df.time)
  return sum_by(df, [:k, :industry, :year])
end

# CRC values a stock at current prices. PYR values the same stock at last
# year's prices. Their ratio gives the asset price change.
"""Express capital stocks in calibration-year prices."""
function rebase_to_calibration_prices(current_cost, previous_year_cost)
  change = innerjoin(
    rename(current_cost, :value => :current),
    rename(previous_year_cost, :value => :previous),
    on = [:k, :industry, :year],
  )
  function change_factor(row)
    row.previous != 0 && return row.current / row.previous
    @assert row.current == 0 "A zero prior-price stock needs a zero current-price stock"
    return 1.0
  end
  price_change = Dict(
    (row.k, row.industry, row.year) => change_factor(row)
    for row in eachrow(change)
  )
  factor(k, i, year) = get(price_change, (k, i, year), 1.0)

  rebased = copy(current_cost)
  rebased.value = [
    row.value *
      prod(factor(row.k, row.industry, year) for year in (row.year + 1):calibration_year; init = 1.0) /
      prod(factor(row.k, row.industry, year) for year in (calibration_year + 1):row.year; init = 1.0)
    for row in eachrow(current_cost)
  ]
  return rebased
end

# ============================================================================
# Investment-product split
# ============================================================================

"""Split fixed-investment products across capital types."""
function synthetic_investment_product_split(
  investment,
  investment_product_quantity_data = read_cells(fixed_investment_file, "qI_p"),
  investment_product_value_data = read_cells(fixed_investment_file, "vI_p"),
)
  investment_product = sort(unique(
    p
    for ((p, year), value) in investment_product_quantity_data
    if year == calibration_year && abs(value) > cell_tolerance
  ))
  investment_product_quantity = Dict(
    p => investment_product_quantity_data[p, calibration_year]
    for p in investment_product
  )
  investment_product_value = Dict(
    p => investment_product_value_data[p, calibration_year]
    for p in investment_product
  )
  capital_type = sort(unique(
    row.k for row in eachrow(investment) if row.year == calibration_year
  ))
  capital_type_value = Dict(
    k => sum(
      row.value
      for row in eachrow(investment)
      if row.k == k && row.year == calibration_year
    )
    for k in capital_type
  )

  @assert :structures in capital_type "Investment split needs structures"
  @assert all(>(cell_tolerance), values(capital_type_value)) "Each capital type needs positive investment"

  @assert sum(values(investment_product_quantity)) > cell_tolerance "Fixed investment must be positive"
  @assert isapprox(
    sum(values(capital_type_value)),
    sum(values(investment_product_value));
    rtol = 1e-3,
  ) "Capital and input-output investment values must agree"

  # Construction is all structures. Split each other product by the remaining
  # purchaser-price value of each capital type.
  nonconstruction_capital_value = Dict(
    k => value - (k == :structures ? investment_product_value[:F] : 0.0)
    for (k, value) in capital_type_value
  )
  @assert all(
    >(cell_tolerance),
    values(nonconstruction_capital_value),
  ) "Each capital type needs positive non-construction investment"
  nonconstruction_value = sum(values(nonconstruction_capital_value))
  split = DataFrame([
    (
      product = p,
      k = k,
      value = p == :F ?
        (k == :structures ? investment_product_quantity[p] : 0.0) :
        investment_product_quantity[p] *
          nonconstruction_capital_value[k] / nonconstruction_value,
    )
    for p in investment_product for k in capital_type
  ])
  return split
end

function refresh_capital_data!(dir = production_data_dir)
  mkpath(dir)
  stock = rebase_to_calibration_prices(
    fetch_capital_table(capital_stock_dataset, stock_unit, stock_asset_to_capital_type),
    fetch_capital_table(capital_stock_dataset, stock_deflator_unit, stock_asset_to_capital_type),
  )
  investment = fetch_capital_table(
    capital_flow_dataset,
    flow_unit,
    flow_asset_to_capital_type,
    "na_item" => "P51G",
  )
  investment_product_split = synthetic_investment_product_split(investment)

  CSV.write(joinpath(dir, "production_capital.csv"), vcat(
    long_format(:qK_k_i, stock, [:k, :industry, :year]),
    long_format(:vI_k_i, investment, [:k, :industry, :year]),
  ))
  # Replace this synthetic table with direct country data when it exists.
  CSV.write(
    joinpath(dir, "production_investment_product_split.csv"),
    long_format(:qI_p_k, investment_product_split, [:product, :k]),
  )
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  CapitalData.refresh_capital_data!()
end
