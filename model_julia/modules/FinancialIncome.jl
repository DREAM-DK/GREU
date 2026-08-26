# Link interest and dividend flows to financial stocks.
# Split each rate into one instrument base and a position adjustment.
# Make each side's stock-weighted adjustments sum to zero.

module FinancialIncome

using SquareModels
import ..GrowthInflationAdjustment: fv
import ..model
import ..SectorAccounts:
  ass_liab,
  fin_instrument,
  sector,
  vFinPosition_s_f,
  vFinIncome_f
import ..Tags: ForecastConstant, ForecastZero
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================
const fixed_debt_asset_sector = sort(unique(
  s for (s, f, al, _) in keys(vFinPosition_s_f)
  if f == :Debt && al == :Assets && !(s in [:FinCorp, :RoW])
))
const fixed_equity_asset_sector = sort(unique(
  s for (s, f, al, _) in keys(vFinPosition_s_f)
  if f == :Equity && al == :Assets && s != :FinCorp
))

@assert all(
  (:FinCorp, f, :Assets, t1) in keys(vFinPosition_s_f) for f in fin_instrument
) "Financial corporations must hold each financial asset"

# ============================================================================
# Variables
# ============================================================================

const FinancialIncomeTag = Tag(:FinancialIncome)

@variables model :: FinancialIncomeTag begin
  rFinIncome_f[f=fin_instrument, t=t], "Average property-income rate by instrument."
end

@variables model :: (FinancialIncomeTag, ForecastConstant) begin
  rFinIncome_s_f[(s,f,al,t)=vFinPosition_s_f], "Property-income rate by financial position."
  jRoWDebtFinIncome[t], "Fixed RoW debt-asset rate adjustment."
end

@variables model :: (FinancialIncomeTag, ForecastZero) begin
  jrFinIncome_s_f[(s,f,al,t)=vFinPosition_s_f], "Adjustment from the average property-income rate."
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
  start_values[rFinIncome_f] .= 0.01
  start_values[rFinIncome_s_f] .= 0.01
  start_values[jrFinIncome_s_f] .= 0.0
  start_values[jRoWDebtFinIncome] .= 0.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  block = @block model begin
    # Rates set income on opening stocks.
    vFinIncome_f[s=sector, f=fin_instrument, al=ass_liab, t=t1:T],
    vFinIncome_f[s,f,al,t] == rFinIncome_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1]/fv

    # Each position rate equals the common instrument rate plus an adjustment.
    rFinIncome_s_f[s=sector, f=fin_instrument, al=ass_liab, t=t1:T],
    rFinIncome_s_f[s,f,al,t] == rFinIncome_f[f,t] + jrFinIncome_s_f[s,f,al,t]

    # FinCorp closes each side's stock-weighted adjustment sum.
    jrFinIncome_s_f[:FinCorp, f=fin_instrument, al=ass_liab, t=t1:T],
    ∑(jrFinIncome_s_f[s,f,al,t] * vFinPosition_s_f[s,f,al,t-1] for s in sector) == 0

    # Keep the RoW debt-asset adjustment fixed.
    jrFinIncome_s_f[s=[:RoW], f=[:Debt], al=[:Assets], t=t1:T],
    jrFinIncome_s_f[s,f,al,t] == jRoWDebtFinIncome[t]

    @test_constraint("Financial income markets close in the forecast"; atol=1e-6, rtol=1e-6)
    rFinIncome_f[f=fin_instrument, t=(t1+1):T; T > t1],
    ∑(vFinIncome_f[s,f,:Assets,t] for s in sector) == ∑(vFinIncome_f[s,f,:Liab,t] for s in sector)
  end

  # Fixed liability rates set the common base and liability adjustments.
  # Fixed debt-asset rates set their adjustments around the common base.
  @endo_exo_swap! block begin
    rFinIncome_f[f=fin_instrument, t=t1:T],
    jrFinIncome_s_f[s=[:FinCorp], f=fin_instrument, al=[:Liab], t=t1:T]

    jrFinIncome_s_f[s=sector, f=fin_instrument, al=[:Liab], t=t1:T],
    rFinIncome_s_f[s=sector, f=fin_instrument, al=[:Liab], t=t1:T]

    jrFinIncome_s_f[s=fixed_debt_asset_sector, f=[:Debt], al=[:Assets], t=t1:T],
    rFinIncome_s_f[s=fixed_debt_asset_sector, f=[:Debt], al=[:Assets], t=t1:T]
  end

  return block
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  # Source flows identify fixed rates and forecast adjustments.
  @endo_exo_swap! block begin
    rFinIncome_s_f[s=sector, f=fin_instrument, al=[:Liab], t=[t1]],
    vFinIncome_f[s=sector, f=fin_instrument, al=[:Liab], t=[t1]]

    rFinIncome_s_f[s=fixed_debt_asset_sector, f=[:Debt], al=[:Assets], t=[t1]],
    vFinIncome_f[s=fixed_debt_asset_sector, f=[:Debt], al=[:Assets], t=[t1]]

    jRoWDebtFinIncome[t1], vFinIncome_f[:RoW,:Debt,:Assets,t1]

    jrFinIncome_s_f[s=fixed_equity_asset_sector, f=[:Equity], al=[:Assets], t=[t1]],
    vFinIncome_f[s=fixed_equity_asset_sector, f=[:Equity], al=[:Assets], t=[t1]]
  end

  return block
end


end # module
