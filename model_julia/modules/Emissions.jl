# Define greenhouse gas emissions by gas and account as model variables.
# CO2 from fuel follows energy use, emissions not from fuel follow output,
# and four totals lead from the residence principle to the inventory.
# Keep the fetch and the source checks in EmissionsData.jl.
include(joinpath(@__DIR__, "EmissionsSettings.jl"))

module Emissions

using SquareModels
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted
import ..InputOutput: industry
import ..Production: qProd, topNest
import ..EnergyBalance: qEUse_e_d, qEUse_e_d_data
import ..EnergyBalanceSettings: households
import ..EmissionsSettings: biogenic_co2, co2_equivalent_gas, emissions_data_dir
import ..Settings: calibration_year
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant


# ============================================================================
# Read data
# ============================================================================
const emissions_file = joinpath(emissions_data_dir, "emissions.csv")
const qEmmE_g_e_d_data = read_cells(emissions_file, "qEmmE_g_e_d")
const qEmmxE_g_d_data = read_cells(emissions_file, "qEmmxE_g_d")
const qEmm_g_d_data = read_cells(emissions_file, "qEmm_g_d")
const qEmmCO2e_d_data = read_cells(emissions_file, "qEmmCO2e_d")
const qEmmBunkering_g_d_data = read_cells(emissions_file, "qEmmBunkering_g_d")
const qEmmInternationalAviation_g_d_data = read_cells(emissions_file, "qEmmInternationalAviation_g_d")
const qEmmBorderTrade_g_data = read_cells(emissions_file, "qEmmBorderTrade_g")
const qEmmOtherDifferences_g_data = read_cells(emissions_file, "qEmmOtherDifferences_g")
const qEmmLULUCF_g_data = read_cells(emissions_file, "qEmmLULUCF_g")
const qEmmTot_g_b_data = read_cells(emissions_file, "qEmmTot_g_b")
const qEmmTotCO2e_b_data = read_cells(emissions_file, "qEmmTotCO2e_b")


# ============================================================================
# Indices
# ============================================================================
# The six parts of the greenhouse gas total, and biogenic CO2 beside them.
const co2e_gas = Symbol.(co2_equivalent_gas)
const gas = [co2e_gas; Symbol(biogenic_co2)]

# A cell gets a variable only if it has a value in the calibration year, as in the GAMS model.
# Each coefficient is emissions over energy use or output in that year, so an empty cell has none.
at_t1(cells) = Set(Base.front(key) for key in keys(cells) if last(key) == calibration_year)

const fuel_g_e_d = at_t1(qEmmE_g_e_d_data)
const fuel_g_d = Set((g,d) for (g, _, d) in fuel_g_e_d)
const not_fuel_g_d = at_t1(qEmmxE_g_d_data)
const emission_g_d = fuel_g_d ∪ not_fuel_g_d
const bunkering_g_d = at_t1(qEmmBunkering_g_d_data)
const aviation_g_d = at_t1(qEmmInternationalAviation_g_d_data)
const bunkering_g = Set(g for (g, _) in bunkering_g_d)
const aviation_g = Set(g for (g, _) in aviation_g_d)
const border_trade_g = Set(g for (g,) in at_t1(qEmmBorderTrade_g_data))
const other_differences_g = Set(g for (g,) in at_t1(qEmmOtherDifferences_g_data))
const lulucf_g = Set(g for (g,) in at_t1(qEmmLULUCF_g_data))

const fuel = sort!(unique(e for (_, e, _) in fuel_g_e_d))
const account = sort!(unique(d for (_, d) in emission_g_d))
const inventory = [:GNA, :GNA_LULUCF, :UNFCCC, :UNFCCC_LULUCF]

# A coefficient over a zero has no value, so each base must be there in the calibration year.
@assert all(get(qEUse_e_d_data, (e,d,calibration_year), 0.0) > 0 for (_, e, d) in fuel_g_e_d) "CO2 from fuel needs energy use in the same cell"
@assert all(d in industry || d == households for (_, d) in not_fuel_g_d) "emissions not from fuel need an industry with output, or households"
@assert bunkering_g_d ∪ aviation_g_d ⊆ emission_g_d "fuel bought abroad needs emissions in its industry"

# Calibration compares each reported total with the model's own sum. A reported cell
# with no model cell would not be compared, so each one needs a model cell.
@assert all((g,d) in emission_g_d for (g, d) in at_t1(qEmm_g_d_data) if g in co2e_gas) "each reported emission needs a part from fuel or not from fuel"
@assert Set(d for (d,) in at_t1(qEmmCO2e_d_data)) ⊆ Set(account) "each reported greenhouse gas total needs an account"
@assert Set(b for (_, b) in at_t1(qEmmTot_g_b_data)) == Set(inventory) "the data step and the model must name the same totals"





