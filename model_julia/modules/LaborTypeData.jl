# Split the aggregate labor series over labor types with shares from DA.
# Split persons by the hours share. Split wages and labor taxes by the wage share.
# The shares in labor_type_shares.csv come from DREAM_data_NACE_alle_tre_faner.xlsx
# (sheets AJO_LOENTIMER and AJO_BREDT_LOENBELOEB, columns G-K). They hold one year
# and apply to every year. Read the aggregate CSV files without modifying them.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module LaborTypeData

using CSV
using DataFrames
import ..DataUtils: read_cells
import ..InputOutputSettings: industry_members
import ..ProductionSettings: production_data_dir, labor_type

const share_file = joinpath(production_data_dir, "labor_type_shares.csv")
const source = CSV.read(share_file, DataFrame)
# The source uses sut_detail_codes. The resolution members use the Eurostat leaf codes with a dash.
source.nace .= replace.(source.nace, "_" => "-")

"""Shares by labor type for one NACE leaf code. Empty when the code has no employees, like L68A."""
function code_shares(column, code)
  rows = source[source.nace .== code, :]
  shares = Dict(Symbol(row.labor_type) => row[column] for row in eachrow(rows))
  sum(values(shares); init = 0.0) == 0 && return Dict{Symbol,Float64}()
  @assert Set(keys(shares)) == Set(labor_type) "Labor types in $share_file must match ProductionSettings.labor_type"
  @assert isapprox(sum(values(shares)), 1; atol = 1e-6) "Shares for $code must sum to one"
  return shares
end

"""Average the shares of the member codes with employees. Skip industries with none, like U."""
function industry_shares(column)
  observed = Dict(i => filter(!isempty, [code_shares(column, code) for code in codes]) for (i, codes) in industry_members)
  return Dict(
    i => Dict(l => sum(s[l] for s in members) / length(members) for l in labor_type)
    for (i, members) in observed if !isempty(members)
  )
end

"""Split one aggregate series over labor types. The first index of each cell is the industry."""
function split_series(variable, cells, shares)
  @assert all(value == 0 for (key, value) in cells if !haskey(shares, key[1])) "$variable has values in an industry without labor-type shares"
  return DataFrame([
    (variable = variable, indices = join((l, key...), ","), value = shares[key[1]][l] * value)
    for (key, value) in sort(collect(cells); by = first) if haskey(shares, key[1]) for l in labor_type
  ])
end

"""Drop the aggregate labor label from each cell key."""
function drop_labor_label(cells)
  @assert all(key[1] == :labor for key in keys(cells)) "The aggregate labor series must use the label labor"
  return Dict(key[2:end] => value for (key, value) in cells)
end

function refresh_labor_type_data!(dir = production_data_dir)
  labor_file = joinpath(dir, "production_labor.csv")
  taxes_file = joinpath(dir, "production_taxes.csv")
  hours_share = industry_shares(:hours_share)
  wage_share = industry_shares(:wage_share)
  CSV.write(joinpath(dir, "production_labor_types.csv"), vcat(
    split_series("nL_l_i", drop_labor_label(read_cells(labor_file, "nL_l_i")), hours_share),
    split_series("vWages_l_i", read_cells(labor_file, "vWages_i"), wage_share),
    split_series("vntL_l_i", drop_labor_label(read_cells(taxes_file, "vntL_l_i")), wage_share),
  ))
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  LaborTypeData.refresh_labor_type_data!()
end
