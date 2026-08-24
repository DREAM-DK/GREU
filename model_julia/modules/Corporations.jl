# Populate financial and non-financial corporation entries of the SectorAccounts interface.
# Keep budget identities and portfolio rules for FinCorp and NonFinCorp.

module Corporations

using SquareModels
import ..Capital: vI_k_i
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..InputOutput: industry, product, vPurchaserUse_p_u, vY_i
import ..Labor: vWages_i
import ..model
import ..Production: vProductionTax_i
import ..ProductionSettings: capital_type
import ..SectorAccounts:
  sector,
  vNetFinTransactions,
  vNetFinIncome,
  vNetTransfers2sector,
  vCorrectionNonFinCorp2Hh,
  vGrossCapitalFormation,
  vNonFinancialNonProducedAssets,
  vGrossOpSurplusMixedIncome,
  vFinAL,
  vFinTransactions,
  vNetFinAssets,
  vFinAssets_al
import ..Time: t, t1, T
import ..Tags: ForecastConstant

# ============================================================================
# Variables
# ============================================================================
const CorporationsTag = Tag(:Corporations)
const corporation_sector = [:FinCorp, :NonFinCorp]
const fin_corp_industry = [:iK]
const public_industry = [:iO, :iP, :iQ]
const non_fin_corp_industry = setdiff(industry, [fin_corp_industry; public_industry])

@assert fin_corp_industry ⊆ industry "The financial corporation industry must be in the input-output data"
@assert public_industry ⊆ industry "Each public industry must be in the input-output data"

@variables model :: (CorporationsTag, ForecastConstant) begin
  rFinCorpDebtAssets2DomesticDebtLiabilities[t], "FinCorp debt asset ratio: debt assets relative to domestic debt liabilities of Hh, NonFinCorp, and Gov."
  rFinCorpDebtLiabilities2EquityLiabilities[t], "FinCorp capital structure: debt liabilities relative to own equity liabilities."
  rNonFinCorpEquityAssets2EquityLiabilities[t], "NonFinCorp equity asset ratio: equity assets relative to own equity liabilities."
  rNonFinCorpDebtAssets2Expenses[t], "NonFinCorp debt asset ratio: debt assets relative to total expenses."
  rNonFinCorpDebtLiabilities2EquityLiabilities[t], "NonFinCorp capital structure: debt liabilities relative to own equity liabilities."
  fGrossOpSurplus_s[s=corporation_sector, t=t], "Factor from modeled industry operating surplus to sector gross operating surplus."
  fGrossCapitalFormation_s[s=corporation_sector, t=t], "Factor from modeled industry investment to sector gross capital formation."
end

