# Fetch gross production tax and subsidy controls.
# Allocate separate tax and subsidy matrices across industries.
# Keep the checked-in matrix open to direct country replacement.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("TaxesSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module TaxesData

using CSV
using DataFrames
import ..DataUtils: long_format, read_cells
import ..EurostatClient
import ..ProductionSettings: production_data_dir
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

@assert Set(tax_class) == Set([reported_tax_class; residual_tax_class]) "Tax settings must cover each source class"
@assert subsidy_class == [:D39] "The broad Eurostat source supports only the D39 subsidy class"

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
# Refresh
# ============================================================================

function refresh_taxes_data!(dir=production_data_dir)
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
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  TaxesData.refresh_taxes_data!()
end
