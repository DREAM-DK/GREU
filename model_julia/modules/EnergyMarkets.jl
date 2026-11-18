# Let industries substitute between energy products inside their energy input.
# Make the product shares of the energy input in Intermediates endogenous through CES demand.
# Keep fixed shares in the energy industries, whose energy inputs are mostly feedstock.
include(joinpath(@__DIR__, "EnergyMarketSettings.jl"))

module EnergyMarkets

using SquareModels
import ..EnergyMarketSettings: energy_elasticity, energy_members
import ..InputOutput: industry, pPurchaserUse_p_u
import ..InputOutputSettings: industry_members, product
import ..Intermediates: ntM_m_i, pM_m_i, rIntermediateProductShare
import ..Production: intermediate_product_m_i
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Indices
# ============================================================================
# Energy industries keep fixed shares.
const energy_industry = [i for i in industry if industry_members[i] ⊆ energy_members]

# Energy products that each other industry buys.
const energy_input_p_i = Set((p,i) for (p,m,i) in intermediate_product_m_i if m == :energy && !(i in energy_industry))
const energy_user = sort(unique(i for (_,i) in energy_input_p_i))

# ============================================================================
# Variables
# ============================================================================
const EnergyMarketsTag = Tag(:EnergyMarkets)

@variables model :: EnergyMarketsTag begin
  uEnergy_p_i[p=product, i=industry, t=t; (p,i) in energy_input_p_i] :: ForecastConstant, "CES weight of an energy product by industry."
  eEnergy_i[i=energy_user], "Substitution elasticity between energy products by industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[eEnergy_i] .= energy_elasticity
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # CES demand. A product's share falls when its price rises relative to the energy input.
    # The energy input is priced before production tax, which falls on all its products alike.
    rIntermediateProductShare[p=product, m=[:energy], i=industry, t=t1:T; (p,i) in energy_input_p_i],
    rIntermediateProductShare[p,m,i,t] ==
      uEnergy_p_i[p,i,t] * ((pM_m_i[m,i,t] - ntM_m_i[m,i,t]) / pPurchaserUse_p_u[p,i,t])^eEnergy_i[i]
  end
end

# ============================================================================
# Calibration
# ============================================================================
# Data fix the shares in the first year. The CES weights follow from them.
function define_calibration(base=define_equations())
  block = copy(base)
  @endo_exo_swap! block begin
    uEnergy_p_i[:,:,t1],
    rIntermediateProductShare[(p,m,i,t) in keys(rIntermediateProductShare); m == :energy && (p,i) in energy_input_p_i && t == t1]
  end
  return block
end

end # module