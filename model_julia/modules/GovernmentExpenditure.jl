# Define primary government expenditure and its source flows.
# Set simple rules for benefits and other expenditure.
# Link government payments to sector-account receipts.

module GovernmentExpenditure

using SquareModels
import ..FixedBasePriceAggregates: vGVA
import ..Government:
  vGovPensionEntitlementAdj,
  vGovCapTransExp,
  vGovOthCurrentTransExp,
  vGovOthProdTax,
  vGovPrimaryExpenditure,
  vGovSocBenefitExp,
  vSocTransKind
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..IndustrySectors: vM_s, vWages_s
import ..InputOutput: vG
import ..Labor: vHhWages
import ..model
import ..SectorAccounts:
  sector,
  vI_s,
  vNonProducedAssetAcquisitions,
  vSocialBenefits
import ..Taxes:
  vProductSubsidy,
  vProductionSubsidy,
  vRoWProductSubsidy,
  vRoWProductionSubsidy
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const GovernmentExpenditureTag = Tag(:GovernmentExpenditure)

@variables model :: (GovernmentExpenditureTag, ForecastConstant) begin
  rGovTransferIncome[t], "Government cash transfer payment relative to its index."
  rRoWTransferIncome[t], "RoW net social benefit receipt relative to the transfer index."
  rSocTransKind2G[t], "Social transfers in kind relative to government consumption."
  rGovOthCurrentTransExp2GVA[t], "Other government current-transfer expense relative to GVA."
  rGovOthProdTax2GVA[t], "Other production taxes paid by government relative to GVA."
  rGovCapTransExp2GVA[t], "Government capital-transfer expense relative to GVA."
  rGovNonProducedAssetAcquisitions2GVA[t], "Government net acquisitions of non-produced assets relative to GVA."
end

@variables model :: (GovernmentExpenditureTag, GrowthAdjusted, InflationAdjusted) begin
  vTransferIncomeIndex[t], "Index for cash transfer income payments."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Primary expenditure.
    vGovPrimaryExpenditure[t=t1:T],
    vGovPrimaryExpenditure[t] == vM_s[:Gov,t]
                                  + vI_s[:Gov,t]
                                  + vWages_s[:Gov,t]
                                  + vGovOthProdTax[t]
                                  + vProductSubsidy[t]
                                  - vRoWProductSubsidy[t]
                                  + vProductionSubsidy[t]
                                  - vRoWProductionSubsidy[t]
                                  + vGovSocBenefitExp[t]
                                  + vGovOthCurrentTransExp[t]
                                  + vGovPensionEntitlementAdj[t]
                                  + vGovCapTransExp[t]
                                  + vNonProducedAssetAcquisitions[:Gov,t]

    # Expenditure without a detailed rule follows GVA or government consumption.
    vGovOthCurrentTransExp[t=t1:T],
    vGovOthCurrentTransExp[t] == rGovOthCurrentTransExp2GVA[t] * vGVA[t]
    vGovOthProdTax[t=t1:T], vGovOthProdTax[t] == rGovOthProdTax2GVA[t] * vGVA[t]
    vGovCapTransExp[t=t1:T], vGovCapTransExp[t] == rGovCapTransExp2GVA[t] * vGVA[t]
    vNonProducedAssetAcquisitions[s=[:Gov], t=t1:T],
    vNonProducedAssetAcquisitions[s,t] == rGovNonProducedAssetAcquisitions2GVA[t] * vGVA[t]
    vSocTransKind[t=t1:T], vSocTransKind[t] == rSocTransKind2G[t] * vG[t]

    # Cash benefits follow a simple income index.
    vTransferIncomeIndex[t=t1:T], vTransferIncomeIndex[t] == vHhWages[t-2]/fv^2
    vGovSocBenefitExp[t=t1:T],
    vGovSocBenefitExp[t] == vSocTransKind[t] + rGovTransferIncome[t] * vTransferIncomeIndex[t]

    # Social benefits use government spending and source flows for other sectors.
    vSocialBenefits[s=[:Gov], t=t1:T],
    vSocialBenefits[s,t] == -(vGovSocBenefitExp[t] - vSocTransKind[t])
    vSocialBenefits[s=[:RoW], t=t1:T],
    vSocialBenefits[s,t] == rRoWTransferIncome[t] * vTransferIncomeIndex[t]
    vSocialBenefits[s=[:NonFinCorp], t=t1:T], vSocialBenefits[s,t] == 0
    vSocialBenefits[s=[:Hh], t=t1:T], ∑(vSocialBenefits[s2,t] for s2 in sector) == 0

    # Non-produced assets use a temporary household counterpart.
    vNonProducedAssetAcquisitions[s=[:Hh], t=t1:T],
    ∑(vNonProducedAssetAcquisitions[s2,t] for s2 in sector) == 0
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  @endo_exo_swap! block begin
    rGovTransferIncome[t1], vGovSocBenefitExp[t1]
    rRoWTransferIncome[t1], vSocialBenefits[:RoW,t1]
    rSocTransKind2G[t1], vSocTransKind[t1]
    rGovOthCurrentTransExp2GVA[t1], vGovOthCurrentTransExp[t1]
    rGovOthProdTax2GVA[t1], vGovOthProdTax[t1]
    rGovCapTransExp2GVA[t1], vGovCapTransExp[t1]
    rGovNonProducedAssetAcquisitions2GVA[t1], vNonProducedAssetAcquisitions[:Gov,t1]
  end

  return block
end

end # module
