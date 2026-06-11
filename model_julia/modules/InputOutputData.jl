include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("EurostatClient.jl")

module InputOutputData

using CSV
using DataFrames
import ..EurostatClient
using ..Settings: calibration_year, country_code
import ..InputOutputSettings

function industry_agg_map(industry_codes)
  raw_codes = setdiff(industry_codes, InputOutputSettings.accounting_ind_ava_codes)
  return Dict(raw_codes .=> Symbol.(first.(raw_codes)))
end

function fetch_io_table(years; c_dest = nothing, c_orig = nothing)
  params = Pair{String,String}[]
  push!(params, "unit" => InputOutputSettings.eurostat_unit)
  push!(params, c_dest !== nothing ? "c_dest" => c_dest : "c_orig" => c_orig)
  for year in years
    push!(params, "time" => string(year))
  end
  df = EurostatClient.fetch_table(InputOutputSettings.eurostat_dataset, params...; scale=1 / 1000)
  rename!(df, :ind_ava => :industry, :ind_use => :demand, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:industry, :demand, :c_orig, :c_dest, :year, :value]]
end

map_origin(country, code) = (code == country || code == "DOM") ? "DOM" : "IMP"

map_codes(codes, mapping) = [get(mapping, code, Symbol(code)) for code in codes]

function rename_and_aggregate(df::DataFrame, agg_map)
  out = copy(df)
  out.industry = map_codes(out.industry, InputOutputSettings.accounting_rename)
  out.demand = map_codes(out.demand, InputOutputSettings.demand_rename)
  out.industry = map_codes(out.industry, agg_map)
  out.demand = map_codes(out.demand, agg_map)
  return combine(groupby(out, [:industry, :demand, :c_orig, :year]), :value => sum => :value)
end

function split_p51g!(df::DataFrame)
  df.demand = ifelse.(df.demand .== :P51G, ifelse.(df.industry .== :F, :structures, :equipment), df.demand)
  return df
end

function process_exports(exports_df::DataFrame, country)
  df = exports_df[exports_df.c_dest .!= country, :]
  df = combine(groupby(df, [:industry, :year]), :value => sum => :value)
  df.demand = fill(:x, nrow(df))
  df.c_orig = fill("DOM", nrow(df))
  return df[:, [:industry, :demand, :c_orig, :year, :value]]
end

function map_intermediate_energy(df::DataFrame)
  out = copy(df)
  industries = InputOutputSettings.model_industries
  energy_map = InputOutputSettings.energy_type_by_supply_industry

  flow_mask = (out.row .∈ Ref(industries)) .& (out.demand .∈ Ref(industries))
  out.demand[flow_mask] = get.(Ref(energy_map), out.row[flow_mask], out.demand[flow_mask])
  return combine(groupby(out, [:row, :demand, :supply, :year]), :value => sum => :value)
end

# Builds the canonical long IO table with columns (row, demand, supply, year, value).
# `supply` (DOM/IMP) comes straight from the origin classification, and `row` holds
# either a model industry or an accounting line (vW_i, vtYM_d, ...).
function build_io_table(years)
  year_strings = string.(years)
  domestic = fetch_io_table(year_strings; c_dest = country_code)
  agg_map = industry_agg_map(unique(domestic.industry))

  exports_raw = fetch_io_table(year_strings; c_orig = country_code)

  domestic.c_orig = map_origin.(country_code, domestic.c_orig)
  domestic = rename_and_aggregate(domestic, agg_map)
  split_p51g!(domestic)

  exports_raw.industry = map_codes(exports_raw.industry, agg_map)
  exports = process_exports(exports_raw, country_code)

  combined = vcat(domestic, exports)
  combined = combine(groupby(combined, [:industry, :demand, :c_orig, :year]), :value => sum => :value)
  rename!(combined, :industry => :row, :c_orig => :supply)
  combined = map_intermediate_energy(combined)

  industries = Set(i for i in InputOutputSettings.model_industries if i in combined.row)
  demand_components = Set(InputOutputSettings.all_demand_components(collect(industries)))

  # Keep industry cells from both supplies; accounting lines only from the domestic side.
  rows_in_demand = combined.demand .∈ Ref(demand_components)
  is_industry = combined.row .∈ Ref(industries)
  is_accounting_dom = (combined.supply .== "DOM") .& (combined.row .∈ Ref(Set(InputOutputSettings.accounting_rows)))
  io_table = combined[rows_in_demand .& (is_industry .| is_accounting_dom), [:row, :demand, :supply, :year, :value]]

  return io_table
end

# Basic-price flows for a supply side (DOM/IMP), with the industry in the `row` column.
function supply_table(io_table, supply)
  mask = (io_table.supply .== supply) .& (io_table.row .∈ Ref(InputOutputSettings.model_industries))
  return rename(io_table[mask, [:row, :demand, :year, :value]], :row => :industry)
end

# The model's IO structure is fixed to the calibration year, so cells absent from
# that year (e.g. flows present only in the lag year) cannot be represented and are
# dropped here to keep the written data aligned with the model's sparse variables.
function restrict_(df::DataFrame)
  active = Set(
    (r.industry, r.demand) for r in eachrow(df)
    if r.year == calibration_year && abs(r.value) > 1e-6
  )
  return df[[(r.industry, r.demand) in active for r in eachrow(df)], :]
end

