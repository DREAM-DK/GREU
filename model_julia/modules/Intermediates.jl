# Define intermediate use, its product split, and production-tree links.
# Add production tax to the user cost and normalize its calibration price.
# Keep intermediate input spend before production tax for the accounts.
# Exclude capital, labor, and CES nest equations.
module Intermediates

using SquareModels
import ..DataUtils: fill_cells!
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, adjustment_factor
import ..InputOutput:
  industry,
  pPurchaserUse_p_u,
  qM_p_i,
  vPurchaserUse_p_u
import ..InputOutputSettings: product
import ..Production:
  parent, pProd, qProd, production_nesting,
  qM_p_m_i_data, qM_m_i_data, intermediate_product_m_i, intermediate_m_i
import ..ProductionSettings: intermediate_type
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Indices
# ============================================================================
@assert intermediate_m_i == Set(
  (m, i)
  for m in intermediate_type, i in industry
  if haskey(parent, (m, i)) && !haskey(production_nesting[i], m)
) "Intermediate data and the industry nest maps must agree"

# ============================================================================
# Variables
# ============================================================================
const IntermediatesTag = Tag(:Intermediates)

@variables model :: (IntermediatesTag, GrowthAdjusted) begin
  qM_m_i[m=intermediate_type, i=industry, t=t; (m,i) in intermediate_m_i], "Intermediate input by type and industry."
  qM_p_m_i[p=product, m=intermediate_type, i=industry, t=t; (p,m,i) in intermediate_product_m_i], "Intermediate input by product, type, and industry."
end

@variables model :: (IntermediatesTag, InflationAdjusted) begin
  pM_m_i[(m,i,t)=qM_m_i], "User cost of intermediate input by type and industry."
  ntM_m_i[(m,i,t)=qM_m_i] :: ForecastConstant, "Production tax less subsidy per unit of intermediate input."
end

@variables model :: (IntermediatesTag, GrowthAdjusted, InflationAdjusted) begin
  vM_i[i=industry, t=t], "Intermediate input spend before production tax by industry."
end

@variables model :: IntermediatesTag begin
  rIntermediateProductShare[(p,m,i,t)=qM_p_m_i] :: ForecastConstant, "Fixed product share by intermediate type and industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, qM_m_i, qM_m_i_data)
  fill_cells!(db, qM_p_m_i, qM_p_m_i_data)
  return nothing
end

# Base-year IO data retain inputs that the forecast production tree omits.
function set_residual_tolerances!(tolerances, rtolerances)
  for (p,i) in keys(qM_p_i[:,:,t1])
    (p,i,t1+1) in keys(qM_p_i) && continue
    tolerances[qM_p_i[p,i,t1]] = abs(sum(
      get(qM_p_m_i_data, (p,m,i,t1), 0.0) for m in intermediate_type
    )) / adjustment_factor(qM_p_i[p,i,t1], t1) + 1e-6
  end
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[qProd[intermediate_type,:,:]] .= start_values[qM_m_i][intermediate_type,:,:]
  start_values[ntM_m_i] .= 0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    qM_m_i[m=intermediate_type, i=industry, t=t1:T], qM_m_i[m,i,t] == qProd[m,i,t] / pM_m_i[m,i,t1]

    qM_p_m_i[p=product, m=intermediate_type, i=industry, t=t1:T],
    qM_p_m_i[p,m,i,t] == rIntermediateProductShare[p,m,i,t] * qM_m_i[m,i,t]

    qM_p_i[p=product, i=industry, t=t1:T], qM_p_i[p,i,t] == ∑(qM_p_m_i[p,m,i,t] for m in intermediate_type)

    pM_m_i[m=intermediate_type, i=industry, t=t1:T],
    pM_m_i[m,i,t] ==
      ∑(rIntermediateProductShare[p,m,i,t] * pPurchaserUse_p_u[p,i,t] for p in product) + ntM_m_i[m,i,t]

    # IO accounts include base-year inputs that the forecast production tree omits.
    vM_i[i=industry, t=t1:T],
    vM_i[i,t] == ∑(vPurchaserUse_p_u[p,i,t] for p in product)

    pProd[m=intermediate_type, i=industry, t=t1:T],
    pProd[m,i,t] == pM_m_i[m,i,t] / pM_m_i[m,i,t1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qProd[intermediate_type,:,t1], qM_m_i[:,:,t1]
    rIntermediateProductShare[:,:,:,t1], qM_p_m_i[:,:,:,t1]
  end

  return block
end
end # module
