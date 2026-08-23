# Add CES choice between domestic and imported products.
# Use purchaser prices and keep the input-output accounts unchanged.
# Exclude inventories, re-exports, and cells with only one origin.
module ImportSubstitution

using SquareModels
import ..InputOutput:
  ordinary_uses,
  origin,
  pPurchaserUse_p_u,
  pPurchaserUse_p_u_o,
  purchaser_use_p_u,
  purchaser_use_p_u_o,
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
const import_p_u = Set(
  (p, u)
  for (p, u) in purchaser_use_p_u
  if u in import_use && all((p, u, o) in purchaser_use_p_u_o for o in origin)
)
const import_product = [p for p in product if any((p, u) in import_p_u for u in import_use)]

# ============================================================================
# Variables
# ============================================================================
const ImportSubstitutionTag = Tag(:ImportSubstitution)

@variables model :: ImportSubstitutionTag begin
  uImport_p_u_o[p=product, u=import_use, o=origin, t=t; (p,u) in import_p_u] :: ForecastConstant, "CES weight by product, use, and origin."
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
    rOriginShare[p=product, u=import_use, o=origin, t=t1:T; (p,u) in import_p_u],
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
    rOriginShare[p=product, u=import_use, o=origin, t=t1; (p,u) in import_p_u]
  end

  return block
end

end # module