@variables model :: (CorporationsTag, GrowthAdjusted, InflationAdjusted) begin
  vGrossOpSurplus_i[i=industry, t=t], "Gross operating surplus by industry."
  vNonFinCorpExpenses[t], "NonFinCorp operating expenses: intermediate inputs, wages, and production taxes."
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
    # Production and investment links.
    vGrossOpSurplus_i[i=industry, t=t1:T],
    vGrossOpSurplus_i[i,t] == vY_i[i,t]
                                - ∑(vPurchaserUse_p_u[p,i,t] for p in product)
                                - vWages_i[i,t]
                                - vProductionTax_i[i,t]

    vGrossOpSurplusMixedIncome[s=[:FinCorp], t=t1:T],
    vGrossOpSurplusMixedIncome[s,t] == fGrossOpSurplus_s[s,t] * ∑(vGrossOpSurplus_i[i,t] for i in fin_corp_industry)

    vGrossOpSurplusMixedIncome[s=[:NonFinCorp], t=t1:T],
    vGrossOpSurplusMixedIncome[s,t] == fGrossOpSurplus_s[s,t] * ∑(vGrossOpSurplus_i[i,t] for i in non_fin_corp_industry)

    vGrossCapitalFormation[s=[:FinCorp], t=t1:T],
    vGrossCapitalFormation[s,t] == fGrossCapitalFormation_s[s,t] * ∑(vI_k_i[k,i,t] for k in capital_type, i in fin_corp_industry)

    vGrossCapitalFormation[s=[:NonFinCorp], t=t1:T],
    vGrossCapitalFormation[s,t] == fGrossCapitalFormation_s[s,t] * ∑(vI_k_i[k,i,t] for k in capital_type, i in non_fin_corp_industry)

    vNonFinCorpExpenses[t=t1:T],
    vNonFinCorpExpenses[t] == ∑(vPurchaserUse_p_u[p,i,t] for p in product, i in non_fin_corp_industry)
                              + ∑(vWages_i[i,t] for i in non_fin_corp_industry)
                              + ∑(vProductionTax_i[i,t] for i in non_fin_corp_industry)

    # Budget identity.
    vNetFinTransactions[s=[:FinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]

    vNetFinTransactions[s=[:NonFinCorp], t=t1:T],
    vNetFinTransactions[s,t] == vNetFinIncome[s,t]
                                 + vNetTransfers2sector[s,t]
                                 - vGrossCapitalFormation[s,t]
                                 - vNonFinancialNonProducedAssets[s,t]
                                 + vGrossOpSurplusMixedIncome[s,t]
                                 - vCorrectionNonFinCorp2Hh[t]

    # Portfolio.
    # Financial corporations.
    # Equity assets follow revaluation.
    vFinAL[s=[:FinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinTransactions[s,f,al,t] == 0

    # Debt assets are a fixed fraction of the aggregate debt liabilities of domestic sectors.
    vFinAL[s=[:FinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rFinCorpDebtAssets2DomesticDebtLiabilities[t] * ∑(vFinAL[s2,:Debt,:Liab,t] for s2 in sector if s2 in (:Hh, :NonFinCorp, :Gov))

    # Debt liabilities are a fixed fraction of equity liabilities (shareholder equity).
    vFinAL[s=[:FinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinAL[s,f,al,t] == rFinCorpDebtLiabilities2EquityLiabilities[t] * vFinAL[:FinCorp,:Equity,:Liab,t]

    # Equity liabilities are residual given net financial assets.
    vFinAL[s=[:FinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]

    # Non-financial corporations.
    # Equity assets are a fixed fraction of equity liabilities.
    vFinAL[s=[:NonFinCorp], f=[:Equity], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpEquityAssets2EquityLiabilities[t] * vFinAL[:NonFinCorp,:Equity,:Liab,t]

    # Debt assets are a fixed fraction of operating expenses.
    vFinAL[s=[:NonFinCorp], f=[:Debt], al=[:Assets], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpDebtAssets2Expenses[t] * vNonFinCorpExpenses[t]

    # Debt liabilities are a fixed fraction of equity liabilities.
    vFinAL[s=[:NonFinCorp], f=[:Debt], al=[:Liab], t=t1:T],
    vFinAL[s,f,al,t] == rNonFinCorpDebtLiabilities2EquityLiabilities[t] * vFinAL[:NonFinCorp,:Equity,:Liab,t]

    # Equity liabilities are residual given net financial assets.
    vFinAL[s=[:NonFinCorp], f=[:Equity], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == vFinAssets_al[s,:Assets,t] - vFinAssets_al[s,:Liab,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  block = define_equations()

  # At t1, use source values to identify scale factors and portfolio ratios.
  @endo_exo_swap! block begin
    fGrossOpSurplus_s[s=corporation_sector, t=[t1]], vGrossOpSurplusMixedIncome[s=corporation_sector, t=[t1]]
    fGrossCapitalFormation_s[s=corporation_sector, t=[t1]], vGrossCapitalFormation[s=corporation_sector, t=[t1]]

    rFinCorpDebtAssets2DomesticDebtLiabilities[t1], vFinAL[:FinCorp,:Debt,:Assets,t1]
    rFinCorpDebtLiabilities2EquityLiabilities[t1], vFinAL[:FinCorp,:Debt,:Liab,t1]
    rNonFinCorpEquityAssets2EquityLiabilities[t1], vFinAL[:NonFinCorp,:Equity,:Assets,t1]
    rNonFinCorpDebtAssets2Expenses[t1], vFinAL[:NonFinCorp,:Debt,:Assets,t1]
    rNonFinCorpDebtLiabilities2EquityLiabilities[t1], vFinAL[:NonFinCorp,:Debt,:Liab,t1]
  end

  return block
end

end # module
