# Fetch and transform national supply-use tables.
# Write model input files and the fixed-investment data contract.
# Keep input-output equations in InputOutput.jl.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module InputOutputData

using CSV
using DataFrames
import ..EurostatClient
using ..Settings: calibration_year, country_code, first_data_year
import ..InputOutputSettings:
  margin_services,
  cell_tolerance,
  cpa_p64_to_p21,
  eurostat_supply_dataset,
  eurostat_use_dataset,
  eurostat_margin_dataset,
  eurostat_net_product_tax_dataset,
  eurostat_unit,
  final_use_rename,
  input_output_data_dir,
  nace_a64_to_a21,
  source_industry,
  final_uses
import ..DataUtils: long_format, sum_by

const data_years = first_data_year:calibration_year
const year_params = ["time" => string(y) for y in data_years]

# Index of a purchaser-use cell, in the order the model reads it.
const cell_index = [:product, :use, :origin, :year]
const cell_columns = [cell_index; :value]
sum_cells(parts...) = sum_by(vcat(parts...), cell_index)

# ============================================================================
# Supply and use tables
# ============================================================================

"""Domestic output by product and industry from the national supply table.

The detailed T15 cells do not add to the balanced T1610 product totals. Keep
their industry shares and scale each product row to domestic use.
"""
function fetch_supply_table(domestic_use)
  df = EurostatClient.fetch_table(
    eurostat_supply_dataset,
    "unit" => eurostat_unit,
    "stk_flow" => "TOTAL",
    "geo" => country_code,
    year_params...,
  )
  df.year = parse.(Int, df.time)
  supply = df[
    in.(df.prd_amo, Ref(Set(keys(cpa_p64_to_p21)))) .&
    in.(df.ind_impv, Ref(Set(keys(nace_a64_to_a21)))),
    :,
  ]
  supply.product = [cpa_p64_to_p21[code] for code in supply.prd_amo]
  supply.industry = [nace_a64_to_a21[code] for code in supply.ind_impv]
  supply = sum_by(supply, [:product, :industry, :year])

  reported = rename(
    sum_by(domestic_use[domestic_use.origin .== :domestic, :], [:product, :year]),
    :value => :reported,
  )
  cell_totals = rename(sum_by(supply, [:product, :year]), :value => :cell_total)
  scales = innerjoin(reported, cell_totals, on = [:product, :year])
  @assert nrow(scales) == nrow(reported) == nrow(cell_totals) "Each supply row needs T15 cells and T1610 use"
  @assert all(
    (abs.(scales.cell_total) .> cell_tolerance) .|
    (abs.(scales.reported) .<= cell_tolerance)
  ) "Each non-zero T1610 supply total needs non-zero T15 product-industry cells"
  scales.scale = [
    abs(cell_total) > cell_tolerance ? reported / cell_total : 0.0
    for (reported, cell_total) in zip(scales.reported, scales.cell_total)
  ]
  supply = leftjoin(supply, scales[:, [:product, :year, :scale]], on = [:product, :year])
  supply.value .*= supply.scale
  return supply[:, [:product, :industry, :year, :value]]
end

"""Raw national use table at basic prices."""
function fetch_use_table()
  df = EurostatClient.fetch_table(
    eurostat_use_dataset,
    "unit" => eurostat_unit,
    "geo" => country_code,
    year_params...,
  )
  df.year = parse.(Int, df.time)
  @assert Set(df.year) == Set(data_years) "T1610 must report each input-output data year"
  return df
end

"""Fetch and map one national product-by-use table."""
function fetch_product_use_table(dataset)
  df = EurostatClient.fetch_table(
    dataset,
    "unit" => eurostat_unit,
    "stk_flow" => "TOTAL",
    "geo" => country_code,
    year_params...,
  )
  use_rename = merge(nace_a64_to_a21, final_use_rename)
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

"""National trade and transport margins by product and use."""
fetch_margin_table() = fetch_product_use_table(eurostat_margin_dataset)

"""Net product taxes by product and use.

T1630 includes D21 product taxes, such as VAT and tariffs, less D31 product
subsidies. A tax module can split this net total into gross flows and tax types.
"""
function fetch_net_product_tax_table()
  taxes = fetch_product_use_table(eurostat_net_product_tax_dataset)
  @assert Set(taxes.year) == Set(data_years) "T1630 must report each input-output data year"
  return taxes
end

# ============================================================================
# Reported use
# ============================================================================

