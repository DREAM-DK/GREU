# Define structural labor supply and a forward-looking wage Phillips curve.
# Set household employment from its effect on wage growth.
# Exclude participation, unemployment benefits, and product prices.
module PhillipsCurve

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..Labor: vW, nLSupplyHh, nLSupplyRoW
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const PhillipsCurveTag = Tag(:PhillipsCurve)

@variables model :: PhillipsCurveTag begin
  rWInflation[t], "Nominal wage inflation."
  rLEmploymentGap[t], "Employment gap relative to structural labor supply."
  uPhillipsCurveEmployment[t] :: ForecastConstant, "Response of wage inflation to the employment gap."
  uPhillipsCurveExpectedInflation, "Weight on the expected wage inflation change."
end

@variables model :: (PhillipsCurveTag, ForecastConstant) begin
  snLSupplyHh[t], "Structural household persons."
  snLSupplyRoW[t], "Structural rest-of-world persons."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[uPhillipsCurveEmployment] .= 5.0
  db[uPhillipsCurveExpectedInflation] = 0.30
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[rLEmploymentGap] .= 0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Rest-of-world employment stays exogenous for now.
    rLEmploymentGap[t=t1:T],
    1 + rLEmploymentGap[t] ==
      (nLSupplyHh[t] + nLSupplyRoW[t]) / (snLSupplyHh[t] + snLSupplyRoW[t])

    # The wage is growth and inflation adjusted, so a constant vW is wage growth at trend.
    rWInflation[t=t1:T], 1 + rWInflation[t] == vW[t] / vW[t-1] * fv

    # Current wage inflation depends on its lag, the employment gap, and the
    # expected change from lagged to future wage inflation.
    nLSupplyHh[t=(t1+1):(T-1)],
    rWInflation[t] == rWInflation[t-1]
      + uPhillipsCurveEmployment[t] * rLEmploymentGap[t]
      + uPhillipsCurveExpectedInflation * (rWInflation[t+1] - rWInflation[t-1])

    # The terminal equation drops the expected future change.
    nLSupplyHh[t=T; T > t1],
    rWInflation[t] == rWInflation[t-1] + uPhillipsCurveEmployment[t] * rLEmploymentGap[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations() + @block model begin
    snLSupplyHh[t1], snLSupplyHh[t1] == nLSupplyHh[t1]
    snLSupplyRoW[t1], snLSupplyRoW[t1] == nLSupplyRoW[t1]
  end
end

end # module
