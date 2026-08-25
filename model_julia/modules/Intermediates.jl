# Define intermediate use, its product split, and production-tree links.
# Link industry input to purchaser use and normalize its calibration price.
# Exclude capital, labor, and CES nest equations.
module Intermediates

using SquareModels
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  industry,
  pPurchaserUse_p_u,
  qM_p_i
import ..InputOutputSettings: product
import ..Production: parent, pProd, qProd
import ..ProductionSettings: intermediate_type, production_data_dir, production_nesting
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const intermediate_product_split_file = joinpath(production_data_dir, "production_intermediate_product_split.csv")
const qM_p_m_i_data = read_cells(intermediate_product_split_file, "qM_p_m_i")
const qM_m_i_data = read_cells(intermediate_product_split_file, "qM_m_i")

# ============================================================================
# Indices
# ============================================================================
const intermediate_product_m_i = Set((p, m, i) for (p, m, i, _) in keys(qM_p_m_i_data))
const intermediate_m_i = Set((m, i) for (_, m, i) in intermediate_product_m_i)
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
  pM_m_i[(m,i,t)=qM_m_i], "Intermediate input price by type and industry."
end

@variables model :: (IntermediatesTag, GrowthAdjusted, InflationAdjusted) begin
  vM_i[i=industry, t=t], "Intermediate input spend by industry."
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

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[qProd[intermediate_type,:,:]] .= start_values[qM_m_i][intermediate_type,:,:]
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

    qM_p_i[(p,i,t) in keys(qM_p_i); t in t1:T], qM_p_i[p,i,t] == ∑(qM_p_m_i[p,m,i,t] for m in intermediate_type)

    pM_m_i[m=intermediate_type, i=industry, t=t1:T],
    pM_m_i[m,i,t] == ∑(rIntermediateProductShare[p,m,i,t] * pPurchaserUse_p_u[p,i,t] for p in product)

    vM_i[i=industry, t=t1:T], vM_i[i,t] == ∑(pM_m_i[m,i,t] * qM_m_i[m,i,t] for m in intermediate_type)

    pProd[m=intermediate_type, i=industry, t=t1:T], pProd[m,i,t] == pM_m_i[m,i,t] / pM_m_i[m,i,t1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    qProd[m=intermediate_type, i=industry, t=t1], qM_m_i[m=intermediate_type, i=industry, t=t1]
    rIntermediateProductShare[p=product, m=intermediate_type, i=industry, t=t1], qM_p_m_i[p=product, m=intermediate_type, i=industry, t=t1]
  end

  return block
end
end # module
