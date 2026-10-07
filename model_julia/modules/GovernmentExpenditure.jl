# Define primary government expenditure and its source flows.
# Set government consumption by product as a share of GDP.
# Set simple rules for benefits and other expenditure.
# Link government payments to sector-account receipts.

module GovernmentExpenditure

using SquareModels
import ..FixedBasePriceAggregates: qGDP, vGVA
import ..Government:
  vGovPensionEntitlementAdj,
  vGovCapTransExp,
  vGovOthCurrentTransExp,
  vGovPrimaryExpenditure,
  vGovSocBenefitExp,
  vSocTransKind
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fv
import ..IndustrySectors: vM_s, vtProduction_s, vWages_s
import ..InputOutput: product, qG_p, vG
import ..Labor: vHhWages
import ..model
import ..SectorAccounts:
  sector,
  vI_s,
  vNonProducedAssetAcquisitions,
  vOtherTransfers,
  vSocialBenefits,
  vSocialContributions
import ..Taxes:
  vsProduct,
  vsProduction,
  vsRoWProduct,
  vsRoWProduction
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
  rGovCapTransExp2GVA[t], "Government capital-transfer expense relative to GVA."
  rGovNonProducedAssetAcquisitions2GVA[t], "Government net acquisitions of non-produced assets relative to GVA."
  rOtherTransfers[s=[:FinCorp, :NonFinCorp, :RoW], t=t], "Other current and capital transfers relative to the transfer index."
  rFinCorpSocialBenefits[t], "Financial-corporation social benefits relative to the transfer index."
  rSocialContributions[s=[:FinCorp, :Gov, :NonFinCorp, :RoW], t=t], "Social contributions relative to the transfer index."
  rG2GDP_p[(p,t)=qG_p], "Government consumption by product relative to real GDP."
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
    # Government consumption is exogenous. The baseline holds it as a share of real GDP.
    rG2GDP_p[p=product, t=t1:T], qG_p[p,t] == rG2GDP_p[p,t] * qGDP[t]

    # Primary expenditure.
    vGovPrimaryExpenditure[t=t1:T],
    vGovPrimaryExpenditure[t] == vM_s[:Gov,t]
                                  + vI_s[:Gov,t]
                                  + vWages_s[:Gov,t]
                                  + vtProduction_s[:Gov,t]
                                  + vsProduct[t] - vsRoWProduct[t]
                                  + vsProduction[t] - vsRoWProduction[t]
                                  + vGovSocBenefitExp[t]
                                  + vGovOthCurrentTransExp[t]
                                  + vGovPensionEntitlementAdj[t]
                                  + vGovCapTransExp[t]
                                  + vNonProducedAssetAcquisitions[:Gov,t]

    # Expenditure without a detailed rule follows GVA or government consumption.
    vGovOthCurrentTransExp[t=t1:T],
    vGovOthCurrentTransExp[t] == rGovOthCurrentTransExp2GVA[t] * vGVA[t]
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
    # Financial corporations pay pension benefits. In 2019 this is about 10 billion EUR.
    vSocialBenefits[s=[:FinCorp], t=t1:T],
    vSocialBenefits[s,t] == rFinCorpSocialBenefits[t] * vTransferIncomeIndex[t]
    vSocialBenefits[s=[:Hh], t=t1:T], ∑(vSocialBenefits[s2,t] for s2 in sector) == 0

    # Household contributions close the sum in GovernmentRevenue.
    vSocialContributions[s=[:FinCorp, :Gov, :NonFinCorp, :RoW], t=t1:T],
    vSocialContributions[s,t] == rSocialContributions[s,t] * vTransferIncomeIndex[t]

    # D.7 is the main part. D.92 and D.99 are smaller capital transfers.
    # Government and households are set in Government.
    vOtherTransfers[s=[:FinCorp, :NonFinCorp, :RoW], t=t1:T],
    vOtherTransfers[s,t] == rOtherTransfers[s,t] * vTransferIncomeIndex[t]

    # Non-produced assets use a temporary household counterpart.
    vNonProducedAssetAcquisitions[s=[:Hh], t=t1:T],
    ∑(vNonProducedAssetAcquisitions[s2,t] for s2 in sector) == 0
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration(base=define_equations())
  block = copy(base)

  @endo_exo_swap! block begin
    qG_p[(p,t) in keys(qG_p); t1 < t <= T], rG2GDP_p[(p,t) in keys(rG2GDP_p); t1 < t <= T]
    rGovTransferIncome[t1], vGovSocBenefitExp[t1]
    rRoWTransferIncome[t1], vSocialBenefits[:RoW,t1]
    rSocTransKind2G[t1], vSocTransKind[t1]
    rGovOthCurrentTransExp2GVA[t1], vGovOthCurrentTransExp[t1]
    rGovCapTransExp2GVA[t1], vGovCapTransExp[t1]
    rGovNonProducedAssetAcquisitions2GVA[t1], vNonProducedAssetAcquisitions[:Gov,t1]
    rOtherTransfers[s=[:FinCorp, :NonFinCorp, :RoW], t=[t1]],
    vOtherTransfers[s=[:FinCorp, :NonFinCorp, :RoW], t=[t1]]
    rFinCorpSocialBenefits[t1], vSocialBenefits[:FinCorp,t1]
    rSocialContributions[s=[:FinCorp, :Gov, :NonFinCorp, :RoW], t=[t1]],
    vSocialContributions[s=[:FinCorp, :Gov, :NonFinCorp, :RoW], t=[t1]]
  end

  return block
end

end # module