# A DOM accounting line (vtYM_d, vW_i, ...), keyed by its demand/using-industry column.
accounting_table(io_table, row::Symbol) =
  io_table[(io_table.supply .== "DOM") .& (io_table.row .== row), [:demand, :year, :value]]

"""Allocate demand-level product taxes to IO cells in proportion to basic-price flows:
`vtY_i_d = vY_i_d / vYM_d * vtYM_d`, with `vYM_d = ∑_i (vY_i_d + vM_i_d)`.
Intermediate product taxes are first mapped to the model's intermediate demand
components using the same proportionality assumption."""
function split_product_taxes(vY_i_d::DataFrame, vM_i_d::DataFrame, vtYM_d::DataFrame)
  vYM_d = combine(groupby(vcat(vY_i_d, vM_i_d), [:demand, :year]), :value => sum => :base)
  intermediate_demands = vcat(InputOutputSettings.model_industries, InputOutputSettings.energy_types)

  intermediate_tax = combine(groupby(vtYM_d[vtYM_d.demand .∈ Ref(InputOutputSettings.model_industries), :], :year), :value => sum => :value)
  intermediate_base = vYM_d[vYM_d.demand .∈ Ref(intermediate_demands), :]
  transform!(groupby(intermediate_base, :year), :base => (x -> x ./ sum(x)) => :share)
  intermediate_tax = innerjoin(intermediate_tax, intermediate_base[:, [:demand, :year, :share]], on = :year)
  intermediate_tax.value .*= intermediate_tax.share
  select!(intermediate_tax, [:demand, :year, :value])

  vtYM_d = vcat(vtYM_d[vtYM_d.demand .∉ Ref(InputOutputSettings.model_industries), :], intermediate_tax)
  rates = innerjoin(vtYM_d, vYM_d, on = [:demand, :year])
  rates = rates[rates.base .> 0, :]
  rates.rate = rates.value ./ rates.base
  allocate(flow) = begin
    df = innerjoin(flow, rates[:, [:demand, :year, :rate]], on = [:demand, :year])
    df.value .*= df.rate
    return select(df[df.value .!= 0, :], [:industry, :demand, :year, :value])
  end
  return allocate(vY_i_d), allocate(vM_i_d)
end

demand_aggregate(vY_i_d::DataFrame, vM_i_d::DataFrame) =
  combine(groupby(vcat(vY_i_d, vM_i_d), [:demand, :year]), :value => sum => :value)

# SquareModels tabular format: (variable, indices, value) with comma-joined indices.
function tabular_df(varname::AbstractString, df::DataFrame, index_cols)
  return DataFrame(
    variable = fill(varname, nrow(df)),
    indices = [join([string(row[col]) for col in index_cols], ",") for row in eachrow(df)],
    value = df.value,
  )
end

write_tabular!(path, varname, df, index_cols) = CSV.write(path, tabular_df(varname, df, index_cols))

function write_index_set!(path, name, members)
  CSV.write(path, DataFrame(
    variable = fill(name, length(members)),
    indices = string.(members),
    value = ones(length(members)),
  ))
end

function write_csv_dataset!(dir, io_table)
  mkpath(dir)
  CSV.write(joinpath(dir, "input_output.csv"), io_table)

  industry_rows = io_table[io_table.row .∈ Ref(InputOutputSettings.model_industries), :]
  write_index_set!(joinpath(dir, "industries.csv"), "industries",
    sort(unique(industry_rows.row[industry_rows.supply .== "DOM"])))
  write_index_set!(joinpath(dir, "industries_with_imports.csv"), "industries_with_imports",
    sort(unique(industry_rows.row[industry_rows.supply .== "IMP"])))

  vY_i_d = restrict_(supply_table(io_table, "DOM"))
  vM_i_d = restrict_(supply_table(io_table, "IMP"))
  vtY_i_d, vtM_i_d = split_product_taxes(vY_i_d, vM_i_d, accounting_table(io_table, :vtYM_d))
  vD = demand_aggregate(vY_i_d, vM_i_d)
  write_tabular!(joinpath(dir, "vY_i_d.csv"), "vY_i_d", vY_i_d, [:industry, :demand, :year])
  write_tabular!(joinpath(dir, "vM_i_d.csv"), "vM_i_d", vM_i_d, [:industry, :demand, :year])
  write_tabular!(joinpath(dir, "vD.csv"), "vD", vD, [:demand, :year])
  write_tabular!(joinpath(dir, "vW_i.csv"), "vW_i",
    rename(accounting_table(io_table, :vW_i), :demand => :industry), [:industry, :year])
  write_tabular!(joinpath(dir, "vtYOther_i.csv"), "vtYOther_i",
    rename(accounting_table(io_table, :vtYOther_i), :demand => :industry), [:industry, :year])
  write_tabular!(joinpath(dir, "vOpSurplus_i.csv"), "vOpSurplus_i",
    rename(accounting_table(io_table, :vOpSurplus_i), :demand => :industry), [:industry, :year])
  write_tabular!(joinpath(dir, "vtY_i_d.csv"), "vtY_i_d", vtY_i_d, [:industry, :demand, :year])
  write_tabular!(joinpath(dir, "vtM_i_d.csv"), "vtM_i_d", vtM_i_d, [:industry, :demand, :year])
  return nothing
end

function refresh_input_output_data!(dir = InputOutputSettings.input_output_data_dir; years = [calibration_year - 1, calibration_year])
  io_table = build_io_table(years)
  write_csv_dataset!(dir, io_table)
  return io_table
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  InputOutputData.refresh_input_output_data!()
end
