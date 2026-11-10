# Define structural labor supply and a forward-looking wage Phillips curve.
# Set household employment from its effect on wage growth.
# Exclude participation, unemployment benefits, and product prices.
module PhillipsCurve

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..Labor: vW_l, nLSupplyHh_l, nLSupplyRoW_l
import ..ProductionSettings: labor_type
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const PhillipsCurveTag = Tag(:PhillipsCurve)

@variables model :: PhillipsCurveTag begin
  rWInflation[l=labor_type, t=t], "Nominal wage inflation."
  rLEmploymentGap[l=labor_type, t=t], "Employment gap relative to structural labor supply."
  uPhillipsCurveEmployment[l=labor_type, t=t] :: ForecastConstant, "Response of wage inflation to the employment gap."
  uPhillipsCurveExpectedInflation, "Weight on the expected wage inflation change."
end

@variables model :: (PhillipsCurveTag, ForecastConstant) begin
  snLSupplyHh[l=labor_type, t=t], "Structural household persons."
  snLSupplyRoW[l=labor_type, t=t], "Structural rest-of-world persons."
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
    rLEmploymentGap[l=labor_type, t=t1:T],
    1 + rLEmploymentGap[l,t] ==
      (nLSupplyHh_l[l,t] + nLSupplyRoW_l[l,t]) / (snLSupplyHh[l,t] + snLSupplyRoW[l,t])

    # The wage is growth and inflation adjusted, so a constant vW is wage growth at trend.
    rWInflation[l=labor_type, t=t1:T], 1 + rWInflation[l,t] == vW_l[l,t] / vW_l[l,t-1] * fv

    # Current wage inflation depends on its lag, the employment gap, and the
    # expected change from lagged to future wage inflation.
    nLSupplyHh_l[l=labor_type, t=(t1+1):(T-1)],
    rWInflation[l,t] == rWInflation[l,t-1]
      + uPhillipsCurveEmployment[l,t] * rLEmploymentGap[l,t]
      + uPhillipsCurveExpectedInflation * (rWInflation[l,t+1] - rWInflation[l,t-1])

    # The terminal equation drops the expected future change.
    nLSupplyHh_l[l=labor_type, t=T; T > t1],
    rWInflation[l,t] == rWInflation[l,t-1] + uPhillipsCurveEmployment[l,t] * rLEmploymentGap[l,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  return copy(base) + @block model begin
    snLSupplyHh[l=labor_type, t=t1], snLSupplyHh[l,t1] == nLSupplyHh_l[l,t1]
    snLSupplyRoW[l=labor_type, t=t1], snLSupplyRoW[l,t1] == nLSupplyRoW_l[l,t1]
  end
end

end # module