# Set total household consumption from income, wealth, and an external habit.
# Use the household accounts for the budget and financial asset changes.
# Exclude the split of consumption across groups and products.

module ConsumptionSavingsDecision

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fq
import ..InputOutput: pC, qC, qC_p, qCTourist
import ..Labor: vHhWages
import ..model
import ..SectorAccounts:
  vCorrectionNonFinCorp2Hh,
  vGrossCapitalFormation,
  vNetFinAssets,
  vNetFinIncome,
  vNetTransfers2sector,
  vNonFinancialNonProducedAssets
import ..Tags: DynamicCalibration, ForecastConstant
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================

const ConsumptionSavingsDecisionTag = Tag(:ConsumptionSavingsDecision)

@variables model :: (ConsumptionSavingsDecisionTag, GrowthAdjusted, InflationAdjusted) begin
  vHhResources[t], "Household resources before consumption and net financial transactions."
end

@variables model :: (ConsumptionSavingsDecisionTag, GrowthAdjusted) begin
  qHhRealIncome[t], "Real household resources before consumption."
  qHhWealth[t], "End-of-period real household net financial assets."
  qHhHandToMouthConsumption[t], "Consumption set as a fixed share of current real income."
  qHhExternalHabit[t], "External habit set from prior total consumption."
  qHhExcessReferenceConsumption[t], "Consumption above the hand-to-mouth amount and external habit."
end

@variables model :: ConsumptionSavingsDecisionTag begin
  dHhUtility2dConsumption[t], "Marginal utility of consumption above the reference level."
  dHhUtility2dWealth[t], "Marginal utility of end-of-period real wealth."

  rHhHandToMouth[t] :: ForecastConstant, "Share of current real income consumed under the hand-to-mouth rule."
  fHhExternalHabit[t] :: ForecastConstant, "External habit relative to prior total consumption."
  rHhRequiredReturn[t] :: ForecastConstant, "Exogenous real return used by the household saving choice."
  βHh, "Household discount factor."
  eHhConsumption, "Curvature of utility from consumption above the reference level."
  eHhWealth, "Curvature of utility from real wealth."
  fHhWealthPreference :: DynamicCalibration, "Preference weight on end-of-period real wealth."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  db[rHhHandToMouth] .= 0.10
  db[fHhExternalHabit] .= 0.50
  db[rHhRequiredReturn] .= 0.02
  db[βHh] = 0.96
  db[eHhConsumption] = 2.0
  db[eHhWealth] = 2.0

  db[qC[t1-1]] =
    sum(db[qC_p[p,year]] for (p, year) in keys(qC_p) if year == t1-1) - db[qCTourist[t1-1]]

  @assert 0 <= db[rHhHandToMouth[t1]] <= 1 "The hand-to-mouth income share must be in [0, 1]"
  @assert 0 <= db[fHhExternalHabit[t1]] < 1 "The external habit factor must be in [0, 1)"
  @assert 0 < db[βHh] < 1 "The household discount factor must be in (0, 1)"
  @assert db[eHhConsumption] > 0 "Consumption utility curvature must be positive"
  @assert db[eHhWealth] > 0 "Wealth utility curvature must be positive"
  @assert db[rHhRequiredReturn[t1]] > -1 "The real required return must be greater than -1"
  @assert db[βHh] * (1 + db[rHhRequiredReturn[t1]]) < 1 "The terminal continuation value must be finite"
  @assert db[qC[t1-1]] > 0 "Prior total consumption must be positive"
  @assert db[vNetFinAssets[:Hh,t1]] > 0 "Source household net financial assets must be positive"
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================

