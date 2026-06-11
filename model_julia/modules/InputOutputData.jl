include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("EurostatClient.jl")

module InputOutputData

using CSV
using DataFrames
import ..EurostatClient
using ..Settings: calibration_year, country_code
import ..InputOutputSettings:
  accounting_ind_ava_codes,
  accounting_rename,
  accounting_rows,
  all_demand_components,
  demand_rename,
  energy_type_by_supply_industry,
  energy_types,
  eurostat_dataset,
  eurostat_unit,
  gfcf_asset_dataset,
  input_output_data_dir,
  model_industries,
  national_accounts_dataset,
  national_accounts_unit

sum_by(df, cols) = combine(groupby(df, cols), :value => sum => :value)

# ==========================================================================
# Eurostat fetches
# ==========================================================================

const year_params = ["time" => string(y) for y in (calibration_year - 1, calibration_year)]

function fetch_io_table(country_dimension)
  df = EurostatClient.fetch_table(eurostat_dataset,
    "unit" => eurostat_unit, country_dimension => country_code, year_params...)
  rename!(df, :ind_ava => :industry, :ind_use => :demand, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:industry, :demand, :c_orig, :c_dest, :year, :value]]
end

function fetch_country_table(dataset, dimension, values)
  df = EurostatClient.fetch_table(dataset,
    "unit" => national_accounts_unit, "geo" => country_code,
    (dimension => value for value in values)..., year_params...)
  df.year = parse.(Int, df.time)
  return df
end

"""Fetch a country table and map `dimension` codes into model names in `target_col`."""
function mapped_country_table(dataset, dimension, mapping, target_col)
  df = fetch_country_table(dataset, dimension, collect(keys(mapping)))
  df[!, target_col] = [mapping[code] for code in df[!, Symbol(dimension)]]
  return df[:, [target_col, :year, :value]]
end

# ==========================================================================
# Input-output table assembly
# ==========================================================================

"""Apply `mappings` in turn (codes not present pass through) and return a Symbol."""
function rename_code(code, mappings...)
  for mapping in mappings
    code = get(mapping, code, code)
  end
  return Symbol(code)
end

"""Map raw industry codes (excluding accounting rows) to their NACE section letter."""
nace_section_map(codes) = Dict(code => Symbol(first(code)) for code in setdiff(codes, accounting_ind_ava_codes))

"""Within-country use flows by (industry, demand, supply origin)."""
function domestic_flows(df, agg_map)
  df.c_orig = ifelse.(df.c_orig .∈ Ref(("DOM", country_code)), "DOM", "IMP")
  df.industry = [rename_code(c, agg_map, accounting_rename) for c in df.industry]
  df.demand = [rename_code(c, agg_map, demand_rename) for c in df.demand]
  df = sum_by(df, [:industry, :demand, :c_orig, :year])
  # GFCF is split into capital types by supplying industry: construction delivers structures.
  df.demand = ifelse.(df.demand .== :P51G, ifelse.(df.industry .== :F, :structures, :equipment), df.demand)
  return df
end

"""Domestic output delivered abroad, summed into the export demand component."""
function export_flows(df, agg_map)
  df = df[df.c_dest .!= country_code, :]
  df.industry = [rename_code(c, agg_map) for c in df.industry]
  df = sum_by(df, [:industry, :year])
  insertcols!(df, :demand => :x, :c_orig => "DOM")
  return df[:, [:industry, :demand, :c_orig, :year, :value]]
end

