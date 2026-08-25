# Link interest and dividend flows to financial stocks.
# Use fixed effective yields by sector, instrument, and side.
# Keep source gaps in calibration and close each forecast market.

module FinancialIncome

using SquareModels
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..model
import ..SectorAccounts:
  ass_liab,
  fin_instrument,
  sector,
  vFinAL,
  vFinIncome
import ..Tags: ForecastConstant, ForecastZero
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================

const fin_position_s_f_al = Set((s, f, al) for (s, f, al, _) in keys(vFinAL))
const income_rate_s_f_al = Set(
  (s, f, al)
  for (s, f, al) in fin_position_s_f_al
  if !(s == :RoW && al == :Assets)
)

@assert all(
  (:RoW, f, :Assets) in fin_position_s_f_al for f in fin_instrument
) "Rest of world must receive income on each asset instrument"

# ============================================================================
# Variables
# ============================================================================

const FinancialIncomeTag = Tag(:FinancialIncome)

@variables model :: FinancialIncomeTag begin
  rFinIncome_s_f_al[
    s=sector, f=fin_instrument, al=ass_liab, t=t; (s,f,al) in income_rate_s_f_al
  ] :: ForecastConstant, "Effective property-income rate on the prior-year financial stock."
end

@variables model :: (FinancialIncomeTag, GrowthAdjusted, InflationAdjusted, ForecastZero) begin
  jFinIncomeMarketGap_f[f=fin_instrument, t=t], "Reported asset income less liability income by instrument."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================

function set_starting_values!(start_values)
  lagged_stocks = [
    start_values[vFinAL[s,f,al,t1-1]]/fv
    for (s, f, al, _) in keys(rFinIncome_s_f_al)
  ]
  @assert all(!iszero, lagged_stocks) "Each income rate needs a nonzero prior-year financial stock"

  start_values[rFinIncome_s_f_al] .= [
    start_values[vFinIncome[s,f,al,t1]] / lagged_stock
    for ((s, f, al, _), lagged_stock) in zip(keys(rFinIncome_s_f_al), lagged_stocks)
  ]
  start_values[jFinIncomeMarketGap_f] .= 0.0
  start_values[jFinIncomeMarketGap_f[:,t1]] .= [
    sum(start_values[vFinIncome[:,f,:Assets,t1]]) -
      sum(start_values[vFinIncome[:,f,:Liab,t1]])
    for f in fin_instrument
  ]
  @assert all(isfinite, start_values[rFinIncome_s_f_al]) "Initial financial income rates must be finite"
  @assert all(isfinite, start_values[jFinIncomeMarketGap_f]) "Initial financial income market gaps must be finite"
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    # Fixed effective yields set interest and dividends.
    vFinIncome[(s,f,al,t) in keys(rFinIncome_s_f_al); t in t1:T],
    vFinIncome[s,f,al,t] == rFinIncome_s_f_al[s,f,al,t] * vFinAL[s,f,al,t-1]/fv

    # Rest-of-world receipts record source gaps in calibration and close each forecast market.
    vFinIncome[s=[:RoW], f=fin_instrument, al=[:Assets], t=t1:T],
    vFinIncome[s,f,al,t] == (∑(vFinIncome[s2,f,:Liab,t] for s2 in sector)
                             - ∑(vFinIncome[s2,f,:Assets,t] for s2 in sector if s2 != :RoW)
                             + jFinIncomeMarketGap_f[f,t])

    @test_constraint("Financial income market gap matches the source discrepancy"; atol=1e-6, rtol=1e-6)
    vFinIncome[s=[:RoW], f=fin_instrument, al=[:Assets], t=t1:T],
    ∑(vFinIncome[s2,f,:Assets,t] for s2 in sector) ==
      ∑(vFinIncome[s2,f,:Liab,t] for s2 in sector) + jFinIncomeMarketGap_f[f,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  # Source flows identify each effective rate except the market-closing receipt.
  @endo_exo_swap! block begin
    rFinIncome_s_f_al[(s,f,al,t) in keys(rFinIncome_s_f_al); t == t1],
    vFinIncome[(s,f,al,t) in keys(rFinIncome_s_f_al); t == t1]

    jFinIncomeMarketGap_f[f=fin_instrument, t=[t1]],
    vFinIncome[s=[:RoW], f=fin_instrument, al=[:Assets], t=[t1]]
  end

  return block
end

end # module