"""Basic-price use by product, use, and domestic or import origin."""
function reported_use(df)
  use_rename = merge(nace_a64_to_a21, final_use_rename)
  origin_rename = Dict("DOM" => :domestic, "IMP" => :import)
  df = df[
    in.(df.prd_ava, Ref(Set(keys(cpa_p64_to_p21)))) .&
    in.(df.ind_use, Ref(Set(keys(use_rename)))) .&
    in.(df.stk_flow, Ref(Set(keys(origin_rename)))),
    :,
  ]
  df.product = [cpa_p64_to_p21[code] for code in df.prd_ava]
  df.use = [use_rename[code] for code in df.ind_use]
  df.origin = [origin_rename[code] for code in df.stk_flow]
  return sum_by(df, cell_index)
end

"""One national-use accounting row by model use."""
function accounting_table(df, row)
  use_rename = merge(nace_a64_to_a21, final_use_rename)
  df = df[
    (df.stk_flow .== "TOTAL") .&
    (df.prd_ava .== row) .&
    in.(df.ind_use, Ref(Set(keys(use_rename)))),
    :,
  ]
  df.use = [use_rename[code] for code in df.ind_use]
  return sum_by(df, [:use, :year])
end

"""One source row and column by year."""
function accounting_series(df, row, column; stock_flow = "TOTAL")
  series = df[
    (df.stk_flow .== stock_flow) .&
    (df.prd_ava .== row) .&
    (df.ind_use .== column),
    [:year, :value],
  ]
  @assert Set(series.year) == Set(data_years) "$row/$column/$stock_flow must report each input-output data year"
  return series
end

"""Direct purchases recorded against household consumption: residents' spending
abroad (`OP_RES`) or non-residents' spending in the country (`OP_NRES`)."""
function direct_purchase_adjustment(df, code)
  df = df[
    (df.stk_flow .== "TOTAL") .&
    (df.prd_ava .== code) .&
    (df.ind_use .== "P3_S14") .&
    (abs.(df.value) .> cell_tolerance),
    [:year, :value],
  ]
  insertcols!(df, :use => :C)
  return df[:, [:use, :year, :value]]
end

# ============================================================================
# Purchaser use
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

