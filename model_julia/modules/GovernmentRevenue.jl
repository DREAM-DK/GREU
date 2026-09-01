# Define primary government revenue and its source flows.
# Set simple rules for non-tax revenue.
# Link government receipts to sector-account payments.

module GovernmentRevenue

using SquareModels
import ..FixedBasePriceAggregates: vGVA
import ..Government:
  vGovCapTransfer,
  vGovOthCurrentTransRev,
  vsGovOthRev,
  vGovPrimaryRevenue,
  vGovPrimaryRevOther,
  vGovSalesRev,
  vSocTransKind
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..IndustrySectors: vY_s
import ..InputOutput: vG
import ..model
import ..SectorAccounts:
  sector,
  vtCap,
  vtDirect,
  vFinIncome_s_f,
  vSocialContributions
import ..Taxes: vtIndirect
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const GovernmentRevenueTag = Tag(:GovernmentRevenue)

@variables model :: (GovernmentRevenueTag, ForecastConstant) begin
  tsGovOthRev2GVA[t], "Other government subsidy revenue relative to GVA."
  rGovOthCurrentTransRev2GVA[t], "Other government current-transfer revenue relative to GVA."
  rGovCapTransfer2GVA[t], "Government capital-transfer revenue relative to GVA."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  return nothing
end

function set_residual_tolerances!(tolerances)
  # Government data use one decimal; sector accounts report whole EUR millions.
  tolerances[vSocialContributions] = 1.0
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Primary revenue.
    vGovPrimaryRevenue[t=t1:T],
    vGovPrimaryRevenue[t] == vtIndirect[t] + vtDirect[t] + vGovPrimaryRevOther[t]

    vGovPrimaryRevOther[t=t1:T],
    vGovPrimaryRevOther[t] == vGovSalesRev[t]
                              + vsGovOthRev[t]
                              + vFinIncome_s_f[:Gov,:Equity,:Assets,t]
                              + vSocialContributions[:Gov,t]
                              + vGovOthCurrentTransRev[t]
                              + vtCap[t]
                              + vGovCapTransfer[t]

    # Public production revenue. Input-output demand determines output.
    vGovSalesRev[t=t1:T],
    vGovSalesRev[t] == vY_s[:Gov,t] - vsGovOthRev[t] + vSocTransKind[t] - vG[t]

    # Non-tax revenue without a detailed rule follows whole-economy GVA.
    vsGovOthRev[t=t1:T], vsGovOthRev[t] == tsGovOthRev2GVA[t] * vGVA[t]
    vGovOthCurrentTransRev[t=t1:T],
    vGovOthCurrentTransRev[t] == rGovOthCurrentTransRev2GVA[t] * vGVA[t]
    vGovCapTransfer[t=t1:T], vGovCapTransfer[t] == rGovCapTransfer2GVA[t] * vGVA[t]

    # Social contributions use the sector-account government flow and a household counterpart.
    vSocialContributions[s=[:Hh], t=t1:T],
    ∑(vSocialContributions[s2,t] for s2 in sector) == 0
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    tsGovOthRev2GVA[t1], vsGovOthRev[t1]
    rGovOthCurrentTransRev2GVA[t1], vGovOthCurrentTransRev[t1]
    rGovCapTransfer2GVA[t1], vGovCapTransfer[t1]
  end

  return block
end

end # module
