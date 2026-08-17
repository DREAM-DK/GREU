include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("EurostatClient.jl")
include("DataRefreshUtils.jl")

module InputOutputData

using CSV
using DataFrames
import ..EurostatClient
using ..Settings: calibration_year, country_code
import ..InputOutputSettings:
  P,
  U,
  margin_services,
  accounting_rename,
  accounting_rows,
  cell_tolerance,
  cpa_p64_to_p21,
  demand_rename,
  eurostat_dataset,
  eurostat_margin_dataset,
  eurostat_unit,
  input_output_data_dir,
  margin_final_use_rename,
  nace_a64_to_a21,
  nace_a64_to_p21,
  national_accounts_dataset,
  national_accounts_unit,
  section_to_industry
import ..DataRefreshUtils: long_format, sum_by

const data_years = (calibration_year - 1):calibration_year
const year_params = ["time" => string(y) for y in data_years]

# Index of a direct-use cell, in the order the model reads it.
const cell_index = [:product, :use, :origin, :year]
const cell_columns = [cell_index; :value]
sum_cells(parts...) = sum_by(vcat(parts...), cell_index)

# ============================================================================
# Eurostat fetches
# ============================================================================

function fetch_io_table(country_dimension)
  df = EurostatClient.fetch_table(
    eurostat_dataset,
    "unit" => eurostat_unit,
    country_dimension => country_code,
    year_params...,
  )
  rename!(df, :ind_ava => :row, :ind_use => :use, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:row, :use, :c_orig, :c_dest, :year, :value]]
end

"""National trade and transport margins by product and use."""
function fetch_margin_table()
  df = EurostatClient.fetch_table(
    eurostat_margin_dataset,
    "unit" => eurostat_unit,
    "stk_flow" => "TOTAL",
    "geo" => country_code,
    year_params...,
  )
  use_rename = merge(nace_a64_to_a21, margin_final_use_rename)
  df = df[
    in.(df.cpa2_1, Ref(Set(keys(cpa_p64_to_p21)))) .&
    in.(df.ind_use, Ref(Set(keys(use_rename)))),
    :,
  ]
  df.product = [cpa_p64_to_p21[code] for code in df.cpa2_1]
  df.use = [use_rename[code] for code in df.ind_use]
  df.year = parse.(Int, df.time)
  return sum_by(df, [:product, :use, :year])
end

function fetch_country_table(dataset, dimension, values)
  df = EurostatClient.fetch_table(
    dataset,
    "unit" => national_accounts_unit,
    "geo" => country_code,
    (dimension => value for value in values)...,
    year_params...,
  )
  df.year = parse.(Int, df.time)
  return df
end

"""Fetch a country table and map `dimension` codes to model names in `target_col`."""
function mapped_country_table(dataset, dimension, mapping, target_col)
  df = fetch_country_table(dataset, dimension, collect(keys(mapping)))
  df[!, target_col] = [mapping[code] for code in df[!, Symbol(dimension)]]
  return df[:, [target_col, :year, :value]]
end

# ============================================================================
# Source table
# ============================================================================

"""Use within the country by product, use, and country of origin."""
function domestic_flows(df)
  row_rename = merge(nace_a64_to_p21, accounting_rename)
  use_rename = merge(nace_a64_to_a21, demand_rename)
  df = df[
    in.(df.row, Ref(Set(keys(row_rename)))) .&
    in.(df.use, Ref(Set(keys(use_rename)))),
    :,
  ]
  df.c_orig = ifelse.(in.(df.c_orig, Ref(("DOM", country_code))), :domestic, :import)
  df.row = [row_rename[code] for code in df.row]
  df.use = [use_rename[code] for code in df.use]
  rename!(df, :c_orig => :origin)
  return sum_by(df, [:row, :use, :origin, :year])
end

"""Domestic output delivered abroad, summed into the export use column."""
function export_flows(df)
  row_rename = merge(nace_a64_to_p21, accounting_rename)
  df = df[(df.c_dest .!= country_code) .& in.(df.row, Ref(Set(keys(row_rename)))), :]
  df.row = [row_rename[code] for code in df.row]
  df = sum_by(df, [:row, :year])
  insertcols!(df, :use => :X, :origin => :domestic)
  return df[:, [:row, :use, :origin, :year, :value]]
