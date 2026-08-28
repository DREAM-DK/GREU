# Define a forward-looking wage Phillips curve.
# Fill the labor slack hook of Labor, so employment can differ from labor supply.
# Exclude labor supply, participation, unemployment benefits, and product prices.
module PhillipsCurve

using SquareModels
import ..GrowthInflationAdjustment: fp, gp
import ..Labor: pW, qLSlack, qLSupplyHh, qLSupplyRoW
import ..model
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# The source data reports no unemployment, so the calibration year has no slack
# and the curve is neutral in the baseline. These assumptions set the speed of
# wage adjustment instead.
const wage_slack_response = 0.30
const expected_wage_weight = 0.90

# ============================================================================
# Variables
# ============================================================================
const PhillipsCurveTag = Tag(:PhillipsCurve)

@variables model :: PhillipsCurveTag begin
  rWInflation[t], "Nominal wage inflation."
  rLSlack[t], "Labor slack as a share of labor supply."
  fWPhillips[t] :: ForecastConstant, "Response of wage inflation to labor slack."
  βWPhillips, "Weight on expected wage inflation."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[fWPhillips] .= wage_slack_response
  db[βWPhillips] = expected_wage_weight

  @assert db[fWPhillips[t1]] > 0 
  @assert 0 <= db[βWPhillips] < 1 
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================
function set_starting_values!(start_values)
  start_values[rWInflation] .= gp
  start_values[rLSlack] .= 0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Slack as a share of labor supply. The source data reports employment as the
    # labor supply, so slack is zero in the calibration year.
    rLSlack[t=t1:T], rLSlack[t] * (qLSupplyHh[t] + qLSupplyRoW[t]) == qLSlack[t]

    # The wage is inflation adjusted, so a constant pW is wage growth at trend.
    rWInflation[t=t1:T], 1 + rWInflation[t] == pW[t] / pW[t-1] * fp

    # Wage inflation above trend needs expected wage inflation above trend or a
    # tight labor market. Slack holds wage growth below trend.
    qLSlack[t=(t1+1):(T-1)],
    rWInflation[t] - gp == βWPhillips * (rWInflation[t+1] - gp) - fWPhillips[t] * rLSlack[t]

    # After T, wage inflation and slack stay constant.
    qLSlack[t=T; T > t1],
    rWInflation[t] - gp == βWPhillips * (rWInflation[t] - gp) - fWPhillips[t] * rLSlack[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations()
end

end # module