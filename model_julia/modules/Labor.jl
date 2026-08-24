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
import ..ProductionSettings: labor_type, production_data_dir
import ..Settings: calibration_year
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const labor_file = joinpath(production_data_dir, "production_labor.csv")
const qL_l_i_data = read_cells(labor_file, "qL_l_i")
const qLSupply_data = read_cells(labor_file, "qLSupply")

# ============================================================================
# Indices
# ============================================================================
const labor_l_i = Set(
  (l, i)
  for ((l, i, year), value) in qL_l_i_data
  if year == calibration_year && value > cell_tolerance
)

# ============================================================================
# Variables
# ============================================================================
const LaborTag = Tag(:Labor)

@variables model :: (LaborTag, GrowthAdjusted) begin
  qL_l_i[l = labor_type, i = industry, t = t; (l, i) in labor_l_i], "Labor in efficiency units by type and industry."
  qLSupply[t] :: ForecastConstant, "Total labor supply in efficiency units."
end

@variables model :: (LaborTag, InflationAdjusted) begin
  pW[t], "Wage per efficiency unit of labor."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, qL_l_i, qL_l_i_data)
  fill_cells!(db, qLSupply, qLSupply_data)
  db[pW[t1]] = 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
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
