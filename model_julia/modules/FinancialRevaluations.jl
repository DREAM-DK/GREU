# Set financial revaluations from opening stocks and position rates.
# Set issuer equity rates from discounted investor cash flows.
# Give all equity owners the average issuer rate.

module FinancialRevaluations

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..model
import ..SectorAccounts:
  ass_liab,
  fin_instrument,
  sector,
  vFinIncome_s_f,
  vFinPosition_s_f,
  vFinReval_s_f,
  vFinTransactions_f
import ..Tags: ForecastZero
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================
const equity_issuer = [:NonFinCorp, :FinCorp, :RoW]
# Households and Government issue a small value of derivatives,#
# which we lump with equity in the data, and mostly ignore

# ============================================================================
# Variables
# ============================================================================

const FinancialRevaluationsTag = Tag(:FinancialRevaluations)

@variables model :: FinancialRevaluationsTag begin
  rFirmRequiredReturn_s[s=equity_issuer, t=t], "Required nominal equity return by issuer."
  rFinReval_s_f[(s,f,al,t)=vFinPosition_s_f] :: ForecastZero, "Financial revaluation rate by position."
  rFinReval_f[f=fin_instrument, t=t], "Average financial revaluation rate by instrument."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  return nothing
end

function set_residual_tolerances!(tolerances)
  tolerances[rFinReval_s_f] = 0.2
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
  vDividends = vFinIncome_s_f[:,:Equity,:Liab,:]
  vEquityIssues = vFinTransactions_f[:,:Equity,:Liab,:]
  vEquity = vFinPosition_s_f[:,:Equity,:Liab,:]

  block = @block model begin
    # Position rates set revaluations on opening stocks.
    vFinReval_s_f[s=sector, f=fin_instrument, al=ass_liab, t=t1:T],
    vFinReval_s_f[s,f,al,t] == rFinReval_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    # Set each instrument rate to the stock-weighted issuer average.
    rFinReval_f[f=fin_instrument, t=t1:T],
    ∑((rFinReval_s_f[s,f,:Liab,t] - rFinReval_f[f,t]) * vFinPosition_s_f[s,f,:Liab,t-1]/fv for s in sector) == 0

    # Equity owners receive the average issuer revaluation rate.
    rFinReval_s_f[s=sector, f=[:Equity], al=[:Assets], t=t1:T],
    rFinReval_s_f[s,f,al,t] == rFinReval_f[f,t]

    # Firm value is the present value of future dividends less equity issues.
    rFinReval_s_f[s=equity_issuer, f=[:Equity], al=[:Liab], t=t1:(T-1)],
    vEquity[s,t] * (1+rFirmRequiredReturn_s[s,t+1]) ==
    vDividends[s,t+1]*fv - vEquityIssues[s,t+1]*fv + vEquity[s,t+1]*fv

    # Terminal value. Equation is left out of static calibration (T>t1).
    rFinReval_s_f[s=equity_issuer, f=[:Equity], al=[:Liab], t=[T]; T > t1],
    vEquity[s,t] * (1+rFirmRequiredReturn_s[s,t]) == vDividends[s,t]*fv - vEquityIssues[s,t]*fv + vEquity[s,t]*fv
  end

  return block
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations() + @block model begin
    # Keep required returns constant after t1+1.
    rFirmRequiredReturn_s[s=equity_issuer, t=(t1+2):T],
    rFirmRequiredReturn_s[s,t] == rFirmRequiredReturn_s[s,t1+1]
  end

  @endo_exo_swap! block begin
    rFinReval_s_f[s=sector, f=[:Debt], al=ass_liab, t=[t1]],
    vFinReval_s_f[s=sector, f=[:Debt], al=ass_liab, t=[t1]]

    rFinReval_s_f[s=sector, f=[:Equity], al=[:Liab], t=[t1]; s ∉ equity_issuer],
    vFinReval_s_f[s=sector, f=[:Equity], al=[:Liab], t=[t1]; s ∉ equity_issuer]]

    residual(rFinReval_s_f)[s=sector, f=[:Equity], al=[:Assets], t=[t1]],
    vFinReval_s_f[s=sector, f=[:Equity], al=[:Assets], t=[t1]]
  end

  # Static calibration only.
  if T == t1
    @endo_exo_swap! block begin
      rFinReval_s_f[s=equity_issuer, f=[:Equity], al=[:Liab], t=[t1]],
      vFinReval_s_f[s=equity_issuer, f=[:Equity], al=[:Liab], t=[t1]]
    end
  end

  # Dynamic calibration only. The t1 valuation uses rFirmRequiredReturn_s[t1+1].
  if T > t1
    @endo_exo_swap! block begin
      rFirmRequiredReturn_s[s=equity_issuer,t1+1],
      vFinReval_s_f[s=equity_issuer,:Equity,:Liab,t1]
    end
  end

  return block
end

end # module
