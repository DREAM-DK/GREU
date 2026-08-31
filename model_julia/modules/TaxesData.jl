# Build product and production tax source files.
# Allocate gross taxes and subsidies before model construction.
# Write factor mappings and product-use splits as model inputs.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("TaxesSettings.jl")
include("GovernmentSettings.jl")
include("SectorAccountsSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module TaxesData

using CSV
using DataFrames
import ..DataUtils: long_format, read_cells
import ..EurostatClient
import ..GovernmentSettings: government_data_dir
import ..InputOutputSettings:
  cell_tolerance,
  input_output_data_dir,
  source_industry
import ..ProductionSettings:
  capital_type,
  intermediate_type,
  labor_type,
  production_data_dir
import ..SectorAccountsSettings: sector_accounts_data_dir
import ..Settings: calibration_year, country_code, first_data_year
import ..TaxesSettings:
  production_subsidy_input_map,
  production_tax_input_map,
  reported_tax_class,
  residual_tax_class,
  resident_sector,
  sector_accounts_dataset,
  sector_accounts_unit,
  tax_dataset,
  tax_unit

const tax_class = sort(collect(keys(production_tax_input_map)))
const subsidy_class = sort(collect(keys(production_subsidy_input_map)))
const data_years = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_years]
const production_gva_file = joinpath(production_data_dir, "production_gva.csv")
const production_capital_file = joinpath(production_data_dir, "production_capital.csv")
const production_labor_file = joinpath(production_data_dir, "production_labor.csv")
const production_intermediate_file = joinpath(production_data_dir, "production_intermediate_product_split.csv")
const production_taxes_file = joinpath(production_data_dir, "production_taxes.csv")
const product_taxes_file = joinpath(production_data_dir, "product_taxes.csv")
const purchaser_use_file = joinpath(input_output_data_dir, "input_output_purchaser_use.csv")
const net_product_tax_file = joinpath(input_output_data_dir, "input_output_net_product_tax.csv")
const government_file = joinpath(government_data_dir, "government_variables.csv")
const non_financial_transactions_file = joinpath(sector_accounts_data_dir, "non_financial_transactions.csv")

@assert Set(tax_class) == Set([reported_tax_class; residual_tax_class]) "Tax settings must cover each source class"
@assert subsidy_class == [:D39] "The broad Eurostat source supports only the D39 subsidy class"
@assert all(
  count(!isempty(intersect(targets, inputs)) for inputs in (capital_type, labor_type, intermediate_type)) <= 1
  for targets in Iterators.flatten((values(production_tax_input_map), values(production_subsidy_input_map)))
) "A tax or subsidy class cannot span factor inputs with different units"

# ============================================================================
# Source controls
# ============================================================================

rounding_residual(value) = value >= 0 ? value : begin
  @assert isapprox(value, 0; atol=1.1, rtol=0) "Reported D29 classes exceed the D29 total"
  0.0
end

"""Fetch government D29 classes and retain any unclassified amount as D29R."""
function fetch_tax_class_totals()
  df = EurostatClient.fetch_table(
    tax_dataset,
    "unit" => tax_unit,
    "sector" => "S13",
    "geo" => country_code,
    year_params...,
    ("na_item" => string(item) for item in [:D29; reported_tax_class])...,
  )
  source = Dict(
    (Symbol(row.na_item), parse(Int, row.time)) => row.value
    for row in eachrow(df)
  )
  residual = Dict(
    year => rounding_residual(
      source[(:D29, year)] -
      sum(get(source, (item, year), 0.0) for item in reported_tax_class)
    )
    for year in data_years
  )
  return Dict(
    (item, year) => item == residual_tax_class ? residual[year] : get(source, (item, year), 0.0)
    for item in tax_class, year in data_years
  )
end

