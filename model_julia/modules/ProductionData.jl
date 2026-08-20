include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("EurostatClient.jl")
include("DataRefreshUtils.jl")

module ProductionData

using CSV
using DataFrames
import ..EurostatClient
import ..DataRefreshUtils: long_format, sum_by
import ..InputOutputSettings:
  eurostat_unit,
  eurostat_use_dataset,
  nace_a64_to_a21
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

# ============================================================================
# Eurostat data
# ============================================================================

"""Fetch one capital table and map A64 industries to model industries."""
function fetch_capital_table(dataset, unit, asset_map)
  df = EurostatClient.fetch_table(
    dataset,
    "unit" => unit,
    "geo" => country_code,
    year_params...,
  )
  df = df[
    in.(df.asset10, Ref(Set(keys(asset_map)))) .&
    in.(df.nace_r2, Ref(Set(keys(nace_a64_to_a21)))),
    :,
  ]
  df.k = [asset_map[asset] for asset in df.asset10]
  df.industry = [nace_a64_to_a21[code] for code in df.nace_r2]
  df.year = parse.(Int, df.time)
  return sum_by(df, [:k, :industry, :year])
end

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
# Checked-in data
# ============================================================================

function refresh_production_data!(dir = production_data_dir)
  mkpath(dir)
  stock = rebase_to_calibration_prices(
    fetch_capital_table(capital_stock_dataset, stock_unit, stock_asset_to_capital_type),
    fetch_capital_table(capital_stock_dataset, stock_deflator_unit, stock_asset_to_capital_type),
  )
  investment = fetch_capital_table(
    capital_flow_dataset,
    flow_unit,
    flow_asset_to_capital_type,
  )
  labor = fetch_labor_table()

  CSV.write(joinpath(dir, "production_capital.csv"), vcat(
    long_format(:qK_k_i, stock, [:k, :industry, :year]),
    long_format(:qI_k_i, investment, [:k, :industry, :year]),
  ))
  CSV.write(
    joinpath(dir, "production_labor.csv"),
    long_format(:qL_i, labor, [:industry, :year]),
  )
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  ProductionData.refresh_production_data!()
end
