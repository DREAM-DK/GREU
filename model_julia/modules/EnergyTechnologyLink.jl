# Link the energy technology model to the CGE model.
# Service demand, energy prices before tax and the capital cost follow their CGE counterparts.
# The energy price of each linked industry follows the energy service price in part.
# The mappings and that share are in EnergyTechnologySettings.jl.
module EnergyTechnologyLink

using SquareModels
import ..EnergyTechnologySettings: energy_service_share, linked_capital, linked_industry, linked_product
import ..EnergyTechnology: energy, energy_es_e_d, pEBase_es_e_d, pES_es_d, pTK_d, qES_es_d, service, service_es_d, user, vES_es_d
import ..InputOutput: pPurchaserUse_p_u
import ..InputOutputSettings: product
import ..Intermediates: ntM_m_i, pM_m_i, qM_m_i, rIntermediateProductShare
import ..Capital: pK_k_i
import ..model
import ..Time: t, t1, T, tBase
import ..Tags: ForecastConstant, Override
import ..@block

# ============================================================================
# Indices
# ============================================================================
# Energy inputs with a CGE product. The others keep their data price.
const linked_es_e_d = Set((es,e,d) for (es,e,d) in energy_es_e_d if haskey(linked_product, e))

# CGE industries with energy services, and the services of each.
const linked_cge_industry = sort(unique(linked_industry[d] for (_,d) in service_es_d))
services_of(i) = [(es,d) for (es,d) in service_es_d if linked_industry[d] == i]

# ============================================================================
# Variables
# ============================================================================
const EnergyTechnologyLinkTag = Tag(:EnergyTechnologyLink)

@variables model :: EnergyTechnologyLinkTag begin
  qES2qM_es_d[es=service, d=user, t=t; (es,d) in service_es_d] :: ForecastConstant,
    "Energy service demand per unit of energy input in the linked CGE industry."
  pEBase2pPurchaser_es_e_d[es=service, e=energy, d=user, t=t; (es,e,d) in linked_es_e_d] :: ForecastConstant,
    "Energy price before tax per unit of the CGE purchaser price of the linked product."
  pTK2pK_d[d=user, t=t] :: ForecastConstant, "Capital cost per unit of the CGE user cost of the linked capital type."
  rEnergyServiceShare_i[i=linked_cge_industry], "Share of the industry's energy price that follows the energy service price."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  for i in linked_cge_industry
    db[rEnergyServiceShare_i[i]] = energy_service_share[i]
  end
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  # CGE price of the energy input from product prices, as in Intermediates.
  product_price(i, t) = ∑(rIntermediateProductShare[p,:energy,i,t] * pPurchaserUse_p_u[p,i,t] for p in product)

  # Energy service price relative to the base year, weighted by base-year service cost.
  service_price_index(i, t) =
    ∑(vES_es_d[es,d,tBase] * pES_es_d[es,d,t] / pES_es_d[es,d,tBase] for (es,d) in services_of(i)) /
    ∑(vES_es_d[es,d,tBase] for (es,d) in services_of(i))

  return @block model begin
    qES_es_d[es=service, d=user, t=t1:T; (es,d) in service_es_d],
    qES_es_d[es,d,t] == qES2qM_es_d[es,d,t] * qM_m_i[:energy,linked_industry[d],t]

    pEBase_es_e_d[es=service, e=energy, d=user, t=t1:T; (es,e,d) in linked_es_e_d],
    pEBase_es_e_d[es,e,d,t] ==
      pEBase2pPurchaser_es_e_d[es,e,d,t] * pPurchaserUse_p_u[linked_product[e],linked_industry[d],t]

    pTK_d[d=user, t=t1:T],
    pTK_d[d,t] == pTK2pK_d[d,t] * pK_k_i[linked_capital,linked_industry[d],t]

    # Replaces the energy price in Intermediates. A share of it follows the energy service price,
    # scaled to the CGE price in the base year. The equation equals the original in the base year.
    pM_m_i[m=[:energy], i=linked_cge_industry, t=t1:T] :: Override,
    pM_m_i[m,i,t] ==
      (1 - rEnergyServiceShare_i[i]) * product_price(i, t)
      + rEnergyServiceShare_i[i] * product_price(i, tBase) * service_price_index(i, t)
      + ntM_m_i[m,i,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
# The data set the partial model's levels in the calibration year. The ratios then stay
# constant, so the linked variables grow with their CGE counterparts.
function define_calibration(base=define_equations())
  block = copy(base)
  @endo_exo_swap! block begin
    qES2qM_es_d[es=service, d=user, t=t1; (es,d) in service_es_d],
      qES_es_d[es=service, d=user, t=t1; (es,d) in service_es_d]
    pEBase2pPurchaser_es_e_d[es=service, e=energy, d=user, t=t1; (es,e,d) in linked_es_e_d],
      pEBase_es_e_d[es=service, e=energy, d=user, t=t1; (es,e,d) in linked_es_e_d]
    pTK2pK_d[d=user, t=t1], pTK_d[d=user, t=t1]
  end
  return block
end

end # module