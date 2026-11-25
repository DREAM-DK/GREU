# Hold the government balance on its baseline share of GDP in a shock.
# Cash transfers to households are the free variable.
# A gap between government net financial assets and their baseline share of GDP moves the balance.
# Load this module only. A shock file adds its equation. The base model has no fiscal rule.
module FiscalClosure

using SquareModels
import ..FixedBasePriceAggregates: vGDP
import ..GovernmentExpenditure: rGovTransferIncome
import ..model
import ..SectorAccounts: vGovBalance, vNetFinAssets
import ..Time: t, t1, T

# ============================================================================
# Variables
# ============================================================================
const FiscalClosureTag = Tag(:FiscalClosure)

@variables model :: FiscalClosureTag begin
  rGovBalance2GDP[t], "Baseline government balance relative to GDP."
  rGovNetFinAssets2GDP[t], "Baseline government net financial assets relative to GDP."
  rGovNetFinAssetsCorrection, "Share of the gap in government net financial assets closed each year."
end

# ============================================================================
# Assign data
# ============================================================================
# The baseline sets all other values. See define_calibration.
function assign_data!(db)
  db[rGovNetFinAssetsCorrection] = 0.1
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # A shock that changes the primary balance in all years would move government net
    # assets for decades, because debt is the residual. The transfer rate returns the
    # change in the balance to households. A gap between net assets and their baseline
    # share of GDP in the prior year moves the balance. The gap then closes at a fixed rate.
    rGovTransferIncome[t=t1:T],
    vGovBalance[t] ==
      rGovBalance2GDP[t] * vGDP[t]
      + rGovNetFinAssetsCorrection * (rGovNetFinAssets2GDP[t-1] - vNetFinAssets[:Gov,t-1] / vGDP[t-1]) * vGDP[t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
# Solve this block alone on a baseline. All other variables keep their baseline values.
function define_calibration(base=define_equations())
  # The baseline sets the net asset target. The gap is then zero on the baseline.
  block = base + @block model begin
    rGovNetFinAssets2GDP[t=(t1-1):(T-1)], rGovNetFinAssets2GDP[t] * vGDP[t] == vNetFinAssets[:Gov,t]
  end

  # The baseline transfer rate sets the balance share.
  @endo_exo_swap! block begin
    rGovBalance2GDP[t=t1:T], rGovTransferIncome[t=t1:T]
  end

  return block
end

end # module