"""Fetch D29 paid and D39 received by all resident institutional sectors."""
function fetch_resident_controls()
  df = EurostatClient.fetch_table(
    sector_accounts_dataset,
    "unit" => sector_accounts_unit,
    "geo" => country_code,
    year_params...,
    ("sector" => sector for sector in resident_sector)...,
    "na_item" => "D29",
    "na_item" => "D39",
  )
  function control(item, direct, year)
    rows = [
      row.value
      for row in eachrow(df)
      if row.na_item == item && row.direct == direct && row.time == string(year)
    ]
    @assert !isempty(rows) "$item $direct needs a resident-sector control for $year"
    return sum(rows)
  end
  return (
    tax = DataFrame(year=collect(data_years), value=[control("D29", "PAID", year) for year in data_years]),
    subsidy = DataFrame(year=collect(data_years), value=[control("D39", "RECV", year) for year in data_years]),
  )
end

# ============================================================================
# Proportional matrix
# ============================================================================

positive_part(value) = value > 0 ? value : 0.0

"""
Allocate gross taxes across industries and tax classes.

Each industry first gets its positive net tax plus a GVA share of the remaining
gross tax. Subsidies close the gap to the reported net industry total. National
tax-class shares apply in each industry.
"""
function proportional_matrices(tax_totals, net_industry, gva)
  industries = sort(unique(i for (i, _) in keys(net_industry)))

  @assert all(value >= 0 for value in values(tax_totals)) "Production tax class totals must be nonnegative"
  @assert all(value >= 0 for value in values(gva)) "Gross value added must be nonnegative"

  raw_tax_total = Dict(
    year => sum(tax_totals[(item, year)] for item in tax_class)
    for year in data_years
  )
  positive_net_total = Dict(
    year => sum(positive_part(net_industry[(i, year)]) for i in industries)
    for year in data_years
  )
  remaining_tax = Dict(
    year => raw_tax_total[year] - positive_net_total[year]
    for year in data_years
  )
  gva_total = Dict(
    year => sum(gva[(i, year)] for i in industries)
    for year in data_years
  )

  @assert all(>(0), values(raw_tax_total)) "Each year needs positive reported D29 classes"
  @assert all(>=(0), values(remaining_tax)) "Gross D29 must cover positive net industry taxes"
  @assert all(>(0), values(gva_total)) "Each year needs positive gross value added"

  industry_tax = Dict(
    (i, year) => positive_part(net_industry[(i, year)]) +
      remaining_tax[year] * gva[(i, year)] / gva_total[year]
    for i in industries, year in data_years
  )
  industry_subsidy = Dict(
    (i, year) => industry_tax[(i, year)] - net_industry[(i, year)]
    for i in industries, year in data_years
  )
  @assert all(value >= 0 for value in values(industry_subsidy)) "Implied production subsidies must be nonnegative"

  taxes = DataFrame(vec([
    (
      tax_class = item,
      industry = i,
      year = year,
      value = industry_tax[(i, year)] * tax_totals[(item, year)] / raw_tax_total[year],
    )
    for item in tax_class, i in industries, year in data_years
  ]))
  subsidies = DataFrame(vec([
    (subsidy_class=:D39, industry=i, year=year, value=industry_subsidy[(i, year)])
    for i in industries, year in data_years
  ]))
  return taxes, subsidies
end

# ============================================================================
# Production-factor allocation
# ============================================================================

function mapped_targets(mapping, class, factor_cells, factor_data, i, year)
  return [
    n
    for n in mapping[class]
    if (n, i) in factor_cells && get(factor_data, (n, i, year), 0.0) > 0
  ]
end

function mapped_value(cells, mapping, factor_cells, factor_data, n, i, year)
  return sum(
    get(cells, (class, i, year), 0.0) *
      factor_data[(n, i, year)] /
      sum(
        factor_data[(target, i, year)]
        for target in mapped_targets(mapping, class, factor_cells, factor_data, i, year)
      )
    for class in keys(mapping)
    if n in mapped_targets(mapping, class, factor_cells, factor_data, i, year)
    ; init=0.0
  )
end

function has_mapped_target(mapping, class, i, year, factors)
  return any(
    !isempty(mapped_targets(mapping, class, cells, data, i, year))
    for (cells, data) in factors
  )
end

function unmapped_value(cells, mapping, i, year, factors)
  return sum(
    get(cells, (class, i, year), 0.0)
    for class in keys(mapping)
    if !has_mapped_target(mapping, class, i, year, factors)
    ; init=0.0
  )
end

