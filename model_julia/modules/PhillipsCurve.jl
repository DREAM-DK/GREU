# Define structural labor supply and a forward-looking wage Phillips curve.
# Set household employment from its effect on wage growth.
# Exclude participation, unemployment benefits, and product prices.
module PhillipsCurve

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, fp, gp
import ..Labor: pW, qLSupplyHh, qLSupplyRoW
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

@variables model :: (PhillipsCurveTag, GrowthAdjusted, ForecastConstant) begin
  sqLSupplyHh[t], "Structural household employees."
  sqLSupplyRoW[t], "Structural rest-of-world employees."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[sqLSupplyHh[t1]] = db[qLSupplyHh[t1]]
  db[sqLSupplyRoW[t1]] = db[qLSupplyRoW[t1]]
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
      (qLSupplyHh[t] + qLSupplyRoW[t]) / (sqLSupplyHh[t] + sqLSupplyRoW[t])

    # The wage is inflation adjusted, so a constant pW is wage growth at trend.
    rWInflation[t=t1:T], 1 + rWInflation[t] == pW[t] / pW[t-1] * fp

    # Current wage inflation depends on its lag, the employment gap, and the
    # expected change from lagged to future wage inflation.
    qLSupplyHh[t=(t1+1):(T-1)],
    rWInflation[t] == rWInflation[t-1]
      + uPhillipsCurveEmployment[t] * rLEmploymentGap[t]
      + uPhillipsCurveExpectedInflation * (rWInflation[t+1] - rWInflation[t-1])

    # The terminal equation drops the expected future change.
    qLSupplyHh[t=T; T > t1],
    rWInflation[t] == rWInflation[t-1] + uPhillipsCurveEmployment[t] * rLEmploymentGap[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations()
end

end # module
