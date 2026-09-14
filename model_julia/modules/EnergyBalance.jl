# Define the physical energy account as model variables.
# Read supply and use in petajoules, and check that they balance by account.
# Keep the fetch and the source mappings in EnergyBalanceData.jl.
include(joinpath(@__DIR__, "EnergyBalanceSettings.jl"))

module EnergyBalance

using SquareModels
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted
import ..EnergyBalanceSettings:
  activity_balance_atol,
  activity_balance_rtol,
  boundary_account,
  energy_balance_data_dir,
  households,
  source_industry,
  source_product
import ..InputOutputSettings
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastZero


# ==============================================================================
# Read data
# ==============================================================================
const energy_balance_file = joinpath(energy_balance_data_dir, "energy_balance.csv")
const qESupply_e_d_data = read_cells(energy_balance_file, "qESupply_e_d")
const qEUse_e_d_data = read_cells(energy_balance_file, "qEUse_e_d")
const qEDiscrepancy_d_data = read_cells(energy_balance_file, "qEDiscrepancy_d")

# The data step drops exact zeros, so a pair reported in one year can be absent in another.
# The forecast years are not in here on purpose.
const data_year = sort!(unique(year for (_, _, year) in [keys(qESupply_e_d_data)...; keys(qEUse_e_d_data)...]))


# ==============================================================================
# Indices
# ==============================================================================
# Build the masks from the reported cells, not from the cross product: 23 accounts x 31 products x 5 years.
# A cell outside the mask gets no variable and no equation.
const supply_e_d = Set((e,d) for (e, d, _) in keys(qESupply_e_d_data))
const use_e_d = Set((e,d) for (e, d, _) in keys(qEUse_e_d_data))

const account = sort!(unique(d for (_, d) in supply_e_d ∪ use_e_d))
const energy_product = sort!(unique(e for (e,_) in supply_e_d ∪ use_e_d))

# The data decides which accounts exist; the settings decide which are allowed.
# Sections T and U report no energy, so the account set is smaller than the source vocabulary and must not be built from it.
const permitted_account = [source_industry; households; collect(values(boundary_account))]
@assert account ⊆ permitted_account "the data holds an account the settings do not name"
@assert energy_product ⊆ Symbol.(source_product) "the data holds a product the settings do not name"

# Energy is conserved for a resident account only.
# The three boundary accounts are where it enters and leaves the economy, so they carry no balance.
const resident_account = [d for d in account if d in [source_industry; households]]

# The industry labels must agree with the input-output module, which builds them by the same rule.
# If one side changes the prefix, this fires now instead of becoming a silent mismatch later.
@assert Set(resident_account) ⊆ Set([InputOutputSettings.source_industry; households]) "energy accounts must be input-output industries or households"


# ==============================================================================
# Variables
# ==============================================================================
const EnergyBalanceTag = Tag(:EnergyBalance)

@variables model :: (EnergyBalanceTag, GrowthAdjusted) begin
  qESupply_e_d[e=energy_product, d=account, t=t; (e,d) in supply_e_d], "Physical energy supply by account and product"
  qEUse_e_d[e=energy_product, d=account, t=t; (e,d) in use_e_d], "Physical energy use by account and product"
  qEUseTotal_d[d=resident_account, t=t], "Physical energy a resident account takes in"
  qESupplyTotal_d[d=resident_account, t=t], "Physical energy a resident account gives out"
  qEDiscrepancy_d[d=resident_account, t=t], "Net SD_IO that PEFA books to make a resident account close."


  jqESupply_e_d[(e,d,t)=qESupply_e_d] :: ForecastZero, "Hook for a module that changes energy supply, for example network losses"
  jqEUse_e_d[(e,d,t)=qEUse_e_d] :: ForecastZero, "Hook for a module that changes the fuel mix"

end

# ==============================================================================
# Assign data
# ==============================================================================
# A missing cell inside a mask is a zero and not an unknown: the data step asserted that the account balanced without it.
# Fill the data years only, so the forecast years still take their values from t1.
fill_data_years(cells, mask) = Dict(
  (e, d, year) => get(cells, (e, d, year), 0.0)
  for (e, d) in mask, year in data_year
)

function assign_data!(db)
  fill_cells!(db, qESupply_e_d, fill_data_years(qESupply_e_d_data, supply_e_d))
  fill_cells!(db, qEUse_e_d, fill_data_years(qEUse_e_d_data, use_e_d))
  fill_cells!(db, qEDiscrepancy_d, qEDiscrepancy_d_data)
  return nothing
end



# ==============================================================================
# Starting values
# ==============================================================================
function set_starting_values!(start_values)
  return nothing
end


# ==============================================================================
# Equations
# ==============================================================================
function define_equations()
  return @block model begin
    # Each side gets its own equation, so both enter the solve model. A variable
    # that appears only in a test constraint is outside it, and the forecast
    # machinery never gives that variable a value after t1.
    qEUseTotal_d[d=resident_account, t=t1:T],
    qEUseTotal_d[d,t] == ∑(qEUse_e_d[e,d,t] + jqEUse_e_d[e,d,t] for e in energy_product if (e,d) in use_e_d)

    # PEFA books SD_IO where a country's supply and use do not close, so it
    # belongs on this side: it is what makes the account balance. Without it the
    # model asserts a different invariant from the data step, and 9 of 27 member
    # states fail. Denmark reports zero, and cannot show the difference.
    qESupplyTotal_d[d=resident_account, t=t1:T],
    qESupplyTotal_d[d,t] == ∑(qESupply_e_d[e,d,t] + jqESupply_e_d[e,d,t] for e in energy_product if (e,d) in supply_e_d) + qEDiscrepancy_d[d,t]


    # Physical energy is conserved, so a resident account gives out what it takes
    # in. The tolerances are the ones the data step asserts on the source cells.
    @test_constraint("Physical energy supply and use balance by resident account"; rtol = activity_balance_rtol, atol = activity_balance_atol)
    qEUseTotal_d[d=resident_account, t=t1:T],
    qEUseTotal_d[d,t] == qESupplyTotal_d[d,t]
  end
end


# ==============================================================================
# Calibration
# ==============================================================================
function define_calibration()
  return define_equations()
end




end # module EnergyBalance