# Set corporate equity values from discounted equity payouts.
# Endogenize issuer and holder equity revaluations.
# Keep portfolio stocks and transactions in the sector modules.

module FirmValue

using SquareModels
import ..Corporations: corporation_sector
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..model
import ..SectorAccounts: vFinAL, vFinIncome, vFinReval
import ..Tags: DynamicCalibration, ForecastConstant
import ..Time: t, t1, T

# ============================================================================
# Indices
# ============================================================================

const equity_asset_sector = sort(unique(
  s for (s, f, al, _) in keys(vFinAL) if f == :Equity && al == :Assets
))
const equity_liability_sector = sort(unique(
  s for (s, f, al, _) in keys(vFinAL) if f == :Equity && al == :Liab
))
const fixed_equity_reval_sector = setdiff(equity_asset_sector, [:RoW])

@assert Set(corporation_sector) ⊆ Set(equity_liability_sector) "Each corporate sector must issue equity"
@assert :RoW in equity_asset_sector "Rest of world must hold the residual equity assets"

# ============================================================================
# Variables
# ============================================================================

const FirmValueTag = Tag(:FirmValue)

@variables model :: (FirmValueTag, GrowthAdjusted, InflationAdjusted) begin
  vFirmEquity_s[s=corporation_sector, t=t], "Market value of corporate equity by issuer."
end

@variables model :: FirmValueTag begin
  rFirmRequiredReturn_s[s=corporation_sector, t=t] :: ForecastConstant, "Required nominal equity return by issuer."
  rEquityRevalAllocation_s[s=fixed_equity_reval_sector, t=t] :: ForecastConstant, "Equity revaluation allocation rate by holder."
  fFirmEquityPayout_s[s=corporation_sector] :: DynamicCalibration, "Scale from source equity payouts to payouts valued by investors."
end

# ============================================================================
# Assign data
# ============================================================================

function assign_data!(db)
  db[rFirmRequiredReturn_s] .= 0.08
  db[vFirmEquity_s[:,t1]] .= [
    db[vFinAL[s,:Equity,:Liab,t1]] for s in corporation_sector
  ]

  @assert all(db[vFinAL[s,:Equity,:Liab,t1]] > 0 for s in corporation_sector) "Source corporate equity values must be positive"
  @assert all(db[vFinIncome[s,:Equity,:Liab,t1]] > 0 for s in corporation_sector) "Source corporate equity payouts must be positive"
  @assert all(db[rFirmRequiredReturn_s[s,t1]] > fv-1 for s in corporation_sector) "Each required return must exceed long-run nominal growth"
  @assert all(
    isfinite(fv / (1 + db[rFirmRequiredReturn_s[s,t1]] - fv))
    for s in corporation_sector
  ) "Each terminal value factor must be finite"
  return nothing
end

# ============================================================================
# Starting values
# ============================================================================

function set_starting_values!(start_values)
  start_values[vFirmEquity_s] .= [
    start_values[vFinAL[s,:Equity,:Liab,t1]]
    for s in corporation_sector, year in t
  ]
  start_values[fFirmEquityPayout_s] .= [
    start_values[vFinAL[s,:Equity,:Liab,t1]] *
      (1 + start_values[rFirmRequiredReturn_s[s,t1]] - fv) /
      (fv * start_values[vFinIncome[s,:Equity,:Liab,t1]])
    for s in corporation_sector
  ]
  total_liability_reval = sum(
    start_values[vFinReval[s,:Equity,:Liab,t1]] for s in equity_liability_sector
  )
  @assert !iszero(total_liability_reval) "Source total equity liability revaluation must be nonzero"
  start_values[rEquityRevalAllocation_s] .= [
    start_values[vFinReval[s,:Equity,:Assets,t1]] / total_liability_reval
    for s in fixed_equity_reval_sector, year in t
  ]
  @assert all(isfinite, start_values[fFirmEquityPayout_s]) "Initial equity payout scales must be finite"
  @assert all(start_values[fFirmEquityPayout_s] .> 0) "Initial equity payout scales must be positive"
  @assert all(isfinite, start_values[rEquityRevalAllocation_s]) "Initial equity revaluation rates must be finite"
  return nothing
end

# ============================================================================
# Equations
# ============================================================================

function define_equations()
  return @block model begin
    # The current equity value is the discounted next payout and next value.
    vFirmEquity_s[s=corporation_sector, t=t1:(T-1); T > t1],
    vFirmEquity_s[s,t] * (1 + rFirmRequiredReturn_s[s,t+1]) == fv * (
      fFirmEquityPayout_s[s] * vFinIncome[s,:Equity,:Liab,t+1]
      + vFirmEquity_s[s,t+1]
    )

    # Adjusted payouts and values stay constant after T.
    vFirmEquity_s[s=corporation_sector, t=[T]],
    vFirmEquity_s[s,t] * (1 + rFirmRequiredReturn_s[s,t] - fv) ==
      fv * fFirmEquityPayout_s[s] * vFinIncome[s,:Equity,:Liab,t]

    # The DCF value sets the issuer stock through its revaluation flow.
    vFinReval[s=corporation_sector, f=[:Equity], al=[:Liab], t=t1:T],
    vFinAL[s,f,al,t] == vFirmEquity_s[s,t]

    # Fixed allocation rates set domestic holder revaluations.
    vFinReval[s=fixed_equity_reval_sector, f=[:Equity], al=[:Assets], t=t1:T],
    vFinReval[s,f,al,t] == rEquityRevalAllocation_s[s,t] *
      ∑(vFinReval[s2,f,:Liab,t] for s2 in equity_liability_sector)

    # Rest-of-world holder revaluation clears the equity market.
    vFinReval[s=[:RoW], f=[:Equity], al=[:Assets], t=t1:T],
    ∑(vFinReval[s2,f,al,t] for s2 in equity_asset_sector) ==
      ∑(vFinReval[s2,f,:Liab,t] for s2 in equity_liability_sector)
  end
end

# ============================================================================
# Calibration
# ============================================================================

function define_calibration()
  block = define_equations()

  # Keep source equity values fixed and identify one payout scale per issuer.
  # Generic residual calibration keeps source revaluations fixed in the tie equation.
  @endo_exo_swap! block begin
    fFirmEquityPayout_s[s=corporation_sector],
    vFirmEquity_s[s=corporation_sector, t=[t1]]

    rEquityRevalAllocation_s[s=fixed_equity_reval_sector, t=[t1]],
    vFinReval[s=fixed_equity_reval_sector, f=[:Equity], al=[:Assets], t=[t1]]
  end

  return block
end

# ============================================================================
# Tests
# ============================================================================

function run_tests(db)
  errors = String[]
  all(db[vFirmEquity_s[:,t1:T]] .> 0) || push!(errors, "Corporate equity values must be positive")
  all(db[fFirmEquityPayout_s] .> 0) || push!(errors, "Equity payout scales must be positive")
  all(db[rFirmRequiredReturn_s[:,t1:T]] .> fv-1) ||
    push!(errors, "Required equity returns must exceed long-run nominal growth")
  return errors
end

end # module
