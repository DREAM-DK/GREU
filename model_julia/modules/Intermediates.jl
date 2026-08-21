# Define intermediate use, its product split, and production-tree links.
# Link industry input to purchaser use and normalize its calibration price.
# Exclude capital, labor, and CES nest equations.
module Intermediates

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput:
  industry,
  pPurchaserUse_p_u,
  qPurchaserUse_p_u,
  qPurchaserUse_p_u_o_data,
  qPurchaserUse_u,
  rProductShare
import ..InputOutputSettings: cell_tolerance, origin, product
import ..Production: parent, pProd, qProd
import ..ProductionSettings: intermediate_product_type_weight, intermediate_type, production_nesting
import ..Settings: calibration_year
import ..db
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Cell masks and product split
# ============================================================================
const intermediate_industry = sort([
  i for (i, year) in keys(qPurchaserUse_u)
  if year == t1 && i in industry
])
const intermediate_m_i = Set(
  (m, i) for m in intermediate_type, i in intermediate_industry
)

const intermediate_product_i = Set(
  (p, u)
  for (p, u, year) in keys(qPurchaserUse_p_u)
  if year == t1 && u in intermediate_industry
)
const qIntermediate_p_i = Dict(
  (p, i) => sum(get(qPurchaserUse_p_u_o_data, (p, i, o, calibration_year), 0.0) for o in origin)
  for (p, i) in intermediate_product_i
)
const qIntermediate_m_i = Dict(
  (m, i) => sum(
    intermediate_product_type_weight[p, m] * qIntermediate_p_i[p, i]
    for (p, ii) in intermediate_product_i if ii == i
  )
  for (m, i) in intermediate_m_i
)
@assert all(>(cell_tolerance), values(qIntermediate_m_i)) "Each intermediate type needs positive use"
const qIntermediate_p_m_i = Dict(
  (p, m, i) => qIntermediate_p_i[p, i] *
    intermediate_product_type_weight[p, m] * qIntermediate_m_i[m, i] /
    sum(
      intermediate_product_type_weight[p, mm] * qIntermediate_m_i[mm, i]
      for mm in intermediate_type
    )
  for (p, i) in intermediate_product_i, m in intermediate_type
  if intermediate_product_type_weight[p, m] > 0
)
const intermediate_product_m_i = Set(keys(qIntermediate_p_m_i))
const rIntermediateProductShare_data = Dict(
  (p, m, i) => value / sum(v for ((_, mm, ii), v) in qIntermediate_p_m_i if mm == m && ii == i)
  for ((p, m, i), value) in qIntermediate_p_m_i
)

# ============================================================================
# Variables
# ============================================================================
const IntermediatesTag = Tag(:Intermediates)

@variables db.model :: (IntermediatesTag, GrowthAdjusted) begin
  qM_m_i[m = intermediate_type, i = intermediate_industry, t = t; (m, i) in intermediate_m_i], "Intermediate input by type and industry."
  qM_p_m_i[p = product, m = intermediate_type, i = intermediate_industry, t = t; (p, m, i) in intermediate_product_m_i], "Intermediate input by product, type, and industry."
end

@variables db.model :: (IntermediatesTag, InflationAdjusted) begin
  pM_m_i[(m, i, t) = qM_m_i], "Intermediate input price by type and industry."
end

@variables db.model :: IntermediatesTag begin
  rIntermediateProductShare[(p, m, i, t) = qM_p_m_i] :: ForecastConstant, "Fixed product share by intermediate type and industry."
end

# ============================================================================
# Data
# ============================================================================
function set_data!(db)
  @assert intermediate_m_i == Set(
    (m, i)
    for m in intermediate_type, i in industry
    if haskey(parent, (m, i)) && !haskey(production_nesting[i], m)
  ) "Intermediate data and the industry nest maps must agree"
  @assert all((i, t1) in keys(qPurchaserUse_u) for i in intermediate_industry) "Each intermediate leaf needs purchaser use"

  db[qM_m_i] .= [
    year == t1 ? qIntermediate_m_i[m, i] : nothing
    for (m, i, year) in keys(qM_m_i)
  ]
  db[rIntermediateProductShare] .= [
    year == t1 ? rIntermediateProductShare_data[p, m, i] : nothing
    for (p, m, i, year) in keys(rIntermediateProductShare)
  ]
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
define_equations() = define_equations(t1:T)

function define_equations(product_link_years)
  return @block db begin
    qM_m_i[(m, i, t) in keys(qM_m_i); t in t1:T],
    qM_m_i[m, i, t] == qProd[m, i, t] / pM_m_i[m, i, t1]

    qM_p_m_i[(p, m, i, t) in keys(qM_p_m_i); t in t1:T],
    qM_p_m_i[p, m, i, t] == rIntermediateProductShare[p, m, i, t] * qM_m_i[m, i, t]

    rProductShare[(p, u, t) in keys(rProductShare); u in intermediate_industry && t in product_link_years],
    qPurchaserUse_p_u[p, u, t] ==
      ∑(qM_p_m_i[p, m, u, t] for m in intermediate_type)

    qPurchaserUse_u[i = intermediate_industry, t = product_link_years],
    qPurchaserUse_u[i, t] == ∑(qM_m_i[m, i, t] for m in intermediate_type)

    pM_m_i[(m, i, t) in keys(pM_m_i); t in t1:T],
    pM_m_i[m, i, t] ==
      ∑(
        rIntermediateProductShare[p, m, i, t] * pPurchaserUse_p_u[p, i, t]
        for p in product
      )

    pProd[m = intermediate_type, i = intermediate_industry, t = t1:T; (m, i) in intermediate_m_i],
    pProd[m, i, t] == pM_m_i[m, i, t] / pM_m_i[m, i, t1]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  # InputOutput calibrates the base-year product cells and use total.
  block = define_equations((t1+1):T)

  @endo_exo_swap! block begin
    qProd[(m, i, t) in keys(qM_m_i); t == t1], qM_m_i[(m, i, t) in keys(qM_m_i); t == t1]
  end

  return block
end
end # module
