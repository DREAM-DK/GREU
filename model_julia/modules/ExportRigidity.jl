# Smooth the relative price signal in direct export demand.
# Use one price-adjustment rule with an optional future-price derivative.
# Fill the zero hook in Exports and leave re-exports and tourists unchanged.
module ExportRigidity

using SquareModels
import ..Exports:
  export_product,
  jXrigidity,
  pXForeign_p
import ..InputOutput:
  domestic,
  pPurchaserUse_p_u_o
import ..model
import ..Tags: DynamicCalibration
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================
const ExportRigidityTag = Tag(:ExportRigidity)

@variables model :: ExportRigidityTag begin
  rXEffectivePrice_p[p=export_product, t=t] :: DynamicCalibration, "Effective domestic export price relative to the foreign price."
  uXrigidity, "Weight on changes in the effective relative export price."
  βXrigidity, "Discount factor for the future export-price adjustment."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[uXrigidity] = 20.0
  db[βXrigidity] = 1/1.15

  # Lagged price ratio enters the equation for the first period.
  # Start calibration with no gap between the effective and spot price.
  db[rXEffectivePrice_p] .= 1
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  pX_p = pPurchaserUse_p_u_o[:,:X,domestic,:]

  return @block model begin
    rXEffectivePrice_p[p=export_product, t=t1:T],
    rXEffectivePrice_p[p,t] * pXForeign_p[p,t] == pX_p[p,t] + jXrigidity[p,t]

    # The first term is the gap between the effective and spot relative price.
    # The last term is the derivative of next year's adjustment cost. The
    jXrigidity[p=export_product, t=t1:(T-1); T > t1],
    jXrigidity[p,t] / pXForeign_p[p,t] ==
      - uXrigidity * (rXEffectivePrice_p[p,t] - rXEffectivePrice_p[p,t-1])
      + uXrigidity * βXrigidity * (rXEffectivePrice_p[p,t+1] - rXEffectivePrice_p[p,t])

    # After T, the effective relative price stays constant. The future
    # adjustment-cost derivative is then zero in both versions.
    jXrigidity[p=export_product, t=T],
    jXrigidity[p,t] / pXForeign_p[p,t] ==
      - uXrigidity * (rXEffectivePrice_p[p,t] - rXEffectivePrice_p[p,t-1])
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations()
end

end # module
