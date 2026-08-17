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
  S,
  U,
  accounting_ind_ava_codes,
  accounting_rename,
  accounting_rows,
  cell_tolerance,
  demand_rename,
  eurostat_dataset,
  eurostat_unit,
  input_output_data_dir,
  margin_uses,
  national_accounts_dataset,
  national_accounts_unit
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

"""Apply `mappings` in turn (codes not present pass through) and return a Symbol."""
function rename_code(code, mappings...)
  for mapping in mappings
    code = get(mapping, code, code)
  end
  return Symbol(code)
end

"""Map raw industry codes to their NACE section letter, keeping accounting rows."""
nace_section_map(codes) =
  Dict(code => Symbol(first(code)) for code in setdiff(codes, accounting_ind_ava_codes))

"""Use within the country by product, use, and country of origin."""
function domestic_flows(df, section_map)
  df = copy(df)
  df.c_orig = ifelse.(in.(df.c_orig, Ref(("DOM", country_code))), :domestic, :import)
  df.row = [rename_code(code, section_map, accounting_rename) for code in df.row]
  df.use = [rename_code(code, section_map, demand_rename) for code in df.use]
  rename!(df, :c_orig => :origin)
  return sum_by(df, [:row, :use, :origin, :year])
end

"""Domestic output delivered abroad, summed into the export use column."""
function export_flows(df, section_map)
  df = df[df.c_dest .!= country_code, :]
  df.row = [rename_code(code, section_map, accounting_rename) for code in df.row]
  df = sum_by(df, [:row, :year])
  insertcols!(df, :use => :x, :origin => :domestic)
  return df[:, [:row, :use, :origin, :year, :value]]
end

