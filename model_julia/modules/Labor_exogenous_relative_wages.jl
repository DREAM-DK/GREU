# Define labor demand, employment, and the wage by labor type.
# Hold relative wages at the base-year ratio. Household supply by education clears that market.
# The reference wage clears total persons. Rest-of-world persons keep the household distribution.
# Their total stays at the baseline. Fix efficiency per person and include the production tax.
# Link wage income to households and the rest of the world.
# Do not use this closure together with the Phillips curve.
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

# The first education is the reference. Its wage clears total persons.
const reference_labor_type = first(labor_type)
const other_labor_type = labor_type[2:end]

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
  nLSupplyHh_l[l=labor_type, t=t], "Household persons by type."
  nLSupplyRoW_l[l=labor_type, t=t], "Rest-of-world persons by type."
  nLSupplyHh[t], "Household persons."
  nLSupplyRoW[t] :: ForecastConstant, "Rest-of-world persons."
  nLSupply[t] :: ForecastConstant, "Total persons."
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

  # Total persons stay at the base-year sum of employed persons.
  n_bar = sum(
    value for ((l, i, year), value) in nL_l_i_data if (l, i) in labor_l_i && year == t1;
    init = 0.0,
  )
  @assert isfinite(n_bar) && n_bar > 0 "Total persons in the base year must be positive"
  db[nLSupply] .= n_bar

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
  start_values[nLSupplyHh_l[:,t1]] .= [sum(start_values[nL_l_i[l,:,t1]]) for l in labor_type]
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

    # Household supply of each education clears that education's labor market.
    nLSupplyHh_l[l=labor_type, t=t1:T],
    nLSupplyHh_l[l,t] + nLSupplyRoW_l[l,t] == ∑(nL_l_i[l,i,t] for i in industry)

    # The average efficiency per person of each type is fixed. The factor absorbs the
    # composition effect when persons move between industries.
    fqL2nL_l[l=labor_type, t=t1:T],
    ∑(qL_l_i[l,i,t] for i in industry) == qL2nL_l[l,t] * (nLSupplyHh_l[l,t] + nLSupplyRoW_l[l,t])

    nLSupplyHh[t=t1:T], nLSupplyHh[t] == ∑(nLSupplyHh_l[l,t] for l in labor_type)

    # Rest-of-world persons keep the household distribution across educations.
    nLSupplyRoW_l[l=other_labor_type, t=t1:T],
    nLSupplyRoW_l[l,t] * nLSupplyHh[t] == nLSupplyHh_l[l,t] * nLSupplyRoW[t]

    # The reference education fills the total. That total stays at the baseline.
    nLSupplyRoW_l[reference_labor_type, t=t1:T],
    nLSupplyRoW_l[reference_labor_type,t] == nLSupplyRoW[t]
      - ∑(nLSupplyRoW_l[l,t] for l in other_labor_type)

    vW_l[l=labor_type, t=t1:T], vW_l[l,t] == pW_l[l,t] * qL2nL_l[l,t]

    # The wage per person stays at the base-year ratio to the reference education.
    # That base-year ratio is the baseline. The reference wage is cleared below.
    pW_l[l=other_labor_type, t=t1:T; t > tBase],
    vW_l[l,t] * vW_l[reference_labor_type,tBase] == vW_l[reference_labor_type,t] * vW_l[l,tBase]

    # Total persons stay at the baseline number. The reference wage clears the labor market.
    pW_l[reference_labor_type, t=t1:T],
    ∑(nLSupplyHh_l[l,t] + nLSupplyRoW_l[l,t] for l in labor_type) == nLSupply[t]

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
  # type average. Household persons clear each education market. The base-year wage bill sets
  # total rest-of-world persons. The base-year wage per efficiency unit stays at one.
  block = copy(base) + @block model begin
    nLSupplyRoW[t=t1],
    nLSupplyRoW[t] * vWages[t] == vRoWNetWages[t] * ∑(nL_l_i[l,i,t] for (l, i) in labor_l_i)
  end

  @endo_exo_swap! block begin
    qProd[l=labor_type, i=industry, t=t1], nL_l_i[l=labor_type, i=industry, t=t1]
    qL2nL_l_i[:,:,t1], vWages_l_i[:,:,t1]
    qL2nL_l[:,t1], fqL2nL_l[:,t1]
  end

  return block
end
end # module
