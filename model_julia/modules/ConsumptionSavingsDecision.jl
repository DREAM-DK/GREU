# Set total household consumption from income, wealth, and an external habit.
# Use the household accounts for the budget and financial asset changes.
# Exclude the split of consumption across groups and products.

module ConsumptionSavingsDecision

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fp, fq
import ..Households: mHhReturn
import ..InputOutput: pC, qC, qC_p, qCTourist, vC
import ..Labor: vHhWages
import ..model
import ..SectorAccounts:
  vNetFinAssets,
  vNetFinTransactions,
  vNetTransfers,
  vPensionSaving
import ..Tags: DynamicCalibration, ForecastConstant
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================

const ConsumptionSavingsDecisionTag = Tag(:ConsumptionSavingsDecision)

@variables model :: (ConsumptionSavingsDecisionTag, GrowthAdjusted, InflationAdjusted) begin
  vHtMIncome[t], "Household wage and net transfer income used in the hand-to-mouth rule."
end

@variables model :: (ConsumptionSavingsDecisionTag, GrowthAdjusted) begin
  qHhWealth[t], "End-of-period real household net financial assets."
  qCxRef[t], "Consumption above the hand-to-mouth amount and external habit."
end

@variables model :: ConsumptionSavingsDecisionTag begin
  dU2dC[t], "Marginal utility of consumption above the reference level."
  dU2dWealth[t], "Marginal utility of end-of-period real wealth."

  rHtM[t] :: ForecastConstant, "Share of current real income consumed under the hand-to-mouth rule."
  rCHabits[t] :: ForecastConstant, "External habit relative to prior total consumption."
  βHh, "Household discount factor."
  eHhConsumption, "Curvature of utility from consumption above the reference level."
  eHhWealth, "Curvature of utility from real wealth."
  uHhWealthPreference :: DynamicCalibration, "Preference weight on end-of-period real wealth."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  db[rHtM] .= 0.10
  db[rCHabits] .= 0.50
  db[βHh] = 0.96
  db[eHhConsumption] = 1/0.8
  db[eHhWealth] = 1/0.8

  db[qC[t1-1]] =
    sum(db[qC_p[p,year]] for (p, year) in keys(qC_p) if year == t1-1) - db[qCTourist[t1-1]]

  @assert 0 <= db[rHtM[t1]] <= 1 "The hand-to-mouth income share must be in [0, 1]"
  @assert 0 <= db[rCHabits[t1]] < 1 "The external habit factor must be in [0, 1)"
  @assert 0 < db[βHh] < 1 "The household discount factor must be in (0, 1)"
  @assert db[eHhConsumption] > 0 "Consumption utility curvature must be positive"
  @assert db[eHhWealth] > 0 "Wealth utility curvature must be positive"
  @assert db[qC[t1-1]] > 0 "Prior total consumption must be positive"
  @assert db[vNetFinAssets[:Hh,t1]] > 0 "Source household net financial assets must be positive"
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
  return @block model begin
    qHhWealth[t=t1:T], pC[t] * qHhWealth[t] == vNetFinAssets[:Hh,t]

    vHtMIncome[t=t1:T], vHtMIncome[t] == vNetTransfers[:Hh,t] - vPensionSaving[:Hh,t] + vHhWages[t]

    qCxRef[t=t1:T],
    qCxRef[t] == qC[t] - rCHabits[t] * qC[t-1]/fq - rHtM[t] * vHtMIncome[t] / pC[t]

    dU2dC[t=t1:T], dU2dC[t] * qCxRef[t]^eHhConsumption == 1

    dU2dWealth[t=t1:T], dU2dWealth[t] * qHhWealth[t]^eHhWealth == uHhWealthPreference

    qC[t=t1:(T-1)], dU2dC[t] == dU2dWealth[t]
      + βHh * (1 + mHhReturn[t+1]) * pC[t] / (pC[t+1]*fp) * dU2dC[t+1]*fq^(-eHhConsumption)

    # After T, adjusted marginal utility, the return, and the adjusted price stay constant.
    qC[t=[T]], dU2dC[t] == dU2dWealth[t]
      + βHh * (1 + mHhReturn[t]) * pC[t] / (pC[t]*fp) * dU2dC[t]*fq^(-eHhConsumption)
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  # Source total consumption identifies the wealth preference in each calibration solve.
  @endo_exo_swap! block begin
    uHhWealthPreference, qC[t1]
  end

  return block
end

end # module