function factor_tax_tables(taxes, subsidies)
  tax_cells = Dict(
    (row.tax_class, row.industry, row.year) => row.value
    for row in eachrow(taxes)
  )
  subsidy_cells = Dict(
    (row.subsidy_class, row.industry, row.year) => row.value
    for row in eachrow(subsidies)
  )
  qK = read_cells(production_capital_file, "qK_k_i")
  qL = read_cells(production_labor_file, "qL_l_i")
  qM = read_cells(production_intermediate_file, "qM_m_i")
  capital_cells = Set(
    (k, i)
    for ((k, i, year), value) in qK
    if year == calibration_year &&
      value > cell_tolerance &&
      get(qK, (k, i, calibration_year-1), 0.0) > cell_tolerance
  )
  labor_cells = Set(
    (l, i)
    for ((l, i, year), value) in qL
    if year == calibration_year && value > cell_tolerance
  )
  intermediate_cells = Set((m, i) for (m, i, _) in keys(qM))
  factors = ((capital_cells, qK), (labor_cells, qL), (intermediate_cells, qM))

  capital = DataFrame(vec([(
    capital=k,
    industry=i,
    year=year,
    value=mapped_value(tax_cells, production_tax_input_map, capital_cells, qK, k, i, year) -
      mapped_value(subsidy_cells, production_subsidy_input_map, capital_cells, qK, k, i, year),
  ) for (k, i) in capital_cells, year in data_years]))
  labor = DataFrame(vec([(
    labor=l,
    industry=i,
    year=year,
    value=mapped_value(tax_cells, production_tax_input_map, labor_cells, qL, l, i, year) -
      mapped_value(subsidy_cells, production_subsidy_input_map, labor_cells, qL, l, i, year),
  ) for (l, i) in labor_cells, year in data_years]))
  intermediate = DataFrame(vec([(
    intermediate=m,
    industry=i,
    year=year,
    value=mapped_value(tax_cells, production_tax_input_map, intermediate_cells, qM, m, i, year) -
      mapped_value(subsidy_cells, production_subsidy_input_map, intermediate_cells, qM, m, i, year),
  ) for (m, i) in intermediate_cells, year in data_years]))
  other = DataFrame(vec([(
    industry=i,
    year=year,
    value=unmapped_value(tax_cells, production_tax_input_map, i, year, factors) -
      unmapped_value(subsidy_cells, production_subsidy_input_map, i, year, factors),
  ) for i in source_industry, year in data_years]))
  return (; capital, labor, intermediate, other)
end

# ============================================================================
# Product taxes and subsidies
# ============================================================================

function split_product_flows(year, q, net, total_subsidy)
  product_use = Set(
    (p, u)
    for ((p, u, source_year), value) in q
    if source_year == year && abs(value) > cell_tolerance
  )
  @assert all(
    (p, u) in product_use
    for ((p, u, source_year), value) in net
    if source_year == year && abs(value) > cell_tolerance
  ) "Each non-zero net product tax needs non-zero purchaser use"

  net_rate = Dict(
    (p, u) => get(net, (p, u, year), 0.0) / q[(p, u, year)]
    for (p, u) in product_use
  )
  minimum_subsidy_rate = Dict(
    (p, u) => (abs(net_rate[(p, u)]) - net_rate[(p, u)])/2
    for (p, u) in product_use
  )
  minimum_subsidy = sum(
    minimum_subsidy_rate[(p, u)] * q[(p, u, year)]
    for (p, u) in product_use
    ; init=0.0
  )
  @assert total_subsidy >= minimum_subsidy - cell_tolerance "Product subsidies must cover negative net rates"

  positive_use = sum(
    q[(p, u, year)]
    for (p, u) in product_use
    if q[(p, u, year)] > 0
    ; init=0.0
  )
  @assert positive_use > 0 "Product subsidies need positive purchaser use"
  extra_rate = (total_subsidy - minimum_subsidy) / positive_use

  subsidy = Dict(
    (p, u, year) =>
      q[(p, u, year)] *
      (minimum_subsidy_rate[(p, u)] + (q[(p, u, year)] > 0 ? extra_rate : 0.0))
    for (p, u) in product_use
  )
  tax = Dict(
    (p, u, year) => get(net, (p, u, year), 0.0) + subsidy[(p, u, year)]
    for (p, u) in product_use
  )
  @assert all(tax[key] / q[key] >= -cell_tolerance for key in keys(tax)) "Gross product tax rates must be nonnegative"
  @assert all(
    subsidy[key] / q[key] >= -cell_tolerance
    for key in keys(subsidy)
  ) "Gross product subsidy rates must be nonnegative"
  return tax, subsidy
