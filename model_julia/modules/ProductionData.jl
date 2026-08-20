include(joinpath(@__DIR__, "..", "Settings.jl"))
include("ProductionSettings.jl")
include("EurostatClient.jl")
include("DataRefreshUtils.jl")

module ProductionData

using CSV
using DataFrames
import ..EurostatClient
using ..Settings: calibration_year, country_code
import ..DataRefreshUtils: sum_by, long_format
import ..ProductionSettings:
  stock_asset_to_capital_type,
  flow_asset_to_capital_type,
  capital_flow_dataset,
  capital_stock_dataset,
  flow_unit,
  production_data_dir,
  stock_deflator_unit,
  stock_unit

const nace_sections = string.('A':'U')

# ==========================================================================
# Eurostat fetch
# ==========================================================================

"""Fetch one capital table for the model country."""
function fetch_capital_table(dataset, unit, asset_map)
  assets = sort(collect(keys(asset_map)))

  df = EurostatClient.fetch_table(dataset,
    "unit"        => unit,
    "geo"         => country_code,
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("asset10" => asset for asset in assets)...,
  )

  return sum_by(DataFrame(
    k        = [asset_map[code] for code in df.asset10],
    industry = [Symbol(first(code)) for code in df.nace_r2],
    year     = parse.(Int, df.time),
    value    = df.value,
  ), [:k, :industry, :year])
end

# ==========================================================================
# Deflation
# ==========================================================================
# CRC values a stock at this year's prices; PYR values the same stock at last
# year's. Their ratio is a pure price change with no volume effect, so chaining
# those changes rebases every year onto the calibration year.
#
# Without this the stock grows partly because assets got more expensive, so it
# appears to grow by more than gross investment — impossible in real terms —
# and the depreciation rate calibrated from the accumulation equation comes out
# too low or negative.

"""Express capital stocks in calibration-year prices."""
function rebase_to_calibration_prices(current_cost, previous_year_cost)
  change = innerjoin(
    rename(current_cost, :value => :crc),
    rename(previous_year_cost, :value => :pyr),
    on = [:k, :industry, :year],
  )
  rate = Dict((row.k, row.industry, row.year) => row.crc / row.pyr for row in eachrow(change))
  factor(k, i, y) = get(rate, (k, i, y), 1.0)

  rebased = copy(current_cost)
  rebased.value = [
    row.value *
      prod(factor(row.k, row.industry, y) for y in (row.year + 1):calibration_year; init = 1.0) /
      prod(factor(row.k, row.industry, y) for y in (calibration_year + 1):row.year; init = 1.0)
    for row in eachrow(current_cost)
  ]
  return rebased
end


# ==========================================================================
# Output files
# ==========================================================================

"""Capital stock and investment, one row per (variable, capital type, industry, year)."""
function write_production_variables(dir, stock, flow)
  CSV.write(joinpath(dir, "production_capital.csv"), vcat(
    long_format(:qK_k_i, stock, [:k, :industry, :year]),
    long_format(:qI_k_i, flow, [:k, :industry, :year]),
  ))
end

function refresh_production_data!(dir = production_data_dir)
  mkpath(dir)
  #notfinished, look through
  stock = rebase_to_calibration_prices(
    fetch_capital_table(capital_stock_dataset, stock_unit, stock_asset_to_capital_type),
    fetch_capital_table(capital_stock_dataset, stock_deflator_unit, stock_asset_to_capital_type),
  )
  
  flow = fetch_capital_table(
    capital_flow_dataset,
    flow_unit,
    flow_asset_to_capital_type,
  )
  write_production_variables(dir, stock, flow)
  return stock, flow
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  ProductionData.refresh_production_data!()
end

