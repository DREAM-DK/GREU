# Shared helpers for the Eurostat-sourced data refresh modules (InputOutputData, SectorAccountsData).
module DataRefreshUtils

using CSV
using DataFrames

sum_by(df, cols) = combine(groupby(df, cols), :value => sum => :value)

"""Long-format (variable, indices, value) rows as read by SquareModels."""
long_format(varname, df, index_cols) = DataFrame(
  variable = string(varname),
  indices = [join((string(row[col]) for col in index_cols), ",") for row in eachrow(df)],
  value = df.value,
)

write_index_set(path, name, members) =
  CSV.write(path, DataFrame(variable = name, indices = string.(members), value = 1.0))

end # module