end

"""Product rows and value-added accounting rows by use and origin.
`domestic` and `exports` are the raw `c_dest` and `c_orig` fetches."""
function input_output_table(domestic, exports)
  table = sum_by(
    vcat(domestic_flows(domestic), export_flows(exports)),
    [:row, :use, :origin, :year],
  )
  is_product = in.(table.row, Ref(Set(P)))
  is_accounting =
    (table.origin .== :domestic) .& in.(table.row, Ref(Set(accounting_rows)))
  return table[in.(table.use, Ref(Set(U))) .& (is_product .| is_accounting), :]
end

reported_direct_use(table) = rename(
  table[in.(table.row, Ref(Set(P))), [:row, :use, :origin, :year, :value]],
  :row => :product,
)

"""One value-added accounting row (product taxes, wages, ...) by use."""
accounting_table(table, row) =
  table[(table.origin .== :domestic) .& (table.row .== row), [:use, :year, :value]]

"""Direct purchases recorded against household consumption: residents' spending
abroad (`OP_RES`) or non-residents' spending in the country (`OP_NRES`)."""
function direct_purchase_adjustment(domestic, code)
  df = domestic[domestic.row .== code, [:use, :year, :value]]
  df = df[in.(df.use, Ref(Set(keys(demand_rename)))), :]
  df.use = [demand_rename[use] for use in df.use]
  df = sum_by(df, [:use, :year])
  return df[(df.use .== :C) .& (abs.(df.value) .> cell_tolerance), :]
end

# ============================================================================
# Reported, estimated, and model-set direct use
# ============================================================================

"""Non-residents' purchases in the country. The product cells already include
these purchases, so only store the positive total for the tourism account."""
function reported_tourist_spend(nonresidents)
  tourists = copy(nonresidents[:, [:year, :value]])
  tourists.value .*= -1
  @assert all(tourists.value .>= 0) "OP_NRES must be non-positive in the source table"
  return tourists
end

"""Add residents' purchases abroad as travel imports. Eurostat gives no product
split, so use the combined private-consumption product mix."""
function resident_purchase_imports(reported, residents)
  @assert all(residents.value .>= 0) "OP_RES must be non-negative in the source table"
  basis = reported[
    (reported.use .== :C) .& (reported.value .> cell_tolerance),
    :,
  ]
  basis = sum_by(basis, [:product, :year])
  totals = rename(sum_by(basis, [:year]), :value => :total)
  shares = innerjoin(basis, totals, on = :year)
  @assert all(shares.total .> cell_tolerance) "Travel imports need a consumption product mix"
  shares.value ./= shares.total
  rename!(shares, :value => :share)
  imports = innerjoin(residents, shares[:, [:product, :year, :share]], on = :year)
  imports.value .*= imports.share
  insertcols!(imports, :origin => :import)
  return imports[:, cell_columns]
end

"""Deflate tourist spend with the combined private-consumption price. At the
benchmark, this price is purchaser spend divided by direct consumption volume."""
function tourist_quantities(
  tourist_spend,
  direct,
  carried_margins,
  service_totals,
  product_taxes,
)
  direct_totals = rename(
    sum_by(direct[direct.use .== :C, :], [:year]),
    :value => :direct,
  )
  service_use_totals = rename(
    sum_by(service_totals[service_totals.use .== :C, :], [:year]),
    :value => :services,
  )
  margin_totals = rename(
    sum_by(carried_margins[carried_margins.use .== :C, :], [:year]),
    :value => :margins,
  )
  tax_totals = rename(
    product_taxes[product_taxes.use .== :C, [:year, :value]],
    :value => :taxes,
  )
  prices = innerjoin(direct_totals, service_use_totals, on = :year)
  prices = innerjoin(prices, margin_totals, on = :year)
  prices = innerjoin(prices, tax_totals, on = :year)
  @assert nrow(prices) == nrow(tourist_spend) "Each tourist total needs a consumption price"
  prices.quantity = prices.direct .- prices.services
  @assert all(prices.quantity .> cell_tolerance) "Consumption volume must be positive"
  prices.price = (prices.quantity .+ prices.margins .+ prices.taxes) ./ prices.quantity
  quantities = innerjoin(tourist_spend, prices[:, [:year, :price]], on = :year)
  quantities.value ./= quantities.price
  return quantities[:, [:year, :value]]