"""Full I-O table: intermediate flows, exports, and accounting rows by supply origin."""
function input_output_table()
  domestic = fetch_io_table("c_dest")  # use within the country, by country of origin
  exports = fetch_io_table("c_orig")   # domestic output, by country of destination
  agg_map = nace_section_map(domestic.industry)

  table = vcat(domestic_flows(domestic, agg_map), export_flows(exports, agg_map))
  table = sum_by(table, [:industry, :demand, :c_orig, :year])
  rename!(table, :industry => :row, :c_orig => :supply)

  # Intermediate deliveries from energy-supplying industries form the energy demand components.
  flows = (table.row .∈ Ref(model_industries)) .& (table.demand .∈ Ref(model_industries))
  table.demand[flows] = get.(Ref(energy_type_by_supply_industry), table.row[flows], table.demand[flows])
  table = sum_by(table, [:row, :demand, :supply, :year])

  industries = intersect(model_industries, table.row)
  demands = Set(all_demand_components(industries))
  is_industry = table.row .∈ Ref(Set(industries))
  is_accounting = (table.supply .== "DOM") .& (table.row .∈ Ref(Set(accounting_rows)))
  return table[(table.demand .∈ Ref(demands)) .& (is_industry .| is_accounting), :]
end

# ==========================================================================
# I-O table slices
# ==========================================================================

"""Industry × demand flows for one supply origin ("DOM" or "IMP")."""
function supply_table(io_table, supply)
  mask = (io_table.supply .== supply) .& (io_table.row .∈ Ref(model_industries))
  return rename(io_table[mask, [:row, :demand, :year, :value]], :row => :industry)
end

"""One accounting row (e.g. wages) by demand column."""
accounting_table(io_table, row::Symbol) =
  io_table[(io_table.supply .== "DOM") .& (io_table.row .== row), [:demand, :year, :value]]

"""Keep only (industry, demand) cells that are non-zero in the calibration year,
since those define the model's sparsity pattern."""
function restrict_to_calibration_cells(df)
  at_t1 = (df.year .== calibration_year) .& (abs.(df.value) .> 1e-6)
  active = Set(tuple.(df.industry[at_t1], df.demand[at_t1]))
  return df[tuple.(df.industry, df.demand) .∈ Ref(active), :]
end

# ==========================================================================
# Product taxes
# ==========================================================================

"""Product tax rate by demand component: vtYM_d totals over the basic-price base.
The tax row records intermediate use by industry while the cells use energy demand
components, so intermediate taxes are pooled and re-spread by basic-price shares."""
function product_tax_rates(io_table, vY_i_d, vM_i_d)
  taxes = accounting_table(io_table, :vtYM_d)
  base = combine(groupby(vcat(vY_i_d, vM_i_d), [:demand, :year]), :value => sum => :base)

  intermediate = taxes.demand .∈ Ref(model_industries)
  pooled = combine(groupby(taxes[intermediate, :], :year), :value => sum => :value)
  shares = base[base.demand .∈ Ref(vcat(model_industries, energy_types)), :]
  transform!(groupby(shares, :year), :base => (x -> x ./ sum(x)) => :share)
  spread = innerjoin(pooled, shares[:, [:demand, :year, :share]], on = :year)
  spread.value .*= spread.share
  taxes = vcat(taxes[.!intermediate, :], spread[:, [:demand, :year, :value]])

  rates = innerjoin(taxes, base, on = [:demand, :year])
  rates = rates[rates.base .> 0, :]
  rates.rate = rates.value ./ rates.base
  return rates[:, [:demand, :year, :rate]]
end

"""Allocate demand-level taxes to (industry, demand) cells in proportion to the flow."""
function allocate_taxes(flow, rates)
  df = innerjoin(flow, rates, on = [:demand, :year])
  df.value .*= df.rate
  return df[df.value .!= 0, [:industry, :demand, :year, :value]]
end

# ==========================================================================
# Output files
# ==========================================================================

"""Long-format (variable, indices, value) rows as read by SquareModels."""
long_format(varname, df, index_cols) = DataFrame(
  variable = string(varname),
  indices = [join((string(row[col]) for col in index_cols), ",") for row in eachrow(df)],
  value = df.value,
)

write_index_set(path, name, members) =
  CSV.write(path, DataFrame(variable = name, indices = string.(members), value = 1.0))

