# Set corporate equity values from discounted investor cash flows.
# Endogenize issuer and holder equity revaluations.
# Keep portfolio stocks and transactions in the sector modules.

module FirmValue

using SquareModels
import ..Corporations: corporation_sector
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..model
import ..SectorAccounts:
  vFinPosition_f,
  vFinIncome_f,
  vFinReval_f,
  vFinTransactions_f
import ..Tags: ForecastConstant
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================

const equity_asset_sector = sort(unique(
  s for (s, f, al, _) in keys(vFinPosition_f) if f == :Equity && al == :Assets
))
const equity_liability_sector = sort(unique(
  s for (s, f, al, _) in keys(vFinPosition_f) if f == :Equity && al == :Liab
))
const fixed_equity_reval_sector = setdiff(equity_asset_sector, [:RoW])
const aggregate_equity_reval_sector = setdiff(fixed_equity_reval_sector, [:FinCorp])

@assert Set(corporation_sector) ⊆ Set(equity_liability_sector) "Each corporate sector must issue equity"
@assert :FinCorp in fixed_equity_reval_sector "Financial corporations must hold equity assets"
@assert :RoW in equity_asset_sector "Rest of world must hold the residual equity assets"

# ============================================================================
# Variables
# ============================================================================

const FirmValueTag = Tag(:FirmValue)

@variables model :: (FirmValueTag, GrowthAdjusted, InflationAdjusted) begin
  vFirmEquity_s[s=corporation_sector, t=t], "Market value of corporate equity by issuer."
end

@variables model :: FirmValueTag begin
  rFirmRequiredReturn_s[s=corporation_sector], "Required nominal equity return by issuer."
  rEquityRevalAllocation_s[s=fixed_equity_reval_sector, t=t] :: ForecastConstant,
    "Equity revaluation allocation rate by holder."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  db[vFirmEquity_s[:,t1]] .= [
    db[vFinPosition_f[s,:Equity,:Liab,t1]] for s in corporation_sector
  ]

  @assert all(
    db[vFinPosition_f[s,:Equity,:Liab,t1]] > 0 for s in corporation_sector
  ) "Source corporate equity values must be positive"
  @assert all(
    db[vFinIncome_f[s,:Equity,:Liab,t1]] > 0 for s in corporation_sector
  ) "Source corporate equity payouts must be positive"
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================

function set_starting_values!(start_values)
  start_values[rFirmRequiredReturn_s] .= 0.08
  start_values[vFirmEquity_s] .= [
    start_values[vFinPosition_f[s,:Equity,:Liab,t1]]
    for s in corporation_sector, year in t
  ]
  total_liability_reval = sum(
    start_values[vFinReval_f[s,:Equity,:Liab,t1]] for s in equity_liability_sector
  )
  non_fin_corp_liability_reval = start_values[vFinReval_f[:NonFinCorp,:Equity,:Liab,t1]]
  @assert !iszero(total_liability_reval) "Source total equity liability revaluation must be nonzero"
  @assert !iszero(
    non_fin_corp_liability_reval
  ) "Source non-financial corporation equity liability revaluation must be nonzero"
  start_values[rEquityRevalAllocation_s[aggregate_equity_reval_sector,:]] .= [
    start_values[vFinReval_f[s,:Equity,:Assets,t1]] / total_liability_reval
    for s in aggregate_equity_reval_sector, year in t
  ]
  start_values[rEquityRevalAllocation_s[:FinCorp,:]] .=
    start_values[vFinReval_f[:FinCorp,:Equity,:Assets,t1]] / non_fin_corp_liability_reval
  @assert all(
    start_values[rFirmRequiredReturn_s] .> fv-1
  ) "Initial required returns must exceed long-run nominal growth"
  @assert all(isfinite, start_values[rEquityRevalAllocation_s]) "Initial equity revaluation rates must be finite"
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    # Investors receive dividends and buy-back cash and fund new equity issues.
    vFirmEquity_s[s=corporation_sector, t=t1:(T-1); T > t1],
    vFirmEquity_s[s,t] * (1 + rFirmRequiredReturn_s[s]) == fv * (vFinIncome_f[s,:Equity,:Liab,t+1]
      - vFinTransactions_f[s,:Equity,:Liab,t+1] + vFirmEquity_s[s,t+1])

    # Constant adjusted payouts after T give the terminal perpetuity value.
    # Leave the calibration-year equity value exogenous in a static model.
    vFirmEquity_s[s=corporation_sector, t=[T]; T > t1],
    vFirmEquity_s[s,t] * (1 + rFirmRequiredReturn_s[s] - fv) == fv * (vFinIncome_f[s,:Equity,:Liab,t]
      - vFinTransactions_f[s,:Equity,:Liab,t])

    # The DCF value sets the issuer stock through its revaluation flow.
    vFinReval_f[s=corporation_sector, f=[:Equity], al=[:Liab], t=t1:T],
    vFinPosition_f[s,f,al,t] == vFirmEquity_s[s,t]

    # Financial corporations keep a fixed ownership position in non-financial corporations.
    vFinReval_f[s=[:FinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinReval_f[s,f,al,t] == rEquityRevalAllocation_s[s,t] * vFinReval_f[:NonFinCorp,f,:Liab,t]

    # Fixed allocation rates set other domestic holder revaluations.
    vFinReval_f[s=aggregate_equity_reval_sector, f=[:Equity], al=[:Assets], t=t1:T],
    vFinReval_f[s,f,al,t] ==
      rEquityRevalAllocation_s[s,t] * ∑(vFinReval_f[s2,f,:Liab,t] for s2 in equity_liability_sector)

    # Rest-of-world holder revaluation clears the equity market.
    vFinReval_f[s=[:RoW], f=[:Equity], al=[:Assets], t=t1:T],
    ∑(vFinReval_f[s2,f,al,t] for s2 in equity_asset_sector) ==
      ∑(vFinReval_f[s2,f,:Liab,t] for s2 in equity_liability_sector)

    # Post-solve bounds.
    @test_constraint("Corporate equity values must be positive")
    vFirmEquity_s[s=corporation_sector, t=t1:T], vFirmEquity_s[s,t] >= 1e-12

    @test_constraint("Required equity returns must exceed long-run nominal growth")
    rFirmRequiredReturn_s[s=corporation_sector; T > t1], rFirmRequiredReturn_s[s] - (fv-1) >= 1e-12
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  # The dynamic solve identifies the required return from source equity values.
  # A static solve has no equity-value equation and keeps source values exogenous.
  if T > t1
    @endo_exo_swap! block begin
      rFirmRequiredReturn_s[s=corporation_sector],
      vFirmEquity_s[s=corporation_sector, t=[t1]]
    end
  end

  # Keep source holder revaluations fixed.
  @endo_exo_swap! block begin
    rEquityRevalAllocation_s[s=fixed_equity_reval_sector, t=[t1]],
    vFinReval_f[s=fixed_equity_reval_sector, f=[:Equity], al=[:Assets], t=[t1]]
  end

  return block
end

end # module
