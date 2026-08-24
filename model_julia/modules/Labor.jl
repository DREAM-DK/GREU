# Define labor demand, fixed labor supplies, and the common wage.
# Link wages by industry to household and rest-of-world wage income.
# Exclude payroll taxes, capital, intermediate inputs, and CES nests.
module Labor

using SquareModels
import ..DataUtils: cell_value, fill_cells!, read_cells
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
const sector_accounts_file = joinpath(@__DIR__, "..", "data", "sector_accounts", "sector_accounts.csv")
const qL_l_i_data = read_cells(labor_file, "qL_l_i")
const qLSupply_data = read_cells(labor_file, "qLSupply")
const vHhWages_data = read_cells(sector_accounts_file, "vHhWages")
const vRoWNetWages_data = read_cells(sector_accounts_file, "vRoWNetWages")

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
end

@variables model :: (LaborTag, InflationAdjusted) begin
  pW[t], "Wage per efficiency unit of labor."
end

@variables model :: (LaborTag, GrowthAdjusted, ForecastConstant) begin
  qLSupplyHh[t], "Labor supplied by households in efficiency units."
  qLSupplyRoW[t], "Labor supplied by the rest of the world in efficiency units."
end

@variables model :: (LaborTag, GrowthAdjusted, InflationAdjusted) begin
  vWages_i[i = industry, t = t], "Wages by industry."
  vWages[t], "Total wages."
  vHhWages[t], "Household wages."
  vRoWNetWages[t], "Rest-of-world net wages."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, qL_l_i, qL_l_i_data)
  db[pW[t1]] = 1.0
  fill_cells!(db, vHhWages, vHhWages_data)
  fill_cells!(db, vRoWNetWages, vRoWNetWages_data)
  source_supply = cell_value(qLSupply_data, t1)
  source_wages = cell_value(vHhWages_data, t1) + cell_value(vRoWNetWages_data, t1)
  db[qLSupplyHh[t1]] = source_supply * cell_value(vHhWages_data, t1) / source_wages
  db[qLSupplyRoW[t1]] = source_supply - db[qLSupplyHh[t1]]
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[qProd[labor_type,:,:]] .= start_values[qL_l_i][labor_type,:,:]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    qL_l_i[l = labor_type, i = industry, t = t1:T], qL_l_i[l, i, t] == qProd[l, i, t]

    pW[t = t1:T], qLSupplyHh[t] + qLSupplyRoW[t] == ∑(qL_l_i[l,i,t] for (l, i) in labor_l_i)

    pProd[l = labor_type, i = industry, t = t1:T], pProd[l, i, t] == pW[t]

    vWages_i[i = industry, t = t1:T], vWages_i[i,t] == pW[t] * ∑(qL_l_i[l,i,t] for l in labor_type)
    vWages[t = t1:T], vWages[t] == ∑(vWages_i[i,t] for i in industry)
    vHhWages[t = t1:T], vHhWages[t] == pW[t] * qLSupplyHh[t]
    vRoWNetWages[t = t1:T], vRoWNetWages[t] == pW[t] * qLSupplyRoW[t]
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

# ============================================================================
# Tests
# ============================================================================
function run_tests(db)
  errors = String[]
  source_total = cell_value(qLSupply_data, t1)
  supplied_total = db[qLSupplyHh[t1]] + db[qLSupplyRoW[t1]]
  supplied_total == source_total ||
    push!(errors, "Household and rest-of-world labor supplies must match the source total")
  return errors
end
end # module
