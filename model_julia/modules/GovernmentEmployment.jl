# Hold government employment at a fixed share of the labor force.
# Government consumption then follows, through the fG hook in InputOutput.
# The sector employment identity stays in IndustrySectors.

module GovernmentEmployment

using SquareModels
import ..IndustrySectors: qL_s
import ..InputOutput: fG
import ..Labor: qLSupplyHh, qLSupplyRoW
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const GovernmentEmploymentTag = Tag(:GovernmentEmployment)

@variables model :: (GovernmentEmploymentTag, ForecastConstant) begin
  rLGov[t], "Government share of the labor force."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Government employment sets the scale of government consumption.
    fG[t=t1:T], qL_s[:Gov,t] == rLGov[t] * (qLSupplyHh[t] + qLSupplyRoW[t])
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # The share is what the calibration year reports. The scale factor starts at one.
  @endo_exo_swap! block begin
    rLGov[t1], fG[t1]
  end

  return block
end

end # module
