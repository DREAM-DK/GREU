# Define labor use and its production-tree price and quantity links.
# Read labor data and normalize the labor price in the calibration year.
# Exclude capital, intermediate inputs, and CES nest equations.
module Labor

using SquareModels
import ..CheckedData: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutputSettings: industry
import ..Production: parent, pProd, qProd, top_i
import ..ProductionSettings: labor_type, production_data_dir, production_nesting
import ..db
import ..Time: t, t1, T

# ============================================================================
# Checked-in data
# ============================================================================
const labor_file = joinpath(production_data_dir, "production_labor.csv")
const qL_i_source_data = read_cells(labor_file, "qL_i")

# ============================================================================
# Variables
# ============================================================================
const LaborTag = Tag(:Labor)

@variables db.model :: (LaborTag, GrowthAdjusted) begin
  qL_l_i[l = labor_type, i = industry, t = t; haskey(parent, (l, i))], "Labor in efficiency units by type and industry."
end

@variables db.model :: (LaborTag, InflationAdjusted) begin
  pL_l_i[l = labor_type, i = industry, t = t; haskey(parent, (l, i))], "Labor cost per efficiency unit by type and industry."
end

# ============================================================================
# Data
# ============================================================================
function set_data!(db)
  @assert all(
    haskey(parent, (l, i)) && !haskey(production_nesting[i], l)
    for l in labor_type, i in keys(top_i)
  ) "Each producing industry needs each labor type as a production leaf"

  fill_cells!(
    db,
    qL_l_i,
    Dict((only(labor_type), i, year) => value for ((i, year), value) in qL_i_source_data),
  )
  db[pL_l_i] .= 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block db begin
    qL_l_i[(l, i, t) in keys(qL_l_i); t in t1:T],
    qL_l_i[l, i, t] == qProd[l, i, t] / pL_l_i[l, i, t1]

    pProd[(n, i, t) in keys(pProd); haskey(parent, (n, i)) && n in labor_type && t in t1:T],
    pProd[n, i, t] == pL_l_i[n, i, t] / pL_l_i[n, i, t1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qProd[(l, i, t) in keys(qL_l_i); t == t1], qL_l_i[l, i, t]
  end

  return block
end
end # module
