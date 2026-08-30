# Government budget identities, source totals, and portfolio rules.
# Load budget items from Eurostat gov_10a_main.

include(joinpath(@__DIR__, "GovernmentSettings.jl"))

module Government

using SquareModels
import ..DataUtils: read_series
import ..GovernmentSettings: government_data_dir
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..IndustrySectors: vM_s, vWages_s
import ..model
import ..SectorAccounts:
  ass_liab,
  fin_instrument,
  sector,
  vConsumptionFixedCapital_s,
  vFinIncome_s_f,
  vFinPosition_s_f,
  vFinTransactions_f,
  vGovBalance,
  vNetFinAssets,
  vNetFinTransactions,
  vOtherTransfers
import ..Taxes:
  vGovOthProductionTax,
  vGovProductTax,
  vGovSub,
  vtCap,
  vtCorp,
  vtDirect,
  vtHhIncome,
  vtIndirect
import ..Time: t, t1, T
import ..Tags: ForecastZero

# ============================================================================
# Read data
# ============================================================================
const government_file = joinpath(government_data_dir, "government_variables.csv")

# ============================================================================
# Variables
# ============================================================================
const GovernmentTag = Tag(:Government)

@variables model :: (GovernmentTag, GrowthAdjusted, InflationAdjusted) begin
  vGovRevenue[t], "Revenue of government (TR)."
  vGovExpenditure[t], "Expenditure of government (TE)."
  vGovPrimaryRevenue[t], "Primary revenue of government (TR less interest income)."
  vGovPrimaryExpenditure[t], "Primary expenditure of government (TE less interest payments)."
  vGovPrimaryBalance[t], "Government net lending or borrowing before interest payments."

  vGovPrimaryRevOther[t], "Other primary revenue of government."
  vGovSalesRev[t], "Revenue from sales (P.11+P.12+P.131)."
  vGovOthSubRev[t], "Revenue from other subsidies (D.39)."
  vGovSocialContRev[t], "Revenue from social contributions (D.61)."
  vGovOthCurrentTransRev[t], "Revenue from other current transfers (D.7)."
  vGovCapRev[t], "Revenue from capital transfers (D.92+D.99)."

  vGovSocBenefitExp[t], "Social benefit expenditure of government (D.62+D.632)."
  vSocTransKind[t], "Social transfers in kind (D.632)."
  vGovOthCurrentTransExp[t], "Other current transfers expenditure of government (D.7)."
  vGovOthProdTax[t], "Other taxes on production paid by government (D.29)."
  vGovAdjExp[t] :: ForecastZero, "Adjustments of government (D.8)."
  vGovCapTransExp[t], "Capital transfers expenditure of government (D.9)."
  vGovNetAcquisitions[t], "Net acquisitions of non-produced non-financial assets of government (NP)."
end

# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  db[vGovBalance] .= read_series(government_file, "vGovBalance", t)
  db[vGovRevenue] .= read_series(government_file, "vGovRevenue", t)
  db[vGovExpenditure] .= read_series(government_file, "vGovExpenditure", t)

  db[vtIndirect] .= read_series(government_file, "vtIndirect", t)
  db[vtDirect] .= read_series(government_file, "vtDirect", t)
  db[vtHhIncome] .= read_series(government_file, "vtHhIncome", t)
  db[vtCorp] .= read_series(government_file, "vtCorp", t)
  db[vtCap] .= read_series(government_file, "vtCap", t)
  db[vGovProductTax] .= read_series(government_file, "vGovProductTax", t)
  db[vGovOthProductionTax] .= read_series(government_file, "vGovOthProductionTax", t)
  db[vGovSub] .= read_series(government_file, "vGovSub", t)

  db[vM_s[:Gov,:]] .= read_series(government_file, "vGovIntermediateCons", t)
  db[vWages_s[:Gov,:]] .= read_series(government_file, "vGovEmplComp", t)
  db[vGovOthProdTax] .= read_series(government_file, "vGovOthProdTax", t)

  db[vGovSalesRev] .= read_series(government_file, "vGovSalesRev", t)
  db[vGovOthSubRev] .= read_series(government_file, "vGovOthSubRev", t)
  db[vGovSocialContRev] .= read_series(government_file, "vGovSocialContRev", t)
  db[vGovOthCurrentTransRev] .= read_series(government_file, "vGovOthCurrentTransRev", t)
  db[vGovCapRev] .= read_series(government_file, "vGovCapRev", t)

  db[vConsumptionFixedCapital_s[:Gov,:]] .=
    read_series(government_file, "vGovConsumptionFixedCapital", t)
  db[vGovSocBenefitExp] .= read_series(government_file, "vGovSocBenefitExp", t)
  db[vSocTransKind] .= read_series(government_file, "vSocTransKind", t)
  db[vGovOthCurrentTransExp] .= read_series(government_file, "vGovOthCurrentTransExp", t)
  db[vGovAdjExp] .= read_series(government_file, "vGovAdjExp", t)
  db[vGovCapTransExp] .= read_series(government_file, "vGovCapTransExp", t)
  db[vGovNetAcquisitions] .= read_series(government_file, "vGovNetAcquisitions", t)

  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  return @block model begin
    # Totals.
    vGovRevenue[t=t1:T],
    vGovRevenue[t] == vGovPrimaryRevenue[t] + vFinIncome_s_f[:Gov,:Debt,:Assets,t]

    vGovExpenditure[t=t1:T],
    vGovExpenditure[t] == vGovPrimaryExpenditure[t] + vFinIncome_s_f[:Gov,:Debt,:Liab,t]

    # Balances.
    vGovPrimaryBalance[t=t1:T],
    vGovPrimaryBalance[t] == vGovPrimaryRevenue[t] - vGovPrimaryExpenditure[t]

    vGovBalance[t=t1:T],
    vGovBalance[t] == vGovPrimaryBalance[t]
                       + vFinIncome_s_f[:Gov,:Debt,:Assets,t]
                       - vFinIncome_s_f[:Gov,:Debt,:Liab,t]

    vNetFinTransactions[s=[:Gov], t=t1:T], vNetFinTransactions[s,t] == vGovBalance[t]

    # Other transfers span primary revenue and expenditure.
    vOtherTransfers[s=[:Gov], t=t1:T],
    vOtherTransfers[s,t] == vGovOthCurrentTransRev[t] + vGovCapRev[t]
                           - vGovOthCurrentTransExp[t] - vGovCapTransExp[t]
    vOtherTransfers[s=[:Hh], t=t1:T], ∑(vOtherTransfers[s2,t] for s2 in sector) == 0

    # Portfolio.
    # Gov neither buys nor sells equity; existing equity stocks follow non-transaction changes.
    vFinPosition_s_f[s=[:Gov], f=[:Equity], al=ass_liab, t=t1:T], vFinTransactions_f[s,f,al,t] == 0

    # Gov does not buy or sell debt assets; the stock follows non-transaction changes.
    vFinPosition_s_f[s=[:Gov], f=[:Debt], al=[:Assets], t=t1:T], vFinTransactions_f[s,f,al,t] == 0

    # Gov debt liabilities are residual given net financial assets.
    vFinPosition_s_f[s=[:Gov], f=[:Debt], al=[:Liab], t=t1:T],
    vNetFinAssets[s,t] == ∑(vFinPosition_s_f[s,f,:Assets,t] for f in fin_instrument)
                           - ∑(vFinPosition_s_f[s,f,:Liab,t] for f in fin_instrument)
  end
end

# ============================================================================
# Calibration
# ============================================================================
function define_calibration()
  return define_equations()
end

end # module
