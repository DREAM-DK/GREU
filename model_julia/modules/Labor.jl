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
import ..Settings: model_modules
include(joinpath(@__DIR__, "LaborNestingSettings.jl"))
import .LaborNestingSettings: labor_types as nesting_labor_types
import ..Time: t, t1, T, tBase
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
  nLSupplyHhType[l=nesting_labor_types, t=t], "Household labor supply by type."
  nLSupplyRoWType[l=nesting_labor_types, t=t] :: ForecastConstant, "Rest-of-world labor supply by type."
  nLType[l=nesting_labor_types, t=t], "Employment by type from industry CES quantity shares."
end

@variables model :: (LaborTag, GrowthAdjusted) begin
  qL_l_i[(l,i,t)=nL_l_i], "Labor in efficiency units by type and industry."
  qL2nL[t] :: ForecastConstant, "Efficiency units per person."
end

@variables model :: (LaborTag, InflationAdjusted) begin
  pW[t], "Wage per efficiency unit."
  pWType[l=nesting_labor_types, t=t], "Endogenous wage per efficiency unit by labor type."
  pLType_i[l=nesting_labor_types, i=industry, t=t; (:labor,i) in labor_l_i], "Labor cost by type and industry (step 3A)."
  pL_l_i[(l,i,t)=nL_l_i], "User cost per efficiency unit by type and industry."
  ntL_l_i[(l,i,t)=nL_l_i] :: ForecastConstant, "Production tax less subsidy per efficiency unit."
end

@variables model :: (LaborTag, GrowthAdjusted, InflationAdjusted) begin
  vW[t], "Wage per person."
  vWType[l=nesting_labor_types, t=t], "Wage per person by type."
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
  db[pWType] .= 1
  # Historical wages initialize each type at the observed aggregate wage.
  for l in nesting_labor_types
    db[vWType[l,(t1-2):t1]] .= [
      (cell_value(vHhWages_data, year) + cell_value(vRoWNetWages_data, year)) /
        cell_value(nLSupply_data, year) for year in (t1-2):t1
    ]
  end
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
    qL_l_i[l=labor_type, i=industry, t=t1:T], qL_l_i[l,i,t] == qProd[l,i,t] / pL_l_i[l,i,tBase]

    nL_l_i[l=labor_type, i=industry, t=t1:T], qL_l_i[l,i,t] == nL_l_i[l,i,t] * qL2nL[t]

    # Aggregate household supply is the sum across labor types.
    nLSupplyHh[t=t1:T],
      nLSupplyHh[t] == ∑(nLSupplyHhType[l,t] for l in nesting_labor_types)

    # RoW supply has the same type composition as CES employment.
    # Cross multiplication avoids division by total employment.
    nLSupplyRoWType[l=nesting_labor_types, t=t1:T],
      nLSupplyRoWType[l,t] * ∑(nLType[k,t] for k in nesting_labor_types) ==
        nLSupplyRoW[t] * nLType[l,t]

    pWType[l=nesting_labor_types, t=t1:T],
      nLSupplyHhType[l,t] + nLSupplyRoWType[l,t] == nLType[l,t]

    pW[t=t1:T],
      pW[t] * (nLSupplyHh[t] + nLSupplyRoW[t]) ==
        ∑(pWType[l,t] * nLType[l,t] for l in nesting_labor_types)

    vW[t=t1:T], vW[t] == pW[t] * qL2nL[t]

    pL_l_i[l=labor_type, i=industry, t=t1:T], pL_l_i[l,i,t] == pW[t] + ntL_l_i[l,i,t]

    # Type-specific wages feed the CES labor costs.
    vWType[l=nesting_labor_types, t=t1:T], vWType[l,t] == pWType[l,t] * qL2nL[t]
    pLType_i[l=nesting_labor_types, i=industry, t=t1:T; (:labor,i) in labor_l_i],
      pLType_i[l,i,t] == pWType[l,t] + ntL_l_i[:labor,i,t]

    pProd[l=labor_type, i=industry, t=t1:T; !(:LaborNesting in model_modules)],
      pProd[l,i,t] == pL_l_i[l,i,t] / pL_l_i[l,i,tBase]

    vWages_i[i=industry, t=t1:T], vWages_i[i,t] == vW[t] * ∑(nL_l_i[l,i,t] for l in labor_type)

    vWages[t=t1:T], vWages[t] == ∑(vWages_i[i,t] for i in industry)

    vHhWages[t=t1:T], vHhWages[t] == ∑(vWType[l,t] * nLSupplyHhType[l,t] for l in nesting_labor_types)

    vRoWNetWages[t=t1:T], vRoWNetWages[t] == ∑(vWType[l,t] * nLSupplyRoWType[l,t] for l in nesting_labor_types)

    # Diagnostic only: RoW aggregate must match the sum of its type supplies.
    # This is implied by the proportional RoW allocation (for positive total
    # employment) and must NOT be a second model equation.
    @test_constraint("RoW labor supply equals sum of labor types"; atol=1.0, rtol=1e-6)
    nLSupplyRoW[t=t1:T],
      nLSupplyRoW[t] == ∑(nLSupplyRoWType[l,t] for l in nesting_labor_types)

    # Diagnostic only: original aggregate employment identity.
    # This is not a model equation and may reveal CES headcount inconsistencies.
    @test_constraint("Aggregate labor supply equals production employment"; atol=1.0, rtol=1e-6)
    nLSupplyHh[t=t1:T],
      nLSupplyHh[t] + nLSupplyRoW[t] == ∑(nL_l_i[l,i,t] for (l,i) in labor_l_i)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  block = copy(base)

  @endo_exo_swap! block begin
    qProd[l=labor_type, i=industry, t=t1], nL_l_i[l=labor_type, i=industry, t=t1]
    qL2nL[t1], vW[t1]
    nLSupplyRoW[t1], vRoWNetWages[t1]
  end

  # Symmetric base-year closure: every labor type uses the same swap.
  # Use an explicit loop: @endo_exo_swap! does not bind the l=... index.
  for l in nesting_labor_types
    @endo_exo_swap! block begin
      nLSupplyHhType[l,t1], pWType[l,t1]
    end
  end

  return block
end
end # module
