# Build the synthetic intermediate product split.
# Assign energy products to energy and all other products to materials.
# Write product cells and the implied type totals.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module IntermediatesData

using CSV
using DataFrames
import ..DataUtils: long_format, read_cells, sum_by
import ..InputOutputSettings: cell_tolerance, input_output_data_dir, product, source_industry
import ..ProductionSettings: energy_product, intermediate_type, production_data_dir
import ..Settings: calibration_year

const purchaser_use_file = joinpath(input_output_data_dir, "input_output_purchaser_use.csv")

"""Assign each input-output product to energy or materials."""
function synthetic_intermediate_product_split(
  purchaser_use = read_cells(purchaser_use_file, "qPurchaserUse_p_u_o"),
)
  split = sum_by(DataFrame([
    (product = p, industry = u, value = value)
    for ((p,u,_,year), value) in purchaser_use
    if u in source_industry && year == calibration_year
  ]), [:product, :industry])
  split = split[abs.(split.value) .> cell_tolerance, :]
  @assert all(>(cell_tolerance), split.value) "Intermediate product use must be positive"
  @assert Set(split.product) ⊆ Set(product) "Intermediate data contain an unknown product"
  split.m = [p in energy_product ? :energy : :materials for p in split.product]
  select!(split, :product, :m, :industry, :value)
  sort!(split, [:industry, :m, :product])
  return split
end

function refresh_intermediates_data!(dir = production_data_dir)
  mkpath(dir)
  split = synthetic_intermediate_product_split()
  split.year .= calibration_year
  qM_m_i = sum_by(split, [:m, :industry, :year])
  @assert Set(qM_m_i.m) == Set(intermediate_type) "Each intermediate type needs product data"
  @assert all(>(cell_tolerance), qM_m_i.value) "Each intermediate type needs positive use"
  # Replace this synthetic table with direct energy data when it exists.
  CSV.write(
    joinpath(dir, "production_intermediate_product_split.csv"),
    vcat(
      long_format(:qM_p_m_i, split, [:product, :m, :industry, :year]),
      long_format(:qM_m_i, qM_m_i, [:m, :industry, :year]),
    ),
  )
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  IntermediatesData.refresh_intermediates_data!()
end
