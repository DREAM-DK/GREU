# Define labor demand, employment, and the wage by labor type.
# Clear one labor market for each labor type.
# Fix efficiency units per person by industry, and hold the type average constant,
# so a move of persons between industries does not change total efficiency units.
# Include production tax in the labor user cost and production link.
# Link wages by type to household and rest-of-world wage income.
# Keep capital, intermediate inputs, and CES nests in other modules.
module Labor

using SquareModels
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry
import ..Production: pProd, qProd, labor_file, nL_l_i_data, labor_l_i
import ..ProductionSettings: labor_type
import ..model
import ..Time: t, t1, T, tBase
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const sector_accounts_file = joinpath(@__DIR__, "..", "data", "sector_accounts", "sector_accounts.csv")
const vWages_l_i_data = read_cells(labor_file, "vWages_l_i")
const vHhWages_data = read_cells(sector_accounts_file, "vHhWages")
const vRoWNetWages_data = read_cells(sector_accounts_file, "vRoWNetWages")

# ============================================================================
# Variables
# ============================================================================
const LaborTag = Tag(:Labor)

@variables model :: LaborTag begin
  nL_l_i[l=labor_type, i=industry, t=t; (l,i) in labor_l_i], "Persons by type and industry."
  nLSupplyHh_l[l=labor_type, t=t] :: ForecastConstant, "Household persons by type."
  nLSupplyRoW_l[l=labor_type, t=t] :: ForecastConstant, "Rest-of-world persons by type."
  nLSupplyHh[t], "Household persons."
  nLSupplyRoW[t], "Rest-of-world persons."
  fqL2nL_l[l=labor_type, t=t], "Factor on efficiency units per person by type. One in the base year."
end

@variables model :: (LaborTag, GrowthAdjusted) begin
  qL_l_i[(l,i,t)=nL_l_i], "Labor in efficiency units by type and industry."
  qL2nL_l_i[(l,i,t)=nL_l_i] :: ForecastConstant, "Base efficiency units per person by type and industry."
  qL2nL_l[l=labor_type, t=t] :: ForecastConstant, "Average efficiency units per person by type."
end

@variables model :: (LaborTag, InflationAdjusted) begin
  pW_l[l=labor_type, t=t], "Wage per efficiency unit by type."
  pL_l_i[(l,i,t)=nL_l_i], "User cost per efficiency unit by type and industry."
  ntL_l_i[(l,i,t)=nL_l_i] :: ForecastConstant, "Production tax less subsidy per efficiency unit."
end

@variables model :: (LaborTag, GrowthAdjusted, InflationAdjusted) begin
  vW_l[l=labor_type, t=t], "Wage per person by type."
  vW[t], "Average wage per person."
  vWages_l_i[(l,i,t)=nL_l_i], "Wages by type and industry."
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
  fill_cells!(db, vWages_l_i, vWages_l_i_data)
  fill_cells!(db, vHhWages, vHhWages_data)
  fill_cells!(db, vRoWNetWages, vRoWNetWages_data)

  db[pW_l] .= 1
  db[fqL2nL_l] .= 1

  # The Phillips curve reads the lagged wage per person. Average each type over its industries.
  db[vW_l[:,t1-1]] .= [sum(db[vWages_l_i[l,:,t1-1]]) / sum(db[nL_l_i[l,:,t1-1]]) for l in labor_type]
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
    qL_l_i[l=labor_type, i=industry, t=t1:T], qL_l_i[l,i,t] == qProd[l,i,t] / pL_l_i[l,i,tBase]

    # Efficiency units per person differ by industry. A common factor by type scales them.
    nL_l_i[l=labor_type, i=industry, t=t1:T], qL_l_i[l,i,t] == fqL2nL_l[l,t] * qL2nL_l_i[l,i,t] * nL_l_i[l,i,t]

    # Persons of each type from households and the rest of the world meet labor demand.
    pW_l[l=labor_type, t=t1:T], nLSupplyHh_l[l,t] + nLSupplyRoW_l[l,t] == ∑(nL_l_i[l,i,t] for i in industry)

    # The average efficiency per person of each type is fixed. The factor absorbs the
    # composition effect when persons move between industries.
    fqL2nL_l[l=labor_type, t=t1:T],
    ∑(qL_l_i[l,i,t] for i in industry) == qL2nL_l[l,t] * (nLSupplyHh_l[l,t] + nLSupplyRoW_l[l,t])

    nLSupplyHh[t=t1:T], nLSupplyHh[t] == ∑(nLSupplyHh_l[l,t] for l in labor_type)

    nLSupplyRoW[t=t1:T], nLSupplyRoW[t] == ∑(nLSupplyRoW_l[l,t] for l in labor_type)

    vW_l[l=labor_type, t=t1:T], vW_l[l,t] == pW_l[l,t] * qL2nL_l[l,t]

    pL_l_i[l=labor_type, i=industry, t=t1:T], pL_l_i[l,i,t] == pW_l[l,t] + ntL_l_i[l,i,t]

    pProd[l=labor_type, i=industry, t=t1:T], pProd[l,i,t] == pL_l_i[l,i,t] / pL_l_i[l,i,tBase]

    vWages_l_i[l=labor_type, i=industry, t=t1:T], vWages_l_i[l,i,t] == pW_l[l,t] * qL_l_i[l,i,t]

    vWages_i[i=industry, t=t1:T], vWages_i[i,t] == ∑(vWages_l_i[l,i,t] for l in labor_type)

    vWages[t=t1:T], vWages[t] == ∑(vWages_i[i,t] for i in industry)

    vW[t=t1:T], vW[t] * ∑(nL_l_i[l,i,t] for (l, i) in labor_l_i) == vWages[t]

    vHhWages[t=t1:T], vHhWages[t] == ∑(vW_l[l,t] * nLSupplyHh_l[l,t] for l in labor_type)

    vRoWNetWages[t=t1:T], vRoWNetWages[t] == ∑(vW_l[l,t] * nLSupplyRoW_l[l,t] for l in labor_type)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  # Wage data by type and industry set efficiency units per person. A unit factor sets the
  # type average. The equilibrium of each type sets household persons. The rest-of-world
  # wage share of each type splits its persons.
  block = copy(base) + @block model begin
    nLSupplyRoW_l[l=labor_type, t=t1],
    nLSupplyRoW_l[l,t] * vWages[t] == vRoWNetWages[t] * ∑(nL_l_i[l,i,t] for i in industry)
  end

  @endo_exo_swap! block begin
    qProd[l=labor_type, i=industry, t=t1], nL_l_i[l=labor_type, i=industry, t=t1]
    qL2nL_l_i[:,:,t1], vWages_l_i[:,:,t1]
    qL2nL_l[:,t1], fqL2nL_l[:,t1]
    nLSupplyHh_l[:,t1], pW_l[:,t1]
  end

  return block
end
end # module
