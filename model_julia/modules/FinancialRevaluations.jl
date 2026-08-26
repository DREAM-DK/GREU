# Set financial revaluations from opening stocks and position rates.
# Set corporate equity values from discounted investor cash flows.
# Link issuer values to domestic equity liability revaluations.
# Keep portfolio stocks and transactions in the sector modules.

module FinancialRevaluations

using SquareModels
import ..Corporations: corporations
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..model
import ..SectorAccounts:
  fin_instrument,
  sector,
  vFinIncome_f,
  vFinPosition_s_f,
  vFinReval_s_f,
  vFinTransactions_f
import ..Tags: ForecastConstant, ForecastZero
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================

const equity_liability_sector = sort(unique(
  s for (s, f, al, _) in keys(vFinPosition_s_f) if f == :Equity && al == :Liab
))
const fixed_equity_liability_sector = setdiff(equity_liability_sector, corporations)
const fixed_equity_asset_sector = setdiff(
  sort(unique(s for (s, f, al, _) in keys(vFinPosition_s_f) if f == :Equity && al == :Assets)),
  [:FinCorp],
)
# ============================================================================
# Variables
# ============================================================================

const FinancialRevaluationsTag = Tag(:FinancialRevaluations)

@variables model :: (FinancialRevaluationsTag, GrowthAdjusted, InflationAdjusted) begin
  vFirmEquity_s[s=corporations, t=t], "Market value of corporate equity by issuer."
end

@variables model :: FinancialRevaluationsTag begin
  rFirmRequiredReturn_s[s=corporations, t=t] :: ForecastConstant, "Required nominal equity return by issuer."
  rFinReval_s_f[(s,f,al,t)=vFinPosition_s_f], "Financial revaluation rate by position."
  rFinReval_f[f=fin_instrument, t=t] :: ForecastZero, "Average financial revaluation rate by instrument."
  jFinReval_f[(s,f,al,t)=vFinPosition_s_f] :: ForecastZero, "Adjustment from the average financial revaluation rate."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  db[vFirmEquity_s[:,t1]] .= [db[vFinPosition_s_f[s,:Equity,:Liab,t1]] for s in corporations]
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================

function set_starting_values!(start_values)
  start_values[rFirmRequiredReturn_s] .= 0.08
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Value of firm is present value of future dividends net of equity issues
    vFirmEquity_s[s=corporations, t=t1:(T-1)],
    vFirmEquity_s[s,t] * (1 + rFirmRequiredReturn_s[s,t+1]) ==
    vFinIncome_f[s,:Equity,:Liab,t+1]*fv - vFinTransactions_f[s,:Equity,:Liab,t+1]*fv + vFirmEquity_s[s,t+1]*fv

    # Terminal value
    vFirmEquity_s[s=corporations, t=[T]; T > t1],
    vFirmEquity_s[s,t] * (1 + rFirmRequiredReturn_s[s,t]) ==
    vFinIncome_f[s,:Equity,:Liab,t]*fv - vFinTransactions_f[s,:Equity,:Liab,t]*fv + vFirmEquity_s[s,t]*fv

    # The DCF value sets the issuer stock through its revaluation flow.
    vFinReval_s_f[s=corporations, f=[:Equity], al=[:Liab], t=t1:T],
    vFinPosition_s_f[s,f,al,t] == vFirmEquity_s[s,t]

    # Position rates set revaluations on opening stocks.
    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f); al == :Assets && t in t1:T],
    vFinReval_s_f[s,f,al,t] == rFinReval_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f); f != :Equity && al == :Liab && t in t1:T],
    vFinReval_s_f[s,f,al,t] == rFinReval_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s in fixed_equity_liability_sector && f == :Equity && al == :Liab && t in t1:T],
    vFinReval_s_f[s,f,al,t] == rFinReval_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    rFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s in corporations && f == :Equity && al == :Liab && t in t1:T],
    vFinReval_s_f[s,f,al,t] == rFinReval_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    # Each position rate equals its instrument rate plus an adjustment.
    rFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f); al == :Assets && t in t1:T],
    rFinReval_s_f[s,f,al,t] == rFinReval_f[f,t] + jFinReval_f[s,f,al,t]

    rFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f); f != :Equity && al == :Liab && t in t1:T],
    rFinReval_s_f[s,f,al,t] == rFinReval_f[f,t] + jFinReval_f[s,f,al,t]

    jFinReval_f[(s,f,al,t) in keys(vFinPosition_s_f); f == :Equity && al == :Liab && t in t1:T],
    rFinReval_s_f[s,f,al,t] == rFinReval_f[f,t] + jFinReval_f[s,f,al,t]

    # FinCorp closes the asset-side adjustment sums.
    jFinReval_f[s=[:FinCorp], f=fin_instrument, al=[:Assets], t=t1:T],
    ∑(jFinReval_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1] for s in sector) == 0

    # FinCorp closes each non-equity liability adjustment sum.
    jFinReval_f[s=[:FinCorp], f=setdiff(fin_instrument, [:Equity]), al=[:Liab], t=t1:T],
    ∑(jFinReval_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1] for s in sector) == 0

    # The corporate liability adjustments identify the average equity rate.
    rFinReval_f[f=[:Equity], t=t1:T],
    ∑(jFinReval_f[s,f,:Liab,t] * vFinPosition_s_f[s,f,:Liab,t-1] for s in sector) == 0
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    # Source equity values identify the required returns in the dynamic solve.
    rFirmRequiredReturn_s[s=corporations, t=[t1]; T > t1],
    vFirmEquity_s[s=corporations, t=[t1]; T > t1]

    rFinReval_f[f=[:Debt], t=[t1]],
    jFinReval_f[s=[:FinCorp], f=[:Debt], al=[:Liab], t=[t1]]

    jFinReval_f[(s,f,al,t) in keys(vFinPosition_s_f); f == :Debt && al == :Liab && t == t1],
    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f); f == :Debt && al == :Liab && t == t1]

    jFinReval_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s != :FinCorp && f == :Debt && al == :Assets && t == t1],
    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s != :FinCorp && f == :Debt && al == :Assets && t == t1]

    jFinReval_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s in fixed_equity_asset_sector && f == :Equity && al == :Assets && t == t1],
    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s in fixed_equity_asset_sector && f == :Equity && al == :Assets && t == t1]

    rFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s in fixed_equity_liability_sector && f == :Equity && al == :Liab && t == t1],
    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      s in fixed_equity_liability_sector && f == :Equity && al == :Liab && t == t1]
  end

  return block
end

end # module
