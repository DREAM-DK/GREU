# Link interest and dividend flows to financial stocks.
# Set debt rates from the ECB rate and fixed position gaps.
# Set equity payouts by issuer and one rate for all owners.

module FinancialIncome

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..model
import ..SectorAccounts:
  ass_liab,
  fin_instrument,
  sector,
  vFinPosition_s_f,
  vFinIncome_s_f
import ..Tags: ForecastConstant
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================

const FinancialIncomeTag = Tag(:FinancialIncome)

@variables model :: FinancialIncomeTag begin
  rFinIncome_f[f=fin_instrument, t=t], "Average property-income rate by instrument."
  rFinIncome_s_f[(s,f,al,t)=vFinPosition_s_f] :: ForecastConstant, "Property-income rate by financial position."
  rDebtIncomeECBGap_s[(s,al,t)=vFinPosition_s_f[:,:Debt,:,:]] :: ForecastConstant, "Debt-income rate less the ECB rate by sector and side."
  rEquityIncomeGap_s[(s,t)=vFinPosition_s_f[:,:Equity,:Assets,:]] :: ForecastConstant, "Equity income rate less the average issuer rate by owner sector."
  rECB[t=t] :: ForecastConstant, "ECB rate."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  db[rECB] .= 0.04 # ToDo: Use source data and a given forecast.
  return nothing
end

function set_residual_tolerances!(tolerances, rtolerances)
  tolerances[rFinIncome_s_f] = 0.1
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================

function set_starting_values!(start_values)
  start_values[rFinIncome_f] .= 0.01
  start_values[rFinIncome_s_f] .= 0.01
  start_values[rDebtIncomeECBGap_s] .= 0.0
  start_values[rEquityIncomeGap_s] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  block = @block model begin
    # Rates set income flows on opening stocks.
    vFinIncome_s_f[s=sector, f=fin_instrument, al=ass_liab, t=t1:T],
    vFinIncome_s_f[s,f,al,t] == rFinIncome_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    # Debt rates equal the ECB rate plus a position gap.
    rFinIncome_s_f[s=sector, f=[:Debt], al=ass_liab, t=t1:T],
    rFinIncome_s_f[s,f,al,t] == rECB[t] + rDebtIncomeECBGap_s[s,al,t]

    # Set each instrument rate to the stock-weighted issuer average.
    rFinIncome_f[f=fin_instrument, t=t1:T],
    ∑((rFinIncome_s_f[s,f,:Liab,t] - rFinIncome_f[f,t]) * vFinPosition_s_f[s,f,:Liab,t-1]/fv for s in sector) == 0

    # Let the financial corporation debt-asset rate close the asset side.
    rDebtIncomeECBGap_s[s=[:FinCorp], al=[:Assets], t=t1:T],
    ∑((rFinIncome_s_f[s,:Debt,al,t] - rFinIncome_f[:Debt,t]) * vFinPosition_s_f[s,:Debt,al,t-1]/fv for s in sector) == 0

    # Equity owners receive the average issuer rate plus their own gap.
    rFinIncome_s_f[s=sector, f=[:Equity], al=[:Assets], t=t1:T],
    rFinIncome_s_f[s,f,al,t] == rFinIncome_f[f,t] + rEquityIncomeGap_s[s,t]

    # The RoW gap makes equity income received equal equity income paid.
    rEquityIncomeGap_s[s=[:RoW], t=t1:T],
    ∑(rEquityIncomeGap_s[s2,t] * vFinPosition_s_f[s2,:Equity,:Assets,t-1]/fv for s2 in sector) == 0
  end

  return block
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration(base=define_equations())
  block = copy(base)

  @endo_exo_swap! block begin
    rDebtIncomeECBGap_s[s=sector, al=ass_liab, t=[t1]; (s,al) ∉ [(:FinCorp, :Assets)]],
    vFinIncome_s_f[s=sector, f=[:Debt], al=ass_liab, t=[t1]; (s,f,al) ∉ [(:FinCorp, :Debt, :Assets)]]

    rFinIncome_s_f[s=sector, f=[:Equity], al=[:Liab], t=[t1]],
    vFinIncome_s_f[s=sector, f=[:Equity], al=[:Liab], t=[t1]]

    # Owner gaps reproduce source equity income at t1 and stay fixed afterwards.
    rEquityIncomeGap_s[s=sector, t=[t1]; s != :RoW],
    vFinIncome_s_f[s=sector, f=[:Equity], al=[:Assets], t=[t1]; s != :RoW]

    # RoW's gap closes the equity income balance. Its t1 residual absorbs source gaps.
    residual(rFinIncome_s_f)[s=[:RoW], f=[:Equity], al=[:Assets], t=[t1]],
    vFinIncome_s_f[s=[:RoW], f=[:Equity], al=[:Assets], t=[t1]]
  end

  return block
end

end # module