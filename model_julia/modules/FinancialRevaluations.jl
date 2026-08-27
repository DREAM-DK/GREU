# Set financial revaluations from opening stocks and position rates.
# Set corporate equity liabilities from discounted investor cash flows.
# Keep portfolio stocks and transactions in the sector modules.

module FinancialRevaluations

using SquareModels
import ..Corporations: corporations
import ..GrowthInflationAdjustment: fv
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
  vDividends = vFinIncome_f[:,:Equity,:Liab,:]
  vEquityIssues = vFinTransactions_f[:,:Equity,:Liab,:]
  vEquity = vFinPosition_s_f[:,:Equity,:Liab,:]

  position_block = @block model begin
    # Position rates set revaluations on opening stocks.
    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f); t in t1:T],
    vFinReval_s_f[s,f,al,t] == rFinReval_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    # Each position rate equals its instrument rate plus an adjustment.
    rFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f); t in t1:T],
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

  # Equity liability rates set adjustments. Firm-value equations set corporate
  # revaluations, so the position formulas set corporate equity liability rates.
  @endo_exo_swap! position_block begin
    jFinReval_f[(s,f,al,t) in keys(vFinPosition_s_f);
      f == :Equity && al == :Liab && t in t1:T],
    rFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      f == :Equity && al == :Liab && t in t1:T]

    rFinReval_s_f[s=corporations, f=[:Equity], al=[:Liab], t=t1:T],
    vFinReval_s_f[s=corporations, f=[:Equity], al=[:Liab], t=t1:T]
  end

  firm_value_block = @block model begin
    # Firm value is the present value of future dividends less equity issues.
    vFinReval_s_f[s=corporations, f=[:Equity], al=[:Liab], t=t1:(T-1)],
    vEquity[s,t] * (1 + rFirmRequiredReturn_s[s,t]) ==
      vDividends[s,t+1]*fv - vEquityIssues[s,t+1]*fv + vEquity[s,t+1]*fv

    # Set the terminal value.
    vFinReval_s_f[s=corporations, f=[:Equity], al=[:Liab], t=[T]; T > t1],
    vEquity[s,t] * (1 + rFirmRequiredReturn_s[s,t]) ==
      vDividends[s,t]*fv - vEquityIssues[s,t]*fv + vEquity[s,t]*fv
  end

  return position_block + firm_value_block
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    # Source equity values identify the required returns in the dynamic solve.
    rFirmRequiredReturn_s[s=corporations, t=[t1]; T > t1],
    vFinReval_s_f[s=corporations, f=[:Equity], al=[:Liab], t=[t1]; T > t1]

    rFinReval_f[f=[:Debt], t=[t1]],
    jFinReval_f[s=[:FinCorp], f=[:Debt], al=[:Liab], t=[t1]]

    jFinReval_f[(s,f,al,t) in keys(vFinPosition_s_f);
      f == :Debt && (al == :Liab || (s != :FinCorp && al == :Assets)) && t == t1],
    vFinReval_s_f[(s,f,al,t) in keys(vFinPosition_s_f);
      f == :Debt && (al == :Liab || (s != :FinCorp && al == :Assets)) && t == t1]

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
