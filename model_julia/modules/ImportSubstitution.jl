# Add CES choice between domestic and imported products.
# Use purchaser prices and keep the input-output accounts unchanged.
# Exclude inventories, re-exports, and cells with only one base-year origin.
module ImportSubstitution

using SquareModels
import ..InputOutput:
  ordinary_uses,
  origin,
  pPurchaserUse_p_u,
  pPurchaserUse_p_u_o,
  purchaser_use_p_u_t,
  purchaser_use_p_u_o_t,
  qPurchaserUse_p_u,
  qPurchaserUse_p_u_o,
  rOriginShare
import ..InputOutputSettings: product
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Indices
# ============================================================================
const import_use = setdiff(ordinary_uses, [:X])
const import_p_u_t = Set(
  (p,u,year)
  for (p,u,year) in purchaser_use_p_u_t
  if u in import_use && all((p,u,o,t1) in purchaser_use_p_u_o_t for o in origin)
)
const import_product = sort(unique(p for (p,_,_) in import_p_u_t))

# ============================================================================
# Variables
# ============================================================================
const ImportSubstitutionTag = Tag(:ImportSubstitution)

@variables model :: ImportSubstitutionTag begin
  uImport_p_u_o[p=product, u=import_use, o=origin, t=t; (p,u,t) in import_p_u_t && (p,u,o,t) in purchaser_use_p_u_o_t] :: ForecastConstant, "CES weight by product, use, and origin."
  eImport_p[p=import_product], "Elasticity between domestic and imported products."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[eImport_p] .= 2.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    rOriginShare[(p,u,o,t) in keys(uImport_p_u_o); t in t1:T],
    qPurchaserUse_p_u_o[p,u,o,t] * pPurchaserUse_p_u_o[p,u,o,t]^eImport_p[p] ==
      uImport_p_u_o[p,u,o,t] * qPurchaserUse_p_u[p,u,t] * pPurchaserUse_p_u[p,u,t]^eImport_p[p]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    uImport_p_u_o[:,:,:,t1],
    rOriginShare[(p,u,o,t) in keys(uImport_p_u_o); t == t1]
  end

  return block
end

end # module
