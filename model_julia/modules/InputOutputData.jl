isdefined(@__MODULE__, :Settings) || include(joinpath(@__DIR__, "..", "Settings.jl"))
isdefined(@__MODULE__, :InputOutputDefinitions) || include("InputOutputDefinitions.jl")

module InputOutputData

using CSV
using EurostatAPI
using ..Settings: calibration_year, country_code, currency_code, input_output_dataset
import ..InputOutputDefinitions as IODef

const DATA_PATH = joinpath(@__DIR__, "..", "data", "input_output.csv")

"""Fetch and add one year's Eurostat IO cells to the raw domestic, import, and accounting tables."""
function add_raw_io_year!(vIO_y, vIO_m, vIO_a, year::Integer)
  url = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/$input_output_dataset?time=$year&geo=$country_code&unit=$currency_code"
  @info "Requesting Eurostat input-output data from $url"

  response = EurostatAPI.HTTP.get(url, readtimeout=120, retries=2)
  response.status == 200 || error("HTTP error: status $(response.status) for $input_output_dataset, year $year")
  data = EurostatAPI.JSON3.read(response.body)
  dims = String.(data.id)
  dim_position = Dict(dim => pos for (pos, dim) in pairs(dims))
  sizes = Int.(data.size)
  labels = Dict(dim => category_labels(getproperty(data.dimension, Symbol(dim))) for dim in dims)

  for (cell, value) in pairs(data.value)
    value isa String && value in (":C", ":c", ":", "-") && continue

    indices = jsonstat_indices(parse(Int, string(cell)), sizes)
    industry_name = IODef.rename_industry_code(labels["ind_ava"][indices[dim_position["ind_ava"]]])
    demand_name = IODef.rename_demand_code(labels["ind_use"][indices[dim_position["ind_use"]]])
    # Gross fixed capital formation is split into construction and other investment.
    demand_name == "P51G" && (demand_name = industry_name == "F" ? "iB" : "iM")

    flow = labels["stk_flow"][indices[dim_position["stk_flow"]]]
    key = (industry_name, demand_name, string(year))
    value = Float64(value) / 1000

    if flow == "DOM" && industry_name in IODef.industry_codes && demand_name in IODef.demand_category_codes
      vIO_y[key] = get(vIO_y, key, 0.0) + value
    elseif flow == "IMP" && industry_name in IODef.industry_codes && demand_name in IODef.demand_category_codes
      vIO_m[key] = get(vIO_m, key, 0.0) + value
    elseif flow == "TOTAL" && industry_name in IODef.accounting_rows && demand_name in IODef.demand_category_codes
      vIO_a[key] = get(vIO_a, key, 0.0) + value
    end
  end

  return nothing
end

"""Return category labels ordered by their zero-based JSON-stat category indices."""
function category_labels(dim)
  out = Vector{String}(undef, length(dim.category.index))
  for (label, idx) in pairs(dim.category.index)
    out[Int(idx) + 1] = string(label)
  end
  return out
end

"""Convert a flattened zero-based JSON-stat cell index into one-based dimension indices."""
function jsonstat_indices(idx0::Int, sizes)
  indices = Int[]
  remaining = idx0
  stride = 1
  for size in sizes
    push!(indices, (remaining ÷ stride) % size + 1)
    stride *= size
  end
  return indices
end

"""Fetch raw Eurostat IO data for the requested years."""
function fetch_raw_input_output(years)
  raw_domestic = IODef.IOValues()
  raw_imports = IODef.IOValues()
  raw_accounting = IODef.IOValues()
  foreach(year -> add_raw_io_year!(raw_domestic, raw_imports, raw_accounting, year), years)
  return (raw_domestic = raw_domestic, raw_imports = raw_imports, raw_accounting = raw_accounting)
end

# Industry-indexed (i, t) variables. All other 2-tuples are (d, t) on qD.
const _industry_indexed = Set([:vW_i, :vtYOther_i, :vDepr_i, :vOpSurplus_i])

csv_row(variable, key, value) = (
  variable = String(variable),
  i = length(key) == 3 ? key[1] : variable in _industry_indexed ? key[1] : "",
  d = length(key) == 3 ? key[2] : variable in _industry_indexed ? "" : key[1],
  t = key[end],
  value = value,
)

csv_rows(parameters) = sort!(
  [csv_row(variable, key, value) for variable in propertynames(parameters) for (key, value) in pairs(getproperty(parameters, variable))];
  by = row -> (row.variable, row.i, row.d, row.t),
)

function refresh_input_output_data!(path = DATA_PATH; years = [calibration_year - 1, calibration_year])
  raw_data = fetch_raw_input_output(years)
  parameters = IODef.derive_parameters(raw_data.raw_domestic, raw_data.raw_imports, raw_data.raw_accounting, string.(years))
  CSV.write(path, csv_rows(parameters))
  return parameters
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  InputOutputData.refresh_input_output_data!()
end