end

function product_tax_tables()
  q = read_cells(purchaser_use_file, "qPurchaserUse_p_u")
  net = read_cells(net_product_tax_file, "vNetProductTax_p_u")
  net_use = read_cells(net_product_tax_file, "vNetProductTax_u")
  government_product_tax = read_cells(government_file, "vGovProductTaxSource")
  government_subsidy = read_cells(government_file, "vGovSubSource")
  transactions = read_cells(non_financial_transactions_file, "NetNonFinancialTransactions")
  production_subsidy_class = read_cells(production_taxes_file, "vProductionSubsidy_c")

  row_product_tax = Dict(
    (year,) => value
    for ((sector, item, year), value) in transactions
    if (sector, item) == (:RoW, :D2)
  )
  row_subsidy = Dict(
    (year,) => -value
    for ((sector, item, year), value) in transactions
    if (sector, item) == (:RoW, :D3)
  )
  years = sort(collect(intersect(
    Set(only(key) for key in keys(government_product_tax)),
    Set(only(key) for key in keys(government_subsidy)),
    Set(only(key) for key in keys(row_product_tax)),
    Set(only(key) for key in keys(row_subsidy)),
  )))
  production_subsidy = Dict(
    (year,) => sum(
      value
      for ((_, source_year), value) in production_subsidy_class
      if source_year == year
      ; init=0.0
    )
    for year in years
  )
  product_subsidy = Dict(
    (year,) => government_subsidy[(year,)] + row_subsidy[(year,)] - production_subsidy[(year,)]
    for year in years
  )
  product_tax = Dict(
    (year,) => government_product_tax[(year,)] + row_product_tax[(year,)]
    for year in years
  )
  row_payer_share = Dict(
    year => row_subsidy[(year,)] / (government_subsidy[(year,)] + row_subsidy[(year,)])
    for year in years
  )
  row_product_subsidy = Dict(
    (year,) => row_payer_share[year] * product_subsidy[(year,)]
    for year in years
  )
  row_production_subsidy = Dict(
    (year,) => row_payer_share[year] * production_subsidy[(year,)]
    for year in years
  )
  splits = Dict(year => split_product_flows(year, q, net, product_subsidy[(year,)]) for year in years)
  gross_tax = Dict(key => value for year in years for (key, value) in first(splits[year]))
  gross_subsidy = Dict(key => value for year in years for (key, value) in last(splits[year]))

  @assert all(>=(0), values(product_subsidy)) "Product subsidy payments must be nonnegative"
  @assert all(>=(0), values(product_tax)) "Product tax receipts must be nonnegative"
  @assert all(0 <= share <= 1 for share in values(row_payer_share)) "RoW subsidy payer shares must be valid"
  @assert all(
    abs(row_product_subsidy[(year,)] + row_production_subsidy[(year,)] - row_subsidy[(year,)]) <= cell_tolerance
    for year in years
  ) "RoW product and production subsidies must sum to D.3"
  @assert all(
    abs(sum(value for ((_, _, source_year), value) in gross_tax if source_year == year) - product_tax[(year,)]) <= 1.2
    for year in years
  ) "Product tax sources disagree"

  gross_tax_table = DataFrame([
    (product=p, use=u, year=year, value=value)
    for ((p, u, year), value) in gross_tax
  ])
  gross_subsidy_table = DataFrame([
    (product=p, use=u, year=year, value=value)
    for ((p, u, year), value) in gross_subsidy
  ])
  net_table = DataFrame([
    (product=p, use=u, year=year, value=value)
    for ((p, u, year), value) in net
    if year in years
  ])
  net_use_table = DataFrame([
    (use=u, year=year, value=value)
    for ((u, year), value) in net_use
    if year in years
  ])
  series(cells) = DataFrame([
    (year=year, value=cells[(year,)])
    for year in years
  ])
  return (;
    gross_tax_table,
    gross_subsidy_table,
    net_table,
    net_use_table,
    product_tax=series(product_tax),
    product_subsidy=series(product_subsidy),
    row_product_tax=series(row_product_tax),
    row_product_subsidy=series(row_product_subsidy),
    row_production_subsidy=series(row_production_subsidy),
  )
