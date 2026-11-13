# Fetch Eurostat's energy price data as published: electricity and gas price
# components, the use of mining products split into coal, crude oil and gas,
# quarrying and services, and the energy taxes that industries and households pay.
# Convert electricity prices from EUR per kWh to EUR per GJ. Gas prices stay per
# GJ of gross calorific value. The price tax component already includes VAT.

include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("EnergyBalanceSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module EnergyPricesData

using CSV
using DataFrames

import ..DataUtils: long_format, sum_by
import ..EurostatClient
import ..Settings: calibration_year, country_code, first_data_year
import ..InputOutputSettings:
  eurostat_margin_dataset,
  eurostat_net_product_tax_dataset,
  eurostat_unit,
  eurostat_use_dataset,
  final_use_rename,
  source_mapping
import ..EnergyBalanceSettings: canonical_activity_code, households, industry_source

const energy_prices_data_dir = joinpath(@__DIR__, "..", "data", "energy_prices")
const data_years = first_data_year:calibration_year
const year_params = ["time" => string(y) for y in data_years]

# Published values carry two decimals, so a sum of parts can miss its total by rounding.
const rounding_tolerance = 0.5

# ============================================================================
# Electricity and gas price components
# ============================================================================
const price_component_source = [
  (dataset = "nrg_pc_204_c", product = :P26, buyer = :households, params = (), eur_per_gj = 1 / 0.0036),
  (dataset = "nrg_pc_205_c", product = :P26, buyer = :nonhouseholds, params = (), eur_per_gj = 1 / 0.0036),
  (dataset = "nrg_pc_202_c", product = :P13, buyer = :households, params = ("unit" => "GJ_GCV",), eur_per_gj = 1.0),
  (dataset = "nrg_pc_203_c", product = :P13, buyer = :nonhouseholds, params = ("unit" => "GJ_GCV",), eur_per_gj = 1.0),
]

"""Fetch one dataset's price components in EUR per GJ for the data years."""
function fetch_components(source)
  df = EurostatClient.fetch_table(source.dataset, "geo" => country_code, "currency" => "EUR", source.params...)
  @assert string(calibration_year) in df.time "$country_code publishes no $(source.dataset) for $calibration_year"
  df = df[in.(df.time, Ref(string.(data_years))) .& .!iszero.(df.value), :]
  return DataFrame(
    product = source.product,
    buyer = source.buyer,
    band = df.nrg_cons,
    component = df.nrg_prc,
    year = df.time,
    value = df.value .* source.eur_per_gj,
  )
end

# ============================================================================
# Use of mining products
# ============================================================================
const mining_product = Dict("CPA_B05" => :B05, "CPA_B06" => :B06, "CPA_B07" => :B07, "CPA_B08" => :B08, "CPA_B09" => :B09)
const origin_map = Dict("DOM" => :domestic, "IMP" => :import)

"""Fetch one use table and check that the parts of B add up to B in every cell."""
function fetch_mining_use(dataset, product_column)
  df = EurostatClient.fetch_table(dataset, "unit" => eurostat_unit, "geo" => country_code, year_params...)
  rename!(df, product_column => :cpa)
  key = [:stk_flow, :ind_use, :time]
  parts = sum_by(df[in.(df.cpa, Ref(keys(mining_product))), :], key)
  whole = df[df.cpa .== "CPA_B", [key; :value]]
  check = outerjoin(parts, whole, on = key, renamecols = "_parts" => "_whole")
  @assert all(abs.(coalesce.(check.value_parts, 0.0) .- coalesce.(check.value_whole, 0.0)) .<= rounding_tolerance) "$dataset: B05-B09 do not add up to B"
  return df
end

"""Map the parts of B to model products and uses, and sum by the given index."""
function mining_cells(df, use_map, index)
  df = df[in.(df.cpa, Ref(keys(mining_product))) .& in.(df.ind_use, Ref(keys(use_map))) .& .!iszero.(df.value), :]
  cells = DataFrame(
    product = getindex.(Ref(mining_product), df.cpa),
    use = getindex.(Ref(use_map), df.ind_use),
    origin = get.(Ref(origin_map), df.stk_flow, :total),
    year = df.time,
    value = df.value,
  )
  return sum_by(cells, index)
end

function mining_use()
  basic = fetch_mining_use(eurostat_use_dataset, :prd_ava)
  margins = fetch_mining_use(eurostat_margin_dataset, :cpa2_1)
  taxes = fetch_mining_use(eurostat_net_product_tax_dataset, :cpa2_1)
  return (;
    basic = mining_cells(basic[in.(basic.stk_flow, Ref(keys(origin_map))), :],
      merge(source_mapping("use_industry", :industry), final_use_rename), [:product, :use, :origin, :year]),
    margins = mining_cells(margins[margins.stk_flow .== "TOTAL", :],
      merge(source_mapping("margin_industry", :industry), final_use_rename), [:product, :use, :year]),
    taxes = mining_cells(taxes[taxes.stk_flow .== "TOTAL", :],
      merge(source_mapping("net_product_tax_industry", :industry), final_use_rename), [:product, :use, :year]),
  )
end

# ============================================================================
# Energy taxes by payer
# ============================================================================
# CO2 taxes are part of energy taxes in the source; keep both as published.
const energy_tax = Dict("NRG" => :energy, "NRG_CO2" => :co2)

"""Energy and CO2 taxes paid by each model industry and by households."""
function energy_taxes()
  df = EurostatClient.fetch_table("env_ac_taxind2", "unit" => eurostat_unit, "geo" => country_code, year_params...)
  df = df[in.(df.tax, Ref(keys(energy_tax))), :]
  df.nace_r2 = canonical_activity_code.(df.nace_r2)
  payer = merge(industry_source(unique(df.nace_r2), "env_ac_taxind2"), Dict("EP_HH" => households))
  total = df[df.nace_r2 .== "TOTAL_HH_NRES", [:tax, :time, :value]]
  df = df[in.(df.nace_r2, Ref(keys(payer))), :]
  cells = DataFrame(tax = getindex.(Ref(energy_tax), df.tax), payer = getindex.(Ref(payer), df.nace_r2), year = df.time, value = df.value)
  check = innerjoin(sum_by(df, [:tax, :time]), total, on = [:tax, :time], renamecols = "_parts" => "_total")
  @assert nrow(check) == nrow(total) == 2 * length(data_years) "env_ac_taxind2 must report both taxes in each data year"
  @assert all(abs.(check.value_parts .- check.value_total) .<= rounding_tolerance) "industries and households do not add up to the reported total"
  return sum_by(cells[.!iszero.(cells.value), :], [:tax, :payer, :year])
end

# ============================================================================
# Write
# ============================================================================
function refresh_energy_prices_data!(dir = energy_prices_data_dir)
  mkpath(dir)
  prices = vcat(fetch_components.(price_component_source)...)
  mining = mining_use()
  CSV.write(joinpath(dir, "energy_prices.csv"), vcat(
    long_format(:pEComponent_e_h_n_x, prices, [:product, :buyer, :band, :component, :year]),
    long_format(:qPurchaserUseB_p_u_o, mining.basic, [:product, :use, :origin, :year]),
    long_format(:qMarginBundleB_p_u, mining.margins, [:product, :use, :year]),
    long_format(:vntProductB_p_u, mining.taxes, [:product, :use, :year]),
    long_format(:vtEnergy_x_d, energy_taxes(), [:tax, :payer, :year]),
  ))
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  EnergyPricesData.refresh_energy_prices_data!()
end
