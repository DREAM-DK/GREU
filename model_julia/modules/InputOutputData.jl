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
  df = copy(df)
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

"""Full I-O table: intermediate flows, exports, and accounting rows by supply origin.
`domestic` and `exports` are the raw `c_dest`/`c_orig` fetches from `fetch_io_table`."""
function input_output_table(domestic, exports)
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

"""Direct-purchase adjustment: residents' spending abroad ("OP_RES") or non-residents' spending
in the domestic economy ("OP_NRES"), both always recorded against household consumption
(P3_S14/P3_S15) in the source data. `domestic` is the raw `c_dest` fetch from `fetch_io_table`,
shared with `input_output_table` to avoid fetching the same Eurostat table twice."""
function direct_purchase_adjustment(domestic, code)
  df = domestic[domestic.industry .== code, [:demand, :year, :value]]
  df.demand = [rename_code(c, demand_rename) for c in df.demand]
  df = sum_by(df, [:demand, :year])
  return df[(df.demand .== :cHh) .& (df.value .!= 0), :]
end

"""Attach a fixed industry to demand-level totals that have no natural industry breakdown."""
with_industry(df, industry) = insertcols(df, :industry => industry)[:, [:industry, :demand, :year, :value]]

"""Move non-resident domestic purchases from household consumption to exports.
Eurostat records "OP_NRES" as a negative adjustment to household consumption (it is spending
already counted there that belongs to non-residents), so negating it gives the positive amount
to move from cHh to exports."""
function reclassify_nonresident_purchases(vY_i_d, vM_i_d, nonresidents)
  nonresidents.value .*= -1
  tagged = vcat(
    insertcols!(copy(vY_i_d), :supply => :Y),
    insertcols!(copy(vM_i_d), :supply => :M),
  )
  basis = tagged[(tagged.demand .== :cHh) .& (tagged.value .> 0), :]
  totals = rename(sum_by(basis, [:year]), :value => :total)
  basis = innerjoin(basis, totals, on = :year)
  basis.share = basis.value ./ basis.total
  moved = innerjoin(nonresidents, basis[:, [:supply, :industry, :year, :share]], on = :year)
  moved.value .*= moved.share

  function updates(supply)
    df = moved[moved.supply .== supply, [:industry, :demand, :year, :value]]
    from = copy(df)
    from.value .*= -1
    to = copy(df)
    to.demand .= :x
    return vcat(from, to)
  end

  return (
    sum_by(vcat(vY_i_d, updates(:Y)), [:industry, :demand, :year]),
    sum_by(vcat(vM_i_d, updates(:M)), [:industry, :demand, :year]),
  )
end

"""Residents' direct purchases abroad are travel imports (accommodation & food services, :I),
not spread across the general import mix, which would misattribute tourist spending to
unrelated goods-producing industries."""
resident_purchases_abroad(residents) = with_industry(residents, :I)

"""Imported goods and services exported again, not covered by existing export cells.
The IO table's export flows (`export_flows`) only cover domestic output crossing the border,
so goods imported and re-exported without domestic processing (merchanting) are invisible to
it; they are recovered here as the gap between the IO table's :x cells and national-accounts
total exports. SNA convention books merchanting as a margin earned by the trading activity
itself, so the whole gap is attributed to wholesale/retail trade (:G) rather than spread across
the general import mix, which would otherwise misattribute it to unrelated industries."""
function reexport_flows(vY_i_d, vM_i_d)
  exports = mapped_country_table(national_accounts_dataset, "na_item",
    Dict("P6" => :x), :demand)
  existing_exports = rename(sum_by(vcat(
    vY_i_d[vY_i_d.demand .== :x, :],
    vM_i_d[vM_i_d.demand .== :x, :],
  ), [:demand, :year]), :value => :existing_exports)
  reexports = innerjoin(exports, existing_exports, on = [:demand, :year])
  reexports.value .-= reexports.existing_exports
  return with_industry(reexports[reexports.value .!= 0, [:demand, :year, :value]], :G)
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
function write_cells(dir, io_table, residents, nonresidents)
  vY_i_d = restrict_to_calibration_cells(supply_table(io_table, "DOM"))
  vM_i_d = restrict_to_calibration_cells(supply_table(io_table, "IMP"))
  vY_i_d, vM_i_d = reclassify_nonresident_purchases(vY_i_d, vM_i_d, nonresidents)
  vM_i_d = vcat(vM_i_d, resident_purchases_abroad(residents))
  vM_i_d = vcat(vM_i_d, reexport_flows(vY_i_d, vM_i_d))
  vM_i_d = sum_by(vM_i_d, [:industry, :demand, :year])
  rates = product_tax_rates(io_table, vY_i_d, vM_i_d)
  vtY_i_d = allocate_taxes(vY_i_d, rates)
  vtM_i_d = allocate_taxes(vM_i_d, rates)
  CSV.write(joinpath(dir, "input_output_cells.csv"), vcat(
    long_format(:vY_i_d, vY_i_d, [:industry, :demand, :year]),
    long_format(:vM_i_d, vM_i_d, [:industry, :demand, :year]),
    long_format(:vtY_i_d, vtY_i_d, [:industry, :demand, :year]),
    long_format(:vtM_i_d, vtM_i_d, [:industry, :demand, :year]),
  ))
  return vY_i_d, vM_i_d, vtY_i_d, vtM_i_d
end

"""Demand totals at purchaser prices: IO cells plus net product taxes (qD) and NA demand (vD)."""
function write_demands(dir, vY_i_d, vM_i_d, vtY_i_d, vtM_i_d)
  qD = sum_by(vcat(vY_i_d, vM_i_d, vtY_i_d, vtM_i_d), [:demand, :year])
  vD = mapped_country_table(national_accounts_dataset, "na_item",
    Dict("P31_S14_S15" => :cHh, "P3_S13" => :g, "P6" => :x), :demand)
  append!(vD, qD[in.(qD.demand, Ref([:equipment, :structures])), :])
  vD = sum_by(vD, [:demand, :year])
  qD = antijoin(qD, vD[:, [:demand, :year]], on = [:demand, :year])
  append!(qD, vD)
  CSV.write(joinpath(dir, "input_output_demands.csv"), vcat(
    long_format(:qD, qD, [:demand, :year]),
    long_format(:vD, vD, [:demand, :year]),
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
  domestic = fetch_io_table("c_dest")  # use within the country, by country of origin
  exports = fetch_io_table("c_orig")   # domestic output, by country of destination
  io_table = input_output_table(domestic, exports)
  CSV.write(joinpath(dir, "input_output.csv"), io_table)
  write_indices(dir, io_table)
  residents = direct_purchase_adjustment(domestic, "OP_RES")
  nonresidents = direct_purchase_adjustment(domestic, "OP_NRES")
  vY_i_d, vM_i_d, vtY_i_d, vtM_i_d = write_cells(dir, io_table, residents, nonresidents)
  write_demands(dir, vY_i_d, vM_i_d, vtY_i_d, vtM_i_d)
  write_aggregates(dir)
  write_industries(dir, io_table)
  return io_table
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  InputOutputData.refresh_input_output_data!()
end