end

# ============================================================================
# Refresh
# ============================================================================

function refresh_factor_tax_data!(file=production_taxes_file)
  tax_cells = read_cells(file, "vProductionTax_c_i")
  subsidy_cells = read_cells(file, "vProductionSubsidy_c_i")
  taxes = DataFrame([
    (tax_class=class, industry=i, year=year, value=value)
    for ((class, i, year), value) in tax_cells
  ])
  subsidies = DataFrame([
    (subsidy_class=class, industry=i, year=year, value=value)
    for ((class, i, year), value) in subsidy_cells
  ])
  factors = factor_tax_tables(taxes, subsidies)
  mapped_variables = Set(["vtK_k_i", "vtL_l_i", "vtM_m_i", "vtProductionOther_i"])
  source = CSV.read(file, DataFrame)
  source = source[.!in.(source.variable, Ref(mapped_variables)), :]
  CSV.write(file, vcat(
    source,
    long_format(:vtK_k_i, factors.capital, [:capital, :industry, :year]),
    long_format(:vtL_l_i, factors.labor, [:labor, :industry, :year]),
    long_format(:vtM_m_i, factors.intermediate, [:intermediate, :industry, :year]),
    long_format(:vtProductionOther_i, factors.other, [:industry, :year]),
  ))
  return nothing
end

function refresh_production_taxes_data!(dir=production_data_dir)
  mkpath(dir)
  tax_totals = fetch_tax_class_totals()
  resident = fetch_resident_controls()
  net_industry = read_cells(production_gva_file, "vProductionTax_i")
  taxes, subsidies = proportional_matrices(
    tax_totals,
    net_industry,
    read_cells(production_gva_file, "vGVA_i"),
  )
  subsidy_totals = DataFrame(
    subsidy_class=fill(:D39, length(data_years)),
    year=collect(data_years),
    value=resident.subsidy.value,
  )
  CSV.write(joinpath(dir, "production_taxes.csv"), vcat(
    long_format(:vProductionTax_c_i, taxes, [:tax_class, :industry, :year]),
    long_format(:vProductionSubsidy_c_i, subsidies, [:subsidy_class, :industry, :year]),
    long_format(:vProductionSubsidy_c, subsidy_totals, [:subsidy_class, :year]),
    long_format(:vProductionTax, resident.tax, [:year]),
  ))
  refresh_factor_tax_data!(joinpath(dir, "production_taxes.csv"))
  return nothing
end

function refresh_product_taxes_data!(dir=production_data_dir)
  mkpath(dir)
  data = product_tax_tables()
  CSV.write(joinpath(dir, "product_taxes.csv"), vcat(
    long_format(:vtProduct_p_u, data.gross_tax_table, [:product, :use, :year]),
    long_format(:vProductSubsidy_p_u, data.gross_subsidy_table, [:product, :use, :year]),
    long_format(:vNetProductTax_p_u, data.net_table, [:product, :use, :year]),
    long_format(:vNetProductTax_u, data.net_use_table, [:use, :year]),
    long_format(:vtProduct, data.product_tax, [:year]),
    long_format(:vProductSubsidy, data.product_subsidy, [:year]),
    long_format(:vtRoWProduct, data.row_product_tax, [:year]),
    long_format(:vRoWProductSubsidy, data.row_product_subsidy, [:year]),
    long_format(:vRoWProductionSubsidy, data.row_production_subsidy, [:year]),
  ))
  return nothing
end

function refresh_taxes_data!()
  refresh_production_taxes_data!()
  refresh_product_taxes_data!()
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  TaxesData.refresh_taxes_data!()
end
