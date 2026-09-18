# Define labor demand, employment, and the common wage.
# Include production tax in the labor user cost and production link.
# Link wages by industry to household and rest-of-world wage income.
# Keep capital, intermediate inputs, and CES nests in other modules.
module Labor

using SquareModels
import ..DataUtils: cell_value, fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry
import ..Production: pProd, qProd, nL_l_i_data, labor_l_i
import ..ProductionSettings: labor_type, production_data_dir
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const labor_file = joinpath(production_data_dir, "production_labor.csv")
const sector_accounts_file = joinpath(@__DIR__, "..", "data", "sector_accounts", "sector_accounts.csv")
const nLSupply_data = read_cells(labor_file, "nLSupply")
const vHhWages_data = read_cells(sector_accounts_file, "vHhWages")
const vRoWNetWages_data = read_cells(sector_accounts_file, "vRoWNetWages")

# ============================================================================
# Variables
# ============================================================================
const LaborTag = Tag(:Labor)

@variables model :: LaborTag begin
  nL_l_i[l=labor_type, i=industry, t=t; (l,i) in labor_l_i], "Persons by type and industry."
  nLSupplyHh[t] :: ForecastConstant, "Household persons."
  nLSupplyRoW[t] :: ForecastConstant, "Rest-of-world persons."
end

@variables model :: (LaborTag, GrowthAdjusted) begin
  qL_l_i[(l,i,t)=nL_l_i], "Labor in efficiency units by type and industry."
  qL2nL[t] :: ForecastConstant, "Efficiency units per person."
end

@variables model :: (LaborTag, InflationAdjusted) begin
  pW[t], "Wage per efficiency unit."
  pL_l_i[(l,i,t)=nL_l_i], "User cost per efficiency unit by type and industry."
  ntL_l_i[(l,i,t)=nL_l_i] :: ForecastConstant, "Production tax less subsidy per efficiency unit."
end

@variables model :: (LaborTag, GrowthAdjusted, InflationAdjusted) begin
  vW[t], "Wage per person."
  vWages_i[i=industry, t=t], "Wages by industry."
  vWages[t], "Total wages."
  vHhWages[t], "Household wages."
  vRoWNetWages[t], "Rest-of-world net wages."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, nL_l_i, nL_l_i_data)
  fill_cells!(db, vHhWages, vHhWages_data)
  fill_cells!(db, vRoWNetWages, vRoWNetWages_data)

  db[pW] .= 1
  db[vW[(t1-2):t1]] .= [
    (cell_value(vHhWages_data, year) + cell_value(vRoWNetWages_data, year)) /
      cell_value(nLSupply_data, year)
    for year in (t1-2):t1
  ]
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  # Keep calibrated production quantities; seed only missing leaves.
  q_start = start_values[qProd[labor_type,:,:]]
  q_start .= ifelse.(isnothing.(q_start), start_values[qL_l_i][labor_type,:,:], q_start)
  start_values[ntL_l_i] .= 0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    qL_l_i[l=labor_type, i=industry, t=t1:T], qL_l_i[l,i,t] == qProd[l,i,t] / pL_l_i[l,i,t1]

    nL_l_i[l=labor_type, i=industry, t=t1:T], qL_l_i[l,i,t] == nL_l_i[l,i,t] * qL2nL[t]

    # Total persons from households and the rest of the world meet labor demand.
    pW[t=t1:T], nLSupplyHh[t] + nLSupplyRoW[t] == ∑(nL_l_i[l,i,t] for (l, i) in labor_l_i)

    vW[t=t1:T], vW[t] == pW[t] * qL2nL[t]

    pL_l_i[l=labor_type, i=industry, t=t1:T], pL_l_i[l,i,t] == pW[t] + ntL_l_i[l,i,t]

    pProd[l=labor_type, i=industry, t=t1:T], pProd[l,i,t] == pL_l_i[l,i,t] / pL_l_i[l,i,t1]

    vWages_i[i=industry, t=t1:T], vWages_i[i,t] == vW[t] * ∑(nL_l_i[l,i,t] for l in labor_type)

    vWages[t=t1:T], vWages[t] == ∑(vWages_i[i,t] for i in industry)

    vHhWages[t=t1:T], vHhWages[t] == vW[t] * nLSupplyHh[t]

    vRoWNetWages[t=t1:T], vRoWNetWages[t] == vW[t] * nLSupplyRoW[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qProd[l=labor_type, i=industry, t=t1], nL_l_i[l=labor_type, i=industry, t=t1]
    qL2nL[t1], vW[t1]
    nLSupplyHh[t1], vHhWages[t1]
    nLSupplyRoW[t1], vRoWNetWages[t1]
  end

  return block
end
end # module
