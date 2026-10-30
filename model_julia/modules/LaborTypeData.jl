# Stand-alone synthetic external education data generator.
# Reads the existing aggregate CSV without modifying it.
module LaborTypeData
using CSV, DataFrames
const production_data_dir = normpath(joinpath(@__DIR__, "..", "data", "production"))
const labor_types = (:low, :medium, :high)

function refresh_labor_type_data!(dir=production_data_dir)
  aggregate = CSV.read(joinpath(dir, "production_labor.csv"), DataFrame)
  sector = CSV.read(normpath(joinpath(dir, "..", "sector_accounts", "sector_accounts.csv")), DataFrame)
  hh = Dict(Int(parse(Int, string(r.indices))) => Float64(r.value) for r in eachrow(sector) if r.variable == "vHhWages")
  row = Dict(Int(parse(Int, string(r.indices))) => Float64(r.value) for r in eachrow(sector) if r.variable == "vRoWNetWages")
  supply = Dict(Int(parse(Int, string(r.indices))) => Float64(r.value) for r in eachrow(aggregate) if r.variable == "nLSupply")
  # Wage rates are NOT divided by three: both employment and payroll are split equally.
  for year in sort!(collect(intersect(keys(hh), keys(row), keys(supply))))
    @assert supply[year] > 0 "Labor supply must be positive for $year"
  end
  rows = NamedTuple{(:variable,:indices,:value),Tuple{String,String,Float64}}[]
  for row in eachrow(aggregate)
    parts = split(String(row.indices), ",")
    if row.variable == "nL_l_i"
      @assert length(parts) == 3 && parts[1] == "labor"
      for l in labor_types
        push!(rows, (variable="nL_l_i", indices=join((l,parts[2],parts[3]),","), value=Float64(row.value)/length(labor_types)))
      end
    elseif row.variable == "nLSupply"
      @assert length(parts) == 1
      for l in labor_types
        push!(rows, (variable="nLSupply_l", indices=join((l,parts[1]),","), value=Float64(row.value)/length(labor_types)))
      end
    elseif row.variable == "vWages_i"
      @assert length(parts) == 2
      for l in labor_types
        push!(rows, (variable="vWages_l_i", indices=join((l,parts[1],parts[2]),","), value=Float64(row.value)/length(labor_types)))
      end
    end
  end
  for year in sort!(collect(intersect(keys(hh), keys(row), keys(supply))))
    wage = (hh[year] + row[year]) / supply[year]
    for l in labor_types
      push!(rows, (variable="vW_l", indices=join((l,year), ","), value=wage))
    end
  end
  CSV.write(joinpath(dir, "production_labor_types.csv"), DataFrame(rows))
  return nothing
end
end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  LaborTypeData.refresh_labor_type_data!()
end
