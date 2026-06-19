module EurostatClient

using DataFrames
using HTTP
using JSON3

const API_BASE = "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
const MISSING_VALUES = (":C", ":c", ":", "-")

"""GET a dataset from the Eurostat statistics API and return the parsed JSON-stat response."""
function fetch_json(dataset::String, params::Pair{String,String}...)
  query = join(("$key=$value" for (key, value) in params), "&")
  url = "$API_BASE/$dataset?$query"
  @info "Requesting Eurostat data from $url"
  response = HTTP.get(url, readtimeout=120, retries=2)
  response.status == 200 || error("HTTP error: status $(response.status) for $url")
  return JSON3.read(response.body)
end

"""Return category labels ordered by their zero-based JSON-stat category indices."""
category_labels(dim) =
  string.(sort(collect(keys(dim.category.index)); by = k -> Int(dim.category.index[k])))

"""Convert a flattened zero-based JSON-stat cell index into one-based dimension indices."""
function jsonstat_indices(idx0::Int, sizes)
  indices = Int[]
  stride = prod(sizes)
  for size in sizes
    stride ÷= size
    push!(indices, (idx0 ÷ stride) % size + 1)
  end
  return indices
end

"""Convert a JSON-stat dataset to a DataFrame with one row per non-missing cell."""
function jsonstat_table(data)
  dims = Symbol.(data.id)
  labels = [category_labels(getproperty(data.dimension, dim)) for dim in dims]
  sizes = Int.(data.size)
  cells = [jsonstat_indices(parse(Int, string(cell)), sizes) => Float64(value)
           for (cell, value) in pairs(data.value)
           if !(value isa String && value in MISSING_VALUES)]
  return DataFrame(
    [dims[d] => [labels[d][indices[d]] for (indices, _) in cells] for d in eachindex(dims)]...,
    :value => last.(cells),
  )
end

"""Fetch a dataset and return its observations as a DataFrame."""
fetch_table(dataset::String, params::Pair{String,String}...) =
  jsonstat_table(fetch_json(dataset, params...))

end # module