function write_indices(dir, io_table)
  rows = io_table[io_table.row .∈ Ref(model_industries), :]
  industries(supply) = sort(unique(rows.row[rows.supply .== supply]))
  write_index_set(joinpath(dir, "industries.csv"), "industries", industries("DOM"))
  write_index_set(joinpath(dir, "industries_with_imports.csv"), "industries_with_imports", industries("IMP"))
end

"""Industry × demand cells: basic-price flows plus allocated product taxes."""
function write_cells(dir, io_table)
  vY_i_d = restrict_to_calibration_cells(supply_table(io_table, "DOM"))
  vM_i_d = restrict_to_calibration_cells(supply_table(io_table, "IMP"))
  rates = product_tax_rates(io_table, vY_i_d, vM_i_d)
  CSV.write(joinpath(dir, "input_output_cells.csv"), vcat(
    long_format(:vY_i_d, vY_i_d, [:industry, :demand, :year]),
    long_format(:vM_i_d, vM_i_d, [:industry, :demand, :year]),
    long_format(:vtY_i_d, allocate_taxes(vY_i_d, rates), [:industry, :demand, :year]),
    long_format(:vtM_i_d, allocate_taxes(vM_i_d, rates), [:industry, :demand, :year]),
  ))
  return vY_i_d, vM_i_d
end

"""Final demand: intermediate use summed over industries (qD) and national-accounts demand (vD)."""
function write_demands(dir, vY_i_d, vM_i_d)
  qD = sum_by(vcat(vY_i_d, vM_i_d), [:demand, :year])
  vD = mapped_country_table(national_accounts_dataset, "na_item",
    Dict("P31_S14_S15" => :cHh, "P3_S13" => :g, "P52_P53" => :equipment, "P6" => :x), :demand)
  # GFCF split into capital types: dwellings and other structures (N11KG) vs the rest.
  gfcf = unstack(fetch_country_table(gfcf_asset_dataset, "asset10", ["N11G", "N11KG"]),
    :year, :asset10, :value)
  append!(vD,
    DataFrame(demand = :equipment, year = gfcf.year, value = gfcf.N11G .- gfcf.N11KG),
    DataFrame(demand = :structures, year = gfcf.year, value = gfcf.N11KG))
  CSV.write(joinpath(dir, "input_output_demands.csv"), vcat(
    long_format(:qD, qD, [:demand, :year]),
    long_format(:vD, sum_by(vD, [:demand, :year]), [:demand, :year]),
  ))
end

"""Macro totals from national accounts (not in the I-O table)."""
function write_aggregates(dir)
  df = mapped_country_table(national_accounts_dataset, "na_item",
    Dict("B1GQ" => :vGDP, "B1G" => :vGVA), :variable)
  CSV.write(joinpath(dir, "input_output_aggregates.csv"),
    vcat((long_format(v, df[df.variable .== v, :], [:year]) for v in (:vGDP, :vGVA))...))
end

"""Per-industry accounting rows: wages, other production taxes, operating surplus."""
function write_industries(dir, io_table)
  industry_row(name) = rename(accounting_table(io_table, name), :demand => :industry)
  CSV.write(joinpath(dir, "input_output_industries.csv"),
    vcat((long_format(v, industry_row(v), [:industry, :year]) for v in (:vW_i, :vtYOther_i, :vOpSurplus_i))...))
end

function refresh_input_output_data!(dir = input_output_data_dir)
  mkpath(dir)
  io_table = input_output_table()
  CSV.write(joinpath(dir, "input_output.csv"), io_table)
  write_indices(dir, io_table)
  vY_i_d, vM_i_d = write_cells(dir, io_table)
  write_demands(dir, vY_i_d, vM_i_d)
  write_aggregates(dir)
  write_industries(dir, io_table)
  return io_table
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  InputOutputData.refresh_input_output_data!()
end