end

"""Imports sold abroad with no domestic processing. The IO export table has
domestic output only, so the gap to national-accounts exports is re-export. SNA
books the gap as a trade margin, so it goes to wholesale and retail trade
(`:G`)."""
function reexport_flows(direct_before_reexports, product_taxes, tourist_spend)
  exports = mapped_country_table(
    national_accounts_dataset,
    "na_item",
    Dict("P6" => :X),
    :use,
  )
  existing = direct_before_reexports[direct_before_reexports.use .== :X, :]
  existing = rename(sum_by(existing, [:year]), :value => :existing)
  export_taxes = rename(
    product_taxes[product_taxes.use .== :X, [:year, :value]],
    :value => :tax,
  )
  reexports = leftjoin(exports, existing, on = :year)
  reexports = leftjoin(reexports, export_taxes, on = :year)
  reexports = leftjoin(reexports, rename(tourist_spend, :value => :tourists), on = :year)
  reexports.existing = coalesce.(reexports.existing, 0.0)
  reexports.tax = coalesce.(reexports.tax, 0.0)
  reexports.tourists = coalesce.(reexports.tourists, 0.0)
  reexports.value .-= reexports.existing .+ reexports.tax .+ reexports.tourists
  @assert all(reexports.value .>= -cell_tolerance) "Estimated re-exports must not be negative"
  reexports = reexports[reexports.value .> cell_tolerance, [:year, :value]]
  insertcols!(reexports, :product => :G, :origin => :import, :use => :X)
  return reexports[:, cell_columns]
end

"""Split T1620 into carried-product margins and margin-service totals."""
function margin_source_parts(table)
  is_service = in.(table.product, Ref(Set(margin_services)))
  @assert all(table.value[is_service] .<= cell_tolerance) "Margin-service rows must not be positive"
  carried = table[.!is_service .& (abs.(table.value) .> cell_tolerance), :]
  services = rename(table[is_service .& (table.value .< -cell_tolerance), :], :product => :service)
  services.value .*= -1
  carried_totals = rename(sum_by(carried, [:use, :year]), :value => :carried)
  service_totals = rename(sum_by(services, [:use, :year]), :value => :services)
  balances = innerjoin(carried_totals, service_totals, on = [:use, :year])
  @assert nrow(balances) == nrow(carried_totals) == nrow(service_totals) "Each margin use needs both sides of T1620"
  @assert all(isapprox.(balances.carried, balances.services; atol = 0.15, rtol = 0)) "T1620 margin sides must balance after source rounding"
  return carried, services
end

"""Take reported margin services out of direct use. T1620 supplies each
service total. FIGARO direct-use cells supply its standard origin shares."""
function margin_reclassification(direct_before_margins, service_totals)
  basis = innerjoin(
    rename(
      direct_before_margins[
        in.(direct_before_margins.product, Ref(Set(margin_services))),
        :,
      ],
      :product => :service,
    ),
    unique(service_totals[:, [:service, :use, :year]]),
    on = [:service, :use, :year],
  )
  totals = rename(sum_by(basis, [:service, :use, :year]), :value => :total)
  @assert nrow(totals) == nrow(service_totals) "Each margin service needs an origin basis"
  shares = innerjoin(basis, totals, on = [:service, :use, :year])
  @assert all(abs.(shares.total) .> cell_tolerance) "Each margin service needs a non-zero origin basis"
  shares.share = shares.value ./ shares.total
  services = innerjoin(
    service_totals,
    shares[:, [:service, :use, :origin, :year, :share]],
    on = [:service, :use, :year],
  )
  services.value .*= services.share
  @assert all(services.value .>= -cell_tolerance) "Margin-service origin cells must be non-negative"
  select!(services, [:service, :use, :origin, :year, :value])

  adjustments = rename(copy(services), :service => :product)
  adjustments.value .*= -1
  return adjustments, services
