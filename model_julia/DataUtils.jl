module DataUtils

using CSV
using DataFrames
import JuMP

# ============================================================================
# Model data
# ============================================================================

"""Read one variable into a dictionary keyed by its index tuple."""
function read_cells(file, variable)
  data = read_sparse_array(file; variable)
  cells = Dict(key => data[key...] for key in eachindex(data))
  @assert all(isfinite, values(cells)) "$variable in $file must be finite"
  return cells
end

"""Return one reported cell, or zero if the source omits it."""
cell_value(cells, index...) = get(cells, index, 0.0)

index_tuple(key::Tuple) = key
index_tuple(key::JuMP.Containers.DenseAxisArrayKey) = key.I

"""Copy reported cells into a model variable. Omitted cells stay `nothing`."""
fill_cells!(db, var, cells) =
  db[var] .= [get(cells, index_tuple(key), nothing) for key in keys(var)]

"""Read a one-dimensional series in the given index order."""
function read_series(file, variable, indices)
  cells = read_cells(file, variable)
  return [get(cells, (index,), nothing) for index in indices]
end

# ============================================================================
# Data tables
# ============================================================================

sum_by(df, cols) = combine(groupby(df, cols), :value => sum => :value)

"""Return long-format rows that SquareModels can read."""
long_format(varname, df, index_cols) = DataFrame(
  variable = string(varname),
  indices = [join((string(row[col]) for col in index_cols), ",") for row in eachrow(df)],
  value = df.value,
)

write_index_set(path, name, members) =
  CSV.write(path, DataFrame(variable = name, indices = string.(members), value = 1.0))

end # module
