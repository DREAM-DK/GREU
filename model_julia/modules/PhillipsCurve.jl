# Define structural labor supply and a forward-looking wage Phillips curve.
# Set household employment from its effect on wage growth.
# Exclude participation, unemployment benefits, and product prices.
module PhillipsCurve

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
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
  uPhillipsCurveEmployment[t] :: ForecastConstant, "Response of wage growth to the employment gap."
  uPhillipsCurveExpectedWage, "Weight on expected wage growth relative to the structural wage."
end

@variables model :: (PhillipsCurveTag, ForecastConstant) begin
  snLSupplyHh[t], "Structural household persons."
  snLSupplyRoW[t], "Structural rest-of-world persons."
end

# Constant in the baseline (wage growth at trend). Shock it to move the normal wage path.
@variables model :: (PhillipsCurveTag, GrowthAdjusted, InflationAdjusted, ForecastConstant) begin
  vWStructural[t], "Structural wage per person."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[uPhillipsCurveEmployment] .= 5.0
  db[uPhillipsCurveExpectedWage] = 0.96
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

    # Wage growth relative to the structural wage depends on expected wage growth
    # relative to the structural wage next year and on the employment gap.
    nLSupplyHh[t=(t1+1):(T-1)],
    (vW[t] / vW[t-1]) / (vWStructural[t] / vWStructural[t-1]) ==
      ((vW[t+1] / vW[t]) / (vWStructural[t+1] / vWStructural[t]))^uPhillipsCurveExpectedWage *
      exp(uPhillipsCurveEmployment[t] * rLEmploymentGap[t])

    # The terminal year expects wage growth at the structural rate.
    nLSupplyHh[t=T; T > t1],
    (vW[t] / vW[t-1]) / (vWStructural[t] / vWStructural[t-1]) == exp(uPhillipsCurveEmployment[t] * rLEmploymentGap[t])
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  return copy(base) + @block model begin
    snLSupplyHh[t1], snLSupplyHh[t1] == nLSupplyHh[t1]
    snLSupplyRoW[t1], snLSupplyRoW[t1] == nLSupplyRoW[t1]
    vWStructural[t1], vWStructural[t1] == vW[t1]
  end
end

end # module