"""Take reported margin services out of purchaser use. T1620 supplies each
service total. T1610 supplies its domestic and import shares."""
function margin_reclassification(purchaser_use_before_margins, service_totals)
  basis = innerjoin(
    rename(
      purchaser_use_before_margins[
        in.(purchaser_use_before_margins.product, Ref(Set(margin_services))),
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

"""Build the model's purchaser-use cells from T1610 and its valuation tables."""
function purchaser_use_data(
  reported,
  residents,
  service_totals,
)
  resident_imports = resident_purchase_imports(reported, residents)
  before_margins = sum_cells(reported, resident_imports)
  reclassification, services = margin_reclassification(before_margins, service_totals)
  return sum_cells(before_margins, reclassification), services
end

"""Give fixed-investment quantity and purchaser value by product."""
function fixed_investment_data(purchaser_use, carried_margins, net_product_taxes)
  quantity = rename(
    sum_by(purchaser_use[purchaser_use.use .== :K, :], [:product, :year]),
    :value => :quantity,
  )
  margins = Dict(
    (row.product, row.year) => row.value
    for row in eachrow(carried_margins) if row.use == :K
  )
  taxes = Dict(
    (row.product, row.year) => row.value
    for row in eachrow(net_product_taxes) if row.use == :K
  )
  quantity_keys = Set((row.product, row.year) for row in eachrow(quantity))
  @assert keys(margins) ⊆ quantity_keys "Each investment margin needs product quantity"
  @assert keys(taxes) ⊆ quantity_keys "Each investment tax needs product quantity"
  quantity.purchaser_value = [
    row.quantity +
      get(margins, (row.product, row.year), 0.0) +
      get(taxes, (row.product, row.year), 0.0)
    for row in eachrow(quantity)
  ]
  sort!(quantity, [:year, :product])
  return quantity
end

# ============================================================================
# Refresh
# ============================================================================

function build_input_output_data()
  use_table = fetch_use_table()
  reported = reported_use(use_table)
  supply = fetch_supply_table(reported)
  carried_margins, margin_service_totals = margin_source_parts(fetch_margin_table())
  net_product_taxes = fetch_net_product_tax_table()
  net_product_tax_totals = accounting_table(use_table, "D21X31")
  residents = direct_purchase_adjustment(use_table, "OP_RES")
  tourist_spend = reported_tourist_spend(direct_purchase_adjustment(use_table, "OP_NRES"))
  purchaser_use, services = purchaser_use_data(
    reported,
    residents,
    margin_service_totals,
  )
  imports = sum_by(
    vcat(
      accounting_series(use_table, "CPA_TOTAL", "TU"; stock_flow = "IMP"),
      residents[:, [:year, :value]],
    ),
    [:year],
  )
  exports = sum_by(
    vcat(
      accounting_series(use_table, "P2_ADJ", "P6"),
      tourist_spend,
    ),
    [:year],
  )
  output = accounting_series(use_table, "P1", "TOTAL")
  fixed_investment = fixed_investment_data(
    purchaser_use,
    carried_margins,
    net_product_taxes,
  )

  return (;
    use_table,
    supply,
    purchaser_use,
    carried_margins,
    services,
    net_product_taxes,
    net_product_tax_totals,
    tourist_spend,
    imports,
    exports,
    output,
    fixed_investment,
  )
end

function write_input_output_data!(data, dir = input_output_data_dir)
  mkpath(dir)
  purchaser_use_p_u = sum_by(data.purchaser_use, [:product, :use, :year])
  q_p_u = Dict((row.product, row.use, row.year) => row.value for row in eachrow(purchaser_use_p_u))
  @assert Set((row.product, row.use, row.year) for row in eachrow(data.carried_margins)) ⊆ keys(q_p_u) "Each reported margin needs purchaser use"
  @assert Set((row.product, row.use, row.year) for row in eachrow(data.net_product_taxes)) ⊆ keys(q_p_u) "Each net product tax needs purchaser use"
  @assert all(abs(q_p_u[row.product, row.use, row.year]) > cell_tolerance for row in eachrow(data.net_product_taxes) if row.year == calibration_year) "Each net product tax needs non-zero purchaser use"
  @assert all(abs(q_p_u[row.product, row.use, row.year]) > cell_tolerance for row in eachrow(data.carried_margins) if row.year == calibration_year) "Each margin rate needs non-zero purchaser use"
  tax = Dict((row.use, row.year) => row.value for row in eachrow(data.net_product_tax_totals))
  net_product_tax_u = DataFrame([
    (use = u, year = year, value = get(tax, (u, year), 0.0))
    for u in [source_industry; final_uses] for year in data_years
  ])

  CSV.write(
    joinpath(dir, "input_output_supply.csv"),
    long_format(:qY_p_i, data.supply, [:product, :industry, :year]),
  )
  CSV.write(
    joinpath(dir, "input_output_purchaser_use.csv"),
    vcat(
      long_format(:qPurchaserUse_p_u_o, data.purchaser_use, cell_index),
      long_format(:qPurchaserUse_p_u, purchaser_use_p_u, [:product, :use, :year]),
      long_format(:qM_p_i, rename(purchaser_use_p_u[in.(purchaser_use_p_u.use, Ref(Set(source_industry))), :], :use => :industry), [:product, :industry, :year]),
      long_format(:qC_p, select(purchaser_use_p_u[purchaser_use_p_u.use .== :C, :], :product, :year, :value), [:product, :year]),
      long_format(:qG_p, select(purchaser_use_p_u[purchaser_use_p_u.use .== :G, :], :product, :year, :value), [:product, :year]),
      long_format(:qI_p, select(purchaser_use_p_u[purchaser_use_p_u.use .== :K, :], :product, :year, :value), [:product, :year]),
      long_format(:qX_p, select(purchaser_use_p_u[purchaser_use_p_u.use .== :X, :], :product, :year, :value), [:product, :year]),
      long_format(:qI, sum_by(purchaser_use_p_u[purchaser_use_p_u.use .== :K, :], [:year]), [:year]),
    ),
  )
  CSV.write(
    joinpath(dir, "input_output_margins.csv"),
    vcat(
      long_format(:qMarginBundle_p_u, data.carried_margins, [:product, :use, :year]),
      long_format(:qMarginService_s_u_o, data.services, [:service, :use, :origin, :year]),
      long_format(:qMarginService_s_u, sum_by(data.services, [:service, :use, :year]), [:service, :use, :year]),
    ),
  )
  CSV.write(
    joinpath(dir, "input_output_net_product_tax.csv"),
    vcat(
      long_format(:vNetProductTax_p_u, data.net_product_taxes, [:product, :use, :year]),
      long_format(:vNetProductTax_u, net_product_tax_u, [:use, :year]),
    ),
  )
  CSV.write(
    joinpath(dir, "input_output_aggregate_totals.csv"),
    vcat(
      long_format(:vY, data.output, [:year]),
      long_format(:vCTourist, data.tourist_spend, [:year]),
      long_format(:vM, data.imports, [:year]),
      long_format(:vX, data.exports, [:year]),
    ),
  )
  CSV.write(
    joinpath(dir, "input_output_fixed_investment.csv"),
    vcat(
      long_format(
        :qI_p,
        select(data.fixed_investment, :product, :year, :quantity => :value),
        [:product, :year],
      ),
      long_format(
        :vI_p,
        select(data.fixed_investment, :product, :year, :purchaser_value => :value),
        [:product, :year],
      ),
    ),
  )
  return nothing
end

function refresh_input_output_data!(dir = input_output_data_dir)
  data = build_input_output_data()
  write_input_output_data!(data, dir)
  return data
end

end # module