function set_starting_values!(start_values)
  source_consumption = something(start_values[qC[t1]], start_values[qC[t1-1]])
  source_price = something(start_values[pC[t1]], 1.0)
  @assert source_price > 0 "The initial consumption price must be positive"
  source_wealth = start_values[vNetFinAssets[:Hh,t1]] / source_price
  start_values[qC[t1:T]] .= source_consumption
  start_values[vHhResources[t1:T]] .= source_price * source_consumption
  start_values[qHhRealIncome[t1:T]] .= source_consumption
  start_values[qHhWealth[t1:T]] .= source_wealth
  start_values[qHhHandToMouthConsumption[t1:T]] .= start_values[rHhHandToMouth[t1]] * source_consumption
  start_values[qHhExternalHabit[t1:T]] .= start_values[fHhExternalHabit[t1]] * start_values[qC[t1-1]]/fq
  start_values[qHhExcessReferenceConsumption[t1:T]] .=
    source_consumption .- start_values[qHhHandToMouthConsumption[t1:T]] .- start_values[qHhExternalHabit[t1:T]]
  @assert all(
    start_values[qHhExcessReferenceConsumption[t1:T]] .> 0
  ) "Initial excess-reference consumption must be positive"
  start_values[dHhUtility2dConsumption[t1:T]] .=
    start_values[qHhExcessReferenceConsumption[t1:T]] .^ (-start_values[eHhConsumption])
  start_values[fHhWealthPreference] =
    (1 - start_values[βHh] * (1 + start_values[rHhRequiredReturn[t1]])) *
    start_values[dHhUtility2dConsumption[t1]] * source_wealth^start_values[eHhWealth]
  start_values[dHhUtility2dWealth[t1:T]] .=
    start_values[fHhWealthPreference] * source_wealth^(-start_values[eHhWealth])
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    # These resources match the household budget just before private consumption.
    vHhResources[t=t1:T],
    vHhResources[t] == vNetFinIncome[:Hh,t]
                       + vNetTransfers2sector[:Hh,t]
                       + vHhWages[t]
                       + vCorrectionNonFinCorp2Hh[t]
                       - vGrossCapitalFormation[:Hh,t]
                       - vNonFinancialNonProducedAssets[:Hh,t]

    qHhRealIncome[t=t1:T], pC[t] * qHhRealIncome[t] == vHhResources[t]
    qHhWealth[t=t1:T], pC[t] * qHhWealth[t] == vNetFinAssets[:Hh,t]

    qHhHandToMouthConsumption[t=t1:T],
    qHhHandToMouthConsumption[t] == rHhHandToMouth[t] * qHhRealIncome[t]

    qHhExternalHabit[t=t1:T],
    qHhExternalHabit[t] == fHhExternalHabit[t] * qC[t-1]/fq

    qHhExcessReferenceConsumption[t=t1:T],
    qHhExcessReferenceConsumption[t] == qC[t]
                                               - qHhExternalHabit[t]
                                               - qHhHandToMouthConsumption[t]

    dHhUtility2dConsumption[t=t1:T],
    dHhUtility2dConsumption[t] * qHhExcessReferenceConsumption[t]^eHhConsumption == 1

    dHhUtility2dWealth[t=t1:T],
    dHhUtility2dWealth[t] * qHhWealth[t]^eHhWealth == fHhWealthPreference

    # The required return is an exogenous hook. A later return module can set it.
    qC[t=t1:(T-1); T > t1],
    1 == (
      dHhUtility2dWealth[t] / dHhUtility2dConsumption[t]
      + βHh * (1 + rHhRequiredReturn[t+1]) *
        dHhUtility2dConsumption[t+1] / dHhUtility2dConsumption[t]
    )

    # Terminal marginal utility stays constant after T. The terminal return also stays constant.
    qC[t=[T]],
    1 == (
      dHhUtility2dWealth[t] / dHhUtility2dConsumption[t]
      + βHh * (1 + rHhRequiredReturn[t])
    )

    # Post-solve bounds.
    @test_constraint("Real household income must be positive")
    qHhRealIncome[t=t1:T], qHhRealIncome[t] >= 1e-12

    @test_constraint("Real household wealth must be positive")
    qHhWealth[t=t1:T], qHhWealth[t] >= 1e-12

    @test_constraint("Consumption above the reference level must be positive")
    qHhExcessReferenceConsumption[t=t1:T], qHhExcessReferenceConsumption[t] >= 1e-12

    @test_constraint("The wealth preference must be positive")
    fHhWealthPreference, fHhWealthPreference >= 1e-12
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  # Source total consumption identifies the wealth preference in each calibration solve.
  @endo_exo_swap! block begin
    fHhWealthPreference, qC[t1]
  end

  return block
end

end # module