end

"""Direct use split into its reported, estimated, and reclassified parts, plus
the product-tax row. Each estimate uses the parts before it as its basis."""
function direct_use_parts(table, domestic, carried_margins, service_totals)
  reported = reported_direct_use(table)
  product_taxes = accounting_table(table, :vProductTax_u)
  tourist_spend = reported_tourist_spend(direct_purchase_adjustment(domestic, "OP_NRES"))
  estimated = resident_purchase_imports(
    reported,
    direct_purchase_adjustment(domestic, "OP_RES"),
  )
  tourists = tourist_quantities(
    tourist_spend,
    sum_cells(reported, estimated),
    carried_margins,
    service_totals,
    product_taxes,
  )
  estimated = sum_cells(
    estimated,
    reexport_flows(sum_cells(reported, estimated), product_taxes, tourist_spend),
  )
  reclassification, services =
    margin_reclassification(sum_cells(reported, estimated), service_totals)
  return reported, estimated, reclassification, services, product_taxes, tourists
end

# ============================================================================
# Supply and aggregate checks
# ============================================================================

"""Domestic supply by product and industry. The first data build maps each
product to the industry of the same NACE section."""
function reported_supply(reported)
  supply = sum_by(reported[reported.origin .== :domestic, :], [:product, :year])
  supply.industry = [section_to_industry[product] for product in supply.product]
  return supply[:, [:product, :industry, :year, :value]]
end

"""Purchaser-price spend by use: direct cells, carried-product margins, taxes."""
demand_checks(direct, carried_margins, product_taxes) = sum_by(
  vcat(
    sum_by(direct, [:use, :year]),
    sum_by(carried_margins, [:use, :year]),
    product_taxes,
  ),
  [:use, :year],
)

# ============================================================================
# Checked-in files
# ============================================================================

function refresh_input_output_data!(dir = input_output_data_dir)
  mkpath(dir)
  domestic = fetch_io_table("c_dest")
  exports = fetch_io_table("c_orig")
  carried_margins, margin_service_totals = margin_source_parts(fetch_margin_table())
  table = input_output_table(domestic, exports)
  reported, estimated, reclassification, services, product_taxes, tourists =
    direct_use_parts(table, domestic, carried_margins, margin_service_totals)
  direct = sum_cells(reported, estimated, reclassification)
  supply = reported_supply(reported)
  national = mapped_country_table(
    national_accounts_dataset,
    "na_item",
    Dict("P6" => :vX_reported, "P7" => :vM_reported),
    :variable,
  )

  CSV.write(joinpath(dir, "input_output.csv"), table)
  CSV.write(
    joinpath(dir, "input_output_supply.csv"),
    long_format(:qY_p_i_reported, supply, [:product, :industry, :year]),
  )
  CSV.write(joinpath(dir, "input_output_direct_use.csv"), vcat(
    long_format(:qD_p_u_o_reported, reported, cell_index),
    long_format(:qD_p_u_o_estimated, estimated, cell_index),
    long_format(:qD_p_u_o_reclassified, reclassification, cell_index),
  ))
  CSV.write(
    joinpath(dir, "input_output_margins.csv"),
    vcat(
      long_format(:qMargin_p_u_reported, carried_margins, [:product, :use, :year]),
      long_format(:qS_s_u_o_reclassified, services, [:service, :use, :origin, :year]),
    ),
  )
  CSV.write(
    joinpath(dir, "input_output_price_adjustments.csv"),
    long_format(:vProductTax_u_reported, product_taxes, [:use, :year]),
  )
  CSV.write(joinpath(dir, "input_output_checks.csv"), vcat(
    long_format(
      :vD_u_reported,
      demand_checks(direct, carried_margins, product_taxes),
      [:use, :year],
    ),
    long_format(:vY_reported, sum_by(supply, [:year]), [:year]),
    long_format(:qCTourist_reported, tourists, [:year]),
    (
      long_format(variable, national[national.variable .== variable, :], [:year])
      for variable in (:vX_reported, :vM_reported)
    )...,
  ))
  return table
end

end # module