# ============================================================================
# Variables
# ============================================================================
const EmissionsTag = Tag(:Emissions)

@variables model :: (EmissionsTag, GrowthAdjusted) begin
  qEmmE_g_e_d[g=gas, e=fuel, d=account, t=t; (g,e,d) in fuel_g_e_d], "CO2 from burned fuel by gas, fuel and account."
  qEmmE_g_d[g=gas, d=account, t=t; (g,d) in fuel_g_d], "CO2 from burned fuel by gas and account."
  qEmmxE_g_d[g=gas, d=account, t=t; (g,d) in not_fuel_g_d], "Emissions not from fuel by gas and account."
  qEmm_g_d[g=gas, d=account, t=t; (g,d) in emission_g_d], "Emissions by gas and account."
  qEmmCO2e_d[d=account, t=t], "Greenhouse gas emissions by account, in CO2 equivalents."

  qEmmBunkering_g_d[g=co2e_gas, d=account, t=t; (g,d) in bunkering_g_d], "Emissions from fuel that resident ships, lorries and fishing vessels buy abroad, by industry."
  qEmmBunkering_g[g=co2e_gas, t=t; g in bunkering_g], "Emissions from fuel that resident ships, lorries and fishing vessels buy abroad."
  qEmmInternationalAviation_g_d[g=co2e_gas, d=account, t=t; (g,d) in aviation_g_d], "Emissions from fuel that resident aircraft buy abroad, by industry."
  qEmmInternationalAviation_g[g=co2e_gas, t=t; g in aviation_g], "Emissions from fuel that resident aircraft buy abroad."
  qEmmBorderTrade_g[g=co2e_gas, t=t; g in border_trade_g], "Emissions from fuel that non-residents buy in the country, with a minus."
  qEmmOtherDifferences_g[g=co2e_gas, t=t; g in other_differences_g], "Other differences between the residence total and the inventory."
  qEmmLULUCF_g[g=co2e_gas, t=t; g in lulucf_g], "Emissions from land use, land-use change and forestry."
  qEmmTot_g_b[g=co2e_gas, b=inventory, t=t], "Emissions of the whole economy by gas and inventory."
  qEmmTotCO2e_b[b=inventory, t=t], "Greenhouse gas emissions of the whole economy by inventory, in CO2 equivalents."
end

@variables model :: EmissionsTag begin
  uEmmE_g_e_d[(g,e,d,t)=qEmmE_g_e_d] :: ForecastConstant, "CO2 per PJ of energy use, by gas, fuel and account."
  uEmmxE_g_d[(g,d,t)=qEmmxE_g_d] :: ForecastConstant, "Emissions not from fuel per unit of output; in households, the emissions themselves."
  uEmmBunkering_g_d[(g,d,t)=qEmmBunkering_g_d] :: ForecastConstant, "Share of an industry's emissions from fuel bought abroad by ships, lorries and fishing vessels."
  uEmmInternationalAviation_g_d[(g,d,t)=qEmmInternationalAviation_g_d] :: ForecastConstant, "Share of an industry's emissions from fuel bought abroad by aircraft."
end


# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, qEmmE_g_e_d, qEmmE_g_e_d_data)
  fill_cells!(db, qEmmxE_g_d, qEmmxE_g_d_data)
  # Biogenic CO2 is fuel times an IPCC factor and differs from the source by design,
  # so calibration compares only the six parts with the source.
  fill_cells!(db, qEmm_g_d, Dict(key => value for (key, value) in qEmm_g_d_data if first(key) in co2e_gas))
  fill_cells!(db, qEmmCO2e_d, qEmmCO2e_d_data)
  fill_cells!(db, qEmmBunkering_g_d, qEmmBunkering_g_d_data)
  fill_cells!(db, qEmmInternationalAviation_g_d, qEmmInternationalAviation_g_d_data)
  fill_cells!(db, qEmmBorderTrade_g, qEmmBorderTrade_g_data)
  fill_cells!(db, qEmmOtherDifferences_g, qEmmOtherDifferences_g_data)
  fill_cells!(db, qEmmLULUCF_g, qEmmLULUCF_g_data)
  fill_cells!(db, qEmmTot_g_b, qEmmTot_g_b_data)
  fill_cells!(db, qEmmTotCO2e_b, qEmmTotCO2e_b_data)
  return nothing
end



# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # CO2 from fuel follows energy use, cell by cell.
    qEmmE_g_e_d[g=gas, e=fuel, d=account, t=t1:T; (g,e,d) in fuel_g_e_d],
    qEmmE_g_e_d[g,e,d,t] == uEmmE_g_e_d[g,e,d,t] * qEUse_e_d[e,d,t]

    qEmmE_g_d[g=gas, d=account, t=t1:T; (g,d) in fuel_g_d],
    qEmmE_g_d[g,d,t] == ∑(qEmmE_g_e_d[g,e,d,t] for e in fuel if (g,e,d) in fuel_g_e_d)

    # Emissions not from fuel follow output in an industry and stay flat in households.
    qEmmxE_g_d[g=gas, d=industry, t=t1:T; (g,d) in not_fuel_g_d],
    qEmmxE_g_d[g,d,t] == uEmmxE_g_d[g,d,t] * qProd[topNest[d],d,t]

    qEmmxE_g_d[g=gas, d=[households], t=t1:T; (g,d) in not_fuel_g_d], qEmmxE_g_d[g,d,t] == uEmmxE_g_d[g,d,t]

    # A part that an account does not have is zero.
    qEmm_g_d[g=gas, d=account, t=t1:T; (g,d) in emission_g_d], qEmm_g_d[g,d,t] == qEmmE_g_d[g,d,t] + qEmmxE_g_d[g,d,t]

    qEmmCO2e_d[d=account, t=t1:T], qEmmCO2e_d[d,t] == ∑(qEmm_g_d[g,d,t] for g in co2e_gas if (g,d) in emission_g_d)

    # Fuel bought abroad is a fixed share of the emissions of the industry that buys it.
    qEmmBunkering_g_d[g=co2e_gas, d=account, t=t1:T; (g,d) in bunkering_g_d],
    qEmmBunkering_g_d[g,d,t] == uEmmBunkering_g_d[g,d,t] * qEmm_g_d[g,d,t]

    qEmmBunkering_g[g=co2e_gas, t=t1:T; g in bunkering_g],
    qEmmBunkering_g[g,t] == ∑(qEmmBunkering_g_d[g,d,t] for d in account if (g,d) in bunkering_g_d)

    qEmmInternationalAviation_g_d[g=co2e_gas, d=account, t=t1:T; (g,d) in aviation_g_d],
    qEmmInternationalAviation_g_d[g,d,t] == uEmmInternationalAviation_g_d[g,d,t] * qEmm_g_d[g,d,t]

    qEmmInternationalAviation_g[g=co2e_gas, t=t1:T; g in aviation_g],
    qEmmInternationalAviation_g[g,t] == ∑(qEmmInternationalAviation_g_d[g,d,t] for d in account if (g,d) in aviation_g_d)

    # The four totals, as in the GAMS model. The inventory leaves out fuel that residents buy abroad
    # and adds fuel that non-residents buy in the country. An item that a gas does not have is zero.
    qEmmTot_g_b[g=co2e_gas, b=[:GNA], t=t1:T],
    qEmmTot_g_b[g,b,t] == ∑(qEmm_g_d[g,d,t] for d in account if (g,d) in emission_g_d)

    qEmmTot_g_b[g=co2e_gas, b=[:GNA_LULUCF], t=t1:T], qEmmTot_g_b[g,b,t] == qEmmTot_g_b[g,:GNA,t] + qEmmLULUCF_g[g,t]

    qEmmTot_g_b[g=co2e_gas, b=[:UNFCCC], t=t1:T],
    qEmmTot_g_b[g,b,t] == qEmmTot_g_b[g,:GNA,t] - qEmmBunkering_g[g,t] - qEmmInternationalAviation_g[g,t]
                          - qEmmBorderTrade_g[g,t] - qEmmOtherDifferences_g[g,t]

    qEmmTot_g_b[g=co2e_gas, b=[:UNFCCC_LULUCF], t=t1:T],
    qEmmTot_g_b[g,b,t] == qEmmTot_g_b[g,:UNFCCC,t] + qEmmLULUCF_g[g,t]

    qEmmTotCO2e_b[b=inventory, t=t1:T], qEmmTotCO2e_b[b,t] == ∑(qEmmTot_g_b[g,b,t] for g in co2e_gas)
  end
end


# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # Each coefficient is set by the emissions in the calibration year.
  @endo_exo_swap! block begin
    uEmmE_g_e_d[:,:,:,t1], qEmmE_g_e_d[:,:,:,t1]
    uEmmxE_g_d[:,:,t1], qEmmxE_g_d[:,:,t1]
    uEmmBunkering_g_d[:,:,t1], qEmmBunkering_g_d[:,:,t1]
    uEmmInternationalAviation_g_d[:,:,t1], qEmmInternationalAviation_g_d[:,:,t1]
  end

  return block
end


end # module Emissions

