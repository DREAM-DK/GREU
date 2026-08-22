# Define intermediate use, its product split, and production-tree links.
# Link industry input to purchaser use and normalize its calibration price.
# Exclude capital, labor, and CES nest equations.
module Intermediates

using SquareModels
import ..DataUtils: read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  industry,
  pPurchaserUse_p_u,
  qM_p_i
import ..InputOutputSettings: cell_tolerance, product
import ..Production: parent, pProd, qProd
import ..ProductionSettings: intermediate_type, production_data_dir, production_nesting
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const intermediate_product_split_file = joinpath(production_data_dir, "production_intermediate_product_split.csv")
const qM_p_m_i_data = read_cells(intermediate_product_split_file, "qM_p_m_i")

# ============================================================================
# Indices
# ============================================================================
const intermediate_product_m_i = Set(keys(qM_p_m_i_data))
const intermediate_m_i = Set((m, i) for (_,m,i) in intermediate_product_m_i)

# ============================================================================
# Variables
# ============================================================================
const IntermediatesTag = Tag(:Intermediates)

@variables db.model :: (IntermediatesTag, GrowthAdjusted) begin
  qM_m_i[m=intermediate_type, i=industry, t=t; (m, i) in intermediate_m_i], "Intermediate input by type and industry."
  qM_p_m_i[p=product, m=intermediate_type, i=industry, t=t; (p, m, i) in intermediate_product_m_i], "Intermediate input by product, type, and industry."
end

@variables db.model :: (IntermediatesTag, InflationAdjusted) begin
  pM_m_i[(m,i,t) = qM_m_i], "Intermediate input price by type and industry."
end

@variables db.model :: IntermediatesTag begin
  rIntermediateProductShare[(p,m,i,t)=qM_p_m_i] :: ForecastConstant, "Fixed product share by intermediate type and industry."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  @assert intermediate_m_i == Set((m, i) for m in intermediate_type, i in industry if haskey(parent, (m, i)) && !haskey(production_nesting[i], m)) "Intermediate data and the industry nest maps must agree"
  @assert Set(m for (_,m,_) in intermediate_product_m_i) == Set(intermediate_type) "Each intermediate type needs product data"
  qM_m_i_data = Dict((m,i) => sum(value for ((_,mm,ii), value) in qM_p_m_i_data if mm == m && ii == i) for (m,i) in intermediate_m_i)
  @assert all(>(cell_tolerance), values(qM_m_i_data)) "Each intermediate type needs positive use"
  db[qM_m_i] .= [
    year == t1 ? qM_m_i_data[m, i] : nothing
    for (m, i, year) in keys(qM_m_i)
  ]
  db[qM_p_m_i] .= [
    year == t1 ? qM_p_m_i_data[p, m, i] : nothing
    for (p, m, i, year) in keys(qM_p_m_i)
  ]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block db begin
    qM_m_i[m=intermediate_type, i=industry, t=t1:T],
    qM_m_i[m,i,t] == qProd[m,i,t] / pM_m_i[m,i,t1]

    qM_p_m_i[p=product, m=intermediate_type, i=industry, t=t1:T],
    qM_p_m_i[p,m,i,t] == rIntermediateProductShare[p,m,i,t] * qM_m_i[m,i,t]

    qM_p_i[(p,i,t) in keys(qM_p_i); t in t1:T], qM_p_i[p,i,t] == ∑(qM_p_m_i[p,m,i,t] for m in intermediate_type)

    pM_m_i[m=intermediate_type, i=industry, t=t1:T],
    pM_m_i[m,i,t] == ∑(rIntermediateProductShare[p,m,i,t] * pPurchaserUse_p_u[p,i,t] for p in product)

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
    qProd[m=intermediate_type, i=industry, t=t1], qM_m_i[m=intermediate_type, i=industry, t=t1]
    rIntermediateProductShare[p=product, m=intermediate_type, i=industry, t=t1], qM_p_m_i[p=product, m=intermediate_type, i=industry, t=t1]
  end

  return block
end
end # module
