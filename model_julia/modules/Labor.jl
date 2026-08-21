# Define labor demand, fixed labor supply, and the common wage.
# Read labor data and set the wage level in the calibration year.
# Exclude capital, intermediate inputs, and CES nest equations.
module Labor

using SquareModels
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry
import ..InputOutputSettings: cell_tolerance
import ..Production: pProd, qProd
import ..ProductionSettings: labor_type, production_data_dir, production_nesting
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Checked-in data
# ============================================================================
const labor_file = joinpath(production_data_dir, "production_labor.csv")
const qL_i_source_data = read_cells(labor_file, "qL_i")
const labor_l_i = Set(
  (only(labor_type), i)
  for ((i, year), value) in qL_i_source_data
  if year == t1 && value > cell_tolerance
)
const qLSupply_data = Dict(
  (year,) => sum(
    value
    for ((i, data_year), value) in qL_i_source_data
    if data_year == year && (only(labor_type), i) in labor_l_i
  )
  for year in unique(last.(keys(qL_i_source_data)))
)

# ============================================================================
# Variables
# ============================================================================
const LaborTag = Tag(:Labor)

@variables db.model :: (LaborTag, GrowthAdjusted) begin
  qL_l_i[l = labor_type, i = industry, t = t; (l, i) in labor_l_i], "Labor in efficiency units by type and industry."
  qLSupply[t] :: ForecastConstant, "Total labor supply in efficiency units."
end

@variables db.model :: (LaborTag, InflationAdjusted) begin
  pW[t], "Wage per efficiency unit of labor."
end

# ============================================================================
# Data
# ============================================================================
function set_data!(db)
  fill_cells!(db, qL_l_i, Dict((only(labor_type), i, year) => value for ((i, year), value) in qL_i_source_data))
  fill_cells!(db, qLSupply, qLSupply_data)
  db[pW[t1]] = 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block db begin
    qL_l_i[l = labor_type, i = industry, t = t1:T], qL_l_i[l, i, t] == qProd[l, i, t]

    # pW[t = t1:T], qLSupply[t] == ∑(qL_l_i[l, i, t] for (l, i) in labor_l_i)

    pProd[l = labor_type, i = industry, t = t1:T], pProd[l, i, t] == pW[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qProd[l = labor_type, i = industry, t = t1], qL_l_i[l = labor_type, i = industry, t = t1]
  end

  return block
end
end # module