"""Product rows and value-added accounting rows by use and origin.
`domestic` and `exports` are the raw `c_dest` and `c_orig` fetches."""
function input_output_table(domestic, exports)
  section_map = nace_section_map(domestic.row)
  table = sum_by(
    vcat(domestic_flows(domestic, section_map), export_flows(exports, section_map)),
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
function direct_purchase_adjustment(domestic, section_map, code)
  df = domestic[domestic.row .== code, [:use, :year, :value]]
  df.use = [rename_code(use, section_map, demand_rename) for use in df.use]
  df = sum_by(df, [:use, :year])
  return df[(df.use .== :cHh) .& (abs.(df.value) .> cell_tolerance), :]
end

# ============================================================================
# Reported, estimated, and model-set direct use
# ============================================================================

"""Move non-residents' domestic purchases from household consumption to exports.
Eurostat books `OP_NRES` as a negative adjustment to household consumption, so
negating it gives the amount to move. The product and origin mix of household
consumption sets the mix of the moved amount."""
function nonresident_purchase_updates(reported, nonresidents)
  amounts = copy(nonresidents)
  amounts.value .*= -1
  @assert all(amounts.value .>= 0) "OP_NRES must be non-positive in the source table"

  basis = reported[(reported.use .== :cHh) .& (reported.value .> cell_tolerance), :]
  totals = rename(sum_by(basis, [:year]), :value => :total)
  basis = innerjoin(basis, totals, on = :year)
  basis.share = basis.value ./ basis.total
  moved = innerjoin(amounts, basis[:, [:product, :origin, :year, :share]], on = :year)
  moved.value .*= moved.share

  from = moved[:, cell_columns]
  to = copy(from)
  from.value .*= -1
  to.use .= :x
  return vcat(from, to)
end

"""Residents' spending abroad is travel import, so assign it to imported
accommodation and food service (`:I`) rather than the general import mix."""
function resident_purchase_imports(residents)
  df = copy(residents)
  insertcols!(df, :product => :I, :origin => :import)
  return df[:, cell_columns]
end

"""Imports sold abroad with no domestic processing. The IO export table has
domestic output only, so the gap to national-accounts exports is re-export. SNA
books the gap as a trade margin, so it goes to wholesale and retail trade
(`:G`)."""
function reexport_flows(direct_before_reexports, product_taxes)
  exports = mapped_country_table(
    national_accounts_dataset,
    "na_item",
    Dict("P6" => :x),
    :use,
  )
  existing = direct_before_reexports[direct_before_reexports.use .== :x, :]
  existing = rename(sum_by(existing, [:year]), :value => :existing)
  export_taxes = rename(product_taxes[product_taxes.use .== :x, [:year, :value]], :value => :tax)
  reexports = leftjoin(exports, existing, on = :year)
  reexports = leftjoin(reexports, export_taxes, on = :year)
  reexports.existing = coalesce.(reexports.existing, 0.0)
  reexports.tax = coalesce.(reexports.tax, 0.0)
  reexports.value .-= reexports.existing .+ reexports.tax
  @assert all(reexports.value .>= -cell_tolerance) "Estimated re-exports must not be negative"
  reexports = reexports[reexports.value .> cell_tolerance, [:year, :value]]
  insertcols!(reexports, :product => :G, :origin => :import, :use => :x)
  return reexports[:, cell_columns]
end

"""Take the margin services out of direct use. The model puts them back as
derived margin demand, priced into the purchaser price of the carried product."""
function margin_reclassification(direct_before_margins)
  services = direct_before_margins[
    in.(direct_before_margins.product, Ref(Set(S))) .&
    in.(direct_before_margins.use, Ref(Set(margin_uses))) .&
    (abs.(direct_before_margins.value) .> cell_tolerance),
    :,
  ]
  @assert all(services.value .>= 0) "Margin-service benchmark cells must be non-negative"
  adjustments = copy(services)
  adjustments.value .*= -1
  rename!(services, :product => :service)
  return adjustments, services
end

"""Direct use split into its reported, estimated, and reclassified parts, plus
the product-tax row. Each estimate uses the parts before it as its basis."""
function direct_use_parts(table, domestic)
  section_map = nace_section_map(domestic.row)
  reported = reported_direct_use(table)
  product_taxes = accounting_table(table, :vProductTax_u)
  estimated = sum_cells(
    nonresident_purchase_updates(
      reported,
      direct_purchase_adjustment(domestic, section_map, "OP_NRES"),
    ),
    resident_purchase_imports(
      direct_purchase_adjustment(domestic, section_map, "OP_RES"),
    ),
  )
  estimated = sum_cells(
    estimated,
    reexport_flows(sum_cells(reported, estimated), product_taxes),
  )
  reclassification, services = margin_reclassification(sum_cells(reported, estimated))
  return reported, estimated, reclassification, services, product_taxes
end

# ============================================================================
# Supply and aggregate checks
# ============================================================================

"""Domestic supply by product and industry. The first data build maps each
product to the industry of the same NACE section."""
function reported_supply(reported)
  supply = sum_by(reported[reported.origin .== :domestic, :], [:product, :year])
  supply.industry = supply.product
  return supply[:, [:product, :industry, :year, :value]]
end

"""Purchaser-price spend by use: direct cells, margin services, product taxes."""
demand_checks(direct, services, product_taxes) = sum_by(
  vcat(
    sum_by(direct, [:use, :year]),
    sum_by(services, [:use, :year]),
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
  table = input_output_table(domestic, exports)
  reported, estimated, reclassification, services, product_taxes =
    direct_use_parts(table, domestic)
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
    long_format(:qS_s_u_o_reclassified, services, [:service, :use, :origin, :year]),
  )
  CSV.write(
    joinpath(dir, "input_output_price_adjustments.csv"),
    long_format(:vProductTax_u_reported, product_taxes, [:use, :year]),
  )
  CSV.write(joinpath(dir, "input_output_checks.csv"), vcat(
    long_format(
      :vD_u_reported,
      demand_checks(direct, services, product_taxes),
      [:use, :year],
    ),
    long_format(:vY_reported, sum_by(supply, [:year]), [:year]),
    (
      long_format(variable, national[national.variable .== variable, :], [:year])
      for variable in (:vX_reported, :vM_reported)
    )...,
  ))
  return table
end

end # module
